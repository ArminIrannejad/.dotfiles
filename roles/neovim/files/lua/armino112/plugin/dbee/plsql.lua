-- what an lsp would give plsql, borrowed from the database itself: oracle is
-- the only thing that really parses it.
--
-- compile runs every CREATE of a plsql unit in the buffer, split on `/` lines,
-- and reads all_errors back as diagnostics. anything else in the buffer is
-- never run. :w on an oracle:// buffer lands here, :DbeeCompile anywhere else.
--
-- gd resolves the dotted name under the cursor against all_objects and opens
-- its source; a name the database does not know falls back to a declaration in
-- the buffer, and a buffer that is not on oracle keeps the lsp.

local ok_oracle, oracle = pcall(require, "armino112.plugin.dbee.oracle")
if not (ok_oracle and type(oracle) == "table") then
  return
end

local M = {}

M.config = {
  confirm = true, -- ask before anything is compiled on the server
}

local ns = vim.api.nvim_create_namespace("dbee_plsql")

local UNIT_KINDS = { "PACKAGE BODY", "TYPE BODY", "PACKAGE", "TYPE", "PROCEDURE", "FUNCTION", "TRIGGER" }

local ERRORS = [[
SELECT line, position, text, attribute
FROM all_errors
WHERE owner = %s
  AND name = '%s'
  AND type = '%s'
ORDER BY sequence]]

local RESOLVE = [[
SELECT owner, object_name, object_type
FROM all_objects
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'FUNCTION', 'TRIGGER', 'TYPE', 'TYPE BODY',
                      'TABLE', 'VIEW', 'MATERIALIZED VIEW', 'SEQUENCE', 'SYNONYM')
  AND (%s)
ORDER BY CASE WHEN owner = USER THEN 0 WHEN owner = 'PUBLIC' THEN 1 ELSE 2 END]]

local SYNONYM = "SELECT table_owner, table_name FROM all_synonyms WHERE owner = '%s' AND synonym_name = '%s'"

local DDL = "SELECT dbms_metadata.get_ddl('%s', '%s', '%s') ddl /* no_limit */ FROM dual"

--- @return { id: string, name: string, type: string }|nil the oracle connection behind a buffer
local function connection(buf)
  local ok, core = pcall(require, "dbee.api.core")
  if not ok then
    return nil
  end

  local unit = vim.b[buf].dbee_oracle
  if unit then
    local got, params = pcall(core.connection_get_params, unit.conn)
    return got and type(params) == "table" and params or nil
  end

  local got, conn = pcall(core.get_current_connection)
  if got and type(conn) == "table" and conn.type == "oracle" then
    return conn
  end
end

M.connection = connection

-- unquoted names fold to upper case, quoted ones keep theirs
local function ident(s)
  local quoted = s:match('^"(.*)"$')
  return quoted or s:upper()
end

