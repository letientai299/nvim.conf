local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("cpp", bufnr, {
    -- clangd, clang-format, and clang-tidy are expected on PATH (system LLVM or
    -- CUDA toolkit), so no tool-installer entries. clang-tidy diagnostics are
    -- delivered through clangd via --clang-tidy (lsp/clangd.lua), not a separate
    -- nvim-lint pass, which avoids double diagnostics and a compile_commands.json
    -- requirement that CUDA projects can't satisfy.
    lsp = "clangd",
    formatter_fts = { "c", "cpp", "cuda" },
    formatters = { "clang_format" },
  })
end

return M
