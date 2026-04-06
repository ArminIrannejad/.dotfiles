vim.pack.add({
  { src = 'https://github.com/mrcjkb/haskell-tools.nvim', version = 'v8.1.0' },
  { src = 'https://github.com/neovimhaskell/haskell-vim' },
  { src = 'https://github.com/luc-tielen/telescope_hoogle' },
})

pcall(function()
  require("telescope").load_extension("hoogle")
end)
