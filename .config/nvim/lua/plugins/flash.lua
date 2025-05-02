return {
  "folke/flash.nvim",
  keys = {
    -- disable the default flash keymap
    { "S", mode = { "n", "x", "o" }, false },
    { "s", mode = { "n", "x", "o" }, false },
    { "R", mode = { "o", "x" }, false },
    { "r", mode = "o", false },
    {
      "<c-s>",
      mode = { "c" },
      function()
        require("flash").toggle()
      end,
      desc = "Toggle Flash Search",
    },
  },
  opts = {
    modes = {
      search = { enabled = false },
    },
  },
}
