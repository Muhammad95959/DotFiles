return {
  enabled = true,
  "zbirenbaum/copilot.lua",
  event = "VeryLazy",
  config = function()
    local copilot_auto_trigger_enabled = false
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

    vim.keymap.set("i", "<A-f>", function()
      require("copilot.suggestion").accept()
    end, { silent = true })
    vim.keymap.set("i", "<A-w>", function()
      require("copilot.suggestion").accept_word()
    end, { silent = true })
    vim.keymap.set("i", "<A-a>", function()
      require("copilot.suggestion").accept_line()
    end, { silent = true })
    vim.keymap.set("i", "<A-e>", function()
      require("copilot.suggestion").next()
    end, { silent = true })
    vim.keymap.set("i", "<A-r>", function()
      require("copilot.suggestion").prev()
    end, { silent = true })
    vim.keymap.set("i", "<A-c>", function()
      require("copilot.suggestion").dismiss()
    end, { silent = true })
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
