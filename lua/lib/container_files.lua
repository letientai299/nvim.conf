-- View files that live inside a container, on demand, with working LSP.
--
-- With a containerized LSP (see lsp/clangd.lua + a project `.nvim/clangd`), the
-- server returns definition/reference locations as *container* absolute paths
-- (e.g. /usr/local/cuda/include/...). Those don't exist on the host, so a plain
-- go-to-definition into a system header fails. This registers a BufReadCmd for
-- the given prefixes that streams the file out of the container with
-- `docker exec <container> cat <path>` into a read-only buffer.
--
-- The same clangd that answered the jump already parsed this header as part of
-- the project translation unit and resolves system paths natively (they're
-- identical host<->container; --path-mappings only rewrites the project). So we
-- adopt that originating client into the fetched buffer -- hover / definition /
-- references work inside the header, and jumping onward re-triggers the fetch
-- (chained navigation). A stray client that auto-attaches with the wrong root
-- is detached.
--
-- Generic mechanism: the container name and prefixes come from the project (its
-- trusted `.nvim.lua`), so nothing container-specific lives in shared config.

local M = {}

--- buf -> set of client ids we intentionally adopted (allowed by the guard).
M._adopted = {} ---@type table<integer, table<integer, true>>

--- True if `path` is `p` or sits beneath it, allowing a versioned suffix on the
--- last segment: prefix `/usr/local/cuda` matches both `/usr/local/cuda/...`
--- and the symlink-resolved `/usr/local/cuda-13.3/...` clangd actually emits,
--- but not `/usr/local/cudafoo`.
--- @param path string
--- @param prefixes string[]
--- @return boolean
local function under_prefix(path, prefixes)
  for _, p in ipairs(prefixes) do
    p = p:gsub("/*$", "")
    if path == p then
      return true
    end
    if vim.startswith(path, p) then
      local nxt = path:sub(#p + 1, #p + 1)
      if nxt == "/" or nxt == "-" then
        return true
      end
    end
  end
  return false
end

--- @param c table clangd/LSP client from vim.lsp.get_clients()
--- @param ft string
--- @return boolean
local function client_serves(c, ft)
  local fts = c.config and c.config.filetypes
  if not fts then
    return true -- can't tell from the client; don't over-filter
  end
  return vim.tbl_contains(fts, ft)
end

--- Find the client that most likely produced this jump and already has the file
--- in its index: the one attached to the buffer we jumped from (current, or the
--- alternate once the window has switched), else any active server for this
--- filetype that has a real root.
--- @param ft string
--- @return table? client from vim.lsp.get_clients(), or nil
local function pick_origin_client(ft)
  local function from_buf(b)
    if b and b > 0 and vim.api.nvim_buf_is_valid(b) then
      for _, c in ipairs(vim.lsp.get_clients({ bufnr = b })) do
        if client_serves(c, ft) then
          return c
        end
      end
    end
  end

  local c = from_buf(vim.api.nvim_get_current_buf()) or from_buf(vim.fn.bufnr("#"))
  if c then
    return c
  end
  for _, cand in ipairs(vim.lsp.get_clients()) do
    if client_serves(cand, ft) and cand.config and cand.config.root_dir then
      return cand
    end
  end
end

--- Attach the originating client to a fetched buffer so LSP works inside it.
--- @param buf integer
--- @param ft string
local function adopt_lsp(buf, ft)
  local origin = pick_origin_client(ft)
  if not origin then
    return -- no server to reuse; buffer stays a read-only view
  end
  if not vim.tbl_isempty(vim.lsp.get_clients({ bufnr = buf, id = origin.id })) then
    return -- already attached (e.g. buffer re-read)
  end
  M._adopted[buf] = M._adopted[buf] or {}
  M._adopted[buf][origin.id] = true
  vim.lsp.buf_attach_client(buf, origin.id) -- sends didOpen to that client
end

--- Populate `buf` (named `path`) with the file's contents from `container`.
--- @param docker string
--- @param container string
--- @param buf integer
--- @param path string
function M.load(docker, container, buf, path)
  local host = vim.uv.fs_stat(path)
  local lines
  if host then
    -- Rare on macOS, but if the path really exists on the host, read it here
    -- (a plain :edit would recurse back into this BufReadCmd).
    lines = vim.fn.readfile(path)
  else
    local res = vim.system({ docker, "exec", container, "cat", path }, { text = true }):wait()
    if res.code ~= 0 then
      vim.notify(
        ("container_files: cannot read %s from %s\n%s"):format(path, container, res.stderr or ""),
        vim.log.levels.WARN
      )
      return
    end
    lines = vim.split(res.stdout or "", "\n", { plain = true })
    -- Drop the empty trailing element from cat's final newline.
    if lines[#lines] == "" then
      lines[#lines] = nil
    end
  end

  -- Set these before writing: the buffer carries a real (phantom) filename, so
  -- nvim would otherwise try to create a swapfile and set_lines trips E325.
  -- buftype=nowrite keeps the name but forbids writing back.
  vim.bo[buf].swapfile = false
  vim.bo[buf].buftype = "nowrite"

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.bo[buf].readonly = true

  local ft = vim.filetype.match({ filename = path, buf = buf })
  if ft then
    vim.bo[buf].filetype = ft -- may spawn a stray auto-attach; the guard reaps it
    adopt_lsp(buf, ft)
  end
end

--- @param opts { container: string, prefixes: string[], docker?: string, augroup?: string }
function M.setup(opts)
  local container = assert(opts.container, "container_files: container required")
  local prefixes = assert(opts.prefixes, "container_files: prefixes required")
  local docker = opts.docker or "docker"
  local group = vim.api.nvim_create_augroup(opts.augroup or "container_files", { clear = true })

  -- Trailing `*` (not `/*`) so a versioned dir like /usr/local/cuda-13.3/... is
  -- caught too; autocmd `*` spans `/`. under_prefix() keeps this from matching
  -- an unrelated sibling like /usr/local/cudafoo.
  local patterns = {}
  for _, p in ipairs(prefixes) do
    patterns[#patterns + 1] = p:gsub("/*$", "") .. "*"
  end

  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = patterns,
    callback = function(args)
      M.load(docker, container, args.buf, args.match)
    end,
  })

  -- Keep the adopted (originating) client; detach anything else that
  -- auto-attaches to a fetched buffer -- e.g. a host clangd rooted nowhere that
  -- would fail against the non-existent host file.
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local buf, id = args.buf, args.data.client_id
      local name = vim.api.nvim_buf_get_name(buf)
      if not (under_prefix(name, prefixes) and not vim.uv.fs_stat(name)) then
        return
      end
      if M._adopted[buf] and M._adopted[buf][id] then
        return -- intentionally reused
      end
      vim.schedule(function()
        pcall(vim.lsp.buf_detach_client, buf, id)
      end)
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      M._adopted[args.buf] = nil
    end,
  })
end

return M
