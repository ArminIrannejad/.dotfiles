-- reads a half typed duckdb statement and says what belongs under the cursor.
--
-- completion runs while the statement is still broken, which is when a real
-- parser gives up, so this is a forgiving tokenizer plus a few rules: which
-- clause the cursor is in, which relations are in scope (tables, aliases,
-- subqueries, ctes, files, table functions) and what dotted prefix it sits
-- behind. no i/o in here, duckdb is asked about the result elsewhere.

local M = {}

-- a "(" followed by one of these opens a new query block with its own relations
local SUBQUERY = {
  select = true,
  with = true,
  from = true,
  values = true,
  table = true,
  pivot = true,
  unpivot = true,
  describe = true,
  summarize = true,
}

-- keywords that put a relation right after them
local TABLE_KEYWORD = {
  from = true,
  join = true,
  into = true,
  update = true,
  describe = true,
  summarize = true,
  truncate = true,
}

-- keywords that leave the cursor wanting an expression
local COLUMN_KEYWORD = {
  select = true,
  where = true,
  on = true,
  having = true,
  by = true,
  set = true,
  qualify = true,
  distinct = true,
  ["and"] = true,
  ["or"] = true,
  ["not"] = true,
  when = true,
  ["then"] = true,
  ["else"] = true,
  case = true,
  between = true,
  like = true,
  ilike = true,
  returning = true,
}

-- what the nearest clause keyword to the left says about the cursor
local CLAUSE = {
  from = "table",
  join = "table",
  into = "table",
  update = "table",
  select = "column",
  where = "column",
  on = "column",
  by = "column",
  having = "column",
  qualify = "column",
  set = "column",
  returning = "column",
  limit = "other",
  offset = "other",
  union = "other",
  except = "other",
  intersect = "other",
  values = "other",
  window = "other",
  create = "other",
  copy = "other",
}

-- end the from list, so a later comma is not another relation
local ENDS_FROM = {
  where = true,
  group = true,
  order = true,
  having = true,
  qualify = true,
  limit = true,
  offset = true,
  window = true,
  union = true,
  except = true,
  intersect = true,
  select = true,
  returning = true,
  set = true,
  values = true,
}

-- words that follow a relation and so can never be its alias
local NOT_AN_ALIAS = vim.tbl_extend("force", ENDS_FROM, {
  join = true,
  inner = true,
  left = true,
  right = true,
  full = true,
  outer = true,
  cross = true,
  natural = true,
  positional = true,
  asof = true,
  semi = true,
  anti = true,
  on = true,
  using = true,
  lateral = true,
  tablesample = true,
  sample = true,
  pivot = true,
  unpivot = true,
  from = true,
  ["as"] = true,
})

---@class armino112.duckdb.Token
---@field kind "word"|"quoted"|"string"|"number"|"punct"|"comment"
---@field s integer first byte, 1-based
---@field e integer last byte
---@field text string
---@field lower? string
---@field open? boolean unterminated

