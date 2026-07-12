vim.pack.add({
  { src = 'https://github.com/mrcjkb/haskell-tools.nvim' },
  { src = 'https://github.com/neovimhaskell/haskell-vim' },
})

vim.lsp.config("haskell-tools.nvim", {
  on_init = function(client)
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("haskell-tools-hls-clean-exit-" .. client.id, { clear = true }),
      callback = function()
        client:stop(false)
      end,
    })
  end,
})
