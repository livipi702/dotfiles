return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    dependencies = { "neovim/nvim-lspconfig" },
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
}
