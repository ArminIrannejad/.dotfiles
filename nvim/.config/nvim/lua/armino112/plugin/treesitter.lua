return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup {
        ensure_installed = { "python", "c", "vim", "lua", "query", "markdown", "bash", "markdown_inline" },
        ignore_install = { "org", "grammar", },
        auto_install = true,
        highlight = {
          enable = true,
          disable = { "org", "grammar", },
        },
        indent = {
          enable = true,
          disable = { "org", "grammar", },
        },
        additional_vim_regex_highlighting = false,
      }
    end,
  }
}
