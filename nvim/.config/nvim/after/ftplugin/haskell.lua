local ht = require('haskell-tools')
local bufnr = vim.api.nvim_get_current_buf()
local opts = { noremap = true, silent = true, buffer = bufnr, }

vim.keymap.set('n', '<space>re', vim.lsp.codelens.run, opts)
vim.keymap.set('n', '<space>hs', ht.hoogle.hoogle_signature, opts)
vim.keymap.set('n', '<space>ev', ht.lsp.buf_eval_all, opts)
vim.keymap.set('n', '<leader>rr', ht.repl.toggle, opts)
vim.keymap.set('n', '<leader>rq', ht.repl.quit, opts)
vim.keymap.set('n', '<leader>rf', function()
  ht.repl.toggle(vim.api.nvim_buf_get_name(0))
end, opts)
vim.keymap.set("n", "<leader>ho", function()
  require("telescope").extensions.hoogle.hoogle()
end, { desc = "Hoogle search (Telescope)" })

vim.bo.autoindent = true
vim.bo.smartindent = false

