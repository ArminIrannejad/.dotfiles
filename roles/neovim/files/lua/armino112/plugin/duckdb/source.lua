-- blink.cmp source for duckdb buffers.
--
-- the catalog and the columns come from the database itself, scoped to what
-- the statement under the cursor actually references. keywords, functions and
-- file paths come from duckdb's own sql_auto_complete(), minus the unscoped
-- table and column names it would otherwise add.

local client = require("armino112.plugin.duckdb.client")
local config = require("armino112.plugin.duckdb.config")
local context = require("armino112.plugin.duckdb.context")

local Kind = vim.lsp.protocol.CompletionItemKind

local Source = {}
Source.__index = Source

function Source.new(opts)
  return setmetatable({ opts = opts or {} }, Source)
end

function Source:enabled()
  return vim.bo.filetype == "sql" and client.available() and config.target(0) ~= nil
end

function Source:get_trigger_characters()
  return { "." }
end

local CATALOG = [[
SELECT 'database' AS kind, database_name AS db, NULL AS sch, NULL AS obj
  FROM duckdb_databases() WHERE database_name NOT IN ('system', 'temp')
UNION ALL
SELECT 'schema', database_name, schema_name, NULL
  FROM duckdb_schemas()
  WHERE database_name NOT IN ('system', 'temp') AND (NOT internal OR schema_name = 'main')
UNION ALL
SELECT 'table', database_name, schema_name, table_name
  FROM duckdb_tables() WHERE NOT internal
UNION ALL
SELECT 'view', database_name, schema_name, view_name
  FROM duckdb_views() WHERE NOT internal
UNION ALL
SELECT 'current', current_database(), current_schema(), NULL
]]

--- sql_auto_complete, with each suggestion sorted into what it names
local function suggestions_sql(statement)
  return ([[
WITH s AS (
  SELECT suggestion, suggestion_start FROM sql_auto_complete(%s) LIMIT 300
),
c AS (SELECT DISTINCT lower(column_name) AS n FROM duckdb_columns() WHERE NOT internal),
t AS (
  SELECT lower(table_name) AS n FROM duckdb_tables() WHERE NOT internal
  UNION SELECT lower(view_name) FROM duckdb_views() WHERE NOT internal
),
f AS (SELECT DISTINCT lower(function_name) AS n FROM duckdb_functions())
SELECT suggestion, suggestion_start,
  CASE
    WHEN suggestion LIKE '%% ' THEN 'keyword'
    WHEN lower(replace(suggestion, '"', '')) IN (SELECT n FROM c) THEN 'column'
    WHEN lower(replace(suggestion, '"', '')) IN (SELECT n FROM t) THEN 'table'
    WHEN lower(suggestion) IN (SELECT n FROM f) THEN 'function'
    ELSE 'other'
  END AS kind
FROM s
]]):format(client.literal(statement))
end

local function describe_sql(relation)
  return ("DESCRIBE %sSELECT * FROM %s"):format(relation.with and (relation.with .. " ") or "", relation.source)
end

