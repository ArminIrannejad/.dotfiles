local dir = vim.fs.joinpath(vim.fn.stdpath("config"), "lua/armino112/plugin")
local plugins = {}

for name, kind in vim.fs.dir(dir) do
  if kind == "file" and name:match("%.lua$") and name ~= "init.lua" then
    table.insert(plugins, name:sub(1, -5))
  elseif kind == "directory" and vim.uv.fs_stat(vim.fs.joinpath(dir, name, "init.lua")) then
    table.insert(plugins, name)
  end
end

table.sort(plugins)

for _, name in ipairs(plugins) do
  require("armino112.plugin." .. name)
end

vim.api.nvim_create_user_command("PackClean", function(opts)
  local unused = vim.iter(vim.pack.get(nil, { info = false }))
    :filter(function(p) return not p.active end)
    :map(function(p) return p.spec.name end)
    :totable()

  if #unused == 0 then
    vim.notify("No unused plugins")
    return
  end

  local msg = "Delete unused plugins?\n\n" .. table.concat(unused, "\n")
  if opts.bang or vim.fn.confirm(msg, "&Yes\n&No", 2) == 1 then
    vim.pack.del(unused)
  end
end, { bang = true, desc = "Delete plugins no longer added by vim.pack.add" })
