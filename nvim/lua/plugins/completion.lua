-- blink.cmp pinned to V1 (main is breaking V2 work)
return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
      keymap = { preset = "super-tab" },
      appearance = { nerd_font_variant = "mono" },
      completion = { documentation = { auto_show = false } },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        per_filetype = { sql = { inherit_defaults = true, "dadbod" } },
        providers = { dadbod = { module = "vim_dadbod_completion.blink" } },
      },
    },
    opts_extend = { "sources.default" },
  },
}
