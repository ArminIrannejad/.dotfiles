vim.pack.add({ "https://github.com/ArminIrannejad/tarminal.nvim" })
require("tarminal").setup()

vim.keymap.set("n", "<leader>ts", function() require("tarminal").toggle() end, { desc = "Toggle shell terminal" })
vim.keymap.set("n", "<leader>ru", function() require("tarminal").run() end, { desc = "Run current file in terminal" })
vim.keymap.set("x", "<leader>ri", function() require("tarminal").send_selection() end, { desc = "Send selection to REPL" })
vim.keymap.set("n", "<leader>rc", function() require("tarminal").send_cell() end, { desc = "Send cell to REPL" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "tarminal",
  callback = function(ev)
    local t = require("tarminal")
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
    end
    map("t", "<Esc><Esc>", [[<C-\><C-n>]], "Exit terminal mode")
    map("n", "<CR>", t.jump_to_error, "Jump to file location on this line")
    map("n", "]e", t.next_error, "Next error location")
    map("n", "[e", t.prev_error, "Previous error location")
    map("n", "<C-q>", t.errors_to_quickfix, "Errors to quickfix")
  end,
})
