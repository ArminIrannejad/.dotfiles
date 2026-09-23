vim.pack.add({
  { src = "https://github.com/jsborjesson/vim-uppercase-sql" },
  { src = "https://github.com/Saghen/blink.compat",          version = vim.version.range("2.*") },
})

vim.pack.add({
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/kndndrj/nvim-dbee",            version = "master" },
  { src = "https://github.com/MattiasMTS/cmp-dbee",          version = "ms/v2" },
}, { load = function() end })

require("blink.compat").setup({})

local commands = {
  "Dbee",
  "DbeeCatalog",
  "DbeeCatalogRefresh",
  "DbeeCmpRefresh",
  "DbeeDoc",
  "DbeeGate",
  "DbeeHostBuild",
  "DbeeLimit",
  "DbeeMem",
  "DbeeStart",
  "DbeeSweep",
}

local function load()
  local setup = "armino112.plugin.dbee.setup"
  if not package.loaded[setup] then
    for _, name in ipairs(commands) do
      pcall(vim.api.nvim_del_user_command, name)
    end
  end
  return require(setup)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "sql",
  once = true,
  callback = function(event)
    load()
    require("armino112.plugin.dbee.hover").attach(event.buf)
  end,
})

for _, name in ipairs(commands) do
  vim.api.nvim_create_user_command(name, function(opts)
    load()
    vim.cmd({ cmd = name, args = opts.fargs, bang = opts.bang })
  end, {
    nargs = "*",
    bang = true,
    complete = function(_, line)
      load()
      return vim.fn.getcompletion(line, "cmdline")
    end,
  })
end

vim.keymap.set("n", "<leader>be", function()
  load().toggle()
end, { silent = true })

vim.keymap.set("n", "<leader>bd", function()
  load().drawer_toggle()
end, { silent = true, desc = "Toggle dbee drawer" })

vim.keymap.set("n", "<leader>bl", function()
  load().log_toggle()
end, { silent = true, desc = "Toggle dbee call log" })
