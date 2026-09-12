-- render-markdown: in-buffer markdown viewing (needs markdown parsers)
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
    ---@module "render-markdown"
    ---@type render.md.UserConfig
    opts = {},
  },
}
