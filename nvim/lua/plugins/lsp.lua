local lang = require("utils.lang-config")
local LSP_SERVERS = lang.get_lsp_servers()
local FORMATTERS = lang.get_formatters()
local DAP_ADAPTERS = lang.get_dap_adapters()
local get_linters = lang.get_linters

return {
	{
		"mason-org/mason.nvim",
		cmd = { "Mason", "MasonInstall", "MasonUpdate" },
		opts = {},
	},

	{
		"mason-org/mason-lspconfig.nvim",
		dependencies = { "mason-org/mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = LSP_SERVERS,
				automatic_enable = false,
			})
		end,
	},

	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = { "mason-org/mason.nvim" },
		config = function()
			local tools = {}
			vim.list_extend(tools, FORMATTERS)
			vim.list_extend(tools, DAP_ADAPTERS)
			vim.list_extend(tools, get_linters())
			vim.list_extend(tools, { "java-test" })
			require("mason-tool-installer").setup({
				ensure_installed = tools,
			})
		end,
	},

	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"mason-org/mason.nvim",
			"mason-org/mason-lspconfig.nvim",
			"hrsh7th/cmp-nvim-lsp",
			"b0o/schemastore.nvim",
		},
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()
			require("config.lsp").setup(capabilities)
		end,
	},

	{
		"mfussenegger/nvim-jdtls",
		ft = "java",
		dependencies = { "mason-org/mason.nvim", "mfussenegger/nvim-dap" },
	},
}
