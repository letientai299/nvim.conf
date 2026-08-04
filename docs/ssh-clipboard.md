# Clipboard sync over SSH

Editing on a remote host over SSH breaks the system clipboard: a yank to the
`+`/`*` registers hits the _remote_ machine's clipboard tool (or none at all),
not the laptop in front of you. [OSC 52][osc52] closes the gap — it is a
terminal escape sequence that carries clipboard data, so the yank travels up the
SSH pipe and the local terminal emulator writes it to the local clipboard.

[`lib/clipboard.lua`][clip] wires this up. It only acts when a session looks
remote (`SSH_TTY` or `SSH_CONNECTION` present); locally it leaves `g:clipboard`
untouched so the native provider (`pbcopy`/`pbpaste` on macOS) keeps working —
faster, and it supports real read-back.

## Copy vs. paste asymmetry

Copy is symmetric and reliable; paste is not, so the two directions use
different mechanisms.

- **Copy** (`"+y`) routes through the built-in [`vim.ui.clipboard.osc52`][mod]
  writer. The terminal — and tmux, when configured — forwards the sequence to
  the local clipboard.
- **Paste** (`"+p`) returns nvim's own unnamed register instead of issuing an
  OSC 52 read query. The read path blocks for up to 10s waiting on a terminal
  response that tmux and most terminals never send. To pull the _local_
  clipboard into nvim, use the terminal's own paste (bracketed paste on
  Cmd/Ctrl-V) — that path already works without nvim's involvement. This is the
  fallback pattern from `:h clipboard-osc52`.

The clipboard keymaps live in [`lua/keymaps_late.lua`][keys] and are unchanged —
they operate on the `+` register, which this module redirects.

## tmux

OSC 52 must survive the extra tmux layer. tmux only forwards the sequence when
clipboard passthrough is on:

```tmux
set -g set-clipboard on
```

With modern tmux and a terminal whose terminfo advertises the `Ms` capability,
that is all that is needed; tmux both stores the copy in its own buffer and
relays it to the outer terminal.

## Interaction with the disabled `osc52` runtime plugin

Neovim ships `plugin/osc52.lua`, which probes the terminal on `UIEnter` and sets
`g:termfeatures.osc52` so the _default_ provider can auto-pick OSC 52. That
probe is disabled here (see the `disabled_plugins` list in [`init.lua`][init])
to skip the startup query. It is not needed: this module sets `g:clipboard`
explicitly, which bypasses provider auto-detection entirely.

[osc52]: https://github.com/ojroques/vim-oscyank/blob/main/README.md
[mod]: https://neovim.io/doc/user/provider.html#clipboard-osc52
[clip]: ../lua/lib/clipboard.lua
[keys]: ../lua/keymaps_late.lua
[init]: ../init.lua
