-- completion and drawer metadata straight from unity catalog instead of the
-- dbee driver. the driver route is a blocking rpcrequest that runs
-- information_schema on the cluster: ~14s when the cluster is warm, minutes when
-- it is asleep, and nvim is frozen for all of it. the catalog rest api needs no
-- compute and runs async, so metadata works with the cluster down and never
-- blocks a keystroke.

local util = require("armino112.plugin.dbee.util")

local M = {}

M.config = {
  -- nothing ever waits on a stale entry: it is served straight away and
  -- revalidated behind you, so a short ttl buys freshness for a background call
  ttl_s = 5 * 60, -- schemas you actually touch, so an etl shows up on its own
  sweep_ttl_s = 12 * 60 * 60, -- the whole-catalog warm, which is 50-odd calls
  retry_s = 60, -- a failed lookup is only worth caching until the next attempt
  timeout_ms = 15000,
  max_jobs = 4,
  store = vim.fn.stdpath("state") .. "/dbee/catalog.json",
}

-- cache[catalog] = { fetched_at, schemas, tables = { [schema] = { fetched_at, failed, list } } }
local cache = nil
local selected = {}
local version = 0
local structure = { version = -1 }
local warmed = {}

local function now()
  return os.time()
end

local function load()
  if cache then
    return cache
  end
  cache = {}
  if vim.fn.filereadable(M.config.store) == 1 then
    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(M.config.store), "\n"))
    if ok and type(decoded) == "table" then
      cache = decoded
    end
  end
  return cache
end

local save_scheduled = false
local function save()
  if save_scheduled then
    return
  end
  save_scheduled = true
  vim.defer_fn(function()
    save_scheduled = false
    vim.fn.mkdir(vim.fn.fnamemodify(M.config.store, ":h"), "p")
    pcall(vim.fn.writefile, { vim.json.encode(cache or {}) }, M.config.store)
  end, 2000)
end

local function bucket(catalog)
  local c = load()
  c[catalog] = c[catalog] or { tables = {} }
  c[catalog].tables = c[catalog].tables or {}
  return c[catalog]
end

local function fresh(entry, ttl)
  if not entry or not entry.fetched_at then
    return false
  end
  if entry.failed then
    ttl = M.config.retry_s
  end
  return now() - entry.fetched_at < (ttl or M.config.ttl_s)
end

--- @return string|nil catalog, table|nil target
function M.context()
  local target = util.target()
  if not target then
    return nil, nil
  end

  local conn = util.connection()
  local catalog = (conn and selected[conn.id]) or target.catalog
  if not catalog then
    return nil, nil
  end
  return catalog, target
end

--- is unity catalog usable for the current connection?
function M.available()
  return (select(1, M.context())) ~= nil
end

-- bounded pool: a bulk warm must never crowd out the lookup someone is waiting on
local queue, active = {}, 0
local inflight = {}

local function pump()
  while active < M.config.max_jobs and #queue > 0 do
    local job = table.remove(queue, 1)
    active = active + 1
    util.json(job.args, M.config.timeout_ms, function(data, out)
      active = active - 1
      job.done(data, out)
      pump()
    end)
  end
end

