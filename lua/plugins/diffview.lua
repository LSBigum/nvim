return {
  "sindrets/diffview.nvim",
  opts = {
    enhanced_diff_hl = false,
    file_panel = {
    win_config = function()
      return {
        type = "split",
        position = "bottom",
        height = 12,
      }
    end,
    },
    view = {
      default = {
        layout = "diff2_vertical",
      },
    },
  },
  config = function(_, opts)
    require("diffview").setup(opts)

    vim.api.nvim_create_user_command("DiffviewOpenPrompt", function()
      local default = "main...HEAD"
      local input = vim.fn.input("Diffview range/rev: ", default)
      if input == nil or input == "" then
        return
      end
      vim.cmd("DiffviewOpen " .. input .. " --imply-local")
    end, {})
  end,
  keys = {
    -- {
    --   "<leader>mr",
    --   -- function()
    --   --   local default = "main...HEAD"
    --   --   local input = vim.fn.input("Diffview range/rev: ", default)
    --   --   if input == nil or input == "" then
    --   --     return
    --   --   end
    --   --   vim.cmd("DiffviewOpen " .. input .. " --imply-local")
    --   -- end,
    --   "<cmd>diffview_open_prompt_imply_local<cr>",
    --   desc = "DiffviewOpen (prompt) --imply-local",
    -- },
    -- {
    --   "<leader>mr",
    --   function()
    --     local default = "main...HEAD"
    --     local input = vim.fn.input("Diffview range/rev: ", default)
    --     if not input or input == "" then
    --       return
    --     end
    --
    --     -- Capture current buffer as absolute, then convert to cwd-relative
    --     local abs = vim.fn.expand("%:p")
    --     local rel = vim.fn.fnamemodify(abs, ":.")  -- relative to current :pwd
    --
    --     vim.cmd("DiffviewOpen " .. input .. " --imply-local")
    --
    --     -- Re-open the working-tree file using cwd-relative path (helps clangd)
    --     if rel and rel ~= "" then
    --       vim.cmd("edit " .. vim.fn.fnameescape(rel))
    --     end
    --   end,
    --   desc = "DiffviewOpen (prompt) --imply-local (edit file relative to cwd)",
    -- },
  },
}
