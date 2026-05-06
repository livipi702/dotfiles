
-- ╔══════════════════════════════════════════════════╗
-- ║                      KEYBINDINGS                 ║
-- ╚══════════════════════════════════════════════════╝

vim.keymap.set("n", "<leader>w", "<cmd>w<CR>", { silent = true, desc = "Save" })
vim.keymap.set("n", "<leader>q", "<cmd>q<CR>", { silent = true, desc = "Quit" })
vim.keymap.set("n", "<leader>x", "<cmd>bdelete<CR>", { silent = true, desc = "Close buffer" })
vim.keymap.set("n", "<leader>h", "<cmd>nohlsearch<CR>", { silent = true, desc = "Clear search highlight" })

vim.keymap.set({ "n", "v" }, "<leader>y", '"+y', { silent = true, desc = "Yank to clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p', { silent = true, desc = "Paste from clipboard" })

-- ═══════════════════════════════════════════════════════════════
-- TELESCOPE
-- ═══════════════════════════════════════════════════════════════
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { silent = true, desc = "Files" })

vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { silent = true, desc = "Grep" })

vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { silent = true, desc = "Buffers" })

vim.keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { silent = true, desc = "Recent" })

vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { silent = true, desc = "Help" })

vim.keymap.set("n", "<leader>fd", function()
  local ok, telescope = pcall(require, "telescope.builtin")
  if not ok then
    vim.notify("Telescope not available", vim.log.levels.WARN)
    return
  end
  telescope.find_files({
    cwd = vim.fn.expand("%:p:h"),
    prompt_title = "Files (current dir)",
  })
end, { silent = true, desc = "Files (current dir)" })

vim.keymap.set("n", "<leader>fs", function()
  local ok, telescope = pcall(require, "telescope.builtin")
  if not ok then
    vim.notify("Telescope not available", vim.log.levels.WARN)
    return
  end
  telescope.live_grep({
    cwd = vim.fn.expand("%:p:h"),
    prompt_title = "Grep (current dir)",
  })
end, { silent = true, desc = "Grep (current dir)" })

vim.keymap.set("n", "<leader>fD", function()
  local ok, telescope = pcall(require, "telescope.builtin")
  if not ok then
    vim.notify("Telescope not available", vim.log.levels.WARN)
    return
  end
  local dir = vim.fn.input("Dir: ", vim.fn.getcwd() .. "/", "dir")
  if dir ~= "" then
    telescope.find_files({ cwd = dir })
  end
end, { silent = true, desc = "Files (pick dir)" })

vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<CR>", { silent = true, desc = "Next buffer" })
vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<CR>", { silent = true, desc = "Prev buffer" })
vim.keymap.set("n", "<leader>bo", "<cmd>%bd|e#|bd#<CR>", { silent = true, desc = "Close other buffers" })

-- ═══════════════════════════════════════════════════════════════
-- LINTING
-- ═══════════════════════════════════════════════════════════════
vim.keymap.set("n", "<leader>lL", function()
  local ok, lint = pcall(require, "lint")
  if not ok then
    vim.notify("nvim-lint not available", vim.log.levels.WARN)
    return
  end
  vim.g.linting_enabled = not vim.g.linting_enabled
  if vim.g.linting_enabled then
    lint.try_lint(nil, { ignore_errors = true })
    vim.notify("Linting: ON", vim.log.levels.INFO)
  else
    vim.notify("Linting: OFF", vim.log.levels.INFO)
  end
end, { silent = true, desc = "Toggle linting" })

