-- require('vim._core.ui2').enable({})
vim.opt.cmdheight = 0

vim.pack.add({
  { src = "https://github.com/rachartier/tiny-cmdline.nvim" },
})

require("tiny-cmdline").setup({
  width = { value = "60%", min = 40, max = 80 },
  position = { x = "50%", y = "25%" },
  native_types = { "/", "?" },
  on_reposition = require("tiny-cmdline").adapters.blink,
})
