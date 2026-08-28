-- K over a function name. spark keeps its reference as annotations on the
-- expression classes, which is the same text DESCRIBE FUNCTION EXTENDED reads
-- back, so the bundled table and the live lookup agree. the table is bundled so
-- a hover costs nothing and still answers with the cluster asleep; the live call
-- only covers what upstream spark does not document -- databricks builtins and
-- anything registered in the catalog.
--
-- the table is pinned to one spark release rather than tracking latest, so a
-- hover never describes a function the runtime does not have. regenerate with
-- roles/neovim/scripts/gen-sparkdoc.py when the cluster runtime moves.

local util = require("armino112.plugin.dbee.util")

local M = {}

M.config = {
  max_width = 88,
  max_height = 24,
  live = true, -- ask the connection about names the bundled table misses
  live_timeout_ms = 60000,
}

local docs -- ~200k of generated lua, only paid for on the first hover
local live = {} -- name -> string|false, per session
local pending = {} -- call_id -> fun(text|nil)
local inflight = {} -- name -> true while the connection is answering

--- @return string|nil doc, string|nil source
local function bundled(name)
  if docs == nil then
    local ok, loaded = pcall(require, "armino112.plugin.dbee.sparkdoc")
    docs = ok and loaded or false
  end
  if not docs then
    return nil, nil
  end
  return docs.functions[name], "spark " .. docs.version
end

--- the identifier the cursor sits in, or nil if it is not sitting in one
--- @return string|nil name, boolean called whether it is followed by an open paren
local function word_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  if not line:sub(col, col):match("[%w_]") then
    return nil, false
  end

  local from, to = col, col
  while from > 1 and line:sub(from - 1, from - 1):match("[%w_]") do
    from = from - 1
  end
  while to < #line and line:sub(to + 1, to + 1):match("[%w_]") do
    to = to + 1
  end

  -- a qualified name is a table, not a function; neither half of one is worth
  -- a function lookup
  if line:sub(from - 1, from - 1) == "." or line:sub(to + 1, to + 1) == "." then
    return nil, false
  end
  return line:sub(from, to):lower(), line:sub(to + 1):match("^%s*%(") ~= nil
end

-- nothing here knows about tables or columns, so leave those to a language
-- server if one ever attaches to a .sql file
local function lsp_hover()
  if #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/hover" }) > 0 then
    vim.lsp.buf.hover()
  end
end

local function float(lines, footer)
  if footer then
    table.insert(lines, "")
    table.insert(lines, "*" .. footer .. "*")
  end
  vim.lsp.util.open_floating_preview(lines, "markdown", {
    border = "rounded",
    max_width = M.config.max_width,
    max_height = M.config.max_height,
    wrap = true,
    focus_id = "sparkdoc",
    close_events = { "CursorMoved", "InsertEnter", "BufLeave" },
  })
end

-- results arrive on the call, not on the execute, so route by call id
pcall(function()
  require("dbee.api.core").register_event_listener("call_state_changed", function(call)
    local done = call and pending[call.id]
    if not done then
      return
    end

    if call.state == "executing" or call.state == "retrieving" then
      return -- still in flight
    end
    pending[call.id] = nil
    if call.state ~= "archived" then
      return done(nil)
    end

    local path = vim.fn.tempname()
    local ok = pcall(require("dbee.api.core").call_store_result, call.id, "json", "file", { extra_arg = path })
    if not ok or vim.fn.filereadable(path) == 0 then
      return done(nil)
    end

    local read, rows = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    vim.fn.delete(path)
    if not read or type(rows) ~= "table" then
      return done(nil)
    end

    -- DESCRIBE FUNCTION hands back one already-formatted column per line
    local out = {}
    for _, row in ipairs(rows) do
      for _, value in pairs(row) do
        out[#out + 1] = tostring(value)
      end
    end
    done(#out > 0 and table.concat(out, "\n") or nil)
  end)
end)

--- @param name string identifier, already known to be [%w_]+
--- @param on_done fun(text: string|nil)
local function ask_live(name, on_done)
  if live[name] ~= nil then
    return on_done(live[name] or nil)
  end

  local ok_core, core = pcall(require, "dbee.api.core")
  local ok_gate, gate = pcall(require, "armino112.plugin.dbee.gate")
  local conn = util.connection()
  if not (M.config.live and ok_core and conn) then
    return on_done(nil)
  end
  if ok_gate and type(gate) == "table" and not gate.allow() then
    return on_done(nil) -- compute is not confirmed up; gate.lua already says so
  end
  if inflight[name] then
    return on_done(nil) -- the first press is still waiting on the same answer
  end

  local ok, call = pcall(core.connection_execute, conn.id, "DESCRIBE FUNCTION EXTENDED " .. name)
  if not ok or type(call) ~= "table" or not call.id then
    return on_done(nil)
  end

  inflight[name] = true
  pending[call.id] = function(text)
    inflight[name] = nil
    live[name] = text or false
    on_done(text)
  end

  -- a call that never reaches a terminal state would otherwise wedge this name
  vim.defer_fn(function()
    inflight[name] = nil
    pending[call.id] = nil
  end, M.config.live_timeout_ms)
end

function M.show()
  local name, called = word_at_cursor()
  if not name then
    return
  end

  local doc, source = bundled(name)
  if doc then
    return float(vim.split(doc, "\n"), source)
  end

  -- only a name written as a call is worth a round trip; K over a column would
  -- otherwise put a DESCRIBE FUNCTION on the cluster for every alias in the query
  if not called then
    return lsp_hover()
  end

  -- nothing is drawn while the connection answers: a hover that pops open
  -- seconds later, over whatever the cursor moved to, is worse than silence
  local buf = vim.api.nvim_get_current_buf()
  ask_live(name, function(text)
    if vim.api.nvim_get_current_buf() ~= buf or word_at_cursor() ~= name then
      return -- answer landed too late to be about what is under the cursor now
    end
    if text then
      float(vim.split(text, "\n"), "DESCRIBE FUNCTION EXTENDED")
    else
      vim.notify(("dbee: no docs for %s"):format(name), vim.log.levels.WARN)
    end
  end)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "sql",
  callback = function(event)
    vim.keymap.set("n", "K", M.show, { buffer = event.buf, desc = "Spark SQL function docs" })
  end,
})

vim.api.nvim_create_user_command("DbeeDoc", function(opts)
  local name = opts.args:lower():match("^[%w_]+$")
  if not name then
    return vim.notify("dbee: not a function name", vim.log.levels.WARN)
  end

  local doc, source = bundled(name)
  if doc then
    return float(vim.split(doc, "\n"), source)
  end
  ask_live(name, function(text)
    if text then
      float(vim.split(text, "\n"), "DESCRIBE FUNCTION EXTENDED")
    else
      vim.notify(("dbee: no docs for %s"):format(name), vim.log.levels.WARN)
    end
  end)
end, {
  nargs = 1,
  desc = "Show Spark SQL function docs",
  complete = function(lead)
    bundled("")
    local out = {}
    for name in pairs(docs and docs.functions or {}) do
      if name:find(lead, 1, true) == 1 then
        out[#out + 1] = name
      end
    end
    table.sort(out)
    return out
  end,
})

return M
