local util = require("whisperer.util")
local config = require("whisperer.config")

local M = {}

function M.post_json(url, headers, body, callback)
  -- Mock hook for tests.
  if vim.env.WHISPERER_MOCK == "1" then
    local mock = _G._whisperer_mock_response
    if type(mock) == "function" then
      vim.schedule(function()
        local err, decoded = mock(url, headers, body)
        callback(err, decoded)
      end)
    else
      vim.schedule(function() callback("mock not configured", nil) end)
    end
    return
  end

  local args = { "curl", "-sS", "-X", "POST", "--max-time",
    tostring(math.floor((config.get("timeout_ms") or 30000) / 1000)), url }
  for k, v in pairs(headers or {}) do
    table.insert(args, "-H")
    table.insert(args, k .. ": " .. v)
  end
  table.insert(args, "--data-binary")
  table.insert(args, "@-")

  local body_str = body
  if type(body) == "table" then
    local encoded, err = util.json_encode(body)
    if not encoded then
      vim.schedule(function() callback("encode failed: " .. tostring(err), nil) end)
      return
    end
    body_str = encoded
  end

  -- Persist redacted log for :WhispererLog (best effort).
  pcall(function()
    local redacted_headers = {}
    for k, v in pairs(headers or {}) do
      if k:lower():match("authorization") or k:lower():match("api%-key") or k:lower() == "x-api-key" then
        redacted_headers[k] = util.redact(v)
      else
        redacted_headers[k] = v
      end
    end
    local log = {
      url = url,
      headers = redacted_headers,
      body = body_str,
      time = os.date("%Y-%m-%d %H:%M:%S"),
    }
    util.write_file(config.log_path(), util.json_encode(log) or "", 384)
  end)

  vim.system(args, { stdin = body_str, text = true }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        return callback("curl exit " .. obj.code .. ": " .. (obj.stderr or ""), nil)
      end
      local decoded, err = util.json_decode(obj.stdout)
      if not decoded then
        return callback("decode failed: " .. tostring(err) .. "\nraw: " .. (obj.stdout or ""):sub(1, 400), nil)
      end
      callback(nil, decoded)
    end)
  end)
end

return M
