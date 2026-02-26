return {
  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    opts = {
      ensure_installed = {
        "python",
        "c",
        "bash",
        "lua",
        "json",
        "sql",
        "haskell",
      },
      indent = { enable = true },
      highlight = { enable = true },
      auto_install = true,
    },
  },
}
