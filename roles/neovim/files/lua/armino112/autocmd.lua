local yank_hl = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group    = yank_hl,
  pattern  = "*",
  callback = function()
    vim.hl.on_yank {
      higroup = "IncSearch",
      timeout = 200,
    }
  end,
})

local cursorline = vim.api.nvim_create_augroup("ActiveCursorLine", { clear = true })
vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
  group = cursorline,
  callback = function() vim.opt_local.cursorlineopt = "both" end,
})
vim.api.nvim_create_autocmd("WinLeave", {
  group = cursorline,
  callback = function() vim.opt_local.cursorlineopt = "number" end,
})
