return {
  cmd = { "tailwindcss-language-server", "--stdio" },
  filetypes = {
    "css",
    "html",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "vue",
    "svelte",
    "astro",
    "mdx",
  },
  root_markers = {
    "tailwind.config.js",
    "tailwind.config.ts",
    "tailwind.config.mjs",
    "tailwind.config.cjs",
    -- Tailwind v4 uses CSS-based config
    "postcss.config.js",
    "postcss.config.mjs",
    "postcss.config.cjs",
  },
  settings = {
    tailwindCSS = {
      validate = true,
    },
  },
}
