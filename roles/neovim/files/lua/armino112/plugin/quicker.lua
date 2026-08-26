vim.pack.add({
  { src = "https://github.com/stevearc/quicker.nvim" },
})

require("quicker").setup({
  keys = {
    {
      ">",
      function()
        require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
      end,
      desc = "Expand quickfix context",
    },
    {
      "<",
      function()
        require("quicker").collapse()
      end,
      desc = "Collapse quickfix context",
    },
  },

  edit = {
    enabled = true,
    autosave = "unmodified",
  },

  highlight = {
    treesitter = true,
    lsp = true,
    load_buffers = false,
  },
})

vim.keymap.set("n", "<leader>q", function()
  require("quicker").toggle()
end, { desc = "Toggle quickfix" })

vim.keymap.set("n", "<leader>l", function()
  require("quicker").toggle({ loclist = true })
end, { desc = "Toggle loclist" })

-- inccommand is global, so drop the preview split only while in the quickfix buffer
local group = vim.api.nvim_create_augroup("QuickerInccommand", { clear = true })
local saved

local function enter()
  if saved == nil then
    saved = vim.o.inccommand
  end
  vim.o.inccommand = "nosplit"
end

local function leave()
  if saved ~= nil then
    vim.o.inccommand = saved
    saved = nil
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "qf",
  callback = function(args)
    enter()
    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
      group = group,
      buffer = args.buf,
      callback = enter,
    })
    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
      group = group,
      buffer = args.buf,
      callback = leave,
    })
  end,
})