-- ═══════════════════════════════════════════════════════════════
-- LSP ATTACH
-- ═══════════════════════════════════════════════════════════════
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("my_lsp_attach", { clear = true }),
  desc = "Set up LSP keybindings on attach",
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    local function supports(method)
      local ok, result = pcall(client.supports_method, client, method, args.buf)
      if ok then
        return result
      end
      ok, result = pcall(client.supports_method, client, method)
      return ok and result
    end
    
    if supports("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(false, { bufnr = args.buf })
    end

    -- ══════════════════════════════════════════════════════════════
    -- BUFFER-LOCAL LSP MAPS
    -- ══════════════════════════════════════════════════════════════
    local function map(keys, fn, desc)
      vim.keymap.set("n", keys, fn, { buffer = args.buf, silent = true, desc = desc })
    end

    if supports("textDocument/codeAction") then
      map("<leader>la", function()
        local ok_ap2, ap2 = pcall(require, "actions-preview")
        if ok_ap2 then
          ap2.code_actions()
        else
          vim.lsp.buf.code_action()
        end
      end, "Code action")
    end

    if supports("textDocument/rename") then
      map("<leader>lr", function()
        local ok_ir2 = pcall(require, "inc_rename")
        if ok_ir2 then
          vim.api.nvim_feedkeys(":IncRename " .. vim.fn.expand("<cword>"), "n", false)
        else
          vim.lsp.buf.rename()
        end
      end, "Rename")
    end

    -- K (hover) and <C-s> (signature help) are now set by Neovim 0.12 automatically

    if supports("textDocument/declaration") then
      map("gD", vim.lsp.buf.declaration, "Go to declaration")
    end

    if supports("textDocument/typeDefinition") then
      map("<leader>lt", vim.lsp.buf.type_definition, "Type definition")
    end

    -- gri (implementation) and grr (references) are now set by Neovim 0.12 automatically

    if supports("textDocument/definition") then
      map("gd", vim.lsp.buf.definition, "Go to definition")
    end

    if supports("workspace/symbol") then
      map("<leader>lS", "<cmd>Telescope lsp_workspace_symbols<CR>", "Workspace symbols")
    end

    if supports("textDocument/documentSymbol") then
      map("<leader>ls", "<cmd>Telescope lsp_document_symbols<CR>", "Document symbols")
    end

    map("<leader>ld", vim.diagnostic.open_float, "Line diagnostics")
    map("<leader>li", "<cmd>LspInfo<CR>", "LSP info")
    
    if supports("textDocument/inlayHint") then
      map("<leader>lH", function()
        local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
        vim.lsp.inlay_hint.enable(not enabled, { bufnr = 0 })
        vim.notify("Inlay hints: " .. (not enabled and "ON" or "OFF"), vim.log.levels.INFO)
      end, "Toggle inlay hints")
    end

    if supports("textDocument/codeLens") then
      map("<leader>lC", vim.lsp.codelens.run, "Run codelens")
      pcall(vim.lsp.codelens.enable, true, { bufnr = args.buf })
    end
  end,
})

vim.api.nvim_create_autocmd("LspDetach", {
  group = vim.api.nvim_create_augroup("my_lsp_detach", { clear = true }),
  desc = "Disable inlay hints when last LSP client detaches",
  callback = function(args)
    local clients = vim.lsp.get_clients({ bufnr = args.buf })
    if #clients <= 1 then
      vim.lsp.inlay_hint.enable(false, { bufnr = args.buf })
    end
  end,
})

vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1, on_jump = vim.diagnostic.open_float })
end, { silent = true, desc = "Prev diagnostic" })

vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1, on_jump = vim.diagnostic.open_float })
end, { silent = true, desc = "Next diagnostic" })

vim.keymap.set("n", "[q", "<cmd>cprev<CR>", { silent = true, desc = "Prev quickfix" })
vim.keymap.set("n", "]q", "<cmd>cnext<CR>", { silent = true, desc = "Next quickfix" })

vim.keymap.set("n", "<leader>gc", "<cmd>Telescope git_commits<cr>", { silent = true, desc = "Commits" })

vim.keymap.set("n", "<leader>gf", "<cmd>Telescope git_status<cr>", { silent = true, desc = "Changed files" })

