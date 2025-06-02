return {
  "hrsh7th/nvim-cmp",
  opts = {
    experimental = {
      ghost_text = false,
    },
    window = {
      completion = require("cmp").config.window.bordered({
        winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None",
      }),
      documentation = require("cmp").config.window.bordered({
        winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None",
      }),
    },
  },
}
