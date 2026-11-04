vim.pack.add({
  { src = 'https://github.com/nvim-lua/plenary.nvim',         name = 'plenary.nvim' },
  { src = 'https://github.com/echasnovski/mini.nvim' },

  { src = 'https://github.com/NeogitOrg/neogit' },
  { src = 'https://github.com/esmuellert/codediff.nvim' },
  { src = 'https://github.com/lewis6991/gitsigns.nvim' },
})

vim.keymap.set("n", "<leader>gg", "<cmd>Neogit<cr>", { desc = "Show Neogit UI" })

require("gitsigns").setup({
  current_line_blame = false,
  current_line_blame_opts = {
    virt_text = true,
    virt_text_pos = "eol",
    delay = 200,
    ignore_whitespace = false,
  },
  current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> • <summary>",

  signcolumn = true,
  attach_to_untracked = true,
  watch_gitdir = { interval = 1000, follow_files = true },
  update_debounce = 100,
  max_file_length = 40000,
})

require("mini.diff").setup({
  view = {
    style = "sign",
    signs = { add = "", change = "", delete = "" },
  },
})

local gs = require("gitsigns")

vim.keymap.set("n", "<leader>gts", gs.toggle_signs, { desc = "Toggle git signs" })
vim.keymap.set("n", "<leader>gtb", gs.toggle_current_line_blame, { desc = "Toggle inline blame" })
vim.keymap.set("n", "<leader>gB", function() gs.blame_line({ full = true }) end, { desc = "Blame line (full)" })

local function hunk(action)
  return function()
    local line = vim.fn.line(".")
    MiniDiff.do_hunks(0, action, { line_start = line, line_end = line })
  end
end

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
vim.keymap.set("n", "<leader>gdh", "<cmd>CodeDiff history %<cr>", { desc = "File history" })
vim.keymap.set("n", "<leader>gdH", "<cmd>CodeDiff history<cr>", { desc = "Repo history" })

vim.keymap.set({ "n", "x" }, "<leader>gy", function()
  Snacks.gitbrowse({
    what = "permalink",
    notify = false,
    open = function(url)
      vim.fn.setreg("+", url)
      vim.notify(url)
    end,
  })
end, { desc = "Yank git link" })

vim.keymap.set({ "n", "x" }, "<leader>gY", function()
  Snacks.gitbrowse({ what = "permalink" })
end, { desc = "Open git link" })

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
