local M = {}

local hl_cache_path = vim.fn.stdpath("state") .. "/theme-highlight-startup.lua"

function M.invalidate()
  os.remove(hl_cache_path)
end

function M.write(colorscheme)
  local groups = vim.fn.getcompletion("", "highlight")
  table.sort(groups)

  local lines = {
    "-- Auto-generated startup highlight cache.",
    "local set_hl = vim.api.nvim_set_hl",
    string.format("vim.g.colors_name = %q", colorscheme),
  }

  for i = 0, 15 do
    local key = "terminal_color_" .. i
    local value = vim.g[key]
    if type(value) == "string" and value ~= "" then
      lines[#lines + 1] = string.format("vim.g[%q] = %q", key, value)
    end
  end

  for _, name in ipairs(groups) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = true })
    if ok and type(hl) == "table" then
      lines[#lines + 1] =
        string.format("set_hl(0, %q, %s)", name, vim.inspect(hl))
    end
  end

  local f = io.open(hl_cache_path, "w")
  if not f then
    return
  end
  f:write(table.concat(lines, "\n"))
  f:write("\n")
  f:close()
end

local scheduled = false
local pending_colorscheme = nil

function M.schedule_write(colorscheme)
  if type(colorscheme) ~= "string" or colorscheme == "" then
    return
  end

  -- Always accept the latest colorscheme so rapid switches don't drop writes.
  pending_colorscheme = colorscheme

  if scheduled then
    return
  end
  scheduled = true

  local function write()
    scheduled = false
    local cs = pending_colorscheme
    pending_colorscheme = nil
    -- Some themes (bamboo, kanagawa) set colors_name to a base name
    -- ("bamboo") while the user-facing variant is more specific
    -- ("bamboo-multiplex"). Accept if either is a prefix of the other.
    local cn = vim.g.colors_name
    if not cs or not cn then
      return
    end
    if cn ~= cs and not cs:find(cn, 1, true) and not cn:find(cs, 1, true) then
      return
    end
    M.write(cs)
  end

  -- Headless benchmarks never reach a real first redraw.
  if #vim.api.nvim_list_uis() == 0 then
    write()
  elseif vim.v.vim_did_enter == 0 then
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      once = true,
      callback = write,
    })
  else
    vim.schedule(write)
  end
end

return M
