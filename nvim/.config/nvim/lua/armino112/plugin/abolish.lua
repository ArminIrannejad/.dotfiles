local loaded = false

local function load_abolish()
  if loaded then
    return
  end
  loaded = true
  vim.pack.add({
    'https://github.com/tpope/vim-abolish',
  })
end

for _, cmd in ipairs({ 'Abolish', 'Subvert', 'S' }) do
  vim.api.nvim_create_user_command(cmd, function(ctx)
    load_abolish()

    local args = table.concat(ctx.fargs, ' ')
    local bang = ctx.bang and '!' or ''
    local cmdline = cmd .. bang
    if args ~= '' then
      cmdline = cmdline .. ' ' .. args
    end

    vim.cmd(cmdline)
  end, {
    nargs = '*',
    bang = true,
    complete = 'file',
  })
end

for _, lhs in ipairs({ 'crs', 'crm', 'crc', 'cru', 'crk' }) do
  vim.keymap.set('n', lhs, function()
    load_abolish()
    return lhs
  end, { remap = true, expr = true })
end
