local providers = require("whisperer.providers")
local http = require("whisperer.http")
local keystore = require("whisperer.keystore")

local M = {
  id = "gemini",
  default_model = "gemini-2.0-flash",
}

local URL_TEMPLATE = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s"

function M.complete(query, opts, callback)
  opts = opts or {}
  local key = keystore.get_key("gemini")
  if not key then
    return callback("no API key configured for gemini", nil)
  end
  local model = opts.model or keystore.get_model("gemini") or M.default_model
  local url = string.format(URL_TEMPLATE, model, key)

  local body = {
    systemInstruction = {
      parts = { { text = providers.SYSTEM_PROMPT } },
    },
    contents = {
      {
        role = "user",
        parts = { { text = providers.build_user_message(query) } },
      },
    },
    generationConfig = {
      responseMimeType = "application/json",
      maxOutputTokens = 512,
    },
  }
  local headers = {
    ["content-type"] = "application/json",
  }
  http.post_json(url, headers, body, function(err, response)
    if err then
      return callback(err, nil)
    end
    if response.error then
      return callback("gemini: " .. (response.error.message or "unknown"), nil)
    end
    local cand = response.candidates and response.candidates[1]
    if not cand or not cand.content or not cand.content.parts or not cand.content.parts[1] then
      return callback("unexpected response shape", nil)
    end
    local text = cand.content.parts[1].text or ""
    local parsed, perr = providers.parse_json_response(text)
    if not parsed then
      return callback("parse failed: " .. perr .. "\n" .. text:sub(1, 200), nil)
    end
    callback(nil, parsed)
  end)
end

providers.register("gemini", M)

return M
