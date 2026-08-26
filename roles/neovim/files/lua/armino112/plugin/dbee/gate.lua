-- the drawer and anything else that asks dbee for metadata does it through a
-- blocking rpcrequest, and the databricks driver waits out cluster boot (its
-- http client timeout is 900s), so one lookup against a sleeping cluster freezes
-- nvim for minutes. gate those calls behind an async cluster-state probe and
-- trip a breaker on anything that comes back slow.

local ok_handler, Handler = pcall(require, "dbee.handler")
if not ok_handler then
  return
end

local util = require("armino112.plugin.dbee.util")

local M = {}

M.config = {
  ttl_up_s = 60,          -- how long a RUNNING verdict is trusted
  ttl_down_s = 15,        -- how long a not-RUNNING verdict is trusted
  probe_timeout_ms = 5000,
  slow_call_ms = 30000,   -- a lookup slower than this is treated as a hang
  notify_every_ms = 30000,
}

local state = {}
local last_notify = 0

local function entry_for(conn)
  local e = state[conn.id]
  if not e then
    e = { verdict = "unknown" }
    state[conn.id] = e
  end
  return e
end

local function probe(target, entry)
  if entry.probing then
    return
  end
  entry.probing = true

  local args = { target.kind, "get", target.id, "--profile", util.profile(target), "-o", "json" }
  util.json(args, M.config.probe_timeout_ms, function(data)
    entry.probing = false
    entry.detail = data and type(data.state) == "string" and data.state or "probe failed"
    entry.verdict = entry.detail == "RUNNING" and "up" or "down"
    entry.checked_at = vim.uv.now()
  end)
end

local function notify(msg, level)
  local at = vim.uv.now()
  if at - last_notify < M.config.notify_every_ms then
    return
  end
  last_notify = at
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.WARN)
  end)
end

--- may we make a blocking metadata call right now?
--- @return boolean
function M.allow()
  local conn = util.connection()
  if not conn then
    return false
  end

  local target = util.target(conn)
  if not target then
    return true -- not databricks compute, nothing to gate on
  end

  local entry = entry_for(conn)
  local ttl = (entry.verdict == "up" and M.config.ttl_up_s or M.config.ttl_down_s) * 1000
  if not entry.checked_at or vim.uv.now() - entry.checked_at > ttl then
    probe(target, entry)
  end

  return entry.verdict == "up"
end

function M.mark(verdict, detail)
  local conn = util.connection()
  if not conn or not util.target(conn) then
    return
  end
  local entry = entry_for(conn)
  entry.verdict = verdict
  entry.detail = detail
  entry.checked_at = vim.uv.now()
end

function M.status()
  local conn = util.connection()
  if not conn then
    return "dbee: no connection"
  end

  local target = util.target(conn)
  if not target then
    return ("dbee: %s (ungated)"):format(conn.name)
  end

  local entry = entry_for(conn)
  local age = entry.checked_at and math.floor((vim.uv.now() - entry.checked_at) / 1000)
  return ("dbee: %s %s %s%s"):format(
    target.id,
    entry.verdict,
    entry.detail or "-",
    age and (" (%ds ago)"):format(age) or ""
  )
end

local function guard(name)
  local original = Handler[name]
  if not original then
    return
  end

  Handler[name] = function(self, ...)
    if not M.allow() then
      local conn = util.connection()
      local entry = conn and state[conn.id]
      notify(("dbee: skipped metadata lookup, compute is %s. :DbeeStart to wake it."):format(
        entry and entry.detail or "not confirmed running"
      ))
      return {}
    end

    local started = vim.uv.now()
    local ok, result = pcall(original, self, ...)
    local elapsed = vim.uv.now() - started

    if not ok then
      M.mark("down", "call failed")
      error(result, 0)
    elseif elapsed > M.config.slow_call_ms then
      M.mark("down", ("slow (%dms)"):format(elapsed))
      notify(("dbee: metadata took %dms, pausing lookups"):format(elapsed))
    else
      M.mark("up", "RUNNING")
    end

    return result
  end
end

guard("connection_get_structure")
guard("connection_get_columns")

-- cmp-dbee caches whatever it gets, so short-circuit above its cache rather than
-- letting an empty result stick around for the whole expiry window
pcall(function()
  local Database = require("cmp-dbee.database")

  local get_db_structure = Database.get_db_structure
  Database.get_db_structure = function(callback)
    if not M.allow() then
      return callback({})
    end
    return get_db_structure(callback)
  end

  local get_column_completion = Database.get_column_completion
  Database.get_column_completion = function(schema, model, callback)
    if not M.allow() then
      return callback({})
    end
    return get_column_completion(schema, model, callback)
  end
end)

-- probe on connect so the first lookup isn't the one paying for a cold verdict
pcall(function()
  require("dbee.api.core").register_event_listener("current_connection_changed", function()
    vim.schedule(M.allow)
  end)
end)

vim.api.nvim_create_user_command("DbeeGate", function()
  vim.notify(M.status())
end, { desc = "Show dbee compute gate state" })

vim.api.nvim_create_user_command("DbeeStart", function()
  local target = util.target()
  if not target then
    return vim.notify("dbee: no databricks compute to start", vim.log.levels.WARN)
  end

  vim.notify(("dbee: starting %s"):format(target.id))
  vim.system(
    { util.cli, target.kind, "start", target.id, "--profile", util.profile(target) },
    { text = true, timeout = 20 * 60 * 1000 },
    function(out)
      vim.schedule(function()
        if out.code == 0 then
          M.mark("up", "RUNNING")
          vim.notify(("dbee: %s is running"):format(target.id))
        else
          vim.notify(("dbee: failed to start %s"):format(target.id), vim.log.levels.ERROR)
        end
      end)
    end
  )
end, { desc = "Start the databricks compute behind the current dbee connection" })

return M
