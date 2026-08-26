vim.pack.add({
  { src = "https://github.com/jsborjesson/vim-uppercase-sql" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/kndndrj/nvim-dbee",            version = "master" },
  { src = "https://github.com/Saghen/blink.compat",          version = vim.version.range("2.*") },
  { src = "https://github.com/MattiasMTS/cmp-dbee",          version = "ms/v2" },
})

require("blink.compat").setup({})

local ok, dbee = pcall(require, "dbee")
if not ok then
  return
end

local build = function()
  local binary = vim.fn.expand("$HOME") .. "/.local/share/nvim/dbee/bin/dbee"
  if vim.fn.filereadable(binary) == 0 then
    require("dbee").install("go")
  end
end
-- same chrome on every tile
local window_options = {
  number = false,
  relativenumber = false,
  signcolumn = "no",
  foldcolumn = "0",
  statuscolumn = "",
  cursorline = true,
  list = false,
  wrap = false,
}

local layouts = require("dbee.layouts")
local tools = require("dbee.layouts.tools")
local ui = dbee.api.ui

-- call log lives in a float instead of a permanent tile
local log_win = nil

local function log_close()
  if log_win and vim.api.nvim_win_is_valid(log_win) then
    vim.api.nvim_win_close(log_win, true)
  end
  log_win = nil
end

local function log_toggle()
  if log_win and vim.api.nvim_win_is_valid(log_win) then
    return log_close()
  end

  if not dbee.is_open() then
    dbee.open()
  end

  -- leave room for the call preview upstream hangs off the right edge
  local preview = 80
  local width = math.min(48, vim.o.columns - 8) -- upstream clips the query at 40 chars
  local height = math.min(vim.o.lines - 8, 16)
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.bo[scratch].bufhidden = "wipe"

  log_win = vim.api.nvim_open_win(scratch, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2 - 1),
    col = math.max(1, math.floor((vim.o.columns - width - preview - 4) / 2)),
    style = "minimal",
    border = "rounded",
    title = " calls ",
    title_pos = "center",
  })
  ui.call_log_show(log_win)
end

local layout = layouts.Default:new({ drawer_width = 32, result_height = 16 })

function layout:open()
  self.egg = tools.save()
  self.windows = {}

  tools.make_only(0)
  local editor = vim.api.nvim_get_current_win()
  self.windows.editor = editor
  ui.editor_show(editor)
  self:configure_window_on_switch(self.on_switch, editor, ui.editor_show, true)
  self:configure_window_on_quit(editor)

  -- result spans the bottom, drawer only splits the editor above it
  vim.cmd("bo " .. self.result_height .. "split")
  local win = vim.api.nvim_get_current_win()
  self.windows.result = win
  ui.result_show(win)
  self:configure_window_on_switch(self.on_switch, win, ui.result_show)
  self:configure_window_on_quit(win)

  vim.api.nvim_set_current_win(editor)
  vim.cmd("lefta " .. self.drawer_width .. "vsplit")
  win = vim.api.nvim_get_current_win()
  self.windows.drawer = win
  ui.drawer_show(win)
  self:configure_window_on_switch(self.on_switch, win, ui.drawer_show)
  self:configure_window_on_quit(win)

  vim.api.nvim_set_current_win(editor)
  self.is_opened = true
end

function layout:reset()
  vim.api.nvim_win_set_height(self.windows.result, self.result_height)
  vim.api.nvim_win_set_width(self.windows.drawer, self.drawer_width)
end

function layout:close()
  log_close()
  layouts.Default.close(self)
end

dbee.setup({
  sources = {
    require("dbee.sources").EnvSource:new("DBEE_CONNECTIONS"),
    require("dbee.sources").FileSource:new(vim.fn.stdpath("state") .. "/dbee/persistence.json"),
  },

  window_layout = layout,

  drawer = {
    disable_help = true,
    window_options = window_options,
  },

  editor = {
    window_options = window_options,
    mappings = {
      { key = "BB",   mode = "v", action = "run_selection" },
      { key = "BB",   mode = "n", action = "run_file" },
      { key = "<CR>", mode = "n", action = "run_under_cursor" },
    },
  },

  result = {
    page_size = 50,
    focus_result = false,
    window_options = window_options,
    mappings = {
      { key = "L",          mode = "",  action = "page_next" },
      { key = "H",          mode = "",  action = "page_prev" },
      { key = "A",          mode = "",  action = "page_first" },
      { key = "S",          mode = "",  action = "page_last" },

      { key = "<leader>yj", mode = "n", action = "yank_current_json" },
      { key = "<leader>yj", mode = "v", action = "yank_selection_json" },
      { key = "<leader>YJ", mode = "",  action = "yank_all_json" },

      { key = "<leader>yc", mode = "n", action = "yank_current_csv" },
      { key = "<leader>yc", mode = "v", action = "yank_selection_csv" },
      { key = "<leader>YC", mode = "",  action = "yank_all_csv" },

      { key = "<C-c>",      mode = "",  action = "cancel_call" },
    },
  },

  call_log = {
    window_options = window_options,
    mappings = {
      {
        key = "<CR>",
        mode = "",
        action = function()
          ui.call_log_do_action("show_result")
          log_close()
        end,
      },
      { key = "<C-c>",  mode = "",  action = "cancel_call" },
      { key = "q",      mode = "n", action = log_close },
      { key = "<Esc>",  mode = "n", action = log_close },
    },
  },
})

-- upstream paints a winbar over the result tile; the page counter lives in the
-- statusline area we already read, so drop the extra strip
pcall(function()
  local result = require("dbee.ui.result")

  local function hide_winbar(self)
    if self.winid and vim.api.nvim_win_is_valid(self.winid) then
      vim.api.nvim_set_option_value("winbar", "", { win = self.winid })
    end
  end

  result.set_default_result_window = hide_winbar

  local display_result = result.display_result
  result.display_result = function(self, page)
    local current = display_result(self, page)
    hide_winbar(self)
    return current
  end
end)

pcall(function()
  require("cmp-dbee").setup({})
end)

-- upstream drops the structure cache every 10s, so a keystroke mid-typing pays
-- for a full information_schema scan. the cache is already busted on connection
-- and database change, so only DDL made elsewhere goes stale.
pcall(function()
  local db = require("cmp-dbee.database")
  db.cache_expiry_s = 30 * 60

  vim.api.nvim_create_user_command("DbeeCmpRefresh", function()
    local conn = db.get_current_connection()
    if not conn then
      return
    end
    db.cache[conn.id] = nil
    db.column_cache[conn.id] = nil
  end, { desc = "Drop cached dbee completion metadata" })
end)

require("armino112.plugin.dbee.gate")
require("armino112.plugin.dbee.drawer")
require("armino112.plugin.dbee.cmp")

vim.keymap.set("n", "<leader>be", function()
  dbee.toggle()
end, { silent = true })

vim.keymap.set("n", "<leader>bl", log_toggle, { silent = true, desc = "Toggle dbee call log" })
