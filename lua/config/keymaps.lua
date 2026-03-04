local opts = { noremap = true, silent = true }

-- Keep cursor centered when scrolling
vim.keymap.set("n", "<C-d>", "<C-d>zz", opts)
vim.keymap.set("n", "<C-u>", "<C-u>zz", opts)

-- Scroll with cursor in-place
vim.keymap.set('n', '<C-e>', '1<C-d>:set scroll=0<CR>', opts)
vim.keymap.set('n', '<C-y>', '1<C-u>:set scroll=0<CR>', opts)

vim.keymap.set('n', "<C-h>", "<C-w>h", opts)
vim.keymap.set('n', "<C-j>", "<C-w>j", opts)
vim.keymap.set('n', "<C-k>", "<C-w>k", opts)
vim.keymap.set('n', "<C-l>", "<C-w>l", opts)

-- Move selected line / block of text in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", opts)
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", opts)

-- paste over currently selected text without yanking it
vim.keymap.set("v", "p", '"_dp')
vim.keymap.set("v", "P", '"_dP')

-- Move line on the screen rather than by line in the file
-- Does not apply when j/k is prefixed with a count, so '10j' will move according to the relative line count
vim.keymap.set("n", "j", function()
  return vim.v.count == 0 and "gj" or "j"
end, vim.tbl_extend("force", opts, { expr = true }))

vim.keymap.set("n", "k", function()
  return vim.v.count == 0 and "gk" or "k"
end, vim.tbl_extend("force", opts, { expr = true }))

-- Move to start/end of line
vim.keymap.set({ "n", "x", "o" }, "H", "^", opts)
vim.keymap.set({ "n", "x", "o" }, "L", "g_", opts)

-- Navigate buffers
vim.keymap.set("n", "<Right>", ":bnext<CR>", opts)
vim.keymap.set("n", "<Left>", ":bprevious<CR>", opts)

-- Split line with X
vim.keymap.set("n", "X", ":keeppatterns substitute/\\s*\\%#\\s*/\\r/e <bar> normal! ==^<cr>", { silent = true })

vim.keymap.set("n", "<Esc>", ":nohlsearch<CR>", opts)

-- Resizing: Ctrl + Arrow keys
vim.keymap.set("n", "<C-Up>",    "<cmd>resize +2<cr>",          { desc = "Resize up" })
vim.keymap.set("n", "<C-Down>",  "<cmd>resize -2<cr>",          { desc = "Resize down" })
vim.keymap.set("n", "<C-Left>",  "<cmd>vertical resize -2<cr>", { desc = "Resize left" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Resize right" })

-- Exit insert-mode when in a terminal with ESC.
vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { noremap = true, silent = true })

