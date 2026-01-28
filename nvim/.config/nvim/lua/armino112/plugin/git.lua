return {
  {
    "NeogitOrg/neogit",
    lazy = true,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = "Neogit",
    keys = {
      { "<leader>gg", "<cmd>Neogit<cr>", desc = "Show Neogit UI" },
    },
  },

  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewFileHistory",
    },
    init = function()
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
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
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
    },
    keys = {
      { "<leader>gts", function() require("gitsigns").toggle_signs() end,               desc = "Toggle git signs" },
      { "<leader>gtb", function() require("gitsigns").toggle_current_line_blame() end, desc = "Toggle inline blame" },
      { "<leader>gB",  function() require("gitsigns").blame_line({ full = true }) end, desc = "Blame line (full)" },

      -- hunks
      { "]h",          function() require("gitsigns").next_hunk() end,                 desc = "Next git hunk" },
      { "[h",          function() require("gitsigns").prev_hunk() end,                 desc = "Prev git hunk" },
      { "<leader>ghs", function() require("gitsigns").stage_hunk() end,                desc = "Stage hunk" },
      { "<leader>ghr", function() require("gitsigns").reset_hunk() end,                desc = "Reset hunk" },
      { "<leader>ghp", function() require("gitsigns").preview_hunk() end,              desc = "Preview hunk" },

      -- diffview (current file)
      {
        "<leader>gdd",
        function()
          local file = vim.fn.fnameescape(vim.fn.expand("%"))
          vim.cmd("DiffviewOpen -- " .. file)
        end,
        desc = "Diff vs index",
      },
      {
        "<leader>gdD",
        function()
          local file = vim.fn.fnameescape(vim.fn.expand("%"))
          vim.cmd("DiffviewOpen HEAD -- " .. file)
        end,
        desc = "Diff vs HEAD",
      },
      {
        "<leader>gdc",
        function()
          local builtin = require("telescope.builtin")
          builtin.git_commits({
            prompt_title = "Diff current file vs commit",
            attach_mappings = function(prompt_bufnr, map)
              local actions = require("telescope.actions")
              local action_state = require("telescope.actions.state")

              local function open_diffview_for_selection()
                local entry = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                local sha = entry.value
                  or entry.commit
                  or (entry.ordinal and entry.ordinal:match("^(%w+)"))

                if not sha then
                  vim.notify("Could not read commit SHA from selection", vim.log.levels.WARN)
                  return
                end

                local file = vim.fn.fnameescape(vim.fn.expand("%"))
                vim.cmd("DiffviewOpen " .. sha .. " -- " .. file)
              end

              map("i", "<CR>", open_diffview_for_selection)
              map("n", "<CR>", open_diffview_for_selection)
              return true
            end,
          })
        end,
        desc = "Diff vs chosen commit",
      },
    },
  },
}

