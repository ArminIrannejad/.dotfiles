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
      -- vim.g.orgmode_treesitter_installed = false
      require("orgmode").setup({
        org_agenda_files          = { "~/org/**/*" },
        org_default_notes_file    = "~/org/refile.org",
        org_hide_emphasis_markers = true,
      })
      local group = vim.api.nvim_create_augroup("OrgConceal", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "org",
        callback = function()
          vim.opt_local.conceallevel = 2
          vim.opt_local.concealcursor = "nc"
        end,
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
        symbols = {
          todo = { " ", "@org.keyword.todo" },
          done = { "✓ ", "@org.keyword.done" },
          half = { "-", "@org.checkbox.halfchecked" },
        }
      })
    end,
  },
}
