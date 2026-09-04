-- completion and drawer metadata straight from unity catalog instead of the
-- dbee driver. the driver route is a blocking rpcrequest that runs
-- information_schema on the cluster: ~14s when the cluster is warm, minutes when
-- it is asleep, and nvim is frozen for all of it. the catalog rest api needs no
-- compute and runs async, so metadata works with the cluster down and never
-- blocks a keystroke.
--
-- the dsn pins one catalog, but that only decides where unqualified names
-- resolve; a fully qualified catalog.schema.table reads fine across the whole
-- workspace. so the tree is catalogs -> schemas -> tables and a schema is
-- identified by "catalog.schema" everywhere, which is exactly what dbee's
-- TableOptions.schema needs to produce a three part name downstream.

local util = require("armino112.plugin.dbee.util")

local M = {}

M.config = {
  -- nothing ever waits on a stale entry: it is served straight away and
  -- revalidated behind you, so a short ttl buys freshness for a background call
  ttl_s = 5 * 60, -- schemas you actually touch, so an etl shows up on its own
  sweep_ttl_s = 10 * 60, -- the whole-catalog sweep, names only and so cheap
  retry_s = 60, -- a failed lookup is only worth caching until the next attempt
  timeout_ms = 15000,
  max_jobs = 4,
  store = vim.fn.stdpath("state") .. "/dbee/catalog.json",
}

-- bump whenever the shape below changes; an older store is dropped, not migrated
local STORE_VERSION = 2

-- cache.workspaces[profile] = {
--   swept_at,                                              -- schema names for every catalog
--   catalogs = { fetched_at, failed, list },
--   tree = { [catalog] = { fetched_at, failed, swept_at, schemas,
--     tables  = { [schema] = { fetched_at, failed, list } },   -- names, cheap
--     columns = { [schema] = { fetched_at, failed, map } } } } -- types, 45x bigger
local cache = nil
local selected = {}
local version = 0
local structure = { version = -1 }

local function now()
  return os.time()
end

local function load()
  if cache then
    return cache
  end
  cache = { version = STORE_VERSION, workspaces = {} }
  if vim.fn.filereadable(M.config.store) == 1 then
    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(M.config.store), "\n"))
    if ok and type(decoded) == "table" and decoded.version == STORE_VERSION and type(decoded.workspaces) == "table" then
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

-- unity catalog metadata belongs to the workspace, not to whichever catalog the
-- dsn happens to pin, so the cache is keyed by cli profile
local function workspace(profile)
  local c = load()
  local w = c.workspaces[profile]
  if not w then
    w = {}
    c.workspaces[profile] = w
  end
  w.tree = w.tree or {}
  return w
end

local function bucket(profile, catalog)
  local tree = workspace(profile).tree
  local entry = tree[catalog]
  if not entry then
    entry = {}
    tree[catalog] = entry
  end
  entry.tables = entry.tables or {}
  entry.columns = entry.columns or {}
  return entry
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

--- the catalog unqualified names resolve to, plus how to reach the workspace
--- @return string|nil catalog, table|nil target, string|nil profile
function M.context()
  local target = util.target()
  if not target then
    return nil, nil, nil
  end

  local conn = util.connection()
  local catalog = (conn and selected[conn.id]) or target.catalog
  if not catalog then
    return nil, nil, nil
  end
  return catalog, target, util.profile(target)
end

--- is unity catalog usable for the current connection?
function M.available()
  return (select(1, M.context())) ~= nil
end

--- @return string qualified "catalog.schema"
function M.qualify(catalog, schema)
  return catalog .. "." .. schema
end

--- split a schema identity back apart. a bare name resolves against the
--- connection's own catalog, so two part sql keeps meaning what it always did.
--- @return string|nil catalog, string|nil schema
function M.split(qualified)
  if not qualified or qualified == "" then
    return nil, nil
  end
  local catalog, schema = qualified:match("^([^.]+)%.([^.]+)$")
  if catalog then
    return catalog, schema
  end
  if qualified:find(".", 1, true) then
    return nil, nil -- three parts or more: not a schema
  end
  return (M.context()), qualified
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
        cb(result, false)
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

--- is anything still on its way in?
function M.loading()
  return #queue > 0 or active > 0
end

