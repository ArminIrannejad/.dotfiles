-- runs sql through the duckdb cli and hands back the rows.
--
-- one short-lived process per question: no state to keep in sync with the
-- database, and a file database is opened read-only so completing never takes
-- a write lock. answers are cached briefly so typing does not respawn it.

local M = {}

local MARK = "__duckdb_complete__"
local TTL = 5000 -- ms

local cache = {}
local warned = {}

function M.available()
  return vim.fn.executable("duckdb") == 1
end

function M.literal(text)
  return "'" .. text:gsub("'", "''") .. "'"
end

function M.clear()
  cache = {}
  warned = {}
end

--- the database moving on invalidates what was cached for it
local function stamp(database)
  if not database then
    return ""
  end
  local parts = {}
  for _, path in ipairs({ database, database .. ".wal" }) do
    local stat = vim.uv.fs_stat(path)
    parts[#parts + 1] = stat and (stat.mtime.sec .. "." .. stat.mtime.nsec) or "-"
  end
  return table.concat(parts, ":")
end

local function parse(out, has_init)
  if has_init then
    local at = out:find(MARK, 1, true)
    local close = at and out:find("]", at, true)
    if not close then
      return nil, "init statements did not finish"
    end
    out = out:sub(close + 1)
  end
  if out:match("^%s*$") then
    return {}
  end
  local ok, rows = pcall(vim.json.decode, out, { luanil = { object = true, array = true } })
  if not ok then
    return nil, "unreadable duckdb output"
  end
  return rows
end

-- binding a half written query fails all the time and is expected; only
-- trouble reaching the database itself is worth interrupting for
local function complain(database, err)
  if not (err:find("[Ll]ock") or err:find("Cannot open") or err:find("Could not open")) then
    return
  end
  local key = (database or ":memory:") .. err
  if warned[key] then
    return
  end
  warned[key] = true
  local line = vim.split(err, "\n", { plain = true })[1]
  vim.schedule(function()
    vim.notify("duckdb completion: " .. line, vim.log.levels.WARN)
  end)
end

--- @param target armino112.duckdb.Target
--- @param sql string a single statement
--- @param callback fun(rows: table[]|nil)
--- @return fun() cancel
function M.run(target, sql, callback)
  local key = table.concat({ target.database or "", stamp(target.database), table.concat(target.init, ";"), sql }, "\0")
  local hit = cache[key]
  if hit and vim.uv.now() - hit.at < TTL then
    vim.schedule(function()
      callback(hit.rows)
    end)
    return function() end
  end

  local args = { "duckdb", "-json", "-init", "/dev/null" }
  if target.database then
    vim.list_extend(args, { "-readonly", target.database })
  end

  local script = {}
  for _, statement in ipairs(target.init) do
    script[#script + 1] = (statement:gsub("%s*;?%s*$", ";"))
  end
  if #target.init > 0 then
    script[#script + 1] = ("SELECT %s AS mark;"):format(M.literal(MARK))
  end
  script[#script + 1] = (sql:gsub("%s*;?%s*$", ";"))

  local cancelled = false
  local ok, handle = pcall(vim.system, args, { stdin = table.concat(script, "\n"), text = true }, function(out)
    vim.schedule(function()
      if cancelled then
        return
      end
      local rows, err
      if out.code ~= 0 then
        err = vim.trim(out.stderr or "")
      else
        rows, err = parse(out.stdout or "", #target.init > 0)
      end
      if rows then
        cache[key] = { at = vim.uv.now(), rows = rows }
      elseif err and err ~= "" then
        complain(target.database, err)
      end
      callback(rows)
    end)
  end)

  if not ok then
    vim.schedule(function()
      callback(nil)
    end)
    return function() end
  end

  return function()
    cancelled = true
    pcall(handle.kill, handle, 15)
  end
end

return M
