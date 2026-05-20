local util = require("whisperer.util")
local config = require("whisperer.config")

local M = {}

local ENV_VAR = {
  anthropic = "ANTHROPIC_API_KEY",
  openai = "OPENAI_API_KEY",
  gemini = "GEMINI_API_KEY",
}

local function read_store()
  local path = config.config_path()
  local data, err = util.read_file(path)
  if not data then
    return { provider = nil, keys = {}, models = {} }, err
  end
  local decoded, derr = util.json_decode(data)
  if not decoded then
    return { provider = nil, keys = {}, models = {} }, derr
  end
  decoded.keys = decoded.keys or {}
  decoded.models = decoded.models or {}
  return decoded, nil
end

local function write_store(store)
  local encoded, err = util.json_encode(store)
  if not encoded then
    return false, err
  end
  return util.write_file(config.config_path(), encoded, 384) -- 0o600
end

function M.get_key(provider)
  local env = ENV_VAR[provider]
  if env then
    local val = vim.env[env]
    if val and val ~= "" then
      return val, "env"
    end
  end
  local store = read_store()
  local key = store.keys[provider]
  if key and key ~= "" then
    return key, "file"
  end
  return nil, nil
end

function M.set_key(provider, key)
  if not ENV_VAR[provider] then
    return false, "unknown provider: " .. tostring(provider)
  end
  local store = read_store()
  store.keys[provider] = key
  if not store.provider then
    store.provider = provider
  end
  return write_store(store)
end

function M.get_active_provider()
  local store = read_store()
  return store.provider or config.get("provider")
end

function M.set_active_provider(provider)
  if not ENV_VAR[provider] then
    return false, "unknown provider: " .. tostring(provider)
  end
  local store = read_store()
  store.provider = provider
  return write_store(store)
end

function M.get_model(provider)
  local store = read_store()
  if store.models and store.models[provider] then
    return store.models[provider]
  end
  return config.get("models")[provider]
end

function M.set_model(provider, model)
  local store = read_store()
  store.models[provider] = model
  return write_store(store)
end

function M.has_key(provider)
  local key = M.get_key(provider)
  return key ~= nil
end

function M.providers()
  return { "Anthropic", "OpenAI", "Gemini" }
end

function M.is_valid_provider(name)
  return ENV_VAR[name] ~= nil
end

return M
