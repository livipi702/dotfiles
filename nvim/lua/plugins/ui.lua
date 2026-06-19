
return {
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
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
		},
	},

	{
		"akinsho/bufferline.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			options = {
				diagnostics = "nvim_lsp",
				offsets = {
					{ filetype = "NvimTree", text = "Explorer", padding = 1 },
				},
				show_close_icon = false,
				show_buffer_close_icons = false,
			},
		},
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

	-- Noice owns command-line and LSP message UI; Snacks owns notifications.
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
		},
		config = function()
			require("noice").setup({
				lsp = {
					progress = { enabled = false },
					override = {
						["vim.lsp.util.convert_input_to_markdown_lines"] = true,
						["cmp.entry.get_documentation"] = true,
					},
				},
				notify = {
					enabled = false,
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
			{ "<leader>fn", function() require("snacks").notifier.show_history() end, desc = "Notifications" },
			{
				"<leader>nd",
				function()
					require("noice").cmd("dismiss")
				end,
				desc = "Dismiss notifications",
			},
		},
	},

	-- Snacks provides notifications, picker extras, dashboard, lazygit, and editor niceties.
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		keys = {
			{ "<leader>gg", function() require("snacks").lazygit() end, desc = "Lazygit" },
			{ "<leader>zz", function() require("snacks").zen() end, desc = "Zen mode" },
			{ "<leader>fp", function() require("snacks").picker.projects() end, desc = "Projects" },
		},
		opts = {
			bigfile = { enabled = true },
			indent = { enabled = true },
			notifier = {
				enabled = true,
				timeout = 3000,
			},
			lazygit = { enabled = true },
			picker = { enabled = true },
			words = {
				enabled = true,
				notify = false,
				filter = function(buf)
					local exclude = {
						["NvimTree"] = true,
						["snacks_dashboard"] = true,
						["toggleterm"] = true,
						["dbui"] = true,
						["qf"] = true,
						["help"] = true,
					}
					return vim.g.snacks_words ~= false
						and vim.b[buf].snacks_words ~= false
						and not exclude[vim.bo[buf].filetype]
				end,
			},
			zen = {
				enabled = true,
				win = {
					backdrop = { transparent = true, blend = 5 },
				},
			},
			dashboard = {
				preset = {
					header = table.concat({
						"                                                     ",
						"  ▓▓▓╗   ▓▓║▓▓▓▓▓▓▓╗ ▓▓▓▓▓▓╗ ▓▓║   ▓▓║▓▓║▓▓▓╗   ▓▓▓╗",
						"  ▓▓▓▓╗  ▓▓║▓▓╔════╝▓▓╔═══▓▓╗▓▓║   ▓▓║▓▓║▓▓▓▓╗ ▓▓▓▓║",
						"  ▓▓╔▓▓╗ ▓▓║▓▓▓▓▓╗  ▓▓║   ▓▓║▓▓║   ▓▓║▓▓║▓▓╔▓▓▓▓╔▓▓║",
						"  ▓▓║╚▓▓╗▓▓║▓▓╔══╝  ▓▓║   ▓▓║╚▓▓╗ ▓▓╔╝▓▓║▓▓║╚▓▓╔╝▓▓║",
						"  ▓▓║ ╚▓▓▓▓║▓▓▓▓▓▓▓╗╚▓▓▓▓▓▓╔╝ ╚▓▓▓▓╔╝ ▓▓║▓▓║ ╚═╝ ▓▓║",
						"  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
					}, "\n"),
					keys = {
						{ icon = " ", key = "f", desc = "Find file", action = ":Telescope find_files" },
						{ icon = " ", key = "r", desc = "Recent files", action = ":Telescope oldfiles" },
						{ icon = " ", key = "g", desc = "Grep text", action = ":Telescope live_grep" },
						{ icon = " ", key = "p", desc = "Projects", action = function() require("snacks").picker.projects() end },
						{ icon = " ", key = "s", desc = "Restore session", action = function() require("persistence").load() end },
						{ icon = " ", key = "c", desc = "Config", action = ":e $MYVIMRC" },
						{ icon = " ", key = "l", desc = "Lazy", action = ":Lazy" },
						{ icon = " ", key = "m", desc = "Mason", action = ":Mason" },
						{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
					},
				},
				sections = {
					{ section = "header" },
					{ section = "keys", gap = 1, padding = 1 },
					{ section = "startup" },
				},
			},
		},
	},

	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		opts = { delay = 300 },
		config = function()
			local wk = require("which-key")
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
		opts = {
			style = "night",
			transparent = false,
			terminal_colors = true,
		},
		config = function()
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
		opts = {
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
		},
	},
}
