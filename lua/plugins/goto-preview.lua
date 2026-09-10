-- A preview float displays the target file's real buffer, so buffer-local maps set
-- here are also live when that file is open in an ordinary window. Every map must
-- check that the current window is a preview float and otherwise do what the key
-- normally does.
local function close_preview_or(fallback)
  return function()
    local win = vim.api.nvim_get_current_win()
    local ok, is_preview = pcall(vim.api.nvim_win_get_var, win, "is-goto-preview-window")
    if ok and is_preview == 1 then
      require("goto-preview").dismiss_preview(win)
    else
      fallback()
    end
  end
end

return {
  "rmagatti/goto-preview",
  opts = {
    width = 120,
    height = 25,
    border = "rounded",
    default_mappings = false,
    dismiss_on_move = false,
    references = { provider = "snacks" },
    post_open_hook = function(buffer, _)
      local map_opts = { buffer = buffer, nowait = true, desc = "Close Preview Window" }
      vim.keymap.set("n", "q", close_preview_or(function()
        vim.api.nvim_feedkeys("q", "ni", false)
      end), map_opts)
      -- Mirrors the global <Esc> map in lua/config/keymaps.lua
      vim.keymap.set("n", "<Esc>", close_preview_or(vim.cmd.nohlsearch), map_opts)
    end,
  },
  keys = {
    {
      "gpd",
      function()
        require("goto-preview").goto_preview_definition()
      end,
      desc = "Preview Definition",
    },
    {
      "gpy",
      function()
        require("goto-preview").goto_preview_type_definition()
      end,
      desc = "Preview T[y]pe Definition",
    },
    {
      "gpi",
      function()
        require("goto-preview").goto_preview_implementation()
      end,
      desc = "Preview Implementation",
    },
    {
      "gpD",
      function()
        require("goto-preview").goto_preview_declaration()
      end,
      desc = "Preview Declaration",
    },
    {
      "gpr",
      function()
        require("goto-preview").goto_preview_references()
      end,
      desc = "Preview References",
    },
    {
      "gpc",
      function()
        require("goto-preview").close_all_win()
      end,
      desc = "Close All Preview Windows",
    },
  },
}
