-- upstream's oracle driver only lists tables and views. the plsql around them
-- comes from all_objects here instead, folded into each schema as folders the
-- way sql developer shows them, and a unit opens from all_source in a buffer.
--
-- structure is a blocking rpc while queries are async, so the first draw goes
-- out without the folders and a drawer refresh brings them once they land.

local ok_handler, Handler = pcall(require, "dbee.handler")
if not ok_handler then
  return
end

local M = {}

M.config = {
  timeout_ms = 30000,
}

-- object_type -> drawer folder and node type
local KINDS = {
  ["PACKAGE"] = { folder = "packages", type = "package", ext = "pks" },
  ["PACKAGE BODY"] = { folder = "package bodies", type = "package_body", ext = "pkb" },
  ["PROCEDURE"] = { folder = "procedures", type = "procedure", ext = "prc" },
  ["FUNCTION"] = { folder = "functions", type = "function", ext = "fnc" },
  ["TRIGGER"] = { folder = "triggers", type = "trigger", ext = "trg" },
  ["TYPE"] = { folder = "types", type = "plsql_type", ext = "tps" },
  ["TYPE BODY"] = { folder = "type bodies", type = "plsql_type_body", ext = "tpb" },
}

local by_type = {}
for object_type, kind in pairs(KINDS) do
  by_type[kind.type] = object_type
end

-- same schemas upstream lists tables for
local UNITS = [[
SELECT owner, object_name, object_type
FROM all_objects
WHERE object_type IN (%s)
  AND generated = 'N'
  AND owner IN (SELECT username FROM all_users WHERE common = 'NO')]]

-- a package body runs well past the row cap
local SOURCE = [[
SELECT text /* no_limit */
FROM all_source
WHERE owner = '%s'
  AND name = '%s'
  AND type = '%s'
ORDER BY line]]

local units = {} -- connection id -> owner -> object_type -> names
local loading = {}
local pending = {}

local function literal(s)
  return (s:gsub("'", "''"))
end

-- results arrive on the call, not on the execute, so route by call id
pcall(function()
  require("dbee.api.core").register_event_listener("call_state_changed", function(data)
    local call = data and data.call
    local done = call and pending[call.id]
    if not done then
      return
    end

    if call.state == "executing" or call.state == "retrieving" then
      return -- still in flight
    end
    pending[call.id] = nil
    if call.state ~= "archived" then
      return done(nil, call.error)
    end

    local path = vim.fn.tempname()
    local ok = pcall(require("dbee.api.core").call_store_result, call.id, "json", "file", { extra_arg = path })
    if not ok or vim.fn.filereadable(path) == 0 then
      return done(nil)
    end

    local read, rows = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    vim.fn.delete(path)
    done(read and type(rows) == "table" and rows or nil)
  end)
end)

--- @param on_done fun(rows: table[]|nil, err: string|nil)
local function query(id, sql, on_done)
  local ok, call = pcall(require("dbee.api.core").connection_execute, id, sql)
  if not ok or type(call) ~= "table" or not call.id then
    return on_done(nil)
  end
  pending[call.id] = on_done

  vim.defer_fn(function()
    if pending[call.id] then
      pending[call.id] = nil
      on_done(nil, "timed out")
    end
  end, M.config.timeout_ms)
end

local function is_oracle(handler, id)
  local ok, params = pcall(handler.connection_get_params, handler, id)
  return ok and type(params) == "table" and params.type == "oracle"
end

