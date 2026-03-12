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
