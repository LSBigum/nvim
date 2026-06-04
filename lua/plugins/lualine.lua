return {
  'nvim-lualine/lualine.nvim',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'stevearc/overseer.nvim'
  },
  config = function()
    local overseer = require("overseer")
    require("lualine").setup({
      sections = {
        lualine_x = {
          {
            "overseer",
            label = "",
            colored = true,
            symbols = {
              [overseer.STATUS.RUNNING] = "󰑮 ",
              [overseer.STATUS.SUCCESS] = "✓ ",
              [overseer.STATUS.FAILURE] = "✗ ",
              [overseer.STATUS.CANCELED] = "⊘ ",
            },
          },
        },
      },
    })
  end
}
