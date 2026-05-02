local lang = require("utils.lang-config")
local TREESITTER_LANGS = lang.get_treesitter_langs()
local PARSER_DIR = vim.fn.stdpath("data") .. "/treesitter-parsers"

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    dependencies = {},
    config = function()
      local ok_ts, ts = pcall(require, "nvim-treesitter")
      if not ok_ts then
        vim.notify("Failed to load nvim-treesitter", vim.log.levels.WARN)
        return
      end

      vim.fn.mkdir(PARSER_DIR .. "/parser", "p")

      ts.setup({
        install_dir = PARSER_DIR,
      })

      vim.schedule(function()
        local installed = ts.get_installed()
        for _, lang in ipairs(TREESITTER_LANGS) do
          if not vim.list_contains(installed, lang) then
            pcall(ts.install, lang)
          end
        end
      end)
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = {
          lookahead = true,
        },
        move = {
          set_jumps = true,
        },
      })

      -- ── Select keymaps (visual & operator-pending) ──────────
      vim.keymap.set({ "x", "o" }, "af", function()
        require("nvim-treesitter-textobjects.select").select_textobject("@function.outer", "textobjects")
      end, { silent = true, desc = "Select outer function" })

      vim.keymap.set({ "x", "o" }, "if", function()
        require("nvim-treesitter-textobjects.select").select_textobject("@function.inner", "textobjects")
      end, { silent = true, desc = "Select inner function" })

      vim.keymap.set({ "x", "o" }, "ac", function()
        require("nvim-treesitter-textobjects.select").select_textobject("@class.outer", "textobjects")
      end, { silent = true, desc = "Select outer class" })

      vim.keymap.set({ "x", "o" }, "ic", function()
        require("nvim-treesitter-textobjects.select").select_textobject("@class.inner", "textobjects")
      end, { silent = true, desc = "Select inner class" })

      vim.keymap.set({ "x", "o" }, "aa", function()
        require("nvim-treesitter-textobjects.select").select_textobject("@parameter.outer", "textobjects")
      end, { silent = true, desc = "Select outer argument" })

      vim.keymap.set({ "x", "o" }, "ia", function()
        require("nvim-treesitter-textobjects.select").select_textobject("@parameter.inner", "textobjects")
      end, { silent = true, desc = "Select inner argument" })

      vim.keymap.set({ "x", "o" }, "ai", function()
        require("nvim-treesitter-textobjects.select").select_textobject("@conditional.outer", "textobjects")
      end, { silent = true, desc = "Select outer conditional" })

      vim.keymap.set({ "x", "o" }, "ii", function()
        require("nvim-treesitter-textobjects.select").select_textobject("@conditional.inner", "textobjects")
      end, { silent = true, desc = "Select inner conditional" })

      vim.keymap.set({ "x", "o" }, "al", function()
        require("nvim-treesitter-textobjects.select").select_textobject("@loop.outer", "textobjects")
      end, { silent = true, desc = "Select outer loop" })

      vim.keymap.set({ "x", "o" }, "il", function()
        require("nvim-treesitter-textobjects.select").select_textobject("@loop.inner", "textobjects")
      end, { silent = true, desc = "Select inner loop" })

      -- ── Move keymaps (normal) ──────────────────────────────
      vim.keymap.set({ "n", "x", "o" }, "]f", function()
        require("nvim-treesitter-textobjects.move").goto_next_start("@function.outer", "textobjects")
      end, { silent = true, desc = "Next function start" })

      vim.keymap.set({ "n", "x", "o" }, "[f", function()
        require("nvim-treesitter-textobjects.move").goto_previous_start("@function.outer", "textobjects")
      end, { silent = true, desc = "Previous function start" })

      vim.keymap.set({ "n", "x", "o" }, "]c", function()
        require("nvim-treesitter-textobjects.move").goto_next_start("@class.outer", "textobjects")
      end, { silent = true, desc = "Next class start" })

      vim.keymap.set({ "n", "x", "o" }, "[c", function()
        require("nvim-treesitter-textobjects.move").goto_previous_start("@class.outer", "textobjects")
      end, { silent = true, desc = "Previous class start" })

      vim.keymap.set({ "n", "x", "o" }, "]a", function()
        require("nvim-treesitter-textobjects.move").goto_next_start("@parameter.inner", "textobjects")
      end, { silent = true, desc = "Next parameter" })

      vim.keymap.set({ "n", "x", "o" }, "[a", function()
        require("nvim-treesitter-textobjects.move").goto_previous_start("@parameter.inner", "textobjects")
      end, { silent = true, desc = "Previous parameter" })

      -- ── Swap keymaps (normal) ──────────────────────────────
      vim.keymap.set("n", "<leader>sa", function()
        require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner")
      end, { silent = true, desc = "Swap with next parameter" })

      vim.keymap.set("n", "<leader>sA", function()
        require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner")
      end, { silent = true, desc = "Swap with previous parameter" })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "BufReadPost",
    config = function()
      local ok_ctx, ctx = pcall(require, "treesitter-context")
      if not ok_ctx then
        return
      end
      ctx.setup({
        enable = true,
        max_lines = 3,
      })
    end,
  },

  {
    "windwp/nvim-ts-autotag",
    event = "InsertEnter",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {},
  },
}
