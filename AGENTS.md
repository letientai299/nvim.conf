# Project Rules

## Adding a new language

Each language has three integration points:

1. **`ftplugin/<ft>.lua`** — entry point, called by nvim on `FileType`. Calls
   the lang module's `setup(buf)`. Multiple filetypes can share one lang module
   (e.g., `go.lua`, `gomod.lua`, `gotmpl.lua` all call `langs.shared.go`).
2. **Lang module under `lua/langs/`** — declares LSP, formatters, linters, and
   treesitter parsers via `entry.setup()`. The `tools` table lists external
   binaries with `bin` (executable name), optional `mise`/`brew`/`script`
   backend fields, and optional `dependencies` (catalog keys for runtimes that
   must be installed first, e.g., `{ "node" }` for npm tools). Follow existing
   modules for the pattern. Runtime catalog entries live in
   `lua/plugins/tool-installer.lua`.

When adding a new language, update points 1 and 2.

## On-demand plugin install compatibility

Plugins may be cloned asynchronously via `lua/lib/lazy_ondemand.lua`. When a
lazy-load trigger fires for an uninstalled plugin, the clone runs in the
background and the trigger is **dropped** — the plugin loads only after the
clone finishes.

Use `lazy_require` from `lib.lazy_ondemand` when calling plugin modules outside
`config`/`opts`. It returns a **no-op proxy** if the module isn't loaded,
silently absorbing method calls and indexing.

```lua
local lazy_require = require("lib.lazy_ondemand").lazy_require

-- In init, keys, or top-level functions that may run before the plugin loads:
lazy_require("oil").open(path)        -- no-op if oil is installing
lazy_require("toggleterm.terminal")   -- returns proxy, .get_all() etc. are safe
```

**When `lazy_require` is NOT enough** — use `package.loaded` guards instead:

- `init` overrides that **return** the result of `require("<plugin>").compute()`
  — the proxy would be returned as the value. Guard with
  `package.loaded["<module>"]` and fall through to default behavior.

See `ts-context-commentstring.lua` and `snacks.lua` for examples.

**Safe patterns** (no `lazy_require` needed):

- `require("<plugin>")` inside `config` or `opts` — runs after plugin loads.
- `require("lib.*")` — config-local modules, always available.
- `<Cmd>PluginCmd<CR>` in keys — error suppressed by `lazy_ondemand.lua`.
- Colorscheme triggers — installed synchronously so the picker's live preview
  works. Theme plugins must declare a `themes` field listing their colorscheme
  names (see `lua/plugins/themes/` for examples).

## Theme guard globals

Some themes ship `after/syntax/*` files that read theme globals before
`colors/*.vim` has initialized them during cached-theme / early-load paths. For
those themes, declare required globals via `init_globals` on the theme spec and
let `lua/lib/theme_helpers.lua` apply them before the theme's own `init()`.

Example:

```lua
return {
  "sainnhe/sonokai",
  lazy = true,
  init_globals = {
    sonokai_loaded_file_types = {},
  },
  init = function()
    vim.g.sonokai_better_performance = 1
  end,
}
```

Do **not** guess or auto-generate globals for every theme. Only declare
theme-specific globals that you have confirmed are read early by that theme's
own scripts.

## Performance benchmarking

Scripts and sample files live in `perf/`. See `perf/readme.md` for the full
guide.

- `perf/utils/sanity-check.sh` — verify config boots cleanly (headless +
  headful)
- `perf/utils/bench.sh` — `nvim --startuptime` across all cases, reports medians
- `perf/utils/lazy-profile.sh [target]` — capture lazy.nvim per-plugin profile
  (requires a real terminal, not `--headless`)
- `perf/samples/` — self-contained source files as benchmark targets
