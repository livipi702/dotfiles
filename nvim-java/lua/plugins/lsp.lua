-- mason chain + native vim.lsp API (nvim-lspconfig is data-only now)
-- NOTE: jdtls is installed via mason-tool-installer but NOT enabled via
-- mason-lspconfig / vim.lsp.enable. It is started per-buffer by nvim-jdtls
-- in ftplugin/java.lua (official ftplugin approach).
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { { "mason-org/mason.nvim", opts = {} } },
    opts = {
      ensure_installed = {
        "jdtls",
        "java-debug-adapter",
        "java-test",
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
        "lua_ls",
        "marksman",
      },
      -- jdtls is mason-installed but must NOT auto-enable:
      -- nvim-jdtls starts it per-buffer in ftplugin/java.lua.
      automatic_enable = { exclude = { "jdtls" } },
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
