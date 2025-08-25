return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local lualine = require("lualine")
    local lazy_status = require("lazy.status")

    local mode_colors = {
      blue   = "#65D1FF",
      green  = "#27AE60",
      violet = "#FF61EF",
      yellow = "#FFDA7B",
      red    = "#FF4A4A",
    }

    local function hl(name)
      local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
      if not ok or not h then return {} end
      local ret = {}
      if h.bg then ret.bg = string.format("#%06x", h.bg) end
      if h.fg then ret.fg = string.format("#%06x", h.fg) end
      return ret
    end

    local function build_theme()
      local base = hl("StatusLine")
      local nc   = hl("StatusLineNC")
      local norm = hl("Normal")

      base.bg = base.bg or norm.bg or "#112638"
      base.fg = base.fg or norm.fg or "#c3ccdc"
      nc.bg   = nc.bg   or base.bg
      nc.fg   = nc.fg   or base.fg

      return {
        normal = {
          a = { bg = mode_colors.blue,   fg = base.bg, gui = "bold" },
          b = { bg = base.bg,            fg = base.fg },
          c = { bg = base.bg,            fg = base.fg },
        },
        insert = {
          a = { bg = mode_colors.green,  fg = base.bg, gui = "bold" },
          b = { bg = base.bg,            fg = base.fg },
          c = { bg = base.bg,            fg = base.fg },
        },
        visual = {
          a = { bg = mode_colors.violet, fg = base.bg, gui = "bold" },
          b = { bg = base.bg,            fg = base.fg },
          c = { bg = base.bg,            fg = base.fg },
        },
        command = {
          a = { bg = mode_colors.yellow, fg = base.bg, gui = "bold" },
          b = { bg = base.bg,            fg = base.fg },
          c = { bg = base.bg,            fg = base.fg },
        },
        replace = {
          a = { bg = mode_colors.red,    fg = base.bg, gui = "bold" },
          b = { bg = base.bg,            fg = base.fg },
          c = { bg = base.bg,            fg = base.fg },
        },
        inactive = {
          a = { bg = nc.bg,              fg = nc.fg,  gui = "bold" },
          b = { bg = nc.bg,              fg = nc.fg },
          c = { bg = nc.bg,              fg = nc.fg },
        },
      }
    end

    local function setup_lualine()
      lualine.setup({
        options = {
          theme = build_theme(),
        },
        sections = {
          lualine_x = {
            { lazy_status.updates, cond = lazy_status.has_updates, color = { fg = "#ff9e64" } },
            "encoding",
            "fileformat",
            "filetype",
          },
        },
      })
    end

    setup_lualine()

    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = setup_lualine,
    })
  end,
}

-- return {
--   "nvim-lualine/lualine.nvim",
--   dependencies = { "nvim-tree/nvim-web-devicons" },
--   config = function()
--     local lualine = require("lualine")
--     local lazy_status = require("lazy.status")
--
--     local colors = {
--       blue = "#65D1FF",
--       green = "#27AE60",
--       violet = "#FF61EF",
--       yellow = "#FFDA7B",
--       red = "#FF4A4A",
--       fg = "#c3ccdc",
--       bg = "#112638",
--       inactive_bg = "#2c3043",
--     }
--
--     local my_lualine_theme = {
--       normal = {
--         a = { bg = colors.blue, fg = colors.bg, gui = "bold" },
--         b = { bg = colors.bg, fg = colors.fg },
--         c = { bg = colors.bg, fg = colors.fg },
--       },
--       insert = {
--         a = { bg = colors.green, fg = colors.bg, gui = "bold" },
--         b = { bg = colors.bg, fg = colors.fg },
--         c = { bg = colors.bg, fg = colors.fg },
--       },
--       visual = {
--         a = { bg = colors.violet, fg = colors.bg, gui = "bold" },
--         b = { bg = colors.bg, fg = colors.fg },
--         c = { bg = colors.bg, fg = colors.fg },
--       },
--       command = {
--         a = { bg = colors.yellow, fg = colors.bg, gui = "bold" },
--         b = { bg = colors.bg, fg = colors.fg },
--         c = { bg = colors.bg, fg = colors.fg },
--       },
--       replace = {
--         a = { bg = colors.red, fg = colors.bg, gui = "bold" },
--         b = { bg = colors.bg, fg = colors.fg },
--         c = { bg = colors.bg, fg = colors.fg },
--       },
--       inactive = {
--         a = { bg = colors.inactive_bg, fg = colors.semilightgray, gui = "bold" },
--         b = { bg = colors.inactive_bg, fg = colors.semilightgray },
--         c = { bg = colors.inactive_bg, fg = colors.semilightgray },
--       },
--     }
--
--     lualine.setup({
--       options = {
--         theme = my_lualine_theme,
--       },
--       sections = {
--         lualine_x = {
--           {
--             lazy_status.updates,
--             cond = lazy_status.has_updates,
--             color = { fg = "#ff9e64" },
--           },
--           { "encoding" },
--           { "fileformat" },
--           { "filetype" },
--         },
--       },
--     })
--   end,
-- }