local function catalog_of(rows)
  local data = { databases = {}, schemas = {}, objects = {}, db = nil, schema = nil }
  for _, row in ipairs(rows or {}) do
    if row.kind == "database" then
      data.databases[#data.databases + 1] = row.db
    elseif row.kind == "schema" then
      data.schemas[#data.schemas + 1] = { db = row.db, name = row.sch }
    elseif row.kind == "table" or row.kind == "view" then
      data.objects[#data.objects + 1] = { db = row.db, schema = row.sch, name = row.obj, kind = row.kind }
    elseif row.kind == "current" then
      data.db, data.schema = row.db, row.sch
    end
  end
  return data
end

local function same(a, b)
  return a ~= nil and b ~= nil and a:lower() == b:lower()
end

local function has_database(data, name)
  for _, db in ipairs(data.databases) do
    if same(db, name) then
      return db
    end
  end
end

local function has_schema(data, db, name)
  for _, schema in ipairs(data.schemas) do
    if same(schema.db, db) and same(schema.name, name) then
      return schema.name
    end
  end
end

local function has_object(data, db, schema, name)
  for _, object in ipairs(data.objects) do
    if same(object.db, db) and same(object.schema, schema) and same(object.name, name) then
      return object
    end
  end
end

--- @param data table
--- @param db string
--- @param schema string
local function objects_in(data, db, schema)
  return vim.tbl_filter(function(object)
    return same(object.db, db) and same(object.schema, schema)
  end, data.objects)
end

local function schemas_in(data, db)
  return vim.tbl_filter(function(schema)
    return same(schema.db, db)
  end, data.schemas)
end

--- a relation written in the query, matched by alias or by name
local function relation_named(relations, name)
  for _, relation in ipairs(relations) do
    if same(relation.alias, name) then
      return relation
    end
  end
  for _, relation in ipairs(relations) do
    if not relation.alias and same(relation.name, name) then
      return relation
    end
  end
end

function Source:get_completions(ctx, callback)
  local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
  local target = config.target(bufnr)
  local empty = { items = {}, is_incomplete_forward = false, is_incomplete_backward = false }
  if not target then
    callback(empty)
    return function() end
  end

  local row, col = ctx.cursor[1], ctx.cursor[2]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local line = lines[row] or ""
  local before = (row > 1 and (table.concat(lines, "\n", 1, row - 1) .. "\n") or "") .. line:sub(1, col)
  local after = line:sub(col + 1) .. (row < #lines and ("\n" .. table.concat(lines, "\n", row + 1)) or "")

  local analysis = context.analyze(before .. after, #before)
  if analysis.skip then
    callback(empty)
    return function() end
  end

  local position = analysis.position
  if analysis.in_string and (position == "column" or position == "qualified") then
    callback(empty)
    return function() end
  end

  local cancelled = false
  local cancels = {}

  local function run(sql, handler)
    cancels[#cancels + 1] = client.run(target, sql, function(rows)
      if not cancelled then
        handler(rows)
      end
    end)
  end

  -- what the cursor's word replaces; a quote typed in front of it goes too
  local typed = analysis.prefix:match("[^\n]*$")
  local function edit(start_col, text)
    return {
      newText = text,
      range = {
        start = { line = row - 1, character = math.max(0, start_col) },
        ["end"] = { line = row - 1, character = col },
      },
    }
  end

  local function item(label, kind, extra)
    local text = context.quote(label)
    if typed:sub(1, 1) == '"' and text:sub(1, 1) ~= '"' then
      text = '"' .. label .. '"' -- they already opened a quote
    end
    return vim.tbl_extend("force", {
      label = label,
      kind = kind,
      filterText = label,
      sortText = "0" .. label:lower(),
      textEdit = edit(col - #typed, text),
    }, extra or {})
  end

  local function finish(items, incomplete)
    if cancelled then
      return
    end
    callback({ items = items, is_incomplete_forward = incomplete == true, is_incomplete_backward = false })
  end

  -- duckdb's own suggestions, optionally narrowed to some kinds
  local function suggestion_items(rows, keep)
    local items = {}
    local statement_length = #analysis.statement
    for index, row in ipairs(rows or {}) do
      if keep[row.kind] then
        local label = (row.suggestion:gsub("%s+$", ""))
        local kind = ({
          keyword = Kind.Keyword,
          ["function"] = Kind.Function,
          column = Kind.Field,
          table = Kind.Class,
        })[row.kind] or Kind.Text
        if label:sub(-1) == "/" then
          kind = Kind.Folder
        elseif analysis.in_string then
          kind = Kind.File
        end
        items[#items + 1] = {
          label = label,
          kind = kind,
          filterText = (label:gsub('^"(.*)"$', "%1")),
          sortText = ("1%04d"):format(index),
          textEdit = edit(col - (statement_length - row.suggestion_start), row.suggestion),
        }
      end
    end
    return items
  end

  local function column_items(columns, relation)
    local where = relation.alias or relation.name or "subquery"
    local items = {}
    for _, column in ipairs(columns or {}) do
      items[#items + 1] = item(column.column_name, Kind.Field, {
        detail = column.column_type,
        labelDetails = { description = where },
        documentation = ("%s.%s\n%s"):format(where, column.column_name, column.column_type),
      })
    end
    return items
  end

  local function columns_of(relation, handler)
    run(describe_sql(relation), function(rows)
      handler(column_items(rows, relation))
    end)
  end

  -- `x.` where x is something written in the query, or part of a catalog path
  local function complete_qualified()
    local parts = analysis.qualifier
    local relation = #parts == 1 and relation_named(analysis.relations, parts[1])
    if relation then
      return columns_of(relation, function(items)
        finish(items)
      end)
    end

    run(CATALOG, function(rows)
      local data = catalog_of(rows)
      local items = {}

      local function tables(db, schema)
        for _, object in ipairs(objects_in(data, db, schema)) do
          items[#items + 1] = item(object.name, Kind.Class, {
            detail = object.kind,
            labelDetails = { description = schema },
          })
        end
      end

      local function columns(db, schema, name)
        local object = has_object(data, db, schema, name)
        if not object then
          return finish({})
        end
        local source = table.concat({ context.quote(object.db), context.quote(object.schema), context.quote(object.name) }, ".")
        columns_of({ source = source, name = object.name }, function(found)
          finish(found)
        end)
      end

      local first, second, third = parts[1], parts[2], parts[3]
      if third then
        return columns(first, second, third)
      end

      if second then
        local db = has_database(data, first)
        if db and has_schema(data, db, second) then
          tables(db, has_schema(data, db, second))
          return finish(items)
        end
        return columns(data.db, first, second)
      end

      local db = has_database(data, first)
      if db then
        for _, schema in ipairs(schemas_in(data, db)) do
          items[#items + 1] = item(schema.name, Kind.Module, { labelDetails = { description = db } })
        end
        tables(db, "main")
        return finish(items)
      end

      local schema = has_schema(data, data.db, first)
      if schema then
        tables(data.db, schema)
        return finish(items)
      end

      -- a table named without its alias: t.|
      local object = has_object(data, data.db, data.schema, first)
      if object then
        return columns(data.db, data.schema, first)
      end
      finish({})
    end)
  end

  local function complete_tables()
    local pending = 2
    local items = {}
    local function done()
      pending = pending - 1
      if pending == 0 then
        table.sort(items, function(a, b)
          return a.sortText < b.sortText
        end)
        finish(items, true)
      end
    end

    run(CATALOG, function(rows)
      local data = catalog_of(rows)
      for _, object in ipairs(objects_in(data, data.db, data.schema)) do
        items[#items + 1] = item(object.name, Kind.Class, { detail = object.kind })
      end
      for _, schema in ipairs(schemas_in(data, data.db)) do
        items[#items + 1] = item(schema.name, Kind.Module, { detail = "schema", sortText = "0~" .. schema.name })
      end
      for _, db in ipairs(data.databases) do
        items[#items + 1] = item(db, Kind.Folder, { detail = "database", sortText = "0~" .. db })
      end
      for _, name in ipairs(analysis.ctes) do
        items[#items + 1] = item(name, Kind.Struct, { detail = "cte", sortText = "0" .. name })
      end
      done()
    end)

    -- table functions and files; names of tables come from the catalog above
    run(suggestions_sql(analysis.statement), function(rows)
      vim.list_extend(items, suggestion_items(rows, { ["function"] = true, other = true }))
      done()
    end)
  end

  local function complete_columns()
    local seen, relations = {}, {}
    for _, relation in ipairs(analysis.relations) do
      local key = (relation.with or "") .. relation.source
      if not seen[key] then
        seen[key] = true
        relations[#relations + 1] = relation
      end
    end

    local pending = #relations + 1
    local items = {}
    local function done()
      pending = pending - 1
      if pending == 0 then
        finish(items, true)
      end
    end

    -- t. and x. start a qualified name
    for _, relation in ipairs(analysis.relations) do
      local name = relation.alias or relation.name
      if name then
        items[#items + 1] = item(name, Kind.Variable, {
          detail = relation.kind,
          sortText = "0~" .. name,
        })
      end
    end

    for _, relation in ipairs(relations) do
      columns_of(relation, function(found)
        vim.list_extend(items, found)
        done()
      end)
    end

    -- with something to scope to, unscoped names from duckdb are noise
    local keep = { keyword = true, ["function"] = true, other = true }
    if #relations == 0 then
      keep.column, keep.table = true, true
    end
    run(suggestions_sql(analysis.statement), function(rows)
      vim.list_extend(items, suggestion_items(rows, keep))
      done()
    end)
  end

  if position == "qualified" then
    complete_qualified()
  elseif position == "table" and not analysis.in_string then
    complete_tables()
  elseif position == "column" then
    complete_columns()
  else
    run(suggestions_sql(analysis.statement), function(rows)
      finish(suggestion_items(rows, { keyword = true, ["function"] = true, other = true, table = true, column = true }), true)
    end)
  end

  return function()
    cancelled = true
    for _, cancel in ipairs(cancels) do
      cancel()
    end
  end
end

return Source
