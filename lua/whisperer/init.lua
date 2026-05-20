local config = require("whisperer.config")
local commands = require("whisperer.commands")
local matcher = require("whisperer.matcher")
local macros = require("whisperer.macros")

local M = {}

local did_setup = false

function M.setup(opts)
  config.setup(opts or {})

  -- Eagerly require providers so they self-register.
  pcall(require, "whisperer.providers.anthropic")
  pcall(require, "whisperer.providers.openai")
  pcall(require, "whisperer.providers.gemini")

  matcher.set_user_macros(macros.all())

  commands.register_all()
  commands.register_autocmds()

  -- Optional default keymaps.
  local km = config.get("keymap") or {}
  if km.ask then
    vim.keymap.set("n", km.ask, function() commands.ask(nil) end,
      { silent = true, desc = "Whisperer: ask" })
  end
  if km.teach then
    vim.keymap.set("n", km.teach, function() commands.teach(nil) end,
      { silent = true, desc = "Whisperer: teach" })
  end

  did_setup = true
end

function M.ask(query) commands.ask(query) end
function M.explain(query) commands.explain(query) end
function M.teach(name) commands.teach(name) end
function M.config() commands.config_wizard() end
function M.macros() commands.show_macros() end

function M._is_setup() return did_setup end

return M
