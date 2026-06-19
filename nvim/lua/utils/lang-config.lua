local helpers = require("utils.helpers")
local has_cmd = helpers.has_cmd
local has_file = helpers.has_file
local get_python = helpers.get_python
local resolve_ts_cmd = helpers.resolve_ts_cmd
local browser_run = helpers.browser_run
local make_temp_out = helpers.make_temp_out
local java_info = helpers.java_info
local java_root_from_class = helpers.java_root_from_class
local safe_hash = helpers.safe_hash
local temp_base = helpers.temp_base

local M = {}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                  PLUGIN CONFIGURATION                         ║
-- ╚══════════════════════════════════════════════════════════════╝

local get_lang_cfg

local function c_family_dap_configs(dap_type)
	return {
		{
			name = "Debug file",
			type = dap_type,
			request = "launch",
			program = function()
				local f = vim.fn.expand("%:p")
				local lang_cfg = get_lang_cfg(vim.bo.filetype)
				if lang_cfg and lang_cfg.out then
					local out = lang_cfg.out(f)
					if out and has_file(out) then
						return out
					end
				end
				return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file")
			end,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
		},
	}
end

local C_FAMILY_PROJECT = {
	{
		marker = "CMakeLists.txt",
		build = "cmake -B build && cmake --build build",
		run = "cmake -B build && cmake --build build && ./build/main",
	},
	{ marker = "Makefile", build = "make", run = "make run" },
	{ marker = "makefile", build = "make", run = "make run" },
}

local function js_family_dap_configs(dap_type)
	return {
		{
			name = "Launch file",
			type = dap_type,
			request = "launch",
			program = "${file}",
			cwd = "${workspaceFolder}",
			sourceMaps = true,
			protocol = "inspector",
			console = "integratedTerminal",
		},
		{
			name = "Attach to process",
			type = dap_type,
			request = "attach",
			processId = function()
				return require("dap.utils").pick_process()
			end,
			cwd = "${workspaceFolder}",
			sourceMaps = true,
		},
	}
end

-- ══════════════════════════════════════════════════════════════
-- THE SINGLE SOURCE OF TRUTH
-- ══════════════════════════════════════════════════════════════

