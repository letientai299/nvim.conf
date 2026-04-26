-- Open certain file types with the system's default application instead of
-- inside neovim. Add new extensions to the table below.

local M = {}

local exts = {
  doc = true,
  docx = true,
  pdf = true,
  ppt = true,
  pptx = true,
  xls = true,
  xlsx = true,
}

---@param filename string
---@return boolean
function M.is_external(filename)
  local ext = filename:match("%.([^.]+)$")
  return ext ~= nil and exts[ext:lower()] == true
end

---@param path string absolute path
function M.open(path)
  vim.ui.open(path)
end

--- Generate autocmd patterns (e.g. {"*.pdf", "*.docx", ...}).
---@return string[]
function M.patterns()
  local pats = {}
  for ext in pairs(exts) do
    pats[#pats + 1] = "*." .. ext
  end
  return pats
end

return M
