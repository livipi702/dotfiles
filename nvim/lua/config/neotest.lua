local helpers = require("utils.helpers")

local M = {}

local function add_adapter(adapters, module, opts)
	local ok, adapter = pcall(require, module)
	if ok then
		adapters[#adapters + 1] = adapter(opts)
	else
		vim.notify("neotest adapter unavailable: " .. module, vim.log.levels.DEBUG)
	end
end

function M.setup()
	local neotest = require("neotest")
	local adapters = {}

	add_adapter(adapters, "neotest-python", {
		dap = { justMyCode = false },
		runner = "pytest",
		python = helpers.get_python(),
	})

	add_adapter(adapters, "neotest-jest", {
		jestCommand = "npx jest",
	})

	add_adapter(adapters, "neotest-go", {
		experimental = {
			test_table = true,
		},
	})

	neotest.setup({
		adapters = adapters,
		status = { virtual_text = true },
		output = { open_on_run = true },
		quickfix = {
			open = function()
				local ok_trouble = pcall(require, "trouble")
				if ok_trouble then
					require("trouble").open({ mode = "quickfix" })
				else
					vim.cmd("copen")
				end
			end,
		},
	})
end

return M
