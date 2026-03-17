# Nvim Config

Full Lua Neovim config optimized for fast startup, small cold installs, and easy
deployment on cloud VMs, containers, and other constrained machines.

## Core ideas

This config is shaped by two recurring use cases.

The full design-doc index lives in [`docs/readme.md`][docs-index].

### For constrained environments

I use this config on dev containers, EC2 VMs, and K8s pods. Full dependencies
are heavy in those environments.

- [**On-demand plugin install**][on-demand-plugin] — plugins clone on first
  trigger, not at startup. First use is a no-op while the clone finishes.
- [**On-demand tool install**][on-demand-tool] — CLI tools (LSP, linter,
  formatter) install when the matching filetype opens.
- [**Startup theme cache**][theme-cache] — highlight groups are snapshotted
  after a colorscheme loads and replayed on subsequent startups, skipping the
  theme plugin's init path.

### For daily project switching

Across many repos, including monorepos, the config should adapt with minimal
per-project friction.

- [**Cascading project `.nvim.lua`**][exrc] — per-project config files form an
  inheritance chain via `source_parent()`, so monorepo subdirectories share a
  common base.
- [**Dual LSP instance fallback**][lsp-fallback] — LSP servers that accept a
  `--config` flag get two pre-registered configs gated by `root_dir`, so the
  right variant attaches based on project config presence.

## Dependencies

Required:

- `sh`, `git`, `curl` or `wget`
- Outbound access to GitHub (for [mise][] and tree-sitter downloads)

The installer auto-provisions everything else — `mise`, `nvim`, `fzf`, `fd`,
`rg`, `tree-sitter`. A C compiler is needed for tree-sitter parser builds; if
none is found, `zig` is installed via mise as a fallback. On musl systems
(Alpine), `tree-sitter-cli` and `build-base` are installed via `apk` instead.
Older glibc systems (RHEL 9 / Rocky 9) fall back to tree-sitter v0.25/0.24
automatically.

On minimal base images, some runtime libraries still need to come from the
system package manager. `install.sh` does **not** install them. In the test
images this includes `libicu` and `libatomic` (or distro equivalents) for
Node/npm-backed tooling. See [`tests/infra/`][test-infra] for per-distro
examples.

## Install

[`./scripts/install.sh`][installer] handles everything:

1. Installs `mise` and activates it in shell rc files
2. Installs `nvim` via mise (aqua backend)
3. Installs global CLI tools (`fzf`, `fd`, `rg`, `tree-sitter`, optionally
   `zig`)
4. Clones or symlinks the config to `~/.config/nvim`
5. Bootstraps essential plugins in headless mode

Re-running the script pulls the latest changes (`git pull --ff-only`) when the
working tree is clean.

> [!NOTE]
>
> - Tools are installed globally via `mise use -g`. This _may_ upgrade existing
>   tool versions and **will** modify `~/.config/mise/config.toml`.
> - Shell rc files are edited to activate [mise][].
> - Only startup-triggered plugins are bootstrapped. For a personal machine, use
>   `:Lazy` to install all 70+ plugins.

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

## Builtin plugins

| Plugin                      | Description                                                                           |
| --------------------------- | ------------------------------------------------------------------------------------- |
| [tool-installer][pi-tool]   | Async multi-backend (mise, brew, script) dev tool provisioning with caching and dedup |
| [store-theme][pi-theme]     | Persistent colorscheme with picker, before/after hooks, and highlight cache           |
| [store-guifont][pi-font]    | Per-context GUI font persistence (neovide, firenvim) with picker and zoom             |
| [blink-cmp-path][pi-path]   | Project-wide path completion via `git ls-files` with incremental updates              |
| [blink-cmp-kitty][pi-kitty] | Completions from other Kitty terminal panes (words, URLs, paths)                      |
| [web-grep][pi-web]          | Web search under cursor — multiple engines, per-project context via `.nvim.lua`       |
| [autocopy][pi-copy]         | Auto-copy buffer to system clipboard on focus loss                                    |
| [yanker][pi-yank]           | Path and diagnostic line yanking helpers                                              |
| [notes][pi-notes]           | Timestamped daily diary notes                                                         |

## Customization

- **Per-machine** — `lua/local/` is gitignored and loaded at startup. Add
  plugins in `lua/local/plugins/` or override settings in `lua/local/init.lua`.
- **Per-project** — `.nvim.lua` at the project root runs via `vim.opt.exrc`. See
  [cascading exrc][exrc] for monorepo inheritance.

## Performance

Startup benchmarks, lazy.nvim profiling, and readiness timing scripts live in
[`perf/`][perf]. Includes sample files for the heaviest lang-module setups.

## Testing

Multi-distro test containers (Alpine, Ubuntu, Fedora, Arch, Rocky, Amazon Linux,
Azure Linux, GCP Debian) with a caching MITM proxy for reproducible offline
runs. See [`tests/readme.md`][tests] for details.

[perf]: ./perf/readme.md
[mise]: https://mise.jdx.dev/
[installer]: ./scripts/install.sh
[test-infra]: ./tests/infra/
[tests]: ./tests/readme.md
[docs-index]: ./docs/readme.md
[on-demand-plugin]: ./docs/on-demand-plugin.md
[on-demand-tool]: ./docs/on-demand-tool.md
[theme-cache]: ./docs/theme-cache.md
[exrc]: ./docs/cascading-exrc.md
[lsp-fallback]: ./docs/dual-lsp-fallback.md
[pi-tool]: ./plugins/tool-installer/doc/tool-installer.txt
[pi-theme]: ./plugins/store-theme/doc/store-theme.txt
[pi-font]: ./plugins/store-guifont/doc/store-guifont.txt
[pi-path]: ./plugins/blink-cmp-path/doc/blink-cmp-path.txt
[pi-kitty]: ./plugins/blink-cmp-kitty/doc/blink-cmp-kitty.txt
[pi-web]: ./plugins/web-grep/doc/web-grep.txt
[pi-copy]: ./plugins/autocopy.nvim/doc/autocopy.txt
[pi-yank]: ./plugins/yanker.nvim/doc/yanker.txt
[pi-notes]: ./plugins/notes.nvim/doc/notes.txt
