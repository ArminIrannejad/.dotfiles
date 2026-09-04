vim.pack.add({
  { src = "https://github.com/folke/snacks.nvim" },
})
require("snacks").setup({
  bigfile = { enabled = true, },
  quickfile = { enabled = true, },
  input = { enabled = true, },
  notifier = { enabled = false, timeout = 3000, },
  dashboard = {
    enabled = true,

    sections = {
      { section = "header" },
      { section = "keys",  gap = 1, padding = 1 },
    },

    preset = {
      header = [[
  ██████╗   ██████╗ ████████╗  █████╗        ██╗ ██████╗   █████╗  ██████╗
 ██╔═══██╗ ██╔════╝ ╚══██╔══╝ ██╔══██╗       ██║ ██╔══██╗ ██╔══██╗ ██╔══██╗
 ██║   ██║ ██║         ██║    ███████║ █████╗██║ ██████╔╝ ███████║ ██████╔╝
 ██║   ██║ ██║         ██║    ██╔══██║ ╚════╝██║ ██╔══██╗ ██╔══██║ ██╔══██╗
 ╚██████╔╝ ╚██████╗    ██║    ██║  ██║       ██║ ██║  ██║ ██║  ██║ ██║  ██║
  ╚═════╝   ╚═════╝    ╚═╝    ╚═╝  ╚═╝       ╚═╝ ╚═╝  ╚═╝ ╚═╝  ╚═╝ ╚═╝  ╚═╝
  ]],
      keys = {
        {
          icon = " ",
          key = "f",
          desc = "Find file",
          action = ":lua Snacks.dashboard.pick('files')",
        },
        {
          icon = " ",
          key = "r",
          desc = "Recent files",
          action = ":lua Snacks.dashboard.pick('oldfiles')",
        },
        {
          icon = " ",
          key = "h",
          desc = "Help tags",
          action = ":lua Snacks.dashboard.pick('help')",
        },
        {
          icon = " ",
          key = "t",
          desc = "Themes",
          action = ":lua Snacks.picker.colorschemes()",
        },
        {
          icon = " ",
          key = "c",
          desc = "Config",
          action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })",
        },
        {
          icon = " ",
          key = "q",
          desc = "Quit",
          action = ":qa",
        },
      },
    },
  },
  indent = {
    enabled = false,
    animate = {
      enabled = false,
    },
  },

  scope = { enabled = true, },
  statuscolumn = { enabled = false, },
  words = { enabled = false, },
  picker = { enabled = true, ui_select = true, },
  scratch = { enabled = true, },
  terminal = { enabled = false, },
  zen = { enabled = true, },
  scroll = { enabled = false, },
  dim = { enabled = false, },
  explorer = { enabled = false, },
})

vim.keymap.set("n", "gd", function()
  if next(vim.lsp.get_clients({ bufnr = 0, method = "textDocument/definition" })) then
    Snacks.picker.lsp_definitions()
  else
    vim.cmd("normal! gd")
  end
end, { desc = "Go to def" })

vim.keymap.set("n", "<leader>fh", function()
  Snacks.picker.help()
end, { desc = "Find Help Tags" })

vim.keymap.set("n", "<leader>th", function()
  Snacks.picker.colorschemes()
end, { desc = "Theme Colorschemes" })

vim.keymap.set("n", "<leader>;", function()
  Snacks.dashboard.open()
end, { desc = "Dashboard" })

vim.keymap.set("n", "<leader>fk", function()
  Snacks.picker.keymaps()
end, { desc = "Find Keymaps" })

vim.keymap.set("n", "<leader>gs", function()
  Snacks.picker.git_status()
end, { desc = "Git Status Picker" })

vim.keymap.set("n", "<leader>gd", function()
  Snacks.picker.git_diff()
end, { desc = "Git Diff Hunks" })

vim.keymap.set("n", "<leader>gl", function()
  Snacks.picker.git_log()
end, { desc = "Git Log" })

vim.keymap.set("n", "<leader>gL", function()
  Snacks.picker.git_log_line()
end, { desc = "Git Log Current Line" })

vim.keymap.set("n", "<leader>gb", function()
  Snacks.picker.git_branches()
end, { desc = "Git Branches" })

vim.keymap.set("n", "<leader>.", function()
  Snacks.scratch()
end, { desc = "Toggle Scratch Buffer" })

vim.keymap.set("n", "<leader>S", function()
  Snacks.scratch.select()
end, { desc = "Select Scratch Buffer" })

vim.keymap.set("n", "<leader>ez", function()
  Snacks.zen()
end, { desc = "Zen Mode" })

vim.keymap.set("n", "<leader>eZ", function()
  Snacks.zen.zoom()
end, { desc = "Zoom Window" })

Snacks.toggle.indent():map("<leader>eg")
Snacks.toggle.diagnostics():map("<leader>ed")
Snacks.toggle.line_number():map("<leader>el")
Snacks.toggle.inlay_hints():map("<leader>eh")
Snacks.toggle.treesitter():map("<leader>eT")
