return {
  "harrisoncramer/gitlab.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim",
    "stevearc/dressing.nvim", -- Recommended but not required. Better UI for pickers.
    "nvim-tree/nvim-web-devicons", -- Recommended but not required. Icons in discussion tree.
  },
  build = function () require("gitlab.server").build(true) end, -- Builds the Go binary
  config = function()
    -- require("diffview")
    require("gitlab").setup({
      debug = {
        go_request = true,
        go_response = true,
        gitlab_request = true,
        gitlab_response = true,
      },
    })
  end,
}
