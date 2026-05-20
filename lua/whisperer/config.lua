local util = require("whisperer.util")

local M = {}

local defaults = {
  provider = "anthropic",
  models = {
    anthropic = "claude-haiku-4-5-20251001",
    openai = "gpt-4o-mini",
    gemini = "gemini-2.0-flash",
  },
  timeout_ms = 30000,
  fuzzy_threshold = 0.6,
  auto_execute = false,
  auto_execute_min_confidence = 0.85,
  send_local_context = true,
  context_max_bytes = 4096,
  ui = { border = "rounded", width = 0.6, height = 0.4 },
  keymap = { ask = nil, teach = nil },
  log_level = "warn",
}

local state = {
  resolved = nil,
  data_dir = nil,
}

local function deep_merge(base, override)
  if type(override) ~= "table" then
    return base
  end
  local out = {}
  for k, v in pairs(base) do
    if type(v) == "table" and type(override[k]) == "table" then
      out[k] = deep_merge(v, override[k])
    elseif override[k] ~= nil then
      out[k] = override[k]
    else
      out[k] = v
    end
  end
  for k, v in pairs(override) do
    if out[k] == nil then
      out[k] = v
    end
  end
  return out
end

function M.setup(opts)
  state.resolved = deep_merge(defaults, opts or {})
  state.data_dir = util.path_join(vim.fn.stdpath("data"), "whisperer")
  util.ensure_dir(state.data_dir, 448) -- 0o700
  util.set_log_level(state.resolved.log_level)
end

function M.get(key)
  if state.resolved == nil then
    M.setup({})
  end
  if key == nil then
    return state.resolved
  end
  return state.resolved[key]
end

function M.set(key, value)
  if state.resolved == nil then
    M.setup({})
  end
  state.resolved[key] = value
end

function M.toggle(key)
  if state.resolved == nil then
    M.setup({})
  end
  state.resolved[key] = not state.resolved[key]
  return state.resolved[key]
end

function M.data_dir()
  if state.data_dir == nil then
    M.setup({})
  end
  return state.data_dir
end

function M.config_path()
  return util.path_join(M.data_dir(), "config.json")
end

function M.macros_path()
  return util.path_join(M.data_dir(), "macros.json")
end

function M.log_path()
  return util.path_join(M.data_dir(), "last_request.log")
end

function M.defaults()
  return defaults
end

return M
