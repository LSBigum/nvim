return {
  "folke/todo-comments.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    -- make TODO(name): searchable with rg
    -- search = {
    --   pattern = [[\b(KEYWORDS)\s*(\([^)]*\))?:]],
    -- },
    --
    -- -- make the WHOLE TODO line pop, not just up to '('
    -- highlight = {
    --   before = "", -- don't color the comment prefix
    --   keyword = "wide_bg", -- bg on the keyword + nearby punctuation (e.g. '(' or ':')
    --   after = "bg", -- <— bg for everything after the keyword
    --   pattern = [[.*<(KEYWORDS)\s*%(\([^)]*\))?:]], -- same match as before
    --   -- comments_only = true, max_line_len = 400 (defaults are fine)
    -- },
    -- project search (rg): still matches TODO: and TODO(name):
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
}
