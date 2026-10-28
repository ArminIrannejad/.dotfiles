vim.pack.add({ { src = 'https://github.com/sphamba/smear-cursor.nvim' } })

require("smear_cursor").setup({
  smear_between_buffers = true,
  smear_insert_mode = true,
  stiffness = 0.7,
  trailing_stiffness = 0.4,
  time_interval = 8,
  legacy_computing_symbols_support = true,
})
