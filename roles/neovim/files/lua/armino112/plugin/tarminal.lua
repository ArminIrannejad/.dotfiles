vim.pack.add({ "https://github.com/ArminIrannejad/tarminal.nvim" })
require("tarminal").setup({
  time_runs = true,
  clear_run = true,
  banner = true,
  follow_run = "focus",
  runners = {
    scala = "scala run",
  },
})

local tarminal = require("tarminal")

vim.keymap.set("n", "<leader>ts", tarminal.toggle, { desc = "Toggle terminal" })
vim.keymap.set("n", "<leader>ru", tarminal.run, { desc = "Run current file" })
vim.keymap.set("n", "<leader>re", tarminal.exec, { desc = "Run command" })
vim.keymap.set("x", "<leader>ri", tarminal.send_selection, { desc = "Send selection to REPL" })
vim.keymap.set("n", "<leader>rc", tarminal.send_cell, { desc = "Send cell to REPL" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "tarminal",
  callback = function(args)
    vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { buffer = args.buf })
    vim.keymap.set("n", "<CR>", tarminal.jump_to_error, { buffer = args.buf })
    vim.keymap.set("n", "]e", tarminal.next_error, { buffer = args.buf })
    vim.keymap.set("n", "[e", tarminal.prev_error, { buffer = args.buf })
    vim.keymap.set("n", "<C-q>", tarminal.errors_to_quickfix, { buffer = args.buf })
  end,
})