local LANG_CONFIG = {
	cpp = {
		lsp = "clangd",
		lsp_opts = {
			root_markers = { ".clangd", ".clang-tidy", ".clang-format", "compile_commands.json", ".git" },
			cmd = {
				"clangd",
				"--completion-style=detailed",
				"--function-arg-placeholders=true",
				"--header-insertion=iwyu",
				"--fallback-style=llvm",
			},
			init_options = {
				clangdFileStatus = true,
				usePlaceholders = true,
				completeUnimported = true,
				semanticHighlighting = true,
			},
		},
		formatters = { "clang-format" },
		dap_adapter = { mason = "codelldb", type = "codelldb" },
		treesitter = { "cpp", "c" },
		indent = { tabstop = 4, shiftwidth = 4 },
		deps = { "g++" },
		project = C_FAMILY_PROJECT,
		dap_configs = c_family_dap_configs,
		out = function(f)
			return make_temp_out(f)
		end,
		compile = function(f, out)
			return ("g++ -std=c++17 -O2 -Wall -Wextra -o %s %s"):format(vim.fn.shellescape(out), vim.fn.shellescape(f))
		end,
		run = function(_, out)
			return vim.fn.shellescape(out)
		end,
	},

	c = {
		lsp = "clangd",
		formatters = { "clang-format" },
		dap_adapter = { mason = "codelldb", type = "codelldb" },
		treesitter = { "c" },
		indent = { tabstop = 4, shiftwidth = 4 },
		deps = { "gcc" },
		project = C_FAMILY_PROJECT,
		dap_configs = c_family_dap_configs,
		out = function(f)
			return make_temp_out(f)
		end,
		compile = function(f, out)
			return ("gcc -std=c17 -O2 -Wall -Wextra -o %s %s"):format(vim.fn.shellescape(out), vim.fn.shellescape(f))
		end,
		run = function(_, out)
			return vim.fn.shellescape(out)
		end,
	},

	python = {
		lsp = "basedpyright",
		linters = { "ruff" },

		formatters = { "ruff_organize_imports", "ruff_format" },
		dap_adapter = { mason = "debugpy", type = "debugpy" },
		treesitter = { "python" },
		indent = { tabstop = 4, shiftwidth = 4 },
		python = true,
		project = {
			{
				marker = "pyproject.toml",
				test = function()
					return get_python() .. " -m pytest"
				end,
			},
		},
		dap_configs = function(dap_type)
			return {
				{
					name = "Debug file",
					type = dap_type,
					request = "launch",
					program = "${file}",
					cwd = "${workspaceFolder}",
					pythonPath = function()
						return get_python()
					end,
				},
			}
		end,
		run = function(f)
			return get_python() .. " " .. vim.fn.shellescape(f)
		end,
	},

	lua = {
		lsp = "lua_ls",
		lsp_opts = {
			settings = {
				Lua = {
					runtime = { version = "LuaJIT" },
					workspace = {
						checkThirdParty = false,
						library = { vim.env.VIMRUNTIME },
					},
					completion = {
						callSnippet = "Replace",
						showWord = "Disable",
						workspaceWord = true,
					},
					hint = {
						enable = true,
						arrayIndex = "Enable",
						setType = true,
						paramType = true,
						paramName = "All",
						await = true,
					},
					diagnostics = {
						globals = { "vim" },
						disable = { "unused-local", "unused-vararg" },
					},
					format = { enable = false },
					telemetry = { enable = false },
				},
			},
		},
		formatters = { "stylua" },
		treesitter = { "lua" },
		indent = { tabstop = 2, shiftwidth = 2 },
		deps = { "lua" },
		run = function(f)
			return "lua " .. vim.fn.shellescape(f)
		end,
	},

	typescript = {
		lsp = "ts_ls",
		linters = { "eslint_d" },
		lsp_opts = {
			filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
			root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
			settings = {
				typescript = {
					preferences = {
						completeFunctionCalls = true,
						preferGoToSourceDefinition = true,
						importModuleSpecifier = "non-relative",
						jsxAttributeCompletionStyle = "braces",
						includeCompletionsForModuleExports = true,
						includeAutomaticOptionalChainCompletions = true,
					},
					suggest = {
						includeAutomaticOptionalChainCompletions = true,
						includeCompletionsForModuleExports = true,
					},
					updateImportsOnFileMove = { enabled = "always" },
					inlayHints = {
						parameterNames = { enabled = "all" },
						functionLikeReturnTypes = { enabled = true },
						propertyDeclarationTypes = { enabled = true },
						variableTypes = { enabled = false },
						enumMemberValues = { enabled = true },
					},
					implementationsCodeLens = { enabled = true },
					referencesCodeLens = { enabled = true },
				},
				javascript = {
					preferences = {
						completeFunctionCalls = true,
						jsxAttributeCompletionStyle = "braces",
					},
					suggest = {
						includeAutomaticOptionalChainCompletions = true,
						includeCompletionsForModuleExports = true,
					},
					updateImportsOnFileMove = { enabled = "always" },
					inlayHints = {
						parameterNames = { enabled = "all" },
						functionLikeReturnTypes = { enabled = true },
						propertyDeclarationTypes = { enabled = true },
						variableTypes = { enabled = false },
						enumMemberValues = { enabled = true },
					},
				},
			},
		},
		formatters = { "prettierd", "prettier", stop_after_first = true },
		dap_adapter = { mason = "js-debug-adapter", type = "pwa-node" },
		treesitter = { "typescript", "javascript" },
		indent = { tabstop = 2, shiftwidth = 2 },
		deps = { "node" },
		project = {
			{
				marker = "package.json",
				run = "npm start",
				build = "npm run build",
				test = "npm test",
			},
		},
		dap_configs = function(dap_type)
			local configs = js_family_dap_configs(dap_type)
			configs[1].resolveSourceMapLocations = {
				"${workspaceFolder}/**",
				"!**/node_modules/**",
			}
			return configs
		end,
		run = function(f)
			local cmd = resolve_ts_cmd()
			if not cmd then
				return nil
			end
			return cmd .. " " .. vim.fn.shellescape(f)
		end,
	},

	javascript = {
		lsp = "ts_ls",
		formatters = { "prettierd", "prettier", stop_after_first = true },
		dap_adapter = { mason = "js-debug-adapter", type = "pwa-node" },
		linters = { "eslint_d" },
		treesitter = { "javascript" },
		indent = { tabstop = 2, shiftwidth = 2 },
		deps = { "node" },
		project = {
			{
				marker = "package.json",
				run = "npm start",
				build = "npm run build",
				test = "npm test",
			},
		},
		dap_configs = js_family_dap_configs,
		run = function(f)
			return "node " .. vim.fn.shellescape(f)
		end,
	},

	html = {
		lsp = "html",
		lsp_opts = {
			filetypes = { "html", "ejs" },
			root_markers = { ".git" },
			settings = {
				html = {
					format = { enable = false },
					suggest = { html5 = true },
					hover = { documentation = true },
					autoClosingTags = true,
					autoCreateTags = true,
				},
			},
		},
		formatters = { "prettierd", "prettier", stop_after_first = true },
		treesitter = { "embedded_template", "html", "javascript", "css" },
		indent = { tabstop = 2, shiftwidth = 2 },
		run = browser_run,
	},

	css = {
		lsp = "cssls",
		lsp_opts = {
			root_markers = { ".git" },
			settings = {
				css = {
					validate = true,
					lint = { unknownAtRules = "ignore" },
					format = { enable = false },
				},
				scss = {
					validate = true,
					format = { enable = false },
				},
				less = {
					validate = true,
					format = { enable = false },
				},
			},
		},
		formatters = { "prettierd", "prettier", stop_after_first = true },
		treesitter = { "css" },
		indent = { tabstop = 2, shiftwidth = 2 },
	},

	ejs = {
		lsp = "html",
		formatters = { "prettierd_html" },
		treesitter = { "embedded_template", "html", "javascript", "css" },
		indent = { tabstop = 2, shiftwidth = 2 },
		run = browser_run,
	},

	json = {
		lsp = "jsonls",
		lsp_opts = {
			root_markers = { ".git" },
			settings = function()
				local ok_ss, schemastore = pcall(require, "schemastore")
				if not ok_ss then
					return {}
				end
				return {
					json = {
						schemas = schemastore.json.schemas(),
						validate = { enable = true },
						format = { enable = false },
					},
				}
			end,
		},
		formatters = { "prettierd", "prettier", stop_after_first = true },
		treesitter = { "json" },
		indent = { tabstop = 2, shiftwidth = 2 },
	},

	java = {
		lsp = nil,
		lsp_manual = "jdtls",
		formatters = { "google-java-format" },
		dap_adapter = { mason = "java-debug-adapter", type = "java" },
		treesitter = { "java" },
		indent = { tabstop = 4, shiftwidth = 4 },
		deps = { "javac", "java" },
		project = {
			{
				marker = "pom.xml",
				build = "mvn compile",
				run = "mvn exec:java",
				test = "mvn test",
			},
			{
				marker = "build.gradle",
				build = "gradle build",
				run = "gradle run",
				test = "gradle test",
			},
			{
				marker = "build.gradle.kts",
				build = "gradle build",
				run = "gradle run",
				test = "gradle test",
			},
		},
		dap_configs = function(dap_type)
			return {
				{
					name = "Debug file",
					type = dap_type,
					request = "launch",
					mainClass = function()
						return vim.fn.input("Main class: ")
					end,
					cwd = "${workspaceFolder}",
				},
			}
		end,
		out = function(f)
			local srcdir, fqcn = java_info(f)
			local out_dir = temp_base() .. "/java_" .. safe_hash(srcdir)
			vim.fn.mkdir(out_dir, "p")
			local class_rel = fqcn:gsub("%.", "/") .. ".class"
			return out_dir .. "/" .. class_rel
		end,
		compile = function(f, out)
			local _, fqcn = java_info(f)
			local root = java_root_from_class(out, fqcn)
			vim.fn.mkdir(root, "p")
			return ("javac -d %s %s"):format(vim.fn.shellescape(root), vim.fn.shellescape(f))
		end,
		run = function(f, out)
			local _, fqcn = java_info(f)
			local root = java_root_from_class(out, fqcn)
			return ("java -cp %s %s"):format(vim.fn.shellescape(root), fqcn)
		end,
	},

	go = {
		lsp = "gopls",
		lsp_opts = {
			root_markers = { "go.mod", ".git" },
			settings = {
				gopls = {
					analyses = {
						unusedparams = true,
						shadow = true,
						unreachable = true,
					},
					staticcheck = true,
					gofumpt = true,
					completeUnimported = true,
					usePlaceholders = true,
					semanticTokens = true,
					hints = {
						assignVariableTypes = true,
						compositeLiteralFields = true,
						compositeLiteralTypes = true,
						constantValues = true,
						functionTypeParameters = true,
						parameterNames = true,
						rangeVariableTypes = true,
					},
				},
			},
		},
		formatters = { "gofmt" },
		dap_adapter = { mason = "delve", type = "go" },
		dap_configs = function(dap_type)
			return {
				{
					name = "Debug file",
					type = dap_type,
					request = "launch",
					program = "${file}",
					cwd = "${workspaceFolder}",
					mode = "auto",
				},
				{
					name = "Debug test",
					type = dap_type,
					request = "launch",
					program = "${file}",
					cwd = "${workspaceFolder}",
					mode = "test",
				},
			}
		end,
		treesitter = { "go" },
		indent = { tabstop = 4, shiftwidth = 4 },
		deps = { "go" },
		linters = { "golangci-lint" },
		project = {
			{
				marker = "go.mod",
				build = "go build -v ./...",
				run = "go run .",
				test = "go test ./...",
			},
		},
		out = function(f)
			return make_temp_out(f, "go_")
		end,
		compile = function(f, out)
			return ("go build -o %s %s"):format(vim.fn.shellescape(out), vim.fn.shellescape(f))
		end,
		run = function(_, out)
			return vim.fn.shellescape(out)
		end,
	},

	sh = {
		formatters = { "shfmt" },
		treesitter = { "bash" },
		indent = { tabstop = 2, shiftwidth = 2 },
		deps = { "bash" },
		linters = { "shellcheck" },
		run = function(f)
			return "bash " .. vim.fn.shellescape(f)
		end,
	},

	markdown = {
		treesitter = { "markdown", "markdown_inline" },
		indent = { tabstop = 2, shiftwidth = 2 },
	},

	http = {
		treesitter = { "http" },
	},

	sql = {
		lsp = "sqlls",
		lsp_opts = {
			root_markers = { ".git" },
			settings = {
				sqls = { connections = {} },
			},
		},
		formatters = { "sqlfluff" },
		treesitter = { "sql" },
		indent = { tabstop = 2, shiftwidth = 2 },
	},

	yaml = {
		lsp = "yamlls",
		lsp_opts = {
			root_markers = { ".git" },
			settings = {
				yaml = {
					format = { enable = false },
					validate = true,
					hover = true,
					completion = true,
					keyOrdering = false,
					schemaStore = {
						enable = true,
						url = "",
					},
				},
			},
		},
		treesitter = { "yaml" },
		indent = { tabstop = 2, shiftwidth = 2 },
	},

	toml = {
		treesitter = { "toml" },
		indent = { tabstop = 2, shiftwidth = 2 },
	},

	vim_ft = {
		treesitter = { "vim" },
		indent = { tabstop = 2, shiftwidth = 2 },
	},

	regex = {
		treesitter = { "regex" },
	},

	make = {
		treesitter = { "make" },
		indent = { tabstop = 4, shiftwidth = 4, expandtab = false },
	},
}

