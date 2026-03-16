# Performance benchmarking

Scripts and sample files for profiling Neovim startup with this config.

## Quick start

```sh
# Verify config boots cleanly (headless + headful)
bash perf/utils/sanity-check.sh

# Run startup benchmarks (all sample files)
bash perf/utils/bench.sh

# Capture lazy.nvim per-plugin profile
bash perf/utils/lazy-profile.sh
bash perf/utils/lazy-profile.sh perf/samples/app.tsx -o /tmp/profile.txt
```

## Scripts

All scripts live in `perf/utils/` and source `common.sh` for shared setup
(isolated XDG dirs, lockfile copy, cleanup).

### `sanity-check.sh`

Two rounds: headless boot (fast, catches init errors) then headful boot (UIEnter
fires, lazy.nvim loads, colorscheme applies). Both rounds test bare nvim, a
directory, and each file in `perf/samples/`. Run this before every benchmark
batch — if any case fails, fix correctness before trusting timings.

The headful round quits via a `LazyVimStarted` autocmd sourced with `-S`. Plain
`+qa` races with UIEnter — lazy.nvim hooks into UIEnter and blocks the quit.
Headful round requires a real terminal (run directly or via tmux, not from a
non-interactive shell).

### `bench.sh`

Two modes, selected automatically:

- **hyperfine** (preferred) — wall-clock timing with warmup and statistical
  output. Requires [hyperfine][hf] on `$PATH`. Uses `--shell=none` (`-N`) so
  hyperfine execs the binary directly without a shell wrapper. Cases are grouped
  into two invocations (baselines + sample files) that each produce a comparison
  table with relative speeds.
- **manual** — fallback when hyperfine isn't available. Runs each case N times
  (default 20, override via `$BENCH_RUNS`), parses `--startuptime` logs, reports
  min/median/max.

Both modes include a `nvim -u NONE --headless` floor baseline. Normal cases run
**without** `--headless` to match real startup (UIEnter fires, lazy.nvim loads).

### `lazy-profile.sh [target] [-o output]`

Captures [lazy.nvim][lazy]'s profile tree and timing stats. Runs nvim
non-headlessly (UIEnter must fire). A terminal window opens briefly. Output goes
to stdout unless `-o` specifies a file.

Uses `lazy.core.util._profiles` (internal API) for the profile tree. If
lazy.nvim removes this field, stats still print — only the tree is lost.

### `common.sh`

Sourced by the other scripts. Provides:

- `setup_isolated_env [tree]` — mktemp XDG dirs, symlink config, copy lockfile,
  copy exrc trust data (so headful nvim doesn't prompt for `.nvim.lua`), copy
  mise trusted-configs (so the mise shim doesn't reject configs in the isolated
  state dir)
- `resolve_nvim` — resolves the real nvim binary via `mise which nvim`,
  bypassing the mise shim (~40ms overhead per invocation). Caches the path in
  `$_PERF_NVIM`. Falls back to `nvim` if mise isn't available.
- `cleanup_env` — rm temp dirs
- `extract_startup_ms <log>` — awk extraction from `--startuptime` output
- `require_cmd <cmd>` — exit if not found
- `REPO_ROOT` — resolved from script location

## Sample files

`perf/samples/` contains synthetic source files chosen to exercise the heaviest
lang-module setups (LSP servers, formatters, linters). Each is 50–200 lines.

| Sample           | Filetype   | Lang module | Key tools triggered                       |
| ---------------- | ---------- | ----------- | ----------------------------------------- |
| `app.tsx`        | tsx        | js_ts       | vtsls, cssmodules-ls, prettier, biomejs   |
| `router.ts`      | typescript | js_ts       | vtsls, cssmodules-ls, prettier, biomejs   |
| `index.html`     | html       | html        | html-ls, prettier                         |
| `style.css`      | css        | css         | css-ls, prettier, biomejs                 |
| `Component.vue`  | vue        | vue         | vue-language-server, prettier, biomejs    |
| `models.go`      | go         | go          | gopls, goimports, golangci-lint           |
| `parser.rs`      | rust       | rust        | rust-analyzer                             |
| `pipeline.py`    | python     | python      | basedpyright, ruff                        |
| `config.lua`     | lua        | lua         | lua-language-server, stylua               |
| `migrations.sql` | sql        | sql         | sqls, sql-formatter                       |
| `document.md`    | markdown   | —           | Treesitter only (no LSP)                  |
| `compose.yaml`   | yaml       | —           | Treesitter only (docker-compose filetype) |
| `Dockerfile`     | dockerfile | docker      | dockerls, hadolint                        |
| `Example.java`   | java       | java        | jdtls                                     |

## Verifying an improvement

1. `sanity-check.sh` passes (both rounds)
2. Candidate improves the median in relevant cases
3. Improvement survives a rerun with the same harness
4. `--startuptime` trace confirms the suspected work moved or disappeared
5. Visual regression — rendering is identical before and after
6. Changed behavior still works (e.g., deferred commands still available)

[hf]: https://github.com/sharkdp/hyperfine
[lazy]: https://github.com/folke/lazy.nvim
