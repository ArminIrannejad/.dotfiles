vim.pack.add({
  { src = 'https://github.com/nvzone/showkeys' },
})

require("showkeys").setup({
  timeout = 2,
  maxkeys = 6,
  position = "top-right",
})
