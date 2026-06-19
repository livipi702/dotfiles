local M = {}

function M.setup()
	local dap = require("dap")
	local dapui = require("dapui")

	require("mason-nvim-dap").setup({
		ensure_installed = {},
		handlers = {
			function(config)
				require("mason-nvim-dap").default_setup(config)
			end,
		},
	})

	vim.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
	vim.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
	vim.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticInfo", linehl = "Visual" })

	for ft, dap_cfg in pairs(require("utils.lang-config").get_dap_configurations()) do
		dap.configurations[ft] = dap_cfg
	end

	dap.listeners.after.event_initialized["dapui_config"] = function()
		dapui.open()
	end
	dap.listeners.before.event_terminated["dapui_config"] = function()
		dapui.close()
	end
	dap.listeners.before.event_exited["dapui_config"] = function()
		dapui.close()
	end
end

return M
