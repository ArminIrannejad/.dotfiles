
vim.pack.add({
  'https://github.com/hat0uma/csvview.nvim',
  'https://github.com/cameron-wags/rainbow_csv.nvim',
})

require("csvview").setup()

pcall(function()
  require("rainbow_csv").setup({})
end)

local function attach_rbql(buf)
  vim.keymap.set("n", "<F5>", "<cmd>RbSelect<cr>", {
    buffer = buf,
    silent = true,
    desc = "Query CSV with RBQL",
  })
  vim.keymap.set("n", "<leader>cq", "<cmd>RbSelect<cr>", {
    buffer = buf,
    silent = true,
    desc = "Query CSV with RBQL",
  })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "csv", "tsv", "csv_semicolon", "csv_whitespace", "csv_pipe", "rfc_csv", "rfc_semicolon" },
  callback = function(args)
    attach_rbql(args.buf)
  end,
})

for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype:match("csv") then
    attach_rbql(buf)
  end
end
