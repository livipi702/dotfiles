return {
  {
    "ahmedkhalf/project.nvim",
    event = "VeryLazy",
    config = function()
      local ok_pr, project = pcall(require, "project_nvim")
      if not ok_pr then
        return
      end
      project.setup({
        detection_methods = { "pattern" },
        patterns = {
          ".git",
          "Makefile",
          "package.json",
          "Cargo.toml",
          "go.mod",
          "pom.xml",
          "build.gradle",
          "build.gradle.kts",
          "pyproject.toml",
          "CMakeLists.txt",
        },
        show_hidden = true,
        silent_chdir = true,
      })
    end,
    keys = {
      { "<leader>fp", "<cmd>Telescope projects<CR>", desc = "Projects" },
    },
  },
}
