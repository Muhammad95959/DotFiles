return {
  "ellisonleao/carbon-now.nvim",
  keys = { { "<A-Space>n", vim.cmd.CarbonNow, mode = "v", desc = "Carbon Now" } },
  cmd = "CarbonNow",
  opts = {
    base_url = "https://carbon.now.sh/",
    options = {
      font_family = "JetBrains Mono",
      theme = "one-dark",
      window_theme = "rounded",
    },
  },
}
