-- the go host drains a whole result set into memory before it draws the first
-- page, then keeps it: handler.lookupCall is never evicted and core.Result:Wipe
-- is dead code upstream, so every call ever run stays resident until the host
-- exits. it gobs a second copy to /tmp/dbee-history and restores the whole call
-- log from /tmp/dbee-calllog.json at boot, and prunes neither. 111 calls had
-- grown the archive to 18G here.
--
-- so: bound the disk, and watch the host's rss for the part that cannot be
-- bounded from out here. nothing in the rpc surface frees a retained result --
-- Call.Cancel even refuses once the state passes Executing, which is exactly the
-- phase that eats the ram -- so a big query is a warning, not something to stop.

local M = {}

M.config = {
  log = "/tmp/dbee-calllog.json",
  history = "/tmp/dbee-history",

  keep = 5, -- calls per connection kept in the log
  max_results = 5, -- archived result sets kept, newest first
  max_age_s = 7 * 24 * 60 * 60,
  max_bytes = 1024 * 1024 * 1024,

  check_ms = 10 * 1000,
  prune_ms = 5 * 60 * 1000,
  warn_fraction = 0.25, -- of MemTotal, held by the host
  danger_fraction = 0.5,
}

local uuid = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

local function human(bytes)
  if bytes >= 1024 * 1024 * 1024 then
    return ("%.2f GiB"):format(bytes / 1024 / 1024 / 1024)
  end
  return ("%d MiB"):format(bytes / 1024 / 1024)
end

-- the call log ------------------------------------------------------------

local function read_log()
  if vim.fn.filereadable(M.config.log) == 0 then
    return {}
  end
  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(M.config.log), "\n"))
  if not ok or type(decoded) ~= "table" then
    return {}
  end
  return decoded
end

local function write_log(store)
  local encoded = vim.json.encode(vim.tbl_isempty(store) and vim.empty_dict() or store)
  local tmp = M.config.log .. ".tmp"
  if not pcall(vim.fn.writefile, { encoded }, tmp) then
    return
  end
  pcall(vim.uv.fs_rename, tmp, M.config.log)
end

--- drop everything but a recent tail from the call log. startup only, and it has
--- to be synchronous: dbee.setup() registers the persisted connections over rpc,
--- so the host is already up when setup returns, and it writes the log back
--- verbatim on exit -- a later trim just gets clobbered.
function M.trim()
  local store = read_log()
  local cutoff = (os.time() - M.config.max_age_s) * 1000000
  local trimmed = {}

  for conn, calls in pairs(store) do
    if type(calls) == "table" then
      table.sort(calls, function(a, b)
        return (a.timestamp_us or 0) > (b.timestamp_us or 0)
      end)
      local tail = {}
      for rank, call in ipairs(calls) do
        if rank > M.config.keep or (call.timestamp_us or 0) < cutoff then
          break
        end
        table.insert(tail, 1, call) -- back to oldest first, the order the host wrote
      end
      if #tail > 0 then
        trimmed[conn] = tail
      end
    end
  end

  write_log(trimmed)
end

-- the result archive ------------------------------------------------------

--- measure every archive: size from one du, age from the directory itself. the
--- log is deliberately not consulted, so this is safe to run mid-session -- an
--- archive from this session can go without taking its result with it, since the
--- host still has that in memory for as long as it is running.
local function measure(on_done)
  if vim.fn.isdirectory(M.config.history) == 0 then
    return on_done({})
  end

  -- -s and -d conflict, so no -s; the parent's own total fails the uuid match
  vim.system({ "du", "-b", "-d", "1", "--", M.config.history }, { text = true }, function(out)
    local archives = {}
    for line in (out.stdout or ""):gmatch("[^\n]+") do
      local bytes, path = line:match("^(%d+)%s+(.+)$")
      local id = path and vim.fs.basename(path)
      if id and id:match(uuid) then
        local stat = vim.uv.fs_stat(path)
        archives[#archives + 1] = {
          path = path,
          bytes = tonumber(bytes) or 0,
          at = stat and stat.mtime and stat.mtime.sec or 0,
        }
      end
    end
    table.sort(archives, function(a, b)
      return a.at > b.at
    end)
    vim.schedule(function()
      on_done(archives)
    end)
  end)
end

