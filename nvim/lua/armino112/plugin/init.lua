local plugins = {
  "abolish",
  "colors",
  "compile",
  "csv",
  "dap",
  "dbee",
  "dial",
  "fff",
  "git",
  "harpoon",
  "haskell",
  "lsp",
  "lualine",
  "mini",
  "multicursor",
  "oil",
  "org",
  "showkeys",
  "snacks",
  "treesitter",
  "trouble",
  "vimbegood",
}

for _, name in ipairs(plugins) do
  require("armino112.plugin." .. name)
end
