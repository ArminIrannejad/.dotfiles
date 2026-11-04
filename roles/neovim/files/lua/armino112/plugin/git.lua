vim.pack.add({
  { src = 'https://github.com/nvim-lua/plenary.nvim',         name = 'plenary.nvim' },
  { src = 'https://github.com/echasnovski/mini.nvim' },

  { src = 'https://github.com/NeogitOrg/neogit' },
  { src = 'https://github.com/esmuellert/codediff.nvim' },
})

vim.keymap.set("n", "<leader>gg", "<cmd>Neogit<cr>", { desc = "Show Neogit UI" })

require("mini.git").setup({})
require("mini.diff").setup({
  view = {
    style = "sign",
    signs = { add = "┃", change = "┃", delete = "_" },
  },
})

local function hunk(action)
  return function()
    local line = vim.fn.line(".")
    MiniDiff.do_hunks(0, action, { line_start = line, line_end = line })
  end
end

vim.keymap.set("n", "<leader>gts", function() MiniDiff.toggle(0) end, { desc = "Toggle git signs" })
vim.keymap.set("n", "<leader>gtb", "<cmd>vertical Git blame -- %<cr>", { desc = "Blame file" })
vim.keymap.set("n", "<leader>gB", MiniGit.show_at_cursor, { desc = "Blame line (full)" })

vim.keymap.set("n", "<leader>ghs", hunk("apply"), { desc = "Stage hunk" })
vim.keymap.set("n", "<leader>ghr", hunk("reset"), { desc = "Reset hunk" })
vim.keymap.set("n", "<leader>ghp", function() MiniDiff.toggle_overlay(0) end, { desc = "Toggle diff overlay" })

local function relpath()
  local file = vim.api.nvim_buf_get_name(0)
  local root = vim.fs.root(0, ".git")
  return root and vim.fs.relpath(root, file) or file
end

vim.keymap.set("n", "<leader>gdd", function()
  vim.cmd("CodeDiff -- " .. vim.fn.fnameescape(relpath()))
end, { desc = "Diff vs index" })

vim.keymap.set("n", "<leader>gdD", "<cmd>CodeDiff file HEAD<cr>", { desc = "Diff vs HEAD" })

vim.keymap.set("n", "<leader>gdm", "<cmd>CodeDiff main...HEAD<cr>", { desc = "Main vs HEAD" })

local function pick_commit(title, open)
  Snacks.picker.git_log({
    title = title,
    layout = "vertical",
    confirm = function(picker, item)
      picker:close()
      local sha = item.commit or item.hash or item.text:match("^(%S+)")
      if not sha then
        vim.notify("Could not read commit SHA", vim.log.levels.WARN)
        return
      end
      open(sha)
    end,
  })
end

vim.keymap.set("n", "<leader>gdc", function()
  pick_commit("Diff current file vs commit", function(sha) vim.cmd("CodeDiff file " .. sha) end)
end, { desc = "Diff vs chosen commit" })

vim.keymap.set("n", "<leader>gdC", function()
  pick_commit("Diff repo vs commit", function(sha) vim.cmd("CodeDiff " .. sha) end)
end, { desc = "Diff repo vs chosen commit" })
