return {
  "stevearc/conform.nvim",
  event = { "LspAttach" },
  keys = {
    {
      "<leader>lf",
      function()
        print("Performed conform formatting")
        local format = require("conform").format
        local hunks = require("gitsigns").get_hunks()
        if hunks == nil then
          return
        end
        for _, hunk in ipairs(hunks) do
          if hunk ~= nil and hunk.type ~= "delete" then
            local start = hunk.added.start
            local last = start + hunk.added.count
            -- nvim_buf_get_lines uses zero-based indexing -> subtract from last
            local last_hunk_line = vim.api.nvim_buf_get_lines(0, last - 2, last - 1, true)[1]
            local range = { start = { start, 0 }, ["end"] = { last - 1, last_hunk_line:len() } }
            format({ range = range })
          end
        end
      end,
      desc = "[F]ormat buffer",
    },
  },
  ---@module "conform"
  ---@type conform.setupOpts
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      python = { "isort", "black" },
      -- cpp = { "clang-format" },
      cpp = { "albatross_clang_format" },
      yaml = { "yamlfix" },
      bash = { "beautysh" },
    },
    formatters = {
      albatross_clang_format = { command = "nordbo-albatross-clang-format" },
    },
    notify_on_error = true,
    notify_no_formatters = true,
  },
}
