return {
  {
    "hat0uma/csvview.nvim",
    cmd = "CsvViewToggle",
    config = function()
      require("csvview").setup()
    end,
  },

  {
    "cameron-wags/rainbow_csv.nvim",
    ft = {
      "csv",
      "tsv",
    },
    module = {
      "rainbow_csv",
      "rainbow_csv.fns",
    },
    opts = {},
  },
}
