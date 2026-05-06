return {
  {
    "rest-nvim/rest.nvim",
    ft = "http",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    cmd = { "Rest", "Rest run", "Rest last" },
    keys = {
      { "<leader>vR", "<cmd>Rest run<CR>", desc = "Run API request" },
      { "<leader>vP", "<cmd>Rest last<CR>", desc = "Re-run last request" },
    },
  },
}