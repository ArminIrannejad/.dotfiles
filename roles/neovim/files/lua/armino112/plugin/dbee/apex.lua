-- apex keeps an application in its own metadata views, not as objects in a
-- schema, so nothing upstream lists ever reaches it. this hangs an `apex` node
-- off an oracle connection: each app the schema can see, its pages, and every
-- component on a page that carries code. a page opens as one buffer holding
-- all of it in page designer order, a component opens on its own.

local ok_tree, NuiTree = pcall(require, "nui.tree")
local ok_oracle, oracle = pcall(require, "armino112.plugin.dbee.oracle")
if not (ok_tree and ok_oracle and type(oracle) == "table") then
  return
end

local M = {}

-- every component with code, one row each. ids are text: apex ids run past
-- what a json number holds exactly. working copies would list every page twice.
local COMPONENTS = [[
SELECT TO_CHAR(application_id) app, TO_CHAR(page_id) page, 'page' kind, TO_CHAR(page_id * 10 + 1) id,
  'javascript' name, 1 seq, 'js' lang, javascript_code code
FROM apex_application_pages WHERE working_copy_name IS NULL AND javascript_code IS NOT NULL
UNION ALL
SELECT TO_CHAR(application_id), TO_CHAR(page_id), 'page', TO_CHAR(page_id * 10 + 2),
  'javascript onload', 2, 'js', javascript_code_onload
FROM apex_application_pages WHERE working_copy_name IS NULL AND javascript_code_onload IS NOT NULL
UNION ALL
SELECT TO_CHAR(application_id), TO_CHAR(page_id), 'page', TO_CHAR(page_id * 10 + 3),
  'inline css', 3, 'css', inline_css
FROM apex_application_pages WHERE working_copy_name IS NULL AND inline_css IS NOT NULL
UNION ALL
SELECT TO_CHAR(application_id), TO_CHAR(page_id), 'page', TO_CHAR(page_id * 10 + 4),
  'html header', 4, 'html', page_html_header
FROM apex_application_pages WHERE working_copy_name IS NULL AND page_html_header IS NOT NULL
UNION ALL
SELECT TO_CHAR(application_id), TO_CHAR(page_id), 'region', TO_CHAR(region_id),
  region_name, display_sequence, CASE WHEN source_type_code LIKE 'STATIC%' THEN 'html' ELSE 'sql' END, region_source
FROM apex_application_page_regions WHERE working_copy_name IS NULL AND region_source IS NOT NULL
UNION ALL
SELECT TO_CHAR(application_id), TO_CHAR(page_id), 'item', TO_CHAR(item_id),
  item_name, display_sequence, 'sql', TO_CLOB(item_source)
FROM apex_application_page_items
WHERE working_copy_name IS NULL AND item_source IS NOT NULL AND item_source_type LIKE '%SQL%'
UNION ALL
SELECT TO_CHAR(application_id), TO_CHAR(page_id), 'lov', TO_CHAR(item_id),
  item_name, display_sequence, 'sql', TO_CLOB(lov_definition)
FROM apex_application_page_items WHERE working_copy_name IS NULL AND lov_definition IS NOT NULL
UNION ALL
SELECT TO_CHAR(application_id), TO_CHAR(page_id), 'computation', TO_CHAR(computation_id),
  item_name, execution_sequence, 'sql', TO_CLOB(computation)
FROM apex_application_page_comp WHERE working_copy_name IS NULL AND computation IS NOT NULL
UNION ALL
SELECT TO_CHAR(application_id), TO_CHAR(page_id), 'validation', TO_CHAR(validation_id),
  validation_name, validation_sequence, 'sql', TO_CLOB(validation_expression1)
FROM apex_application_page_val
WHERE working_copy_name IS NULL AND validation_expression1 IS NOT NULL AND validation_type_code NOT LIKE 'ITEM%'
UNION ALL
SELECT TO_CHAR(application_id), TO_CHAR(page_id), 'process', TO_CHAR(process_id),
  process_name, execution_sequence, CASE process_source_language WHEN 'JAVASCRIPT' THEN 'js' ELSE 'sql' END,
  process_source
FROM apex_application_page_proc
WHERE working_copy_name IS NULL AND process_source IS NOT NULL AND process_source_language IS NOT NULL
UNION ALL
SELECT TO_CHAR(application_id), TO_CHAR(page_id), 'dynamic action', TO_CHAR(action_id),
  dynamic_action_name || ' - ' || action_name, action_sequence,
  CASE action_code WHEN 'NATIVE_JAVASCRIPT_CODE' THEN 'js' ELSE 'sql' END, TO_CLOB(attribute_01)
FROM apex_application_page_da_acts
WHERE working_copy_name IS NULL AND attribute_01 IS NOT NULL
  AND action_code IN ('NATIVE_JAVASCRIPT_CODE', 'NATIVE_EXECUTE_PLSQL_CODE')
UNION ALL
SELECT TO_CHAR(application_id), NULL, 'application process', TO_CHAR(application_process_id),
  process_name, process_sequence, CASE process_language WHEN 'JAVASCRIPT' THEN 'js' ELSE 'sql' END, process
FROM apex_application_processes WHERE working_copy_name IS NULL AND process IS NOT NULL
UNION ALL
SELECT TO_CHAR(application_id), NULL, 'shared lov', TO_CHAR(lov_id),
  list_of_values_name, 0, 'sql', TO_CLOB(list_of_values_query)
FROM apex_application_lovs WHERE working_copy_name IS NULL AND list_of_values_query IS NOT NULL]]

