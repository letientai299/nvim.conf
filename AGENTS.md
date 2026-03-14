# Project Rules

## Adding a new language

Each language has three integration points:

1. **`ftplugin/<ft>.lua`** — entry point, called by nvim on `FileType`. Calls
   the lang module's `setup(buf)`. Multiple filetypes can share one lang module
   (e.g., `go.lua`, `gomod.lua`, `gotmpl.lua` all call `langs.shared.go`).
2. **Lang module under `lua/langs/`** — declares LSP, formatters, linters, and
   treesitter parsers via `entry.setup()`. The `tools` table lists external
   binaries with `bin` (executable name) and `kind` (`lsp`, `fmt`, `lint`,
   `check`). Follow existing modules for the pattern.
3. **`tools.txt`** — every external binary in the `tools` table must have a
   corresponding entry here so `mise run sync` installs it. Use the appropriate
   mise backend (`go:`, `npm:`, `dotnet:`, or a registry shortname).

When adding a new language, update all three. If a tool has no mise backend
(e.g., Perl scripts), add it to the brew section in `tasks/sync.sh`.

## On-demand plugin install compatibility

Plugins may be cloned asynchronously via `lua/lib/lazy_ondemand.lua`. When a
lazy-load trigger fires for an uninstalled plugin, the clone runs in the
background and the trigger is **dropped** — the plugin loads only after the
clone finishes.

This means code that runs **outside** a plugin's `config` function must not
assume the plugin module is available. Dangerous patterns:

- `init` functions that call `require("lazy").load()` then `require("<plugin>")`
  — the load may return before the plugin is ready.
- `init` functions that override globals (e.g., `vim.filetype.get_option`,
  `vim.notify`) with a `require("<plugin>")` call inside — the override fires
  before the plugin is cloned.
- `keys` callbacks that expand to `<Cmd>PluginCmd<CR>` — lazy's keys handler
  re-feeds the key, which hits the cmd handler, which errors because the command
  doesn't exist yet. The error is suppressed by `lazy_ondemand.lua` but the
  first invocation is still lost.

**Safe patterns** (no guard needed):

- `require("<plugin>")` inside `config` or `opts` — these run after the plugin
  is loaded.
- `keys` callbacks with inline `function() require("<plugin>").foo() end` — the
  callback only runs on _subsequent_ presses after the plugin is loaded via
  `lazy_ondemand`'s `LazyInstall` handler. The first press is dropped.
- `require("lib.*")` — config-local modules, always available.

**How to guard:**

```lua
-- In init or keys callbacks that may run before the plugin is loaded:
if not package.loaded["<plugin>"] then
  return  -- fall through to default behavior or no-op
end
```

See `oil.lua`, `snacks.lua`, and `ts-context-commentstring.lua` for examples.

## Performance benchmarking

Scripts and sample files live in `perf/`. See `perf/readme.md` for the full
guide.

- `perf/utils/sanity-check.sh` — verify config boots cleanly (headless +
  headful)
- `perf/utils/bench.sh` — `nvim --startuptime` across all cases, reports medians
- `perf/utils/lazy-profile.sh [target]` — capture lazy.nvim per-plugin profile
  (requires a real terminal, not `--headless`)
- `perf/samples/` — self-contained source files as benchmark targets
