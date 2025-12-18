return {
  {
    "NeogitOrg/neogit",
    lazy = true,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = "Neogit",
    keys = {
      { "<leader>gg", "<cmd>Neogit<cr>", desc = "Show Neogit UI" },
    },
    config = true,
  },

  {
    "esmuellert/vscode-diff.nvim",
    lazy = true,
    dependencies = { "MunifTanjim/nui.nvim" },
    cmd = "CodeDiff",
    keys = {
      { "<leader>do", "<cmd>CodeDiff<cr>" },
      { "<leader>df", "<cmd>CodeDiff file HEAD<cr>" },
      { "<leader>dc", "<cmd>tabclose<cr>"},
    },
  },
}

