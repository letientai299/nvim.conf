local state_file = vim.fn.stdpath("state") .. "/neovide.json"

local function load_state()
  local f = io.open(state_file, "r")
  if not f then
    return {}
  end
  local ok, data = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and data or {}
end

local function save_state(patch)
  local state = load_state()
  for k, v in pairs(patch) do
    state[k] = v
  end
  local f = io.open(state_file, "w")
  if not f then
    return
  end
  f:write(vim.json.encode(state))
  f:close()
end

return {
  dir = ".",
  name = "neovide",
  cond = vim.g.neovide ~= nil,
  init = function()
    vim.g.neovide_input_macos_option_key_is_meta = true
    vim.g.neovide_hide_mouse_when_typing = true
    vim.g.neovide_cursor_animation_length = 0.1
    vim.g.neovide_cursor_animate_command_line = false
    vim.g.neovide_cursor_vfx_mode = "torpedo"
    vim.g.neovide_remember_window_size = true
    vim.g.neovide_remember_window_position = true

    local state = load_state()

    vim.g.neovide_scale_factor = state.scale_factor or 1.25

    if state.guifont then
      vim.o.guifont = state.guifont
    else
      vim.o.guifont = "JetBrainsMono Nerd Font Mono:style=Light,Regular:h15"
    end

    -- cd to $HOME if cwd is /
    if vim.fn.getcwd() == "/" then
      vim.cmd.cd(vim.env.HOME)
    end

    -- Persist scale factor on exit
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        save_state({ scale_factor = vim.g.neovide_scale_factor })
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

    -- Font picker (monospace fonts only)
    vim.keymap.set("n", "<leader>fp", function()
      local fzf = require("fzf-lua")
      local prev_font = vim.o.guifont

      fzf.fzf_exec("fc-list ':spacing=100' family | sort -u", {
        prompt = "Font> ",
        fzf_opts = { ["--preview-window"] = "hidden" },
        actions = {
          ["default"] = function(selected)
            if not selected or #selected == 0 then
              return
            end
            local font = selected[1] .. ":h15"
            vim.o.guifont = font
            save_state({ guifont = font })
          end,
          ["esc"] = function()
            vim.o.guifont = prev_font
          end,
        },
      })
    end, { desc = "Pick font" })
  end,
}
