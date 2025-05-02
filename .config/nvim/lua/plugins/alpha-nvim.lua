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
    require("alpha").setup(require("alpha.themes.startify").config)
    vim.keymap.set("n", "<A-Space>a", ":Alpha<cr>", { desc = "Alpha Toggle", silent = true })
  end,
}
