-- Capture at load time so it works regardless of stdpath("config")
local this_dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))

local function title_case(s)
  return s:gsub("[_-]", " "):gsub("(%a)([%w]*)", function(first, rest)
    return first:upper() .. rest
  end)
end

local function collect_themes()
  local themes = { "default" }
  local dir = this_dir
  for name, ftype in vim.fs.dir(dir) do
    if ftype == "file" and name:match("%.lua$") and name ~= "themery.lua" then
      local mod = dofile(dir .. "/" .. name)
      if mod.themes then
        for _, t in ipairs(mod.themes) do
          if type(t) == "string" then
            table.insert(themes, { name = title_case(t), colorscheme = t })
          else
            table.insert(themes, {
              name = t.name or title_case(t.colorscheme),
              colorscheme = t.colorscheme,
              before = t.before,
              after = t.after,
            })
          end
        end
      end
    end
  end
  return themes
end

return {
  "zaldih/themery.nvim",
  lazy = false,
  priority = 1000,
  keys = {
    { "<leader>ft", "<Cmd>Themery<CR>", desc = "Colorschemes" },
  },
  config = function()
    require("themery").setup({
      themes = collect_themes(),
      livePreview = true,
    })
  end,
}