local PAGES = [[
SELECT TO_CHAR(a.application_id) app, a.application_name app_name, TO_CHAR(p.page_id) page, p.page_name
FROM apex_applications a
JOIN apex_application_pages p
  ON p.application_id = a.application_id AND p.working_copy_name IS NULL
WHERE a.working_copy_name IS NULL]]

-- the union is full of LIKE patterns, so only ever format the filter behind it
local LIST = "SELECT app, page, kind, id, name, seq FROM (" .. COMPONENTS .. ")"
local ONE = "SELECT lang, code /* no_limit */ FROM (" .. COMPONENTS .. ")\nWHERE "
local SOME = "SELECT kind, name, seq, code /* no_limit */ FROM (" .. COMPONENTS .. ")\nWHERE "

-- page designer order
local ORDER = {
  ["page"] = 1,
  ["region"] = 2,
  ["item"] = 3,
  ["lov"] = 4,
  ["computation"] = 5,
  ["validation"] = 6,
  ["process"] = 7,
  ["dynamic action"] = 8,
  ["application process"] = 9,
  ["shared lov"] = 10,
}

local LANGS = {
  js = { ext = "js", filetype = "javascript" },
  css = { ext = "css", filetype = "css" },
  html = { ext = "html", filetype = "html" },
  sql = { ext = "sql", filetype = "plsql" },
}

local apps = {} -- connection id -> app list, false where apex is not there to ask
local loading = {}

local function by_order(a, b)
  local ka, kb = ORDER[a.kind] or 99, ORDER[b.kind] or 99
  if ka ~= kb then
    return ka < kb
  end
  local sa, sb = tonumber(a.seq) or 0, tonumber(b.seq) or 0
  if sa ~= sb then
    return sa < sb
  end
  return a.name < b.name
end

local function by_number(a, b)
  return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
end