local function fetch(key, args, parse, callback, background)
  local waiting = inflight[key]
  if waiting then
    if callback then
      table.insert(waiting, callback)
    end
    return
  end
  inflight[key] = callback and { callback } or {}

  local job = {
    args = args,
    done = function(data, out)
      local result = parse(data, out)
      local callbacks = inflight[key] or {}
      inflight[key] = nil
      version = version + 1
      save()
      for _, cb in ipairs(callbacks) do
        cb(result)
      end
      M.on_update()
    end,
  }

  if background then
    queue[#queue + 1] = job
  else
    table.insert(queue, 1, job)
  end
  pump()
end

--- replaced by the drawer bridge; fired whenever cached metadata changes
function M.on_update() end

--- @param callback fun(schemas: string[], stale: boolean)
function M.schemas(callback)
  local catalog, target = M.context()
  if not catalog then
    return callback({})
  end

  local entry = bucket(catalog)
  if fresh(entry) and entry.schemas then
    return callback(entry.schemas, false)
  end

  local stale = entry.schemas
  local args = { "schemas", "list", catalog, "--profile", util.profile(target), "-o", "json" }
  local parse = function(data)
    if not data then
      entry.schemas = entry.schemas or {}
      entry.fetched_at, entry.failed = now(), true
      return entry.schemas
    end

    local names = {}
    for _, schema in ipairs(data) do
      if schema.name then
        names[#names + 1] = schema.name
      end
    end
    table.sort(names)
    entry.schemas = names
    entry.fetched_at, entry.failed = now(), nil
    return names
  end

  -- stale data now beats correct data in a second; refresh happens behind it
  if stale then
    fetch("schemas:" .. catalog, args, parse, nil, true)
    return callback(stale, true)
  end
  fetch("schemas:" .. catalog, args, parse, callback)
end

local TABLE_TYPES = {
  VIEW = "view",
  MATERIALIZED_VIEW = "view",
}

--- @param schema string
--- @param callback fun(tables: table[], stale: boolean)
--- @param background? boolean part of the bulk warm: long ttl, queued last
function M.tables(schema, callback, background)
  local catalog, target = M.context()
  if not catalog or not schema then
    return callback({})
  end

  local entry = bucket(catalog)
  local cached = entry.tables[schema]
  local args = { "tables", "list", catalog, schema, "--profile", util.profile(target), "-o", "json" }

  local parse = function(data)
    if not data then
      entry.tables[schema] = { fetched_at = now(), failed = true, list = (cached and cached.list) or {} }
      return entry.tables[schema].list
    end

    local list = {}
    for _, tbl in ipairs(data) do
      if tbl.name then
        local columns = {}
        for _, column in ipairs(tbl.columns or {}) do
          -- nested struct types run to tens of kilobytes; keep docs readable
          local kind = column.type_text or column.type_name or ""
          if #kind > 120 then
            kind = kind:sub(1, 117) .. "..."
          end
          columns[#columns + 1] = { name = column.name, type = kind }
        end
        list[#list + 1] = {
          name = tbl.name,
          schema = schema,
          type = TABLE_TYPES[tbl.table_type or ""] or "table",
          columns = columns,
        }
      end
    end
    entry.tables[schema] = { fetched_at = now(), list = list }
    return list
  end

  if fresh(cached, background and M.config.sweep_ttl_s or nil) then
    return callback(cached.list, false)
  end
  if cached and cached.list and #cached.list > 0 then
    fetch("tables:" .. catalog .. "." .. schema, args, parse, nil, true)
    return callback(cached.list, true)
  end
  fetch("tables:" .. catalog .. "." .. schema, args, parse, callback, background)
end

--- @param callback fun(catalogs: string[])
function M.catalogs(callback)
  local catalog, target = M.context()
  if not catalog then
    return callback({})
  end

  local entry = bucket(catalog)
  local cached = entry.catalogs
  if fresh(cached, M.config.sweep_ttl_s) then
    return callback(cached.list)
  end

  local args = { "catalogs", "list", "--profile", util.profile(target), "-o", "json" }
  local parse = function(data)
    if not data then
      entry.catalogs = { fetched_at = now(), failed = true, list = (cached and cached.list) or {} }
      return entry.catalogs.list
    end

    local names = {}
    for _, item in ipairs(data) do
      if item.name then
        names[#names + 1] = item.name
      end
    end
    table.sort(names)
    entry.catalogs = { fetched_at = now(), list = names }
    return names
  end

  if cached and #cached.list > 0 then
    fetch("catalogs", args, parse, nil, true)
    return callback(cached.list)
  end
  fetch("catalogs", args, parse, callback)
end

--- pull every schema's tables in the background, so the drawer fills in behind
--- the user instead of making them wait per node
function M.warm_all()
  local catalog = M.context()
  if not catalog or warmed[catalog] then
    return
  end
  warmed[catalog] = true

  M.schemas(function(schemas)
    if #schemas == 0 then
      warmed[catalog] = nil -- schema list failed; let the next caller try again
      return
    end
    for _, schema in ipairs(schemas) do
      M.tables(schema, function() end, true)
    end
  end)
end

--- whatever is cached right now, in dbee's DBStructure shape. never fetches.
--- @return table[]
function M.structure_now()
  local catalog = M.context()
  if not catalog then
    return {}
  end
  if structure.version == version and structure.catalog == catalog then
    return structure.value
  end

  local entry = bucket(catalog)
  local value = {}
  for _, name in ipairs(entry.schemas or {}) do
    local cached = entry.tables[name]
    value[#value + 1] = {
      name = name,
      schema = name,
      type = "schema",
      children = cached and cached.list or {},
    }
  end

  structure = { version = version, catalog = catalog, value = value }
  return value
end

--- @return table[]|nil columns nil when they still have to be fetched
function M.columns_now(schema, model)
  local catalog = M.context()
  if not catalog or not schema then
    return nil
  end

  local cached = bucket(catalog).tables[schema]
  if not cached then
    return nil
  end
  for _, tbl in ipairs(cached.list) do
    if tbl.name == model then
      return tbl.columns
    end
  end
  return {}
end

--- @return string[]
function M.catalogs_now()
  local catalog = M.context()
  local cached = catalog and bucket(catalog).catalogs
  return cached and cached.list or {}
end

--- cmp-dbee's Database shape, so the completion source can swap providers
--- @param callback fun(structure: table[])
function M.get_db_structure(callback)
  if not M.available() then
    return callback({}, false)
  end
  M.schemas(function(_, stale)
    M.warm_all()
    -- items are still arriving while the sweep runs; say so, or the client
    -- filters the half-built list locally and never asks again
    callback(M.structure_now(), stale or #queue > 0 or active > 0)
  end)
end

--- @param schema string
--- @param callback fun(models: table[], stale: boolean)
function M.get_models(schema, callback)
  M.tables(schema, callback)
end

--- @param schema string
--- @param model string
--- @param callback fun(columns: table[], stale: boolean)
function M.get_column_completion(schema, model, callback)
  M.tables(schema, function(tables, stale)
    for _, tbl in ipairs(tables) do
      if tbl.name == model then
        return callback(tbl.columns, stale)
      end
    end
    callback({}, stale)
  end)
end

-- catalog switching happens in the go driver; follow it so lookups track it
pcall(function()
  require("dbee.api.core").register_event_listener("database_selected", function(data)
    if data and data.conn_id and data.database_name then
      selected[data.conn_id] = data.database_name
      version = version + 1
      M.on_update()
    end
  end)
end)

-- pull the schema list ahead of the first keystroke that needs it
local function warm_schemas()
  if M.available() then
    M.schemas(function() end)
  end
end

pcall(function()
  require("dbee.api.core").register_event_listener("current_connection_changed", function()
    vim.schedule(warm_schemas)
  end)
end)

vim.defer_fn(warm_schemas, 1000)

vim.api.nvim_create_user_command("DbeeCatalogRefresh", function(opts)
  local schema = opts.args ~= "" and opts.args or nil
  local catalog = M.context()

  -- one schema is the etl case: drop just that, everything else stays warm
  if schema and catalog then
    bucket(catalog).tables[schema] = nil
    version = version + 1
    M.tables(schema, function(tables)
      vim.notify(("dbee: %s refreshed, %d tables"):format(schema, #tables))
    end)
    return
  end

  cache, warmed = {}, {}
  version = version + 1
  pcall(vim.fn.delete, M.config.store)
  M.warm_all()
  vim.notify("dbee: catalog cache dropped")
end, {
  nargs = "?",
  desc = "Refresh cached unity catalog metadata, all of it or one schema",
  complete = function(lead)
    local catalog = M.context()
    if not catalog then
      return {}
    end
    return vim.tbl_filter(function(name)
      return name:find(lead, 1, true) == 1
    end, bucket(catalog).schemas or {})
  end,
})

vim.api.nvim_create_user_command("DbeeCatalog", function()
  local catalog = M.context()
  if not catalog then
    return vim.notify("dbee: no unity catalog for this connection", vim.log.levels.WARN)
  end

  local entry = bucket(catalog)
  local tables = 0
  for _, cached in pairs(entry.tables) do
    tables = tables + #cached.list
  end
  vim.notify(("dbee: %s, %d schemas, %d/%d loaded, %d tables, %d queued"):format(
    catalog,
    #(entry.schemas or {}),
    vim.tbl_count(entry.tables),
    #(entry.schemas or {}),
    tables,
    #queue
  ))
end, { desc = "Show cached unity catalog metadata" })

return M
