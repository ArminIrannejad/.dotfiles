local ht = require("haskell-tools")

local opts = {
  noremap = true,
  silent = true,
  buffer = true,
}

vim.keymap.set("n", "<space>re", vim.lsp.codelens.run, opts)
vim.keymap.set("n", "<space>ev", ht.lsp.buf_eval_all, opts)

vim.keymap.set("n", "<leader>rr", ht.repl.toggle, opts)
vim.keymap.set("n", "<leader>rq", ht.repl.quit, opts)

vim.keymap.set("n", "<leader>rf", function()
  ht.repl.toggle(vim.api.nvim_buf_get_name(0))
end, opts)

vim.bo.autoindent = true
vim.bo.smartindent = false
