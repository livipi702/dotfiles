return {
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeOpen" },
    keys = {
      { "<leader>e", "<cmd>NvimTreeToggle<CR>", silent = true, desc = "Explorer toggle" },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    init = function()
      if vim.fn.argc() == 1 then
        local arg = vim.fn.argv(0)
        local stat = vim.uv.fs_stat(arg)
        if stat and stat.type == "directory" then
          vim.api.nvim_create_autocmd("VimEnter", {
            once = true,
            callback = function()
              vim.schedule(function()
                local dir = vim.fn.fnamemodify(arg, ":p")
                vim.cmd.cd(vim.fn.fnameescape(dir))
                vim.cmd("enew")
                vim.cmd("NvimTreeOpen")
              end)
            end,
          })
        end
      end
    end,
    opts = {
      view = { width = 30 },
      filters = { dotfiles = false },
      hijack_netrw = true,
      disable_netrw = true,
    },
  },
}
