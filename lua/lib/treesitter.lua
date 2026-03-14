local M = {}

local registered = false

function M.register_default_languages()
  if registered then
    return
  end

  registered = true
  vim.treesitter.language.register(
    "tsx",
    { "typescriptreact", "javascriptreact" }
  )
  vim.treesitter.language.register("bash", { "sh" })
  vim.treesitter.language.register("json", { "jsonc" })
  vim.treesitter.language.register("c_sharp", { "cs" })
  vim.treesitter.language.register("markdown", { "mdx" })
end

function M.enable_highlight(bufnr, filetype)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if vim.bo[bufnr].buftype ~= "" then
    vim.b[bufnr].ts_highlight = false
    return false
  end

  M.register_default_languages()

  local active = vim.treesitter.highlighter.active[bufnr]
  if active then
    vim.b[bufnr].ts_highlight = true
    if type(filetype) == "string" and filetype ~= "" then
      vim.b[bufnr].current_syntax = filetype
    end
    return true
  end

  local ft = filetype
  if type(ft) ~= "string" or ft == "" then
    ft = vim.bo[bufnr].filetype
  end
  local lang = ft ~= "" and vim.treesitter.language.get_lang(ft) or nil

  local ok
  if type(lang) == "string" and lang ~= "" then
    ok = pcall(vim.treesitter.start, bufnr, lang)
  else
    ok = pcall(vim.treesitter.start, bufnr)
  end

  vim.b[bufnr].ts_highlight = ok
  if ok and type(ft) == "string" and ft ~= "" then
    vim.b[bufnr].current_syntax = ft
  end

  return ok
end

local installing = {} ---@type table<string, true?>

--- Auto-install a missing parser for the buffer's filetype, then enable
--- highlighting. Uses nvim-treesitter's async install; re-triggers
--- enable_highlight on completion.
function M.auto_install(bufnr)
  local ft = vim.bo[bufnr].filetype
  if ft == "" then
    return
  end

  local lang = vim.treesitter.language.get_lang(ft) or ft
  if installing[lang] then
    return
  end

  -- In-memory check: if the parser .so is already loaded, skip install
  if pcall(vim.treesitter.language.inspect, lang) then
    return
  end

  local parsers = require("nvim-treesitter.parsers")
  if not parsers[lang] then
    return -- no parser definition exists in nvim-treesitter
  end

  installing[lang] = true
  require("nvim-treesitter")
    .install({ lang }, {
      summary = false,
    })
    :await(function()
      installing[lang] = nil
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          M.enable_highlight(bufnr)
        end
      end)
    end)
end

return M
