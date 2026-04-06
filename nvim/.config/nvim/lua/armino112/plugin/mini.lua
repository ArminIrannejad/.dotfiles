vim.pack.add({
  { src = 'https://github.com/echasnovski/mini.nvim' },
  -- { src = 'https://github.com/nvim-mini/mini.pairs'},
})

require("mini.surround").setup({})

-- require("mini.pairs").setup({
--   modes = { insert = true, command = true, terminal = false },
--   skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
--   skip_ts = { "string" },
--   skip_unbalanced = true,
--   markdown = true,
-- })
