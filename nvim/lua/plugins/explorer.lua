return {
  {
    "stevearc/oil.nvim",
    lazy = false, -- lazy-loading breaks oil
    dependencies = { { "nvim-mini/mini.icons", opts = {} } },
    ---@module "oil"
    ---@type oil.SetupOpts
    opts = {
      default_file_explorer = true,
      columns = { "icon" },
      lsp_file_methods = { enabled = true, timeout_ms = 1000 },
      constrain_cursor = "editable",
      float = { win_options = { winblend = 20 } },
      view_options = {
        show_hidden = true,
        is_always_hidden = function(name)
          return name == ".git" or name == "node_modules" or name == "dist"
        end,
      },
    },
  },
}
