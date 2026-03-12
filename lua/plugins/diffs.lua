-- diffs.nvim adds treesitter syntax highlighting to inline diff hunks
-- (Neogit status buffer, fugitive, etc.). diffview.nvim handles standalone
-- side-by-side diffs — they serve different roles.
--
-- diffs.nvim docs list diffview.nvim as a potential conflict since both touch
-- diff highlighting. In practice they shouldn't clash because diffview runs
-- in its own tabpage. If issues arise, remove this plugin first.
--
-- https://github.com/barrettruth/diffs.nvim
-- https://github.com/NeogitOrg/neogit/discussions/1187
return {
  "barrettruth/diffs.nvim",
  lazy = true,
  init = function()
    vim.g.diffs = {
      integrations = {
        neogit = true,
      },
    }
  end,
}
