return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      { "nvim-neotest/neotest-python", lazy = true },
      { "nvim-neotest/neotest-jest", lazy = true },
      { "nvim-neotest/neotest-go", lazy = true },
    },
    keys = {
      {
        "<leader>cT",
        function()
          require("neotest").run.run()
        end,
        desc = "Test nearest",
      },
      {
        "<leader>cF",
        function()
          require("neotest").run.run(vim.fn.expand("%"))
        end,
        desc = "Test file",
      },
      {
        "<leader>cS",
        function()
          require("neotest").summary.toggle()
        end,
        desc = "Test summary",
      },
      {
        "<leader>cO",
        function()
          require("neotest").output_panel.toggle()
        end,
        desc = "Test output",
      },
      {
        "<leader>cD",
        function()
          require("neotest").run.run({ strategy = "dap" })
        end,
        desc = "Test debug nearest",
      },
      {
        "<leader>cL",
        function()
          require("neotest").run.run_last()
        end,
        desc = "Test re-run last",
      },
      {
        "]T",
        function()
          require("neotest").jump.next({ status = "failed" })
        end,
        desc = "Next failed test",
      },
      {
        "[T",
        function()
          require("neotest").jump.prev({ status = "failed" })
        end,
        desc = "Prev failed test",
      },
    },
    config = function()
      require("config.neotest").setup()
    end,
  },
}
