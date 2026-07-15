vim.pack.add({
  { src = 'https://github.com/nvim-lualine/lualine.nvim' },
  { src = 'https://github.com/nvim-tree/nvim-web-devicons' },
})

local loader = require("lualine.utils.loader")

local function hl_color(group, attr)
  local h = vim.api.nvim_get_hl(0, { name = group, link = false })
  return h[attr] and string.format("#%06x", h[attr]) or nil
end

local function rgb_to_hsl(hex)
  local r = tonumber(hex:sub(2, 3), 16) / 255
  local g = tonumber(hex:sub(4, 5), 16) / 255
  local b = tonumber(hex:sub(6, 7), 16) / 255
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local h, s, l = 0, 0, (max + min) / 2
  local d = max - min
  if d ~= 0 then
    s = l > 0.5 and d / (2 - max - min) or d / (max + min)
    if max == r then
      h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then
      h = (b - r) / d + 2
    else
      h = (r - g) / d + 4
    end
    h = h / 6
  end
  return h, s, l
end

local function hsl_to_rgb(h, s, l)
  local function hue(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
    return p
  end
  local r, g, b = l, l, l
  if s ~= 0 then
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    r = hue(p, q, h + 1 / 3)
    g = hue(p, q, h)
    b = hue(p, q, h - 1 / 3)
  end
  local function channel(x)
    return math.max(0, math.min(255, math.floor(x * 255 + 0.5)))
  end
  return string.format("#%02x%02x%02x", channel(r), channel(g), channel(b))
end

local mode_hue = {
  normal = 205,
  insert = 140,
  visual = 278,
  command = 45,
  replace = 0,
}

local function apply_mode_palette(palette)
  local base = palette.normal and palette.normal.a and palette.normal.a.bg
  if type(base) ~= "string" or base:sub(1, 1) ~= "#" then
    return
  end
  local _, s, l = rgb_to_hsl(base)
  s = math.min(math.max(s, 0.55), 0.9)
  l = math.min(math.max(l, 0.6), 0.78)
  for name, hue in pairs(mode_hue) do
    local mode = palette[name]
    if mode and mode.a then
      local color = hsl_to_rgb(hue / 360, s, l)
      mode.a.bg = color
      if mode.b then mode.b.fg = color end
    end
  end
end

local function section_bg()
  local normal = hl_color("Normal", "bg")
  local status = hl_color("StatusLine", "bg")
  if status and status ~= normal then
    return status
  end
  if not normal then
    return status
  end
  local h, s, l = rgb_to_hsl(normal)
  local delta = l < 0.5 and 0.06 or -0.06
  return hsl_to_rgb(h, s, math.max(0, math.min(1, l + delta)))
end

local function statusline_theme()
  local palette = loader.load_theme("auto")
  if vim.g.colors_name ~= "ayu" then
    apply_mode_palette(palette)
  end
  local transparent = vim.g.transparent_status
  local bg = section_bg()
  for _, mode in pairs(palette) do
    for section, colors in pairs(mode) do
      if section ~= "a" then
        if transparent then
          colors.bg = "NONE"
        elseif bg then
          colors.bg = bg
        end
      end
    end
  end
  return palette
end

local function shortened_filename()
  local path = vim.fn.expand("%:~:.")
  if path == "" then
    return "[No Name]"
  end

  local parts = vim.split(path, "/", { plain = true })
  local max_depth = 5

  if #parts > max_depth then
    local sliced = vim.list_slice(parts, #parts - max_depth + 1, #parts)
    return ".../" .. table.concat(sliced, "/")
  end
  return path
end

local default_separators = require("lualine").get_config().options.section_separators

local function setup_lualine()
  local separators = vim.g.transparent_status and { left = "", right = "" } or default_separators
  require("lualine").setup({
    options = {
      theme = statusline_theme,
      globalstatus = true,
      section_separators = separators,
    },
    sections = {
      lualine_c = {
        shortened_filename,
      },
      lualine_x = {
        "encoding",
        "fileformat",
        "filetype",
      },
    },
  })
end

setup_lualine()

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("user_lualine", { clear = true }),
  callback = setup_lualine,
})
