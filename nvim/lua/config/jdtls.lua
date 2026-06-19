local helpers = require("utils.helpers")
local get_jdtls_bundles = helpers.get_jdtls_bundles
local is_dir = helpers.is_dir
local safe_hash = helpers.safe_hash
local CURRENT_OS = helpers.CURRENT_OS

local M = {}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║              JDTLS SETUP (per official nvim-jdtls docs)      ║
-- ╚══════════════════════════════════════════════════════════════╝

--- Build the `cmd` using the `jdtls` wrapper script (Mason provides this).
--- The wrapper auto-handles: Java args, classpath, config dir, launcher jar.
--- Requires Python 3.9+ and `jdtls` in $PATH.
local function cmd_via_wrapper(workspace_dir)
	if vim.fn.executable("jdtls") ~= 1 then
		return nil
	end
	return { "jdtls", "-data", workspace_dir }
end

--- Build the `cmd` by invoking `java` directly (fallback if wrapper unavailable).
--- This is the traditional approach — manually specifies launcher jar, config dir, JVM flags.
local function cmd_via_java(workspace_dir)
	local ok_reg, mason_registry = pcall(require, "mason-registry")
	if not ok_reg then
		vim.notify("[jdtls] mason-registry not available", vim.log.levels.WARN)
		return nil
	end

	if not mason_registry.is_installed("jdtls") then
		vim.notify("[jdtls] Not installed via Mason. Run :MasonInstall jdtls", vim.log.levels.WARN)
		return nil
	end

	local jdtls_path = mason_registry.get_package("jdtls"):get_install_path()

	local launcher_jar = vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar")
	if launcher_jar == "" then
		vim.notify("[jdtls] Launcher jar not found at: " .. jdtls_path .. "/plugins/", vim.log.levels.WARN)
		return nil
	end

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

	return {
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
	}
end

--- Java language settings for eclipse.jdt.ls
local JAVA_SETTINGS = {
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
}

--- Set Java-specific keymaps on attach
local function on_attach(_, bufnr)
	local ok_jdtls, jdtls = pcall(require, "jdtls")
	if not ok_jdtls then
		return
	end

	local function jmap(k, fn, d)
		vim.keymap.set("n", k, fn, { buf = bufnr, silent = true, desc = d })
	end
	local function jvmap(k, fn, d)
		vim.keymap.set("v", k, fn, { buf = bufnr, silent = true, desc = d })
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

	local bundles = get_jdtls_bundles()
	if #bundles > 0 then
		pcall(function()
			jdtls.setup_dap({ hotcodereplace = "auto" })
			pcall(require("jdtls.dap").setup_dap_main_class_configs)
		end)
	end
end

--- Main setup function — call from ftplugin/java.lua
function M.setup()
	-- Guard: don't start twice for the same buffer
	local clients = vim.lsp.get_clients({ name = "jdtls", bufnr = 0 })
	if #clients > 0 then
		return
	end

	local ok_jdtls, jdtls = pcall(require, "jdtls")
	if not ok_jdtls then
		vim.notify("[jdtls] Plugin not available: " .. tostring(jdtls), vim.log.levels.WARN)
		return
	end

	-- Root directory
	local root_dir = require("jdtls.setup").find_root({
		".git",
		"mvnw",
		"gradlew",
		"pom.xml",
		"build.gradle",
		"build.gradle.kts",
	}) or vim.fn.getcwd()

	-- Workspace directory (persists index data across restarts)
	local project_name = vim.fn.fnamemodify(root_dir, ":t")
	local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name .. "-" .. safe_hash(root_dir)
	vim.fn.mkdir(workspace_dir, "p")

	-- Build cmd: try wrapper first, fall back to manual java invocation
	local cmd = cmd_via_wrapper(workspace_dir) or cmd_via_java(workspace_dir)
	if not cmd then
		return
	end

	-- Capabilities
	local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
	local capabilities = ok_cmp and cmp_lsp.default_capabilities() or {}

	local bundles = get_jdtls_bundles()

	jdtls.start_or_attach({
		cmd = cmd,
		root_dir = root_dir,
		capabilities = capabilities,
		settings = JAVA_SETTINGS,
		init_options = { bundles = bundles },
		on_attach = on_attach,
	})
end

--- Health check for :checkhealth jdtls
function M.check()
	local health = vim.health or require("health")
	local start = health.start or health.report_start
	local ok = health.ok or health.report_ok
	local warn = health.warn or health.report_warn
	local error = health.error or health.report_error

	start("jdtls")

	-- Check jdtls executable (wrapper)
	if vim.fn.executable("jdtls") == 1 then
		ok("jdtls wrapper in PATH (simplified cmd)")
	else
		warn("jdtls wrapper not in PATH — will use manual java invocation (requires Mason jdtls package)")
	end

	-- Check Java
	if vim.fn.executable("java") == 1 then
		ok("java executable found")
	else
		error("java not found in PATH — jdtls requires Java 17+")
	end

	-- Check Mason packages
	local ok_reg, mason_registry = pcall(require, "mason-registry")
	if ok_reg then
		if mason_registry.is_installed("jdtls") then
			ok("Mason: jdtls installed")
		else
			warn("Mason: jdtls not installed — run :MasonInstall jdtls")
		end
		if mason_registry.is_installed("java-debug-adapter") then
			ok("Mason: java-debug-adapter installed (DAP support)")
		else
			warn("Mason: java-debug-adapter not installed — no DAP. Run :MasonInstall java-debug-adapter")
		end
		if mason_registry.is_installed("java-test") then
			ok("Mason: java-test installed (JUnit support)")
		else
			warn("Mason: java-test not installed — no JUnit DAP. Run :MasonInstall java-test")
		end
	else
		warn("mason-registry not available — cannot verify Mason packages")
	end

	-- Check Python (needed for jdtls wrapper)
	if vim.fn.executable("python3") == 1 or vim.fn.executable("python") == 1 then
		ok("Python found (required for jdtls wrapper)")
	else
		warn("Python not found — jdtls wrapper requires Python 3.9+. Manual java invocation will be used as fallback.")
	end
end

return M
