# Nvim Config

Pure Lua Neovim config, replacing `dotfiles/vim`.

## Motivation

The old config grew over years — vim-plug, vimscript, Lua, and CoC all mixed
together. Many plugins are only partially used. This repo starts fresh with
[lazy.nvim][lazy] and rewrites everything in Lua.

## Approach

Migration is incremental. Each plugin from the old config goes through a review:
keep it, replace it with a smaller alternative, or rewrite the needed bits in
Lua. The goal is a minimal config where every line earns its place.

The old config stays functional during migration. `nv` launches this config via
`NVIM_APPNAME`, so global `nvim` is unaffected.

## Dependencies

LSPs, formatters, linters, and CLI tools are declared in `tools.txt`. On a new
machine, install [mise][mise] and run:

```sh
mise run sync
```

This installs all tools globally. Brew-only packages (`pgformatter`) are
handled in `tasks/sync.sh`.

Prerequisites not managed by mise: a C compiler (Xcode CLT), `git`, `curl`,
[jq][], and [Roslyn language server][roslyn-install]. To add a new tool, add it
to `tools.txt` and re-run `mise run sync`.

## Keybinding differences from dotfiles/vim

[mini.surround][mini-surround] replaces `tpope/vim-surround`. Default mappings
differ — `sa`/`sd`/`sr` instead of `ys`/`ds`/`cs`. See `:h mini.surround` for
the full mapping reference.

## Migration notes

| Old plugin              | Replacement     | Notes                                                      |
| ----------------------- | --------------- | ---------------------------------------------------------- |
| `embear/vim-localvimrc` | Built-in `exrc` | Set `vim.o.exrc = true`, place `.nvim.lua` in project root |

## Beyond dotfiles/vim

Once the migration is complete, this config will grow on its own — new plugins,
local plugins developed in-repo, and workflow-specific tooling that the old
setup never had.

## Theme tests

**bold**, _italic_, **_both_**, ~~crossed~~, `-> ==> [] () != <> |> )( <|`,

[jq]: https://jqlang.github.io/jq/
[mise]: https://mise.jdx.dev/
[roslyn-install]:
  https://github.com/seblyng/roslyn.nvim?tab=readme-ov-file#install-the-language-server
[lazy]: https://github.com/folke/lazy.nvim
[mini-surround]: https://github.com/nvim-mini/mini.surround
