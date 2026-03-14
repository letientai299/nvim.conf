# Multi-stage build for a Node.js application
# Exercises: FROM, ARG, COPY, RUN, HEALTHCHECK, multi-stage, caching layers

# --- Base ---
FROM node:22-alpine AS base
WORKDIR /app
RUN apk add --no-cache tini curl
ENV NODE_ENV=production
ENTRYPOINT ["/sbin/tini", "--"]

# --- Dependencies ---
FROM base AS deps
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts \
    && npm cache clean --force

# Dev dependencies (for building)
FROM deps AS dev-deps
RUN npm ci --ignore-scripts

# --- Build ---
FROM dev-deps AS build
ARG NODE_ENV=production
COPY tsconfig.json ./
COPY src/ src/
RUN npm run build \
    && rm -rf src/ tsconfig.json

# --- API target ---
FROM base AS api
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1
CMD ["node", "dist/server.js"]

# --- Worker target ---
FROM base AS worker
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./
CMD ["node", "dist/worker.js"]

# --- Dev ---
FROM dev-deps AS dev
ENV NODE_ENV=development
COPY . .
EXPOSE 3000 9229
CMD ["npx", "tsx", "watch", "--inspect=0.0.0.0:9229", "src/server.ts"]
