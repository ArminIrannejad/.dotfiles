vim.g.dracula_italic = 0
vim.g.dracula_italic_comment = 0

vim.g.nord_italic = false
vim.g.nord_italic_comments = false

vim.g.gruvbox_material_enable_italic = 0
vim.g.gruvbox_material_disable_italic_comment = 1

vim.g.sonokai_enable_italic = 0
vim.g.sonokai_disable_italic_comment = 1

vim.g.moonflyItalics = false

vim.pack.add({
  { src = 'https://github.com/catppuccin/nvim', name = 'catppuccin' },
  { src = 'https://github.com/rose-pine/neovim', name = 'rose-pine' },
  { src = 'https://github.com/blazkowolf/gruber-darker.nvim', name = 'gruber-darker' },
  { src = 'https://github.com/EdenEast/nightfox.nvim', name = 'nightfox.nvim' },
  { src = 'https://github.com/bignimbus/pop-punk.vim', name = 'pop-punk' },
  { src = 'https://github.com/dracula/vim', name = 'dracula' },
  { src = 'https://github.com/shaunsingh/nord.nvim', name = 'nord.nvim' },
  { src = 'https://github.com/navarasu/onedark.nvim', name = 'onedark.nvim' },
  { src = 'https://github.com/rebelot/kanagawa.nvim', name = 'kanagawa.nvim' },
  { src = 'https://github.com/sainnhe/gruvbox-material', name = 'gruvbox-material' },
  { src = 'https://github.com/tjdevries/colorbuddy.vim', name = 'colorbuddy.vim' },
  { src = 'https://github.com/tjdevries/gruvbuddy.nvim', name = 'gruvbuddy.nvim' },
  { src = 'https://github.com/scottmckendry/cyberdream.nvim', name = 'cyberdream.nvim' },
  { src = 'https://github.com/nanotech/jellybeans.vim', name = 'jellybeans' },
  { src = 'https://github.com/nyoom-engineering/oxocarbon.nvim', name = 'oxocarbon.nvim' },
  { src = 'https://github.com/bluz71/vim-moonfly-colors', name = 'moonfly' },
  { src = 'https://github.com/pineapplegiant/spaceduck', name = 'spaceduck' },
  { src = 'https://github.com/jaredgorski/spacecamp', name = 'spacecamp' },
  { src = 'https://github.com/tpope/vim-vividchalk', name = 'vividchalk' },
  { src = 'https://github.com/Everblush/nvim', name = 'everblush' },
  { src = 'https://github.com/Rigellute/shades-of-purple.vim', name = 'shades-of-purple' },
  { src = 'https://github.com/diegoulloao/neofusion.nvim', name = 'neofusion' },
  { src = 'https://github.com/folke/tokyonight.nvim', name = 'tokyonight.nvim' },
  { src = 'https://github.com/zenbones-theme/zenbones.nvim', name = 'zenbones.nvim' },
  { src = 'https://github.com/rktjmp/lush.nvim', name = 'lush.nvim' },
  { src = 'https://github.com/maxmx03/fluoromachine.nvim', name = 'fluoromachine.nvim' },
  { src = 'https://github.com/dasupradyumna/midnight.nvim', name = 'midnight.nvim' },
  { src = 'https://github.com/Shatur/neovim-ayu', name = 'ayu' },
  { src = 'https://github.com/sainnhe/sonokai', name = 'sonokai' },
})

require("catppuccin").setup({
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
})

require("rose-pine").setup({
  disable_italics = true,
})

require("gruber-darker").setup({
  bold = false,
  italic = {
    strings = false,
    comments = false,
    operators = false,
    folds = false,
  },
  underline = false,
  undercurl = false,
  invert = {
    signs = false,
    tabline = false,
    visual = false,
  },
})

require("nightfox").setup({
  options = {
    styles = {
      comments = "NONE",
      keywords = "NONE",
      functions = "NONE",
      types = "NONE",
      variables = "NONE",
      strings = "NONE",
    },
  },
})

require("onedark").setup({
  code_style = {
    comments = "none",
    keywords = "none",
    functions = "none",
    strings = "none",
    variables = "none",
  },
})

require("kanagawa").setup({
  commentStyle = { italic = false },
  keywordStyle = { italic = false },
  statementStyle = { italic = false },
  typeStyle = { italic = false },
})

require("cyberdream").setup({
  variant = "dark",
  transparent = false,
  italic_comments = false,
})

require("everblush").setup({})

require("midnight").setup({})

local transparent = false
local transparent_groups = {
  "Normal",
  "NormalFloat",
  "SignColumn",
  "FoldColumn",
  "Folded",
  "WinSeparator",
  "StatusLine",
  "StatusLineNC",
  "TabLine",
  "TabLineFill",
  "TabLineSel",
}

require("ayu").setup({
  mirage = false,
  overrides = function()
    local colors = require("ayu.colors")
    return {
      CursorLineNr = { fg = colors.accent, bg = "NONE", bold = true },
      CursorLineConceal = { fg = colors.guide_normal, bg = "NONE" },
      Comment = { fg = colors.comment, italic = false },
    }
  end,
})

require("neofusion").setup({
  italic = {
    strings = false,
    emphasis = false,
    comments = false,
    operators = false,
    folds = false,
  },
})

require("tokyonight").setup({
  transparent = false,
  style = "night",
  styles = {
    comments = { italic = false },
    keywords = { italic = false },
    functions = { italic = false },
    variables = { italic = false },
  },
})


vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("user_highlights", { clear = true }),
  callback = function()
    vim.api.nvim_set_hl(0, "MiniJump", {
      sp = "#cc241d",
      underline = true,
      nocombine = true,
    })

    vim.api.nvim_set_hl(0, "Cursor", { fg = "#000000", bg = "#ffff00" })
    vim.api.nvim_set_hl(0, "lCursor", { fg = "#000000", bg = "#ffff00" })

    if transparent then
      for _, group in ipairs(transparent_groups) do
        local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
        hl.bg = "NONE"
        vim.api.nvim_set_hl(0, group, hl)
      end
    end
  end,
})

vim.cmd.colorscheme("ayu-dark")

vim.keymap.set("n", "<leader>tt", function()
  transparent = not transparent
  vim.cmd.colorscheme(vim.g.colors_name)
  vim.notify("Transparency " .. (transparent and "on" or "off"))
end, { desc = "Toggle transparent background" })

local function toggle_transparent_status()
  vim.g.transparent_status = not vim.g.transparent_status
  vim.cmd.colorscheme(vim.g.colors_name)
  vim.notify("Statusbar transparency " .. (vim.g.transparent_status and "on" or "off"))
end

vim.api.nvim_create_user_command("TransparentStatus", toggle_transparent_status, {})
vim.keymap.set("n", "<leader>tT", toggle_transparent_status, { desc = "Toggle transparent statusbar" })
