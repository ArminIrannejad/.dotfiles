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

-- nui refuses to expand a node with no children, and a node that never got
-- marked expanded is not re-populated by the refresh that brings the real ones.
-- so anything still loading gets a placeholder child to expand onto.
local function loading_node(schema)
  return { name = "loading", schema = schema, type = "" }
end

guard("connection_get_structure", function()
  wanted = true
  Catalog.warm_all()

  local nodes = {}
  for _, schema in ipairs(Catalog.structure_now()) do
    local children = schema.children
    nodes[#nodes + 1] = {
      name = schema.name,
      schema = schema.schema,
      type = schema.type,
      children = #children > 0 and children or { loading_node(schema.name) },
    }
  end
  return nodes
end)

guard("connection_get_columns", function(_, opts)
  local schema = opts and opts.schema
  Catalog.columns(schema, function() end) -- no-op when fresh, revalidates when not

  local columns = Catalog.columns_now(schema, opts and opts.table)
  if columns then
    return columns -- empty is a real answer here: the table has no columns
  end
  return { { name = "loading", type = "" } }
end)

guard("connection_list_databases", function()
  local catalog = Catalog.context()
  Catalog.catalogs(function() end)
  return catalog or "", Catalog.catalogs_now()
end)

return M
