-- On Enter after an opening "{", insert a properly indented closing "}" and
-- put the cursor on the empty inner line.
vim.keymap.set("i", "<CR>", function()
  local col  = vim.fn.col(".")
  local line = vim.api.nvim_get_current_line()
  local before = line:sub(1, col - 1)
  local after  = line:sub(col)

  -- trigger only if cursor is at end of a line that ends with "{"
  if before:match("{%s*$") and after:match("^%s*$") then
    -- newline, add "}", reindent it, then open a line above (cursor ends inside)
    return "\n}<C-o>==<C-o>O"
  end

  return "\n"
end, { buffer = true, expr = true, desc = "Smart block newline for Go" })

