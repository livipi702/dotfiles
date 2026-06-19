
local lang = require("utils.lang-config")
local CONFORM_BY_FT, CUSTOM_FORMATTERS = lang.get_conform_config()
local LINTERS_BY_FT = lang.get_linters_by_ft()

return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    opts = {},
  },
  -- ══════════════════════════════════════════════════════
  -- BREADCRUMBS
  -- ══════════════════════════════════════════════════════
  {
    "Bekaboo/dropbar.nvim",
    event = "BufReadPost",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      bar = {
        sources = function(_, _)
          local sources = require("dropbar.sources")
          local utils = require("dropbar.utils")
          return {
            utils.source.fallback({ sources.lsp, sources.treesitter }),
          }
        end,
        update_events = {
          win = { "CursorMoved", "CursorMovedI", "WinResized" },
          buf = {
            "BufModifiedSet",
            "FileChangedShellPost",
            "TextChanged",
            "TextChangedI",
            "ModeChanged",
          },
          global = { "DirChanged", "VimResized" },
        },
      },
    },
    keys = {
      {
        "<leader>;",
        function()
          require("dropbar.api").pick()
        end,
        desc = "Pick symbols in winbar",
      },
    },
  },

  -- ══════════════════════════════════════════════════════
  -- CONFORM.NVIM
  -- ══════════════════════════════════════════════════════
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = { "ConformInfo", "Format" },
    keys = {
      {
        "<leader>lf",
        function()
          require("conform").format({ bufnr = 0, async = true, lsp_format = "fallback", timeout_ms = 5000 })
        end,
        mode = { "n", "v" },
        desc = "Format",
      },
    },
    config = function()
      local conform = require("conform")
      conform.setup({
        formatters_by_ft = CONFORM_BY_FT,
        formatters = CUSTOM_FORMATTERS,
        notify_on_error = false,
        notify_no_formatters = false,
        format_on_save = function(bufnr)
          if not vim.g.autoformat then
            return
          end
          local bufname = vim.api.nvim_buf_get_name(bufnr)
          local stat = vim.uv.fs_stat(bufname)
          if stat and stat.size > 1024 * 1024 then
            return
          end
          return { timeout_ms = 1000, lsp_format = "fallback" }
        end,
      })

      vim.api.nvim_create_user_command("Format", function()
        conform.format({ bufnr = 0, lsp_format = "fallback", timeout_ms = 5000 })
      end, { desc = "Format current buffer" })
    end,
  },

  -- ══════════════════════════════════════════════════════
  -- NVIM-LINT
  -- ══════════════════════════════════════════════════════
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "mason-org/mason.nvim" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = LINTERS_BY_FT

      vim.g.linting_enabled = true

      vim.schedule(function()
        if vim.g.linting_enabled and LINTERS_BY_FT[vim.bo.filetype] then
          local ok_lint, err = pcall(function()
            lint.try_lint(nil, { ignore_errors = true })
          end)
          if not ok_lint then
            vim.notify("Initial lint failed: " .. tostring(err), vim.log.levels.DEBUG)
          end
        end
      end)

      local lint_augroup = vim.api.nvim_create_augroup("nvim_lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        group = lint_augroup,
        callback = function()
          if vim.g.linting_enabled then
            local ok_lint, err = pcall(function()
              lint.try_lint(nil, { ignore_errors = true })
            end)
            if not ok_lint then
              vim.notify("Lint failed: " .. tostring(err), vim.log.levels.DEBUG)
            end
          end
        end,
      })
    end,
  },

  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "<leader>ft", "<cmd>TodoTelescope<CR>", desc = "Todo comments" },
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next todo" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Prev todo" },
    },
  },

  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>lx", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Buffer diagnostics" },
      { "<leader>lX", "<cmd>Trouble diagnostics toggle<CR>", desc = "Workspace diagnostics" },
    },
    opts = {},
  },

  {
    "mbbill/undotree",
    keys = {
      { "<leader>tu", "<cmd>UndotreeToggle<CR>", desc = "Undo tree" },
    },
  },

  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    keys = {
      {
        "<leader>sR",
        function()
          require("grug-far").open()
        end,
        desc = "Search & replace (project)",
      },
    },
    opts = {},
  },

  {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    opts = {},
  },

  -- ══════════════════════════════════════════════════════
  -- COMMENTS
  -- ══════════════════════════════════════════════════════
  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- ══════════════════════════════════════════════════════
  -- COLORIZER
  -- ══════════════════════════════════════════════════════
  {
    "NvChad/nvim-colorizer.lua",
    event = "BufReadPost",
    opts = {
      filetypes = {
        "css", "html", "javascript", "typescript",
        "javascriptreact", "typescriptreact", "lua", "vim",
      },
      user_default_options = {
        RGB = true,
        RRGGBB = true,
        RRGGBBAA = true,
        rgb_fn = true,
        hsl_fn = true,
        css = true,
        css_fn = true,
        mode = "background",
        tailwind = true,
        sass = { enable = false },
      },
    },
  },

  -- ══════════════════════════════════════════════════════
  -- DIAL
  -- ══════════════════════════════════════════════════════
  {
    "monaqa/dial.nvim",
    event = "VeryLazy",
    config = function()
      local augend = require("dial.augend")
      require("dial.config").augends:register_group({
        default = {
          augend.constant.new({
            elements = { "true", "false" },
            word = true,
            cyclic = true,
          }),
          augend.constant.new({
            elements = { "&&", "||" },
            word = false,
            cyclic = true,
          }),
          augend.date.alias["%Y-%m-%d"],
          augend.date.alias["%Y/%m/%d"],
          augend.date.alias["%d/%m/%Y"],
          augend.date.alias["%H:%M:%S"],
          augend.date.alias["%H:%M"],
          augend.integer.alias.decimal,
          augend.integer.alias.hex,
          augend.hexcolor.new({ case = "lower" }),
          augend.semver.alias.semver,
        },
      })
    end,
  },
}
