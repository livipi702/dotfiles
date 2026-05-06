local lang = require("utils.lang-config")
local helpers = require("utils.helpers")
local LSP_SERVERS = lang.get_lsp_servers()
local FORMATTERS = lang.get_formatters()
local DAP_ADAPTERS = lang.get_dap_adapters()
local get_linters = lang.get_linters
local LANG_CONFIG = lang.LANG_CONFIG

return {
	{
		"williamboman/mason.nvim",
		cmd = { "Mason", "MasonInstall", "MasonUpdate" },
		config = function()
			require("mason").setup()
		end,
	},

	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = LSP_SERVERS,
				automatic_enable = false,
			})
		end,
	},

	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = { "williamboman/mason.nvim" },
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
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"hrsh7th/cmp-nvim-lsp",
			"b0o/schemastore.nvim",
		},
		config = function()
			local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
			if not ok_cmp then
				vim.notify("Failed to load cmp_nvim_lsp: " .. tostring(cmp_lsp), vim.log.levels.WARN)
				return
			end
			local capabilities = cmp_lsp.default_capabilities()

			-- ══════════════════════════════════════════════════════
			-- CAPABILITIES
			-- ══════════════════════════════════════════════════════
			vim.lsp.config("*", { capabilities = capabilities })

			-- ══════════════════════════════════════════════════════
			-- SERVER CONFIGS
			-- ══════════════════════════════════════════════════════
			local server_cfgs = {}
			for _, lang_cfg in pairs(LANG_CONFIG) do
				if lang_cfg.lsp and lang_cfg.lsp_opts and not server_cfgs[lang_cfg.lsp] then
					local opts = vim.deepcopy(lang_cfg.lsp_opts)
					if type(opts.settings) == "function" then
						opts.settings = opts.settings()
					end
					server_cfgs[lang_cfg.lsp] = opts
				end
			end

			-- ══════════════════════════════════════════════════════
			-- ROOT MARKERS for lang-config sourced servers
			-- ══════════════════════════════════════════════════════
			local root_markers_by_server = {
				clangd = { ".clangd", ".clang-tidy", ".clang-format", "compile_commands.json", ".git" },
				gopls = { "go.mod", ".git" },
				ts_ls = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
				jsonls = { ".git" },
				html = { ".git" },
				cssls = { ".git" },
				yamlls = { ".git" },
				sqlls = { ".git" },
			}
			for srv, markers in pairs(root_markers_by_server) do
				if server_cfgs[srv] and not server_cfgs[srv].root_markers then
					server_cfgs[srv].root_markers = markers
				end
			end

			-- ══════════════════════════════════════════════════════
			-- PYTHON
			-- ══════════════════════════════════════════════════════
			server_cfgs["basedpyright"] = {
				filetypes = { "python" },
				root_markers = {
					"pyrightconfig.json",
					"pyproject.toml",
					"setup.py",
					"setup.cfg",
					"requirements.txt",
					".git",
				},
				workspace_required = false,
				settings = {
					python = {
						analysis = {
							typeCheckingMode = "basic",
							autoImportCompletions = true,
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
							diagnosticMode = "openFilesOnly",
							inlayHints = {
								variableTypes = true,
								functionReturnTypes = true,
								callArgumentNames = true,
								pytestParameters = true,
							},
							diagnosticSeverityOverrides = {
								reportUnusedImport = "information",
								reportUnusedVariable = "information",
								reportMissingTypeStubs = "none",
							},
						},
					},
				},
			}

			-- ══════════════════════════════════════════════════════
			-- EMMET
			-- ══════════════════════════════════════════════════════
			server_cfgs["emmet_ls"] = {
				filetypes = {
					"html",
					"css",
					"javascriptreact",
					"typescriptreact",
					"ejs",
				},
			}

			-- ══════════════════════════════════════════════════════
			-- TAILWIND CSS
			-- ══════════════════════════════════════════════════════
			server_cfgs["tailwindcss"] = {
				filetypes = {
					"html",
					"css",
					"javascriptreact",
					"typescriptreact",
					"ejs",
				},
				root_markers = {
					{
						"tailwind.config.js",
						"tailwind.config.ts",
						"tailwind.config.cjs",
						"tailwind.config.mjs",
						"tailwind.config.mts",
					},
					".git",
				},
				settings = {
					tailwindCSS = {
						classAttributes = {
							"class",
							"className",
							"class:list",
							"classList",
							"ngClass",
						},
						includeLanguages = {
							ejs = "html",
							html = "html",
							javascript = "javascript",
							javascriptreact = "javascript",
							typescript = "typescript",
							typescriptreact = "typescript",
						},
						lint = {
							cssConflict = "warning",
							invalidApply = "error",
							invalidScreen = "error",
							invalidVariant = "error",
							recommendedVariantOrder = "warning",
						},
						validate = true,
					},
				},
			}

			-- ══════════════════════════════════════════════════════
			-- APPLY CONFIGS
			-- ══════════════════════════════════════════════════════
			for server, opts in pairs(server_cfgs) do
				vim.lsp.config(server, opts)
			end

			-- ══════════════════════════════════════════════════════
			-- LSP ENABLE
			-- ══════════════════════════════════════════════════════
			local all_servers = {}
			local seen = {}

			for server, _ in pairs(server_cfgs) do
				if not seen[server] then
					seen[server] = true
					table.insert(all_servers, server)
				end
			end

			for _, server in ipairs(LSP_SERVERS) do
				if not seen[server] then
					seen[server] = true
					table.insert(all_servers, server)
				end
			end

			-- ══════════════════════════════════════════════════════
			-- LSP STARTUP
			-- ══════════════════════════════════════════════════════
			if #all_servers > 0 then
				for _, server in ipairs(all_servers) do
					local ok, err = pcall(vim.lsp.enable, server)
					if not ok then
						vim.notify(
							"Failed to enable LSP server '" .. server .. "': " .. tostring(err),
							vim.log.levels.WARN
						)
					end
				end
				-- LSP servers enabled silently
			end
		end,
	},

	{
		"mfussenegger/nvim-jdtls",
		ft = "java",
		dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
	},
}
