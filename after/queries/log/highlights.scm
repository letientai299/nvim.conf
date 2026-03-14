; Adapted from https://github.com/Tudyx/tree-sitter-log/blob/main/queries/highlights.scm
; Remapped Helix captures → Neovim standard captures

(trace) @comment
(debug) @comment.note
(info) @comment.note
(warn) @comment.warning
(error) @comment.error

(year_month_day) @number
(time) @string.special

(string_literal) @string
(number) @number
(constant) @constant.builtin
