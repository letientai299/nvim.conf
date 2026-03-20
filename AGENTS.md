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

**Every new plugin and tool addition MUST be verified for on-demand install
compatibility.** The initial lazy-load trigger is dropped during async clone, so
any side effects (activation, buffer setup, keymaps) that ran as no-ops will not
automatically replay. Use `on_load` to defer work until the plugin is ready.

### Choosing the right pattern

| Situation                                         | Pattern                                                             |
| ------------------------------------------------- | ------------------------------------------------------------------- |
| Fire-and-forget call (no return value needed)     | `lazy_require("mod").method()` — no-op proxy absorbs the call       |
| Side effect that MUST run per-buffer              | `on_load("plugin-name", fn)` — defers `fn` until after clone + load |
| `init` override that **returns** a computed value | `package.loaded["mod"]` guard — fall through to default when absent |
| Inside `config`/`opts` callbacks                  | Plain `require()` — runs after plugin loads                         |
| `<Cmd>PluginCmd<CR>` in keys                      | No guard needed — error suppressed by `lazy_ondemand.lua`           |
| Colorscheme triggers                              | No guard needed — installed synchronously for live preview          |

### Examples

```lua
local ondemand = require("lib.lazy_ondemand")

-- Fire-and-forget (no-op if not loaded):
ondemand.lazy_require("oil").open(path)

-- Must-run side effect (retries after clone finishes):
ondemand.on_load("snacks.nvim", function()
  require("snacks").setup()
end)
```

See `ts-context-commentstring.lua` and `snacks.lua` for real examples.

Theme plugins must declare a `themes` field listing their colorscheme names (see
`lua/plugins/themes/`).

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
