-- Headless checks for the DuckDB completion source against a real database.
--
--   nvim --headless -u NONE -l tests/duckdb_source.lua
--
-- Needs the duckdb CLI on PATH. "|" marks the cursor in every sample.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = root .. "/roles/neovim/files/lua/?.lua;" .. root .. "/roles/neovim/files/lua/?/init.lua;" .. package.path

if vim.fn.executable("duckdb") ~= 1 then
  print("SKIP  duckdb is not installed")
  os.exit(0)
end

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local db = dir .. "/test.duckdb"
vim.fn.system({ "duckdb", db }, [[
CREATE TABLE customers(customer_id INT, full_name VARCHAR);
CREATE TABLE orders(order_id INT, customer_id INT, total DOUBLE);
CREATE SCHEMA sales;
CREATE TABLE sales.invoices(invoice_id INT, amount DOUBLE);
CREATE VIEW big_orders AS SELECT * FROM orders WHERE total > 100;
]])
vim.fn.writefile({ "id,label", "1,a" }, dir .. "/data.csv")

local Source = require("armino112.plugin.duckdb.source")
local failures = 0

local function complete(sample, setup)
  local lines = vim.split(sample, "\n", { plain = true })
  local row, col
  for index, line in ipairs(lines) do
    local at = line:find("|", 1, true)
    if at then
      row, col = index, at - 1
      lines[index] = line:gsub("|", "", 1)
    end
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "sql"
  vim.b[bufnr].duckdb_database = db
  vim.api.nvim_set_current_buf(bufnr)
  if setup then
    setup(bufnr)
  end

  local response
  Source.new():get_completions({ bufnr = bufnr, cursor = { row, col } }, function(result)
    response = result or { items = {} }
  end)
  vim.wait(5000, function()
    return response ~= nil
  end, 10)
  return response and response.items or {}
end

local function labels(items)
  return vim.tbl_map(function(item)
    return item.label
  end, items)
end

local function has(items, label)
  return vim.tbl_contains(labels(items), label)
end

local function check(name, ok, detail)
  if ok then
    print("OK    " .. name)
  else
    failures = failures + 1
    print(("FAIL  %s%s"):format(name, detail and (": " .. detail) or ""))
  end
end

local function top(items, n)
  return table.concat(vim.list_slice(labels(items), 1, n or 8), ",")
end

local items = complete("SELECT * FROM |")
check("tables after FROM", has(items, "customers") and has(items, "orders") and has(items, "big_orders"), top(items))
check("schemas after FROM", has(items, "sales"))
check("no columns after FROM", not has(items, "total"), top(items))

items = complete("SELECT * FROM customers WHERE |")
check("scoped columns", has(items, "full_name") and has(items, "customer_id"), top(items))
check("other tables' columns left out", not has(items, "total"), top(items))
check("functions kept", has(items, "abs") or has(items, "count"), top(items))

items = complete("SELECT | FROM customers c JOIN orders o ON o.customer_id = c.customer_id")
check("columns before FROM", has(items, "full_name") and has(items, "total"), top(items))
check("aliases offered", has(items, "c") and has(items, "o"), top(items))

items = complete("SELECT * FROM customers c JOIN orders o ON o.|")
check("alias columns", has(items, "order_id") and has(items, "total") and not has(items, "full_name"), top(items))

items = complete("SELECT * FROM sales.|")
check("schema tables", has(items, "invoices") and not has(items, "orders"), top(items))

items = complete("SELECT * FROM main.orders WHERE orders.|")
check("table name qualifies columns", has(items, "total"), top(items))

items = complete("SELECT * FROM test.sales.invoices WHERE |")
check("three part names", has(items, "amount"), top(items))

items = complete("SELECT * FROM test.|")
check("database qualifies schemas", has(items, "sales") and has(items, "orders"), top(items))

items = complete("WITH recent AS (SELECT customer_id AS cid, 1 AS flag FROM orders) SELECT | FROM recent")
check("cte columns", has(items, "cid") and has(items, "flag") and not has(items, "total"), top(items))

items = complete("SELECT * FROM (SELECT customer_id AS who FROM orders) s WHERE s.|")
check("subquery columns", has(items, "who"), top(items))

items = complete("SELECT * FROM read_csv('" .. dir .. "/data.csv') d WHERE |")
check("file function columns", has(items, "label"), top(items))

items = complete("SELECT * FROM '" .. dir .. "/da|")
check("file paths", has(items, "data.csv'"), top(items))

items = complete("SELECT * FROM customers LEFT |")
check("keywords after a relation", has(items, "join") or has(items, "outer"), top(items))

items = complete("SELECT 1;\nSELECT * FROM orders WHERE tot|")
check("later statement only", has(items, "total") and not has(items, "full_name"), top(items))
local edit = vim.iter(items):find(function(i) return i.label == "total" end)
check("edit replaces the typed word", edit and edit.textEdit.range.start.character == 27 and edit.textEdit.range["end"].character == 30, vim.inspect(edit and edit.textEdit))

items = complete("-- SELECT |")
check("nothing in comments", #items == 0)

items = complete("-- duckdb: " .. db .. "\nSELECT * FROM |", function(bufnr)
  vim.b[bufnr].duckdb_database = nil
end)
check("modeline picks the database", has(items, "customers"), top(items))

items = complete("SELECT * FROM |", function(bufnr)
  vim.b[bufnr].duckdb_database = ":memory:"
  vim.b[bufnr].duckdb_init = { "CREATE TABLE scratch(x INT)" }
end)
check("init sql runs first", has(items, "scratch") and not has(items, "customers"), top(items))

vim.fn.delete(dir, "rf")
print(failures == 0 and "PASS" or ("FAIL: " .. failures))
os.exit(failures == 0 and 0 or 1)
