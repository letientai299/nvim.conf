return {
  "Julian/lean.nvim",
  lazy = true,
  init = function()
    vim.g.lean_config = {
      mappings = true,
      lsp = { enable = false },
      infoview = { autoopen = not vim.g.started_by_firenvim },
    }
  end,
  config = function()
    if vim.g.started_by_firenvim then
      return
    end

    local root_dir = vim.lsp.config.leanls.root_dir
    vim.lsp.config("leanls", {
      root_dir = function(buf, on_dir)
        -- Retry after the tool installer finishes.
        if vim.fn.executable("lean") == 0 then
          return
        end
        root_dir(buf, function(root)
          on_dir(root or vim.fs.dirname(vim.api.nvim_buf_get_name(buf)))
        end)
      end,
    })
    require("lib.lsp").enable("leanls")
  end,
}
