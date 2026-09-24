return {
  "windwp/nvim-ts-autotag",
  ft = {
    "astro",
    "blade",
    "dot",
    "elixir",
    "eruby",
    "glimmer",
    "handlebars",
    "hbs",
    "heex",
    "html",
    "htmlangular",
    "htmldjango",
    "javascript",
    "javascript.glimmer",
    "javascript.jsx",
    "javascriptreact",
    "liquid",
    "markdown",
    "php",
    "rescript",
    "rust",
    "svelte",
    "templ",
    "twig",
    "typescript",
    "typescript.glimmer",
    "typescript.tsx",
    "typescriptreact",
    "vento",
    "vue",
    "xml",
  },
  opts = {},
  config = function(_, opts)
    require("nvim-ts-autotag").setup(opts)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_buf_call(buf, function()
          require("nvim-ts-autotag.internal").attach(buf)
        end)
      end
    end
  end,
}
