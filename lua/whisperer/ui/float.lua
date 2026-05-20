local config = require("whisperer.config")

local M = {}

local function dimensions()
  local ui_cfg = config.get("ui") or {}
  local screen_w = vim.o.columns
  local screen_h = vim.o.lines
  local w = math.floor(screen_w * (ui_cfg.width or 0.6))
  local h = math.floor(screen_h * (ui_cfg.height or 0.4))
  if w < 40 then w = 40 end
  if h < 6 then h = 6 end
  return w, h
end

function M.open(opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = opts.filetype or "whisperer"

  local w, h = dimensions()
  if opts.height then h = opts.height end
  if opts.width then w = opts.width end

  local row = math.floor((vim.o.lines - h) / 2)
  local col = math.floor((vim.o.columns - w) / 2)

  local ui_cfg = config.get("ui") or {}
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = w,
    height = h,
    row = row,
    col = col,
    style = "minimal",
    border = ui_cfg.border or "rounded",
    title = opts.title and (" " .. opts.title .. " ") or nil,
    title_pos = opts.title and "center" or nil,
  })

  if opts.lines then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.lines)
  end

  if opts.readonly then
    vim.bo[buf].modifiable = false
  end

  return buf, win
end

function M.close(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

function M.set_lines(buf, lines)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
  local was_modifiable = vim.bo[buf].modifiable
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = was_modifiable
end

function M.bind(buf, lhs, rhs)
  vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, silent = true })
end

-- Translate raw motion keystrokes into human-readable form for beginners.
-- e.g. ":w<CR>" -> ": w Enter"; "<leader>fs" -> "Leader f s"; "<C-x>" -> "Ctrl+X"
local SPECIAL = {
  ["<CR>"] = "Enter", ["<RETURN>"] = "Enter", ["<ENTER>"] = "Enter",
  ["<ESC>"] = "Esc", ["<TAB>"] = "Tab", ["<BS>"] = "Backspace",
  ["<DEL>"] = "Del", ["<SPACE>"] = "Space", ["<NL>"] = "Newline",
  ["<UP>"] = "Up", ["<DOWN>"] = "Down", ["<LEFT>"] = "Left", ["<RIGHT>"] = "Right",
  ["<HOME>"] = "Home", ["<END>"] = "End",
  ["<PAGEUP>"] = "PageUp", ["<PAGEDOWN>"] = "PageDown",
  ["<LEADER>"] = "Leader",
}

local function translate_token(token)
  local upper = token:upper()
  if SPECIAL[upper] then
    return SPECIAL[upper]
  end
  -- Modifier forms: <C-x>, <M-x>, <S-x>, <D-x>
  local mods = { C = "Ctrl", M = "Alt", S = "Shift", D = "Cmd", A = "Alt" }
  local mod, key = upper:match("^<([CMSDA])%-(.+)>$")
  if mod and mods[mod] then
    return mods[mod] .. "+" .. key
  end
  -- Function keys: <F1>..<F12>
  if upper:match("^<F%d+>$") then
    return upper:sub(2, -2)
  end
  return token -- unknown special form, leave as-is
end

local function humanize(motion)
  if type(motion) ~= "string" or motion == "" then
    return ""
  end
  local parts = {}
  local i, len = 1, #motion
  while i <= len do
    local c = motion:sub(i, i)
    if c == "<" then
      local close = motion:find(">", i + 1, true)
      if close then
        table.insert(parts, translate_token(motion:sub(i, close)))
        i = close + 1
      else
        table.insert(parts, c)
        i = i + 1
      end
    else
      table.insert(parts, c)
      i = i + 1
    end
  end
  return table.concat(parts, " ")
end

function M.show_result(result, on_action)
  local motion = result.motion or "<unknown>"
  local lines = {
    "Motion: " .. motion,
    "Type:   " .. humanize(motion),
    "",
    result.explanation or "",
    "",
    "Source: " .. (result.source or "?")
      .. "   Confidence: " .. tostring(result.confidence or "?"),
    "",
    "[<CR>] execute   [e] explain more   [t] teach me one   [a] toggle auto-exec   [q] close",
  }
  local buf, win = M.open({
    title = "Whisperer",
    lines = lines,
    readonly = true,
    height = #lines + 2,
  })

  local function close_and(cb)
    M.close(win)
    if cb then vim.schedule(cb) end
  end

  M.bind(buf, "<CR>", function() close_and(function() on_action("execute", result) end) end)
  M.bind(buf, "e", function() on_action("explain", result) end)
  M.bind(buf, "t", function() close_and(function() on_action("teach", result) end) end)
  M.bind(buf, "a", function() on_action("toggle_auto", result) end)
  M.bind(buf, "q", function() close_and() end)
  M.bind(buf, "<Esc>", function() close_and() end)

  return buf, win
end

function M.show_message(title, lines)
  local buf, win = M.open({
    title = title,
    lines = lines,
    readonly = true,
    height = #lines + 2,
  })
  M.bind(buf, "q", function() M.close(win) end)
  M.bind(buf, "<Esc>", function() M.close(win) end)
  M.bind(buf, "<CR>", function() M.close(win) end)
  return buf, win
end

return M
