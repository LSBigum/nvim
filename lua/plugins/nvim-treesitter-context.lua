return {
  {
    "nvim-treesitter/nvim-treesitter-context",
    config = function(_, opts)
      require("treesitter-context").setup(opts)
      -- Add a subtle underline “border” under the context window
      vim.api.nvim_set_hl(0, "TreesitterContextBottom", { underline = true, sp = "Grey" })
      vim.api.nvim_set_hl(0, "TreesitterContextLineNumberBottom", { underline = true, sp = "Grey" })
    end,
    opts = {
      max_lines = 1,
      trim_scope = "inner"
    },
  },
  {
    "nvim-treesitter/playground",
    config = function() end,
  },
}
