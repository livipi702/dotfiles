vim.diagnostic.config({
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  signs = true,
  virtual_text = false,
  virtual_lines = { current_line = true },
  float = { border = "rounded", source = "if_many" },
  jump = { wrap = true },
})

vim.keymap.set("n", "gK", function()
  local cur = vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = not cur })
end, { desc = "Toggle diagnostics message" })
