return {
  "folke/tokyonight.nvim",
  lazy = true,
  opts = {
    style = "moon",
    on_highlights = function(hl, c)
      hl.Comment = { fg = "#818ed9" }
      hl.CodeiumSuggestion = { fg = "#09B6A2" }
      hl.NeoCodeiumSuggestion = { fg = "#09B6A2" }
      hl.CopilotAnnotation = { fg = "#FDFD96" }
      hl.CopilotSuggestion = { fg = "#FDFD96" }
      hl.CmpGhostText = { fg = "#717bbf" }
      hl.DiagnosticUnnecessary = { fg = "#717bbf" }
      hl.LineNr = { fg = "#6976ad" }
      hl.LineNrAbove = { fg = "#6976ad" }
      hl.LineNrBelow = { fg = "#6976ad" }
      hl.CursorLineNr = { fg = c.fg }
      hl.WinSeparator = { fg = c.fg }
    end,
  },
}
