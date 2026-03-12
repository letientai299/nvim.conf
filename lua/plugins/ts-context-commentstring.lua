-- Context-aware commenting for mixed-language files (JSX, Vue, HTML+CSS, etc.).
-- Overrides vim.filetype.get_option so native gc/gcc uses treesitter to resolve
-- the correct commentstring at cursor position.
return {
  "JoosepAlviste/nvim-ts-context-commentstring",
  lazy = true,
  opts = {
    enable_autocmd = false,
  },
  init = function()
    local get_option = vim.filetype.get_option
    vim.filetype.get_option = function(filetype, option)
      if option == "commentstring" then
        return require("ts_context_commentstring.internal").calculate_commentstring()
      end
      return get_option(filetype, option)
    end
  end,
}
