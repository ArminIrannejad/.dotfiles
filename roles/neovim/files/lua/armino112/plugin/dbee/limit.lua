-- host.lua bounds how many rows the host reads, which holds for every dialect
-- but pushes nothing down: the engine still scans the lot. so where a trailing
-- LIMIT is unambiguously valid, send one, and let the engine stop instead.
--
-- unambiguously is doing the work. the statement has to be a plain select, on a
-- dialect with a trailing cap (`LIMIT`, or oracle's `FETCH FIRST`), with nothing
-- after the select list that cap cannot follow. anything else -- sqlserver's
-- TOP, EXPLAIN, DESCRIBE, the non-sql adapters -- is left to the host cap.
-- `no_limit` in the query opts out of both, silently.

local ok_handler, Handler = pcall(require, "dbee.handler")
if not ok_handler then
  return
end

local host = require("armino112.plugin.dbee.host")

local M = {}

M.config = {
  marker = "no_limit",
}

-- adapters that take a trailing cap, by every alias they register under
local LIMIT = "LIMIT %d"
local dialects = {
  bigquery = LIMIT,
  clickhouse = LIMIT,
  databricks = LIMIT,
  duck = LIMIT,
  duckdb = LIMIT,
  mysql = LIMIT,
  oracle = "FETCH FIRST %d ROWS ONLY", -- 12c and up
  pg = LIMIT,
  postgres = LIMIT,
  postgresql = LIMIT,
  redshift = LIMIT,
  sqlite = LIMIT,
  sqlite3 = LIMIT,
}

-- blank the contents of comments, string literals and quoted identifiers so the
-- keyword and paren scans below never trip on them. length is preserved, so
-- offsets still point at the original query.
local function mask(query)
  local out, i, n = {}, 1, #query

  local function blank(stop)
    out[#out + 1] = (" "):rep(stop - i)
    i = stop
  end

  while i <= n do
    local c = query:sub(i, i)
    local two = query:sub(i, i + 1)

    if two == "--" then
      blank(query:find("\n", i, true) or n + 1)
    elseif two == "/*" then
      local stop = query:find("*/", i + 2, true)
      blank(stop and stop + 2 or n + 1)
    elseif c == "'" or c == '"' or c == "`" then
      local j = i + 1
      while j <= n do
        local d = query:sub(j, j)
        if d == "\\" then
          j = j + 2
        elseif d ~= c then
          j = j + 1
        elseif query:sub(j + 1, j + 1) == c then
          j = j + 2 -- a doubled quote stays inside the literal
        else
          j = j + 1
          break
        end
      end
      blank(math.min(j, n + 1))
    else
      out[#out + 1] = c
      i = i + 1
    end
  end

  return table.concat(out)
end

-- paren depth at every offset, so a keyword can be told from the same keyword
-- inside a subquery
local function depths(masked)
  local d, depth = {}, 0
  for i = 1, #masked do
    local c = masked:sub(i, i)
    if c == "(" then
      depth = depth + 1
      d[i] = depth
    elseif c == ")" then
      d[i] = depth
      depth = depth - 1
    else
      d[i] = depth
    end
  end
  return d
end

local function has_top_level(masked, d, word)
  local pattern = "%f[%w_]" .. word .. "%f[^%w_]"
  local at = 1
  while true do
    local s = masked:find(pattern, at)
    if not s then
      return false
    end
    if d[s] == 0 then
      return true
    end
    at = s + 1
  end
end

local skips = {
  -- a cte can feed a write, and a cap belongs on neither half of one
  "insert",
  "create",
  "update",
  "delete",
  "merge",
  "replace",
  "alter",
  "drop",

  -- already bounded, or bounded by a clause nothing may follow
  "limit",
  "fetch", -- FETCH FIRST n ROWS ONLY
  "offset", -- LIMIT after OFFSET is a syntax error where it parses at all
  "into", -- SELECT INTO, INTO OUTFILE
  "for", -- FOR UPDATE / FOR SHARE
}

--- @param id string connection id
--- @return string|nil the trailing cap this connection's dialect takes
local function cap(id)
  local ok, core = pcall(require, "dbee.api.core")
  if not ok then
    return nil
  end
  local got, params = pcall(core.connection_get_params, id)
  return got and type(params) == "table" and dialects[params.type] or nil
end

--- @param id string connection id
--- @return string|nil query with a row cap appended, nil to leave it alone
function M.apply(id, query)
  local rows = host.config.rows
  if type(query) ~= "string" or not rows or rows <= 0 then
    return nil
  end

  if query:lower():find("%f[%w_]" .. M.config.marker .. "%f[^%w_]") then
    return nil
  end

  local masked = mask(query):lower()
  local head = masked:match("^%s*([%a_]+)")
  if head ~= "select" and head ~= "with" then
    return nil
  end

  local d = depths(masked)

  for _, word in ipairs(skips) do
    if has_top_level(masked, d, word) then
      return nil
    end
  end

  local clause = cap(id)
  if not clause then
    return nil
  end

  -- run_file hands over the whole buffer, so more than one statement is not
  -- something a single trailing cap can bound
  local tail = nil
  local at = 1
  while true do
    local s = masked:find(";", at, true)
    if not s then
      break
    end
    if d[s] == 0 then
      if masked:sub(s + 1):match("%S") then
        return nil
      end
      tail = s
      break
    end
    at = s + 1
  end

  local cut = (tail or #query + 1) - 1
  return query:sub(1, cut) .. "\n" .. clause:format(rows) .. query:sub(cut + 1)
end

local connection_execute = Handler.connection_execute

Handler.connection_execute = function(self, id, query)
  return connection_execute(self, id, M.apply(id, query) or query)
end

-- the host reads DBEE_MAX_ROWS once at spawn, so this only moves the pushdown
-- until nvim restarts. lowering it still bounds the query; raising it past the
-- host cap does nothing.
vim.api.nvim_create_user_command("DbeeLimit", function(opts)
  local arg = vim.trim(opts.args)
  local report = function()
    local rows = host.config.rows
    vim.notify(("dbee: pushdown %s, host cap %s until restart"):format(
      rows > 0 and rows or "off",
      tonumber(vim.env.DBEE_MAX_ROWS) or "off"
    ))
  end

  if arg == "" then
    return report()
  end
  if arg == "off" or arg == "0" then
    host.config.rows = 0
    return report()
  end
  local n = tonumber(arg)
  if not n or n < 0 then
    return vim.notify("dbee: DbeeLimit takes a row count or `off`", vim.log.levels.ERROR)
  end
  host.config.rows = math.floor(n)
  report()
end, { nargs = "?", desc = "Show or set the dbee row cap" })

return M
