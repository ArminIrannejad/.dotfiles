vim.pack.add({
  { src = "https://github.com/jsborjesson/vim-uppercase-sql" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/kndndrj/nvim-dbee", version = "master" },
})

local ok, dbee = pcall(require, "dbee")
if not ok then
  return
end

dbee.setup({
  sources = {
    require("dbee.sources").EnvSource:new("DBEE_CONNECTIONS"),
    require("dbee.sources").FileSource:new(vim.fn.stdpath("state") .. "/dbee/persistence.json"),
  },
  editor = {
    mappings = {
      { key = "BB", mode = "v", action = "run_selection" },
      { key = "BB", mode = "n", action = "run_file" },
      { key = "<CR>", mode = "n", action = "run_under_cursor" },
    },
  },
  result = {
    page_size = 50,
    focus_result = false,
  },
  mappings = {
    { key = "L", mode = "", action = "page_next" },
    { key = "H", mode = "", action = "page_prev" },
    { key = "A", mode = "", action = "page_first" },
    { key = "S", mode = "", action = "page_last" },

    { key = "<leader>yj", mode = "n", action = "yank_current_json" },
    { key = "<leader>yj", mode = "v", action = "yank_selection_json" },
    { key = "<leader>YJ", mode = "", action = "yank_all_json" },

    { key = "<leader>yc", mode = "n", action = "yank_current_csv" },
    { key = "<leader>yc", mode = "v", action = "yank_selection_csv" },
    { key = "<leader>YC", mode = "", action = "yank_all_csv" },

    { key = "<C-c>", mode = "", action = "cancel_call" },
  },
})

vim.keymap.set("n", "<leader>be", function()
  dbee.toggle()
end, { silent = true })
