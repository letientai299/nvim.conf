local tsdk = require("lib.volar").get_tsdk()

return {
  cmd = { "mdx-language-server", "--stdio" },
  filetypes = { "mdx" },
  root_markers = { "package.json", ".git" },
  init_options = {
    typescript = { tsdk = tsdk },
  },
}
