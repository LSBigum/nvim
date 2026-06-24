return {
  'nvim-lualine/lualine.nvim',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'stevearc/overseer.nvim'
  },
  config = function()
    local overseer = require("overseer")

    vim.api.nvim_set_hl(0, "LualineMacroRecording", { fg = "#ff5f5f", bold = true })

    vim.api.nvim_set_hl(0, "LualineMacroRecordingPending", { fg = "#ff5f5f", bold = true })

    local function macro_recording()
      local register = vim.g.macro_recording_register or ""
      if register == "" then
        return ""
      end

      return "● REC @" .. register
    end

    require("lualine").setup({
      sections = {
        lualine_x = {
          {
            "%S",
            color = "LualineMacroRecordingPending",
            fmt = function(showcmd)
              if showcmd == "q" then
                return "● REC"
              end

              return showcmd
            end,
          },
          {
            macro_recording,
            color = "LualineMacroRecording",
          },
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

    local group = vim.api.nvim_create_augroup("lualine_macro_recording", { clear = true })
    vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
      group = group,
      callback = function(args)
        if args.event == "RecordingEnter" then
          vim.g.macro_recording_register = vim.fn.reg_recording()
        else
          vim.g.macro_recording_register = ""
        end

        vim.schedule(function()
          require("lualine").refresh({ place = { "statusline" } })
        end)
      end,
    })
  end
}
