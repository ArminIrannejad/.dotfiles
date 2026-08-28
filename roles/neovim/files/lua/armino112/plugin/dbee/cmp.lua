-- completion follows the same shape as the drawer: catalogs -> schemas ->
-- tables -> columns. a dotted prefix is resolved one level at a time against
-- the real hierarchy, so choosing a catalog never offers another catalog's
-- tables, and an unqualified name only ever means the catalog the connection
-- is pinned to.

local ok, Source = pcall(require, "cmp-dbee.source")
if not ok then
  return
end

local Database = require("cmp-dbee.database")
local Catalog = require("armino112.plugin.dbee.catalog")
local Parser = require("cmp-dbee.treesitter")

-- unity catalog answers without compute and off the ui thread; the dbee driver
-- runs information_schema on the cluster and blocks nvim while it does
local unity = {
  default_catalog = function()
    return (Catalog.context())
  end,
  catalogs = Catalog.catalogs,
  schemas = Catalog.schemas,
  tables = Catalog.tables,
  columns = Catalog.table_columns,
  overview = function(callback)
    Catalog.warm_all() -- cached only below, so the fetching happens out here
    local default = Catalog.context()
    local schemas = {}
    for _, catalog in ipairs(Catalog.structure_now()) do
      if catalog.name == default then
        schemas = catalog.children
        break
      end
    end
    -- items are still arriving while the sweep runs; say so, or the client
    -- filters the half-built list locally and never asks again
    callback(Catalog.catalogs_now(), schemas, Catalog.loading())
  end,
}

