local helpers = require("utils.helpers")
local has_cmd = helpers.has_cmd

return {
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = (helpers.CURRENT_OS == "win")
        and "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release"
      or "make",
  },

  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Files" },
      { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Grep" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
      { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent" },
      { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help" },
      {
        "<leader>fd",
        function()
          require("telescope.builtin").find_files({
            cwd = vim.fn.expand("%:p:h"),
            prompt_title = "Files (current dir)",
          })
        end,
        desc = "Files (current dir)",
      },
      {
        "<leader>fs",
        function()
          require("telescope.builtin").live_grep({
            cwd = vim.fn.expand("%:p:h"),
            prompt_title = "Grep (current dir)",
          })
        end,
        desc = "Grep (current dir)",
      },
      {
        "<leader>fD",
        function()
          local dir = vim.fn.input("Dir: ", vim.fn.getcwd() .. "/", "dir")
          if dir ~= "" then
            require("telescope.builtin").find_files({ cwd = dir })
          end
        end,
        desc = "Files (pick dir)",
      },
    },
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope-fzf-native.nvim" },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")
      telescope.setup({
        defaults = {
          file_ignore_patterns = {
            "node_modules/",
            ".git/",
            "build/",
            "%.class",
            "%.o",
            "%.exe",
            "package%-lock%.json",
          },
          layout_config = {
            prompt_position = "top",
            horizontal = { preview_width = 0.5 },
          },
          sorting_strategy = "ascending",
          path_display = { "truncate" },
          mappings = {
            i = {
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
            },
          },
        },
        pickers = {
          find_files = has_cmd("fd")
              and {
                find_command = {
                  "fd",
                  "--type",
                  "f",
                  "--strip-cwd-prefix",
                  "--hidden",
                  "--exclude",
                  ".git",
                },
              }
            or {},
        },
      })
      pcall(telescope.load_extension, "fzf")
    end,
  },
}
