-- the drawer builds its tree from blocking driver calls: connection_get_structure
-- runs information_schema (~14s warm, minutes asleep), connection_get_columns
-- another query per table, and the database switcher a SHOW CATALOGS. serve all
-- three from the unity catalog cache and let the tree fill in behind the user.

local ok_handler, Handler = pcall(require, "dbee.handler")
if not ok_handler then
  return
end

local Catalog = require("armino112.plugin.dbee.catalog")
local util = require("armino112.plugin.dbee.util")

local M = {}

M.config = {
  refresh_debounce_ms = 400,
}

local wanted = false
local refresh_pending = false

local function refresh()
  if not wanted or refresh_pending then
    return
  end
  refresh_pending = true

  vim.defer_fn(function()
    refresh_pending = false
    pcall(function()
      require("dbee.api.ui").drawer_refresh()
    end)
  end, M.config.refresh_debounce_ms)
end

Catalog.on_update = refresh

-- the catalog cache only speaks for the connection dbee currently has selected;
-- anything else falls back to the gated driver path
local function serving(id)
  local conn = util.connection()
  return conn ~= nil and conn.id == id and Catalog.available()
end

local function guard(name, serve)
  local original = Handler[name]
  if not original then
    return
  end

  Handler[name] = function(self, id, ...)
    if not serving(id) then
      return original(self, id, ...)
    end
    return serve(id, ...)
  end
end

guard("connection_get_structure", function()
  wanted = true
  Catalog.warm_all()
  return Catalog.structure_now()
end)

guard("connection_get_columns", function(_, opts)
  local columns = Catalog.columns_now(opts and opts.schema, opts and opts.table)
  if columns then
    return columns
  end

  -- not cached yet: fill it in and redraw the node once it lands
  Catalog.tables(opts.schema, function() end)
  return {}
end)

guard("connection_list_databases", function()
  local catalog = Catalog.context()
  Catalog.catalogs(function() end)
  return catalog or "", Catalog.catalogs_now()
end)

return M
