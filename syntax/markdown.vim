" Treesitter handles highlighting — skip the runtime syntax cascade
" (html → css → yaml → javascript → vb → xml → dtd).
if has('nvim-0.5')
  let b:current_syntax = 'markdown'
  finish
endif
