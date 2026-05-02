
local helpers = require("utils.helpers")
local is_dir = helpers.is_dir

local lang = require("utils.lang-config")
local CONFORM_BY_FT, CUSTOM_FORMATTERS = lang.get_conform_config()
local LINTERS_BY_FT = lang.get_linters_by_ft()

return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      pcall(function() require("nvim-autopairs").setup({}) end)
    end,
  },
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = function()
      pcall(function() require("nvim-surround").setup({}) end)
    end,
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    config = function()
      require("ibl").setup({
        indent = { char = "│" },
      })
    end,
  },

  {
    "RRethy/vim-illuminate",
    config = function()
      local ok_il, il = pcall(require, "illuminate")
      if not ok_il then return end
      il.configure({
        delay = 200,
        filetypes_exclude = {
          "NvimTree",
          "alpha",
          "toggleterm",
          "dbui",
          "qf",
          "help",
        },
      })
    end,
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
      local ok, conform = pcall(require, "conform")
      if not ok then
        vim.notify("conform.nvim not available", vim.log.levels.WARN)
        return
      end

      conform.setup({
        formatters_by_ft = CONFORM_BY_FT,
        formatters = CUSTOM_FORMATTERS,
        notify_on_error = false,
        notify_no_formatters = false,
        format_on_save = function()
          if not vim.g.autoformat then
            return
          end
          local bufname = vim.api.nvim_buf_get_name(0)
          if bufname == "" or is_dir(bufname) then
            return
          end
          local ft = vim.bo.filetype
          if ft == "" then
            return
          end
          if not CONFORM_BY_FT[ft] then
            return
          end

          local max_size = 1024 * 1024
          local stat = vim.uv.fs_stat(bufname)
          if stat and stat.size > max_size then
            vim.notify(
              ("Skipping format: file too large (%s bytes)"):format(stat.size),
              vim.log.levels.DEBUG
            )
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
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      local ok, lint = pcall(require, "lint")
      if not ok then
        vim.notify("nvim-lint not available", vim.log.levels.WARN)
        return
      end

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
    config = function()
      local ok_tc, tc = pcall(require, "todo-comments")
      if not ok_tc then return end
      tc.setup()
      vim.keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<CR>", { silent = true, desc = "Todo comments" })
      vim.keymap.set("n", "]t", function()
        require("todo-comments").jump_next()
      end, { silent = true, desc = "Next todo" })
      vim.keymap.set("n", "[t", function()
        require("todo-comments").jump_prev()
      end, { silent = true, desc = "Prev todo" })
    end,
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
    config = function()
      local ok_ir, inc = pcall(require, "inc_rename")
      if not ok_ir then
        return
      end
      inc.setup({})
    end,
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
  -- ZEN MODE
  -- ══════════════════════════════════════════════════════
  {
    "folke/zen-mode.nvim",
    keys = { { "<leader>zz", "<cmd>ZenMode<CR>", desc = "Zen mode" } },
    opts = {
      window = {
        backdrop = 0.95,
        width = 120,
        height = 0.85,
      },
      plugins = {
        options = { enabled = true, ruler = false, showcmd = false },
        twilight = { enabled = false },
        gitsigns = { enabled = true },
        tmux = { enabled = false },
        alacritty = { enabled = false },
        kitty = { enabled = false },
      },
      on_open = function()
        vim.notify("Zen mode ON", vim.log.levels.INFO)
      end,
      on_close = function()
        vim.notify("Zen mode OFF", vim.log.levels.INFO)
      end,
    },
  },

  -- ══════════════════════════════════════════════════════
  -- DIAL
  -- ══════════════════════════════════════════════════════
  {
    "monaqa/dial.nvim",
    event = "VeryLazy",
    config = function()
      local ok, dial = pcall(require, "dial")
      if not ok then
        vim.notify("dial.nvim not available", vim.log.levels.WARN)
        return
      end
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