vim.pack.add({
  { src = 'https://github.com/echasnovski/mini.nvim' },
  -- { src = 'https://github.com/nvim-mini/mini.pairs'},
  { src = 'https://github.com/nvim-mini/mini.jump',      version = 'stable' },
  { src = 'https://github.com/nvim-mini/mini.ai' },
  { src = 'https://github.com/nvim-mini/mini.surround' },
  { src = 'https://github.com/nvim-mini/mini.hipatterns' },
})

require("mini.surround").setup({})
require("mini.jump").setup({})
require("mini.ai").setup({})

local jump = MiniJump.jump
MiniJump.jump = function(...)
  local ic, sc = vim.o.ignorecase, vim.o.smartcase
  vim.o.ignorecase, vim.o.smartcase = false, false
  local ok, err = pcall(jump, ...)
  vim.o.ignorecase, vim.o.smartcase = ic, sc
  if not ok then error(err) end
end

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

local hipatterns = require('mini.hipatterns')
hipatterns.setup({
  highlighters = {
    todo = { pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsHack', },
    fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme', },
    hack = { pattern = '%f[%w]()HACK()%f[%W]', group = 'MiniHipatternsTodo', },
    note = { pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote', },
    hex_color = hipatterns.gen_highlighter.hex_color(),
  },
})
