return {
  "uga-rosa/ccc.nvim",
  keys = {
    { "<A-Space>c", vim.cmd.CccHighlighterToggle, desc = "Ccc Highlighter Toggle" },
    { "<A-Space>p", vim.cmd.CccPick, desc = "Ccc Pick" },
  },
  cmd = {
    "CccHighlighterToggle",
    "CccPick",
  },
  config = function()
    require("ccc").setup()
  end,
}
