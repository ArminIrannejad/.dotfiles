return {
  {
    "nvim-orgmode/orgmode",
    ft = { "org" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      -- Setup orgmode
      require("orgmode").setup({
        org_agenda_files = { "~/orgfiles/**/*" }, -- you can keep this
        org_default_notes_file = "~/orgfiles/refile.org",
      })
      -- NOTE: If you are using nvim-treesitter with ~ensure_installed = "all"~ option
      -- add ~org~ to ignore_install
      -- require('nvim-treesitter.configs').setup({
      --   ensure_installed = 'all',
      --   ignore_install = { 'org' },
      -- })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "org",
        callback = function()
          vim.wo.conceallevel = 2
          vim.wo.concealcursor = "nc"
        end,
      })
    end,
  },

  {
    "nvim-orgmode/org-bullets.nvim",
    ft = { "org" },
    dependencies = { "nvim-orgmode/orgmode" },
    config = function()
      require("org-bullets").setup({
        symbols = { "◉", "○", "●", "○", "●", "○", "●" },
        -- symbols = { "●", "○", "◆", "◇", "▸", "▹" },
      })
    end,
  },
}
