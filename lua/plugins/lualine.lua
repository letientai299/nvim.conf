return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	opts = {
		options = {
			globalstatus = true,
			section_separators = "",
			component_separators = "",
		},
		tabline = {
			lualine_a = { { "buffers", show_filename_only = true, mode = 2 } },
			lualine_z = { "tabs" },
		},
		sections = {
			lualine_a = { "mode" },
			lualine_b = { "branch" },
			lualine_c = { { "filename", path = 1 } },
			lualine_x = { "diagnostics" },
			lualine_y = { "filetype" },
			lualine_z = { "location" },
		},
	},
}
