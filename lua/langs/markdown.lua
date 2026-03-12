vim.lsp.enable("marksman")

return {
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				markdown = { "prettierd", "prettier", stop_after_first = true },
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				markdown = { "markdownlint-cli2" },
			},
		},
	},
	{
		"nvim-treesitter/nvim-treesitter",
		opts = { ensure_installed = { "markdown", "markdown_inline" } },
	},
}