local function load(id)
  if loading[id] then
    return
  end
  loading[id] = true

  local types = {}
  for object_type in pairs(KINDS) do
    types[#types + 1] = "'" .. object_type .. "'"
  end
  table.sort(types)

  query(id, UNITS:format(table.concat(types, ", ")), function(rows, err)
    loading[id] = nil
    if not rows then
      units[id] = units[id] or {} -- keep what was there, and stop asking
      return vim.notify("dbee: oracle units failed: " .. (err or "no result"), vim.log.levels.WARN)
    end

    local grouped = {}
    for _, row in ipairs(rows) do
      local owner, name, object_type = row.OWNER, row.OBJECT_NAME, row.OBJECT_TYPE
      if owner and name and KINDS[object_type] then
        grouped[owner] = grouped[owner] or {}
        grouped[owner][object_type] = grouped[owner][object_type] or {}
        table.insert(grouped[owner][object_type], name)
      end
    end
    units[id] = grouped

    pcall(function()
      require("dbee.api.ui").drawer_refresh()
    end)
  end)
end

-- stale folders stay up until the new ones land
function M.forget(id)
  if units[id] then
    load(id)
  end
end

local function merge(structs, grouped)
  if type(structs) ~= "table" then
    structs = {}
  end

  local schemas = {}
  for _, struct in ipairs(structs) do
    if struct.type == "schema" then
      schemas[struct.name] = struct
    end
  end

  for owner, by_kind in pairs(grouped) do
    local schema = schemas[owner]
    if not schema then
      schema = { name = owner, schema = owner, type = "schema", children = {} }
      schemas[owner] = schema
      table.insert(structs, schema)
    end
    if type(schema.children) ~= "table" then
      schema.children = {}
    end

    for object_type, names in pairs(by_kind) do
      local kind = KINDS[object_type]
      local children = {}
      for _, name in ipairs(names) do
        children[#children + 1] = { name = name, schema = owner, type = kind.type }
      end
      table.insert(schema.children, { name = kind.folder, schema = owner, type = "folder", children = children })
    end
  end

  return structs
end

pcall(function()
  table.insert(require("armino112.plugin.dbee.drawer").refreshers, M.forget)
end)

local get_structure = Handler.connection_get_structure

Handler.connection_get_structure = function(self, id)
  local structs = get_structure(self, id)
  if not is_oracle(self, id) then
    return structs
  end
  if not units[id] then
    load(id)
    return structs
  end
  return merge(structs, units[id])
end

local function show(title, lines)
  local buf = vim.fn.bufnr(title)
  if buf == -1 then
    vim.cmd.tabnew()
    buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.api.nvim_buf_set_name(buf, title)
  else
    local win = vim.fn.win_findbuf(buf)[1]
    if win then
      vim.api.nvim_set_current_win(win)
    else
      vim.cmd.tabnew()
      vim.api.nvim_win_set_buf(0, buf)
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false
  vim.bo[buf].filetype = "plsql"
end

local function open(id, owner, name, object_type)
  local sql = SOURCE:format(literal(owner), literal(name), object_type)
  query(id, sql, function(rows, err)
    if not rows then
      return vim.notify("dbee: no source for " .. name .. ": " .. (err or "no result"), vim.log.levels.WARN)
    end

    local text = {}
    for _, row in ipairs(rows) do
      text[#text + 1] = row.TEXT or ""
    end
    local lines = vim.split((table.concat(text):gsub("\r", "")), "\n", { plain = true })
    if lines[#lines] == "" then
      table.remove(lines)
    end
    if #lines == 0 then
      return vim.notify("dbee: " .. name .. " has no visible source", vim.log.levels.WARN)
    end

    -- all_source starts at the unit header, so make it runnable again
    lines[1] = "CREATE OR REPLACE " .. lines[1]:gsub("^%s+", "")
    show(("%s.%s.%s"):format(owner, name, KINDS[object_type].ext), lines)
  end)
end

-- upstream only gives tables and views an action, so hang one off every unit
pcall(function()
  local convert = require("dbee.ui.drawer.convert")
  local handler_nodes = convert.handler_nodes

  local function arm(id, nodes)
    for _, node in ipairs(nodes or {}) do
      local object_type = by_type[node.type]
      if object_type then
        node.action_1 = function()
          open(id, node.schema, node.name, object_type)
        end
      end
      arm(id, node.__children)
    end
  end

  -- the connection's children are lazy, so the walk has to go in behind them
  convert.handler_nodes = function(handler, ...)
    local nodes = handler_nodes(handler, ...)
    for _, source in ipairs(nodes) do
      for _, node in ipairs(source.__children or {}) do
        local lazy = node.lazy_children
        if node.type == "connection" and lazy then
          node.lazy_children = function()
            local children = lazy()
            if is_oracle(handler, node.id) then
              arm(node.id, children)
            end
            return children
          end
        end
      end
    end
    return nodes
  end
end)

return M
