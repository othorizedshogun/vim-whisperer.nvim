local M = {}

function M.input(opts, callback)
  vim.ui.input({
    prompt = opts.prompt or "> ",
    default = opts.default or "",
  }, function(value)
    callback(value)
  end)
end

function M.input_secret(opts, callback)
  -- vim.ui.input doesn't mask; fall back to native inputsecret() in a deferred call.
  vim.schedule(function()
    local ok, value = pcall(vim.fn.inputsecret, opts.prompt or "secret: ")
    if not ok then
      callback(nil)
    else
      callback(value)
    end
  end)
end

function M.select(items, opts, callback)
  vim.ui.select(items, {
    prompt = opts.prompt or "select:",
    format_item = opts.format_item or tostring,
  }, function(choice)
    callback(choice)
  end)
end

return M
