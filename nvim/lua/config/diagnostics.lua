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
  vim.diagnostic.config({ virtual_lines = cur and false or { current_line = true } })
end, { desc = "Toggle diagnostics message" })

vim.keymap.set("n", "<leader>cy", function()
  local diags = vim.diagnostic.get(0, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 })
  if #diags == 0 then
    vim.notify("No diagnostics on line", vim.log.levels.INFO)
    return
  end
  local lines = vim.tbl_map(function(d)
    local code = d.code and tostring(d.code) .. ": " or ""
    local src = d.source and " (" .. d.source .. ")" or ""
    return code .. d.message .. src
  end, diags)
  vim.fn.setreg("+", table.concat(lines, "\n"))
  vim.notify("Yanked " .. #diags .. " diagnostic(s)", vim.log.levels.INFO)
end, { desc = "Yank line diagnostics" })
