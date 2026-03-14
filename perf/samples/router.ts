import { type Request, type Response, type NextFunction } from "express";

// --- Types ---

interface RouteConfig {
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  path: string;
  handler: (req: Request, res: Response) => Promise<void>;
  middleware?: Middleware[];
  rateLimit?: { windowMs: number; max: number };
}

type Middleware = (req: Request, res: Response, next: NextFunction) => void;

interface ApiError {
  status: number;
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

// --- Middleware ---

function createRateLimiter(windowMs: number, max: number): Middleware {
  const hits = new Map<string, { count: number; resetAt: number }>();

  return (req, res, next) => {
    const key = req.ip ?? "unknown";
    const now = Date.now();
    const entry = hits.get(key);

    if (!entry || now > entry.resetAt) {
      hits.set(key, { count: 1, resetAt: now + windowMs });
      return next();
    }

    if (entry.count >= max) {
      res.status(429).json({
        status: 429,
        code: "RATE_LIMITED",
        message: `Too many requests, retry after ${Math.ceil((entry.resetAt - now) / 1000)}s`,
      } satisfies ApiError);
      return;
    }

    entry.count++;
    next();
  };
}

function validateBody<T extends Record<string, unknown>>(
  schema: Record<keyof T, (v: unknown) => boolean>,
): Middleware {
  return (req, res, next) => {
    const errors: string[] = [];
    for (const [field, validate] of Object.entries(schema)) {
      if (!validate(req.body?.[field])) {
        errors.push(`Invalid field: ${field}`);
      }
    }
    if (errors.length > 0) {
      res.status(400).json({
        status: 400,
        code: "VALIDATION_ERROR",
        message: "Request validation failed",
        details: { errors },
      } satisfies ApiError);
      return;
    }
    next();
  };
}

// --- Route builder ---

class Router {
  private routes: RouteConfig[] = [];

  add(config: RouteConfig): this {
    this.routes.push(config);
    return this;
  }

  get(path: string, handler: RouteConfig["handler"]): this {
    return this.add({ method: "GET", path, handler });
  }

  post(
    path: string,
    handler: RouteConfig["handler"],
    opts?: Pick<RouteConfig, "middleware" | "rateLimit">,
  ): this {
    return this.add({ method: "POST", path, handler, ...opts });
  }

  build(): RouteConfig[] {
    return this.routes.map((route) => {
      const middleware = [...(route.middleware ?? [])];
      if (route.rateLimit) {
        middleware.unshift(
          createRateLimiter(route.rateLimit.windowMs, route.rateLimit.max),
        );
      }
      return { ...route, middleware };
    });
  }
}

// --- Handlers ---

interface User {
  id: string;
  name: string;
  email: string;
  createdAt: Date;
}

const users = new Map<string, User>();

async function listUsers(_req: Request, res: Response): Promise<void> {
  const list = Array.from(users.values()).sort(
    (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
  );
  res.json({ data: list, total: list.length });
}

async function getUser(req: Request, res: Response): Promise<void> {
  const user = users.get(req.params.id);
  if (!user) {
    res.status(404).json({
      status: 404,
      code: "NOT_FOUND",
      message: `User ${req.params.id} not found`,
    } satisfies ApiError);
    return;
  }
  res.json({ data: user });
}

async function createUser(req: Request, res: Response): Promise<void> {
  const id = crypto.randomUUID();
  const user: User = {
    id,
    name: req.body.name,
    email: req.body.email,
    createdAt: new Date(),
  };
  users.set(id, user);
  res.status(201).json({ data: user });
}

// --- Assembly ---

const isNonEmpty = (v: unknown): boolean =>
  typeof v === "string" && v.length > 0;

const router = new Router()
  .get("/users", listUsers)
  .get("/users/:id", getUser)
  .post("/users", createUser, {
    middleware: [validateBody({ name: isNonEmpty, email: isNonEmpty })],
    rateLimit: { windowMs: 60_000, max: 10 },
  });

export { router, type RouteConfig, type ApiError, type User };