local function shape(page_rows, component_rows)
  local list, index = {}, {}

  for _, row in ipairs(page_rows) do
    local app = index[row.APP]
    if not app then
      app = { id = row.APP, name = row.APP_NAME or "", pages = {}, by_page = {}, shared = {} }
      index[row.APP] = app
      list[#list + 1] = app
    end
    local page = { id = row.PAGE, name = row.PAGE_NAME or "", components = {} }
    app.pages[#app.pages + 1] = page
    app.by_page[row.PAGE] = page
  end

  for _, row in ipairs(component_rows) do
    local app = index[row.APP]
    if app then
      local component = { kind = row.KIND, id = row.ID, name = row.NAME or "", seq = row.SEQ, page = row.PAGE }
      local page = row.PAGE and app.by_page[row.PAGE]
      table.insert(page and page.components or app.shared, component)
    end
  end

  table.sort(list, by_number)
  for _, app in ipairs(list) do
    table.sort(app.pages, by_number)
    table.sort(app.shared, by_order)
    for _, page in ipairs(app.pages) do
      table.sort(page.components, by_order)
    end
  end
  return list
end

local function load(id)
  if loading[id] then
    return
  end
  loading[id] = true

  local got = {}
  local function done()
    if got.pages == nil or got.components == nil then
      return
    end
    loading[id] = nil
    -- no apex views means no apex here; nothing to say about that
    apps[id] = got.pages and got.components and shape(got.pages, got.components) or false
    oracle.redraw()
  end

  oracle.query(id, PAGES, function(rows)
    got.pages = rows or false
    done()
  end)
  oracle.query(id, LIST, function(rows)
    got.components = rows or false
    done()
  end)
end

function M.forget(id)
  if apps[id] ~= nil then
    load(id)
  end
end

pcall(function()
  table.insert(require("armino112.plugin.dbee.drawer").refreshers, M.forget)
end)

local function label(component)
  return component.kind .. ": " .. component.name
end

local function file_part(s)
  return (tostring(s):gsub("[%s/\\]+", "_"))
end

local function open_component(id, app, component)
  local sql = ONE
    .. ("app = '%s' AND kind = '%s' AND id = '%s'"):format(
      oracle.literal(app.id),
      oracle.literal(component.kind),
      oracle.literal(component.id)
    )
  oracle.query(id, sql, function(rows, err)
    local row = rows and rows[1]
    if not row then
      return vim.notify("dbee: no code for " .. label(component) .. ": " .. (err or "gone"), vim.log.levels.WARN)
    end

    local lang = LANGS[row.LANG] or LANGS.sql
    local where = component.page and ("p" .. component.page) or "shared"
    local title = ("APEX.%s.%s.%s.%s.%s"):format(
      app.id,
      where,
      file_part(component.kind),
      file_part(component.name),
      lang.ext
    )
    oracle.show(title, oracle.lines(row.CODE or ""), lang.filetype)
  end)
end

-- the whole page in one buffer, a comment ahead of every component
local function open_page(id, app, page)
  local filter = page and ("page = '%s'"):format(oracle.literal(page.id)) or "page IS NULL"
  oracle.query(id, SOME .. ("app = '%s' AND %s"):format(oracle.literal(app.id), filter), function(rows, err)
    if not rows then
      return vim.notify("dbee: apex page failed: " .. (err or "no result"), vim.log.levels.WARN)
    end

    local components = {}
    for _, row in ipairs(rows) do
      components[#components + 1] = { kind = row.KIND, name = row.NAME or "", seq = row.SEQ, code = row.CODE or "" }
    end
    table.sort(components, by_order)

    local heading = page and ("page %s %s"):format(page.id, page.name) or "shared components"
    local lines = { ("-- %s, app %s %s"):format(heading, app.id, app.name) }
    if #components == 0 then
      lines[#lines + 1] = "-- nothing on it carries code"
    end
    for _, component in ipairs(components) do
      lines[#lines + 1] = ""
      lines[#lines + 1] = "-- " .. label(component)
      vim.list_extend(lines, oracle.lines(component.code))
    end

    oracle.show(("APEX.%s.%s.sql"):format(app.id, page and ("p" .. page.id) or "shared"), lines)
  end)
end

local function component_nodes(id, app, parent_id, components)
  local nodes = {}
  for _, component in ipairs(components) do
    nodes[#nodes + 1] = NuiTree.Node({
      id = parent_id .. "__" .. component.kind .. "_" .. component.id,
      name = label(component),
      type = "apex_component",
      action_1 = function()
        open_component(id, app, component)
      end,
    })
  end
  return nodes
end

local function apex_node(id, list)
  local apex_id = id .. "__apex__"
  local app_nodes = {}

  for _, app in ipairs(list) do
    local app_id = apex_id .. app.id
    local children = {}

    if #app.shared > 0 then
      local shared_id = app_id .. "__shared"
      children[#children + 1] = NuiTree.Node({
        id = shared_id,
        name = "shared components",
        type = "folder",
        action_1 = function()
          open_page(id, app, nil)
        end,
      }, component_nodes(id, app, shared_id, app.shared))
    end

    for _, page in ipairs(app.pages) do
      local page_id = app_id .. "__page_" .. page.id
      children[#children + 1] = NuiTree.Node({
        id = page_id,
        name = page.id .. " " .. page.name,
        type = "apex_page",
        action_1 = function()
          open_page(id, app, page)
        end,
      }, component_nodes(id, app, page_id, page.components))
    end

    app_nodes[#app_nodes + 1] = NuiTree.Node({ id = app_id, name = app.id .. " " .. app.name, type = "apex_app" }, children)
  end

  return NuiTree.Node({ id = apex_id, name = "apex", type = "apex" }, app_nodes)
end

-- ahead of the schemas, behind the refresh node
table.insert(oracle.grafts, function(id, children)
  if apps[id] == nil then
    return load(id)
  end
  if not apps[id] or #apps[id] == 0 then
    return
  end

  local at = #children + 1
  for i, node in ipairs(children) do
    if node.type == "schema" then
      at = i
      break
    end
  end
  table.insert(children, at, apex_node(id, apps[id]))
end)

return M
