local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local yank_grp = augroup("YankHighlight", { clear = true })
autocmd("TextYankPost", {
  group = yank_grp,
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

local resize_grp = augroup("ResizeSplits", { clear = true })
autocmd("VimResized", {
  group = resize_grp,
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

local close_grp = augroup("CloseWithQ", { clear = true })
autocmd("FileType", {
  group = close_grp,
  pattern = { "help", "man", "qf", "lspinfo", "checkhealth" },
  callback = function(ev)
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buf = ev.buf, silent = true })
  end,
})

local lsp_grp = augroup("LspAttachMaps", { clear = true })
autocmd("LspAttach", {
  group = lsp_grp,
  callback = function(ev)
    local map = function(keys, fn, desc)
      vim.keymap.set("n", keys, fn, { buf = ev.buf, desc = "LSP: " .. desc })
    end
    map("gd", vim.lsp.buf.definition, "Goto definition")
    -- references/rename/code-action use native grr/grn/gra (0.11+ defaults)
    map("gI", vim.lsp.buf.implementation, "Goto implementation")
    map("gy", vim.lsp.buf.type_definition, "Type definition")
    map("K", vim.lsp.buf.hover, "Hover")
    map("<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("<leader>cr", vim.lsp.buf.rename, "Rename")
    map("<leader>cd", vim.diagnostic.open_float, "Diagnostics")
  end,
})
