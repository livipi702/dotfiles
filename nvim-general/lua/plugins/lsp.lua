-- mason chain + native vim.lsp API (nvim-lspconfig is data-only now)
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { { "mason-org/mason.nvim", opts = {} } },
    opts = {
      ensure_installed = {
        "basedpyright",
        "ruff",
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
      automatic_enable = true,
      ensure_installed = {
        "basedpyright",
        "ruff",
        "lua_ls",
        "marksman",
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
