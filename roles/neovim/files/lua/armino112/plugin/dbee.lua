vim.pack.add({
  { src = "https://github.com/jsborjesson/vim-uppercase-sql" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/kndndrj/nvim-dbee",            version = "master" },
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
-- same chrome on every tile
local window_options = {
  number = false,
  relativenumber = false,
  signcolumn = "no",
  foldcolumn = "0",
  statuscolumn = "",
  cursorline = true,
  list = false,
  wrap = false,
}

dbee.setup({
  sources = {
    require("dbee.sources").EnvSource:new("DBEE_CONNECTIONS"),
    require("dbee.sources").FileSource:new(vim.fn.stdpath("state") .. "/dbee/persistence.json"),
  },

  window_layout = require("dbee.layouts").Default:new({
    drawer_width = 32,
    result_height = 16,
    call_log_height = 12,
  }),

  drawer = {
    disable_help = true,
    window_options = window_options,
  },

  editor = {
    window_options = window_options,
    mappings = {
      { key = "BB",   mode = "v", action = "run_selection" },
      { key = "BB",   mode = "n", action = "run_file" },
      { key = "<CR>", mode = "n", action = "run_under_cursor" },
    },
  },

  result = {
    page_size = 50,
    focus_result = false,
    window_options = window_options,
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
  },

  call_log = {
    window_options = window_options,
  },
})

pcall(function()
  require("cmp-dbee").setup({})
end)

-- upstream drops the structure cache every 10s, so a keystroke mid-typing pays
-- for a full information_schema scan. the cache is already busted on connection
-- and database change, so only DDL made elsewhere goes stale.
pcall(function()
  local db = require("cmp-dbee.database")
  db.cache_expiry_s = 30 * 60

  vim.api.nvim_create_user_command("DbeeCmpRefresh", function()
    local conn = db.get_current_connection()
    if not conn then
      return
    end
    db.cache[conn.id] = nil
    db.column_cache[conn.id] = nil
  end, { desc = "Drop cached dbee completion metadata" })
end)

require("armino112.dbee_cmp")

vim.keymap.set("n", "<leader>be", function()
  dbee.toggle()
end, { silent = true })
