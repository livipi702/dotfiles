local lang = require("utils.lang-config")
local get_lang_cfg = lang.get_lang_cfg
local cache_invalidate = require("utils.helpers").cache_invalidate

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                     AUTOCOMMANDS                             ║
-- ╚══════════════════════════════════════════════════════════════╝

vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("my_yank_highlight", { clear = true }),
	desc = "Briefly highlight yanked text",
	callback = function()
		vim.hl.on_yank({ timeout = 200 })
	end,
})

vim.api.nvim_create_autocmd("DirChanged", {
	group = vim.api.nvim_create_augroup("my_cache_invalidate", { clear = true }),
	desc = "Invalidate runtime caches on directory change",
	callback = cache_invalidate,
})

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("my_indent_setup", { clear = true }),
	desc = "Apply language indent and treesitter indent",
	callback = function(event)
		local ft = vim.bo.filetype

		-- Language-specific indent from config
		local cfg = get_lang_cfg(ft)
		if cfg and cfg.indent then
			vim.opt_local.tabstop = cfg.indent.tabstop or 4
			vim.opt_local.shiftwidth = cfg.indent.shiftwidth or 4
			vim.opt_local.softtabstop = cfg.indent.softtabstop or cfg.indent.tabstop or 4
			if cfg.indent.expandtab ~= nil then
				vim.opt_local.expandtab = cfg.indent.expandtab
			end
		end

		-- Enable current nvim-treesitter main-branch features when a parser exists.
		local ok_get, ts_lang = pcall(vim.treesitter.language.get_lang, ft)
		ts_lang = (ok_get and ts_lang) or ft
		local ok_parser = pcall(vim.treesitter.language.inspect, ts_lang)
		if ok_parser then
			pcall(vim.treesitter.start, event.buf, ts_lang)
			vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
	group = vim.api.nvim_create_augroup("my_strip_trailing_ws", { clear = true }),
	desc = "Strip trailing whitespace for unformatted filetypes",
	pattern = "*",
	callback = function()
		if not vim.bo.modifiable or vim.bo.buftype ~= "" or vim.bo.filetype == "" then
			return
		end
		local cfg = get_lang_cfg(vim.bo.filetype)
		if cfg and cfg.formatters and vim.g.autoformat then
			return
		end
		local view = vim.fn.winsaveview()
		pcall(vim.cmd, [[keeppatterns %s/\s\+$//e]])
		vim.fn.winrestview(view)
	end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
	group = vim.api.nvim_create_augroup("my_restore_cursor", { clear = true }),
	desc = "Restore cursor to last known position",
	callback = function()
		if vim.tbl_contains({ "gitcommit", "gitrebase", "help" }, vim.bo.filetype) then
			return
		end
		if vim.bo.buftype ~= "" then
			return
		end
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lines = vim.api.nvim_buf_line_count(0)
		if mark[1] > 0 and mark[1] <= lines then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("my_close_special_bufs", { clear = true }),
	desc = "Close special buffers with q",
	pattern = {
		"help",
		"lspinfo",
		"notify",
		"qf",
		"query",
		"startuptime",
		"checkhealth",
		"neotest-summary",
		"neotest-output",
		"neotest-output-panel",
		"dbout",
		"httpResult",
	},
	callback = function(event)
		vim.bo[event.buf].buflisted = false
		vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = event.buf, silent = true })
	end,
})

vim.api.nvim_create_autocmd("User", {
	group = vim.api.nvim_create_augroup("my_startup_notify", { clear = true }),
	pattern = "VeryLazy",
	once = true,
	callback = function()
		local LANG_CONFIG = require("utils.lang-config").LANG_CONFIG
		vim.notify(
			"Config loaded \u{2014} "
				.. vim.tbl_count(LANG_CONFIG)
				.. " languages  |  Linting ON by default (\u{3c}leader\u{3e}lL to toggle)",
			vim.log.levels.INFO
		)
	end,
})
