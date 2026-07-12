vim.pack.add({
  "https://github.com/nvim-treesitter/nvim-treesitter",
})

require("nvim-treesitter").setup({
  install_dir = vim.fn.stdpath("data") .. "/site",
})

-- nvim-treesitter pins tree-sitter-haskell at a revision whose bundled
-- tree_sitter/array.h violates strict aliasing: the array_* macros cast a typed
-- array to `Array *` and store the realloc'd pointer through it, so at -O2 the
-- scanner keeps reading the stale pre-realloc pointer. Haskell's layout scanner
-- leans on those arrays, so every Haskell buffer corrupts the heap and nvim
-- dies with "corrupted size vs. prev_size". Upstream fixed array.h in 98aedbd.
-- install() re-requires the parser table, so re-apply on User TSUpdate too.
local function pin_haskell_parser()
  require("nvim-treesitter.parsers").haskell.install_info.revision =
    "98aedbd2d6947a168ba3ba3755d70b0cb6b78395"
end

pin_haskell_parser()

vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("treesitter_pins", { clear = true }),
  pattern = "TSUpdate",
  callback = pin_haskell_parser,
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
