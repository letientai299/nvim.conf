-- Shared image format detection (mirrors snacks.image defaults).
-- Used by oil.nvim and fzf-lua to lazy-load snacks before previewing images.

local M = {}

local exts = {
  png = true,
  jpg = true,
  jpeg = true,
  gif = true,
  bmp = true,
  webp = true,
  tiff = true,
  heic = true,
  avif = true,
  icns = true,
  pdf = true,
}

---@param filename string
---@return boolean
function M.is_image(filename)
  local ext = filename:match("%.([^.]+)$")
  return ext ~= nil and exts[ext:lower()] == true
end

return M
