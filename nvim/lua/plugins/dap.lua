return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = { { "mason-org/mason.nvim", opts = {} } },
        opts = {
          ensure_installed = { "js-debug-adapter" },
          automatic_installation = false,
        },
      },
    },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Step over" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Step out" },
      { "<leader>dr", function() require("dap").restart() end, desc = "Restart" },
      { "<leader>dx", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>dR", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()
      dap.listeners.after.event_initialized["dapui"] = function()
        dapui.open()
      end
      for _, ev in ipairs({ "event_terminated", "event_exited" }) do
        dap.listeners.before[ev]["dapui"] = function()
          dapui.close()
        end
      end
      -- pwa-node attach/launch covers Vite (dev) + Hono (tsx/node)
      for _, adapter in ipairs({ "pwa-node", "pwa-chrome" }) do
        if not dap.adapters[adapter] then
          dap.adapters[adapter] = {
            type = "server",
            host = "localhost",
            port = "${port}",
            executable = { command = "js-debug-adapter", args = { "${port}" } },
          }
        end
      end
      for _, lang in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact" }) do
        dap.configurations[lang] = {
          { type = "pwa-node", request = "launch", name = "Launch file", program = "${file}", cwd = "${workspaceFolder}" },
          { type = "pwa-node", request = "attach", name = "Attach", processId = require("dap.utils").pick_process, cwd = "${workspaceFolder}" },
        }
      end
    end,
  },
}
