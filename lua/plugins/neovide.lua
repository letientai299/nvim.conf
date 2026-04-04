return {
  dir = ".",
  name = "neovide",
  cond = vim.g.neovide ~= nil,
  init = function()
    local font = require("store-guifont").new("neovide")

    vim.g.neovide_input_macos_option_key_is_meta = "both"
    vim.g.neovide_hide_mouse_when_typing = true
    vim.g.neovide_cursor_animation_length = 0.1
    vim.g.neovide_cursor_animate_command_line = false
    vim.g.neovide_cursor_vfx_mode = "torpedo"
    vim.g.neovide_remember_window_size = true
    vim.g.neovide_remember_window_position = true
    vim.g.neovide_show_border = false
    vim.g.neovide_scroll_animation_length = 0.1
    vim.g.neovide_floating_shadow = true
    vim.g.neovide_floating_corner_radius = 0.3

    font:apply("JetBrainsMono Nerd Font Mono:style=Light,Regular:h15")
    font:apply_scale({ var = "neovide_scale_factor", default = 1.25 })

    -- cd to ~/temp if launched from $HOME (Neovide default)
    if vim.fn.getcwd() == vim.env.HOME then
      vim.cmd.cd(vim.env.HOME .. "/temp")
    end

    -- Clipboard: Cmd+C / Cmd+V
    vim.keymap.set("v", "<D-c>", '"+y', { desc = "Copy" })
    vim.keymap.set({ "n", "v" }, "<D-v>", '"+p', { desc = "Paste" })
    vim.keymap.set({ "i", "c" }, "<D-v>", "<C-r>+", { desc = "Paste" })

    font:map_scale_zoom()
    font:map_pick()
  end,
}