vim.keymap.set("n", "<leader>gl", "<cmd>Telescope git_bcommits<cr>", { silent = true, desc = "Buffer commits" })

vim.keymap.set("n", "<leader>gD", "<cmd>DiffviewOpen<CR>", { silent = true, desc = "Diff view" })
vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory<CR>", { silent = true, desc = "File history" })

vim.keymap.set(
  "n",
  "<leader>rr",
  [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
  { silent = true, desc = "Replace word under cursor" }
)

vim.keymap.set(
  "v",
  "<leader>rr",
  [[:s///gI<Left><Left><Left><Left>]],
  { silent = true, desc = "Replace in selection" }
)

vim.keymap.set("n", "<leader>tf", function()
  vim.g.autoformat = not vim.g.autoformat
  vim.notify("Autoformat: " .. (vim.g.autoformat and "ON" or "OFF"))
end, { silent = true, desc = "Autoformat" })

vim.keymap.set("n", "<leader>tw", "<cmd>set wrap!<CR>", { silent = true, desc = "Word wrap" })
vim.keymap.set("n", "<leader>tn", "<cmd>set relativenumber!<CR>", { silent = true, desc = "Relative numbers" })
vim.keymap.set("n", "<leader>tc", "<cmd>set cursorline!<CR>", { silent = true, desc = "Cursor line" })
vim.keymap.set("n", "<leader>ts", "<cmd>set spell!<CR>", { silent = true, desc = "Spell check" })

-- ═══════════════════════════════════════════════════════════════
-- THEME
-- ═══════════════════════════════════════════════════════════════
vim.keymap.set("n", "<leader>tT", function()
  local ok, tokyonight = pcall(require, "tokyonight")
  if not ok then
    vim.notify("tokyonight.nvim not available", vim.log.levels.WARN)
    return
  end
  local current = _G._tokyonight_style or "night"
  local next_style = current == "night" and "day" or "night"
  _G._tokyonight_style = next_style
  vim.cmd("colorscheme tokyonight-" .. next_style)
  vim.opt.background = next_style == "day" and "light" or "dark"
  vim.notify("Theme: tokyonight-" .. next_style, vim.log.levels.INFO)
end, { silent = true, desc = "Toggle light/dark theme" })

-- ═══════════════════════════════════════════════════════════════
-- DIAGNOSTICS
-- ═══════════════════════════════════════════════════════════════
vim.keymap.set("n", "<leader>tl", function()
  local enabled = vim.diagnostic.is_enabled()
  vim.diagnostic.enable(not enabled)
  vim.notify("Diagnostics: " .. (not enabled and "ON" or "OFF"))
end, { silent = true, desc = "Diagnostics" })

vim.keymap.set("n", "<leader>tq", function()
  local qf_open = false
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 then
      qf_open = true
      break
    end
  end
  if qf_open then
    vim.cmd("cclose")
  else
    vim.cmd("botright copen")
  end
end, { silent = true, desc = "Quickfix list" })

-- ═══════════════════════════════════════════════════════════════
-- CONFIG RELOAD
-- ═══════════════════════════════════════════════════════════════
vim.keymap.set("n", "<leader>tr", function()
  local ok, lazy = pcall(require, "lazy")
  if not ok then
    vim.notify("lazy.nvim not available", vim.log.levels.WARN)
    return
  end
  lazy.reload()
  vim.notify("Config reloaded", vim.log.levels.INFO)
end, { silent = true, desc = "Reload config" })

vim.keymap.set("n", "<C-h>", "<C-w>h", { silent = true, desc = "Window left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { silent = true, desc = "Window down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { silent = true, desc = "Window up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { silent = true, desc = "Window right" })
vim.keymap.set("n", "<C-Up>", "<cmd>resize +2<CR>", { silent = true, desc = "Height ++" })
vim.keymap.set("n", "<C-Down>", "<cmd>resize -2<CR>", { silent = true, desc = "Height --" })
vim.keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { silent = true, desc = "Width --" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { silent = true, desc = "Width ++" })
vim.keymap.set("n", "<leader>sv", "<cmd>vsplit<CR>", { silent = true, desc = "Split vertical" })
vim.keymap.set("n", "<leader>sh", "<cmd>split<CR>", { silent = true, desc = "Split horizontal" })
vim.keymap.set("n", "<leader>sc", "<cmd>close<CR>", { silent = true, desc = "Close split" })

vim.keymap.set("v", "J", "<cmd>m '>+1<CR>gv=gv", { silent = true, desc = "Move lines down" })
vim.keymap.set("v", "K", "<cmd>m '<-2<CR>gv=gv", { silent = true, desc = "Move lines up" })
vim.keymap.set("n", "J", "mzJ`z", { silent = true, desc = "Join line (stay put)" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { silent = true, desc = "Scroll down centered" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { silent = true, desc = "Scroll up centered" })
vim.keymap.set("n", "n", "nzzzv", { silent = true, desc = "Next match centered" })
vim.keymap.set("n", "N", "Nzzzv", { silent = true, desc = "Prev match centered" })
vim.keymap.set("v", "<", "<gv", { silent = true, desc = "Indent left" })
vim.keymap.set("v", ">", ">gv", { silent = true, desc = "Indent right" })
vim.keymap.set("x", "p", [[_dP]], { silent = true, desc = "Paste (keep register)" })
vim.keymap.set("n", "]<Space>", "o<Esc>k", { silent = true, desc = "Blank line below" })
vim.keymap.set("n", "[<Space>", "O<Esc>j", { silent = true, desc = "Blank line above" })
vim.keymap.set("n", "<leader>j", "<cmd>t.<CR>", { silent = true, desc = "Duplicate line down" })
vim.keymap.set("v", "<leader>j", "<cmd>t '><CR>gv", { silent = true, desc = "Duplicate selection down" })

vim.keymap.set("n", "<C-a>", "<Plug>(dial-increment)", { silent = true, desc = "Increment" })
vim.keymap.set("n", "<C-x>", "<Plug>(dial-decrement)", { silent = true, desc = "Decrement" })
vim.keymap.set("v", "<C-a>", "<Plug>(dial-increment)", { silent = true, desc = "Increment" })
vim.keymap.set("v", "<C-x>", "<Plug>(dial-decrement)", { silent = true, desc = "Decrement" })
vim.keymap.set("v", "g<C-a>", "<Plug>(dial-increment-additional)", { silent = true, desc = "Increment alt" })
vim.keymap.set("v", "g<C-x>", "<Plug>(dial-decrement-additional)", { silent = true, desc = "Decrement alt" })

vim.keymap.set("n", "<leader>a", "ggVG", { silent = true, desc = "Select all" })
vim.keymap.set("n", "+", "<Plug>(dial-increment)", { silent = true, desc = "Increment" })
vim.keymap.set("n", "-", "<Plug>(dial-decrement)", { silent = true, desc = "Decrement" })
vim.keymap.set("v", "+", "<Plug>(dial-increment)", { silent = true, desc = "Increment" })
vim.keymap.set("v", "-", "<Plug>(dial-decrement)", { silent = true, desc = "Decrement" })
vim.keymap.set("v", "g+", "<Plug>(dial-increment-additional)", { silent = true, desc = "Increment sequential" })
vim.keymap.set("v", "g-", "<Plug>(dial-decrement-additional)", { silent = true, desc = "Decrement sequential" })

vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { silent = true, desc = "Exit terminal mode" })

vim.keymap.set("n", "<leader>pn", function()
  local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  local notes_dir = vim.fn.stdpath("data") .. "/project_notes"
  vim.fn.mkdir(notes_dir, "p")
  vim.cmd("edit " .. vim.fn.fnameescape(notes_dir .. "/" .. project_name .. ".md"))
end, { silent = true, desc = "Project notes" })
