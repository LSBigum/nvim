return {
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPost", "BufNewFile" },
    config = function(_, opts)
      require("treesitter-context").setup(opts)
      -- Add a subtle underline “border” under the context window
      vim.api.nvim_set_hl(0, "TreesitterContextBottom", { underline = true, sp = "Grey" })
      vim.api.nvim_set_hl(0, "TreesitterContextLineNumberBottom", { underline = true, sp = "Grey" })
    end,
    keys = {
      { "<leader>ut", "<cmd>TSContext toggle<cr>", desc = "Toggle Treesitter Context" },
    },
    opts = {
      enable = true,
      max_lines = 0,
      trim_scope = "inner",
    },
  },
  {
    "nvim-treesitter/playground",
    config = function() end,
  },
}
