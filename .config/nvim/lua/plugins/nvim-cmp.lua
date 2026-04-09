return {
  "hrsh7th/nvim-cmp",
  opts = function(_, opts)
    local cmp = require("cmp")

    opts.experimental = {
      ghost_text = false,
    }

    opts.window = {
      completion = cmp.config.window.bordered({
        border = "rounded",           -- ← most popular choice nowadays
        winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None",
      }),

      documentation = cmp.config.window.bordered({
        border = "rounded",
        winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,Search:None",
      }),
    }

    return opts
  end,
}
