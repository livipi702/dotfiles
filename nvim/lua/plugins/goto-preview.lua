return {
  {
    "rmagatti/goto-preview",
    event = "LspAttach",
    dependencies = { "rmagatti/logger.nvim" },
    config = function()
      local ok_gp, gp = pcall(require, "goto-preview")
      if not ok_gp then
        return
      end
      gp.setup({
        width = 120,
        height = 30,
        border = "rounded",
        dismiss_on_move = false,
        stack_floating_preview_windows = true,
        preview_window_title = { enable = true, position = "left" },
      })
    end,
    keys = {
      {
        "gpd",
        function()
          require("goto-preview").goto_preview_definition()
        end,
        desc = "Peek definition",
      },
      {
        "gpr",
        function()
          require("goto-preview").goto_preview_references()
        end,
        desc = "Peek references",
      },
      {
        "gpi",
        function()
          require("goto-preview").goto_preview_implementation()
        end,
        desc = "Peek implementation",
      },
      {
        "gpt",
        function()
          require("goto-preview").goto_preview_type_definition()
        end,
        desc = "Peek type definition",
      },
      {
        "gP",
        function()
          require("goto-preview").close_all_win()
        end,
        desc = "Close all previews",
      },
    },
  },

  {
    "aznhe21/actions-preview.nvim",
    event = "LspAttach",
    config = function()
      local ok_ap, ap = pcall(require, "actions-preview")
      if not ok_ap then
        return
      end
      ap.setup({
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
      })
    end,
  },
}
