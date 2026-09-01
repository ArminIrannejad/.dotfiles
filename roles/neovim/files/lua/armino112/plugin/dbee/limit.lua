-- the go host drains a whole result set into memory before it draws the first
-- page, then keeps it there: handler.lookupCall is never evicted and
-- core.Result:Wipe is dead code upstream, so every call ever run stays resident
-- for the life of the host. it also gobs a second copy to /tmp/dbee-history.
-- one `SELECT * FROM delta.\`abfss://...\`` is gigabytes of rss, the next one is
-- gigabytes more, and the host gets oom-killed a handful of queries in. the
-- janitor bounds the disk after the fact; this bounds the query up front.
--
-- the result window only ever renders one page, so nothing is lost by bounding
-- the statement instead. `-- no_limit` in the query opts out, silently: the cap
-- is never announced, so a query either says no_limit or is capped.

local ok_handler, Handler = pcall(require, "dbee.handler")
if not ok_handler then
  return
end

local M = {}

M.config = {
  rows = 10000,
  marker = "no_limit",
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

local writes = { "insert", "create", "update", "delete", "merge", "replace", "alter", "drop" }

--- @return string|nil query with a row cap appended, nil to leave it alone
function M.apply(query)
  local rows = M.config.rows
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

  -- a cte can feed a write, and a cap belongs on neither half of one
  for _, word in ipairs(writes) do
    if has_top_level(masked, d, word) then
      return nil
    end
  end

  if has_top_level(masked, d, "limit") then
    return nil
  end

  -- run_file hands over the whole buffer, so more than one statement is not
  -- something a single trailing LIMIT can bound
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
  return query:sub(1, cut) .. "\nLIMIT " .. rows .. query:sub(cut + 1)
end

local connection_execute = Handler.connection_execute

Handler.connection_execute = function(self, id, query)
  return connection_execute(self, id, M.apply(query) or query)
end

vim.api.nvim_create_user_command("DbeeLimit", function(opts)
  local arg = vim.trim(opts.args)
  if arg == "" then
    return vim.notify(("dbee: row cap %s"):format(M.config.rows > 0 and M.config.rows or "off"))
  end
  if arg == "off" or arg == "0" then
    M.config.rows = 0
    return vim.notify("dbee: row cap off")
  end
  local n = tonumber(arg)
  if not n or n < 0 then
    return vim.notify("dbee: DbeeLimit takes a row count or `off`", vim.log.levels.ERROR)
  end
  M.config.rows = math.floor(n)
  vim.notify(("dbee: row cap %d"):format(M.config.rows))
end, { nargs = "?", desc = "Show or set the dbee row cap" })

return M
