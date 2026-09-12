return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Buffer keymaps" },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-mini/mini.icons" },
    opts = {
      options = { theme = "auto", globalstatus = true },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff" },
        lualine_c = {
          { "filename", path = 1, symbols = { modified = " [+]", readonly = " [-]", unnamed = "[No Name]" } },
          { "diagnostics", symbols = { error = "E:", warn = "W:", info = "I:", hint = "H:" } },
        },
        lualine_x = {
          { "encoding", show_bomb = true, cond = function() return vim.bo.fileencoding ~= "utf-8" end },
          { "fileformat", symbols = { unix = "LF", dos = "CRLF", mac = "CR" }, cond = function() return vim.bo.fileformat ~= "unix" end },
          "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
  {
    -- seamless C-h/j/k/l with tmux panes (christoomey plugin both sides)
    "christoomey/vim-tmux-navigator",
    lazy = false,
  },
}
