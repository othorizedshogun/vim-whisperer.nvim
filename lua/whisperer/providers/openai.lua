local providers = require("whisperer.providers")
local http = require("whisperer.http")
local keystore = require("whisperer.keystore")

local M = {
  id = "openai",
  default_model = "gpt-5-nano",
}

local URL = "https://api.openai.com/v1/chat/completions"

function M.complete(query, opts, callback)
  opts = opts or {}
  local key = keystore.get_key("openai")
  if not key then
    return callback("no API key configured for openai", nil)
  end
  local model = opts.model or keystore.get_model("openai") or M.default_model
  local body = {
    model = model,
    response_format = { type = "json_object" },
    messages = {
      { role = "system", content = providers.SYSTEM_PROMPT },
      { role = "user", content = providers.build_user_message(query) },
    },
  }
  local headers = {
    ["content-type"] = "application/json",
    ["authorization"] = "Bearer " .. key,
  }
  http.post_json(URL, headers, body, function(err, response)
    if err then
      return callback(err, nil)
    end
    if response.error then
      return callback("OpenAI: " .. (response.error.message or "unknown"), nil)
    end
    local choices = response.choices
    if type(choices) ~= "table" or not choices[1] or not choices[1].message then
      return callback("unexpected response shape", nil)
    end
    local text = choices[1].message.content or ""
    local parsed, perr = providers.parse_json_response(text)
    if not parsed then
      return callback("parse failed: " .. perr .. "\n" .. text:sub(1, 200), nil)
    end
    callback(nil, parsed)
  end)
end

providers.register("OpenAI", M)

return M
