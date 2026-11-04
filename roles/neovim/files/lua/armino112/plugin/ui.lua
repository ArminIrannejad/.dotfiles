vim.pack.add({
  { src = 'https://github.com/nvim-tree/nvim-web-devicons' },
  { src = 'https://github.com/akinsho/bufferline.nvim' },
  { src = 'https://github.com/MeanderingProgrammer/render-markdown.nvim' },
  { src = 'https://github.com/nvzone/showkeys' },
  { src = 'https://github.com/sphamba/smear-cursor.nvim' },
  { src = 'https://github.com/folke/which-key.nvim' },
})

require("bufferline").setup({
  options = {
    close_command = function(n) Snacks.bufdelete(n) end,
    right_mouse_command = function(n) Snacks.bufdelete(n) end,
    diagnostics = "nvim_lsp",
    always_show_bufferline = true,
    show_buffer_close_icons = false,
    show_close_icon = true,
    show_tab_indicators = true,
    separator_style = { "", "" },
    indicator = { style = "none" },
    -- oil dirs are just navigation, keep them off the bar
    custom_filter = function(buf) return vim.bo[buf].filetype ~= "oil" end,
  },
})

-- <leader>bd belong to dbee
vim.keymap.set("n", "<leader>bx", function() Snacks.bufdelete() end, { desc = "Delete Buffer" })
vim.keymap.set("n", "<leader>bp", "<cmd>BufferLineTogglePin<CR>", { desc = "Toggle Pin" })
vim.keymap.set("n", "<leader>bP", "<cmd>BufferLineGroupClose ungrouped<CR>", { desc = "Delete Non-Pinned Buffers" })
vim.keymap.set("n", "<leader>bl", "<cmd>BufferLineCloseRight<CR>", { desc = "Delete Buffers to the Right" })
vim.keymap.set("n", "<leader>bh", "<cmd>BufferLineCloseLeft<CR>", { desc = "Delete Buffers to the Left" })
vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Prev Buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next Buffer" })
vim.keymap.set("n", "[b", "<cmd>BufferLineCyclePrev<CR>", { desc = "Prev Buffer" })
vim.keymap.set("n", "]b", "<cmd>BufferLineCycleNext<CR>", { desc = "Next Buffer" })
vim.keymap.set("n", "[B", "<cmd>BufferLineMovePrev<CR>", { desc = "Move buffer prev" })
vim.keymap.set("n", "]B", "<cmd>BufferLineMoveNext<CR>", { desc = "Move buffer next" })

require("render-markdown").setup({
  file_types = { "markdown", "ipynb" },
})

require("showkeys").setup({
  timeout = 2,
  maxkeys = 6,
  position = "top-right",
})

require("smear_cursor").setup({
  smear_between_buffers = true,
  smear_insert_mode = true,
  stiffness = 0.7,
  trailing_stiffness = 0.4,
  time_interval = 8,
  legacy_computing_symbols_support = true,
})

vim.o.timeout = true
vim.o.timeoutlen = 300

local wk = require("which-key")

wk.setup({
  preset = "modern",
  delay = 1000,
  spec = {},
  notify = true,
  triggers = {
    { "<auto>", mode = "nixsotc" },
  },

  defer = function(ctx)
    return ctx.mode == "V" or ctx.mode == "<C-V>"
  end,

  plugins = {
    marks = true,
    registers = true,

    spelling = {
      enabled = true,
      suggestions = 10,
    },

    presets = {
      operators = true,
      motions = false,
      text_objects = true,
      windows = true,
      nav = true,
      z = true,
      g = true,
    },
  },

  win = {
    no_overlap = true,
    padding = { 1, 2 },
    title = true,
    title_pos = "center",
    zindex = 1000,
    bo = {},
    wo = {},
  },

  layout = {
    width = { min = 20 },
    spacing = 3,
  },

  keys = {
    scroll_down = "<c-d>",
    scroll_up = "<c-u>",
  },

  sort = { "local", "order", "group", "alphanum", "mod" },
  expand = 0,
  replace = {
    key = {
      function(key)
        return require("which-key.view").format(key)
      end,
    },

    desc = {
      { "<Plug>%(?(.*)%)?", "%1" },
      { "^%+",              "" },
      { "<[cC]md>",         "" },
      { "<[cC][rR]>",       "" },
      { "<[sS]ilent>",      "" },
      { "^lua%s+",          "" },
      { "^call%s+",         "" },
      { "^:%s*",            "" },
    },
  },

  icons = {
    breadcrumb = "»",
    separator = "➜",
    group = "+",
    ellipsis = "…",
    mappings = true,
    rules = {},
    colors = true,
    keys = {
      Up = " ",
      Down = " ",
      Left = " ",
      Right = " ",
      C = "󰘴 ",
      M = "󰘵 ",
      D = "󰘳 ",
      S = "󰘶 ",
      CR = "󰌑 ",
      Esc = "󱊷 ",
      ScrollWheelDown = "󱕐 ",
      ScrollWheelUp = "󱕑 ",
      NL = "󰌑 ",
      BS = "󰁮",
      Space = "󱁐 ",
      Tab = "󰌒 ",
      F1 = "󱊫",
      F2 = "󱊬",
      F3 = "󱊭",
      F4 = "󱊮",
      F5 = "󱊯",
      F6 = "󱊰",
      F7 = "󱊱",
      F8 = "󱊲",
      F9 = "󱊳",
      F10 = "󱊴",
      F11 = "󱊵",
      F12 = "󱊶",
    },
  },

  show_help = true,
  show_keys = true,
  disable = {
    ft = {},
    bt = {},
  },

  debug = false,
})

vim.keymap.set("n", "<leader>ww", function()
  wk.show({
    keys = "<c-w>",
    loop = true,
  })
end, { desc = "Window hydra" })

wk.add({
  -- Group names.
  { "<leader>f", group = "file" },
  { "<leader>w", group = "window" },
  { "<leader>g", group = "git" },
})
