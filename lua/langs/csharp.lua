local install_dir = vim.fn.expand("~/.local/share/roslyn-lsp")

vim.lsp.enable("roslyn")

local function find_dll()
  local specific = install_dir .. "/content/LanguageServer/neutral/Microsoft.CodeAnalysis.LanguageServer.dll"
  if vim.uv.fs_stat(specific) then return specific end

  local m = vim.fn.glob(install_dir .. "/**/Microsoft.CodeAnalysis.LanguageServer.dll", false, true)
  return m[1]
end

--- Downloads the neutral Roslyn LSP NuGet package to ~/.local/share/roslyn-lsp.
--- Requires `dotnet` on PATH (needed for C# development anyway).
local function roslyn_install()
  local feed = "https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/flat2"
  local pkg = "microsoft.codeanalysis.languageserver.neutral"

  vim.notify("Fetching Roslyn versions…")

  vim.system({ "curl", "-sL", feed .. "/" .. pkg .. "/index.json" }, { text = true }, function(r)
    if r.code ~= 0 then
      return vim.schedule(function()
        vim.notify("Failed to fetch Roslyn versions", vim.log.levels.ERROR)
      end)
    end

    local versions = vim.json.decode(r.stdout).versions
    local ver = versions[#versions]
    local url = ("%s/%s/%s/%s.%s.nupkg"):format(feed, pkg, ver, pkg, ver)
    local tmp = os.tmpname() .. ".nupkg"

    vim.schedule(function() vim.notify("Downloading Roslyn " .. ver .. "…") end)

    vim.system({ "curl", "-sL", "-o", tmp, url }, {}, function(dl)
      if dl.code ~= 0 then
        return vim.schedule(function()
          vim.notify("Roslyn download failed", vim.log.levels.ERROR)
        end)
      end

      local extract = ("rm -rf '%s' && mkdir -p '%s' && unzip -qo '%s' -d '%s' && rm '%s'"):format(
        install_dir, install_dir, tmp, install_dir, tmp
      )
      vim.system({ "sh", "-c", extract }, {}, function(uz)
        if uz.code ~= 0 then
          return vim.schedule(function()
            vim.notify("Roslyn extraction failed", vim.log.levels.ERROR)
          end)
        end

        vim.schedule(function()
          local dll = find_dll()
          if not dll then
            vim.notify("Roslyn DLL not found after extraction", vim.log.levels.ERROR)
            return
          end
          vim.lsp.config("roslyn", {
            cmd = {
              "dotnet", dll,
              "--logLevel=Information",
              "--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.log.get_filename()),
              "--stdio",
            },
          })
          vim.lsp.enable("roslyn")
          vim.notify("Roslyn " .. ver .. " installed and activated.")
        end)
      end)
    end)
  end)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "cs",
  group = vim.api.nvim_create_augroup("roslyn_install", { clear = true }),
  callback = function(ev)
    vim.api.nvim_buf_create_user_command(ev.buf, "RoslynInstall", roslyn_install, {
      desc = "Install Roslyn language server",
    })
  end,
})

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        cs = { "csharpier" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "c_sharp" } },
  },
}
