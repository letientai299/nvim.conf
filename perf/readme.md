# Performance benchmarking

Scripts and sample files for profiling Neovim startup with this config.

## Quick start

From a terminal (or tmux session — see
[Running from a non-interactive shell](#running-from-a-non-interactive-shell)):

```sh
# Verify config boots cleanly (headless + headful)
bash perf/utils/sanity-check.sh

# Run startup benchmarks (all sample files)
bash perf/utils/bench.sh

# Capture lazy.nvim per-plugin profile
bash perf/utils/lazy-profile.sh
bash perf/utils/lazy-profile.sh perf/samples/app.tsx -o /tmp/profile.txt
```

## Terminal requirement

All three scripts run nvim **headfully** (without `--headless`) for at least
some cases. Headful nvim needs a real terminal — `UIEnter` fires on terminal
attach, which triggers [lazy.nvim][lazy] plugin loading and colorscheme
application. Running from a pipe, cron, or CI without a terminal will hang or
produce wrong results.

If you're in a regular terminal (iTerm, Alacritty, the macOS Terminal app), the
scripts work directly. A brief nvim window flashes for each headful case — this
is expected.

## Running from a non-interactive shell

AI agents, SSH pipes, and CI runners don't have a terminal attached. Use tmux to
provide one. The pattern:

```sh
# 1. Start the script inside a detached tmux session.
#    tmux allocates a pty, so headful nvim works normally.
tmux new-session -d -s bench \
  "bash perf/utils/bench.sh 2>&1 | tee /tmp/bench.txt; \
   tmux wait-for -S bench-done"

# 2. Block until the script finishes.
tmux wait-for bench-done

# 3. Read the captured output.
cat /tmp/bench.txt

# 4. Clean up.
tmux kill-session -t bench 2>/dev/null
```

The same pattern works for `sanity-check.sh` and `lazy-profile.sh`. Key points:

- `tmux new-session -d` creates a detached session with a real pty.
- `tmux wait-for -S` / `tmux wait-for` is a clean signal — no polling.
- Pipe through `tee` to capture output for later inspection.
- Always kill the session afterward to avoid leaks.

To reduce bench runtime during development, set `BENCH_RUNS`:

```sh
tmux new-session -d -s bench \
  "BENCH_RUNS=5 bash perf/utils/bench.sh 2>&1 | tee /tmp/bench.txt; \
   tmux wait-for -S bench-done"
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
