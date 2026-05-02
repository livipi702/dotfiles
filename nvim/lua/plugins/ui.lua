
return {
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			local ok_ll, lualine = pcall(require, "lualine")
			if not ok_ll then
				return
			end
			lualine.setup({
				options = {
					theme = "tokyonight",
					section_separators = { left = "", right = "" },
					component_separators = { left = "", right = "" },
				},
				sections = {
					lualine_a = { "mode" },
					lualine_b = { "branch", "diff", "diagnostics" },
					lualine_c = { { "filename", path = 1 } },
					lualine_x = { "encoding", "filetype" },
					lualine_y = { "progress" },
					lualine_z = { "location" },
				},
			})
		end,
	},

	{
		"akinsho/bufferline.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			local ok_bl, bufferline = pcall(require, "bufferline")
			if not ok_bl then
				return
			end
			bufferline.setup({
				options = {
					diagnostics = "nvim_lsp",
					offsets = {
						{ filetype = "NvimTree", text = "Explorer", padding = 1 },
					},
					show_close_icon = false,
					show_buffer_close_icons = false,
				},
			})
		end,
	},

	-- ═══════════════════════════════════════════════════════════════════════════════════════
	-- FIDGET - Better LSP progress notifications (replaces noice progress)
	-- ═══════════════════════════════════════════════════════════════════════════════════════
	{
		"j-hui/fidget.nvim",
		event = "LspAttach",
		opts = {
			progress = {
				poll_rate = 0.5,
				suppress_on_insert = true,
				ignore_done_already = true,
				ignore_empty_message = true,
				clear_on_detach = function(client_id)
					local client = vim.lsp.get_client_by_id(client_id)
					return client and client.name ~= "basedpyright"
				end,
				display = {
					render_limit = 3,
					done_ttl = 2,
				},
			},
			notification = {
				override_vim_notify = false,
				window = {
					winblend = 0,
					border = "none",
				},
			},
		},
	},

	{
		"folke/noice.nvim",
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
			{
				"rcarriga/nvim-notify",
				opts = {
					timeout = 3000,
					max_height = function()
						return math.floor(vim.o.lines * 0.75)
					end,
					max_width = function()
						return math.floor(vim.o.columns * 0.75)
					end,
					render = "wrapped-compact",
					stages = "fade",
				},
			},
		},
		config = function()
			local ok_no, noice = pcall(require, "noice")
			if not ok_no then
				return
			end
			noice.setup({
				lsp = {
					progress = { enabled = false },
					override = {
						["vim.lsp.util.convert_input_to_markdown_lines"] = true,
						["cmp.entry.get_documentation"] = true,
					},
				},
				presets = {
					bottom_search = true,
					command_palette = true,
					long_message_to_split = true,
					lsp_doc_border = true,
					inc_rename = true,
				},
				routes = {
					{ filter = { event = "msg_show", kind = "", find = "written" }, opts = { skip = true } },
					{ filter = { event = "msg_show", kind = "", find = "fewer lines" }, opts = { skip = true } },
					{ filter = { event = "msg_show", kind = "", find = "more lines" }, opts = { skip = true } },
					{ filter = { event = "msg_show", kind = "", find = "line less" }, opts = { skip = true } },
				},
			})
		end,
		keys = {
			{ "<leader>fn", "<cmd>Telescope notify<CR>", desc = "Notifications" },
			{
				"<leader>nd",
				function()
					require("noice").cmd("dismiss")
				end,
				desc = "Dismiss notifications",
			},
		},
	},

	{
		"goolord/alpha-nvim",
		event = "VimEnter",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			if vim.fn.argc() > 0 or vim.fn.line2byte(vim.fn.line("$")) ~= -1 then
				return
			end
			local ok_a, alpha = pcall(require, "alpha")
			if not ok_a then
				return
			end
			local dashboard = require("alpha.themes.dashboard")

			dashboard.section.header.val = {
				"                                                     ",
				"  ▓▓▓╗   ▓▓║▓▓▓▓▓▓▓╗ ▓▓▓▓▓▓╗ ▓▓║   ▓▓║▓▓║▓▓▓╗   ▓▓▓╗",
				"  ▓▓▓▓╗  ▓▓║▓▓╔════╝▓▓╔═══▓▓╗▓▓║   ▓▓║▓▓║▓▓▓▓╗ ▓▓▓▓║",
				"  ▓▓╔▓▓╗ ▓▓║▓▓▓▓▓╗  ▓▓║   ▓▓║▓▓║   ▓▓║▓▓║▓▓╔▓▓▓▓╔▓▓║",
				"  ▓▓║╚▓▓╗▓▓║▓▓╔══╝  ▓▓║   ▓▓║╚▓▓╗ ▓▓╔╝▓▓║▓▓║╚▓▓╔╝▓▓║",
				"  ▓▓║ ╚▓▓▓▓║▓▓▓▓▓▓▓╗╚▓▓▓▓▓▓╔╝ ╚▓▓▓▓╔╝ ▓▓║▓▓║ ╚═╝ ▓▓║",
				"  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
			}
			dashboard.section.buttons.val = {
				dashboard.button("f", "  Find file", ":Telescope find_files<CR>"),
				dashboard.button("r", "  Recent files", ":Telescope oldfiles<CR>"),
				dashboard.button("g", "  Grep text", ":Telescope live_grep<CR>"),
				dashboard.button("p", "  Projects", ":Telescope projects<CR>"),
				dashboard.button("s", "  Restore session", [[<cmd>lua require("persistence").load()<CR>]]),
				dashboard.button("c", "  Config", ":e $MYVIMRC<CR>"),
				dashboard.button("l", "  Lazy", ":Lazy<CR>"),
				dashboard.button("m", "  Mason", ":Mason<CR>"),
				dashboard.button("q", "  Quit", ":qa<CR>"),
			}

			vim.api.nvim_create_autocmd("User", {
				pattern = "LazyDone",
				once = true,
				callback = function()
					local stats = require("lazy").stats()
					local ms = math.floor(stats.startuptime * 100 + 0.5) / 100
					dashboard.section.footer.val = "  "
						.. stats.loaded
						.. "/"
						.. stats.count
						.. " plugins in "
						.. ms
						.. "ms"
					pcall(vim.cmd.AlphaRedraw)
				end,
			})

			alpha.setup(dashboard.config)

			vim.api.nvim_create_autocmd("User", {
				pattern = "AlphaReady",
				callback = function()
					vim.opt_local.foldenable = false
					vim.opt_local.cursorline = false
				end,
			})
		end,
	},

	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		config = function()
			local wk = require("which-key")
			wk.setup({ delay = 300 })
			wk.add({
				{ "<leader>f", group = "Find" },
				{ "<leader>c", group = "Code" },
				{ "<leader>l", group = "LSP" },
				{ "<leader>d", group = "Debug" },
				{ "<leader>g", group = "Git" },
				{ "<leader>h", group = "Harpoon" },
				{ "<leader>t", group = "Toggle" },
				{ "<leader>s", group = "Split/Search/Swap" },
				{ "<leader>b", group = "Buffer" },
				{ "<leader>S", group = "Session" },
				{ "<leader>v", group = "View (live server/API)" },
				{ "gp", group = "Peek (preview)" },
			})
		end,
	},

	{
		"folke/tokyonight.nvim",
		priority = 1000,
		config = function()
			require("tokyonight").setup({
				style = "night",
				transparent = false,
				terminal_colors = true,
			})
			vim.cmd("colorscheme tokyonight-night")
		end,
	},

	-- ═══════════════════════════════════════════════════════════════════════════════════════
	-- SMOOTH CURSOR
	-- ═══════════════════════════════════════════════════════════════════════════════════════
	{
		"gen740/smoothcursor.nvim",
		event = "VeryLazy",
		opts = {
			autostart = true,
			cursor = "|",
			texthl = "SmoothCursor",
			linehl = nil,
			type = "default",
			fancy = {
				enable = true,
				head = { cursor = "\u{25b7}", texthl = "SmoothCursor", linehl = nil },
				body = { cursor = "\u{f0c1}", texthl = "SmoothCursor" },
				tail = { cursor = "\u{2022}", texthl = "SmoothCursor" },
			},
		},
	},

	{
		"hedyhli/outline.nvim",
		cmd = "Outline",
		keys = {
			{ "<leader>lo", "<cmd>Outline<CR>", desc = "Symbol outline" },
		},
		config = function()
			local ok_ol, outline = pcall(require, "outline")
			if not ok_ol then
				return
			end
			outline.setup({
				outline_window = { width = 30, relative_width = false },
				symbols = {
					icons = {
						File = { icon = "\u{f088}", hl = "Identifier" },
						Module = { icon = "\u{f1a7}", hl = "Include" },
						Namespace = { icon = "\u{f217}", hl = "Include" },
						Package = { icon = "\u{f17d}", hl = "Include" },
						Class = { icon = "\u{e0b2}", hl = "Type" },
						Method = { icon = "\u{0192}", hl = "Function" },
						Property = { icon = "\u{e08c}", hl = "Identifier" },
						Field = { icon = "\u{f124}", hl = "Identifier" },
						Constructor = { icon = "\u{e0c7}", hl = "Special" },
						Enum = { icon = "\u{e0af}", hl = "Type" },
						Interface = { icon = "\u{f170}", hl = "Type" },
						Function = { icon = "\u{f292}", hl = "Function" },
						Variable = { icon = "\u{e08f}", hl = "Constant" },
						Constant = { icon = "\u{e03f}", hl = "Constant" },
					},
				},
			})
		end,
	},
}