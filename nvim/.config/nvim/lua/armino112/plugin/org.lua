return {
  {
    "nvim-orgmode/orgmode",
    lazy = false,
    -- ft = { "org" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      -- Setup orgmode
      vim.g.orgmode_treesitter_installed = false
      require("orgmode").setup({
        org_agenda_files = { "~/org/**/*" },
        org_default_notes_file = "~/org/refile.org",
      })
    end
    -- NOTE: If you are using nvim-treesitter with ~ensure_installed = "all"~ option
    -- add ~org~ to ignore_install
    -- require('nvim-treesitter.configs').setup({
    --   ensure_installed = 'all',
    --   ignore_install = { 'org' },
    -- })
  },

  {
    "nvim-orgmode/org-bullets.nvim",
    ft = { "org" },
    dependencies = { "nvim-orgmode/orgmode" },
    config = function()
      require("org-bullets").setup({
        -- symbols = { "◉", "○", "●", "○", "●", "○", "●" },
        -- symbols = { "●", "○", "◆", "◇", "▸", "▹" },
      })
    end,
  },
}
