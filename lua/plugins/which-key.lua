return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "helix",
    delay = 300,
    icons = {
      rules = false,
      breadcrumb = " ", -- symbol used in the command line area that shows your active key combo
      separator = "󱦰  ", -- symbol used between a key and it's label
      group = "󰹍 ", -- symbol prepended to a group
    },
    plugins = {
      spelling = {
        enabled = false,
      },
    },
    win = {
      height = {
        max = math.huge,
      },
    },
    spec = {
      {
        mode = { "n", "v" },
        { "<leader>c", group = "Copy..." },
        { "<leader>d", group = "Debug" },
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Gitsigns" },
        { "<leader>G", group = "Git" },
        { "<leader>l", group = "LSP" },
        { "<leader>o", group = "Overseer" },
        { "<leader>R", group = "Replace" },
        { "<leader>s", group = "Search" },
        { "<leader>t", group = "Test" },
        { "<leader>u", group = "Toggle Features" },
        { "<leader>W", group = "Workspace" },
        { "<leader>x", group = "diagnostics/quickfix (Trouble)" },
        { "[",         group = "prev" },
        { "]",         group = "next" },
        { "g",         group = "goto" },
      },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
}
