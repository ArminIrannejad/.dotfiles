--- Terminal runner / REPL integration.

local M = {}

local uv = vim.uv or vim.loop

--- Where focus goes after sending something to a terminal:
---@alias terminal.Follow
---| '"none"'   # stay in the code window
---| '"focus"'  # move to the terminal window, normal mode
---| '"insert"' # move to the terminal window and enter terminal-mode

---@class terminal.Config
---@field split_height integer height of the bottom terminal split
---@field shell string
---@field follow_run terminal.Follow
---@field follow_repl terminal.Follow
---@field park_on_error boolean park the cursor on the first error after a run
---@field cell_marker string line that delimits REPL cells
---@field runners table<string, string> filetype -> command that runs a file
---@field repls table<string, string> filetype -> interactive REPL command
---@field keymaps table<string, string>
M.config = {
  split_height = 12,
  shell = vim.env.SHELL or "/bin/bash",
  follow_run = "focus",
  follow_repl = "none",
  park_on_error = true,
  cell_marker = "# COMMAND ----------",
  runners = {
    python = "python",
    sh = "bash",
    lua = "lua",
    go = "go run",
    haskell = "runghc",
    ocaml = "ocaml",
    c = "cc",
  },
  repls = {
    python = "ipython",
    lua = "lua -i",
    haskell = "ghci",
    ocaml = "ocaml",
  },
  keymaps = {
    toggle = "<leader>ts",
    run = "<leader>ru",
    send_selection = "<leader>ri",
    send_cell = "<leader>rc",
    jump_to_error = "<CR>",
  },
}


