
local lang = require("utils.lang-config")
local helpers = require("utils.helpers")
local LSP_SERVERS = lang.get_lsp_servers()
local FORMATTERS = lang.get_formatters()
local DAP_ADAPTERS = lang.get_dap_adapters()
local get_linters = lang.get_linters
local get_jdtls_bundles = helpers.get_jdtls_bundles
local is_dir = helpers.is_dir
local home_dir = helpers.home_dir
local CURRENT_OS = helpers.CURRENT_OS
local LANG_CONFIG = lang.LANG_CONFIG

return {
	{
		"williamboman/mason.nvim",
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
			"folke/lazydev.nvim",
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
					tailwind = {
						classAttributes = {
							"class",
							"className",
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
		config = function()
			local function setup_jdtls()
				local ok_jdtls, jdtls = pcall(require, "jdtls")
				if not ok_jdtls then
					vim.notify("nvim-jdtls not available: " .. tostring(jdtls), vim.log.levels.WARN)
					return
				end

				local ok_reg, mason_registry = pcall(require, "mason-registry")
				if not ok_reg then
					vim.notify("mason-registry not available: " .. tostring(mason_registry), vim.log.levels.WARN)
					return
				end

				if not mason_registry.is_installed("jdtls") then
					vim.notify("jdtls not installed via Mason. Run :MasonInstall jdtls", vim.log.levels.WARN)
					return
				end

				local jdtls_path = mason_registry.get_package("jdtls"):get_install_path()
				local launcher_jar = vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar")
				if launcher_jar == "" then
					vim.notify("jdtls launcher jar not found at: " .. jdtls_path .. "/plugins/", vim.log.levels.WARN)
					return
				end

				local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
				local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name
				vim.fn.mkdir(workspace_dir, "p")

				local os_config
				if CURRENT_OS == "mac" then
					if is_dir(jdtls_path .. "/config_mac_arm") then
						os_config = "config_mac_arm"
					elseif is_dir(jdtls_path .. "/config_mac") then
						os_config = "config_mac"
					else
						os_config = "config_linux"
					end
				elseif CURRENT_OS == "win" then
					os_config = "config_win"
				else
					os_config = "config_linux"
				end

				local config_path = jdtls_path .. "/" .. os_config
				if not is_dir(config_path) then
					config_path = jdtls_path .. "/config_linux"
				end

				local bundles = get_jdtls_bundles()
				local ok_cmp2, cmp_lsp2 = pcall(require, "cmp_nvim_lsp")
				local caps = ok_cmp2 and cmp_lsp2.default_capabilities() or {}

				local jdtls_config = {
					cmd = {
						"java",
						"-Declipse.application=org.eclipse.jdt.ls.core.id1",
						"-Dosgi.bundles.defaultStartLevel=4",
						"-Declipse.product=org.eclipse.jdt.ls.core.product",
						"-Dlog.protocol=true",
						"-Dlog.level=ALL",
						"-Xmx2g",
						"--add-modules=ALL-SYSTEM",
						"--add-opens",
						"java.base/java.util=ALL-UNNAMED",
						"--add-opens",
						"java.base/java.lang=ALL-UNNAMED",
						"-jar",
						launcher_jar,
						"-configuration",
						config_path,
						"-data",
						workspace_dir,
					},
					root_dir = require("jdtls.setup").find_root({
						".git",
						"mvnw",
						"gradlew",
						"pom.xml",
						"build.gradle",
						"build.gradle.kts",
					}) or vim.fn.getcwd(),
					capabilities = caps,
					settings = {
						java = {
							signatureHelp = { enabled = true },
							completion = {
								favoriteStaticMembers = {
									"org.junit.Assert.*",
									"org.junit.jupiter.api.Assertions.*",
									"org.mockito.Mockito.*",
									"org.mockito.BDDMockito.*",
									"java.util.Objects.requireNonNull",
									"java.util.Objects.requireNonNullElse",
									"java.util.Collections.*",
									"java.util.stream.Collectors.*",
								},
								importOrder = { "java", "javax", "com", "org" },
								filteredTypes = {
									"java.awt.*",
									"javax.swing.*",
								},
								guessMethodArguments = true,
							},
							sources = {
								organizeImports = {
									starThreshold = 9999,
									staticStarThreshold = 9999,
								},
							},
							codeGeneration = {
								toString = {
									template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
								},
								hashCodeEquals = {
									useJava7Objects = true,
									useInstanceof = true,
								},
								useBlocks = true,
							},
							inlayHints = {
								parameterNames = { enabled = "literals" },
							},
							referencesCodeLens = { enabled = true },
							implementationsCodeLens = { enabled = true },
							semanticHighlighting = { enabled = true },
							format = {
								enabled = false,
							},
							foldingRange = { enabled = true },
							selectionRange = { enabled = true },
							saveActions = {
								organizeImports = true,
							},
							autobuild = { enabled = true },
							maven = { downloadSources = true },
							gradle = { downloadSources = true },
							eclipse = { downloadSources = true },
							errors = {
								incompleteClasspath = { severity = "ignore" },
							},
						},
					},
					init_options = { bundles = bundles },
					on_attach = function(_, bufnr)
						local function jmap(k, fn, d)
							vim.keymap.set("n", k, fn, { buffer = bufnr, silent = true, desc = d })
						end
						local function jvmap(k, fn, d)
							vim.keymap.set("v", k, fn, { buffer = bufnr, silent = true, desc = d })
						end

						jmap("<leader>co", jdtls.organize_imports, "Organize imports")
						jmap("<leader>cv", jdtls.extract_variable, "Extract variable")
						jvmap("<leader>cv", function()
							jdtls.extract_variable(true)
						end, "Extract variable")
						jmap("<leader>cC", jdtls.extract_constant, "Extract constant")
						jvmap("<leader>cC", function()
							jdtls.extract_constant(true)
						end, "Extract constant")
						jvmap("<leader>cm", function()
							jdtls.extract_method(true)
						end, "Extract method")

						jmap("<leader>cJ", jdtls.test_nearest_method, "Test nearest method")
						jmap("<leader>cK", jdtls.test_class, "Test class")

						jmap("<leader>cu", jdtls.super_implementation, "Go to super implementation")

						if #bundles > 0 then
							pcall(function()
								jdtls.setup_dap({ hotcodereplace = "auto" })
								pcall(require("jdtls.dap").setup_dap_main_class_configs)
							end)
						end
					end,
				}

				jdtls.start_or_attach(jdtls_config)
			end

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("nvim_jdtls", { clear = true }),
				pattern = "java",
				callback = setup_jdtls,
				desc = "Start/attach nvim-jdtls",
			})
		end,
	},
}