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

## Beyond dotfiles/vim

Once the migration is complete, this config will grow on its own — new plugins,
local plugins developed in-repo, and workflow-specific tooling that the old setup
never had.

[lazy]: https://github.com/folke/lazy.nvim
