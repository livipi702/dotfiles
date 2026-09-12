-- nvim-jdtls ftplugin driver (official documented approach).
-- The server itself is started in ftplugin/java.lua via start_or_attach.
return {
  {
    "mfussenegger/nvim-jdtls",
    ft = { "java" },
    dependencies = {
      "mfussenegger/nvim-dap",
      "saghen/blink.cmp",
      { "mason-org/mason.nvim", opts = {} },
    },
  },
}
