-- duckdb sql completion. the pieces load on first use; this only sets up the
-- commands. the source itself is wired into blink.cmp in plugin/lsp.lua.

local function config()
  return require("armino112.plugin.duckdb.config")
end

vim.api.nvim_create_user_command("DuckdbDatabase", function(opts)
  if opts.args == "" then
    local target = config().target(0)
    vim.notify(target and ("duckdb: " .. (target.database or ":memory:")) or "duckdb: not enabled for this buffer")
    return
  end
  if opts.bang then
    vim.g.duckdb_database = opts.args
  else
    vim.b.duckdb_database = opts.args
  end
  require("armino112.plugin.duckdb.client").clear()
end, {
  nargs = "?",
  bang = true,
  complete = "file",
  desc = "Complete this buffer against a duckdb database (! for every buffer, :memory: for a scratch one)",
})

vim.api.nvim_create_user_command("DuckdbRefresh", function()
  require("armino112.plugin.duckdb.client").clear()
end, { desc = "Forget cached duckdb completion results" })
