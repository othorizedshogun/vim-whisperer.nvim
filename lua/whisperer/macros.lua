local util = require("whisperer.util")
local config = require("whisperer.config")

local M = {}

local cache = nil

local function load_from_disk()
  local path = config.macros_path()
  local data = util.read_file(path)
  if not data then
    return {}
  end
  local decoded, err = util.json_decode(data)
  if not decoded then
    util.warn("could not decode macros.json: " .. tostring(err))
    return {}
  end
  return decoded
end

local function persist()
  local path = config.macros_path()
  local encoded, err = util.json_encode(cache or {})
  if not encoded then
    return false, err
  end
  return util.write_file(path, encoded, 384) -- 0o600
end

function M.all()
  if cache == nil then
    cache = load_from_disk()
  end
  return cache
end

function M.find_by_name(name)
  for _, m in ipairs(M.all()) do
    if m.name == name then
      return m
    end
  end
  return nil
end

function M.add(macro)
  if cache == nil then
    cache = load_from_disk()
  end
  for i, existing in ipairs(cache) do
    if existing.name == macro.name then
      cache[i] = macro
      return persist()
    end
  end
  table.insert(cache, macro)
  return persist()
end

function M.remove(name)
  if cache == nil then
    cache = load_from_disk()
  end
  for i, m in ipairs(cache) do
    if m.name == name then
      table.remove(cache, i)
      return persist()
    end
  end
  return false, "not found"
end

function M.refresh()
  cache = load_from_disk()
  return cache
end

return M
