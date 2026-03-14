import {
  useState,
  useEffect,
  useCallback,
  useMemo,
  type ReactNode,
  type FC,
  type ChangeEvent,
} from "react";

// --- Types ---

interface User {
  id: string;
  name: string;
  email: string;
  role: "admin" | "editor" | "viewer";
  lastLogin: Date;
}

interface FilterState {
  query: string;
  role: User["role"] | "all";
  sortBy: keyof Pick<User, "name" | "email" | "lastLogin">;
  sortDir: "asc" | "desc";
}

type Action<T extends string, P = void> = P extends void
  ? { type: T }
  : { type: T; payload: P };

type FilterAction =
  | Action<"SET_QUERY", string>
  | Action<"SET_ROLE", FilterState["role"]>
  | Action<"TOGGLE_SORT", FilterState["sortBy"]>
  | Action<"RESET">;

// --- Hooks ---

function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);
  return debounced;
}

function useFilterReducer(initial: FilterState) {
  const [state, setState] = useState(initial);

  const dispatch = useCallback((action: FilterAction) => {
    setState((prev) => {
      switch (action.type) {
        case "SET_QUERY":
          return { ...prev, query: action.payload };
        case "SET_ROLE":
          return { ...prev, role: action.payload };
        case "TOGGLE_SORT":
          return {
            ...prev,
            sortBy: action.payload,
            sortDir:
              prev.sortBy === action.payload && prev.sortDir === "asc"
                ? "desc"
                : "asc",
          };
        case "RESET":
          return initial;
      }
    });
  }, [initial]);

  return [state, dispatch] as const;
}

// --- Components ---

const Badge: FC<{ role: User["role"] }> = ({ role }) => {
  const colors = {
    admin: "bg-red-100 text-red-800",
    editor: "bg-blue-100 text-blue-800",
    viewer: "bg-gray-100 text-gray-800",
  } as const;

  return (
    <span className={`px-2 py-0.5 rounded text-xs font-medium ${colors[role]}`}>
      {role}
    </span>
  );
};

const SortButton: FC<{
  field: FilterState["sortBy"];
  current: FilterState["sortBy"];
  dir: FilterState["sortDir"];
  onToggle: (field: FilterState["sortBy"]) => void;
  children: ReactNode;
}> = ({ field, current, dir, onToggle, children }) => (
  <button
    onClick={() => onToggle(field)}
    className="flex items-center gap-1 text-sm font-medium"
  >
    {children}
    {current === field && <span>{dir === "asc" ? "↑" : "↓"}</span>}
  </button>
);

const UserRow: FC<{ user: User }> = ({ user }) => (
  <tr className="border-b hover:bg-gray-50 transition-colors">
    <td className="px-4 py-3 font-medium">{user.name}</td>
    <td className="px-4 py-3 text-gray-600">{user.email}</td>
    <td className="px-4 py-3">
      <Badge role={user.role} />
    </td>
    <td className="px-4 py-3 text-sm text-gray-500">
      {user.lastLogin.toLocaleDateString()}
    </td>
  </tr>
);

// --- Main ---

export default function UserTable({ users }: { users: User[] }) {
  const [filter, dispatch] = useFilterReducer({
    query: "",
    role: "all",
    sortBy: "name",
    sortDir: "asc",
  });

  const debouncedQuery = useDebounce(filter.query, 250);

  const filtered = useMemo(() => {
    let result = users.filter((u) => {
      if (filter.role !== "all" && u.role !== filter.role) return false;
      if (!debouncedQuery) return true;
      const q = debouncedQuery.toLowerCase();
      return u.name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q);
    });

    result.sort((a, b) => {
      const av = a[filter.sortBy];
      const bv = b[filter.sortBy];
      const cmp = av < bv ? -1 : av > bv ? 1 : 0;
      return filter.sortDir === "asc" ? cmp : -cmp;
    });

    return result;
  }, [users, filter.role, filter.sortBy, filter.sortDir, debouncedQuery]);

  return (
    <div className="space-y-4">
      <div className="flex gap-4 items-center">
        <input
          type="text"
          placeholder="Search users..."
          value={filter.query}
          onChange={(e: ChangeEvent<HTMLInputElement>) =>
            dispatch({ type: "SET_QUERY", payload: e.target.value })
          }
          className="border rounded px-3 py-1.5 text-sm"
        />
        <select
          value={filter.role}
          onChange={(e: ChangeEvent<HTMLSelectElement>) =>
            dispatch({
              type: "SET_ROLE",
              payload: e.target.value as FilterState["role"],
            })
          }
          className="border rounded px-3 py-1.5 text-sm"
        >
          <option value="all">All roles</option>
          <option value="admin">Admin</option>
          <option value="editor">Editor</option>
          <option value="viewer">Viewer</option>
        </select>
        <button
          onClick={() => dispatch({ type: "RESET" })}
          className="text-sm text-gray-500 underline"
        >
          Reset
        </button>
      </div>

      <table className="w-full border-collapse">
        <thead>
          <tr className="border-b-2 text-left">
            {(["name", "email", "lastLogin"] as const).map((field) => (
              <th key={field} className="px-4 py-2">
                <SortButton
                  field={field}
                  current={filter.sortBy}
                  dir={filter.sortDir}
                  onToggle={(f) => dispatch({ type: "TOGGLE_SORT", payload: f })}
                >
                  {field === "lastLogin" ? "Last Login" : field}
                </SortButton>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {filtered.map((user) => (
            <UserRow key={user.id} user={user} />
          ))}
        </tbody>
      </table>

      <p className="text-sm text-gray-500">
        Showing {filtered.length} of {users.length} users
      </p>
    </div>
  );
}