--- keep archives newest first while they fit the count, age and byte budgets,
--- delete the rest. an archive dropped while its call is still in the log
--- leaves the host to downgrade that call to "unknown" on the next restore, and
--- the next trim ages it out.
--- @param report boolean|nil
function M.prune(report)
  measure(function(archives)
    local cutoff = os.time() - M.config.max_age_s
    local drop, kept, freed, total = {}, 0, 0, 0

    for rank, archive in ipairs(archives) do
      local fits = rank <= M.config.max_results
        and archive.at >= cutoff
        and total + archive.bytes <= M.config.max_bytes

      if fits then
        total = total + archive.bytes
        kept = kept + 1
      else
        drop[#drop + 1] = archive.path
        freed = freed + archive.bytes
      end
    end

    if #drop > 0 then
      local cmd = { "rm", "-rf", "--" }
      vim.list_extend(cmd, drop)
      vim.system(cmd)
    end

    if report then
      vim.notify(("dbee: swept %d archives (%s), kept %d (%s)")
        :format(#drop, human(freed), kept, human(total)))
    end
  end)
end

function M.sweep(report)
  M.trim()
  M.prune(report)
end

-- the host ----------------------------------------------------------------

local host = { pid = nil }

local function alive(pid)
  return pid and vim.uv.fs_stat("/proc/" .. pid) ~= nil
end

--- @return integer|nil pid of the go host, if one is running
local function host_pid()
  if alive(host.pid) then
    return host.pid
  end
  host.pid = nil

  for _, chan in ipairs(vim.api.nvim_list_chans()) do
    local argv = chan.argv
    if chan.stream == "job" and type(argv) == "table" and type(argv[1]) == "string" and argv[1]:match("dbee$") then
      local ok, pid = pcall(vim.fn.jobpid, chan.id)
      if ok and alive(pid) then
        host.pid = pid
        return pid
      end
    end
  end
end

local page_size = 4096

local function rss(pid)
  local file = io.open("/proc/" .. pid .. "/statm")
  if not file then
    return nil
  end
  local line = file:read("l")
  file:close()
  local resident = line and line:match("^%d+%s+(%d+)")
  return resident and tonumber(resident) * page_size or nil
end

local meminfo = {}

local function mem(field)
  local file = io.open("/proc/meminfo")
  if not file then
    return nil
  end
  local value
  for line in file:lines() do
    local kb = line:match("^" .. field .. ":%s+(%d+) kB")
    if kb then
      value = tonumber(kb) * 1024
      break
    end
  end
  file:close()
  return value
end

--- @return { pid: integer, rss: integer, total: integer, available: integer }|nil
function M.host()
  local pid = host_pid()
  if not pid then
    return nil
  end
  meminfo.total = meminfo.total or mem("MemTotal")
  local resident = rss(pid)
  if not (resident and meminfo.total) then
    return nil
  end
  return { pid = pid, rss = resident, total = meminfo.total, available = mem("MemAvailable") or 0 }
end

-- the watchdog ------------------------------------------------------------

local level = 0 -- 0 fine, 1 warned, 2 in danger. only ever notifies on the way up

local function check()
  local state = M.host()
  if not state then
    level = 0
    return
  end

  local warn = M.config.warn_fraction * state.total
  local danger = M.config.danger_fraction * state.total

  local at = 0
  if state.rss >= danger then
    at = 2
  elseif state.rss >= warn then
    at = 1
  end

  if at < level then
    -- hysteresis: a host hovering on a threshold should notify once, not every tick
    if state.rss < (level == 2 and danger or warn) * 0.9 then
      level = at
    end
    return
  elseif at == level then
    return
  end
  level = at

  if at == 2 then
    vim.notify(
      ("dbee: host holding %s, %s free. every result stays resident until nvim restarts")
        :format(human(state.rss), human(state.available)),
      vim.log.levels.ERROR
    )
  else
    vim.notify(
      ("dbee: host holding %s of cached results (:DbeeMem)"):format(human(state.rss)),
      vim.log.levels.WARN
    )
  end
end

local timer

local function watch()
  if timer or vim.fn.isdirectory("/proc") == 0 then
    return -- rss lives in /proc; elsewhere the disk sweep is all there is
  end

  timer = vim.uv.new_timer()
  local since_prune = 0

  timer:start(M.config.check_ms, M.config.check_ms, vim.schedule_wrap(function()
    check()

    since_prune = since_prune + M.config.check_ms
    if since_prune >= M.config.prune_ms then
      since_prune = 0
      M.prune()
    end
  end))

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if timer then
        timer:stop()
        timer:close()
        timer = nil
      end
    end,
  })
end

-- commands ----------------------------------------------------------------

vim.api.nvim_create_user_command("DbeeSweep", function()
  M.prune(true)
end, { desc = "Prune the dbee result archive" })

vim.api.nvim_create_user_command("DbeeMem", function()
  local state = M.host()
  if not state then
    return vim.notify("dbee: no host running")
  end
  measure(function(archives)
    local bytes = 0
    for _, archive in ipairs(archives) do
      bytes = bytes + archive.bytes
    end
    vim.notify(("dbee: host %s rss, %s free  ·  archive %s in %d results")
      :format(human(state.rss), human(state.available), human(bytes), #archives))
  end)
end, { desc = "Show dbee host memory and archive size" })

function M.start(report)
  M.sweep(report)
  watch()
end

return M
