return {
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      CustomOilBar = function()
        local path = vim.fn.expand("%")
        path = path:gsub("oil://", "")
        return "  " .. vim.fn.fnamemodify(path, ":.")
      end

      require("oil").setup({
        columns = {
          "icon",
          "permissions",
          "size",
          "mtime",
        },

        keymaps = {
          ["<C-h>"] = false,
          ["<BS>"] = "actions.parent",
          ["C"] = "actions.cd",
          ["~"] = {
            callback = function()
              require("oil").open(vim.fn.expand("~"))
            end,
          },
        },

        win_options = {
          winbar = nil
        },

        view_options = {
          show_hidden = true,
          is_always_hidden = function(name)
            return name == ".." or name == "../"
          end,

        },
      })

      vim.keymap.set("n", "<leader>pv", "<CMD>Oil<CR>", { desc = "Open parent directory" })
    end,
  },
}
