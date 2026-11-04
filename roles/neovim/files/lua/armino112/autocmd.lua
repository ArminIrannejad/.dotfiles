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
