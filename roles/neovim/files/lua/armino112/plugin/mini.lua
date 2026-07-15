vim.pack.add({
  { src = 'https://github.com/echasnovski/mini.nvim' },
  { src = 'https://github.com/nvim-mini/mini.jump',  version = 'stable' },
  { src =  'https://github.com/nvim-mini/mini.ai'}
  -- { src = 'https://github.com/nvim-mini/mini.pairs'},
})

require("mini.surround").setup({})
require("mini.jump").setup({})
require("mini.ai").setup({})

vim.keymap.set({ "n", "x", "o" }, ",", function()
  local backward = MiniJump.state.backward
  MiniJump.jump(nil, not backward)
  MiniJump.state.backward = backward
end, { desc = "Jump to previous target" })

-- require("mini.pairs").setup({
--   modes = { insert = true, command = true, terminal = false },
--   skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
--   skip_ts = { "string" },
--   skip_unbalanced = true,
--   markdown = true,
-- })
