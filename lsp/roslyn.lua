local M = {
  filetypes = { "cs" },
  root_markers = { "*.sln", "*.csproj", ".git" },
  settings = {
    ["csharp|inlay_hints"] = {
      csharp_enable_inlay_hints_for_implicit_variable_types = true,
      csharp_enable_inlay_hints_for_lambda_parameter_types = true,
      csharp_enable_inlay_hints_for_types = true,
      dotnet_enable_inlay_hints_for_indexer_parameters = true,
      dotnet_enable_inlay_hints_for_literal_parameters = true,
      dotnet_enable_inlay_hints_for_object_creation_parameters = true,
      dotnet_enable_inlay_hints_for_other_parameters = true,
      dotnet_enable_inlay_hints_for_parameters = true,
      dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
      dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
    },
  },
}

local install_dir = vim.fn.expand("~/.local/share/roslyn-lsp")
local specific = install_dir .. "/content/LanguageServer/neutral/Microsoft.CodeAnalysis.LanguageServer.dll"
local dll = vim.uv.fs_stat(specific) and specific
  or (vim.fn.glob(install_dir .. "/**/Microsoft.CodeAnalysis.LanguageServer.dll", false, true))[1]

if dll then
  M.cmd = {
    "dotnet", dll,
    "--logLevel=Information",
    "--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.log.get_filename()),
    "--stdio",
  }
end

return M
