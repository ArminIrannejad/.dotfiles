vim.pack.add({
  { src = 'https://github.com/nvim-lua/plenary.nvim', name = 'plenary.nvim' },

  { src = 'https://github.com/NeogitOrg/neogit' },
  { src = 'https://github.com/sindrets/diffview.nvim' },
  { src = 'https://github.com/lewis6991/gitsigns.nvim' },
  { src = 'https://github.com/ThePrimeagen/git-worktree.nvim' },
})

vim.keymap.set("n", "<leader>gg", "<cmd>Neogit<cr>", { desc = "Show Neogit UI" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "DiffviewFiles", "DiffviewFilePanel", "DiffviewDiff" },
  callback = function(event)
    vim.keymap.set(
      "n",
      "q",
      "<cmd>DiffviewClose<CR>",
      { buffer = event.buf, silent = true, desc = "Close Diffview" }
    )
  end,
})

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

local gs = require("gitsigns")

vim.keymap.set("n", "<leader>gts", gs.toggle_signs, { desc = "Toggle git signs" })
vim.keymap.set("n", "<leader>gtb", gs.toggle_current_line_blame, { desc = "Toggle inline blame" })
vim.keymap.set("n", "<leader>gB", function() gs.blame_line({ full = true }) end, { desc = "Blame line (full)" })

vim.keymap.set("n", "]h", gs.next_hunk, { desc = "Next git hunk" })
vim.keymap.set("n", "[h", gs.prev_hunk, { desc = "Prev git hunk" })
vim.keymap.set("n", "<leader>ghs", gs.stage_hunk, { desc = "Stage hunk" })
vim.keymap.set("n", "<leader>ghr", gs.reset_hunk, { desc = "Reset hunk" })
vim.keymap.set("n", "<leader>ghp", gs.preview_hunk, { desc = "Preview hunk" })

vim.keymap.set("n", "<leader>gdd", function()
  local file = vim.fn.fnameescape(vim.fn.expand("%"))
  vim.cmd("DiffviewOpen -- " .. file)
end, { desc = "Diff vs index" })

vim.keymap.set("n", "<leader>gdD", function()
  local file = vim.fn.fnameescape(vim.fn.expand("%"))
  vim.cmd("DiffviewOpen HEAD -- " .. file)
end, { desc = "Diff vs HEAD" })

vim.keymap.set("n", "<leader>gdc", function()
  local file = vim.fn.fnameescape(vim.fn.expand("%"))

  Snacks.picker.git_log({
    title = "Diff current file vs commit",
    layout = "vertical",
    confirm = function(picker, item)
      picker:close()
      local sha = item.commit or item.hash or item.text:match("^(%S+)")
      if not sha then
        vim.notify("Could not read commit SHA", vim.log.levels.WARN)
        return
      end
      vim.cmd("DiffviewOpen " .. sha .. " -- " .. file)
    end,
  })
end, { desc = "Diff vs chosen commit" })
require("git-worktree").setup({
  change_directory_command = "cd",
  update_on_change = true,
  update_on_change_command = "e .",
  clearjumps_on_change = true,
  autopush = false,
})

local Worktree = require("git-worktree")

Worktree.on_tree_change(function(op, metadata)
  if op == Worktree.Operations.Switch then
    vim.notify(("Worktree: %s"):format(metadata.path))
  end
end)

vim.keymap.set("n", "<leader>gw", function()
  local lines = vim.fn.systemlist("git worktree list")

  if vim.v.shell_error ~= 0 or vim.tbl_isempty(lines) then
    vim.notify("No worktrees found", vim.log.levels.WARN)
    return
  end

  vim.ui.select(lines, {
    prompt = "Worktrees",
  }, function(choice)
    if not choice then
      return
    end

    local path = choice:match("^(%S+)")
    if path then
      Worktree.switch_worktree(path)
    end
  end)
end, { desc = "Worktrees" })

vim.keymap.set("n", "<leader>gW", function()
  vim.ui.input({
    prompt = "Worktree path: ",
  }, function(path)
    if not path or path == "" then
      return
    end

    vim.ui.input({
      prompt = "Branch name: ",
    }, function(branch)
      if not branch or branch == "" then
        return
      end

      Worktree.create_worktree(path, branch)
    end)
  end)
end, { desc = "Create worktree" })
