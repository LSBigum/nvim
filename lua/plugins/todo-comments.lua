return {
  "folke/todo-comments.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    -- make TODO(name): searchable with rg
    search = {
      pattern = [[\b(KEYWORDS)\s*(\([^)]*\))?:]],
    },

    -- buffer highlighting: only color the "// " + "TODO"
    highlight = {
      keyword = "bg", -- highlight just the keyword letters (not punctuation)
      after = "", -- don't highlight the rest
      pattern = [[\s*(KEYWORDS)]],
    },

    -- optional: lock to only TODO if you want
    -- keywords = { TODO = { icon = " ", color = "info" } },
    -- merge_keywords = false,
  },
  keys = {
    { "<leader>st", function() Snacks.picker.todo_comments() end, desc = "Todo" },
    { "<leader>sT", function() Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } }) end, desc = "Todo/Fix/Fixme" },
  },
}
