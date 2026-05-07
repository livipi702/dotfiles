local helpers = require("utils.helpers")
local get_python = helpers.get_python

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
      local neotest = require("neotest")
      local adapters = {}
      local np = require("neotest-python")
      adapters[#adapters + 1] = np({
        dap = { justMyCode = false },
        runner = "pytest",
        python = get_python(),
      })
      local nj = require("neotest-jest")
      adapters[#adapters + 1] = nj({ jestCommand = "npx jest" })
      local ngo = require("neotest-go")
      adapters[#adapters + 1] = ngo({
        experimental = {
          test_table = true,
        },
      })
      neotest.setup({
        adapters = adapters,
        status = { virtual_text = true },
        output = { open_on_run = true },
        quickfix = {
          open = function()
            local ok_trouble = pcall(require, "trouble")
            if ok_trouble then
              require("trouble").open({ mode = "quickfix" })
            else
              vim.cmd("copen")
            end
          end,
        },
      })
    end,
  },
}
