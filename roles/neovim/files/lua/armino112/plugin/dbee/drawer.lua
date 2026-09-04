-- the drawer builds its tree from blocking driver calls: connection_get_structure
-- runs information_schema (~14s warm, minutes asleep), connection_get_columns
-- another query per table, and the database switcher a SHOW CATALOGS. serve all
-- three from the unity catalog cache and let the tree fill in behind the user.
--
-- the tree is catalogs -> schemas -> tables. dbee only carries a `schema` field
-- down to the driver, so a schema node names itself "catalog.schema"; that is
-- what comes back in TableOptions and what turns every generated query into a
-- three part name, which is how a query escapes the catalog pinned in the dsn.

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

-- catalogs and schemas are containers and always keep a child, so they stay
-- expandable while their contents are still in flight. tables are left alone:
-- dbee hangs its own lazy column loader off them.
local function to_nodes(structs)
  local nodes = {}
  for _, struct in ipairs(structs) do
    local children = struct.children or {}
    local node = { name = struct.name, schema = struct.schema, type = struct.type }
    if struct.type == "catalog" or struct.type == "schema" then
      node.children = #children > 0 and to_nodes(children) or { loading_node(struct.schema) }
    end
    nodes[#nodes + 1] = node
  end
  return nodes
end

guard("connection_get_structure", function()
  wanted = true
  Catalog.warm_all()
  return to_nodes(Catalog.structure_now())
end)

guard("connection_get_columns", function(_, opts)
  local qualified = opts and opts.schema
  local catalog, schema = Catalog.split(qualified)
  if catalog and schema then
    Catalog.columns(catalog, schema, function() end) -- no-op when fresh, revalidates when not
  end

  local columns = Catalog.columns_now(qualified, opts and opts.table)
  if columns then
    return columns -- empty is a real answer here: the table has no columns
  end
  return { { name = "loading", type = "" } }
end)

guard("connection_list_databases", function()
  local catalog = Catalog.context()
  Catalog.catalogs(function() end)
  -- still worth switching: this is where unqualified names in a note resolve
  return catalog or "", Catalog.catalogs_now()
end)

-- upstream's helpers format TableOptions as "%s.%s", so a qualified schema
-- already yields catalog.schema.table for List and Describe. the
-- information_schema ones need the catalog moved to the front instead, since
-- table_schema is a bare name there.
guard("connection_get_helpers", function(_, opts)
  local catalog, schema = Catalog.split(opts and opts.schema)
  local model = opts and opts.table
  if not (catalog and schema and model) then
    return {}
  end

  local fqn = ("%s.%s.%s"):format(catalog, schema, model)
  local function lookup(view)
    return ([[
SELECT *
FROM %s.information_schema.%s
WHERE table_schema = '%s'
  AND table_name = '%s';]]):format(catalog, view, schema, model)
  end

  return {
    List = ("SELECT * FROM %s LIMIT 100;"):format(fqn),
    Describe = ("DESCRIBE EXTENDED %s;"):format(fqn),
    Columns = lookup("columns"),
    Constraints = lookup("table_constraints"),
    Keys = lookup("key_column_usage"),
  }
end)

-- upstream's only refresh is the `r` mapping, and that just redraws the tree.
-- now that the tree is served from the catalog cache a redraw hands back the
-- same names, so hang a node off every connection that drops the cache first.
pcall(function()
  local convert = require("dbee.ui.drawer.convert")
  local NuiTree = require("nui.tree")
  local handler_nodes = convert.handler_nodes

  local function refresh_node(id)
    return NuiTree.Node({
      id = id .. "__catalog_refresh__",
      name = "refresh",
      type = "refresh",
      action_1 = function(cb)
        if serving(id) then
          Catalog.refresh()
        end
        cb() -- a connection the cache does not serve refetches from the driver
      end,
    })
  end

  -- the connection's children are lazy, so the node has to go in behind them
  convert.handler_nodes = function(...)
    local nodes = handler_nodes(...)
    for _, source in ipairs(nodes) do
      for _, node in ipairs(source.__children or {}) do
        local lazy = node.lazy_children
        if node.type == "connection" and lazy then
          node.lazy_children = function()
            local children = lazy()
            table.insert(children, 1, refresh_node(node.id))
            return children
          end
        end
      end
    end
    return nodes
  end
end)

-- expanding a catalog or a schema is the only signal that someone wants its
-- contents; the structure call fires on refresh, not on expand, so hook the
-- action itself. a catalog nobody opens costs nothing.
pcall(function()
  local DrawerUI = require("dbee.ui.drawer")
  local get_actions = DrawerUI.get_actions

  DrawerUI.get_actions = function(self)
    local actions = get_actions(self)

    local function prime()
      if not Catalog.available() then
        return
      end
      local node = self.tree and self.tree:get_node()
      if not node then
        return
      end

      if node.type == "catalog" then
        Catalog.warm_catalog(node.name)
      elseif node.type == "schema" then
        local catalog, schema = Catalog.split(node.schema)
        if catalog and schema then
          Catalog.tables(catalog, schema, function() end)
        end
      end
    end

    for _, name in ipairs({ "expand", "toggle" }) do
      local action = actions[name]
      if action then
        actions[name] = function()
          pcall(prime)
          action()
        end
      end
    end

    return actions
  end
end)

return M
