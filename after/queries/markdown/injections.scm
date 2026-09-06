;; extends

; Fence info strings carrying a `:`-suffixed renderer modifier, as used by
; dirsv (https://github.com/letientai299/dirsv):
;
;     ```c:line-numbers {5,1-3}
;
; tree-sitter-markdown folds the whole `c:line-numbers` word into (language),
; so the runtime injection resolves a language name that has no parser and the
; block stays unhighlighted. The `{5,1-3}` line range is already outside
; (language) and needs no handling.
;
; Re-inject with the modifier stripped. The #lua-match? guard keeps plain
; fences on the runtime pattern alone — matching both would inject the same
; range twice and parse it twice.
((fenced_code_block
  (info_string
    (language) @injection.language)
  (code_fence_content) @injection.content)
  (#lua-match? @injection.language ":")
  (#gsub! @injection.language "^([^:]*):.*" "%1"))
