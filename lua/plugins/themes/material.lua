return {
  "marko-cerovac/material.nvim",
  lazy = true,
  opts = {
    async_loading = true,
    plugins = { "blink", "gitsigns", "mini" },
    styles = {
      comments = { italic = true },
      keywords = { italic = true },
      functions = { bold = true },
      types = { bold = true },
    },
  },
  themes = {
    { name = "Material Darker", colorscheme = "material", before = [[vim.g.material_style = "darker"]] },
    { name = "Material Lighter", colorscheme = "material", before = [[vim.g.material_style = "lighter"]] },
    { name = "Material Oceanic", colorscheme = "material", before = [[vim.g.material_style = "oceanic"]] },
    { name = "Material Palenight", colorscheme = "material", before = [[vim.g.material_style = "palenight"]] },
    { name = "Material Deep Ocean", colorscheme = "material", before = [[vim.g.material_style = "deep ocean"]] },
  },
}
