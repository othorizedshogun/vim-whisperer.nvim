local util = require("whisperer.util")
local config = require("whisperer.config")
local keystore = require("whisperer.keystore")
local providers = require("whisperer.providers")
local matcher = require("whisperer.matcher")
local context = require("whisperer.context")
local macros = require("whisperer.macros")
local executor = require("whisperer.executor")
local float = require("whisperer.ui.float")
local prompt = require("whisperer.ui.prompt")

local M = {}

local function on_action(action, result)
  if action == "execute" then
    executor.execute(result.motion)
  elseif action == "explain" then
    float.show_message("Whisperer · Detail", {
      "Motion: " .. result.motion,
      "",
      result.explanation or "",
      "",
      "Source: " .. (result.source or "?"),
      "Confidence: " .. tostring(result.confidence or "?"),
      result.exists and "Built-in or mapped — should work as-is."
        or "Marked as not built-in — may require a macro or plugin.",
    })
  elseif action == "teach" then
    M.teach()
  elseif action == "toggle_auto" then
    local new = config.toggle("auto_execute")
    util.info("auto_execute = " .. tostring(new))
  end
end

local function show_or_execute(result)
  if config.get("auto_execute")
    and result.exists
    and (result.confidence or 0) >= (config.get("auto_execute_min_confidence") or 0.85)
  then
    executor.execute(result.motion)
    return
  end
  float.show_result(result, on_action)
end

local function call_provider(query)
  local provider_name = keystore.get_active_provider() or config.get("provider")
  if not keystore.has_key(provider_name) then
    float.show_message("Whisperer", {
      "No local match and no API key configured for " .. provider_name .. ".",
      "",
      "Run :WhispererConfig to set one up.",
    })
    return
  end
  local provider = providers.resolve(provider_name)
  if not provider then
    util.error("unknown provider: " .. tostring(provider_name))
    return
  end
  util.info("asking " .. provider_name .. "…")
  provider.complete(query, {}, function(err, result)
    if err then
      util.error(err)
      return
    end
    if not result.exists then
      float.show_message("Whisperer", {
        "No built-in motion does this:",
        "  " .. result.motion,
        "",
        result.explanation or "",
        "",
        "Press :WhispererTeach to record a macro for it.",
      })
      return
    end
    show_or_execute(result)
  end)
end

function M.ask(query)
  if not query or query == "" then
    prompt.input({ prompt = "ask whisperer: " }, function(value)
      if value and value ~= "" then
        M.ask(value)
      end
    end)
    return
  end
  local hit = matcher.find(query)
  if hit then
    show_or_execute({
      motion = hit.entry.motion,
      explanation = hit.entry.explanation,
      source = hit.entry.source or "builtin",
      exists = hit.entry.exists,
      confidence = hit.score,
    })
    return
  end
  call_provider(query)
end

function M.explain(query)
  if not query or query == "" then
    prompt.input({ prompt = "explain: " }, function(value)
      if value and value ~= "" then
        M.explain(value)
      end
    end)
    return
  end
  local hit = matcher.find(query)
  if hit then
    float.show_message("Whisperer · Explain", {
      "Motion: " .. hit.entry.motion,
      "",
      hit.entry.explanation or "",
      "",
      "Source: " .. (hit.entry.source or "builtin"),
    })
    return
  end
  call_provider(query) -- show_or_execute will respect auto_execute = false here
end

function M.teach(initial_name)
  float.show_message("Whisperer · Teach", {
    "Press <CR> to start recording into register q.",
    "Perform the action in your buffer, then press q to stop.",
  })
  -- Set a one-shot RecordingLeave handler.
  local group = vim.api.nvim_create_augroup("WhispererTeach", { clear = true })
  vim.api.nvim_create_autocmd("RecordingLeave", {
    group = group,
    once = true,
    callback = function(args)
      local reg = args.data and args.data.regname or "q"
      local keys = vim.fn.getreg(reg) or ""
      if keys == "" then
        util.warn("recording was empty — nothing saved")
        return
      end
      vim.schedule(function()
        prompt.input({ prompt = "name this macro: ", default = initial_name or "" }, function(name)
          if not name or name == "" then
            util.warn("teach cancelled — no name")
            return
          end
          prompt.input({ prompt = "description: " }, function(desc)
            macros.add({
              name = name,
              description = desc or "",
              keys = keys,
              created_at = os.time(),
            })
            matcher.set_user_macros(macros.all())
            float.show_message("Whisperer · Saved", {
              "Macro saved as: " .. name,
              "Keys: " .. vim.fn.keytrans(keys),
              "",
              "Replay any time with: :Whisperer " .. name,
            })
          end)
        end)
      end)
    end,
  })

  -- Wait briefly for the user to read the message, then start recording.
  vim.defer_fn(function()
    vim.api.nvim_feedkeys("qq", "n", false)
  end, 600)
end

