# Nvim Config

This is my new full lua Neovim config, optimize for fast startup, small cold
installs, and easy deployment on cloud VMs, containers, and other constrained
machines.

## Core ideas

I use this nvim distro on many machines. Some are dev/k8s container, EC2 VM, and
other constrainted env. In those env, the full dependencies are heavy. Hence:

- [**On-demand plugin install**](/docs/on-demand-plugin.md) — except some
  essential plugins, other plugins are only cloned when some events need it. The
  trade-off is 1st trigger is a no-op and need to wait a bit to use that plugin.
- [**On-demand tool install**](/docs/on-demand-tool.md) — CLI tools (LSP,
  linter, formatter) for each language are only installed when the matching
  filetype is opened.

For extra perf and convenience:

- [**Startup theme cache**](/docs/theme-cache.md) — highlight groups are
  snapshotted after a colorscheme loads and replayed on subsequent startups,
  skipping the theme plugin's init path.

For daily usage between many projects, some are monorepo:

- [**Cascading project `.nvim.lua`**](/docs/cascading-exrc.md) — per-project
  config files form an inheritance chain via `source_parent()`, so monorepo
  subdirectories share a common base.
- [**Dual LSP instance fallback**](/docs/dual-lsp-fallback.md) — LSP servers
  that accept a `--config` flag get two pre-registered configs gated by
  `root_dir`, so the right variant attaches based on project config presence.

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

[mise]: https://mise.jdx.dev/
[installer]: ./scripts/install.sh
