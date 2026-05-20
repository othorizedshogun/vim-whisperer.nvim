-- A representative slice of LazyVim's default keymaps for fixture-based tests.
return {
  n = {
    { lhs = "<leader>w",  rhs = "<cmd>w<CR>",                        desc = "Save file" },
    { lhs = "<leader>q",  rhs = "<cmd>q<CR>",                        desc = "Quit window" },
    { lhs = "<leader>ff", rhs = "<cmd>Telescope find_files<CR>",     desc = "Find files" },
    { lhs = "<leader>fg", rhs = "<cmd>Telescope live_grep<CR>",      desc = "Grep files" },
    { lhs = "<leader>fb", rhs = "<cmd>Telescope buffers<CR>",        desc = "Find buffers" },
    { lhs = "<leader>e",  rhs = "<cmd>NvimTreeToggle<CR>",           desc = "Toggle file explorer" },
    { lhs = "<leader>cd", rhs = "<cmd>Lspsaga code_action<CR>",      desc = "Code action" },
    { lhs = "<leader>cr", rhs = "<cmd>Lspsaga rename<CR>",           desc = "Rename symbol" },
    { lhs = "<leader>gh", rhs = "<cmd>Gitsigns preview_hunk<CR>",    desc = "Preview hunk" },
    { lhs = "<leader>gs", rhs = "<cmd>Telescope git_status<CR>",     desc = "Git status" },
    { lhs = "<leader>l",  rhs = "<cmd>Lazy<CR>",                     desc = "Open Lazy" },
    { lhs = "<leader>x",  rhs = "<cmd>TroubleToggle<CR>",            desc = "Toggle trouble list" },
    { lhs = "<leader>bn", rhs = "<cmd>bnext<CR>",                    desc = "Next buffer" },
    { lhs = "<leader>bp", rhs = "<cmd>bprev<CR>",                    desc = "Previous buffer" },
    { lhs = "<leader>bd", rhs = "<cmd>bdelete<CR>",                  desc = "Delete buffer" },
    { lhs = "K",          rhs = "<cmd>Lspsaga hover_doc<CR>",        desc = "Hover documentation" },
    { lhs = "gd",         rhs = "<cmd>Telescope lsp_definitions<CR>", desc = "Go to definition" },
    -- Some maps without desc should be filtered out:
    { lhs = "<leader>z",  rhs = "<cmd>echo 'hi'<CR>",                desc = "" },
    { lhs = "<leader>yz", rhs = "<cmd>echo 'no desc'<CR>" },
  },
  v = {
    { lhs = "<leader>y",  rhs = '"+y',                               desc = "Yank to system clipboard" },
    { lhs = "J",          rhs = ":m '>+1<CR>gv=gv",                  desc = "Move selection down" },
    { lhs = "K",          rhs = ":m '<-2<CR>gv=gv",                  desc = "Move selection up" },
  },
  x = {},
  o = {},
  i = {
    { lhs = "<C-s>",      rhs = "<Esc><cmd>w<CR>a",                  desc = "Save file" },
  },
}
