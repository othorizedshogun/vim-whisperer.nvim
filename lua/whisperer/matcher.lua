local config = require("whisperer.config")
local motions = require("whisperer.motions")
local context = require("whisperer.context")

local M = {}

local cache = {
  flat = nil,
  user_macros = {},
}

local function flatten(entries)
  local flat = {}
  for _, e in ipairs(entries) do
    for _, phrase in ipairs(e.phrases or {}) do
      table.insert(flat, { phrase = phrase, entry = e })
    end
  end
  return flat
end

local function build()
  local all = {}
  for _, e in ipairs(motions) do
    table.insert(all, e)
  end
  for _, e in ipairs(context.keymap_entries()) do
    table.insert(all, e)
  end
  for _, m in ipairs(cache.user_macros) do
    table.insert(all, {
      phrases = { m.name, m.description or "" },
      motion = m.keys,
      explanation = m.description or m.name,
      exists = true,
      source = "user_macro",
      macro_name = m.name,
    })
  end
  cache.flat = flatten(all)
end

function M.set_user_macros(macros)
  cache.user_macros = macros or {}
  cache.flat = nil
end

function M.refresh()
  cache.flat = nil
end

local function fuzzy_score(phrase, query)
  if phrase == query then
    return 1.0
  end
  local p, q = phrase:lower(), query:lower()
  if p == q then
    return 0.99
  end
  if p:find(q, 1, true) then
    return 0.9 - (#p - #q) * 0.005
  end
  if q:find(p, 1, true) then
    return 0.85 - (#q - #p) * 0.005
  end
  -- token overlap
  local p_tokens, q_tokens = {}, {}
  for t in p:gmatch("%w+") do
    p_tokens[t] = true
  end
  local q_count, hits = 0, 0
  for t in q:gmatch("%w+") do
    q_count = q_count + 1
    if p_tokens[t] then
      hits = hits + 1
    end
  end
  if q_count == 0 then
    return 0
  end
  return (hits / q_count) * 0.8
end

function M.find(query)
  if not query or query == "" then
    return nil
  end
  if cache.flat == nil then
    build()
  end
  local best, best_score = nil, 0
  for _, item in ipairs(cache.flat) do
    local s = fuzzy_score(item.phrase, query)
    if s > best_score then
      best_score = s
      best = item.entry
    end
  end
  local threshold = config.get("fuzzy_threshold") or 0.6
  if best and best_score >= threshold then
    return { entry = best, score = best_score }
  end
  return nil
end

function M.find_top(query, n)
  if not query or query == "" then
    return {}
  end
  if cache.flat == nil then
    build()
  end
  local scored = {}
  for _, item in ipairs(cache.flat) do
    local s = fuzzy_score(item.phrase, query)
    if s > 0 then
      table.insert(scored, { score = s, entry = item.entry })
    end
  end
  table.sort(scored, function(a, b)
    return a.score > b.score
  end)
  local out = {}
  local seen = {}
  for _, x in ipairs(scored) do
    if not seen[x.entry.motion] then
      seen[x.entry.motion] = true
      table.insert(out, x)
      if #out >= (n or 5) then
        break
      end
    end
  end
  return out
end

return M
