return {
  {
    'mrcjkb/haskell-tools.nvim',
    version = '^6',
    lazy = false,
  },
  { "neovimhaskell/haskell-vim", ft = "haskell" },
  {
    "luc-tielen/telescope_hoogle",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      require("telescope").load_extension("hoogle")
    end
  },
}
