vim.opt.guicursor = ""
vim.opt.winborder = "rounded"
vim.opt.nu = true
vim.opt.relativenumber = true
vim.opt.splitbelow = true
vim.opt.splitright = true

vim.cmd.packadd("nvim.undotree")
vim.g.undotree_SetFocusWhenToggle = 1
vim.keymap.set("n", "<leader>u", vim.cmd.Undotree)

-- old school vim but want it enabled.
vim.opt.path:append("**")
vim.opt.wildmenu = true
vim.opt.wildignore:append({ "*.o", "*.hi", "*.so" })
vim.opt.grepprg = 'rg --vimgrep --no-messages --smart-case'


local yank_hl = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group    = yank_hl,
  pattern  = "*",
  callback = function()
    vim.highlight.on_yank {
      higroup = "IncSearch",
      timeout = 200,
    }
  end,
})


vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.opt.smartindent = true
vim.opt.smartcase = true
vim.opt.ignorecase = true
vim.opt.inccommand = "split"

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.smoothscroll = true
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.cursorline = false
vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50
