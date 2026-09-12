-- mason chain + native vim.lsp API (nvim-lspconfig is data-only now)
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { { "mason-org/mason.nvim", opts = {} } },
    opts = {
      ensure_installed = {
        "prettierd",
        "stylua",
        "tree-sitter-cli",
      },
    },
  },

  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
    },
    opts = {
      ensure_installed = {
        "vtsls",
        "tailwindcss",
        "eslint",
        "emmet_language_server",
        "jsonls",
        "yamlls",
        "lua_ls",
        "marksman",
        -- NOTE: swap vtsls -> tsgo/tsc later for the faster native TS server.
      },
    },
    config = function(_, opts)
      local ok, blink = pcall(require, "blink.cmp")
      if ok then
        vim.lsp.config("*", { capabilities = blink.get_lsp_capabilities() })
      end
      require("mason-lspconfig").setup(opts)
    end,
  },
}
