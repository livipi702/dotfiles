-- nvim-treesitter main branch + treesitter-modules (old configs.setup is gone)
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    dependencies = { "MeanderingProgrammer/treesitter-modules.nvim" },
    config = function()
      require("treesitter-modules").setup({
        ensure_installed = {
          "java",
          "javadoc",
          "xml",
          "properties",
          "lua",
          "luadoc",
          "vim",
          "vimdoc",
          "markdown",
          "markdown_inline",
          "dockerfile",
          "bash",
          "regex",
        },
        highlight = { enable = true },
        indent = { enable = true },
        fold = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "gnn",
            node_incremental = "gni",
            scope_incremental = "gnc",
            node_decremental = "gnm",
          },
        },
      })
    end,
  },
}
