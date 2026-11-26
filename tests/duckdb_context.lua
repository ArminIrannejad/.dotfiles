-- Headless checks for the DuckDB completion context reader.
--
--   nvim -l tests/duckdb_context.lua
--
-- "|" marks the cursor in every sample.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = root .. "/roles/neovim/files/lua/?.lua;" .. root .. "/roles/neovim/files/lua/?/init.lua;" .. package.path

local context = require("armino112.plugin.duckdb.context")

local failures = 0

local function analyze(sample)
  local cur = sample:find("|", 1, true) - 1
  local text = sample:gsub("|", "", 1)
  return context.analyze(text, cur)
end

local function check(label, ok, detail)
  if not ok then
    failures = failures + 1
    print(("FAIL  %s%s"):format(label, detail and (": " .. vim.inspect(detail)) or ""))
  else
    print(("OK    %s"):format(label))
  end
end

local function names(result)
  return vim.tbl_map(function(r)
    return (r.alias or r.name or "?") .. ":" .. r.kind
  end, result.relations)
end

local function case(sample, expect)
  local result = analyze(sample)
  for key, want in pairs(expect) do
    local got = result[key]
    if key == "relations" then
      got = names(result)
    end
    check(("%s -> %s"):format(sample, key), vim.deep_equal(got, want), got)
  end
end

case("SELECT * FROM |", { position = "table", relations = {} })
case("SELECT * FROM or|", { position = "table", prefix = "or" })
case("SELECT na| FROM t", { position = "column", prefix = "na", relations = { "t:table" } })
case("SELECT a, | FROM t", { position = "column", relations = { "t:table" } })
case("SELECT * FROM t x WHERE x.|", { position = "qualified", qualifier = { "x" }, relations = { "x:table" } })
case("SELECT * FROM a JOIN b ON a.id = b.|", { position = "qualified", qualifier = { "b" }, relations = { "a:table", "b:table" } })
case("SELECT * FROM a, b WHERE |", { position = "column", relations = { "a:table", "b:table" } })
case("SELECT * FROM a, | WHERE x", { position = "table" })
case("SELECT * FROM db.main.t1 |", { position = "other", relations = { "t1:table" } })
case("SELECT * FROM db.main.|", { position = "qualified", qualifier = { "db", "main" }, relations = {} })
case("SELECT * FROM t1 |", { position = "other" })
case("SELECT * FROM t1 AS x WHERE x.a = |", { position = "column", relations = { "x:table" } })
case("WITH c AS (SELECT 1 a) SELECT | FROM c", { position = "column", relations = { "c:cte" }, ctes = { "c" } })
case("WITH c AS (SELECT 1 a), d AS (SELECT * FROM c) SELECT * FROM d WHERE |", { relations = { "d:cte" }, ctes = { "c", "d" } })
case("SELECT * FROM (SELECT x FROM t1) s WHERE |", { position = "column", relations = { "s:subquery" } })
case("SELECT * FROM (SELECT | FROM t1) s", { position = "column", relations = { "t1:table", "s:subquery" } })
case("SELECT (SELECT | FROM inner_t) FROM outer_t", { position = "column", relations = { "inner_t:table", "outer_t:table" } })
case("SELECT 1; SELECT | FROM t2; SELECT * FROM t3", { relations = { "t2:table" } })
case("SELECT * FROM 'data.csv' d WHERE |", { relations = { "d:file" } })
case("SELECT * FROM 'data.csv.gz' WHERE |", { relations = { "data:file" } })
case("SELECT * FROM read_csv('x.csv') r WHERE r.|", { position = "qualified", relations = { "r:function" } })
case("SELECT * FROM 'dat|", { in_string = true, position = "table" })
case("SELECT * FROM t WHERE a IN (1, |", { position = "column" })
case("SELECT count(|) FROM t", { position = "column", relations = { "t:table" } })
case("SELECT * FROM t WHERE a = 'x|'", { in_string = true })
case("INSERT INTO t (|", { position = "column", relations = { "t:table" } })
case("UPDATE t SET a = 1, | WHERE x", { position = "column", relations = { "t:table" } })
case("DROP TABLE |", { position = "table" })
case("CREATE TABLE |", { position = "other" })
case("SELECT * FROM (|", { position = "other" })
case("SELECT * |", { position = "other" })
case("SELECT t1.a, t2.b FROM t1 JOIN t2 USING (|", { position = "column", relations = { "t1:table", "t2:table" } })
case('SELECT "my col|', { prefix = '"my col', position = "column" })
case('SELECT * FROM "my tab" m WHERE |', { relations = { "m:table" } })
case("|", { position = "other" })

check("comment skips", analyze("SELECT 1 -- note |").skip == true)
check("block comment skips", analyze("SELECT /* no| */ 1").skip == true)
check("after block comment completes", analyze("SELECT /* no */ |").skip == nil)
check("number skips", analyze("SELECT 12|").skip == true)

local cte = analyze("WITH c AS (SELECT 1 a) SELECT * FROM c WHERE |").relations[1]
check("cte keeps its with clause", cte.with == "WITH c AS (SELECT 1 a)", cte.with)
local sub = analyze("SELECT * FROM (SELECT x FROM t1) s WHERE |").relations[1]
check("subquery keeps its source", sub.source == "(SELECT x FROM t1)", sub.source)
check("statement stops at the cursor", analyze("SELECT 1; SELECT a| FROM t").statement == "SELECT a")

print(failures == 0 and "PASS" or ("FAIL: " .. failures))
os.exit(failures == 0 and 0 or 1)
