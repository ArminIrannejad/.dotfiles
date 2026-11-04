local yank_hl = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group    = yank_hl,
  pattern  = "*",
  callback = function()
    vim.hl.on_yank {
      higroup = "IncSearch",
      timeout = 200,
    }
  end,
})

local cursorline = vim.api.nvim_create_augroup("ActiveCursorLine", { clear = true })
vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
  group = cursorline,
  callback = function() vim.opt_local.cursorlineopt = "both" end,
})
vim.api.nvim_create_autocmd("WinLeave", {
  group = cursorline,
  callback = function() vim.opt_local.cursorlineopt = "number" end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true }),
  desc = "Enable treesitter highlighting when a parser is available",
  callback = function(args)
    if vim.treesitter.highlighter.active[args.buf] then
      return
    end

    local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
    if not lang or not vim.treesitter.language.add(lang) then
      return
    end

    pcall(vim.treesitter.start, args.buf, lang)
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("csv_auto_view", { clear = true }),
  pattern = "*.csv",
  command = "CsvViewEnable",
})

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("close_with_q", { clear = true }),
  pattern = { "checkhealth", "git", "help", "man", "qf", "query" },
  callback = function(args)
    vim.keymap.set("n", "q", "<cmd>quit<cr>", { buffer = args.buf, silent = true })
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("last_location", { clear = true }),
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
      vim.cmd('normal! g`"zz')
    end
  end,
})
