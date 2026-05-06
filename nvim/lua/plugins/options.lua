local helpers = require("utils.helpers")
local CURRENT_OS = helpers.CURRENT_OS
local has_cmd = helpers.has_cmd

-- ╔══════════════════════════════════════════════════╗
-- ║                      OPTIONS                       ║
-- ╚══════════════════════════════════════════════════╝

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.softtabstop = 4
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.wrap = false
vim.opt.cursorline = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.undofile = true
vim.opt.swapfile = false
vim.opt.mouse = "a"
vim.opt.showmode = false

vim.opt.smoothscroll = true
vim.opt.jumpoptions = "stack"
vim.opt.timeoutlen = 400

vim.opt.fillchars = {
	eob = " ",
}

vim.g.mapleader = " "
vim.g.autoformat = true

vim.filetype.add({ extension = { ejs = "ejs" } })
vim.treesitter.language.register("embedded_template", "ejs")

-- ╔══════════════════════════════════════════════════╗
-- ║                    CLIPBOARD               ║
-- ╚══════════════════════════════════════════════════╝

if CURRENT_OS == "linux" then
	local is_wsl = vim.fn.has("wsl") == 1
	if is_wsl then
		if has_cmd("win32yank.exe") then
			vim.g.clipboard = {
				name = "WslClipboard",
				copy = { ["+"] = "win32yank.exe -i --crlf", ["*"] = "win32yank.exe -i --crlf" },
				paste = { ["+"] = "win32yank.exe -o --lf", ["*"] = "win32yank.exe -o --lf" },
				cache_enabled = 0,
			}
		else
			vim.g.clipboard = {
				name = "WslClipboard",
				copy = { ["+"] = "clip.exe", ["*"] = "clip.exe" },
				paste = {
					["+"] = 'powershell.exe -NoLogo -NoProfile -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
					["*"] = 'powershell.exe -NoLogo -NoProfile -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
				},
				cache_enabled = 0,
			}
		end
	end
elseif CURRENT_OS == "mac" then
	vim.g.clipboard = {
		name = "macOSClipboard",
		copy = { ["+"] = "pbcopy", ["*"] = "pbcopy" },
		paste = { ["+"] = "pbpaste", ["*"] = "pbpaste" },
	}
elseif CURRENT_OS == "win" then
	vim.g.clipboard = {
		name = "WindowsClipboard",
		copy = { ["+"] = "clip.exe", ["*"] = "clip.exe" },
		paste = {
			["+"] = "powershell.exe -NoLogo -NoProfile -c Get-Clipboard",
			["*"] = "powershell.exe -NoLogo -NoProfile -c Get-Clipboard",
		},
	}
end

local sev = vim.diagnostic.severity
vim.diagnostic.config({
	virtual_text = { prefix = "●" },
	signs = {
		text = {
			[sev.ERROR] = "●",
			[sev.WARN] = "●",
			[sev.INFO] = "●",
			[sev.HINT] = "●",
		},
	},
	underline = true,
	update_in_insert = false,
	float = { border = "rounded", source = true },
})
