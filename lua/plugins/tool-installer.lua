--- Tools named on the command line, or every tool of the current filetype.
---@param args string[]
---@return tool-installer.Tool[], string[] unknown bins
local function pick_tools(args)
  local registry = require("lib.lang_registry")
  if #args == 0 then
    return registry.tools_by_ft[vim.bo.filetype] or {}, {}
  end
  local by_bin = registry.tools_by_bin()
  local catalog = require("tool-installer").get_config().catalog
  local picked, unknown = {}, {}
  for _, bin in ipairs(args) do
    local t = by_bin[bin] or catalog[bin]
    if t then
      picked[#picked + 1] = t
    else
      unknown[#unknown + 1] = bin
    end
  end
  return picked, unknown
end

local function tool_install(opts)
  local tools, unknown = pick_tools(opts.fargs)
  if #unknown > 0 then
    vim.notify(
      "Unknown tools: " .. table.concat(unknown, ", "),
      vim.log.levels.WARN
    )
  end
  if #tools == 0 then
    vim.notify(
      "No tools registered for " .. vim.bo.filetype,
      vim.log.levels.WARN
    )
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  require("tool-installer").ensure(tools, function()
    if vim.api.nvim_buf_is_valid(buf) then
      require("lib.lsp").reattach(buf)
    end
  end, { force = opts.bang })
end

local function complete_tools(lead)
  local names = vim.tbl_keys(require("lib.lang_registry").tools_by_bin())
  vim.list_extend(
    names,
    vim.tbl_keys(require("tool-installer").get_config().catalog)
  )
  table.sort(names)
  return vim.tbl_filter(function(n)
    return vim.startswith(n, lead)
  end, names)
end

return {
  dir = vim.fn.stdpath("config") .. "/plugins/tool-installer",
  name = "tool-installer",
  lazy = false,
  config = function()
    require("tool-installer").setup({
      script_dir = vim.fn.stdpath("config") .. "/scripts",
      catalog = {
        go = { bin = "go", mise = "go" },
        node = { bin = "node", mise = "node" },
        rust = { bin = "cargo", mise = "rust" },
        dotnet = { bin = "dotnet", mise = "dotnet" },
        ["7zip"] = { bin = "7zz", mise = "aqua:ip7z/7zip" },
      },
    })

    vim.api.nvim_create_user_command("ToolInstall", tool_install, {
      bang = true,
      nargs = "*",
      complete = complete_tools,
      desc = "Install tools for buffer or by name; ! reinstalls",
    })
  end,
}
