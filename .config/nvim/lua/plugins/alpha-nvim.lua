return {
  "goolord/alpha-nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local startify = require("alpha.themes.startify")
    local logo = [[

                                              
       ████ ██████           █████      ██
      ███████████             █████ 
      █████████ ███████████████████ ███   ███████████
     █████████  ███    █████████████ █████ ██████████████
    █████████ ██████████ █████████ █████ █████ ████ █████
  ███████████ ███    ███ █████████ █████ █████ ████ █████
 ██████  █████████████████████ ████ █████ █████ ████ ██████

    ]]
    startify.section.header.val = vim.split(logo, "\n")
    startify.section.top_buttons.val = {
      startify.button("e", "  New file", ":ene <BAR> startinsert<CR>"),
      startify.button("d", "  Restore current dir session", "<cmd>lua require('persistence').load()<CR>"),
      startify.button("r", "󰑓  Restore last session", "<cmd>lua require('persistence').load({ last = true })<CR>"),
    }
    require("alpha").setup(require("alpha.themes.startify").config)
    vim.keymap.set("n", "<A-Space>a", ":Alpha<cr>", { desc = "Alpha Toggle", silent = true })
  end,
}
