vim.pack.add({
  { src = "https://github.com/nvim-orgmode/orgmode" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
  { src = "https://github.com/nvim-orgmode/org-bullets.nvim" },
})

require("orgmode").setup({
  org_agenda_files          = { "~/work/org/**/*" },
  org_default_notes_file    = "~/work/org/refile.org",
  org_hide_emphasis_markers = true,
})

local group = vim.api.nvim_create_augroup("OrgConceal", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "org",
  callback = function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = "nc"
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "org",
  callback = function()
    require("org-bullets").setup({
      symbols = {
        todo = { " ", "@org.keyword.todo" },
        done = { "✓ ", "@org.keyword.done" },
        half = { "-", "@org.checkbox.halfchecked" },
      },
    })
  end,
})
