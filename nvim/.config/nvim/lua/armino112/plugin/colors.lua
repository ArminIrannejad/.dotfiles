return {

  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      no_italic = true,
      styles = {
        comments = {},
        conditionals = {},
        loops = {},
        functions = {},
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
      },
    },
  },

  {
    "rose-pine/neovim",
    name = "rose-pine",
    opts = {
      disable_italics = true,
    },
  },
  {
    "blazkowolf/gruber-darker.nvim",
    name = "gruber-darker",
    opts = {
      bold = false,
      italic = {
        strings   = false,
        comments  = false,
        operators = false,
        folds     = false,
      },
      underline = false,
      undercurl = false,
      invert = {
        signs   = false,
        tabline = false,
        visual  = false,
      },
    },
    config = function(_, opts)
      require("gruber-darker").setup(opts)
      vim.cmd.colorscheme("gruber-darker")
    end,

  },

  {
    "EdenEast/nightfox.nvim",
    opts = {
      options = {
        styles = {
          comments  = "NONE",
          keywords  = "NONE",
          functions = "NONE",
          types     = "NONE",
          variables = "NONE",
          strings   = "NONE",
        },
      },
    },
  },

  {
    "bignimbus/pop-punk.vim",
    name = "pop-punk",
  },

  {
    "dracula/vim",
    name = "dracula",
    init = function()
      vim.g.dracula_italic = 0
      vim.g.dracula_italic_comment = 0
    end,
  },

  {
    "shaunsingh/nord.nvim",
    init = function()
      vim.g.nord_italic = false
      vim.g.nord_italic_comments = false
    end,
  },

  {
    "navarasu/onedark.nvim",
    opts = {
      code_style = {
        comments  = "none",
        keywords  = "none",
        functions = "none",
        strings   = "none",
        variables = "none",
      },
    },
  },

  {
    "rebelot/kanagawa.nvim",
    opts = {
      commentStyle   = { italic = false },
      keywordStyle   = { italic = false },
      statementStyle = { italic = false },
      typeStyle      = { italic = false },
    },
  },

  {
    "sainnhe/gruvbox-material",
    init = function()
      vim.g.gruvbox_material_enable_italic = 0
      vim.g.gruvbox_material_disable_italic_comment = 1
    end,
  },

  { "tjdevries/colorbuddy.vim" },
  { "tjdevries/gruvbuddy.nvim" },

  {
    "scottmckendry/cyberdream.nvim",
    opts = {
      variant = "dark",
      transparent = false,
      italic_comments = false,
    },
  },

  { "nanotech/jellybeans.vim",         name = "jellybeans" },

  { "nyoom-engineering/oxocarbon.nvim" },

  {
    "bluz71/vim-moonfly-colors",
    name = "moonfly",
    init = function()
      vim.g.moonflyItalics = false
    end,
  },

  { "pineapplegiant/spaceduck" },

  { "jaredgorski/spacecamp" },

  { "tpope/vim-vividchalk",    name = "vividchalk" },

  {
    "Everblush/nvim",
    name = "everblush",
    opts = {
    },
  },

  { "Rigellute/shades-of-purple.vim", name = "shades-of-purple" },

  {
    "diegoulloao/neofusion.nvim",
    name = "neofusion",
    opts = {
      italic = {
        strings = false,
        emphasis = false,
        comments = false,
        operators = false,
        folds = false,
      },
    },
  },
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = false,
      style = "night",
      styles = {
        comments  = { italic = false },
        keywords  = { italic = false },
        functions = { italic = false },
        variables = { italic = false },
      },
    },
  },
}
