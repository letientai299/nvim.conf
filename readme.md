# Nvim Config

This is my Lua Neovim config. I optimize for fast startup, small cold installs,
and easy deployment on cloud VMs, containers, and other constrained machines.

## Core ideas

- **On-demand plugin install** — a plugin is cloned when some real trigger asks
  for it. See [on-demand-plugin-install][].
- **On-demand tool install** — language tools install when the matching filetype
  is opened. See [on-demand-tool-install][].
- **Eager warm-up** — `mise run sync` installs everything from [tools.txt][] up
  front when I want a fully-prepared machine.

## Dependencies

Prerequisite :

- `sh`, `git`, `curl`/`wget`, `tar`
- Outbound access to GitHub, for [mise][], and the tree-sitter to download

> [!WARNING] Many tools needs `node`, and are installed via `npm` backend. Even
> though we can manage `node` via `mise`, we can't make sure everything `node`
> needs are available in the system. Our limited manual testing using containers
> buld from `./tests/infra/*.Dockerfile` show that `libatomic`,`icu` must be
> available before hand.

Optional:

- A C compiler for tree-sitter parser builds. This nvim distro will auto
  download `zig` via `mise` if none exists, but that's mostly a hack, as
  `zig cc` isn't fully compatible with all the gcc/llvm flags that
  `nvim-treesitter` uses.

## Install

How [`./scripts/install.sh`][installer] works:

- Ensure these commands are available: `mise`, `nvim`, `fzf`, `fd`, `rg`,
  `tree-sitter`.
- Backup existings `~/.config/nvim` if any.
- Clones or symlinks (if run within a cloned copy of this repo) this repo to
  `~/.config/nvim`
- Bootstraps some essential plugins to nost block `nvim` 1st startup.

The script could also be used for `git pull --ff-only` the repo, as long as
there's no dirty changes.

> [!NOTE]
>
> - Tools are installed globally via `mise use -g`. This _might_ upgrade your
>   exist tool versions, and **will** make change to your global
>   `~/.config/mise/config.toml`.
> - It might edits shell rc files to activate [mise][].
> - It bootstraps startup-triggered plugins only, as not all plugins are needed
>   for all env. For personal machine, you can use `mise run sync` to install
>   all tools and use `:Lazy` UI to install all 70+ plugins.

### Remote install

```sh

curl -fsSL https://raw.githubusercontent.com/letientai299/nvim.conf/main/scripts/install.sh | sh
```

### From a local clone

```sh
git clone https://github.com/letientai299/nvim.conf ~/.config/nvim
cd ~/.config/nvim
./scripts/install.sh
```

Unattended / CI:

```sh
./scripts/install.sh -y
```

## Custom plugins

- **web-grep** (`plugins/web-grep/`) — search the word under cursor or visual
  selection in a browser. Supports multiple engines and per-project context
  keywords via `.nvim.lua`.

[on-demand-plugin-install]: docs/on-demand-plugin-install.md
[mise]: https://mise.jdx.dev/
[on-demand-tool-install]: docs/on-demand-tool-install.md
[tools.txt]: tools.txt
[installer]: ./scripts/install.sh
