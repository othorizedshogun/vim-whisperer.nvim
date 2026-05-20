# Contributing

## Dev workflow

```lua
-- in ~/.config/nvim/init.lua
vim.opt.runtimepath:prepend("/path/to/vim-whisperer.nvim")
require("whisperer").setup({})
```

Hot-reload during dev:

```vim
:lua for k in pairs(package.loaded) do if k:match("^whisperer") then package.loaded[k] = nil end end
:lua require("whisperer").setup({})
```

## Lint

```sh
stylua --check .
luacheck lua/
```

## Headless tests

```sh
nvim --headless --noplugin -u NONE -l tests/run.lua
```

The test harness has no external dependencies. Add new fixture files under `tests/fixtures/` and new `it(...)` blocks to `tests/run.lua`.

## Mock provider

To run interactively against canned responses:

```sh
WHISPERER_MOCK=1 nvim
```

Then in Lua:

```lua
_G._whisperer_mock_response = function(url, headers, body)
  return nil, { content = { { type = "text", text = '{"motion":"dw","explanation":"x","exists":true,"confidence":0.9}' } } }
end
```

## Manual test checklist

For changes that touch UI, providers, or the macro flow, run through:

- [ ] `:Whisperer delete word` → matches locally, `<CR>` executes.
- [ ] `:Whisperer save` (with a `<leader>w` keymap that has `desc = "Save file"`) → returns `<leader>w` without an LLM call (verify with `:WhispererLog`).
- [ ] `:WhispererConfig` → wizard runs, key file written with mode 0600 (`stat -f %Lp <path>`).
- [ ] `:Whisperer move every other line up` → LLM call, response renders.
- [ ] `:WhispererProvider openai` → switches without losing the anthropic key.
- [ ] `:WhispererTeach` → records a macro, prompts for name/description, saves.
- [ ] `:WhispererContext` → bundle has only `lhs`+`desc`+mode (no `rhs`).
- [ ] Set `send_local_context = false`, run a query, check `:WhispererLog` — bundle absent.
- [ ] Delete `config.json`, run query → message points to `:WhispererConfig`, no macro flow.
- [ ] `:WhispererToggleAutoExec` → next high-confidence match runs without `<CR>` confirm.

## Releases

1. Tag with `vX.Y.Z` (semver).
2. Update minimum Neovim version in `plugin/whisperer.lua` if needed.
3. `:helptags doc/` regenerates `doc/tags`.
