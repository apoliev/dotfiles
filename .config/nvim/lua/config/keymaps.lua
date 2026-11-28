-- Global keymaps. LSP maps are buffer-local (plugins/lsp.lua); telescope,
-- the file tree and the TODO list load on their keys in their plugin specs.
local map = vim.keymap.set

-- Jump back through the jumplist (gd/gD/gr push onto it). <C-o> is taken by
-- the neo-tree toggle, so <C-t> does the VSCode "go back" job. <C-i> = forward.
map("n", "<C-t>", "<C-o>", { remap = true, desc = "Jump back (jumplist)" })

map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Diagnostics (VSCode "Problems")
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end,
  { desc = "Next diagnostic" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end,
  { desc = "Previous diagnostic" })
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Diagnostic details" })
