return {
  "akinsho/flutter-tools.nvim",
  ft = { "dart" },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "stevearc/dressing.nvim",
  },
  opts = {
    ui = {
      border = "rounded",
    },
    decorations = {
      statusline = {
        app_version = true,
        device = true,
        project_config = true,
      },
    },
    debugger = {
      enabled = true,
      run_via_dap = true,
      register_configurations = function(_)
        require("dap").configurations.dart = {}
      end,
    },
    closing_tags = {
      enabled = true,
      highlight = "Comment",
      prefix = "// ",
      priority = 10,
    },
    dev_log = {
      enabled = true,
      open_cmd = "tabedit",
    },
    lsp = {
      color = {
        enabled = true,
        background = false,
        foreground = false,
        virtual_text = true,
        virtual_text_str = "■",
      },
      settings = {
        showTodos = true,
        completeFunctionCalls = true,
        renameFilesWithClasses = "prompt",
        enableSnippets = true,
        updateImportsOnRename = true,
      },
    },
    widget_guides = {
      enabled = true,
    },
  },
  keys = {
    { "<leader>Fr", "<cmd>FlutterRun<cr>", desc = "Flutter Run", ft = "dart" },
    { "<leader>FR", "<cmd>FlutterRestart<cr>", desc = "Flutter Restart", ft = "dart" },
    { "<leader>Fl", "<cmd>FlutterReload<cr>", desc = "Flutter Hot Reload", ft = "dart" },
    { "<leader>Fq", "<cmd>FlutterQuit<cr>", desc = "Flutter Quit", ft = "dart" },
    { "<leader>Fd", "<cmd>FlutterDevices<cr>", desc = "Flutter Devices", ft = "dart" },
    { "<leader>Fe", "<cmd>FlutterEmulators<cr>", desc = "Flutter Emulators", ft = "dart" },
    { "<leader>Fo", "<cmd>FlutterOutlineToggle<cr>", desc = "Flutter Outline", ft = "dart" },
    { "<leader>FL", "<cmd>FlutterLogToggle<cr>", desc = "Flutter Log", ft = "dart" },
    { "<leader>FD", "<cmd>FlutterDevTools<cr>", desc = "Flutter DevTools", ft = "dart" },
    { "<leader>FP", "<cmd>FlutterPubGet<cr>", desc = "Flutter Pub Get", ft = "dart" },
  },
  config = function(_, opts)
    require("flutter-tools").setup(opts)
  end,
}
