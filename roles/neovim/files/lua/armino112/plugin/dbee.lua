vim.pack.add({
  { src = "https://github.com/jsborjesson/vim-uppercase-sql" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/kndndrj/nvim-dbee",            version = "master" },
  -- cmp-dbee is an nvim-cmp source; blink.compat bridges it (and stubs `cmp`)
  { src = "https://github.com/Saghen/blink.compat",          version = vim.version.range("2.*") },
  { src = "https://github.com/MattiasMTS/cmp-dbee",          version = "ms/v2" },
})

require("blink.compat").setup({})

local ok, dbee = pcall(require, "dbee")
if not ok then
  return
end

local build = function()
  local binary = vim.fn.expand("$HOME") .. "/.local/share/nvim/dbee/bin/dbee"
  if vim.fn.filereadable(binary) == 0 then
    require("dbee").install("go")
  end
end
dbee.setup({
  sources = {
    require("dbee.sources").EnvSource:new("DBEE_CONNECTIONS"),
    require("dbee.sources").FileSource:new(vim.fn.stdpath("state") .. "/dbee/persistence.json"),
  },
  editor = {
    mappings = {
      { key = "BB",   mode = "v", action = "run_selection" },
      { key = "BB",   mode = "n", action = "run_file" },
      { key = "<CR>", mode = "n", action = "run_under_cursor" },
    },
  },
  result = {
    page_size = 50,
    focus_result = false,
  },
  mappings = {
    { key = "L",          mode = "",  action = "page_next" },
    { key = "H",          mode = "",  action = "page_prev" },
    { key = "A",          mode = "",  action = "page_first" },
    { key = "S",          mode = "",  action = "page_last" },

    { key = "<leader>yj", mode = "n", action = "yank_current_json" },
    { key = "<leader>yj", mode = "v", action = "yank_selection_json" },
    { key = "<leader>YJ", mode = "",  action = "yank_all_json" },

    { key = "<leader>yc", mode = "n", action = "yank_current_csv" },
    { key = "<leader>yc", mode = "v", action = "yank_selection_csv" },
    { key = "<leader>YC", mode = "",  action = "yank_all_csv" },

    { key = "<C-c>",      mode = "",  action = "cancel_call" },
  },
})

pcall(function()
  require("cmp-dbee").setup({})
end)

-- cmp-dbee assumes `schema.table`, Databricks is `catalog.schema.table`.
-- Upstream anchors the schema match on whitespace/paren, so a dotted prefix
-- never matches and it falls back to listing every table in the catalog.
pcall(function()
  local utils = require("cmp-dbee.source.utils")

  -- last identifier before the trailing dot, dotted prefix and all
  function utils:captured_schema(line)
    local before = line or self:get_cursor_before_line()
    local qualified = before:match("[%s%(,]([%w_%.]+)%.$") or before:match("^([%w_%.]+)%.$")
    if not qualified then
      return nil
    end
    local segments = vim.split(qualified, ".", { plain = true })
    return segments[#segments]
  end
end)

-- dbee's databricks structure is only schema -> table for the current catalog,
-- so an unknown name is the catalog: answer it with the schema list.
pcall(function()
  local database = require("cmp-dbee.database")

  function database.get_models(name, callback)
    database.get_db_structure(function(structure)
      structure = structure or {}
      for _, schema in ipairs(structure) do
        if schema.name == name then
          callback(schema.children or {})
          return
        end
      end
      callback(structure)
    end)
  end
end)

vim.keymap.set("n", "<leader>be", function()
  dbee.toggle()
end, { silent = true })
