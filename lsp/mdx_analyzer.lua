return {
  cmd = { "mdx-language-server", "--stdio" },
  filetypes = { "mdx" },
  root_markers = { "package.json", ".git" },
  on_init = require("lib.volar").on_init,
}
