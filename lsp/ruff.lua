return {
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
  -- Defer hover to ty. Two responders break otter-ls, which forwards one
  -- request per attached client into a single handler.
  -- https://docs.astral.sh/ruff/editors/setup/#neovim
  on_attach = function(client)
    client.server_capabilities.hoverProvider = false
  end,
}
