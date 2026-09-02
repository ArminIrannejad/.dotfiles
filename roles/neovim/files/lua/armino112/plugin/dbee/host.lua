-- the go host drains a whole result set into memory before it draws the first
-- page and never evicts it, so one unbounded select is gigabytes of rss. the
-- only knob nvim has over that from out here is the query text, and rewriting
-- the query is wrong for every dialect that has no trailing LIMIT.
--
-- so bound the drain instead: host.patch stops core.Result:SetIter at
-- DBEE_MAX_ROWS rows and closes the stream. the engine still runs the whole
-- query -- nothing is pushed down -- but the host stops holding the answer.
-- limit.lua still pushes a LIMIT down where the dialect makes that free.
--
-- the patch means building the host instead of downloading it. build from a
-- copy, not in place, so vim.pack still sees a clean checkout to pull into.

local M = {}

M.config = {
  rows = 10000,
  dir = vim.fn.stdpath("cache") .. "/dbee-build",
}

local patch = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)) .. "/host.patch"
local building = false

local function paths()
  local ok, install = pcall(require, "dbee.install")
  if not ok then
    return nil
  end
  return install.source_path(), install.bin()
end

-- what the binary on disk was built from: this patch, that upstream revision
local function want(source, done)
  local text = table.concat(vim.fn.readfile(patch), "\n")
  vim.system({ "git", "-C", source, "rev-parse", "HEAD" }, { text = true }, function(out)
    local rev = out.code == 0 and vim.trim(out.stdout) or "unknown"
    done(vim.fn.sha256(text) .. " " .. rev, rev)
  end)
end

--- rebuild the patched host, unless it is already what we want
--- @param force boolean|nil build even if the stamp matches
function M.build(force)
  local source, binary = paths()
  if not source or building then
    return
  end
  if vim.fn.executable("go") == 0 or vim.fn.filereadable(patch) == 0 then
    return vim.notify("dbee: cannot build the patched host (go, host.patch)", vim.log.levels.WARN)
  end

  local stamp = binary .. ".stamp"

  want(source, function(wanted, rev)
    local have = vim.fn.filereadable(stamp) == 1 and vim.fn.readfile(stamp)[1] or nil
    if not force and have == wanted and vim.fn.executable(binary) == 1 then
      return
    end

    building = true
    vim.schedule(function()
      vim.notify("dbee: building the patched host")
    end)

    -- git init so `git apply` resolves paths against the copy, wherever it sits.
    -- the copy has no history, so hand the revision to main.version instead --
    -- :checkhealth dbee reads it back and would otherwise call the host unknown.
    local script = ([[
      set -e
      rm -rf %s
      cp -r %s %s
      cd %s
      git init -q .
      git apply -p1 %s
      go build -buildvcs=false -ldflags %s -o %s.new .
      mv %s.new %s
    ]]):format(
      vim.fn.shellescape(M.config.dir),
      vim.fn.shellescape(source),
      vim.fn.shellescape(M.config.dir),
      vim.fn.shellescape(M.config.dir),
      vim.fn.shellescape(patch),
      vim.fn.shellescape("-X main.version=" .. rev),
      vim.fn.shellescape(binary),
      vim.fn.shellescape(binary),
      vim.fn.shellescape(binary)
    )

    vim.system({ "sh", "-c", script }, { text = true }, function(out)
      building = false
      vim.schedule(function()
        if out.code ~= 0 then
          local why = vim.trim((out.stderr or ""):gsub(".*\n(.-)\n?$", "%1"))
          return vim.notify("dbee: host build failed: " .. why, vim.log.levels.ERROR)
        end
        pcall(vim.fn.writefile, { wanted }, stamp)
        vim.notify("dbee: patched host built, restart nvim to pick it up")
      end)
    end)
  end)
end

function M.setup()
  vim.env.DBEE_MAX_ROWS = tostring(M.config.rows)

  vim.api.nvim_create_autocmd("PackChanged", {
    callback = function(ev)
      local data = ev.data or {}
      if data.spec and data.spec.name == "nvim-dbee" and data.kind ~= "delete" then
        M.build(true)
      end
    end,
  })

  -- a plugin updated by an nvim that never ran this hook, or a fresh machine
  vim.defer_fn(function()
    M.build(false)
  end, 1000)

  vim.api.nvim_create_user_command("DbeeHostBuild", function(opts)
    M.build(opts.bang)
  end, { bang = true, desc = "Rebuild the patched dbee host (! to force)" })
end

return M
