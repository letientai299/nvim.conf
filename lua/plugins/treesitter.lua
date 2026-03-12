return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  event = "VeryLazy",
  opts = {
    ensure_installed = { "query", "vim", "vimdoc" },
  },
  init = function()
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        local buf = vim.api.nvim_get_current_buf()
        if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) == "" then
          return
        end

        vim.schedule(function()
          require("lazy").load({ plugins = { "nvim-treesitter" } })
        end)
      end,
    })
  end,
  config = function(_, opts)
    local group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true })
    local ts = require("nvim-treesitter")

    ts.setup({})
    require("lib.lang_registry").activate_treesitter()

    vim.schedule(function()
      ts.install(opts.ensure_installed, { summary = false })
    end)

    local current = vim.api.nvim_get_current_buf()
    if vim.bo[current].buftype == "" and vim.api.nvim_buf_get_name(current) ~= "" then
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(current) then
          pcall(vim.treesitter.start, current)
        end
      end)
    end

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function()
        local buf = vim.api.nvim_get_current_buf()
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
            pcall(vim.treesitter.start, buf)
          end
        end)
      end,
    })

    vim.api.nvim_create_autocmd("OptionSet", {
      group = group,
      pattern = "foldmethod",
      callback = function()
        if vim.wo.foldmethod ~= "expr" or vim.wo.foldexpr ~= "" then
          return
        end

        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
      end,
    })
  end,
}
