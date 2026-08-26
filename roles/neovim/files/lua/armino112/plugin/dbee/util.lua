-- shared databricks bits: which compute the current dbee connection points at,
-- and which cli profile talks to it.

local M = {}

M.cli = "databricks"

local profiles

-- every lookup is an rpcrequest into the go host, and completion asks a few
-- times per keystroke; hold the answer briefly and drop it when dbee switches
M.memo_ms = 5000
local memo = { at = 0 }

function M.forget()
  memo = { at = 0 }
end

function M.connection()
  if memo.conn and vim.uv.now() - memo.at < M.memo_ms then
    return memo.conn
  end

  local ok, core = pcall(require, "dbee.api.core")
  if not ok then
    return nil
  end
  local got, conn = pcall(core.get_current_connection)
  if not got then
    return nil
  end

  memo = { conn = conn, at = vim.uv.now() }
  return conn
end

--- @return { kind: "clusters"|"warehouses", id: string, catalog: string|nil }|nil
function M.target(conn)
  conn = conn or M.connection()
  if not conn or conn.type ~= "databricks" then
    return nil
  end

  local url = conn.url or ""
  local path = url:match("^[^?]*") or ""
  local catalog = url:match("[?&]catalog=([%w%-_]+)")

  local id = path:match("/sql/protocolv1/o/[^/]+/([%w%-_]+)")
  if id then
    return { kind = "clusters", id = id, catalog = catalog }
  end
  id = path:match("/sql/1%.0/warehouses/([%w%-_]+)")
  if id then
    return { kind = "warehouses", id = id, catalog = catalog }
  end
  return nil
end

-- compute id -> profile, so cli calls authenticate the same way the dsn does
local function known_profiles()
  if profiles then
    return profiles
  end
  profiles = {}

  local path = vim.fn.expand("~/.databrickscfg")
  if vim.fn.filereadable(path) == 0 then
    return profiles
  end

  local section
  for _, line in ipairs(vim.fn.readfile(path)) do
    local name = line:match("^%s*%[(.-)%]")
    if name then
      section = name
    else
      local key, value = line:match("^%s*([%w_]+)%s*=%s*(%S+)")
      if section and (key == "cluster_id" or key == "warehouse_id") then
        profiles[value] = section
      end
    end
  end
  return profiles
end

--- @param target table|nil
--- @return string
function M.profile(target)
  return vim.g.dbee_profile or (target and known_profiles()[target.id]) or "DEFAULT"
end

--- run a databricks cli call off the ui thread, hand back decoded json or nil
function M.json(args, timeout_ms, on_done)
  if vim.fn.executable(M.cli) == 0 then
    return vim.schedule(function()
      on_done(nil, { code = -1 })
    end)
  end

  local cmd = { M.cli }
  vim.list_extend(cmd, args)

  vim.system(cmd, { text = true, timeout = timeout_ms }, function(out)
    local data
    if out.code == 0 and out.stdout and out.stdout ~= "" then
      local ok, decoded = pcall(vim.json.decode, out.stdout)
      if ok and type(decoded) == "table" then
        data = decoded
      end
    end
    vim.schedule(function()
      on_done(data, out)
    end)
  end)
end

pcall(function()
  require("dbee.api.core").register_event_listener("current_connection_changed", M.forget)
end)

return M
