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
        "sqlfmt",
        "shfmt",
        "taplo",
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
      automatic_enable = true,
      ensure_installed = {
        "vtsls",
        "tailwindcss",
        "eslint",
        "emmet_language_server",
        "jsonls",
        "yamlls",
        "lua_ls",
        "marksman",
        -- NOTE: swap vtsls -> tsc later for the faster native TS server (TS 7+, tsc --lsp --stdio).
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
