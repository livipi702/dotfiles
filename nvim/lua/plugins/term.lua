return {
  {
    "akinsho/toggleterm.nvim",
    opts = {
      size = 15,
      open_mapping = [[<C-t>]],
      direction = "horizontal",
      shade_terminals = true,
      on_open = function(_)
        vim.cmd("startinsert")
      end,
    },
  },

  {
    "barrettruth/live-server.nvim",
    ft = { "html", "css", "javascript", "javascriptreact", "typescript", "typescriptreact", "ejs" },
    cmd = { "LiveServerStart", "LiveServerStop" },
    keys = {
      { "<leader>vs", function() require("config.live-server").start_default_server() end, desc = "Live server start (port 8080)" },
      { "<leader>vS", function() require("config.live-server").start_alt_server(3000) end, desc = "Live server start (port 3000)" },
      { "<leader>vx", function() require("config.live-server").stop_all_servers() end, desc = "Live server stop" },
    },
    config = function()
      require("config.live-server").setup()
    end,
  },
}
