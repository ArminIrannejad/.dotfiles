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

  if not self.drawer_hidden then
    self:drawer_open()
  end

  vim.api.nvim_set_current_win(editor)
  self.is_opened = true
end

-- the drawer is the only window between the result and the editor, so <C-w>k
-- out of the result lands in the tree whenever the cursor is in the left
-- columns. hiding it is what makes that motion mean "back to the query".
function layout:drawer_open()
  vim.api.nvim_set_current_win(self.windows.editor)
  vim.cmd("lefta " .. self.drawer_width .. "vsplit")
  local win = vim.api.nvim_get_current_win()
  self.windows.drawer = win
  ui.drawer_show(win)
  self:configure_window_on_switch(self.on_switch, win, ui.drawer_show)
  self:configure_window_on_quit(win)
end

-- nvim_win_close only raises WinClosed; :q here would trip the QuitPre hook
-- upstream hangs off every tile and tear down the whole ui
function layout:drawer_close()
  local win = self.windows.drawer
  self.windows.drawer = nil
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  if vim.api.nvim_get_current_win() == win then
    vim.api.nvim_set_current_win(self.windows.editor)
  end
  pcall(vim.api.nvim_win_close, win, false)
end

function layout:drawer_toggle()
  self.drawer_hidden = not self.drawer_hidden
  if not self.is_opened then
    return -- honoured by the next open()
  end
  if self.drawer_hidden then
    self:drawer_close()
  else
    local from = vim.api.nvim_get_current_win()
    self:drawer_open()
    vim.api.nvim_set_current_win(vim.api.nvim_win_is_valid(from) and from or self.windows.editor)
  end
end

function layout:reset()
  vim.api.nvim_win_set_height(self.windows.result, self.result_height)
  if self.windows.drawer and vim.api.nvim_win_is_valid(self.windows.drawer) then
    vim.api.nvim_win_set_width(self.windows.drawer, self.drawer_width)
  end
end

function layout:close()
  log_close()
  layouts.Default.close(self)
end

-- setup registers the persisted connections over rpc, which starts the go host
-- and restores the call log, so the sweep and the host's env have to land first
require("armino112.plugin.dbee.janitor").start()
require("armino112.plugin.dbee.host").setup()

dbee.setup({
  sources = {
    require("dbee.sources").EnvSource:new("DBEE_CONNECTIONS"),
    require("dbee.sources").FileSource:new(vim.fn.stdpath("state") .. "/dbee/persistence.json"),
  },

  window_layout = layout,

  drawer = {
    disable_help = true,
    window_options = window_options,
    candies = {
      -- upstream has no catalog level; the tree grew one, so give it an icon
      catalog = {
        icon = "\u{f1c0}",
        icon_highlight = "Directory",
        text_highlight = "",
      },
      -- nor a refresh node; drawer.lua hangs one off every connection
      refresh = {
        icon = "\u{f021}",
        icon_highlight = "String",
        text_highlight = "",
      },
    },
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

-- upstream's winbar reads "2/3 (150)" with the timing shoved to the far right;
-- restate it as a row range pinned top-left so paging is legible at a glance
pcall(function()
  local result = require("dbee.ui.result")

  local display_result = result.display_result
  result.display_result = function(self, page)
    local current = display_result(self, page)

    if self.winid and vim.api.nvim_win_is_valid(self.winid) then
      -- total row count only lives in the winbar upstream just wrote
      local bar = vim.api.nvim_get_option_value("winbar", { win = self.winid })
      local total = tonumber(bar:match("%((%d+)%)"))
      if total then
        local seconds = self.current_call.time_taken_us / 1000000
        local text
        if total == 0 then
          text = string.format(" no rows  ·  %.3fs", seconds)
        else
          text = string.format(
            " rows %d-%d of %d  ·  page %d/%d  ·  %.3fs",
            self.page_size * current + 1,
            math.min(self.page_size * (current + 1), total),
            total,
            current + 1,
            self.page_ammount + 1,
            seconds
          )
        end
        vim.api.nvim_set_option_value("winbar", "%#DbeeResultInfo#" .. text, { win = self.winid })
      end
    end

    return current
  end
end)

-- upstream dims row numbers into the same NonText as the box drawing, which in
-- most themes is a hair off the background. keep the borders faint, not the numbers.
pcall(function()
  local result = require("dbee.ui.result")

  local function set_hl()
    vim.api.nvim_set_hl(0, "DbeeResultRowNumber", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "DbeeResultInfo", { link = "Comment", default = true })
  end
  set_hl()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })

  result.apply_highlight = function(_, winid)
    if not (winid and vim.api.nvim_win_is_valid(winid)) then
      return
    end
    vim.fn.clearmatches(winid)
    vim.fn.matchadd("NonText", [[─\|│\|┼]], 10, -1, { window = winid })
    vim.fn.matchadd("DbeeResultRowNumber", [[^\s*\d\+]], 20, -1, { window = winid })
  end
end)

-- upstream flattens the driver error onto one line and leaves wrap off, so a
-- failed query has to be read by scrolling sideways. wrap the status text only;
-- result tables stay unwrapped.
pcall(function()
  local result = require("dbee.ui.result")

  local failed = {
    executing_failed = true,
    retrieving_failed = true,
    canceled = true,
  }

  local function sync_wrap(self)
    local winid = self.winid
    if not (winid and vim.api.nvim_win_is_valid(winid)) then
      return
    end
    local on = failed[self.current_call and self.current_call.state] or false
    for _, opt in ipairs({ "wrap", "linebreak", "breakindent" }) do
      vim.api.nvim_set_option_value(opt, on, { win = winid })
    end
  end

  for _, name in ipairs({ "display_status", "display_result", "show" }) do
    local orig = result[name]
    result[name] = function(self, ...)
      local a, b = orig(self, ...)
      sync_wrap(self)
      return a, b
    end
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

require("armino112.plugin.dbee.limit")
require("armino112.plugin.dbee.gate")
require("armino112.plugin.dbee.drawer")
require("armino112.plugin.dbee.cmp")
require("armino112.plugin.dbee.hover")

vim.keymap.set("n", "<leader>be", function()
  dbee.toggle()
end, { silent = true })

vim.keymap.set("n", "<leader>bd", function()
  layout:drawer_toggle()
end, { silent = true, desc = "Toggle dbee drawer" })

vim.keymap.set("n", "<leader>bl", log_toggle, { silent = true, desc = "Toggle dbee call log" })
