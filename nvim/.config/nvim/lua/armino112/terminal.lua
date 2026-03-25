vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("custom-term-open", { clear = true }),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.scrolloff = 0
    vim.bo.filetype = "terminal"
  end,
})

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>")

vim.keymap.set("n", "<space>ts", function()
  vim.cmd.new()
  vim.cmd.wincmd("J")
  vim.api.nvim_win_set_height(0, 12)
  vim.wo.winfixheight = true
  vim.cmd.term()
end)

local SPLIT_HEIGHT = 15

local function bottom_split()
  vim.cmd("botright split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(win, SPLIT_HEIGHT)
  vim.wo.winfixheight = true
  return win
end

local function get_job_id(buf)
  return vim.b[buf].terminal_job_id
end

local function ensure_window_for_buf(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return win
    end
  end
  local win = bottom_split()
  vim.api.nvim_win_set_buf(win, buf)
  return win
end

local function find_terminal_by_var(var_name, expected)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == "terminal" and vim.b[buf][var_name] == expected then
      return buf
    end
  end
end

local function open_shell_term(shell)
  local win = bottom_split()
  if shell:match("zsh") then
    vim.cmd("term zsh")
  else
    vim.cmd("term bash")
  end
  local buf = vim.api.nvim_get_current_buf()
  return buf, win
end

local function get_visual_selection()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" then
    vim.cmd("normal! \27")
  end

  local p1 = vim.fn.getpos("'<")
  local p2 = vim.fn.getpos("'>")
  local line_start, col_start = p1[2], p1[3]
  local line_end, col_end = p2[2], p2[3]

  if line_start > line_end or (line_start == line_end and col_start > col_end) then
    line_start, line_end, col_start, col_end = line_end, line_start, col_end, col_start
  end

  local lines = vim.fn.getline(line_start, line_end)
  lines[1] = string.sub(lines[1], col_start, #lines[1])
  lines[#lines] = string.sub(lines[#lines], 1, col_end)

  return table.concat(lines, "\n")
end

-- ============================================================================
-- Run buffer in term
-- ============================================================================

local TERMINAL_MODE = false

local function find_runner_term()
  return find_terminal_by_var("is_runner", true)
end

local function ensure_runner_window(term_buf)
  return ensure_window_for_buf(term_buf)
end

vim.keymap.set("n", "<leader>ru", function()
  vim.cmd("w")

  local file = vim.fn.expand("%:p")
  local stem = vim.fn.expand("%:t:r")
  local dir = vim.fn.fnamemodify(file, ":h")
  local file_escaped = vim.fn.shellescape(file)
  local stem_escaped = vim.fn.shellescape(stem)
  local shell = vim.env.SHELL or "/bin/bash"

  local runners = {
    python = "python",
    sh = "bash",
    lua = "lua",
    go = "go run",
    haskell = "runghc",
    ocaml = "ocaml",
    c = "cc",
  }

  local ft = vim.bo.filetype
  local exe = runners[ft]
  if not exe then
    vim.notify("No runner configured for filetype: " .. ft, vim.log.levels.WARN)
    return
  end

  local build_cmd = {
    c = function()
      return table.concat({
        "cc",
        "-Wall -Wextra -Wpedantic -O2",
        file_escaped,
        "-o",
        stem_escaped,
        "&&",
        "time",
        "./" .. stem_escaped,
      }, " ")
    end,
  }

  local cmd_builder = build_cmd[ft]
  local runner_cmd
  if cmd_builder then
    runner_cmd = "\n" .. cmd_builder()
  else
    runner_cmd = "\n" .. "time " .. exe .. " " .. file_escaped
  end

  local term_buf = find_runner_term()
  local term_win
  if not term_buf then
    term_buf, term_win = open_shell_term(shell)
    vim.b[term_buf].is_runner = true
  else
    term_win = ensure_runner_window(term_buf)
  end

  local job = get_job_id(term_buf)
  local code_win = vim.api.nvim_get_current_win()
  local cmd = table.concat({
    "cd " .. vim.fn.shellescape(dir),
    "clear",
    "printf '\\n===== RUN: %s =====\\n' \"$(date '+%H:%M:%S')\"",
    runner_cmd,
  }, " && ") .. "\n"

  vim.fn.chansend(job, cmd)

  if TERMINAL_MODE then
    vim.api.nvim_set_current_win(term_win)
    vim.cmd("normal! G")
    vim.cmd("startinsert")
  else
    vim.api.nvim_set_current_win(term_win)
    vim.cmd("normal! G")
    vim.api.nvim_set_current_win(code_win)
  end
end)

-- ============================================================================
-- Send visual selection to REPL
-- ============================================================================

local REPL_FOLLOW = false

local repls = {
  python = "ipython",
  lua = "lua -i",
  haskell = "ghci",
  ocaml = "ocaml",
}

local function find_repl_term(ft)
  return find_terminal_by_var("repl_ft", ft)
end

local function ensure_repl_window(repl_buf)
  return ensure_window_for_buf(repl_buf)
end

local function get_or_start_repl(ft, dir, shell)
  local buf = find_repl_term(ft)
  local win

  if not buf then
    buf, win = open_shell_term(shell)

    local job = get_job_id(buf)
    vim.fn.chansend(job, "cd " .. vim.fn.shellescape(dir) .. "\n")

    local repl_cmd = repls[ft]
    if not repl_cmd then
      vim.notify("riperoni " .. ft, vim.log.levels.WARN)
      return
    end

    vim.fn.chansend(job, repl_cmd .. "\n")
    vim.b[buf].repl_ft = ft
  else
    win = ensure_repl_window(buf)
  end

  return buf, win
end

local function send_to_repl(repl_buf, text)
  local job = get_job_id(repl_buf)
  local start_bp = "\x1b[200~"
  local end_bp = "\x1b[201~"

  if not text:match("\n$") then
    text = text .. "\n"
  end

  vim.fn.chansend(job, start_bp .. text .. end_bp .. "\n")
end

vim.keymap.set("x", "<leader>ri", function()
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")
  local dir = vim.fn.fnamemodify(file, ":h")
  local shell = vim.env.SHELL or "/bin/bash"

  if not repls[ft] then
    vim.notify("riperoni " .. ft, vim.log.levels.WARN)
    return
  end

  local text = get_visual_selection()
  local repl_buf, repl_win = get_or_start_repl(ft, dir, shell)
  if not repl_buf then
    return
  end

  local code_win = vim.api.nvim_get_current_win()
  send_to_repl(repl_buf, text)

  if REPL_FOLLOW then
    vim.api.nvim_set_current_win(repl_win)
    vim.cmd("normal! G")
    vim.cmd("startinsert")
  else
    vim.api.nvim_set_current_win(repl_win)
    vim.cmd("normal! G")
    vim.api.nvim_set_current_win(code_win)
  end
end)

-- =============================================================================
-- run "cell" in REPL
-- =============================================================================

local CELL_MARKER = "# COMMAND ----------"

local function line_is_marker(s)
  return s:find(CELL_MARKER, 1, true) ~= nil
end

local function get_current_cell_range()
  local total = vim.api.nvim_buf_line_count(0)
  local cur = vim.fn.line(".")
  local up = cur

  while up >= 1 do
    local l = vim.api.nvim_buf_get_lines(0, up - 1, up, false)[1]
    if line_is_marker(l) then
      break
    end
    up = up - 1
  end

  local start_line = (up >= 1) and (up + 1) or 1
  local down = cur

  while down <= total do
    local l = vim.api.nvim_buf_get_lines(0, down - 1, down, false)[1]
    if line_is_marker(l) then
      break
    end
    down = down + 1
  end

  local end_line = (down <= total) and (down - 1) or total
  return start_line, end_line
end

local function get_current_cell_text()
  local s, e = get_current_cell_range()
  local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
  return table.concat(lines, "\n") .. "\n"
end

vim.keymap.set("n", "<leader>rc", function()
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")
  local dir = vim.fn.fnamemodify(file, ":h")
  local shell = vim.env.SHELL or "/bin/bash"

  local text = get_current_cell_text()
  local repl_buf, repl_win = get_or_start_repl(ft, dir, shell)
  if not repl_buf then
    return
  end

  local code_win = vim.api.nvim_get_current_win()
  send_to_repl(repl_buf, text)

  if REPL_FOLLOW then
    vim.api.nvim_set_current_win(repl_win)
    vim.cmd("normal! G$")
    vim.cmd("startinsert")
  else
    vim.api.nvim_set_current_win(repl_win)
    vim.cmd("normal! G$")
    vim.api.nvim_set_current_win(code_win)
  end
end)
