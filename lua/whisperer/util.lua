local M = {}

local LEVELS = { error = 1, warn = 2, info = 3, debug = 4 }

local function should_log(level)
  local cfg_level = LEVELS[(_G._whisperer_log_level or "warn")] or 2
  return (LEVELS[level] or 99) <= cfg_level
end

local function notify(level, msg)
  local prefix = "[whisperer] "
  local vim_level = ({
    error = vim.log.levels.ERROR,
    warn = vim.log.levels.WARN,
    info = vim.log.levels.INFO,
    debug = vim.log.levels.DEBUG,
  })[level] or vim.log.levels.INFO
  vim.notify(prefix .. msg, vim_level)
end

function M.set_log_level(level)
  _G._whisperer_log_level = level
end

function M.error(msg)
  notify("error", msg)
end

function M.warn(msg)
  if should_log("warn") then
    notify("warn", msg)
  end
end

function M.info(msg)
  if should_log("info") then
    notify("info", msg)
  end
end

function M.debug(msg)
  if should_log("debug") then
    notify("debug", msg)
  end
end

function M.json_encode(value)
  local ok, encoded = pcall(vim.json.encode, value)
  if not ok then
    return nil, "json encode failed: " .. tostring(encoded)
  end
  return encoded, nil
end

function M.json_decode(str)
  if str == nil or str == "" then
    return nil, "empty input"
  end
  local ok, decoded = pcall(vim.json.decode, str)
  if not ok then
    return nil, "json decode failed: " .. tostring(decoded)
  end
  return decoded, nil
end

function M.path_join(...)
  local sep = package.config:sub(1, 1)
  local parts = { ... }
  local joined = table.concat(parts, sep)
  local cleaned = joined:gsub(sep .. sep, sep)
  return cleaned
end

function M.ensure_dir(path, mode)
  mode = mode or 448 -- 0o700
  local stat = vim.uv.fs_stat(path)
  if stat and stat.type == "directory" then
    return true, nil
  end
  local ok, err = vim.uv.fs_mkdir(path, mode)
  if not ok then
    local parent = path:match("^(.*)/[^/]+$")
    if parent and parent ~= path then
      local pok, perr = M.ensure_dir(parent, mode)
      if not pok then
        return false, perr
      end
      ok, err = vim.uv.fs_mkdir(path, mode)
    end
  end
  return ok and true or false, err
end

function M.read_file(path)
  local fd = vim.uv.fs_open(path, "r", 420) -- 0o644
  if not fd then
    return nil, "open failed"
  end
  local stat = vim.uv.fs_fstat(fd)
  if not stat then
    vim.uv.fs_close(fd)
    return nil, "fstat failed"
  end
  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  return data, nil
end

function M.write_file(path, content, mode)
  mode = mode or 384 -- 0o600
  local fd, err = vim.uv.fs_open(path, "w", mode)
  if not fd then
    return false, "open failed: " .. tostring(err)
  end
  local ok, werr = vim.uv.fs_write(fd, content, 0)
  vim.uv.fs_close(fd)
  if not ok then
    return false, "write failed: " .. tostring(werr)
  end
  return true, nil
end

function M.redact(str)
  if type(str) ~= "string" or #str < 8 then
    return "***"
  end
  return str:sub(1, 4) .. "…" .. str:sub(-4)
end

return M
