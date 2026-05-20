local config = require("whisperer.config")

local M = {}

local PLUGIN_PROBES = {
  "flash", "hop", "leap",
  "mini.surround", "nvim-surround", "surround",
  "mini.ai", "mini.move", "mini.bracketed",
  "telescope", "fzf-lua", "snacks",
  "which-key", "legendary",
}

local cache = {
  bundle = nil,
  built_at = 0,
}

local function detect_distro()
  if vim.g.lazyvim_version or package.loaded["lazyvim"] then
    return "lazyvim"
  end
  if vim.g.nvchad_loaded or package.loaded["nvchad"] or package.loaded["nvconfig"] then
    return "nvchad"
  end
  if vim.g.astronvim_first_install or package.loaded["astronvim"] or package.loaded["astrocore"] then
    return "astronvim"
  end
  -- kickstart heuristic: a single init.lua at stdpath('config') with kickstart marker
  local cfg = vim.fn.stdpath("config") .. "/init.lua"
  local stat = vim.uv.fs_stat(cfg)
  if stat and stat.type == "file" then
    local fd = vim.uv.fs_open(cfg, "r", 420)
    if fd then
      local contents = vim.uv.fs_read(fd, math.min(stat.size, 4096), 0) or ""
      vim.uv.fs_close(fd)
      if contents:lower():match("kickstart") then
        return "kickstart"
      end
    end
  end
  return "plain"
end

local function detect_plugins()
  local hits = {}
  for _, name in ipairs(PLUGIN_PROBES) do
    if package.loaded[name] then
      table.insert(hits, name)
    end
  end
  return hits
end

local function collect_keymaps()
  local entries = {}
  local seen = {}
  local modes = { "n", "v", "x", "o", "i" }
  for _, mode in ipairs(modes) do
    local ok, maps = pcall(vim.api.nvim_get_keymap, mode)
    if ok and type(maps) == "table" then
      for _, m in ipairs(maps) do
        local desc = m.desc
        if desc and desc ~= "" then
          local key = mode .. ":" .. m.lhs
          if not seen[key] then
            seen[key] = true
            table.insert(entries, { lhs = m.lhs, mode = mode, desc = desc })
          end
        end
      end
    end
  end
  return entries
end

local function approx_size(value)
  local ok, encoded = pcall(vim.json.encode, value)
  if not ok then
    return math.huge
  end
  return #encoded
end

local function score_relevance(desc, query)
  if not query or query == "" then
    return 0
  end
  desc = desc:lower()
  query = query:lower()
  if desc:find(query, 1, true) then
    return 100
  end
  local score = 0
  for token in query:gmatch("%w+") do
    if #token >= 2 and desc:find(token, 1, true) then
      score = score + 10
    end
  end
  return score
end

function M.build(query)
  local bundle = {
    distro = detect_distro(),
    plugins = detect_plugins(),
    filetype = vim.bo.filetype or "",
    keymaps = collect_keymaps(),
  }

  local max_bytes = config.get("context_max_bytes") or 4096
  if approx_size(bundle) > max_bytes then
    if query and query ~= "" then
      table.sort(bundle.keymaps, function(a, b)
        return score_relevance(a.desc, query) > score_relevance(b.desc, query)
      end)
    else
      table.sort(bundle.keymaps, function(a, b)
        return a.lhs < b.lhs
      end)
    end
    while #bundle.keymaps > 0 and approx_size(bundle) > max_bytes do
      table.remove(bundle.keymaps)
    end
  end

  cache.bundle = bundle
  cache.built_at = vim.uv.now()
  return bundle
end

function M.get(query)
  if cache.bundle == nil then
    return M.build(query)
  end
  return cache.bundle
end

function M.refresh(query)
  cache.bundle = nil
  return M.build(query)
end

function M.keymap_entries()
  local bundle = M.get()
  local out = {}
  for _, km in ipairs(bundle.keymaps or {}) do
    table.insert(out, {
      phrases = { km.desc, km.lhs },
      motion = km.lhs,
      explanation = km.desc .. " (your keymap, mode " .. km.mode .. ")",
      exists = true,
      source = "user_keymap",
    })
  end
  return out
end

return M
