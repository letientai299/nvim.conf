return {
  cmd = { "vue-language-server", "--stdio" },
  filetypes = { "vue" },
  root_markers = { "package.json" },
  init_options = {
    typescript = { tsdk = require("lib.volar").get_tsdk() },
  },
}
