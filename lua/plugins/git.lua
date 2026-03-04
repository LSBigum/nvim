return {
  {
    "lewis6991/gitsigns.nvim",
    lazy = false,
    config = function()
      -- local icons = require('config.icons')
      require("gitsigns").setup({
        signs = {
          add = { text = "┃" },
          change = { text = "┃" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
          untracked = { text = "┆" },
        },
        signs_staged = {
          add = { text = "┃" },
          change = { text = "┃" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
          untracked = { text = "┆" },
        },
        signcolumn = true,
        numhl = false,
        linehl = false,
        word_diff = false,
        watch_gitdir = {
          interval = 1000,
          follow_files = true,
        },
        attach_to_untracked = true,
        current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
          delay = 1000,
          ignore_whitespace = false,
        },
        current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
        sign_priority = 6,
        status_formatter = nil,
        update_debounce = 200,
        max_file_length = 40000,
        preview_config = {
          border = "rounded",
          style = "minimal",
          relative = "cursor",
          row = 0,
          col = 1,
        },
        -- yadm = { enable = false },

        on_attach = function(bufnr)
          local gitsigns = require('gitsigns')

          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          -- Navigation
          map('n', ']]', function()
            if vim.wo.diff then
              vim.cmd.normal({']c', bang = true})
            else
              gitsigns.nav_hunk('next')
            end
          end,
            { desc = "Next git diff" })

          map('n', '[[', function()
            if vim.wo.diff then
              vim.cmd.normal({'[c', bang = true})
            else
              gitsigns.nav_hunk('prev')
            end
          end,
            { desc = "Previous git diff" })

          -- Actions
          map('n', '<leader>hs', gitsigns.stage_hunk, { desc = "[s]tage hunk" })
          map('n', '<leader>hr', gitsigns.reset_hunk, { desc = "[r]eset hunk" })

          map('v', '<leader>hs', function()
            gitsigns.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
          end, 
            { desc = "[s]tage hunk (visual mode)"})

          map('v', '<leader>hr', function()
            gitsigns.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
          end,
            { desc = "[r]eset hunk (visual mode)"})

          map('n', '<leader>hS', gitsigns.stage_buffer, { desc = "[S]tage buffer" })
          map('n', '<leader>hR', gitsigns.reset_buffer, { desc = "[R]eset buffer" })
          map('n', '<leader>hp', gitsigns.preview_hunk, { desc = "[p]review hunk" })
          map('n', '<leader>hi', gitsigns.preview_hunk_inline, { desc = "Preview hunk [i]nline" })

          map('n', '<leader>hb', function()
            gitsigns.blame_line({ full = true })
          end,
            { desc = "[b]lame line" })

          map('n', '<leader>hd', gitsigns.diffthis, { desc = "[d]iff this" })

          map('n', '<leader>hD', function()
            gitsigns.diffthis('~')
          end)

          map('n', '<leader>hQ', function() gitsigns.setqflist('all') end, { desc = "Add diffs to [Q]uicklist (all)" })
          map('n', '<leader>hq', gitsigns.setqflist, { desc = "Add diffs to [q]uicklist (buffer)" })

          -- Toggles
          map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = "Toggle [b]lame current line" })
          map('n', '<leader>tw', gitsigns.toggle_word_diff, { desc = "Toggle [w]ord diff" })

          -- Text object
          map({'o', 'x'}, 'ih', gitsigns.select_hunk, { desc = "Delete inside [h]unk"})
        end,
      })
    end,
  },
  -- {
  --   "sindrets/diffview.nvim",
  --   event = "VeryLazy",
  --   cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles" },
  -- },
  {
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
  },
  -- Git related plugins
  "tpope/vim-fugitive",
  "shumphrey/fugitive-gitlab.vim",
  "tpope/vim-rhubarb",

  -- not git, but it's okay
  {
    "mbbill/undotree",
    keys = {
      {
        "<leader>GU",
        ":UndotreeToggle<CR>",
        desc = "Toggle UndoTree",
      },
    },
  },
}
