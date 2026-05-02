vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

require("utils.helpers")
require("utils.lang-config")

require("plugins.options")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
local out = vim.fn.system({
"git",
"clone",
"--filter=blob:none",
"https://github.com/folke/lazy.nvim.git",
lazypath,
})
if vim.v.shell_error ~= 0 then
vim.api.nvim_echo({
{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
{ out, "WarningMsg" },
}, true, {})
return
end
end
vim.opt.rtp:prepend(lazypath)

local plugin_specs = {}
vim.list_extend(plugin_specs, require("plugins.lazydev"))
vim.list_extend(plugin_specs, require("plugins.lsp"))
vim.list_extend(plugin_specs, require("plugins.treesitter"))
vim.list_extend(plugin_specs, require("plugins.completion"))
vim.list_extend(plugin_specs, require("plugins.editor"))
vim.list_extend(plugin_specs, require("plugins.flash"))
vim.list_extend(plugin_specs, require("plugins.ui"))
vim.list_extend(plugin_specs, require("plugins.git"))
vim.list_extend(plugin_specs, require("plugins.term"))
vim.list_extend(plugin_specs, require("plugins.dap"))
vim.list_extend(plugin_specs, require("plugins.telescope"))
vim.list_extend(plugin_specs, require("plugins.harpoon"))
vim.list_extend(plugin_specs, require("plugins.persistence"))
vim.list_extend(plugin_specs, require("plugins.nvim-tree"))
vim.list_extend(plugin_specs, require("plugins.rest"))
vim.list_extend(plugin_specs, require("plugins.project"))
vim.list_extend(plugin_specs, require("plugins.dadbod"))
vim.list_extend(plugin_specs, require("plugins.goto-preview"))
vim.list_extend(plugin_specs, require("plugins.neotest"))

require("lazy").setup(plugin_specs, {
rocks = { enabled = false },
})

require("plugins.keymaps")

require("plugins.autocmds")

require("utils.runner")
