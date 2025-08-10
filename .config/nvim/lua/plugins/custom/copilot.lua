return {
  enabled = false,
  "zbirenbaum/copilot.lua",
  event = "VeryLazy",
  config = function()
    local copilot_auto_trigger_enabled = true
    require("copilot").setup({
      suggestion = {
        enabled = true,
        auto_trigger = copilot_auto_trigger_enabled,
        accept = false,
      },
      panel = {
        enabled = false,
      },
      filetypes = {
        markdown = true,
        help = true,
        ["*"] = true,
      },
    })

    vim.keymap.set("i", "<Tab>", function()
      if require("copilot.suggestion").is_visible() then
        require("copilot.suggestion").accept()
      else
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
      end
    end, {
      silent = true,
    })

    vim.keymap.set("i", "<C-e>", function()
      if require("copilot.suggestion").is_visible() then
        require("copilot.suggestion").dismiss()
      else
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-e>", true, false, true), "n", false)
      end
    end, {
      silent = true,
    })

    vim.keymap.set("n", "<leader>ct", function()
      require("copilot.suggestion").toggle_auto_trigger()
      copilot_auto_trigger_enabled = not copilot_auto_trigger_enabled
      if copilot_auto_trigger_enabled then
        vim.notify("Copilot auto trigger enabled", vim.log.levels.INFO)
      else
        vim.notify("Copilot auto trigger disabled", vim.log.levels.INFO)
      end
    end, {
      desc = "Toggle Copilot Auto Trigger",
    })
  end,
}
