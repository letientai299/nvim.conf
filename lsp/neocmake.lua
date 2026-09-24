return {
  cmd = { "neocmakelsp", "stdio" },
  filetypes = { "cmake" },
  root_markers = { ".git", "CMakePresets.json", "CMakeLists.txt" },
  init_options = {
    format = { enable = false },
    scan_cmake_in_package = false,
  },
}
