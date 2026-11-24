vim.pack.add({
  { src = "https://github.com/nvim-orgmode/orgmode" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
  { src = "https://github.com/nvim-orgmode/org-bullets.nvim" },
})

local org_dir = vim.env.ORG_DIR
org_dir = vim.fs.normalize(org_dir and org_dir ~= "" and org_dir or "~/org")
local notes_file = vim.fs.joinpath(org_dir, "refile.org")

local ok, err = pcall(function()
  vim.fn.mkdir(org_dir, "p")
  -- Exclusive creation: never truncate existing notes.
  local fd, open_err, code = vim.uv.fs_open(notes_file, "wx", tonumber("600", 8))
  if fd then
    vim.uv.fs_close(fd)
  elseif code ~= "EEXIST" then
    error(open_err, 0)
  end
end)
if not ok then
  vim.notify("Could not initialize Org notes: " .. err, vim.log.levels.WARN)
end

require("orgmode").setup({
  org_agenda_files          = { vim.fs.joinpath(org_dir, "**/*") },
  org_default_notes_file    = notes_file,
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