local function bottom_split()
  vim.cmd("botright split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(win, M.config.split_height)
  vim.wo.winfixheight = true
  return win
end

local function get_job_id(buf)
  return vim.b[buf].terminal_job_id
end

local function find_win_for_buf(buf)
  if not buf then return nil end
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(w) == buf then return w end
  end
end

local function ensure_window_for_buf(buf)
  local win = find_win_for_buf(buf)
  if win then return win end
  win = bottom_split()
  vim.api.nvim_win_set_buf(win, buf)
  return win
end

local function is_terminal_alive(buf)
  local job = get_job_id(buf)
  if not job then return false end
  return vim.fn.jobwait({ job }, 0)[1] == -1
end

--- Find the terminal buffer tagged with `b:<var_name> == expected`,
--- deleting it instead if its job has exited.
---@param var_name string
---@param expected any
---@return integer|nil buf
local function find_live_terminal(var_name, expected)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == "terminal" and vim.b[buf][var_name] == expected then
      if is_terminal_alive(buf) then
        return buf
      end
      vim.api.nvim_buf_delete(buf, { force = true })
      return nil
    end
  end
end

local function open_shell_term()
  local win = bottom_split()
  vim.cmd("term " .. (M.config.shell:match("zsh") and "zsh" or "bash"))
  local buf = vim.api.nvim_get_current_buf()
  vim.b[buf].term_cwd = vim.fn.getcwd()
  return buf, win
end

local function term_send(buf, text)
  vim.fn.chansend(get_job_id(buf), text)
end

local function term_cd(buf, dir)
  term_send(buf, "cd " .. vim.fn.shellescape(dir) .. "\n")
  vim.b[buf].term_cwd = dir
end

--- Scroll the terminal to the bottom, then place focus according to `follow`.
---@param term_win integer
---@param code_win integer window we were editing in
---@param follow terminal.Follow
local function focus_after_send(term_win, code_win, follow)
  M._last_code_win = code_win
  vim.api.nvim_set_current_win(term_win)
  vim.cmd("normal! G")
  if follow == "insert" then
    vim.cmd("startinsert")
  elseif follow ~= "focus" then
    vim.api.nvim_set_current_win(code_win)
  end
end

-- ============================================================================
-- Error locations: <CR> on an error line in the terminal jumps to it
-- ============================================================================

--- Working directory of the terminal's shell (via /proc, falling back to the
--- last directory we cd'd it into), so relative paths in errors resolve.
---@param buf integer terminal buffer
---@return string|nil
local function term_cwd(buf)
  local job = get_job_id(buf)
  if job then
    local ok, pid = pcall(vim.fn.jobpid, job)
    if ok and pid and pid > 0 then
      local cwd = uv.fs_readlink("/proc/" .. pid .. "/cwd")
      if cwd then return cwd end
    end
  end
  return vim.b[buf].term_cwd
end

---@param path string absolute, relative or ~ path from an error message
---@param term_buf integer terminal buffer the message appeared in
---@return string|nil # absolute path to an existing file
local function resolve_file(path, term_buf)
  if path:sub(1, 1) == "~" then
    path = vim.fn.expand(path)
  end
  local candidates
  if path:sub(1, 1) == "/" then
    candidates = { path }
  else
    candidates = {}
    local cwd = term_cwd(term_buf)
    if cwd then candidates[#candidates + 1] = cwd .. "/" .. path end
    candidates[#candidates + 1] = vim.fn.getcwd() .. "/" .. path
  end
  for _, p in ipairs(candidates) do
    if vim.fn.filereadable(p) == 1 then return p end
  end
end

--- First location on the line that points at a real file. Covers
--- cc/go/ghc/lua style ("foo.c:12:5:") and python/ocaml style
--- ('File "foo.py", line 12') messages.
---@param line string
---@param term_buf integer
---@return string|nil file, integer|nil lnum, integer|nil col
local function parse_error_line(line, term_buf)
  local file, lnum = line:match('File "([^"]+)", line (%d+)')
  if file then
    local path = resolve_file(file, term_buf)
    if path then return path, tonumber(lnum), nil end
  end
  for f, l, c in line:gmatch("([^%s:'\"()]+):(%d+):?(%d*)") do
    local path = resolve_file(f, term_buf)
    if path then return path, tonumber(l), tonumber(c) end
  end
end

---@param term_buf integer
---@return integer # width the terminal wraps its output at
local function pty_width(term_buf)
  local win = find_win_for_buf(term_buf)
  return win and vim.api.nvim_win_get_width(win) or vim.o.columns
end

--- Terminal output hard-wraps at the PTY width, splitting long paths across
--- physical lines. Rebuild the logical line around `row` by joining
--- full-width lines with their continuations.
---@param lines string[] physical buffer lines
---@param row integer 1-based index into lines
---@param width integer PTY width
---@return string logical, integer first_row, integer last_row
local function logical_line_at(lines, row, width)
  local first, last = row, row
  while first > 1 and #lines[first - 1] == width do
    first = first - 1
  end
  while last < #lines and #lines[last] == width do
    last = last + 1
  end
  return table.concat(lines, "", first, last), first, last
end

--- Window a jump should land in: the code window we last ran from, else the
--- previous window, else any window showing a normal file buffer.
---@return integer|nil win
local function pick_code_win()
  local wins = {}
  if M._last_code_win then wins[#wins + 1] = M._last_code_win end
  wins[#wins + 1] = vim.fn.win_getid(vim.fn.winnr("#"))
  vim.list_extend(wins, vim.api.nvim_tabpage_list_wins(0))
  for _, win in ipairs(wins) do
    if win ~= 0 and vim.api.nvim_win_is_valid(win)
        and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
      return win
    end
  end
end

--- Jump to the file location on the current terminal line (mapped to <CR>
--- in terminal-buffer normal mode).
function M.jump_to_error()
  local term_buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = logical_line_at(lines, row, pty_width(term_buf))
  local file, lnum, col = parse_error_line(line, term_buf)
  if not file then
    vim.notify("No file location on this line", vim.log.levels.WARN)
    return
  end

  local win = pick_code_win()
  if not win then
    vim.cmd("aboveleft split")
    win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_set_current_win(win)

  local buf = vim.fn.bufadd(file)
  vim.bo[buf].buflisted = true
  local ok, err = pcall(vim.api.nvim_win_set_buf, win, buf)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  lnum = math.min(lnum, vim.api.nvim_buf_line_count(buf))
  vim.api.nvim_win_set_cursor(win, { lnum, math.max((col or 1) - 1, 0) })
  vim.cmd("normal! zz")
end

local PARK_INTERVAL = 200
local PARK_TIMEOUT = 30000

--- Watch the terminal for the first error location printed after this run's
--- banner and park the cursor on it, so a single <CR> jumps to it. Output
--- arrives async (and `clear` rewrites the screen rather than appending), so
--- this polls for the banner token and gives up quietly if nothing errors.
---@param term_buf integer
---@param banner_token string unique marker this run prints before its output
local function park_cursor_on_error(term_buf, banner_token)
  if M._park_timer then
    M._park_timer:stop()
    M._park_timer:close()
    M._park_timer = nil
  end

  local elapsed = 0
  local timer = uv.new_timer()
  M._park_timer = timer

  local function stop()
    timer:stop()
    timer:close()
    if M._park_timer == timer then M._park_timer = nil end
  end

  timer:start(PARK_INTERVAL, PARK_INTERVAL, vim.schedule_wrap(function()
    if timer:is_closing() then return end
    elapsed = elapsed + PARK_INTERVAL
    if elapsed > PARK_TIMEOUT or not vim.api.nvim_buf_is_valid(term_buf) then
      stop()
      return
    end

    local lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
    local banner_row
    for i = #lines, 1, -1 do
      if lines[i]:find(banner_token, 1, true) then
        banner_row = i
        break
      end
    end
    if not banner_row then return end

    local width = pty_width(term_buf)
    local i = banner_row + 1
    while i <= #lines do
      local logical, first, last = logical_line_at(lines, i, width)
      if parse_error_line(logical, term_buf) then
        local win = find_win_for_buf(term_buf)
        -- don't steal the cursor while typing in the terminal
        local typing = win == vim.api.nvim_get_current_win()
          and vim.api.nvim_get_mode().mode:sub(1, 1) == "t"
        if win and not typing then
          vim.api.nvim_win_set_cursor(win, { math.max(first, banner_row + 1), 0 })
        end
        stop()
        return
      end
      i = last + 1
    end
  end))
end

-- ============================================================================
-- Shared shell terminal: toggled with <leader>ts, reused by <leader>ru
-- ============================================================================

local function get_or_create_shell_term()
  local buf = find_live_terminal("is_shell", true)
  if buf then
    return buf, ensure_window_for_buf(buf)
  end
  local win
  buf, win = open_shell_term()
  vim.b[buf].is_shell = true
  return buf, win
end

--- Show/hide the shared shell terminal.
function M.toggle()
  local buf = find_live_terminal("is_shell", true)
  local win = find_win_for_buf(buf)
  if win then
    vim.api.nvim_win_close(win, false)
  else
    get_or_create_shell_term()
  end
end

--- Save and run the current file in the shared shell terminal.
function M.run()
  vim.cmd("w")

  local file = vim.fn.expand("%:p")
  local stem = vim.fn.expand("%:t:r")
  local dir = vim.fn.fnamemodify(file, ":h")
  local file_escaped = vim.fn.shellescape(file)
  local stem_escaped = vim.fn.shellescape(stem)

  local ft = vim.bo.filetype
  local exe = M.config.runners[ft]
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

  local code_win = vim.api.nvim_get_current_win()
  local term_buf, term_win = get_or_create_shell_term()

  M._run_id = (M._run_id or 0) + 1
  local banner = ("RUN[%d]"):format(M._run_id)

  local cmd = table.concat({
    "cd " .. vim.fn.shellescape(dir),
    "clear",
    "printf '\\n===== " .. banner .. ": %s =====\\n' \"$(date '+%H:%M:%S')\"",
    runner_cmd,
  }, " && ") .. "\n"

  if M.config.park_on_error then
    park_cursor_on_error(term_buf, banner)
  end
  term_send(term_buf, cmd)
  vim.b[term_buf].term_cwd = dir

  focus_after_send(term_win, code_win, M.config.follow_run)
end

-- ============================================================================
-- REPL: send visual selection or "cell"
-- ============================================================================

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

---@param ft string filetype whose REPL to reuse or start
---@return integer|nil buf, integer|nil win
local function get_or_start_repl(ft)
  local buf = find_live_terminal("repl_ft", ft)
  if buf then
    return buf, ensure_window_for_buf(buf)
  end

  local repl_cmd = M.config.repls[ft]
  if not repl_cmd then
    vim.notify("riperoni " .. ft, vim.log.levels.WARN)
    return
  end

  local dir = vim.fn.expand("%:p:h")
  local win
  buf, win = open_shell_term()
  term_cd(buf, dir)
  term_send(buf, repl_cmd .. "\n")
  vim.b[buf].repl_ft = ft
  return buf, win
end

--- Send text bracketed-paste wrapped, so multi-line blocks paste cleanly.
---@param repl_buf integer
---@param text string
local function send_to_repl(repl_buf, text)
  local start_bp = "\x1b[200~"
  local end_bp = "\x1b[201~"

  if not text:match("\n$") then
    text = text .. "\n"
  end

  term_send(repl_buf, start_bp .. text .. end_bp .. "\n")
end

--- Send the visual selection to the filetype's REPL.
function M.send_selection()
  local code_win = vim.api.nvim_get_current_win()
  local text = get_visual_selection()
  local repl_buf, repl_win = get_or_start_repl(vim.bo.filetype)
  if not repl_buf then
    return
  end

  send_to_repl(repl_buf, text)
  focus_after_send(repl_win, code_win, M.config.follow_repl)
end

-- ============================================================================
-- Cells: blocks delimited by cell_marker lines
-- ============================================================================

local function line_is_marker(s)
  return s:find(M.config.cell_marker, 1, true) ~= nil
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

--- Send the cell around the cursor to the filetype's REPL.
function M.send_cell()
  local code_win = vim.api.nvim_get_current_win()
  local text = get_current_cell_text()
  local repl_buf, repl_win = get_or_start_repl(vim.bo.filetype)
  if not repl_buf then
    return
  end

  send_to_repl(repl_buf, text)
  focus_after_send(repl_win, code_win, M.config.follow_repl)
end

-- ============================================================================
-- Setup
-- ============================================================================

---@param opts terminal.Config|nil merged over the defaults in M.config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  local keys = M.config.keymaps

  vim.api.nvim_create_autocmd("TermOpen", {
    group = vim.api.nvim_create_augroup("custom-term-open", { clear = true }),
    callback = function(ev)
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.opt_local.scrolloff = 0
      vim.bo.filetype = "terminal"
      vim.keymap.set("n", keys.jump_to_error, M.jump_to_error,
        { buffer = ev.buf, desc = "Jump to file location under cursor" })
    end,
  })

  vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>")
  vim.keymap.set("n", keys.toggle, M.toggle, { desc = "Toggle shell terminal" })
  vim.keymap.set("n", keys.run, M.run, { desc = "Run current file in terminal" })
  vim.keymap.set("x", keys.send_selection, M.send_selection, { desc = "Send selection to REPL" })
  vim.keymap.set("n", keys.send_cell, M.send_cell, { desc = "Send cell to REPL" })
end

M.setup()

return M