function M.config_wizard()
  local provs = keystore.providers()
  prompt.select(provs, { prompt = "Choose provider:" }, function(choice)
    if not choice then return end
    if not keystore.is_valid_provider(choice) then
      util.error("invalid provider: " .. tostring(choice))
      return
    end
    keystore.set_active_provider(choice)
    prompt.input_secret({ prompt = choice .. " API key: " }, function(key)
      if not key or key == "" then
        util.warn("no key entered; provider switched but no key saved")
        return
      end
      local ok, err = keystore.set_key(choice, key)
      if not ok then
        util.error("could not save key: " .. tostring(err))
        return
      end
      util.info("provider set to " .. choice .. ", key saved (0600)")
    end)
  end)
end

function M.set_provider(name)
  if not keystore.is_valid_provider(name) then
    util.error("unknown provider: " .. tostring(name))
    return
  end
  keystore.set_active_provider(name)
  if not keystore.has_key(name) then
    util.warn("provider switched to " .. name .. " but no key set; run :WhispererKey " .. name)
  else
    util.info("active provider: " .. name)
  end
end

function M.rotate_key(provider_name)
  provider_name = provider_name or keystore.get_active_provider()
  if not keystore.is_valid_provider(provider_name) then
    util.error("unknown provider: " .. tostring(provider_name))
    return
  end
  prompt.input_secret({ prompt = provider_name .. " API key: " }, function(key)
    if not key or key == "" then
      util.warn("no key entered")
      return
    end
    local ok, err = keystore.set_key(provider_name, key)
    if not ok then
      util.error("could not save key: " .. tostring(err))
    else
      util.info("key for " .. provider_name .. " saved")
    end
  end)
end

function M.show_macros()
  local list = macros.all()
  local lines = { "# Whisperer macros (" .. #list .. ")", "" }
  if #list == 0 then
    table.insert(lines, "(none yet — :WhispererTeach to record one)")
  end
  for _, m in ipairs(list) do
    table.insert(lines, "- " .. m.name .. " :: " .. (m.description or ""))
    table.insert(lines, "    " .. vim.fn.keytrans(m.keys or ""))
  end
  vim.cmd("vnew")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

function M.refresh_context()
  context.refresh()
  matcher.refresh()
  util.info("context refreshed")
end

function M.show_context()
  local bundle = context.get()
  local encoded = vim.json.encode(bundle)
  local lines = vim.split(encoded, "\n", { plain = true })
  vim.cmd("vnew")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.filetype = "json"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

function M.show_log()
  local data = util.read_file(config.log_path())
  if not data then
    util.warn("no log yet")
    return
  end
  vim.cmd("vnew")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.filetype = "json"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(data, "\n", { plain = true }))
end

function M.toggle_auto_exec()
  local new = config.toggle("auto_execute")
  util.info("auto_execute = " .. tostring(new))
end

function M.register_all()
  local function arg_or_nil(opts)
    if opts.args == nil or opts.args == "" then return nil end
    return opts.args
  end

  vim.api.nvim_create_user_command("Whisperer", function(opts)
    M.ask(arg_or_nil(opts))
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("WhispererExplain", function(opts)
    M.explain(arg_or_nil(opts))
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("WhispererTeach", function(opts)
    M.teach(arg_or_nil(opts))
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("WhispererConfig", function() M.config_wizard() end, {})

  vim.api.nvim_create_user_command("WhispererProvider", function(opts)
    M.set_provider(opts.args)
  end, { nargs = 1, complete = function() return keystore.providers() end })

  vim.api.nvim_create_user_command("WhispererKey", function(opts)
    M.rotate_key(arg_or_nil(opts))
  end, { nargs = "?", complete = function() return keystore.providers() end })

  vim.api.nvim_create_user_command("WhispererMacros", function() M.show_macros() end, {})
  vim.api.nvim_create_user_command("WhispererContext", function() M.show_context() end, {})
  vim.api.nvim_create_user_command("WhispererRefreshContext", function() M.refresh_context() end, {})
  vim.api.nvim_create_user_command("WhispererLog", function() M.show_log() end, {})
  vim.api.nvim_create_user_command("WhispererToggleAutoExec", function() M.toggle_auto_exec() end, {})

  -- Short aliases for everyday use. `:Ask <query>` is the headline path.
  vim.api.nvim_create_user_command("Ask", function(opts)
    M.ask(arg_or_nil(opts))
  end, { nargs = "?" })
  vim.api.nvim_create_user_command("AskTeach", function(opts)
    M.teach(arg_or_nil(opts))
  end, { nargs = "?" })
  vim.api.nvim_create_user_command("AskConfig", function() M.config_wizard() end, {})
  vim.api.nvim_create_user_command("AskExplain", function(opts)
    M.explain(arg_or_nil(opts))
  end, { nargs = "?" })
end

function M.register_autocmds()
  local group = vim.api.nvim_create_augroup("WhispererCore", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = { "LazyDone", "VeryLazy" },
    callback = function()
      context.refresh()
      matcher.refresh()
    end,
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function()
      -- Cheap: just invalidate the matcher cache; context lazily rebuilds.
      context.refresh()
      matcher.refresh()
    end,
  })
end

return M
