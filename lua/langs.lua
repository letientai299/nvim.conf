local M = {}

local specs = {
  { module = "langs.astro", ft = { "astro" } },
  { module = "langs.bash", ft = { "bash", "sh", "zsh" } },
  { module = "langs.css", ft = { "css", "scss", "less" } },
  {
    module = "langs.cssmodules",
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  },
  { module = "langs.csharp", ft = { "cs" } },
  { module = "langs.docker", ft = { "dockerfile" } },
  { module = "langs.go", ft = { "go", "gomod", "gowork", "gotmpl" } },
  { module = "langs.html", ft = { "html" } },
  { module = "langs.json", ft = { "json", "jsonc" } },
  { module = "langs.lua", ft = { "lua" } },
  { module = "langs.markdown", ft = { "markdown", "markdown.mdx" } },
  { module = "langs.mdx", ft = { "mdx" } },
  { module = "langs.racket", ft = { "racket" } },
  { module = "langs.rust", ft = { "rust" } },
  { module = "langs.sql", ft = { "sql" } },
  { module = "langs.svelte", ft = { "svelte" } },
  {
    module = "langs.tailwind",
    ft = {
      "astro",
      "css",
      "html",
      "javascript",
      "javascriptreact",
      "mdx",
      "svelte",
      "typescript",
      "typescriptreact",
      "vue",
    },
  },
  { module = "langs.toml", ft = { "toml" } },
  {
    module = "langs.typescript",
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  },
  { module = "langs.vue", ft = { "vue" } },
  { module = "langs.yaml", ft = { "yaml", "yaml.docker-compose" } },
}

function M.setup()
  vim.filetype.add({ extension = { mdx = "mdx" } })

  local group = vim.api.nvim_create_augroup("LangLoader", { clear = true })

  for _, spec in ipairs(specs) do
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = spec.ft,
      once = true,
      callback = function(args)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(args.buf) then
            require(spec.module).setup(args.buf)
          end
        end)
      end,
    })
  end
end

return M