--- every catalog in the workspace. names only, one call, no compute.
--- @param callback fun(catalogs: string[], stale: boolean)
function M.catalogs(callback)
  local _, target, profile = M.context()
  if not target then
    return callback({}, false)
  end

  local w = workspace(profile)
  local cached = w.catalogs
  if fresh(cached, M.config.sweep_ttl_s) then
    return callback(cached.list, false)
  end

  local args = { "catalogs", "list", "--profile", util.profile(target), "-o", "json" }
  local parse = function(data)
    if not data then
      w.catalogs = { fetched_at = now(), failed = true, list = (cached and cached.list) or {} }
      return w.catalogs.list
    end

    local names = {}
    for _, item in ipairs(data) do
      if item.name then
        names[#names + 1] = item.name
      end
    end
    table.sort(names)
    w.catalogs = { fetched_at = now(), list = names }
    return names
  end

  local key = "catalogs:" .. profile
  if cached and cached.list and #cached.list > 0 then
    fetch(key, args, parse, nil, true)
    return callback(cached.list, true)
  end
  fetch(key, args, parse, callback)
end

--- @return string[]
function M.catalogs_now()
  local catalog, _, profile = M.context()
  if not catalog then
    return {}
  end
  local cached = workspace(profile).catalogs
  return (cached and cached.list) or {}
end

--- @param catalog string
--- @param callback fun(schemas: string[], stale: boolean)
--- @param background? boolean
function M.schemas(catalog, callback, background)
  local _, target, profile = M.context()
  if not target or not catalog then
    return callback({}, false)
  end

  local entry = bucket(profile, catalog)
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

  local key = "schemas:" .. profile .. "." .. catalog
  -- stale data now beats correct data in a second; refresh happens behind it
  if stale then
    fetch(key, args, parse, nil, true)
    return callback(stale, true)
  end
  fetch(key, args, parse, callback, background)
end

--- @return string[]
function M.schemas_now(catalog)
  local _, target, profile = M.context()
  if not target or not catalog then
    return {}
  end
  return bucket(profile, catalog).schemas or {}
end

local TABLE_TYPES = {
  VIEW = "view",
  MATERIALIZED_VIEW = "view",
}

--- table names and kinds for one schema. drops the column payload, which is
--- 45x the bytes and most of the wall time, so this is cheap enough to re-run
--- across a whole catalog. entries carry the qualified schema, so a node handed
--- back to dbee already knows which catalog it came from.
--- @param catalog string
--- @param schema string
--- @param callback fun(tables: table[], stale: boolean)
--- @param background? boolean part of a bulk sweep: queued last
function M.tables(catalog, schema, callback, background)
  local _, target, profile = M.context()
  if not target or not catalog or not schema then
    return callback({}, false)
  end

  local entry = bucket(profile, catalog)
  local cached = entry.tables[schema]
  local args = {
    "tables",
    "list",
    catalog,
    schema,
    "--omit-columns",
    "--omit-properties",
    "--omit-username",
    "--profile",
    util.profile(target),
    "-o",
    "json",
  }

  local qualified = M.qualify(catalog, schema)
  local parse = function(data)
    if not data then
      entry.tables[schema] = { fetched_at = now(), failed = true, list = (cached and cached.list) or {} }
      return entry.tables[schema].list
    end

    local list = {}
    for _, tbl in ipairs(data) do
      if tbl.name then
        list[#list + 1] = {
          name = tbl.name,
          schema = qualified,
          type = TABLE_TYPES[tbl.table_type or ""] or "table",
        }
      end
    end
    entry.tables[schema] = { fetched_at = now(), list = list }
    return list
  end

  local key = "tables:" .. profile .. "." .. qualified
  if fresh(cached) then
    return callback(cached.list, false)
  end
  if cached and cached.list and #cached.list > 0 then
    fetch(key, args, parse, nil, true)
    return callback(cached.list, true)
  end
  fetch(key, args, parse, callback, background)
end

--- @return table[]
function M.tables_now(catalog, schema)
  local _, target, profile = M.context()
  if not target or not catalog or not schema then
    return {}
  end
  local cached = bucket(profile, catalog).tables[schema]
  return (cached and cached.list) or {}
end

--- columns for every table in one schema. the expensive call, so it only runs
--- for schemas someone actually works in.
--- @param catalog string
--- @param schema string
--- @param callback fun(columns: table<string, table[]>, stale: boolean)
function M.columns(catalog, schema, callback)
  local _, target, profile = M.context()
  if not target or not catalog or not schema then
    return callback({}, false)
  end

  local entry = bucket(profile, catalog)
  local cached = entry.columns[schema]
  local args = { "tables", "list", catalog, schema, "--profile", util.profile(target), "-o", "json" }

  local parse = function(data)
    if not data then
      entry.columns[schema] = { fetched_at = now(), failed = true, map = (cached and cached.map) or {} }
      return entry.columns[schema].map
    end

    local map = {}
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
        map[tbl.name] = columns
      end
    end
    entry.columns[schema] = { fetched_at = now(), map = map }
    return map
  end

  local key = "columns:" .. profile .. "." .. M.qualify(catalog, schema)
  if fresh(cached) then
    return callback(cached.map, false)
  end
  if cached and cached.map and next(cached.map) then
    fetch(key, args, parse, nil, true)
    return callback(cached.map, true)
  end
  fetch(key, args, parse, callback)
end

--- @param callback fun(columns: table[], stale: boolean)
function M.table_columns(catalog, schema, model, callback)
  M.columns(catalog, schema, function(map, stale)
    callback(map[model] or {}, stale)
  end)
end

--- @param qualified string "catalog.schema"
--- @return table[]|nil columns nil when they still have to be fetched
function M.columns_now(qualified, model)
  local catalog, schema = M.split(qualified)
  local _, target, profile = M.context()
  if not target or not catalog or not schema then
    return nil
  end

  local cached = bucket(profile, catalog).columns[schema]
  if not cached then
    return nil
  end
  return cached.map[model] or {}
end

--- pull one catalog's tables in the background, so the tree fills in behind the
--- user instead of making them wait per node
function M.warm_catalog(catalog)
  local _, target, profile = M.context()
  if not target or not catalog then
    return
  end

  local entry = bucket(profile, catalog)
  if entry.swept_at and now() - entry.swept_at < M.config.sweep_ttl_s then
    return
  end
  entry.swept_at = now()

  M.schemas(catalog, function(schemas)
    if #schemas == 0 then
      entry.swept_at = nil -- schema list failed; let the next caller try again
      return
    end
    for _, schema in ipairs(schemas) do
      M.tables(catalog, schema, function() end, true)
    end
  end)
end

--- top of the tree, plus the connection's own catalog in full. every other
--- catalog only gets its schema names here; its tables wait until something
--- actually asks, which is a drawer expand or a qualified completion.
function M.warm_all()
  local current, _, profile = M.context()
  if not current then
    return
  end

  local w = workspace(profile)
  if not (w.swept_at and now() - w.swept_at < M.config.sweep_ttl_s) then
    w.swept_at = now()
    M.catalogs(function(catalogs)
      if #catalogs == 0 then
        w.swept_at = nil
        return
      end
      for _, name in ipairs(catalogs) do
        if name ~= current then
          M.schemas(name, function() end, true)
        end
      end
    end)
  end

  M.warm_catalog(current)
end

--- whatever is cached right now, in dbee's DBStructure shape: catalogs hold
--- schemas hold tables. never fetches.
--- @return table[]
function M.structure_now()
  local current, _, profile = M.context()
  if not current then
    return {}
  end
  if structure.version == version and structure.catalog == current then
    return structure.value
  end

  local names = M.catalogs_now()
  if #names == 0 then
    names = { current } -- the catalog list has not landed yet; show what we know
  end

  local tree = workspace(profile).tree
  local value = {}
  for _, catalog in ipairs(names) do
    -- read through, never create: a catalog nobody opened stays out of the cache
    local entry = tree[catalog] or {}
    local schemas = {}
    for _, schema in ipairs(entry.schemas or {}) do
      local cached = (entry.tables or {})[schema]
      schemas[#schemas + 1] = {
        name = schema,
        schema = M.qualify(catalog, schema),
        type = "schema",
        children = (cached and cached.list) or {},
      }
    end
    value[#value + 1] = {
      name = catalog,
      schema = catalog,
      type = "catalog",
      children = schemas,
    }
  end

  structure = { version = version, catalog = current, value = value }
  return value
end

-- catalog switching happens in the go driver; follow it so unqualified names
-- resolve where the driver resolves them
pcall(function()
  require("dbee.api.core").register_event_listener("database_selected", function(data)
    if data and data.conn_id and data.database_name then
      selected[data.conn_id] = data.database_name
      version = version + 1
      M.on_update()
    end
  end)
end)

-- pull the catalog and schema lists ahead of the first keystroke that needs them
local function warm_top()
  local catalog = M.context()
  if not catalog then
    return
  end
  M.catalogs(function() end)
  M.schemas(catalog, function() end)
end

pcall(function()
  require("dbee.api.core").register_event_listener("current_connection_changed", function()
    vim.schedule(warm_top)
  end)
end)

vim.defer_fn(warm_top, 1000)

--- "catalog.schema" or "schema" (current catalog) or "catalog" (whole catalog)
local function parse_arg(arg)
  if not arg or arg == "" then
    return nil, nil
  end
  local catalog, schema = arg:match("^([^.]+)%.([^.]+)$")
  if catalog then
    return catalog, schema
  end
  -- a bare name is a catalog if we know it as one, otherwise a schema
  if vim.tbl_contains(M.catalogs_now(), arg) then
    return arg, nil
  end
  return (M.context()), arg
end

--- drop cached metadata and fetch it again: all of it, one catalog, or one
--- catalog.schema
--- @param arg string|nil
function M.refresh(arg)
  local _, target, profile = M.context()
  if not target then
    return vim.notify("dbee: no unity catalog for this connection", vim.log.levels.WARN)
  end

  local catalog, schema = parse_arg(arg)

  -- one schema is the etl case: drop just that, everything else stays warm
  if catalog and schema then
    local entry = bucket(profile, catalog)
    entry.tables[schema], entry.columns[schema] = nil, nil
    version = version + 1
    M.tables(catalog, schema, function(tables)
      vim.notify(("dbee: %s.%s refreshed, %d tables"):format(catalog, schema, #tables))
    end)
    return
  end

  -- one catalog: forget its schemas so the sweep runs again
  if catalog then
    workspace(profile).tree[catalog] = nil
    version = version + 1
    M.warm_catalog(catalog)
    vim.notify(("dbee: %s dropped, re-sweeping"):format(catalog))
    return
  end

  cache = nil
  version = version + 1
  pcall(vim.fn.delete, M.config.store)
  M.warm_all()
  vim.notify("dbee: catalog cache dropped")
end

vim.api.nvim_create_user_command("DbeeCatalogRefresh", function(opts)
  M.refresh(opts.args)
end, {
  nargs = "?",
  desc = "Refresh cached unity catalog metadata: all of it, one catalog, or one catalog.schema",
  complete = function(lead)
    local items = {}
    local current = M.context()
    for _, catalog in ipairs(M.catalogs_now()) do
      items[#items + 1] = catalog
    end
    for _, schema in ipairs(current and M.schemas_now(current) or {}) do
      items[#items + 1] = M.qualify(current, schema)
    end
    return vim.tbl_filter(function(name)
      return name:find(lead, 1, true) == 1
    end, items)
  end,
})

vim.api.nvim_create_user_command("DbeeCatalog", function()
  local current, _, profile = M.context()
  if not current then
    return vim.notify("dbee: no unity catalog for this connection", vim.log.levels.WARN)
  end

  local tree = workspace(profile).tree
  local names = vim.tbl_keys(tree)
  table.sort(names)

  local lines = {}
  for _, catalog in ipairs(names) do
    local entry = tree[catalog]
    local tables = 0
    for _, cached in pairs(entry.tables) do
      tables = tables + #cached.list
    end
    local swept = entry.swept_at and ("%dm ago"):format(math.floor((now() - entry.swept_at) / 60)) or "never"
    lines[#lines + 1] = ("  %s%s: %d/%d schemas, %d tables, columns for %d, swept %s"):format(
      catalog == current and "* " or "",
      catalog,
      vim.tbl_count(entry.tables),
      #(entry.schemas or {}),
      tables,
      vim.tbl_count(entry.columns),
      swept
    )
  end

  table.insert(lines, 1, ("dbee: %s via %s, %d catalogs, %d queued"):format(
    current,
    profile,
    #M.catalogs_now(),
    #queue + active
  ))
  vim.notify(table.concat(lines, "\n"))
end, { desc = "Show cached unity catalog metadata" })

return M
