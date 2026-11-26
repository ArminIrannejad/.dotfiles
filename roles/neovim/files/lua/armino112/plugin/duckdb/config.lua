-- which buffers are duckdb, and what database they talk to.
--
-- sql buffers are shared with dbee and whatever else, so completion has to be
-- opted into. in order of precedence:
--
--   vim.b.duckdb_database   :DuckdbDatabase path
--   -- duckdb: path/to.db   modeline in the first lines of the file
--   vim.g.duckdb_database   :DuckdbDatabase! path
--
-- an empty value or ":memory:" is a scratch database; "-- duckdb" alone works
-- too. vim.b.duckdb_init / vim.g.duckdb_init is sql (a string or a list) to
-- run before completing, usually ATTACH statements.

local M = {}

local MODELINE_LINES = 20

--- @class armino112.duckdb.Target
--- @field database? string nil is in-memory
--- @field init string[]

local function modeline(bufnr)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, MODELINE_LINES, false)) do
    local rest = line:match("^%s*%-%-%s*duckdb%s*:?%s*(.-)%s*$")
    if rest and not line:match("^%s*%-%-%s*duckdb[%w_%-]") then
      return rest
    end
  end
end

local function normalize(value)
  if value == nil or value == "" or value == ":memory:" then
    return nil
  end
  return vim.fn.expand(value)
end

local function init_statements(bufnr)
  local init = vim.b[bufnr].duckdb_init or vim.g.duckdb_init
  if type(init) == "string" then
    init = { init }
  end
  return init or {}
end

--- @param bufnr? integer
--- @return armino112.duckdb.Target|nil nil when the buffer is not a duckdb one
function M.target(bufnr)
  bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr

  local database = vim.b[bufnr].duckdb_database
  if database == nil then
    database = modeline(bufnr)
  end
  if database == nil then
    database = vim.g.duckdb_database
  end
  if database == nil then
    return nil
  end

  return { database = normalize(database), init = init_statements(bufnr) }
end

--- other sql sources step aside in buffers this one owns
function M.active(bufnr)
  return vim.bo[bufnr or 0].filetype == "sql" and M.target(bufnr) ~= nil
end

return M
