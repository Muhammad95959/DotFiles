return {
  "Exafunction/windsurf.nvim",
  -- cond = function()
  --   local ext = vim.fn.expand("%:e")
  --   local disabled = { "html", "css", "js", "ts", "jsx", "tsx" }
  --   if vim.tbl_contains(disabled, ext) then
  --     return false
  --   end
  -- end,
  ft = {
    "lua",
    "python",
    "java",
    "kotlin",
    "rust",
    "go",
    "c",
    "cpp",
    "sh",
    "zsh",
    "json",
    "yaml",
    "toml",
    "markdown",
  },
  config = function()
    require("codeium").setup({
      enable_cmp_source = false,
      virtual_text = {
        enabled = true,
        manual = false,
        filetypes = {
          html = false,
          css = false,
          javascript = false,
          typescript = false,
          javascriptreact = false,
          typescriptreact = false,
        },
        default_filetype_enabled = true,
        idle_delay = 75,
        virtual_text_priority = 65535,
        map_keys = true,
        accept_fallback = nil,
        key_bindings = {
          accept = "<Tab>",
          accept_word = false,
          accept_line = false,
          clear = "<C-e>",
          next = "<M-]>",
          prev = "<M-[>",
        },
      },
    })
  end,
}
