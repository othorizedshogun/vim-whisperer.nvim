local util = require("whisperer.util")
local config = require("whisperer.config")
local context = require("whisperer.context")

local M = {}

M.SYSTEM_PROMPT = [[You translate natural-language descriptions of text editing actions into Vim normal-mode keystrokes that work in THIS USER'S Neovim setup.

You will receive the user's natural-language query AND a JSON "local_context" block describing their setup:
- distro: "lazyvim" | "nvchad" | "kickstart" | "astronvim" | "plain" | "unknown"
- plugins: array of motion-affecting plugins detected (e.g. ["flash.nvim","mini.surround"])
- keymaps: array of {lhs, mode, desc} for the user's keymaps that have descriptions
- filetype: current buffer's filetype

Reply with ONLY a JSON object, no prose, no code fences:
{
  "motion": "<exact keystrokes the user would type, e.g. dw, gg, 5j, ciw, <leader>fs, :%s/foo/bar/g<CR>>",
  "explanation": "<one sentence, plain English, <=120 chars>",
  "source": "builtin" | "user_keymap" | "plugin" | "macro_needed",
  "exists": <true if achievable with built-ins, the user's keymaps, or installed plugins; false if it genuinely requires a recorded macro>,
  "confidence": <0.0-1.0>
}

Rules:
- PREFER the user's own keymaps when one matches the intent (their muscle memory, their config). Use the lhs verbatim.
- If multiple options work, pick the one most idiomatic to their detected distro/plugins.
- Use <CR>, <Esc>, <C-x>, <leader> notation for special keys.
- Never invent keystrokes that don't appear in their context block or built-in Vim.
- If unsure, set exists=false and source="macro_needed".
- Do not include comments, markdown, or trailing text.]]

function M.build_user_message(query)
  local lines = { "Query: " .. query }
  if config.get("send_local_context") then
    local bundle = context.get(query)
    local encoded, err = util.json_encode(bundle)
    if encoded then
      table.insert(lines, "")
      table.insert(lines, "local_context:")
      table.insert(lines, encoded)
    elseif err then
      util.warn("could not encode context: " .. err)
    end
  end
  return table.concat(lines, "\n")
end

function M.parse_json_response(text)
  if type(text) ~= "string" then
    return nil, "non-string response"
  end
  -- Strip ```json fences if model added them despite instructions.
  text = text:gsub("```json%s*", ""):gsub("```%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
  local decoded, err = util.json_decode(text)
  if not decoded then
    return nil, err
  end
  if type(decoded.motion) ~= "string" then
    return nil, "missing motion field"
  end
  return {
    motion = decoded.motion,
    explanation = decoded.explanation or "",
    source = decoded.source or "builtin",
    exists = decoded.exists ~= false,
    confidence = tonumber(decoded.confidence) or 0.5,
    raw = text,
  }, nil
end

local registry = {}

function M.register(name, mod)
  registry[name] = mod
end

function M.resolve(name)
  if registry[name] then
    return registry[name]
  end
  local ok, mod = pcall(require, "whisperer.providers." .. name)
  if ok then
    registry[name] = mod
    return mod
  end
  return nil
end

return M
