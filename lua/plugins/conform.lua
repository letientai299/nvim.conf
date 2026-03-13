return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  ---@module "conform"
  ---@type conform.setupOpts
  opts = function()
    return {
      formatters = {
        prettier = {
          prepend_args = { "--ignore-unknown", "--ignore-path", "/dev/null" },
          -- Override cwd to include .ts config files (prettier 3.x) and also
          -- check package.json for a "prettier" key. Uses callback form of
          -- vim.fs.root so it returns the nearest match, not the first marker.
          -- https://prettier.io/docs/configuration
          cwd = function(_, ctx)
            local config_names = {
              [".prettierrc"] = true,
              [".prettierrc.json"] = true,
              [".prettierrc.yml"] = true,
              [".prettierrc.yaml"] = true,
              [".prettierrc.json5"] = true,
              [".prettierrc.js"] = true,
              [".prettierrc.cjs"] = true,
              [".prettierrc.mjs"] = true,
              [".prettierrc.ts"] = true,
              [".prettierrc.toml"] = true,
              ["prettier.config.js"] = true,
              ["prettier.config.cjs"] = true,
              ["prettier.config.mjs"] = true,
              ["prettier.config.ts"] = true,
            }
            return vim.fs.root(ctx.dirname, function(name, path)
              if config_names[name] then
                return true
              end
              if name == "package.json" then
                local f = io.open(path .. "/" .. name, "r")
                if not f then
                  return false
                end
                local ok, json = pcall(vim.json.decode, f:read("*a"))
                f:close()
                return ok and json and json.prettier ~= nil
              end
              return false
            end)
          end,
        },
        injected = { options = { ignore_errors = true } },
      },
      formatters_by_ft = {
        ["*"] = { "trim_whitespace", "trim_newlines", "injected" },
      },
      default_format_opts = {
        lsp_format = "fallback",
      },
      format_on_save = {
        timeout_ms = 500,
      },
    }
  end,
  init = function()
    vim.o.formatexpr =
      "v:lua.require'conform'.formatexpr({timeout_ms=500, lsp_format='fallback'})"
  end,
  config = function(_, opts)
    require("lib.lang_registry").activate_conform(opts)
    require("conform").setup(opts)
    require("lib.lang_registry").install_lazy_formatters()
  end,
}
