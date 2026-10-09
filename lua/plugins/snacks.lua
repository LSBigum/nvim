local function explorer_format(item, picker)
  if not (picker.input and picker.input.filter.meta.searching) then
    return Snacks.picker.format.file(item, picker)
  end

  local formatters = picker.opts.formatters
  local proxy = setmetatable({
    opts = setmetatable({
      formatters = setmetatable({
        file = vim.tbl_extend("force", {}, formatters.file, {
          filename_first = true,
          filename_only = false,
        }),
      }, { __index = formatters }),
    }, { __index = picker.opts }),
  }, { __index = picker })

  return Snacks.picker.format.file(item, proxy)
end

local function capture_dapui_stacks_widths()
  local ok, windows = pcall(require, "dapui.windows")
  if not ok then
    return nil
  end

  local widths = {}

  for _, layout in ipairs(windows.layouts or {}) do
    local is_stacks_layout = false
    for _, win_state in ipairs(layout.win_states or {}) do
      if win_state.id == "stacks" then
        is_stacks_layout = true
        break
      end
    end

    if is_stacks_layout and layout.layout_type == "vertical" and layout.is_open and layout:is_open() then
      local ok_width, width = pcall(vim.api.nvim_win_get_width, layout.opened_wins[1])
      if ok_width and width > 0 then
        widths[layout] = width
      end
    end
  end

  return next(widths) and widths or nil
end

local function restore_dapui_stacks_widths(widths)
  if not widths then
    return
  end

  for layout, width in pairs(widths) do
    if layout.is_open and layout:is_open() then
      layout.area_state.size = width
      layout:resize()
    end
  end
end

local function explorer_is_open()
  return #Snacks.picker.get({ source = "explorer" }) > 0
end

local function is_file_buffer(buf)
  return vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
end

-- From the explorer (or another non-file window) the current buffer has no file,
-- so fall back to the only file shown in a window of this tab when that choice is unambiguous
local function file_to_reveal()
  if is_file_buffer(0) then
    return vim.api.nvim_buf_get_name(0)
  end

  -- Keyed by buffer so a file split across two windows counts once
  local files = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if is_file_buffer(buf) then
      files[buf] = vim.api.nvim_buf_get_name(buf)
    end
  end

  local buf, file = next(files)
  return buf and next(files, buf) == nil and file or nil
end

local function make_explorer_on_show(widths, after_show)
  if not widths and not after_show then
    return nil
  end

  return function(picker)
    if after_show then
      after_show(picker)
    end

    if widths then
      vim.schedule(function()
        restore_dapui_stacks_widths(widths)
      end)
    end
  end
