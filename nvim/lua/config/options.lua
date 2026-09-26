local o = vim.opt

o.number = true
o.relativenumber = true
o.cursorline = true
o.signcolumn = "yes"
o.termguicolors = true

o.tabstop = 2
o.shiftwidth = 2
o.softtabstop = 2
o.expandtab = true
o.breakindent = true

o.wrap = false
o.scrolloff = 8
o.sidescrolloff = 8

o.ignorecase = true
o.smartcase = true
o.incsearch = true
o.hlsearch = true

o.splitright = true
o.splitbelow = true

o.updatetime = 200
o.timeoutlen = 300
o.ttimeoutlen = 50

o.undofile = true
o.swapfile = false
o.backup = false
o.writebackup = false

o.mouse = "a"
o.clipboard = "unnamedplus"
o.completeopt = { "menu", "menuone", "noselect", "popup" }
o.pumheight = 10
o.showmode = false
o.cmdheight = 1
o.laststatus = 3
o.confirm = true

o.winborder = "rounded"

-- folds: window-local method/expr owned by treesitter-modules (fold.enable)
-- keep only global defaults here so oil/help/qf without parser don't get a broken expr
o.foldlevel = 99
o.foldlevelstart = 99
