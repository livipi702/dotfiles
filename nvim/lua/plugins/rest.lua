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
    config = function()
      local ok, rest = pcall(require, "rest-nvim")
      if not ok or not rest.setup then
        return
      end
      rest.setup({
        client = "curl",
        env_file = ".env",
        env_pattern = ".env",
        env_edit_command = "tabedit",
        encode_url = true,
        highlight = {
          enable = true,
          timeout = 750,
        },
        result = {
          show_url = true,
          show_http_info = true,
          show_headers = true,
          formatters = {
            json = "jq",
            html = function(body)
              return body
            end,
          },
        },
        jump_to_request = false,
      })
    end,
  },
}