end

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },
    dashboard = { enabled = true },
    explorer = { enabled = true },
    indent = { enabled = false },
    input = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    --@type snacks.config.picker
    picker = {
      layout = { preset = "vertical", },
      layouts = {
        vertical = {
          layout = {
            backdrop = false,
            width = 0.85,
            min_width = 80,
            height = 0.9,
            min_height = 30,
            box = "vertical",
            border = "rounded",
            title = "{title} {live} {flags}",
            title_pos = "center",
            { win = "input", height = 1, border = "bottom" },
            { win = "list", border = "none" },
            { win = "preview", title = "{preview}", height = 0.6, border = "top" },
          },
        },
      },
      enabled = true,
      sources = {
        explorer = {
          hidden = true,
          follow_file = false,
          format = explorer_format,
          win = {
            list = {
              wo = {
                number = true, relativenumber = true,
              },
            },
          },
        },
      },
      ---@class snacks.picker.files.Config: snacks.picker.proc.Config
      files = { hidden = true },
      ---@class snacks.picker.grep.Config: snacks.picker.proc.Config
      grep = { hidden = true },
      show_empty = true,
      win = {
        -- input window
        input = {
          keys = {
            ["<M-H>"] = { "toggle_hidden", mode = { "n", "i" } },
            ["<M-I>"] = { "toggle_ignored", mode = { "n", "i" } },
            ["<M-R>"] = { "toggle_regex", mode = { "n" } },
            ["<M-K>"] = { "focus_preview", mode = { "i", "n" } },
            ["<M-J>"] = { "focus_list", mode = { "i", "n" } },
            ["<C-M-k>"] = { "focus_preview", mode = { "i", "n" } },
            ["<C-M-j>"] = { "focus_list", mode = { "i", "n" } },
            ["<C-M-u>"] = { "preview_scroll_up", mode = { "i", "n" } },
            ["<C-M-d>"] = { "preview_scroll_down", mode = { "i", "n" } },
            ["<C-u>"] = { "list_scroll_up", mode = { "n" } }, -- only normal mode
            ["<C-d>"] = { "list_scroll_down", mode = { "n" } }, -- only normal mode
          },
        },
        -- result list window
        list = {
          keys = {
            ["<M-H>"] = { "toggle_hidden", mode = { "n", "i" } },
            ["<M-I>"] = { "toggle_ignored", mode = { "n", "i" } },
            ["<M-K>"] = { "focus_input", mode = { "i", "n" } },
            ["<M-J>"] = { "focus_preview", mode = { "i", "n" } },
            ["<C-M-k>"] = { "focus_input", mode = { "i", "n" } },
            ["<C-M-j>"] = { "focus_preview", mode = { "i", "n" } },
            ["<C-M-u>"] = { "preview_scroll_up", mode = { "i", "n" } },
            ["<C-M-d>"] = { "preview_scroll_down", mode = { "i", "n" } },
          },
        },
        preview = {
          keys = {
            ["<M-K>"] = { "focus_list", mode = { "i", "n" } },
            ["<M-J>"] = { "focus_input", mode = { "i", "n" } },
            ["<C-M-k>"] = { "focus_list", mode = { "i", "n" } },
            ["<C-M-j>"] = { "focus_input", mode = { "i", "n" } },
            ["<C-j>"] = { { "focus_list", "list_down" }, mode = { "i", "n" } },
            ["<C-k>"] = { { "focus_list", "list_up" }, mode = { "i", "n" } },
          }
        }
      },
    },
    quickfile = { enabled = true },
    root = { auto = true, },
    scope = { enabled = true },
    scroll = { enabled = false },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    ---@class snacks.zen.Config
    zen = {
      ---@type table<string, boolean>
      toggles = {
        dim = false,
        gitsigns = true,
      },
    },
    styles = {
      zen = {
        width = 200,
        backdrop = {
          transparent = false,
          blend = 80
        },
      },
      notification = {
        -- wo = { wrap = true } -- Wrap notifications
      },
    },
  },
  keys = {
    -- Top Pickers & Explorer
    {
      "<leader>/",
      function()
        Snacks.picker.grep({ cwd = vim.fn.getcwd() })
      end,
      desc = "Grep (cwd)",
    },
    {
      "<C-s>",
      function()
        Snacks.picker.grep_buffers()
      end,
      desc = "Grep Open Buffers",
    },
    {
      "<leader>sw",
      function()
        Snacks.picker.grep_word({ cwd = vim.fn.getcwd() })
      end,
      desc = "Visual selection or word",
      mode = { "n", "x" },
    },
    {
      "<leader>:",
      function()
        Snacks.picker.command_history()
      end,
      desc = "Command History",
    },
    {
      "<leader>e",
      function()
        local widths = explorer_is_open() and nil or capture_dapui_stacks_widths()
        local on_show = make_explorer_on_show(widths)
        Snacks.explorer(on_show and { on_show = on_show } or nil)
      end,
      desc = "File Explorer",
    },
    {
      "<leader>se",
      function()
        -- Capture the file before opening: inside on_show the current buffer is the explorer's
        local file = file_to_reveal()

        if explorer_is_open() then
          if file then
            Snacks.explorer.reveal({ file = file })
          else
            Snacks.notify.warn("No single file buffer to reveal")
          end
          return
        end

        local widths = capture_dapui_stacks_widths()
        Snacks.explorer({
          on_show = make_explorer_on_show(widths, function()
            if file then
              Snacks.explorer.reveal({ file = file })
            end
          end),
        })
      end,
      desc = "Reveal Current File in Explorer",
    },
    -- find
    {
      "<leader>sB",
      function()
        Snacks.picker.buffers({
          win = {
            input = {
              keys = {
                ["dd"] = "bufdelete",
              },
            },
            list = { keys = { ["dd"] = "bufdelete" } },
          },
        })
      end,
      desc = "Buffers",
    },
    {
      "<leader>fc",
      function()
        Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
      end,
      desc = "Find Config File",
    },
    {
      "<leader>fg",
      function()
        Snacks.picker.git_files()
      end,
      desc = "Find Git Files",
    },
    {
      "<leader>fp",
      function()
        Snacks.picker.projects()
      end,
      desc = "Projects",
    },
    {
      "<leader>fr",
      function()
        Snacks.picker.recent()
      end,
      desc = "Recent",
    },
    {
      "<leader>ffa",
      function()
        local root = vim.fn.getcwd()

        root = vim.fs.normalize(root)

        Snacks.picker.lsp_workspace_symbols({
          cwd = root,
          tree = false,
          live = true,

          filter = {
            default = { "Function", "Method", "Constructor" },
          },

          transform = function(item)
            if not item.file then
              return item
            end

            local file = vim.fs.normalize(item.file)

            -- Only keep symbols physically inside this codebase.
            if file ~= root and not vim.startswith(file, root .. "/") then
              return false
            end

            return item
          end,
        })
      end,
      desc = "Search [a]ll workspace functions",
    },
    {
      "<leader>ffl",
      function()
        Snacks.picker.lsp_symbols({
          filter = {
            default = { "Function", "Method", "Constructor" },
          },
          tree = false,
        })
      end,
      desc = "Search [l]ocal functions in buffer"
    },

    -- git
    {
      "<leader>gb",
      function()
        Snacks.picker.git_branches()
      end,
      desc = "Git Branches",
    },
    {
      "<leader>gl",
      function()
        Snacks.picker.git_log()
      end,
      desc = "Git Log",
    },
    {
      "<leader>gL",
      function()
        Snacks.picker.git_log_line()
      end,
      desc = "Git Log Line",
    },
    {
      "<leader>gs",
      function()
        Snacks.picker.git_status()
      end,
      desc = "Git Status",
    },
    {
      "<leader>gS",
      function()
        Snacks.picker.git_stash()
      end,
      desc = "Git Stash",
    },
    {
      "<leader>gdd",
      function()
        Snacks.picker.git_diff()
      end,
      desc = "Git Diff (Hunks)",
    },
    {
      "<leader>gF",
      function()
        Snacks.picker.git_log_file()
      end,
      desc = "Git Log File",
    },
    -- search
    {
      '<leader>s"',
      function()
        Snacks.picker.registers()
      end,
      desc = "Registers",
    },
    {
      "<leader>s/",
      function()
        Snacks.picker.search_history()
      end,
      desc = "Search History",
    },
    {
      "<leader>sa",
      function()
        Snacks.picker.autocmds()
      end,
      desc = "Autocmds",
    },
    {
      "<leader>sb",
      function()
        Snacks.picker.lines()
      end,
      desc = "Buffer Lines",
    },
    {
      "<leader>sc",
      function()
        Snacks.picker.command_history()
      end,
      desc = "Command History",
    },
    {
      "<leader>sC",
      function()
        Snacks.picker.commands()
      end,
      desc = "Commands",
    },
    {
      "<leader>sd",
      function()
        Snacks.picker.diagnostics()
      end,
      desc = "Diagnostics",
    },
    {
      "<leader>sD",
      function()
        Snacks.picker.diagnostics_buffer()
      end,
      desc = "Buffer Diagnostics",
    },
    {
      "<leader>sh",
      function()
        Snacks.picker.help()
      end,
      desc = "Help Pages",
    },
    {
      "<leader>sH",
      function()
        Snacks.picker.highlights()
      end,
      desc = "Highlights",
    },
    {
      "<leader>si",
      function()
        Snacks.picker.icons()
      end,
      desc = "Icons",
    },
    {
      "<leader>sj",
      function()
        Snacks.picker.jumps()
      end,
      desc = "Jumps",
    },
    {
      "<leader>sk",
      function()
        Snacks.picker.keymaps()
      end,
      desc = "Keymaps",
    },
    {
      "<leader>sl",
      function()
        Snacks.picker.loclist()
      end,
      desc = "Location List",
    },
    {
      "<leader>sm",
      function()
        Snacks.picker.marks()
      end,
      desc = "Marks",
    },
    {
      "<leader>sM",
      function()
        Snacks.picker.man()
      end,
      desc = "Man Pages",
    },
    {
      "<leader>sp",
      function()
        Snacks.picker.lazy()
      end,
      desc = "Search for Plugin Spec",
    },
    {
      "<leader>sq",
      function()
        Snacks.picker.qflist()
      end,
      desc = "Quickfix List",
    },
    {
      "<leader>sr",
      function()
        Snacks.picker.resume()
      end,
      desc = "Resume",
    },
    {
      "<leader>su",
      function()
        Snacks.picker.undo()
      end,
      desc = "Undo History",
    },
    {
      "<leader>uC",
      function()
        Snacks.picker.colorschemes()
      end,
      desc = "Colorschemes",
    },
    -- LSP
    {
      "gd",
      function()
        Snacks.picker.lsp_definitions()
      end,
      desc = "Goto Definition",
    },
    {
      "gD",
      function()
        Snacks.picker.lsp_declarations()
      end,
      desc = "Goto Declaration",
    },
    {
      "gr",
      function()
        Snacks.picker.lsp_references()
      end,
      nowait = true,
      desc = "References",
    },
    {
      "gI",
      function()
        Snacks.picker.lsp_implementations()
      end,
      desc = "Goto Implementation",
    },
    {
      "gy",
      function()
        Snacks.picker.lsp_type_definitions()
      end,
      desc = "Goto T[y]pe Definition",
    },
    {
      "<leader>p",
      function()
        Snacks.picker.lsp_symbols()
      end,
      desc = "LSP Symbols",
    },
    {
      "<leader>WS",
      function()
        Snacks.picker.lsp_workspace_symbols()
      end,
      desc = "LSP Workspace Symbols",
    },
    -- Other
    {
      "<leader>z",
      function()
        Snacks.zen()
      end,
      desc = "Toggle Zen Mode",
    },
    {
      "<leader>Z",
      function()
        Snacks.zen.zoom()
      end,
      desc = "Toggle Zoom",
    },
    {
      "<leader>.",
      function()
        Snacks.scratch()
      end,
      desc = "Toggle Scratch Buffer",
    },
    {
      "<leader>S",
      function()
        Snacks.scratch.select()
      end,
      desc = "Select Scratch Buffer",
    },
    {
      "<leader>n",
      function()
        Snacks.notifier.show_history()
      end,
      desc = "Notification History",
    },
    {
      "Q",
      function()
        Snacks.bufdelete()
      end,
      desc = "Delete Buffer",
    },
    {
      "<leader>gB",
      function()
        Snacks.gitbrowse()
      end,
      desc = "Git Browse",
      mode = { "n", "v" },
    },
    {
      "<leader>uN",
      function()
        Snacks.notifier.hide()
      end,
      desc = "Dismiss All Notifications",
    },
    {
      "<c-/>",
      function()
        Snacks.terminal()
      end,
      desc = "Toggle Terminal",
    },
    {
      "<c-_>",
      function()
        Snacks.terminal()
      end,
      desc = "which_key_ignore",
    },
    {
      "<leader>N",
      desc = "Neovim News",
      function()
        Snacks.win({
          file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
          width = 0.6,
          height = 0.6,
          wo = {
            spell = false,
            wrap = false,
            signcolumn = "yes",
            statuscolumn = " ",
            conceallevel = 3,
          },
        })
      end,
    },
    { "gai", function() Snacks.picker.lsp_incoming_calls() end, desc = "Calls [I]ncoming" },
    { "gao", function() Snacks.picker.lsp_outgoing_calls() end, desc = "Calls [O]utgoing" },
  },
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        -- Setup some globals for debugging (lazy-loaded)
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end
        vim.print = _G.dd -- Override print to use snacks for `:=` command

        -- Create some toggle mappings
        Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
        Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
        Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
        Snacks.toggle.diagnostics():map("<leader>ud")
        Snacks.toggle.line_number():map("<leader>ul")
        Snacks.toggle
            .option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
            :map("<leader>uc")
        Snacks.toggle.treesitter():map("<leader>uT")
        Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
        Snacks.toggle.inlay_hints():map("<leader>uh")
        Snacks.toggle.indent():map("<leader>ug")
        Snacks.toggle.dim():map("<leader>uD")
      end,
    })
  end,
}
