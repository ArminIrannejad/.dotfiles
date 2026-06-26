vim.keymap.set("i", "<CR>", function()
  local col  = vim.fn.col(".")
  local line = vim.api.nvim_get_current_line()
  local before = line:sub(1, col - 1)
  local after  = line:sub(col)

  if before:match("{%s*$") and after:match("^%s*$") then
    return "\n}<C-o>==<C-o>O"
  end

  return "\n"
end, { buffer = true, expr = true, desc = "curly braces autopair thingy" })