-- the driver only ever sees the one catalog the dsn pinned, so there is no
-- hierarchy above the schema to offer
local fallback = {
  default_catalog = function()
    return nil
  end,
  catalogs = function(callback)
    callback({}, false)
  end,
  schemas = function(_, callback)
    Database.get_db_structure(function(structure)
      local names = {}
      for _, schema in ipairs(structure or {}) do
        names[#names + 1] = schema.name
      end
      callback(names, false)
    end)
  end,
  tables = function(_, schema, callback)
    Database.get_models(schema, function(models)
      callback(models or {}, false)
    end)
  end,
  columns = function(_, schema, model, callback)
    Database.get_column_completion(schema, model, function(columns)
      callback(columns or {}, false)
    end)
  end,
  overview = function(callback)
    Database.get_db_structure(function(structure)
      callback({}, structure or {}, false)
    end)
  end,
}

local function provider()
  return Catalog.available() and unity or fallback
end

local Kind = vim.lsp.protocol.CompletionItemKind

local TABLE_CLAUSE = {
  from = true,
  join = true,
  into = true,
  update = true,
  table = true,
}

local COLUMN_CLAUSE = {
  select = true,
  where = true,
  on = true,
  by = true,
  having = true,
  set = true,
  distinct = true,
  ["and"] = true,
  ["or"] = true,
  ["not"] = true,
}

--- dotted name for a schema, however much of it we know
local function scope_of(catalog, schema)
  if catalog and catalog ~= "" then
    return catalog .. "." .. schema
  end
  return schema
end

local function cursor_before_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return vim.api.nvim_get_current_line():sub(1, col)
end

local function statement_before_cursor()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local node = Parser.get_cursor_node()
  local start_row = node and node:range() or 0

  local lines = vim.api.nvim_buf_get_lines(0, start_row, row - 1, false)
  lines[#lines + 1] = cursor_before_line()
  return table.concat(lines, "\n")
end

local function statement_text()
  local node = Parser.get_cursor_node()
  if not node then
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  end
  local start_row, _, end_row = node:range()
  return table.concat(vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false), "\n")
end

--- @return "column"|"table"
local function clause_at_cursor()
  local last
  for word in statement_before_cursor():gmatch("[%a_]+") do
    local keyword = word:lower()
    if TABLE_CLAUSE[keyword] or COLUMN_CLAUSE[keyword] then
      last = keyword
    end
  end
  return last and TABLE_CLAUSE[last] and "table" or "column"
end

--- the dotted prefix the cursor sits behind, split into its parts
--- @return string[]|nil
local function qualifier_before_cursor()
  local line = cursor_before_line()
  local qualified = line:match("[%s%(,]([%w_%.]+)%.$") or line:match("^([%w_%.]+)%.$")
  if not qualified then
    return nil
  end

  local segments = vim.split(qualified, ".", { plain = true })
  for _, part in ipairs(segments) do
    if part == "" then
      return nil -- mid-typo like "a..", nothing to resolve against
    end
  end
  return segments
end

local function memoize(build)
  local cache = setmetatable({}, { __mode = "k" })
  return function(key, ...)
    local hit = cache[key]
    if not hit then
      hit = build(key, ...)
      cache[key] = hit
    end
    return hit
  end
end

local column_items = memoize(function(columns, scope, model)
  local items = {}
  for _, column in ipairs(columns) do
    items[#items + 1] = {
      label = column.name,
      kind = Kind.Field,
      labelDetails = { description = model },
      documentation = ("%s.%s.%s\nType: %s"):format(scope, model, column.name, column.type),
    }
  end
  return items
end)

local table_items = memoize(function(models, scope)
  local items = {}
  for _, model in ipairs(models) do
    local where = model.schema or scope
    items[#items + 1] = {
      label = model.name,
      kind = Kind.Class,
      labelDetails = { description = where },
      documentation = ("%s.%s\nType: %s"):format(where, model.name, model.type),
    }
  end
  return items
end)

local schema_items = memoize(function(names, catalog)
  local items = {}
  for _, name in ipairs(names) do
    items[#items + 1] = {
      label = name,
      kind = Kind.Module,
      labelDetails = { description = catalog },
      documentation = ("Schema: %s"):format(scope_of(catalog, name)),
    }
  end
  return items
end)

local catalog_items = memoize(function(names)
  local items = {}
  for _, name in ipairs(names) do
    items[#items + 1] = {
      label = name,
      kind = Kind.Folder,
      documentation = ("Catalog: %s"):format(name),
    }
  end
  return items
end)

-- every schema in the connection's own catalog, plus their tables. a bare name
-- in a query means this catalog, so nothing from another one belongs here.
local overview_items = memoize(function(schemas)
  local items = {}
  for _, schema in ipairs(schemas) do
    local where = schema.schema or schema.name
    items[#items + 1] = {
      label = schema.name,
      kind = Kind.Module,
      labelDetails = { description = where },
      documentation = ("Schema: %s"):format(where),
    }
  end
  for _, schema in ipairs(schemas) do
    vim.list_extend(items, table_items(schema.children or {}, schema.schema or schema.name))
  end
  return items
end)

local function cte_items(ctes)
  local items = {}
  for _, cte in ipairs(ctes or {}) do
    items[#items + 1] = {
      label = cte,
      kind = Kind.Struct,
      documentation = ("CTE: %s"):format(cte),
    }
  end
  return items
end

local function complete_columns(refs, callback)
  local p = provider()
  local default = p.default_catalog()

  local items = {}
  local incomplete = false
  for _, ref in ipairs(refs) do
    if ref.alias and ref.alias ~= "" then
      items[#items + 1] = {
        label = ref.alias,
        kind = Kind.Variable,
        documentation = ("Alias for %s.%s"):format(scope_of(ref.catalog or default, ref.schema), ref.model),
      }
    end
  end

  local pending = #refs
  for _, ref in ipairs(refs) do
    local catalog = ref.catalog or default
    p.columns(catalog, ref.schema, ref.model, function(columns, stale)
      vim.list_extend(items, column_items(columns, scope_of(catalog, ref.schema), ref.model))
      incomplete = incomplete or stale == true
      pending = pending - 1
      if pending == 0 then
        callback({ items = items, isIncomplete = incomplete })
      end
    end)
  end
end

local function complete_tables(ctes, callback)
  provider().overview(function(catalogs, schemas, stale)
    local items = {}
    vim.list_extend(items, catalog_items(catalogs))
    vim.list_extend(items, overview_items(schemas))
    vim.list_extend(items, cte_items(ctes))
    callback({ items = items, isIncomplete = stale == true })
  end)
end

--- resolve a dotted prefix one level at a time against the real hierarchy
local function complete_qualified(segments, refs, callback)
  local p = provider()
  local default = p.default_catalog()

  local function columns_of(catalog, schema, model)
    p.columns(catalog, schema, model, function(columns, stale)
      callback({
        items = column_items(columns, scope_of(catalog, schema), model),
        isIncomplete = stale == true,
      })
    end)
  end

  local function tables_of(catalog, schema)
    p.tables(catalog, schema, function(models, stale)
      callback({ items = table_items(models, scope_of(catalog, schema)), isIncomplete = stale == true })
    end)
  end

  -- three parts leave nothing to guess at
  if #segments >= 3 then
    return columns_of(segments[#segments - 2], segments[#segments - 1], segments[#segments])
  end

  if #segments == 2 then
    local first, second = segments[1], segments[2]
    return p.catalogs(function(catalogs)
      if vim.tbl_contains(catalogs, first) then
        return tables_of(first, second)
      end
      -- not a catalog, so schema.table in the connection's own catalog
      columns_of(default, first, second)
    end)
  end

  -- one part: an alias, a catalog, a schema, or a table already in the query
  local name = segments[1]
  for _, ref in ipairs(refs) do
    if ref.alias ~= "" and ref.alias == name then
      return columns_of(ref.catalog or default, ref.schema, ref.model)
    end
  end

  p.catalogs(function(catalogs)
    if vim.tbl_contains(catalogs, name) then
      return p.schemas(name, function(schemas, stale)
        callback({ items = schema_items(schemas, name), isIncomplete = stale == true })
      end)
    end

    p.schemas(default, function(schemas)
      if vim.tbl_contains(schemas, name) then
        return tables_of(default, name)
      end
      for _, ref in ipairs(refs) do
        if ref.model == name then
          return columns_of(ref.catalog or default, ref.schema, ref.model)
        end
      end
      callback({ items = {}, isIncomplete = false })
    end)
  end)
end

-- upstream's query only reaches two levels and pairs its captures by index, so
-- a three part name loses its catalog and one missing schema shifts every
-- reference after it. match whole relations instead.
local OBJECT_REFERENCE = [[
(relation
  (object_reference
    database: (identifier)? @_catalog
    schema: (identifier)? @_schema
    name: (identifier) @_table)
  alias: (identifier)? @_alias)
]]

local CTE_REFERENCE = "(cte (identifier) @cte)"

local compiled = {}
local function query_for(text)
  if compiled[text] == nil then
    local built, query = pcall(vim.treesitter.query.parse, Parser.filetype, text)
    compiled[text] = built and query or false
  end
  return compiled[text] or nil
end

local function capture_text(match, query, bufnr)
  local parts = {}
  for id, nodes in pairs(match) do
    local node = type(nodes) == "table" and nodes[1] or nodes
    if node then
      parts[query.captures[id]] = vim.treesitter.get_node_text(node, bufnr)
    end
  end
  return parts
end

local function references_at_cursor()
  local node = Parser.get_cursor_node()
  local query = query_for(OBJECT_REFERENCE)
  if not node or not query then
    return {}
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local refs = {}
  for _, match in query:iter_matches(node, bufnr) do
    local parts = capture_text(match, query, bufnr)
    if parts._schema and parts._table then
      refs[#refs + 1] = {
        catalog = parts._catalog,
        schema = parts._schema,
        model = parts._table,
        alias = parts._alias or "",
      }
    end
  end
  return refs
end

local function ctes_at_cursor()
  local node = Parser.get_cursor_node()
  local query = query_for(CTE_REFERENCE)
  if not node or not query then
    return {}
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local names = {}
  for _, match in query:iter_matches(node, bufnr) do
    local parts = capture_text(match, query, bufnr)
    if parts.cte then
      names[#names + 1] = parts.cte
    end
  end
  return names
end

-- treesitter gives up on a half typed statement, which is exactly when
-- completion runs; fall back to reading the references off the raw text
local function references_from_text(text)
  local words = {}
  for word in text:gmatch("[%w_%.]+") do
    words[#words + 1] = word
  end

  local refs = {}
  local i = 1
  while i <= #words do
    local keyword = words[i]:lower()
    if TABLE_CLAUSE[keyword] and words[i + 1] then
      local segments = vim.split(words[i + 1], ".", { plain = true })
      local model = segments[#segments]
      local schema = segments[#segments - 1]
      local catalog = segments[#segments - 2]

      if schema and schema ~= "" and model ~= "" then
        local alias = words[i + 2] or ""
        if alias:lower() == "as" then
          alias = words[i + 3] or ""
        end
        if TABLE_CLAUSE[alias:lower()] or COLUMN_CLAUSE[alias:lower()] or alias:find("%.") then
          alias = ""
        end
        refs[#refs + 1] = { catalog = catalog, schema = schema, model = model, alias = alias }
      end
      i = i + 2
    else
      i = i + 1
    end
  end
  return refs
end

Source.complete = function(_, _, callback)
  local refs = references_at_cursor()
  if #refs == 0 then
    refs = references_from_text(statement_text())
  end

  local segments = qualifier_before_cursor()
  if segments then
    complete_qualified(segments, refs, callback)
    return
  end

  if clause_at_cursor() == "column" and #refs > 0 then
    complete_columns(refs, callback)
    return
  end

  complete_tables(ctes_at_cursor(), callback)
end

Source.get_trigger_characters = function()
  return { "." }
end

return Source
