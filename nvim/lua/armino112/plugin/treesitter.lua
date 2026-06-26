vim.pack.add({
  "https://github.com/nvim-treesitter/nvim-treesitter",
})

require("nvim-treesitter").setup({
  install_dir = vim.fn.stdpath("data") .. "/site",
})

vim.treesitter.language.register("terraform", "terraform-vars")

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

require("nvim-treesitter").install({
  "bash",
  "c",
  "haskell",
  "json",
  "lua",
  "markdown",
  "python",
  "sql",
  "terraform",
  "vim",
})
