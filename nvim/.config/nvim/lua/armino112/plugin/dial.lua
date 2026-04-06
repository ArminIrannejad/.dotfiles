vim.pack.add({
  { src = 'https://github.com/monaqa/dial.nvim'},
})

vim.keymap.set("n", "<C-a>", function() require("dial.map").manipulate("increment", "normal") end, { desc = "Dial increment" })
vim.keymap.set("n", "<C-x>", function() require("dial.map").manipulate("decrement", "normal") end, { desc = "Dial decrement" })
vim.keymap.set("n", "g<C-a>", function() require("dial.map").manipulate("increment", "gnormal") end, { desc = "Dial g-increment" })
vim.keymap.set("n", "g<C-x>", function() require("dial.map").manipulate("decrement", "gnormal") end, { desc = "Dial g-decrement" })
vim.keymap.set("x", "<C-a>", function() require("dial.map").manipulate("increment", "visual") end, { desc = "Dial increment (visual)" })
vim.keymap.set("x", "<C-x>", function() require("dial.map").manipulate("decrement", "visual") end, { desc = "Dial decrement (visual)" })
vim.keymap.set("x", "g<C-a>", function() require("dial.map").manipulate("increment", "gvisual") end, { desc = "Dial g-increment (visual)" })
vim.keymap.set("x", "g<C-x>", function() require("dial.map").manipulate("decrement", "gvisual") end, { desc = "Dial g-decrement (visual)" })

local augend = require("dial.augend")

require("dial.config").augends:register_group({
  default = {
    augend.integer.alias.decimal,
    augend.integer.alias.hex,
    augend.date.alias["%Y-%m-%d"],
    augend.constant.new({ elements = { "true", "false" }, word = true, cyclic = true }),
    augend.constant.new({ elements = { "True", "False" }, word = true, cyclic = true }),
  },
})
