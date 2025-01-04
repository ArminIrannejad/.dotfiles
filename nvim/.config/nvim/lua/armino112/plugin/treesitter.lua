return {
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup {
                ensure_installed = { "python", "c", "vim", "lua", "query", "markdown" }, -- Removed duplicate "vim"
                auto_install = true,
                highlight = {
                    enable = true,
                },
                additional_vim_regex_highlighting = false,
            }
        end,
    }
}

