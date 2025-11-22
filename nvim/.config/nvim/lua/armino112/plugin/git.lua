return {
  {
    "tpope/vim-fugitive",
  },
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      local gitsigns = require("gitsigns")
      gitsigns.setup({
        signcolumn = false,
      })

      vim.keymap.set("n", "<leader>ph", function()
        gitsigns.preview_hunk()
      end)

      local signs_enabled = false
      vim.keymap.set("n", "<leader>tg", function()
        gitsigns.toggle_signs()
        signs_enabled = not signs_enabled
        print("Signs " .. (signs_enabled and "ON" or "OFF"))
      end)
    end,
  },
}
