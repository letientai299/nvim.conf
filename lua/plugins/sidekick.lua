-- AI CLI integration via sidekick.nvim.
-- Prefix: <Leader>a.
--
-- Only the CLI half is enabled. The other half, NES (next edit suggestions),
-- drives the Copilot language server and needs a Copilot subscription plus an
-- `lsp/copilot.lua` config; without those it would only emit status warnings.

local lazy_require = require("lib.lazy_ondemand").lazy_require

--- Build a key handler calling `sidekick.cli`.
---@param fn string
---@param opts table?
local function cli(fn, opts)
  return function()
    lazy_require("sidekick.cli")[fn](opts)
  end
end

-- stylua: ignore
local keys = {
  { "<Leader>aa", cli("toggle", { focus = true }),                    mode = { "n", "x" }, desc = "Toggle CLI" },
  { "<Leader>ac", cli("toggle", { name = "claude", focus = true }),                        desc = "Toggle Claude" },
  { "<Leader>as", cli("select", { focus = true }),                                         desc = "Select CLI" },
  { "<Leader>ap", cli("prompt"),                                      mode = { "n", "x" }, desc = "Pick prompt" },
  { "<Leader>at", cli("send", { msg = "{this}" }),                    mode = { "n", "x" }, desc = "Send this" },
  { "<Leader>af", cli("send", { msg = "{file}" }),                                         desc = "Send file" },
  { "<Leader>ad", cli("send", { prompt = "diagnostics" }),                                 desc = "Send diagnostics" },
  { "<Leader>ax", cli("close"),                                                            desc = "Close CLI" },
  { "<C-.>",      cli("focus"),                mode = { "n", "x", "i", "t" }, desc = "Focus/blur CLI" },
}

return {
  "folke/sidekick.nvim",
  keys = keys,
  opts = {
    -- No Copilot LSP is configured, so NES has nothing to talk to.
    nes = { enabled = false },
    copilot = { status = { enabled = false } },
    cli = {
      -- Run the agent in a tmux window and attach to it, so the session
      -- survives `:qa` and reattaches on the next Neovim start.
      --
      -- `dump` is how many lines `tmux capture-pane` pulls in when leaving
      -- terminal mode. Claude renders on the alternate screen, so that dump is
      -- the only scrollback there is to scroll and yank; the 2000-line default
      -- runs out quickly. Costs a re-capture and re-render on every entry to
      -- normal mode, so don't raise it much further.
      mux = { enabled = true, backend = "tmux", dump = 10000 },
      picker = "fzf-lua",
      win = {
        layout = "right",
        split = { width = 90 },
        keys = {
          -- <C-q> is the toggleterm prefix (see toggleterm.lua); leave it
          -- alone here. `q` still hides, and <C-\><C-n> still leaves insert.
          hide_ctrl_q = false,
          stopinsert = false,
          -- Swap the upstream defaults. Upstream: <C-.> hides, <C-z> blurs.
          -- Here <C-.> is the single focus toggle (paired with the global
          -- <C-.> above, which `cli.focus` implements as focus/blur), so the
          -- agent stays visible while you jump back to the code. <C-z> takes
          -- over hiding, matching the shell's "background it" meaning.
          hide_ctrl_dot = { "<c-.>", "blur", mode = "nt" },
          hide_ctrl_z = { "<c-z>", "hide", mode = "nt" },
        },
      },
      prompts = {
        -- MUST return a string: sidekick indexes a function prompt's result
        -- without a nil check (cli/context/init.lua), and the prompt picker
        -- renders every prompt, so a nil here breaks <Leader>ap entirely.
        staged = function()
          local diff = vim.fn.system({ "git", "diff", "--cached" })
          if vim.v.shell_error ~= 0 or diff == "" then
            return "No staged changes."
          end
          return "Review these staged changes:\n```diff\n" .. diff .. "```"
        end,
      },
    },
  },
}
