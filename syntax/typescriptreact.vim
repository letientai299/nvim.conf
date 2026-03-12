" Treesitter handles highlighting — skip the runtime syntax script.
if has('nvim-0.5')
  let b:current_syntax = 'typescriptreact'
  finish
endif