--- @param text string
--- @return armino112.duckdb.Token[]
function M.tokenize(text)
  local tokens = {}
  local n = #text
  local i = 1

  local function push(kind, s, e, open)
    local token = { kind = kind, s = s, e = e, text = text:sub(s, e), open = open }
    if kind == "word" then
      token.lower = token.text:lower()
    end
    tokens[#tokens + 1] = token
  end

  while i <= n do
    local c = text:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif text:sub(i, i + 1) == "--" then
      local newline = text:find("\n", i, true)
      local e = newline and newline - 1 or n
      push("comment", i, e, false)
      i = e + 1
    elseif text:sub(i, i + 1) == "/*" then
      local _, e = text:find("*/", i + 2, true)
      push("comment", i, e or n, e == nil)
      i = (e or n) + 1
    elseif c == "'" or c == '"' then
      local kind = c == "'" and "string" or "quoted"
      local j = i + 1
      while true do
        local q = text:find(c, j, true)
        if not q then
          push(kind, i, n, true)
          i = n + 1
          break
        end
        if text:sub(q + 1, q + 1) == c then
          j = q + 2 -- doubled quote is an escape
        else
          push(kind, i, q)
          i = q + 1
          break
        end
      end
    elseif c:match("[%a_\128-\255]") then
      local _, e = text:find("^[%w_$\128-\255]*", i + 1)
      push("word", i, e, nil)
      i = e + 1
    elseif c:match("%d") then
      local _, e = text:find("^[%w_%.]*", i + 1)
      push("number", i, e, nil)
      i = e + 1
    else
      push("punct", i, i, nil)
      i = i + 1
    end
  end

  return tokens
end

--- identifier as the user would type it back, quoted only when it has to be
--- @param name string
function M.quote(name)
  if name:match("^[%a_][%w_]*$") then
    return name
  end
  return '"' .. name:gsub('"', '""') .. '"'
end

local function ident(token)
  if token.kind == "quoted" then
    local inner = token.text:sub(2, token.open and -1 or -2)
    return (inner:gsub('""', '"'))
  end
  return token.text
end

local function is_name(token)
  return token ~= nil and (token.kind == "word" or token.kind == "quoted")
end

local function is_punct(token, char)
  return token ~= nil and token.kind == "punct" and token.text == char
end

local function is_word(token, word)
  return token ~= nil and token.kind == "word" and token.lower == word
end

--- cursor sitting inside a comment means nothing to complete
local function in_comment(comments, cur)
  for _, token in ipairs(comments) do
    if token.open or token.text:sub(1, 2) == "--" then
      if cur > token.s and cur <= token.e then
        return true
      end
    elseif cur > token.s and cur < token.e then
      return true
    end
  end
  return false
end

--- split the statement the cursor is in out of the whole buffer
local function statement_tokens(all, cur)
  local first, last = 1, #all
  for index, token in ipairs(all) do
    if is_punct(token, ";") then
      if token.e <= cur then
        first = index + 1
      elseif token.s > cur then
        last = index - 1
        break
      end
    end
  end
  return vim.list_slice(all, first, last)
end

--- give every token a scope and a paren depth, and pair up the parentheses
local function annotate(toks, before_n)
  local scopes = { [0] = { id = 0, base = 0, first = 1 } }
  local stack = {}
  local scope = 0
  local cursor_scope = 0
  local next_id = 0

  for index, token in ipairs(toks) do
    if is_punct(token, "(") then
      token.scope, token.depth = scope, #stack
      local following = toks[index + 1]
      local opens = following and following.kind == "word" and SUBQUERY[following.lower]
      stack[#stack + 1] = { outer = scope, open = index }
      if opens then
        next_id = next_id + 1
        scopes[next_id] = { id = next_id, parent = scope, base = #stack, first = index + 1 }
        scope = next_id
        stack[#stack].scope = next_id
      end
    elseif is_punct(token, ")") and #stack > 0 then
      local top = table.remove(stack)
      if top.scope then
        scopes[top.scope].last = index - 1
      end
      toks[top.open].match = index
      scope = top.outer
      token.scope, token.depth = scope, #stack
    else
      token.scope, token.depth = scope, #stack
    end
    if index == before_n then
      cursor_scope = scope
    end
  end

  for _, s in pairs(scopes) do
    s.last = s.last or #toks
  end
  return scopes, cursor_scope
end

--- walk left to the nearest clause keyword that still applies at the cursor
--- @return string|nil keyword
local function clause_at(toks, index)
  local depth = 0
  for j = index, 1, -1 do
    local token = toks[j]
    if is_punct(token, ")") then
      depth = depth + 1
    elseif is_punct(token, "(") then
      if depth > 0 then
        depth = depth - 1
      elseif toks[j + 1] and toks[j + 1].kind == "word" and SUBQUERY[toks[j + 1].lower] then
        return nil -- a subquery starts here, nothing outside it counts
      end
    elseif depth == 0 and token.kind == "word" and CLAUSE[token.lower] then
      return token.lower
    end
  end
  return nil
end

local function position_of(toks, before_n, qualified)
  if qualified then
    return "qualified"
  end

  local prev = toks[before_n]
  if not prev then
    return "other"
  end

  if prev.kind == "word" then
    local kw = prev.lower
    local first = toks[1] and toks[1].lower
    if TABLE_KEYWORD[kw] then
      return "table"
    end
    if (first == "drop" or first == "alter") and (kw == "table" or kw == "view" or kw == "exists") then
      return "table"
    end
    return COLUMN_KEYWORD[kw] and "column" or "other"
  end

  if is_punct(prev, ",") then
    local clause = CLAUSE[clause_at(toks, before_n - 1)]
    return clause or "other"
  end

  if is_punct(prev, "(") then
    local before = toks[before_n - 1]
    if before and before.kind == "word" and (before.lower == "from" or before.lower == "join") then
      return "other" -- a subquery is about to start
    end
    if is_word(before, "using") then
      return "column" -- join t using (|
    end
    local clause = clause_at(toks, before_n - 1)
    -- insert into t (|
    if clause == "into" or CLAUSE[clause] == "column" then
      return "column"
    end
    return "other"
  end

  if prev.kind == "punct" and prev.text:match("[=<>!+%-*/%%|&^~:]") then
    if prev.text == "*" then
      local before = toks[before_n - 1]
      if before and (is_punct(before, ",") or is_punct(before, ".") or is_punct(before, "(") or COLUMN_KEYWORD[before.lower or ""]) then
        return "other" -- select * |
      end
    end
    local clause = CLAUSE[clause_at(toks, before_n - 1)]
    return clause == "column" and "column" or "other"
  end

  return "other"
end

--- the with clause at the start of a scope, one entry per finished cte
local function scan_ctes(toks, text, scope)
  local ctes = {}
  local start = scope.first
  if not is_word(toks[start], "with") then
    return ctes
  end

  local j = start + 1
  if is_word(toks[j], "recursive") then
    j = j + 1
  end

  while is_name(toks[j]) do
    local name = ident(toks[j])
    j = j + 1
    if is_punct(toks[j], "(") and toks[j].match then
      j = toks[j].match + 1 -- column list
    end
    if not is_word(toks[j], "as") then
      break
    end
    j = j + 1
    if is_word(toks[j], "not") then
      j = j + 1
    end
    if is_word(toks[j], "materialized") then
      j = j + 1
    end
    if not (is_punct(toks[j], "(") and toks[j].match) then
      break
    end
    local close = toks[j].match
    ctes[#ctes + 1] = {
      name = name,
      close = close,
      with = text:sub(toks[start].s, toks[close].e),
    }
    j = close + 1
    if is_punct(toks[j], ",") then
      j = j + 1
    else
      break
    end
  end
  return ctes
end

--- relation starting at toks[i]: a name, a function call, a file or a subquery
--- @return table|nil relation
--- @return integer|nil last index consumed
local function parse_relation(toks, text, i, skip)
  local token = toks[i]
  if not token or token == skip then
    return nil
  end

  local relation = { start = i }
  local j = i

  if is_punct(token, "(") then
    if not token.match then
      return nil
    end
    j = token.match
    relation.kind = "subquery"
    relation.source = text:sub(token.s, toks[j].e)
  elseif is_name(token) then
    if token.kind == "word" and (ENDS_FROM[token.lower] or NOT_AN_ALIAS[token.lower]) then
      return nil
    end
    local path = { ident(token) }
    while is_punct(toks[j + 1], ".") and is_name(toks[j + 2]) and toks[j + 2] ~= skip do
      path[#path + 1] = ident(toks[j + 2])
      j = j + 2
    end
    if is_punct(toks[j + 1], ".") then
      return nil -- schema. with the table still to come
    end
    relation.name = path[#path]
    if is_punct(toks[j + 1], "(") and toks[j + 1].match then
      j = toks[j + 1].match
      relation.kind = "function"
      relation.source = text:sub(token.s, toks[j].e)
    else
      relation.kind = "table"
      relation.path = path
      relation.source = table.concat(vim.tbl_map(M.quote, path), ".")
    end
  elseif token.kind == "string" and not token.open then
    j = i
    relation.kind = "file"
    relation.source = token.text
    relation.name = token.text:sub(2, -2):match("([^/\\]+)$") or ""
    relation.name = relation.name:gsub("%.[%w_]+$", ""):gsub("%.[%w_]+$", "")
  else
    return nil
  end

  -- alias, with or without AS
  local following = toks[j + 1]
  if is_word(following, "as") and is_name(toks[j + 2]) and toks[j + 2] ~= skip then
    relation.alias = ident(toks[j + 2])
    j = j + 2
  elseif following and following ~= skip and (following.kind == "quoted" or (following.kind == "word" and not NOT_AN_ALIAS[following.lower])) then
    relation.alias = ident(following)
    j = j + 1
  end
  return relation, j
end

--- every relation a scope puts in front of its own clauses
local function scan_relations(toks, text, scope, skip)
  local relations = {}
  local in_from = false
  local i = scope.first

  while i <= scope.last do
    local token = toks[i]
    if token.scope == scope.id and token.depth == scope.base then
      local take = false
      if token.kind == "word" then
        local kw = token.lower
        if kw == "from" or kw == "join" or kw == "update" or kw == "into" then
          take = true
          in_from = kw ~= "into"
        elseif kw == "using" and not is_punct(toks[i + 1], "(") then
          take = true
          in_from = true
        elseif ENDS_FROM[kw] then
          in_from = false
        end
      elseif in_from and is_punct(token, ",") then
        take = true
      end

      if take then
        local relation, last = parse_relation(toks, text, i + 1, skip)
        if relation then
          relation.scope = scope.id
          relations[#relations + 1] = relation
          i = last
        end
      end
    end
    i = i + 1
  end
  return relations
end

--- @class armino112.duckdb.Context
--- @field skip? boolean nothing to complete here
--- @field prefix string what has been typed of the word under the cursor
--- @field prefix_start integer byte index in the text where that word starts
--- @field position "table"|"column"|"qualified"|"other"
--- @field in_string boolean
--- @field qualifier? string[]
--- @field relations table[]
--- @field ctes string[]
--- @field statement string the statement up to the cursor

--- @param text string whole buffer
--- @param cur integer bytes before the cursor
--- @return armino112.duckdb.Context
function M.analyze(text, cur)
  local all = M.tokenize(text)

  local comments = vim.tbl_filter(function(token)
    return token.kind == "comment"
  end, all)
  if in_comment(comments, cur) then
    return { skip = true }
  end

  local toks = vim.tbl_filter(function(token)
    return token.kind ~= "comment"
  end, statement_tokens(all, cur))

  -- the token the cursor is touching is being typed, not finished
  local typing
  local before_n = 0
  for index, token in ipairs(toks) do
    local touching = token.s <= cur
      and (cur < token.e or (cur == token.e and (token.kind == "word" or token.open)))
    if touching and (token.kind == "word" or token.kind == "quoted" or token.kind == "string") then
      typing = token
      before_n = index - 1
      break
    elseif token.s <= cur and cur <= token.e and token.kind == "number" then
      return { skip = true }
    end
    if token.e <= cur then
      before_n = index
    else
      break
    end
  end

  local scopes, cursor_scope = annotate(toks, before_n)

  local qualifier
  if is_punct(toks[before_n], ".") then
    local parts = {}
    local j = before_n
    while is_punct(toks[j], ".") and is_name(toks[j - 1]) do
      table.insert(parts, 1, ident(toks[j - 1]))
      j = j - 2
    end
    qualifier = #parts > 0 and parts or nil
  end

  local result = {
    prefix = typing and text:sub(typing.s, cur) or "",
    prefix_start = typing and typing.s or cur + 1,
    in_string = typing ~= nil and typing.kind == "string",
    qualifier = qualifier,
    position = position_of(toks, before_n, qualifier ~= nil),
    relations = {},
    ctes = {},
    statement = text:sub(toks[1] and math.min(toks[1].s, cur + 1) or cur + 1, cur),
  }

  -- innermost block first: a correlated subquery sees its own relations
  -- before the ones around it
  local chain = {}
  local id = cursor_scope
  while id do
    chain[#chain + 1] = id
    id = scopes[id].parent
  end

  local finished = {}
  for _, sid in ipairs(chain) do
    finished[sid] = scan_ctes(toks, text, scopes[sid])
    for _, cte in ipairs(finished[sid]) do
      result.ctes[#result.ctes + 1] = cte.name
    end
  end

  local function find_cte(name)
    for _, sid in ipairs(chain) do
      for _, cte in ipairs(finished[sid]) do
        if cte.name:lower() == name:lower() then
          return cte
        end
      end
    end
  end

  -- the with clause a relation's own source needs to compile
  local function with_for(relation)
    for _, sid in ipairs(chain) do
      local last
      for _, cte in ipairs(finished[sid]) do
        if cte.close < relation.start then
          last = cte
        end
      end
      if last then
        return last.with
      end
    end
  end

  for _, sid in ipairs(chain) do
    for _, relation in ipairs(scan_relations(toks, text, scopes[sid], typing)) do
      local cte = relation.kind == "table" and #relation.path == 1 and find_cte(relation.path[1])
      if cte then
        relation.kind = "cte"
        relation.with = cte.with
      else
        relation.with = with_for(relation)
      end
      result.relations[#result.relations + 1] = relation
    end
  end

  return result
end

return M
