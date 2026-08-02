# CUDA clangd on macOS via a containerized toolchain

Editing `.cu` files on macOS floods clangd with false diagnostics: the host
clangd is Apple clangd (arm64-darwin) and the CUDA toolchain — the
`cuda_runtime.h` family _and_ the Linux libc those headers transitively pull in
— exists only inside the Linux build container. Copying headers to the host does
not work: CUDA's Linux headers include glibc (`<bits/...>`) absent on macOS, so
it needs a full Linux sysroot plus cross-compile flags. Brittle whack-a-mole.

The fix is to run clangd **inside the container** and translate paths at the LSP
boundary. This doc is the reminder for wiring a new CUDA project the same way.

## Two layers

The mechanism is generic and lives here in `nvim.conf`; every container name and
CUDA flag lives in the project. Nothing project-specific leaks into shared
config, so any future remote-toolchain project reuses the same hook.

| Layer                 | Owns                                                         | Where                     |
| --------------------- | ------------------------------------------------------------ | ------------------------- |
| `nvim.conf` (generic) | clangd flag policy; resolve `<root>/.nvim/clangd` if present | [`lsp/clangd.lua`][cl]    |
| Project (specific)    | container name, path mapping, CUDA arch, root pinning        | `.nvim/clangd`, `.clangd` |

[`lsp/clangd.lua`][cl] resolves the binary from `config.root_dir`: a project
executable at `<root>/.nvim/clangd` shadows the system `clangd`. The wrapper
inherits the flag args via `"$@"` — it owns transport, not policy.

## Onboarding a new CUDA project

Add these four files to the project (the `cuda/` subtree, wherever the `.cu`
sources live):

1. **`.nvim/clangd`** (executable wrapper) — forwards clangd into the container
   and maps the host project root to the container mount:

   ```sh
   #!/bin/sh
   exec docker exec -i "$CONTAINER_NAME" clangd \
     --path-mappings="$(git rev-parse --show-toplevel)/cuda=/app" "$@"
   ```

2. **`.clangd`** — a [config file][clangd-config] that doubles as a **root
   marker** (pins the LSP root to the `cuda/` subtree instead of the parent
   repo's `.git`) and supplies CUDA flags so a lone `.cu` indexes without a
   `compile_commands.json`:

   ```yaml
   CompileFlags:
     Add:
       [
         --cuda-path=/usr/local/cuda,
         --cuda-gpu-arch=sm_80,
         --no-cuda-version-check,
       ]
     Remove:
       [
         -forward-unknown-to-host-compiler,
         -rdc=*,
         -gencode*,
         --generate-code*,
         -ccbin*,
         --compiler-options*,
       ]
   ```

   The `Remove:` list strips **nvcc-only** flags that clangd chokes on — needed
   whenever a real `compile_commands.json` (nvcc-generated) is present.

3. **`Dockerfile`** — install `clangd` in the image so it survives rebuilds.

4. **`.nvim.lua`** (project-local config) — export `CONTAINER_NAME` (via `.env`)
   and, if header navigation matters, register the container's CUDA include
   prefixes with [`container_files`][cf] so go-to-definition on
   `/usr/local/cuda-*/include/...` opens read-only phantom buffers.

## Path translation

The container bind-mounts the project at `/app`, so host and container paths
differ. clangd's own `--path-mappings` rewrites the LSP `file://` URIs in both
directions — **framing-safe**, unlike a byte-stream `sed` proxy which would
corrupt `Content-Length` headers. Diagnostics and completion resolve fully; the
mapping round-trips (clangd echoes back the host URI).

## Gotchas

- **nvcc flags must be stripped** from `compile_commands.json` via `.clangd`
  `Remove:`, or clangd reports every command line as an error.
- **clangd emits symlink-resolved, versioned header paths** —
  `/usr/local/cuda-13.3/include/...`, not `/usr/local/cuda/...`. Any
  header-prefix matching (e.g. [`container_files`][cf]) must account for the
  versioned form.
- **Phantom header buffers need `swapfile=false` + `buftype=nowrite`** or Neovim
  raises `E325` trying to write a swapfile for a path that has no host file.
- **Reuse the originating clangd** for headers pulled from the container —
  spawning a second per-header instance loses the path-mapping context.
- **LSP setup is deferred to `VeryLazy`.** Headless tests (`nvim --headless`)
  must start clangd manually; it will not auto-attach.
- **Go-to-definition into `/usr/local/cuda/include/...` only works** if
  [`container_files`][cf] is wired up — bare `--path-mappings` maps the project
  tree only, not the toolchain includes.

## Verification

- In the container: `clangd --check=/app/src/<file>.cu` →
  `All checks completed, 0 errors` (confirms target CPU, CUDA wrapper header,
  libdevice all resolve).
- Full handshake through the wrapper: clangd echoes the **host** URI with 0
  diagnostics post-preamble — proves `--path-mappings` round-trips.

## Where the logic lives

| File                                | Role                                                    |
| ----------------------------------- | ------------------------------------------------------- |
| [`lsp/clangd.lua`][cl]              | Generic: flag policy + resolve project `.nvim/clangd`   |
| [`lua/lib/container_files.lua`][cf] | Generic: open container header paths as phantom buffers |

Project-side files (`.nvim/clangd`, `.clangd`, `.nvim.lua`, `Dockerfile`) live
in the CUDA project, not here.

[cl]: ../lsp/clangd.lua
[cf]: ../lua/lib/container_files.lua
[clangd-config]: https://clangd.llvm.org/config
