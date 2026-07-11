
vim.pack.add({
  'https://github.com/hat0uma/csvview.nvim',
  'https://github.com/cameron-wags/rainbow_csv.nvim',
})

require("csvview").setup()

pcall(function()
  require("rainbow_csv").setup({})
end)
