-- the go host gobs every result to /tmp/dbee-history and restores every call it
-- has ever run from /tmp/dbee-calllog.json. neither is pruned by anything, ever:
-- 111 calls had grown the archive to 18G here, and every restored call is one
-- more entry the host keeps for good. see [[limit]] for the other half, which
-- keeps new archives small in the first place.
--
-- dbee.setup() registers the persisted connections over rpc, so the host is
-- already up by the time setup returns, and it writes the log back verbatim when
-- it exits. the log therefore has to be trimmed before setup, and synchronously.
-- only the disk sweep can afford to wait.

local M = {}

M.config = {
  log = "/tmp/dbee-calllog.json",
  history = "/tmp/dbee-history",
  keep = 20, -- calls per connection
  max_age_s = 7 * 24 * 60 * 60,
  max_bytes = 2 * 1024 * 1024 * 1024,
}

local uuid = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

local function stamp(call)
  return call.timestamp_us or 0
end

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

--- drop everything but a recent tail from the call log
--- @return table<string, table[]> the trimmed store
function M.trim()
  local store = read_log()
  local cutoff = (os.time() - M.config.max_age_s) * 1000000
  local trimmed = {}

  for conn, calls in pairs(store) do
    if type(calls) == "table" then
      table.sort(calls, function(a, b)
        return stamp(a) > stamp(b)
      end)
      local tail = {}
      for rank, call in ipairs(calls) do
        if rank > M.config.keep or stamp(call) < cutoff then
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
  return trimmed
end

--- delete the archives the trimmed log no longer refers to, then spend a byte
--- budget on what is left, newest first. an archive dropped for budget leaves its
--- call in the log; the host downgrades it to "unknown" on the next restore and
--- the next trim ages it out.
--- @param store table<string, table[]>
--- @param report boolean|nil
function M.prune(store, report)
  if vim.fn.isdirectory(M.config.history) == 0 then
    return
  end

  local calls = {}
  for _, conn_calls in pairs(store) do
    for _, call in ipairs(conn_calls) do
      if call.id then
        calls[#calls + 1] = call
      end
    end
  end
  table.sort(calls, function(a, b)
    return stamp(a) > stamp(b)
  end)

  -- -s and -d conflict, so no -s; the parent's own total fails the uuid match
  vim.system({ "du", "-b", "-d", "1", "--", M.config.history }, { text = true }, function(out)
    local by_id = {}
    for line in (out.stdout or ""):gmatch("[^\n]+") do
      local bytes, path = line:match("^(%d+)%s+(.+)$")
      local id = path and vim.fs.basename(path)
      if id and id:match(uuid) then
        by_id[id] = tonumber(bytes)
      end
    end

    vim.schedule(function()
      local keep, total = {}, 0
      for _, call in ipairs(calls) do
        local size = by_id[call.id]
        if size and total + size <= M.config.max_bytes then
          total = total + size
          keep[call.id] = true
        end
      end

      local drop, freed = {}, 0
      for name, kind in vim.fs.dir(M.config.history) do
        if kind == "directory" and name:match(uuid) and not keep[name] then
          drop[#drop + 1] = M.config.history .. "/" .. name
          freed = freed + (by_id[name] or 0)
        end
      end

      if #drop > 0 then
        local cmd = { "rm", "-rf", "--" }
        vim.list_extend(cmd, drop)
        vim.system(cmd)
      end

      if report then
        vim.notify(("dbee: swept %d archives (%.2f GiB), kept %d (%.2f GiB)"):format(
          #drop,
          freed / 1024 / 1024 / 1024,
          vim.tbl_count(keep),
          total / 1024 / 1024 / 1024
        ))
      end
    end)
  end)
end

--- @param report boolean|nil
function M.sweep(report)
  M.prune(M.trim(), report)
end

vim.api.nvim_create_user_command("DbeeSweep", function()
  M.sweep(true)
end, { desc = "Prune the dbee result archive and call log" })

return M
