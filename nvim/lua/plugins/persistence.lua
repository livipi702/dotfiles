return {
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    config = function()
      local ok_pe, persistence = pcall(require, "persistence")
      if not ok_pe then
        return
      end
      persistence.setup({
        options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp" },
      })
    end,
    keys = {
      {
        "<leader>Ss",
        function()
          require("persistence").load()
        end,
        desc = "Restore session (cwd)",
      },
      {
        "<leader>Sl",
        function()
          require("persistence").load({ last = true })
        end,
        desc = "Restore last session",
      },
      {
        "<leader>Sd",
        function()
          require("persistence").stop()
        end,
        desc = "Stop session save",
      },
      {
        "<leader>SS",
        function()
          require("persistence").select()
        end,
        desc = "Select session",
      },
    },
  },
}
