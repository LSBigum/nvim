return {
  "sindrets/winshift.nvim",
  lazy = true,
  cmd = "WinShift",
  keys = {
    { "<C-w>H", "<cmd>WinShift left<cr>",  desc = "Move window left" },
    { "<C-w>J", "<cmd>WinShift down<cr>",  desc = "Move window down" },
    { "<C-w>K", "<cmd>WinShift up<cr>",    desc = "Move window up" },
    { "<C-w>L", "<cmd>WinShift right<cr>", desc = "Move window right" },
  },
  opts = {},
}