LANG_CONFIG.c.lsp_opts = vim.deepcopy(LANG_CONFIG.cpp.lsp_opts)

local FT_ALIAS_MAP = {
	vim = "vim_ft",
}

function get_lang_cfg(ft)
	if not ft or ft == "" then
		return nil
	end
	local key = FT_ALIAS_MAP[ft] or ft
	return LANG_CONFIG[key]
end

LANG_CONFIG.bash = vim.deepcopy(LANG_CONFIG.sh)
LANG_CONFIG.bash._alias_of = "sh"

LANG_CONFIG.javascriptreact = vim.deepcopy(LANG_CONFIG.javascript)
LANG_CONFIG.javascriptreact._alias_of = "javascript"

LANG_CONFIG.typescriptreact = vim.deepcopy(LANG_CONFIG.typescript)
LANG_CONFIG.typescriptreact._alias_of = "typescript"

-- ══════════════════════════════════════════════════════════════
-- MASON MAPPING TABLES
-- ══════════════════════════════════════════════════════════════

local SKIP_MASON_FORMATTERS = {
	prettierd_html = true,
	gofmt = true,
}

local FORMATTER_TO_MASON = {
	ruff_format = "ruff",
	ruff_organize_imports = "ruff",
}

-- ══════════════════════════════════════════════════════════════
-- DERIVED CONFIGURATION
-- ══════════════════════════════════════════════════════════════

