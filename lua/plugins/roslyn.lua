return {
  "seblyng/roslyn.nvim",
  ft = { "cs", "razor" },
  opts = {
    -- broad_search recursively walks the git root looking for solutions before
    -- first paint. On real C# repos that blocks UI startup noticeably.
    broad_search = false,
  },
}
