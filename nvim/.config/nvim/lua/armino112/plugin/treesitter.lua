vim.pack.add({
  'https://github.com/nvim-treesitter/nvim-treesitter',
})

require('nvim-treesitter').setup({
  install_dir = vim.fn.stdpath('data') .. '/site',
})

require('nvim-treesitter').install({
  "python",
  "c",
  "bash",
  "lua",
  "json",
  "sql",
  "haskell",
  "markdown",
})
