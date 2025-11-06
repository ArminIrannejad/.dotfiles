return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local lualine = require("lualine")
    local lazy_status = require("lazy.status")

    local function hl(name)
      local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
      if not ok or not h then return {} end
      local ret = {}
      if h.bg then ret.bg = string.format("#%06x", h.bg) end
      if h.fg then ret.fg = string.format("#%06x", h.fg) end
      if h.sp then ret.sp = string.format("#%06x", h.sp) end
      return ret
    end

    local function pick_color(groups, attr)
      for _, g in ipairs(groups) do
        local h = hl(g)
        local c = h[attr]
        if c then return c end
      end
    end

    local function mode_palette()
      local blue   = pick_color({ "@function", "Function", "Identifier", "@type", "Type" }, "fg")
      local green  = pick_color({ "@string", "String", "DiffAdd", "DiagnosticOk" }, "fg")
      local violet = pick_color({ "@constant", "Constant", "@keyword", "Statement" }, "fg")
      local yellow = pick_color({ "DiagnosticWarn", "WarningMsg", "Todo" }, "fg")
      local red    = pick_color({ "DiagnosticError", "ErrorMsg", "Error", "DiffDelete" }, "fg")

      return {
        blue   = blue   or "#65D1FF",
        green  = green  or "#27AE60",
        violet = violet or "#FF61EF",
        yellow = yellow or "#FFDA7B",
        red    = red    or "#FF4A4A",
      }
    end

    local function build_theme()
      local base = hl("StatusLine")
      local nc   = hl("StatusLineNC")
      local norm = hl("Normal")

      base.bg = base.bg or norm.bg or "#112638"
      base.fg = base.fg or norm.fg or "#c3ccdc"
      nc.bg   = nc.bg   or base.bg
      nc.fg   = nc.fg   or base.fg

      local mode = mode_palette()

      return {
        normal = {
          a = { bg = mode.blue,   fg = base.bg, gui = "bold" },
          b = { bg = base.bg,     fg = base.fg },
          c = { bg = base.bg,     fg = base.fg },
        },
        insert = {
          a = { bg = mode.green,  fg = base.bg, gui = "bold" },
          b = { bg = base.bg,     fg = base.fg },
          c = { bg = base.bg,     fg = base.fg },
        },
        visual = {
          a = { bg = mode.violet, fg = base.bg, gui = "bold" },
          b = { bg = base.bg,     fg = base.fg },
          c = { bg = base.bg,     fg = base.fg },
        },
        command = {
          a = { bg = mode.yellow, fg = base.bg, gui = "bold" },
          b = { bg = base.bg,     fg = base.fg },
          c = { bg = base.bg,     fg = base.fg },
        },
        replace = {
          a = { bg = mode.red,    fg = base.bg, gui = "bold" },
          b = { bg = base.bg,     fg = base.fg },
          c = { bg = base.bg,     fg = base.fg },
        },
        inactive = {
          a = { bg = nc.bg,       fg = nc.fg,  gui = "bold" },
          b = { bg = nc.bg,       fg = nc.fg },
          c = { bg = nc.bg,       fg = nc.fg },
        },
      }
    end

    local function setup_lualine()
      lualine.setup({
        options = {
          theme = build_theme(),
          globalstatus = true,
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

    -- Recompute palette whenever the colorscheme changes
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = setup_lualine,
      desc = "Rebuild lualine theme from current colorscheme",
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
--     local mode_colors = {
--       blue   = "#65D1FF",
--       green  = "#27AE60",
--       violet = "#FF61EF",
--       yellow = "#FFDA7B",
--       red    = "#FF4A4A",
--     }
--
--     local function hl(name)
--       local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
--       if not ok or not h then return {} end
--       local ret = {}
--       if h.bg then ret.bg = string.format("#%06x", h.bg) end
--       if h.fg then ret.fg = string.format("#%06x", h.fg) end
--       return ret
--     end
--
--     local function build_theme()
--       local base = hl("StatusLine")
--       local nc   = hl("StatusLineNC")
--       local norm = hl("Normal")
--
--       base.bg = base.bg or norm.bg or "#112638"
--       base.fg = base.fg or norm.fg or "#c3ccdc"
--       nc.bg   = nc.bg   or base.bg
--       nc.fg   = nc.fg   or base.fg
--
--       return {
--         normal = {
--           a = { bg = mode_colors.blue,   fg = base.bg, gui = "bold" },
--           b = { bg = base.bg,            fg = base.fg },
--           c = { bg = base.bg,            fg = base.fg },
--         },
--         insert = {
--           a = { bg = mode_colors.green,  fg = base.bg, gui = "bold" },
--           b = { bg = base.bg,            fg = base.fg },
--           c = { bg = base.bg,            fg = base.fg },
--         },
--         visual = {
--           a = { bg = mode_colors.violet, fg = base.bg, gui = "bold" },
--           b = { bg = base.bg,            fg = base.fg },
--           c = { bg = base.bg,            fg = base.fg },
--         },
--         command = {
--           a = { bg = mode_colors.yellow, fg = base.bg, gui = "bold" },
--           b = { bg = base.bg,            fg = base.fg },
--           c = { bg = base.bg,            fg = base.fg },
--         },
--         replace = {
--           a = { bg = mode_colors.red,    fg = base.bg, gui = "bold" },
--           b = { bg = base.bg,            fg = base.fg },
--           c = { bg = base.bg,            fg = base.fg },
--         },
--         inactive = {
--           a = { bg = nc.bg,              fg = nc.fg,  gui = "bold" },
--           b = { bg = nc.bg,              fg = nc.fg },
--           c = { bg = nc.bg,              fg = nc.fg },
--         },
--       }
--     end
--
--     local function setup_lualine()
--       lualine.setup({
--         options = {
--           theme = build_theme(),
--         },
--         sections = {
--           lualine_x = {
--             { lazy_status.updates, cond = lazy_status.has_updates, color = { fg = "#ff9e64" } },
--             "encoding",
--             "fileformat",
--             "filetype",
--           },
--         },
--       })
--     end
--
--     setup_lualine()
--
--     vim.api.nvim_create_autocmd("ColorScheme", {
--       callback = setup_lualine,
--     })
--   end,
-- }
--
