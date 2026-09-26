local map = vim.keymap.set

map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit window" })

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- C-h/j/k/l owned by vim-tmux-navigator (normal + terminal modes)
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Grow window height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Shrink window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Shrink window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Grow window width" })

-- same resizing from terminal mode (no Esc dance: drops to normal, resizes, jumps back in)
map("t", "<C-Up>", "<C-\\><C-n><cmd>resize +2<CR>i", { desc = "Grow window height" })
map("t", "<C-Down>", "<C-\\><C-n><cmd>resize -2<CR>i", { desc = "Shrink window height" })
map("t", "<C-Left>", "<C-\\><C-n><cmd>vertical resize -2<CR>i", { desc = "Shrink window width" })
map("t", "<C-Right>", "<C-\\><C-n><cmd>vertical resize +2<CR>i", { desc = "Grow window width" })

map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })

map("n", "<C-d>", "<C-d>zz", { desc = "Half page down" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up" })
map("n", "n", "nzzzv", { desc = "Next search result" })
map("n", "N", "Nzzzv", { desc = "Prev search result" })

map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down", silent = true })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up", silent = true })

map("n", "-", "<cmd>Oil<CR>", { desc = "Open parent directory" })
map("n", "<leader>e", "<cmd>Oil --float<CR>", { desc = "Oil floating explorer" })

map("n", "g[[", "[[", { desc = "Prev section" })
map("n", "g]]", "]]", { desc = "Next section" })
