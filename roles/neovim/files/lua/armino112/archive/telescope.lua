vim.pack.add({
  { src = 'https://github.com/nvim-lua/plenary.nvim', name = 'plenary.nvim' },
  { src = 'https://github.com/nvim-telescope/telescope.nvim'},
  { src = 'https://github.com/nvim-telescope/telescope-fzf-native.nvim', name = 'telescope-fzf-native.nvim' },
})

require("telescope").setup({
  pickers = {
    find_files = {
      theme = "ivy",
    },
    colorscheme = {
      enable_preview = true,
    },
  },
  extensions = {
    fzf = {},
  },
})

pcall(function()
  require("telescope").load_extension("fzf")
end)

local builtin = require("telescope.builtin")

vim.keymap.set("n", "<leader>fh", builtin.help_tags)
vim.keymap.set("n", "<leader>th", builtin.colorscheme)

vim.keymap.set("n", "<leader>ff", function()
  builtin.find_files({
    no_ignore = true,
    hidden = false,
  })
end)

vim.keymap.set("n", "<leader>fc", function()
  local ok, oil = pcall(require, "oil")
  local dir = ok and oil.get_current_dir() or nil

  if dir then
    builtin.find_files({ cwd = dir })
  else
    builtin.find_files({
      cwd = vim.fn.expand("%:p:h"),
    })
  end
end)

vim.keymap.set("n", "<leader>fa", function()
  builtin.find_files({
    cwd = vim.fs.normalize(vim.fn.expand("~/work")),
  })
end)

vim.keymap.set("n", "<leader>fp", function()
  builtin.find_files({
    cwd = vim.fs.normalize(vim.fn.expand("~/personal")),
  })
end)

vim.keymap.set("n", "<leader>en", function()
  builtin.find_files({
    cwd = vim.fn.stdpath("config"),
  })
end)

vim.keymap.set("n", "<leader>ep", function()
  builtin.find_files({
    cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy"),
  })
end)

vim.keymap.set("n", "<leader>om", function()
  builtin.find_files({
    cwd = "~/org",
  })
end)

require("armino112.telescope.multigrep").setup()
