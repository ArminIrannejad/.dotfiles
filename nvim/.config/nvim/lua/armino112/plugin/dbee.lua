return {
  {
    "jsborjesson/vim-uppercase-sql",
    enabled = true,
    ft = { "sql", "psql", "mysql" },
  },
  {
    "kndndrj/nvim-dbee",
    branch="master",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    build = function()
      -- Install tries to automatically detect the install method.
      -- if it fails, try calling it with one of these parameters:
      --    "curl", "wget", "bitsadmin", "go"
      require("dbee").install("go")
    end,

    config = function()
      local dbee = require("dbee")
      dbee.setup({
        -- connections
        sources = {
          require("dbee.sources").EnvSource:new("DBEE_CONNECTIONS"),
          require("dbee.sources").FileSource:new(vim.fn.stdpath("state") .. "/dbee/persistence.json"),
        },
        editor = {
          mappings = {
            -- run what's currently selected on the active connection
            { key = "BB",   mode = "v", action = "run_selection" },
            -- run the whole file on the active connection
            { key = "BB",   mode = "n", action = "run_file" },
            -- run what's under the cursor to the next newline
            { key = "<CR>", mode = "n", action = "run_under_cursor" },
          },
        },

        result = {
          page_size = 50,
          focus_result = false,
        },
        -- mappings
        mappings = {
          -- next/previous page
          { key = "L",          mode = "",  action = "page_next" },
          { key = "H",          mode = "",  action = "page_prev" },
          { key = "A",          mode = "",  action = "page_first" },
          { key = "S",          mode = "",  action = "page_last" },
          -- yank rows as csv/json
          { key = "<leader>yj", mode = "n", action = "yank_current_json" },
          { key = "<leader>yj", mode = "v", action = "yank_selection_json" },
          { key = "<leader>YJ", mode = "",  action = "yank_all_json" },
          { key = "<leader>yc", mode = "n", action = "yank_current_csv" },
          { key = "<leader>yc", mode = "v", action = "yank_selection_csv" },
          { key = "<leader>YC", mode = "",  action = "yank_all_csv" },

          -- cancel current call execution
          { key = "<C-c>",      mode = "",  action = "cancel_call" },
        },
      })
    end,
    keys = {
      {
        "<leader>be",
        function()
          require("dbee").toggle()
        end,
        mode = "n",
        silent = true,
      },
    },
  },
}
