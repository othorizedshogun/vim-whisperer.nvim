# vim-whisperer.nvim

Natural-language → Vim motions, for people still learning Vim.

You type *"delete to end of line"*, and `:Whisperer` tells you the motion (`D`) — or runs it for you. If the plugin doesn't know a motion for what you described, it walks you through recording a Vim macro and saves it as a named, recallable command.

It's aware of **your setup**: LazyVim, NvChad, kickstart.nvim, AstroNvim, or hand-rolled. It reads your keymaps and recommends the binding *you've actually mapped* — not vanilla Vim defaults that don't exist in your config.

LLM backend is configurable: **Claude (Anthropic)**, **OpenAI**, or **Gemini**.

---

## Why

You copied a starter dotfile, opened Neovim, and you can edit text — but you don't yet *think* in motions. You know what you want in English ("yank inside the next quoted string"), not in keystrokes (`yi"`). Whisperer is the bridge.

It is explicitly designed for beginners. It will not auto-execute by default. It explains things. It helps you build muscle memory by surfacing your *own* keymaps when they apply.

## Install

Requires Neovim **0.10+** and `curl` on your `PATH` (already on macOS, Linux, WSL).

### lazy.nvim

```lua
{
  "othorizedshogun/vim-whisperer.nvim",
  cmd = { "Ask", "AskConfig", "AskTeach", "Whisperer", "WhispererConfig" },
  keys = {
    { "<leader>a",  "<cmd>Ask<cr>",       desc = "Ask Whisperer" },
    { "<leader>at", "<cmd>AskTeach<cr>",  desc = "Whisperer: teach a macro" },
    { "<leader>ac", "<cmd>AskConfig<cr>", desc = "Whisperer: configure provider/key" },
  },
  opts = {
    -- See "Configuration" below. Defaults work.
  },
}
```

### packer.nvim

```lua
use({
  "othorizedshogun/vim-whisperer.nvim",
  config = function() require("whisperer").setup({}) end,
})
```

### Manual / dotfiles

```lua
vim.opt.runtimepath:prepend("/path/to/vim-whisperer.nvim")
require("whisperer").setup({})
```

## First-time setup

```
:AskConfig
```

(or the long form `:WhispererConfig` — both work)

Pick a provider (Claude / OpenAI / Gemini), paste your API key. The key is saved to `stdpath("data")/whisperer/config.json` with file mode `0600`. You can also set the environment variable (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or `GEMINI_API_KEY`) instead — env vars override the file.

## Usage

```vim
:Ask delete word
:Ask save
:Ask move every other line up
:Ask
```

`:Ask` is the short alias; `:Whisperer` is the long form. Both behave identically.

In the result float:

```
Motion: :w<CR>
Type:   : w Enter            <- humanized keystrokes for beginners

save current buffer

Source: builtin   Confidence: 1
```

| key             | action                                         |
| --------------- | ---------------------------------------------- |
| `<CR>`          | execute the motion                             |
| `e`             | show a longer explanation                      |
| `t`             | "I want a custom one" — record a macro for it  |
| `a`             | toggle auto-execute for this session           |
| `q` / `<Esc>`   | close                                          |

## Commands

Short aliases (`:Ask*`) for everyday use; long forms (`:Whisperer*`) for discoverability and tab-completion. They're interchangeable.

| Short            | Long                                              | Behavior                                       |
| ---------------- | ------------------------------------------------- | ---------------------------------------------- |
| `:Ask [query]`   | `:Whisperer [query]`                              | Main entry. No arg → prompt.                   |
| `:AskExplain`    | `:WhispererExplain [query]`                       | Show motion + reason; never auto-executes.     |
| `:AskTeach`      | `:WhispererTeach [name]`                          | Manually start the macro recording flow.       |
| `:AskConfig`     | `:WhispererConfig`                                | Wizard: pick provider + enter key.             |
|                  | `:WhispererProvider {anthropic\|openai\|gemini}`  | Switch active provider.                        |
|                  | `:WhispererKey [provider]`                        | Rotate the key for one provider.               |
|                  | `:WhispererMacros`                                | List your saved macros.                        |
|                  | `:WhispererContext`                               | Show the local-context bundle (privacy audit). |
|                  | `:WhispererRefreshContext`                        | Re-scan keymaps after editing your config.     |
|                  | `:WhispererLog`                                   | Last LLM request/response (key redacted).      |
|                  | `:WhispererToggleAutoExec`                        | Flip auto-execute on/off.                      |

### Default keymaps (when wired via lazy.nvim spec)

| key             | action                                  |
| --------------- | --------------------------------------- |
| `<leader>a`     | open the prompt (`:Ask`)                |
| `<leader>at`    | teach a custom motion (`:AskTeach`)     |
| `<leader>ac`    | configure provider/key (`:AskConfig`)   |

## Configuration

```lua
require("whisperer").setup({
  provider = "anthropic",
  models = {
    anthropic = "claude-haiku-4-5-20251001",
    openai    = "gpt-4o-mini",
    gemini    = "gemini-2.0-flash",
  },
  timeout_ms = 30000,
  fuzzy_threshold = 0.6,                  -- below this score, fall back to LLM
  auto_execute = false,                   -- runtime-toggleable
  auto_execute_min_confidence = 0.85,
  send_local_context = true,              -- privacy toggle (see below)
  context_max_bytes = 4096,               -- cap on the context bundle
  ui = { border = "rounded", width = 0.6, height = 0.4 },
  keymap = { ask = nil, teach = nil },     -- set if not using lazy.nvim's `keys` block
  log_level = "warn",
})
```

## How matching works

1. **Local fuzzy match** — Whisperer ships a curated table of common phrases → motions, plus your own keymaps that have a `desc` field set, plus any macros you've saved. Fuzzy lookup happens entirely offline. Most beginner queries hit here without any API call.
2. **LLM fallback** — if no local match scores above `fuzzy_threshold`, the active provider is asked. The system prompt includes your local context (distro, plugins, keymaps) so the model recommends *your* binding when one exists.
3. **Macro recording** — if the LLM says no built-in does it (`exists: false`), or you press `t`, Whisperer walks you through recording a Vim macro and saves it as a named command.

## Make Whisperer smarter

Whisperer ignores keymaps that don't have a `desc` set — descriptionless mappings are noise. Most starter distros set `desc` everywhere. If you've hand-rolled a config, add `desc` to your `vim.keymap.set` calls:

```lua
vim.keymap.set("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
```

Whisperer will pick that up automatically.

## Privacy

Whisperer does **not** send buffer contents, file paths, working directory, or env vars to the LLM. With `send_local_context = true` (default) it sends:

- your detected starter distro name
- the names of installed motion-affecting plugins
- your keymaps' `lhs` + `desc` + mode (never `rhs`)
- the current buffer's `filetype`

Set `send_local_context = false` to send only the literal query. Use `:WhispererContext` to inspect exactly what would be sent.

API keys are stored at `stdpath("data")/whisperer/config.json` with mode `0600`. Use environment variables on shared machines if you'd rather not have plaintext on disk.

## License

MIT. See [LICENSE](./LICENSE).
