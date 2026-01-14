return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000, -- Load early for colorscheme
  config = function()
    require("catppuccin").setup({
      custom_highlights = function(colors)
        return {
          CodeiumSuggestion = { fg = "#09B6A2" },
          CopilotAnnotation = { fg = "#FDFD96" },
          CopilotSuggestion = { fg = "#FDFD96" },
          LineNr = { fg = "#727593" },
          LineNrAbove = { fg = "#727593" },
          LineNrBelow = { fg = "#727593" },
          WinSeparator = { fg = colors.text },
          CursorLineNr = { style = { "bold" } },
        }
      end,
    })
  end,
}
