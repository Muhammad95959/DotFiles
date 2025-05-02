-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local function map(mode, lhs, rhs, opts)
  local keys = require("lazy.core.handler").handlers.keys
  ---@cast keys LazyKeysHandler
  -- do not create the keymap if a lazy keys handler exists
  if not keys.active[keys.parse({ lhs, mode = mode }).id] then
    opts = opts or {}
    opts.silent = opts.silent ~= false
    if opts.remap and not vim.g.vscode then
      opts.remap = nil
    end
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

function Save_and_close_buffer()
  if vim.bo.buftype == "help" then
    vim.cmd("q!")
  else
    if #vim.fn.getbufinfo({ buflisted = 1 }) > 1 then
      vim.cmd("w | bdelete")
    else
      vim.cmd("wq")
    end
  end
end

function Close_buffer()
  if #vim.fn.getbufinfo({ buflisted = 1 }) > 1 then
    vim.cmd("bdelete!")
  else
    vim.cmd("q!")
  end
end

map("x", "p", "P")
map("x", "P", "p")

map("n", "c", '"_c')
map("n", "C", '"_C')
map("v", "c", '"_c')
map("v", "C", '"_C')
map("n", "x", '"_x')
map("n", "X", '"_X')
map("v", "x", '"_x')
map("v", "X", '"_X')
map("n", "s", '"_s')
map("n", "S", '"_S')
map("v", "s", '"_s')
map("v", "S", '"_S')
map("n", "r", '"_r')
map("n", "R", '"_R')
map("v", "r", '"_r')
map("v", "R", '"_R')

map("n", "<A-d>", '"_d')
map("n", "<A-D>", '"_D')
map("v", "<A-d>", '"_d')
map("v", "<A-D>", '"_D')

map("n", "<A-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
map("n", "<A-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
map("n", "<A-,>", "<cmd>BufferLineMovePrev<cr>", { desc = "Buffer move prev" })
map("n", "<A-.>", "<cmd>BufferLineMoveNext<cr>", { desc = "Buffer move next" })
map("n", "ZZ", ":lua Save_and_close_buffer()<cr>", { desc = "Save and close buffer" })
map("n", "ZQ", ":lua Close_buffer()<cr>", { desc = "Close buffer" })
map("n", "<leader>cs", ":LspStop<cr>", { desc = "Lsp Stop" })
map("n", "<leader>cS", ":LspStart<cr>", { desc = "Lsp Start" })
map("v", "<leader>cs", ":LspStop<cr>", { desc = "Lsp Stop" })
map("v", "<leader>cS", ":LspStart<cr>", { desc = "Lsp Start" })
map("v", "<C-c>", "y", { desc = "yank" })
map("v", "<C-v>", "p", { desc = "paste" })

-- Open kitty terminal in the current working dir
map("n", "<A-Space>k", ':silent !kitty "%:p:h" &<cr>', { desc = "Kitty" })

-- -- Trim the trailing empty lines and the trailing spaces
-- map(
--   "n",
--   "<leader>t",
--   ":let save_cursor = getpos('.')<CR>:silent %!sed -e :a -e '/^\\n*$/{$d;N;ba' -e '}; s/[[:space:]]*$//'<CR>:call setpos('.', save_cursor)<CR>",
--   { desc = "Trailing Trim" }
-- )

-- Menu navigation
vim.keymap.set("c", "<Down>", 'pumvisible() ? "\\<C-n>" : "\\<C-j>"', { expr = true, noremap = true })
vim.keymap.set("c", "<Up>", 'pumvisible() ? "\\<C-p>" : "\\<C-k>"', { expr = true, noremap = true })
