local providers = require("whisperer.providers")
local http = require("whisperer.http")
local keystore = require("whisperer.keystore")

local M = {
  id = "anthropic",
  default_model = "claude-haiku-4-5-20251001",
}

local URL = "https://api.anthropic.com/v1/messages"

function M.complete(query, opts, callback)
  opts = opts or {}
  local key = keystore.get_key("anthropic")
  if not key then
    return callback("no API key configured for anthropic", nil)
  end
  local model = opts.model or keystore.get_model("anthropic") or M.default_model
  local body = {
    model = model,
    max_tokens = 512,
    system = providers.SYSTEM_PROMPT,
    messages = {
      { role = "user", content = providers.build_user_message(query) },
    },
  }
  local headers = {
    ["content-type"] = "application/json",
    ["x-api-key"] = key,
    ["anthropic-version"] = "2023-06-01",
  }
  http.post_json(URL, headers, body, function(err, response)
    if err then
      return callback(err, nil)
    end
    if response.error then
      return callback("anthropic: " .. (response.error.message or "unknown"), nil)
    end
    local content = response.content
    if type(content) ~= "table" or not content[1] or content[1].type ~= "text" then
      return callback("unexpected response shape", nil)
    end
    local text = content[1].text or ""
    local parsed, perr = providers.parse_json_response(text)
    if not parsed then
      return callback("parse failed: " .. perr .. "\n" .. text:sub(1, 200), nil)
    end
    callback(nil, parsed)
  end)
end

providers.register("anthropic", M)

return M
