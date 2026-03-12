-- Interactive text alignment (replaces vim-easy-align)
--
-- Usage:
--   ga{motion} or visual ga  — align (no preview)
--   gA{motion} or visual gA  — align with live preview (recommended while learning)
--
-- After triggering, type a split character (, = : | etc.) to align on it.
-- All occurrences are aligned by default (unlike vim-easy-align which did first only).
--
-- Interactive modifiers (type after ga/gA + motion):
--   s  — enter Lua pattern to split on (use Lua patterns, not Vim regex:
--         %s+ not \s\+, %. not \.)
--   j  — pick justification: l(eft), c(enter), r(ight), n(one)
--   m  — set merge delimiter (string between aligned parts)
--   f  — filter rows by Lua expression
--   t  — trim whitespace from parts
--   p  — pair neighboring parts
--   <BS> — undo last modifier step
return {
  "nvim-mini/mini.align",
  keys = { { "ga", mode = { "n", "x" } }, { "gA", mode = { "n", "x" } } },
  opts = {},
}
