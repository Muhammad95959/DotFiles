return {
  enabled = false,
  "Exafunction/windsurf.nvim",
  config = function()
    require("codeium").setup({
      enable_cmp_source = false,
      virtual_text = {
        enabled = true,
        manual = false,
        default_filetype_enabled = true,
        idle_delay = 75,
        virtual_text_priority = 65535,
        map_keys = true,
        accept_fallback = "<Tab>",
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
