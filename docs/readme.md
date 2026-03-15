# Docs

Design docs for non-obvious features in this config.

| Doc                                        | Summary                                            |
| ------------------------------------------ | -------------------------------------------------- |
| [On-demand plugin install][plugin]         | Plugins clone on first trigger, not at startup     |
| [On-demand tool install][tool]             | CLI tools install when the matching filetype opens |
| [Startup theme cache][theme]               | Highlight snapshot replays instead of theme init   |
| [Cascading project `.nvim.lua`][exrc]      | Inherited per-project config via `source_parent()` |
| [Dual LSP instance fallback][lsp-fallback] | Two LSP configs gate by project config presence    |

[exrc]: ./cascading-exrc.md
[lsp-fallback]: ./dual-lsp-fallback.md
[plugin]: ./on-demand-plugin.md
[theme]: ./theme-cache.md
[tool]: ./on-demand-tool.md
