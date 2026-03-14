-- Schema: multi-tenant project management
-- Exercises: DDL, constraints, indexes, triggers, CTEs, window functions

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Tenants
CREATE TABLE tenants (
    id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug        text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9-]{3,32}$'),
    name        text NOT NULL,
    plan        text NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'pro', 'enterprise')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    archived_at timestamptz
);

CREATE INDEX idx_tenants_slug ON tenants (slug);

-- Users
CREATE TABLE users (
    id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email       text NOT NULL,
    name        text NOT NULL,
    role        text NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, email)
);

-- Projects
CREATE TABLE projects (
    id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name        text NOT NULL,
    description text,
    status      text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'archived')),
    created_by  uuid REFERENCES users(id) ON DELETE SET NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_projects_tenant ON projects (tenant_id, status);

-- Tasks with recursive parent for subtasks
CREATE TABLE tasks (
    id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id  uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    parent_id   uuid REFERENCES tasks(id) ON DELETE CASCADE,
    title       text NOT NULL,
    body        text,
    priority    smallint NOT NULL DEFAULT 0 CHECK (priority BETWEEN 0 AND 4),
    status      text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'review', 'done', 'cancelled')),
    assignee_id uuid REFERENCES users(id) ON DELETE SET NULL,
    due_date    date,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_tasks_project_status ON tasks (project_id, status);
CREATE INDEX idx_tasks_assignee ON tasks (assignee_id) WHERE assignee_id IS NOT NULL;

-- Trigger: auto-update updated_at
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_projects_updated BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_tasks_updated BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- View: task tree with depth via recursive CTE
CREATE OR REPLACE VIEW task_tree AS
WITH RECURSIVE tree AS (
    SELECT id, parent_id, title, status, priority, 0 AS depth
    FROM tasks
    WHERE parent_id IS NULL
    UNION ALL
    SELECT t.id, t.parent_id, t.title, t.status, t.priority, tree.depth + 1
    FROM tasks t
    JOIN tree ON tree.id = t.parent_id
)
SELECT * FROM tree;

-- Analytics query: per-project summary with window functions
CREATE OR REPLACE VIEW project_summary AS
SELECT
    p.id AS project_id,
    p.name AS project_name,
    count(t.id) AS total_tasks,
    count(t.id) FILTER (WHERE t.status = 'done') AS done_tasks,
    round(
        count(t.id) FILTER (WHERE t.status = 'done')::numeric
        / NULLIF(count(t.id), 0) * 100, 1
    ) AS completion_pct,
    avg(t.priority) AS avg_priority,
    rank() OVER (
        PARTITION BY p.tenant_id
        ORDER BY count(t.id) FILTER (WHERE t.status = 'done')::numeric
                 / NULLIF(count(t.id), 0) DESC NULLS LAST
    ) AS tenant_rank
FROM projects p
LEFT JOIN tasks t ON t.project_id = p.id
GROUP BY p.id, p.name, p.tenant_id;

COMMIT;
