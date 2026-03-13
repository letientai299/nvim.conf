# Nvim Config

Pure Lua Neovim config built on [lazy.nvim][lazy].

## Deploy

Prerequisites: a C compiler (Xcode CLT), `git`, `curl`, [jq][], [mise][].

```sh
# Clone into the standard nvim config path
git clone git@github.com: ~/.config/nvim https://github.com/letientai299/nvim.conf

# Install all tools globally
cd ~/.config/nvim
mise run sync
```

`mise run sync` reads `tools.txt` and installs everything via mise. Brew-only
packages (`pgformatter`) are handled separately in the same task. To add a new
tool, append it to `tools.txt` and re-run `mise run sync`.

Neovim bootstraps [lazy.nvim][lazy] on first launch — open `nvim` and let it
finish installing plugins.

[jq]: https://jqlang.github.io/jq/
[lazy]: https://github.com/folke/lazy.nvim
[mini-surround]: https://github.com/nvim-mini/mini.surround
[mise]: https://mise.jdx.dev/
