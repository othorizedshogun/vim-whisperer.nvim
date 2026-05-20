if vim.g.loaded_whisperer == 1 then
  return
end
vim.g.loaded_whisperer = 1

if vim.fn.has("nvim-0.10") == 0 then
  vim.notify("[whisperer] requires Neovim 0.10+ (vim.system, RecordingLeave)", vim.log.levels.ERROR)
  return
end

-- Register stub commands that lazy-init on first call. Users who do not call
-- require("whisperer").setup() in their config can still :Whisperer their way in.
local function ensure_setup()
  if not require("whisperer")._is_setup() then
    require("whisperer").setup({})
  end
end

local function stub(name, fn_name, has_args)
  vim.api.nvim_create_user_command(name, function(opts)
    ensure_setup()
    -- After ensure_setup, the real command is registered; delegate.
    local cmd = vim.api.nvim_get_commands({})[name]
    if cmd then
      vim.cmd(string.format("%s %s", name, opts.args or ""))
    else
      require("whisperer.commands")[fn_name](opts.args ~= "" and opts.args or nil)
    end
  end, { nargs = has_args and "?" or 0 })
end

-- Register the headline command early so :Whisperer works pre-setup.
vim.api.nvim_create_user_command("Whisperer", function(opts)
  ensure_setup()
  require("whisperer.commands").ask(opts.args ~= "" and opts.args or nil)
end, { nargs = "?" })

vim.api.nvim_create_user_command("WhispererConfig", function()
  ensure_setup()
  require("whisperer.commands").config_wizard()
end, {})

-- Short aliases registered eagerly so `:Ask` triggers lazy-load too.
vim.api.nvim_create_user_command("Ask", function(opts)
  ensure_setup()
  require("whisperer.commands").ask(opts.args ~= "" and opts.args or nil)
end, { nargs = "?" })

vim.api.nvim_create_user_command("AskConfig", function()
  ensure_setup()
  require("whisperer.commands").config_wizard()
end, {})
