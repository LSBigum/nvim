return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('harpoon'):setup()
  end,
  keys = {
    {
      '<leader>h',
      function()
        require('harpoon'):list():add()
      end,
      desc = "Add to [h]arpoon"
    },
    {
      '<C-f>',
      function()
        require('harpoon').ui:toggle_quick_menu(require('harpoon'):list())
      end,
      desc = "Open harpoon list"
    },
    {
      '<M-a>',
      function()
        require('harpoon'):list():select(1)
      end,
      mode = {'n', 'i'},
      desc = "Jump to harpoon 1",
    },
    {
      '<M-s>',
      function()
        require('harpoon'):list():select(2)
      end,
      mode = {'n', 'i'},
      desc = "Jump to harpoon 2",
    },
    {
      '<M-d>',
      function()
        require('harpoon'):list():select(3)
      end,
      mode = {'n', 'i'},
      desc = "Jump to harpoon 3",
    },
    {
      '<M-f>',
      function()
        require('harpoon'):list():select(4)
      end,
      mode = {'n', 'i'},
      desc = "Jump to harpoon 4",
    },
    {
      '<M-g>',
      function()
        require('harpoon'):list():select(5)
      end,
      mode = {'n', 'i'},
      desc = "Jump to harpoon 5",
    },
  }
}
