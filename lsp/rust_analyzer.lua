return {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  root_markers = { "Cargo.toml" },
  workspace_required = true,
  settings = {
    ["rust-analyzer"] = {
      check = { command = "clippy" },
      procMacro = { enable = true },
      completion = { autoimport = { enable = true } },
      inlayHints = {
        typeHints = { enable = true },
        parameterHints = { enable = true },
        chainingHints = { enable = true },
      },
    },
  },
}
