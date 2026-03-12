# nvim-conf

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

## Usage

```sh
nv              # launch nvim with this config
nv .            # open oil in current directory
nv some/file    # edit a file
```

The `nv` script lives at `~/.local/bin/nv`

## Dependencies

External tools required for full functionality. A bootstrap script to install
these automatically is planned.

| Tool              | Required by         | Install                        |
| ----------------- | ------------------- | ------------------------------ |
| `tree-sitter-cli` | nvim-treesitter     | `brew install tree-sitter-cli` |
| C compiler        | nvim-treesitter     | Xcode CLT / `gcc` / `clang`   |
| `git`             | lazy.nvim, parsers  | `brew install git`             |
| `curl`            | nvim-treesitter     | Usually preinstalled           |
| [jq][]            | git pre-commit hook | `brew install jq`              |

[tree-sitter-cli][ts-cli] (0.26.1+) is needed to compile grammar parsers.
Without it, `:TSInstall` for languages with external scanners (like `c_sharp`)
will fail.

## Keybinding differences from dotfiles/vim

[mini.surround][mini-surround] replaces `tpope/vim-surround`. Default mappings
differ — `sa`/`sd`/`sr` instead of `ys`/`ds`/`cs`. See `:h mini.surround` for
the full mapping reference.

## Migration notes

| Old plugin            | Replacement                | Notes                            |
| --------------------- | -------------------------- | -------------------------------- |
| `embear/vim-localvimrc` | Built-in `exrc`          | Set `vim.o.exrc = true`, place `.nvim.lua` in project root |

## Beyond dotfiles/vim

Once the migration is complete, this config will grow on its own — new plugins,
local plugins developed in-repo, and workflow-specific tooling that the old setup
never had.

## Theme tests

**bold**, _italic_, **_both_**, ~~crossed~~, `-> ==> [] () != <> |> )( <|`,

[jq]: https://jqlang.github.io/jq/
[lazy]: https://github.com/folke/lazy.nvim
[mini-surround]: https://github.com/nvim-mini/mini.surround
[ts-cli]: https://github.com/tree-sitter/tree-sitter/blob/master/crates/cli/README.md
