local plugins = {
  "abolish",
  "colors",
  "ui",
  "compile",
  "csv",
  "dap",
  "dbee",
  "dial",
  "fff",
  "git",
  "harpoon",
  "haskell",
  "ipynb",
  "lsp",
  "lualine",
  "mini",
  "multicursor",
  "oil",
  "org",
  "quicker",
  "snacks",
  "tarminal",
  "treesitter",
  "trouble",
  "vimbegood",
}

for _, name in ipairs(plugins) do
  require("armino112.plugin." .. name)
end
