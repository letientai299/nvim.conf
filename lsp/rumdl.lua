return {
  cmd = { "rumdl", "server", "--stdio" },
  filetypes = { "markdown", "quarto" },
  root_markers = { ".rumdl.toml", "rumdl.toml", ".git" },
  fallback_config = require("lib.rumdl").fallback_spec,
}
