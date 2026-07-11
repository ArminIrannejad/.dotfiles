vim.pack.add({
  { src = "https://github.com/folke/which-key.nvim" },
  -- { src = "https://github.com/echasnovski/mini.icons" },
  { src = "https://github.com/nvim-tree/nvim-web-devicons" },
})

vim.o.timeout = true
vim.o.timeoutlen = 300

local ok, wk = pcall(require, "which-key")
if not ok then
  return
end

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
    wo = {
    },
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
      Up = " ",
      Down = " ",
      Left = " ",
      Right = " ",
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
    ft = {
      -- "TelescopePrompt",
      -- "neo-tree",
      -- "NvimTree",
    },
    bt = {
      -- "terminal",
      -- "nofile",
      -- "prompt",
    },
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
