local ok, Source = pcall(require, "cmp-dbee.source")
if not ok then
  return
end

local Database = require("cmp-dbee.database")
local Catalog = require("armino112.plugin.dbee.catalog")
local Parser = require("cmp-dbee.treesitter")

-- unity catalog answers without compute and off the ui thread; the dbee driver
-- runs information_schema on the cluster and blocks nvim while it does
local function provider()
  return Catalog.available() and Catalog or Database
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

--- @return string|nil
local function qualifier_before_cursor()
  local line = cursor_before_line()
  local qualified = line:match("[%s%(,]([%w_%.]+)%.$") or line:match("^([%w_%.]+)%.$")
  if not qualified then
    return nil
  end
  local segments = vim.split(qualified, ".", { plain = true })
  return segments[#segments]
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

local column_items = memoize(function(columns, schema, model)
  local items = {}
  for _, column in ipairs(columns) do
    items[#items + 1] = {
      label = column.name,
      kind = Kind.Field,
      labelDetails = { description = model },
      documentation = ("%s.%s.%s\nType: %s"):format(schema, model, column.name, column.type),
    }
  end
  return items
end)

local table_items = memoize(function(models, schema)
  local items = {}
  for _, model in ipairs(models) do
    items[#items + 1] = {
      label = model.name,
      kind = Kind.Class,
      labelDetails = { description = model.schema or schema },
      documentation = ("%s.%s\nType: %s"):format(model.schema or schema, model.name, model.type),
    }
  end
  return items
end)

local schema_items = memoize(function(structure)
  local items = {}
  for _, schema in ipairs(structure) do
    items[#items + 1] = {
      label = schema.name,
      kind = Kind.Module,
      documentation = ("Schema: %s"):format(schema.name),
    }
  end
  return items
end)

local catalog_items = memoize(function(structure)
  local items = {}
  vim.list_extend(items, schema_items(structure))
  for _, schema in ipairs(structure) do
    vim.list_extend(items, table_items(schema.children or {}, schema.name))
  end
  return items
end)

local function cte_items(ctes)
  local items = {}
  for _, cte in ipairs(ctes or {}) do
    items[#items + 1] = {
      label = cte.cte,
      kind = Kind.Struct,
      documentation = ("CTE: %s"):format(cte.cte),
    }
  end
  return items
end

local function complete_columns(refs, callback)
  local items = {}
  for _, ref in ipairs(refs) do
    if ref.alias and ref.alias ~= "" then
      items[#items + 1] = {
        label = ref.alias,
        kind = Kind.Variable,
        documentation = ("Alias for %s.%s"):format(ref.schema, ref.model),
      }
    end
  end

  local pending = #refs
  for _, ref in ipairs(refs) do
    provider().get_column_completion(ref.schema, ref.model, function(columns)
      vim.list_extend(items, column_items(columns, ref.schema, ref.model))
      pending = pending - 1
      if pending == 0 then
        callback({ items = items, isIncomplete = false })
      end
    end)
  end
end

local function complete_tables(refs, callback)
  provider().get_db_structure(function(structure)
    structure = structure or {}
    local catalog = catalog_items(structure)
    local ctes = cte_items(refs)

    if #ctes == 0 then
      callback({ items = catalog, isIncomplete = false })
      return
    end

    local items = {}
    vim.list_extend(items, catalog)
    vim.list_extend(items, ctes)
    callback({ items = items, isIncomplete = false })
  end)
end

local function complete_qualified(qualifier, refs, callback)
  local function columns_of(ref)
    provider().get_column_completion(ref.schema, ref.model, function(columns)
      callback({ items = column_items(columns, ref.schema, ref.model), isIncomplete = false })
    end)
  end

  for _, ref in ipairs(refs) do
    if ref.alias ~= "" and ref.alias == qualifier then
      columns_of(ref)
      return
    end
  end

  provider().get_db_structure(function(structure)
    structure = structure or {}
    for _, schema in ipairs(structure) do
      if schema.name == qualifier then
        provider().get_models(schema.name, function(models)
          callback({ items = table_items(models, schema.name), isIncomplete = false })
        end)
        return
      end
    end
    for _, ref in ipairs(refs) do
      if ref.model == qualifier then
        columns_of(ref)
        return
      end
    end
    callback({ items = schema_items(structure), isIncomplete = false })
  end)
end

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

      if schema and schema ~= "" and model ~= "" then
        local alias = words[i + 2] or ""
        if alias:lower() == "as" then
          alias = words[i + 3] or ""
        end
        if TABLE_CLAUSE[alias:lower()] or COLUMN_CLAUSE[alias:lower()] or alias:find("%.") then
          alias = ""
        end
        refs[#refs + 1] = { schema = schema, model = model, alias = alias }
      end
      i = i + 2
    else
      i = i + 1
    end
  end
  return refs
end

Source.complete = function(_, _, callback)
  local references = Parser.get_references_at_cursor()
  local tables = references and references.schema_table_references or {}
  local ctes = references and references.cte_references or {}

  if #tables == 0 then
    tables = references_from_text(statement_text())
  end

  local qualifier = qualifier_before_cursor()
  if qualifier then
    complete_qualified(qualifier, tables, callback)
    return
  end

  if clause_at_cursor() == "column" and #tables > 0 then
    complete_columns(tables, callback)
    return
  end

  complete_tables(ctes, callback)
end

Source.get_trigger_characters = function()
  return { "." }
end

return Source
