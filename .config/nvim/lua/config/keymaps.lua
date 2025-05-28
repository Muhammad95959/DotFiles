vim.keymap.del("n", "H")
vim.keymap.del("n", "L")
vim.keymap.del("o", "r")
vim.keymap.del({ "o", "x" }, "R")
vim.keymap.del({ "n", "x", "o" }, "s")
vim.keymap.del({ "n", "x", "o" }, "S")

vim.keymap.set("x", "p", "P", { silent = true })
vim.keymap.set("x", "P", "p", { silent = true })
vim.keymap.set({ "n", "v" }, "c", '"_c', { silent = true })
vim.keymap.set({ "n", "v" }, "C", '"_C', { silent = true })
vim.keymap.set({ "n", "v" }, "x", '"_x', { silent = true })
vim.keymap.set({ "n", "v" }, "X", '"_X', { silent = true })
vim.keymap.set({ "n", "v" }, "s", '"_s', { silent = true })
vim.keymap.set({ "n", "v" }, "S", '"_S', { silent = true })
vim.keymap.set({ "n", "v" }, "r", '"_r', { silent = true })
vim.keymap.set({ "n", "v" }, "R", '"_R', { silent = true })
vim.keymap.set({ "n", "v" }, "<A-d>", '"_d', { silent = true })
vim.keymap.set({ "n", "v" }, "<A-D>", '"_D', { silent = true })

vim.keymap.set("v", "<C-c>", "y", { silent = true, desc = "yank" })
vim.keymap.set("v", "<C-v>", "p", { silent = true, desc = "paste" })

vim.keymap.set({ "n", "v" }, "<leader>cs", ":LspStop<cr>", { silent = true, desc = "Lsp Stop" })
vim.keymap.set({ "n", "v" }, "<leader>cS", ":LspStart<cr>", { silent = true, desc = "Lsp Start" })

vim.keymap.set("n", "ZZ", ":lua Save_and_close_buffer()<cr>", { silent = true, desc = "Save and close buffer" })
vim.keymap.set("n", "ZQ", ":lua Close_buffer()<cr>", { silent = true, desc = "Close buffer" })

vim.keymap.set("n", "<A-h>", "<cmd>BufferLineCyclePrev<cr>", { silent = true, desc = "Prev buffer" })
vim.keymap.set("n", "<A-l>", "<cmd>BufferLineCycleNext<cr>", { silent = true, desc = "Next buffer" })
vim.keymap.set("n", "<A-,>", "<cmd>BufferLineMovePrev<cr>", { silent = true, desc = "Buffer move prev" })
vim.keymap.set("n", "<A-.>", "<cmd>BufferLineMoveNext<cr>", { silent = true, desc = "Buffer move next" })

vim.keymap.set("c", "<Down>", 'pumvisible() ? "\\<C-n>" : "\\<C-j>"', { silent = true, expr = true, noremap = true })
vim.keymap.set("c", "<Up>", 'pumvisible() ? "\\<C-p>" : "\\<C-k>"', { silent = true, expr = true, noremap = true })

vim.keymap.set("n", "<A-Space>k", ':silent !kitty "%:p:h" &<cr>', { silent = true, desc = "Kitty" })

function Save_and_close_buffer()
  if #vim.fn.getbufinfo({ buflisted = 1 }) > 1 then
    vim.cmd("w | bdelete")
  else
    vim.cmd("wq")
  end
end

function Close_buffer()
  if #vim.fn.getbufinfo({ buflisted = 1 }) > 1 then
    vim.cmd("bdelete!")
  else
    vim.cmd("q!")
  end
end
