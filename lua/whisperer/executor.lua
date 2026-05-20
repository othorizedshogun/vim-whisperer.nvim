local M = {}

local function termcoded(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

function M.execute(motion)
  if type(motion) ~= "string" or motion == "" then
    return false, "empty motion"
  end
  local keys = termcoded(motion)
  vim.api.nvim_feedkeys(keys, "nx", false)
  return true, nil
end

function M.replay_macro(keys)
  if type(keys) ~= "string" or keys == "" then
    return false, "empty macro"
  end
  -- saved macros are already in nvim_feedkeys-ready form (raw register contents)
  vim.api.nvim_feedkeys(keys, "nx", false)
  return true, nil
end

return M
