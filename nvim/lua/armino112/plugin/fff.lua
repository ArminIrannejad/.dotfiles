vim.pack.add({ 'https://github.com/dmtrKovalenko/fff.nvim' })

vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == 'fff.nvim' and (kind == 'install' or kind == 'update') then
      if not ev.data.active then vim.cmd.packadd('fff.nvim') end
      require('fff.download').download_or_build_binary()
    end
  end,
})

vim.g.fff = {
  lazy_sync = true,
  debug = { enabled = true, show_scores = true },
}

vim.keymap.set('n', '<leader>ff', function() require('fff').find_files() end)
vim.keymap.set('n', '<leader>fg', function() require('fff').live_grep() end)
vim.keymap.set('n', '<leader>fc', function()
  local ok, oil = pcall(require, 'oil')
  local dir = ok and oil.get_current_dir() or nil

  require('fff').find_files_in_dir(dir or vim.fn.expand('%:p:h'))
end, { desc = 'Find files in current directory' })

vim.keymap.set('n', '<leader>en', function()
  require('fff').find_files_in_dir(vim.fn.stdpath('config'))
end, { desc = 'Find Neovim config files' })


-- require('fff').find_files()                        -- find files in current repo
-- require('fff').live_grep()                         -- live content grep
-- require('fff').scan_files()                        -- force rescan
-- require('fff').refresh_git_status()                -- refresh git status
-- require('fff').find_files_in_dir(path)             -- find in a specific dir
-- require('fff').change_indexing_directory(new_path) -- change root
--
-- -- Programmatic search (no UI). Useful for plugin integrations.
-- require('fff').file_search(query, opts)            -- fuzzy search files / dirs / mixed
-- require('fff').content_search(query, opts)         -- programmatic grep
