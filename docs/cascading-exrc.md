# Cascading project `.nvim.lua`

Per-project configuration files form an inheritance chain so monorepo
subdirectories share a common base config.

## Why

Neovim's built-in `exrc` sources `.nvim.lua` from the working directory, but
each file is independent. In a monorepo with nested services, shared settings
(web-grep context, LSP overrides, keymaps) would need to be duplicated in every
subdirectory's `.nvim.lua`.

## How it works

1. `vim.opt.exrc = true` in [`lua/options.lua`][options] enables native
   `.nvim.lua` discovery.
2. [`lua/lib/exrc.lua`][exrc] adds two functions:
   - `source_parent()` — walks up the directory tree looking for the nearest
     `.nvim.lua` above the current working directory. Stops at the filesystem
     root.
   - `mark(path)` — records a path as already sourced so `source_parent()` won't
     load it again.
3. A child `.nvim.lua` calls `require("lib.exrc").source_parent()` at the top to
   inherit the parent's config before adding its own overrides.

A module-level `sourced` table guards against double-sourcing. When Neovim's
built-in exrc loads a file first, `mark()` keeps the table in sync.

## Example hierarchy

```
~/projects/
  .nvim.lua                     -- shared web-grep context
  monorepo/
    .nvim.lua                   -- calls source_parent(), adds LSP overrides
    services/
      backend/
        .nvim.lua               -- calls source_parent(), gets monorepo + root
```

## Keymaps

| Key          | Action                                               |
| ------------ | ---------------------------------------------------- |
| `<Leader>vp` | Edit the nearest `.nvim.lua` (or create at git root) |
| `<Leader>va` | Reload local and project configs                     |
| `<Leader>vl` | Edit machine-local config (`lua/local/local.lua`)    |

Defined in [`lua/keymaps_late.lua`][keymaps-late].

## Where the logic lives

- [`lua/lib/exrc.lua`][exrc] — `source_parent()` and `mark()`
- [`lua/options.lua`][options] — `exrc` enable
- [`lua/keymaps_late.lua`][keymaps-late] — discovery helper and keymaps
- [`lua/plugins/fzf-lua.lua`][fzf-lua] — includes `.nvim.lua` in the file picker
  despite gitignore

## Trade-offs

- Inheritance is parent-first, single-chain. There is no merge or override
  semantics beyond what Lua code in each file implements.
- `source_parent()` uses `vim.cmd.source`, so parent files run in the same
  global scope as if sourced directly. Side effects accumulate.
- The `sourced` table is in-memory only. Reloading via `<Leader>va` bypasses the
  guard intentionally.

[exrc]: ../lua/lib/exrc.lua
[fzf-lua]: ../lua/plugins/fzf-lua.lua
[keymaps-late]: ../lua/keymaps_late.lua
[options]: ../lua/options.lua
