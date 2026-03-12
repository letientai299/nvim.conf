return {
  dir = ".",
  name = "neovide",
  cond = vim.g.neovide ~= nil,
  init = function()
    local guifont = require("lib.guifont")
    local store = guifont.state("neovide")

    vim.g.neovide_input_macos_option_key_is_meta = true
    vim.g.neovide_hide_mouse_when_typing = true
    vim.g.neovide_cursor_animation_length = 0.1
    vim.g.neovide_cursor_animate_command_line = false
    vim.g.neovide_cursor_vfx_mode = "torpedo"
    vim.g.neovide_remember_window_size = true
    vim.g.neovide_remember_window_position = true

    local state = store.load()
    vim.g.neovide_scale_factor = state.scale_factor or 1.25

    guifont.apply(store, "JetBrainsMono Nerd Font Mono:style=Light,Regular:h15")

    -- cd to $HOME if cwd is /
    if vim.fn.getcwd() == "/" then
      vim.cmd.cd(vim.env.HOME)
    end

    -- Persist scale factor on exit
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        store.save({ scale_factor = vim.g.neovide_scale_factor })
      end,
    })

    -- Clipboard: Cmd+C / Cmd+V
    vim.keymap.set("v", "<D-c>", '"+y', { desc = "Copy" })
    vim.keymap.set({ "n", "v" }, "<D-v>", '"+p', { desc = "Paste" })
    vim.keymap.set({ "i", "c" }, "<D-v>", "<C-r>+", { desc = "Paste" })

    -- Zoom: Cmd+= / Cmd+-
    vim.keymap.set("n", "<D-=>", function()
      vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * 1.1
    end, { desc = "Zoom in" })
    vim.keymap.set("n", "<D-->", function()
      vim.g.neovide_scale_factor = vim.g.neovide_scale_factor / 1.1
    end, { desc = "Zoom out" })

    guifont.map_picker(store)
  end,
}
