# Docs

Design docs for non-obvious features in this config.

| Doc                                        | Summary                                             |
| ------------------------------------------ | --------------------------------------------------- |
| [On-demand plugin install][plugin]         | Plugins clone on first trigger, not at startup      |
| [On-demand tool install][tool]             | CLI tools install when the matching filetype opens  |
| [Startup theme cache][theme-cache]         | Highlight snapshot replays instead of theme init    |
| [Store-theme pipeline][store-theme]        | Theme catalog → picker → persistence → cache        |
| [Prettier textwidth sync][prettier-tw]     | Auto-set `textwidth` from prettier `printWidth`     |
| [Cascading project `.nvim.lua`][exrc]      | Inherited per-project config via `source_parent()`  |
| [Dual LSP instance fallback][lsp-fallback] | Two LSP configs gated by project config presence    |
| [CUDA clangd on macOS][cuda-on-mac]        | Containerized clangd + path mapping for `.cu` files |
| [Clipboard sync over SSH][ssh-clipboard]   | OSC 52 routes yanks to the local clipboard remotely |

[cuda-on-mac]: ./cuda-on-mac.md
[ssh-clipboard]: ./ssh-clipboard.md
[exrc]: ./cascading-exrc.md
[lsp-fallback]: ./dual-lsp-fallback.md
[plugin]: ./on-demand-plugin.md
[prettier-tw]: ./prettier-textwidth.md
[store-theme]: ./store-theme.md
[theme-cache]: ./theme-cache.md
[tool]: ./on-demand-tool.md
