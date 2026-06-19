local lang = require("utils.lang-config")

local M = {}

local function resolve_opts(opts)
	local resolved = vim.deepcopy(opts)
	if type(resolved.settings) == "function" then
		resolved.settings = resolved.settings()
	end
	return resolved
end

local function lang_server_configs()
	local configs = {}
	for _, cfg in pairs(lang.LANG_CONFIG) do
		if cfg.lsp and cfg.lsp_opts and not configs[cfg.lsp] then
			configs[cfg.lsp] = resolve_opts(cfg.lsp_opts)
		end
	end
	return configs
end

function M.setup(capabilities)
	vim.lsp.config("*", { capabilities = capabilities })

	for server, opts in pairs(lang_server_configs()) do
		vim.lsp.config(server, opts)
	end

	for _, server in ipairs(lang.get_lsp_servers()) do
		local ok, err = pcall(vim.lsp.enable, server)
		if not ok then
			vim.notify("Failed to enable LSP server '" .. server .. "': " .. tostring(err), vim.log.levels.WARN)
		end
	end
end

return M