local function iter_primary_langs()
	local results = {}
	for key, cfg in pairs(LANG_CONFIG) do
		if not cfg._alias_of then
			results[key] = cfg
		end
	end
	return results
end

local function get_lsp_servers()
	local seen, servers = {}, {}
	for _, cfg in pairs(iter_primary_langs()) do
		if cfg.lsp and not seen[cfg.lsp] then
			seen[cfg.lsp] = true
			servers[#servers + 1] = cfg.lsp
		end
	end
	vim.list_extend(servers, { "emmet_ls", "tailwindcss" })
	return servers
end

local function get_formatters()
	local seen, list = {}, {}
	for _, cfg in pairs(iter_primary_langs()) do
		if cfg.formatters then
			for _, fmt in ipairs(cfg.formatters) do
				if not SKIP_MASON_FORMATTERS[fmt] then
					local mason_name = FORMATTER_TO_MASON[fmt] or fmt
					if not seen[mason_name] then
						seen[mason_name] = true
						list[#list + 1] = mason_name
					end
				end
			end
		end
	end
	return list
end

local function get_treesitter_langs()
	local seen, list = {}, {}
	for _, cfg in pairs(iter_primary_langs()) do
		if cfg.treesitter then
			for _, ts in ipairs(cfg.treesitter) do
				if not seen[ts] then
					seen[ts] = true
					list[#list + 1] = ts
				end
			end
		end
	end
	return list
end

local function get_dap_adapters()
	local seen, list = {}, {}
	for _, cfg in pairs(iter_primary_langs()) do
		if cfg.dap_adapter then
			local mason_name = cfg.dap_adapter.mason
			if mason_name and not seen[mason_name] then
				seen[mason_name] = true
				list[#list + 1] = mason_name
			end
		end
	end
	return list
end

local function get_linters()
	local seen, list = {}, {}
	for _, cfg in pairs(iter_primary_langs()) do
		if cfg.linters then
			for _, linter in ipairs(cfg.linters) do
				if not seen[linter] then
					seen[linter] = true
					list[#list + 1] = linter
				end
			end
		end
	end
	return list
end

local function get_conform_config()
	local by_ft, custom = {}, {}

	for ft, cfg in pairs(LANG_CONFIG) do
		if cfg.formatters then
			local actual_ft = ft
			if ft == "vim_ft" then
				actual_ft = "vim"
			end
			if not by_ft[actual_ft] then
				by_ft[actual_ft] = cfg.formatters
			end
		end
	end

	-- ══════════════════════════════════════════════════════════════
	-- CUSTOM FORMATTERS
	-- ══════════════════════════════════════════════════════════════

	custom.prettierd_html = {
		command = function()
			return has_cmd("prettierd") and "prettierd" or "prettier"
		end,
		condition = function()
			return has_cmd("prettierd") or has_cmd("prettier")
		end,
		args = function(ctx)
			local filename = ctx.filename or "stdin.html"
			filename = filename:gsub("%.ejs$", ".html")
			if has_cmd("prettierd") then
				return { filename }
			end
			return { "--stdin-filepath", filename }
		end,
		stdin = true,
	}

	custom.eslint_d = {
		command = "eslint_d",
		args = { "--stdin", "--stdin-filename", "$FILENAME", "--fix-to-stdout" },
		stdin = true,
		condition = function()
			return has_cmd("eslint_d")
		end,
	}

	custom["clang-format"] = {
		condition = function()
			return has_cmd("clang-format")
		end,
	}

	custom.stylua = {
		condition = function()
			return has_cmd("stylua")
		end,
	}

	custom.shfmt = {
		condition = function()
			return has_cmd("shfmt")
		end,
	}

	custom.gofmt = {
		condition = function()
			return has_cmd("gofmt")
		end,
	}

	-- ══════════════════════════════════════════════════════════════
	-- RUFF FORMAT
	-- ══════════════════════════════════════════════════════════════
	custom.ruff_format = {
		command = "ruff",
		args = { "format", "--stdin-filename", "$FILENAME", "-" },
		stdin = true,
		condition = function()
			return has_cmd("ruff")
		end,
	}

	-- ══════════════════════════════════════════════════════════════
	-- RUFF IMPORTS
	-- ══════════════════════════════════════════════════════════════
	custom.ruff_organize_imports = {
		command = "ruff",
		args = { "check", "--select", "I", "--fix", "--stdin-filename", "$FILENAME", "-" },
		stdin = true,
		condition = function()
			return has_cmd("ruff")
		end,
	}

	custom["google-java-format"] = {
		condition = function()
			return has_cmd("google-java-format")
		end,
	}

	return by_ft, custom
end

local function get_linters_by_ft()
	local by_ft = {}
	for ft, cfg in pairs(LANG_CONFIG) do
		if cfg.linters then
			local target_ft = ft
			if ft == "vim_ft" then
				target_ft = "vim"
			end
			by_ft[target_ft] = cfg.linters
		end
	end
	return by_ft
end

local function get_dap_configurations()
	local configs = {}

	for ft, cfg in pairs(LANG_CONFIG) do
		if cfg.dap_adapter and cfg.dap_configs then
			local dap_type = cfg.dap_adapter.type
			local ft_configs = cfg.dap_configs(dap_type)

			if ft_configs then
				configs[ft] = ft_configs
			end
		end
	end

	return configs
end

-- ══════════════════════════════════════════════════════════════
-- PUBLIC API
-- ══════════════════════════════════════════════════════════════

M.LANG_CONFIG = LANG_CONFIG
M.FT_ALIAS_MAP = FT_ALIAS_MAP
M.SKIP_MASON_FORMATTERS = SKIP_MASON_FORMATTERS
M.FORMATTER_TO_MASON = FORMATTER_TO_MASON
M.get_lang_cfg = get_lang_cfg
M.iter_primary_langs = iter_primary_langs
M.get_lsp_servers = get_lsp_servers
M.get_formatters = get_formatters
M.get_treesitter_langs = get_treesitter_langs
M.get_dap_adapters = get_dap_adapters
M.get_linters = get_linters
M.get_conform_config = get_conform_config
M.get_linters_by_ft = get_linters_by_ft
M.get_dap_configurations = get_dap_configurations

return M
