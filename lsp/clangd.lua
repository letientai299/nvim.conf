return {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--header-insertion=iwyu",
    "--completion-style=detailed",
  },
  filetypes = { "c", "cpp", "cuda", "objc", "objcpp" },
  root_markers = {
    ".clangd",
    "compile_commands.json",
    "compile_flags.txt",
    ".clang-format",
    ".git",
  },
}