local function skip_comments(text, at)
  while true do
    local s = text:match("^%s*()", at)
    if text:sub(s, s + 1) == "--" then
      at = (text:find("\n", s, true) or #text) + 1
    elseif text:sub(s, s + 1) == "/*" then
      at = (select(2, text:find("*/", s + 2, true)) or #text) + 1
    else
      return s
    end
  end
end

--- @return { kind: string, owner: string|nil, name: string, kw: integer, name_s: integer, name_e: integer }|nil
local function header(text)
  local upper = text:upper()
  local at = skip_comments(text, 1)
  local rest = upper:match("^CREATE%s+()", at)
  if not rest then
    return nil
  end
  rest = upper:match("^OR%s+REPLACE%s+()", rest) or rest
  rest = upper:match("^NONEDITIONABLE%s+()", rest) or upper:match("^EDITIONABLE%s+()", rest) or rest

  for _, kind in ipairs(UNIT_KINDS) do
    local after = upper:match("^" .. kind:gsub(" ", "%%s+") .. "%s+()", rest)
    if after then
      local id = '"[^"]+"'
      local plain = "[%w_$#]+"
      local s, e
      for _, pattern in ipairs({ id .. "%." .. id, id .. "%." .. plain, plain .. "%." .. id, plain .. "%." .. plain, id, plain }) do
        s, e = text:find("^" .. pattern, after)
        if s then
          break
        end
      end
      if not s then
        return nil
      end

      local full = text:sub(s, e)
      local owner, name = full:match('^("?[^".]+"?)%.("?[^".]+"?)$')
      return {
        kind = kind,
        owner = owner and ident(owner) or nil,
        name = ident(name or full),
        kw = rest,
        name_s = s,
        name_e = e,
      }
    end
  end
end

--- @return integer line, integer col 0 based, of a byte offset
local function position(text, offset)
  local before = text:sub(1, offset - 1)
  local _, newlines = before:gsub("\n", "")
  local last = before:match(".*\n()") or 1
  return newlines, offset - last
end

-- every chunk between `/` lines that creates a plsql unit
local function units(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local found = {}
  local start, chunk = 0, {}

  local function flush()
    local text = table.concat(chunk, "\n")
    local head = header(text)
    if head then
      local kw_line, kw_col = position(text, head.kw)
      found[#found + 1] = { start = start, text = text, head = head, kw_line = kw_line, kw_col = kw_col }
    end
  end

  for i, line in ipairs(lines) do
    if line:match("^%s*/%s*$") then
      flush()
      start, chunk = i, {}
    else
      chunk[#chunk + 1] = line
    end
  end
  flush()
  return found
end

local function diagnose(unit, rows, err)
  local out = {}
  for _, row in ipairs(rows or {}) do
    local line = (tonumber(row.LINE) or 1) - 1
    local col = (tonumber(row.POSITION) or 1) - 1
    if line == 0 then
      col = col + unit.kw_col -- stored source starts at the unit keyword
    end
    out[#out + 1] = {
      lnum = unit.start + unit.kw_line + line,
      col = col,
      severity = row.ATTRIBUTE == "WARNING" and vim.diagnostic.severity.WARN or vim.diagnostic.severity.ERROR,
      message = vim.trim((row.TEXT or ""):gsub("\n", " ")),
      source = "oracle",
    }
  end

  -- a failure all_errors knows nothing of is the statement itself
  if #out == 0 and err and not err:find("ORA%-24344") then
    out[1] = {
      lnum = unit.start + unit.kw_line,
      col = 0,
      severity = vim.diagnostic.severity.ERROR,
      message = vim.trim(err:gsub("\n", " ")),
      source = "oracle",
    }
  end
  return out
end

function M.compile(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  local conn = connection(buf)
  if not conn then
    return vim.notify("dbee: no oracle connection for this buffer", vim.log.levels.WARN)
  end

  local found = units(buf)
  if #found == 0 then
    return vim.notify("dbee: nothing to compile, no CREATE of a plsql unit here", vim.log.levels.WARN)
  end

  -- a unit read from another schema compiles back into that schema
  local owner_of = vim.b[buf].dbee_oracle and vim.b[buf].dbee_oracle.owner
  local names = {}
  for _, unit in ipairs(found) do
    unit.owner = unit.head.owner or owner_of
    names[#names + 1] = ("%s%s (%s)"):format(unit.owner and unit.owner .. "." or "", unit.head.name, unit.head.kind:lower())
  end

  if M.config.confirm then
    local ask = ("Compile on %s:\n  %s"):format(conn.name, table.concat(names, "\n  "))
    if vim.fn.confirm(ask, "&Yes\n&No", 2) ~= 1 then
      return
    end
  end

  local diagnostics = {}

  local function finish()
    vim.diagnostic.set(ns, buf, diagnostics)
    local errors = #vim.tbl_filter(function(d)
      return d.severity == vim.diagnostic.severity.ERROR
    end, diagnostics)

    if errors == 0 then
      if vim.bo[buf].buftype == "acwrite" then
        vim.bo[buf].modified = false
      end
      vim.notify(("dbee: compiled %s"):format(table.concat(names, ", ")))
    else
      vim.notify(("dbee: %d error(s), see diagnostics"):format(errors), vim.log.levels.ERROR)
    end
  end

  local function step(i)
    local unit = found[i]
    if not unit then
      return finish()
    end

    local sql = unit.text
    if unit.owner and not unit.head.owner then
      sql = sql:sub(1, unit.head.name_s - 1) .. ('"%s".'):format(unit.owner) .. sql:sub(unit.head.name_s)
    end

    -- the driver trims one trailing `;`, which is the END of the unit
    oracle.query(conn.id, sql .. "\n", function(_, err)
      local owner = unit.owner and ("'%s'"):format(oracle.literal(unit.owner)) or "USER"
      local check = ERRORS:format(owner, oracle.literal(unit.head.name), unit.head.kind)
      oracle.query(conn.id, check, function(rows)
        vim.list_extend(diagnostics, diagnose(unit, rows, err))
        step(i + 1)
      end)
    end, { rows = false })
  end

  vim.diagnostic.reset(ns, buf)
  step(1)
end

--- @return string[]|nil the dotted name under the cursor, up to the part the cursor is on
local function dotted_name()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local part = '[%w_$#"]'
  if not line:sub(col, col):match(part) then
    return nil
  end

  local s, e = col, col
  while s > 1 and line:sub(s - 1, s - 1):match('[%w_$#".]') do
    s = s - 1
  end
  while e < #line and line:sub(e + 1, e + 1):match(part) do
    e = e + 1
  end

  local parts = {}
  for piece in line:sub(s, e):gmatch("[^%.]+") do
    parts[#parts + 1] = ident(piece)
  end
  return #parts > 0 and parts or nil
end

-- a subprogram, cursor or type declared in this buffer
local function local_declaration(name)
  local pattern = [[\c\v<(procedure|function|cursor|type|subtype)\s+\V]] .. name .. [[\>]]
  local here = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local found = vim.fn.search(pattern, "cnW")
  vim.api.nvim_win_set_cursor(0, here)
  if found == 0 or found == here[1] then
    return false
  end
  vim.cmd("normal! m'") -- so <C-o> comes back
  vim.api.nvim_win_set_cursor(0, { found, 0 })
  vim.fn.search([[\v\c<(procedure|function|cursor|type|subtype)\s+\zs]], "cW", found)
  return true
end

local function jump_to_member(buf, member)
  if not (buf and member) then
    return
  end
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.fn.search([[\c\v<(procedure|function)\s+\V]] .. member .. [[\>]], "cW")
  vim.cmd("normal! zz")
end

local function show_ddl(conn, owner, name, object_type)
  local sql = DDL:format(object_type:gsub(" ", "_"), oracle.literal(name), oracle.literal(owner))
  oracle.query(conn.id, sql, function(rows, err)
    local ddl = rows and rows[1] and rows[1].DDL
    if not ddl then
      return vim.notify(("dbee: no ddl for %s.%s: %s"):format(owner, name, err or "not visible"), vim.log.levels.WARN)
    end
    oracle.show(("%s.%s.sql"):format(owner, name), oracle.lines(vim.trim(ddl)), "sql")
  end)
end

local function open(conn, target)
  local types, owner, name, member = target.types, target.owner, target.name, target.member

  if types["PACKAGE"] or types["TYPE"] then
    local spec = types["PACKAGE"] and "PACKAGE" or "TYPE"
    local body = spec .. " BODY"
    -- a member lives in the body; the spec is the fallback when it is hidden
    local first = member and types[body] and body or spec
    return oracle.open(conn.id, owner, name, first, function(buf)
      if not buf and first == body then
        return oracle.open(conn.id, owner, name, spec, function(b)
          jump_to_member(b, member)
        end)
      end
      jump_to_member(buf, member)
    end)
  end

  for _, kind in ipairs({ "PROCEDURE", "FUNCTION", "TRIGGER" }) do
    if types[kind] then
      return oracle.open(conn.id, owner, name, kind)
    end
  end

  for _, kind in ipairs({ "TABLE", "VIEW", "MATERIALIZED VIEW", "SEQUENCE" }) do
    if types[kind] then
      return show_ddl(conn, owner, name, kind)
    end
  end
end

local function resolve(conn, parts, depth, on_found)
  local where = { ("object_name = '%s'"):format(oracle.literal(parts[1])) }
  if parts[2] then
    where[#where + 1] = ("(owner = '%s' AND object_name = '%s')"):format(oracle.literal(parts[1]), oracle.literal(parts[2]))
  end

  oracle.query(conn.id, RESOLVE:format(table.concat(where, " OR ")), function(rows)
    if not rows or #rows == 0 then
      return on_found(nil)
    end

    -- owner.name beats name.member, then the order the query ranked them in
    local pick
    for _, row in ipairs(rows) do
      if parts[2] and row.OWNER == parts[1] and row.OBJECT_NAME == parts[2] then
        pick = { owner = row.OWNER, name = row.OBJECT_NAME, member = parts[3] }
        break
      end
    end
    if not pick then
      for _, row in ipairs(rows) do
        if row.OBJECT_NAME == parts[1] then
          pick = { owner = row.OWNER, name = row.OBJECT_NAME, member = parts[2] }
          break
        end
      end
    end
    if not pick then
      return on_found(nil)
    end

    pick.types = {}
    for _, row in ipairs(rows) do
      if row.OWNER == pick.owner and row.OBJECT_NAME == pick.name then
        pick.types[row.OBJECT_TYPE] = true
      end
    end

    if pick.types["SYNONYM"] and vim.tbl_count(pick.types) == 1 and depth < 3 then
      local sql = SYNONYM:format(oracle.literal(pick.owner), oracle.literal(pick.name))
      return oracle.query(conn.id, sql, function(syn)
        local row = syn and syn[1]
        if not row then
          return on_found(nil)
        end
        resolve(conn, { row.TABLE_OWNER, row.TABLE_NAME, pick.member }, depth + 1, on_found)
      end)
    end
    on_found(pick)
  end)
end

function M.definition()
  local buf = vim.api.nvim_get_current_buf()
  local conn = connection(buf)
  if not conn then
    return vim.lsp.buf.definition()
  end

  local parts = dotted_name()
  if not parts then
    return
  end
  -- a bare name declared right here wins over a schema object of the same name
  if #parts == 1 and local_declaration(parts[1]) then
    return
  end

  resolve(conn, parts, 0, function(target)
    if target then
      return open(conn, target)
    end
    if not local_declaration(parts[#parts]) then
      vim.notify("dbee: no definition for " .. table.concat(parts, "."), vim.log.levels.INFO)
    end
  end)
end

function M.attach(buf)
  vim.keymap.set("n", "gd", M.definition, { buffer = buf, desc = "Go to def (oracle aware)" })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "sql", "plsql" },
  callback = function(args)
    M.attach(args.buf)
  end,
})

-- the buffer that loaded dbee already had its FileType
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(buf) and vim.tbl_contains({ "sql", "plsql" }, vim.bo[buf].filetype) then
    M.attach(buf)
  end
end

vim.api.nvim_create_user_command("DbeeCompile", function()
  M.compile(0)
end, { desc = "Compile the plsql units in this buffer on the oracle connection" })

-- sql files only format through sqlcl while the buffer is on oracle
pcall(function()
  require("conform").formatters_by_ft.sql = function(buf)
    return connection(buf) and { "sqlcl" } or {}
  end
end)

return M
