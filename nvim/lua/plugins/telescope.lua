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
      telescope.load_extension("fzf")
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          telescope.load_extension("projects")
        end,
      })
    end,
  },
}
