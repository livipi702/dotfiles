return {
  {
    "rmagatti/goto-preview",
    event = "LspAttach",
    dependencies = { "rmagatti/logger.nvim" },
    opts = {
      width = 120,
      height = 30,
      border = "rounded",
      default_mappings = true,
      dismiss_on_move = false,
      stack_floating_preview_windows = true,
      preview_window_title = { enable = true, position = "left" },
    },
  },

  {
    "aznhe21/actions-preview.nvim",
    event = "LspAttach",
    opts = {
      telescope = {
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
          width = 0.8,
          height = 0.9,
          prompt_position = "top",
          preview_height = 0.6,
        },
      },
    },
  },
}
