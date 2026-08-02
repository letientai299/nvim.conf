-- View files that live inside a container, read-only, on demand.
--
-- With a containerized LSP (see lsp/clangd.lua + a project `.nvim/clangd`), the
-- server returns definition/reference locations as *container* absolute paths
-- (e.g. /usr/local/cuda/include/...). Those don't exist on the host, so a plain
-- go-to-definition into a system header fails. This registers a BufReadCmd for
-- the given prefixes that streams the file out of the container with
-- `docker exec <container> cat <path>` into a scratch, read-only buffer -- the
-- LSP jump's line/col still lands correctly.
--
-- Generic mechanism: the container name and prefixes come from the project (its
-- trusted `.nvim.lua`), so nothing container-specific lives in shared config.

local M = {}

--- @param path string
--- @param prefixes string[]
--- @return boolean
local function under_prefix(path, prefixes)
  for _, p in ipairs(prefixes) do
    if path == p or vim.startswith(path, p:gsub("/*$", "") .. "/") then
      return true
    end
  end
  return false
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

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.bo[buf].readonly = true
  vim.bo[buf].swapfile = false
  vim.bo[buf].buftype = "nowrite" -- keep the name, forbid writing to a phantom path

  local ft = vim.filetype.match({ filename = path, buf = buf })
  if ft then
    vim.bo[buf].filetype = ft
  end
end

--- @param opts { container: string, prefixes: string[], docker?: string, augroup?: string }
function M.setup(opts)
  local container = assert(opts.container, "container_files: container required")
  local prefixes = assert(opts.prefixes, "container_files: prefixes required")
  local docker = opts.docker or "docker"
  local group = vim.api.nvim_create_augroup(opts.augroup or "container_files", { clear = true })

  local patterns = {}
  for _, p in ipairs(prefixes) do
    patterns[#patterns + 1] = p:gsub("/*$", "") .. "/*"
  end

  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = patterns,
    callback = function(args)
      M.load(docker, container, args.buf, args.match)
    end,
  })

  -- The fetched buffers carry container paths, so any LSP that auto-attaches
  -- (host clangd, rooted nowhere) would fail against the non-existent host
  -- file. Detach it -- these buffers are for reading, not indexing.
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local name = vim.api.nvim_buf_get_name(args.buf)
      if under_prefix(name, prefixes) and not vim.uv.fs_stat(name) then
        vim.schedule(function()
          pcall(vim.lsp.buf_detach_client, args.buf, args.data.client_id)
        end)
      end
    end,
  })
end

return M
