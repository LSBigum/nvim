return {
  'mfussenegger/nvim-dap',
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    'leoluz/nvim-dap-go',

    'theHamsta/nvim-dap-virtual-text',
  },
  keys = {
    -- Basic debugging keymaps, feel free to change to your liking!
    {
      '<leader>dc',
      function()
        require("dap").continue()
      end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<F7>',
      function()
        require("dap").continue()
      end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<leader>dsi',
      function()
        require("dap").step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<F8>',
      function()
        require("dap").step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<leader>dso',
      function()
        require("dap").step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<F9>',
      function()
        require("dap").step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<leader>dsb',
      function()
        require("dap").step_out()
      end,
      desc = 'Debug: Step Out ([B]ack)',
    },
    {
      '<F10>',
      function()
        require("dap").step_out()
      end,
      desc = 'Debug: Step Out ([B]ack)',
    },
    {
      '<leader>dq',
      function()
        require("dapui").close()
      end,
      desc = 'Debug: Close dap-ui',
    },
    {
      '<leader>dd',
      function()
        require("dap").toggle_breakpoint()
      end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>db',
      function()
        require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end,
      desc = 'Debug: Set conditional breakpoint',
    },
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    {
      '<leader>du',
      function()
        require("dapui").toggle()
      end,
      desc = 'Debug: See last session result.',
    },
    {
      '<leader>dz',
      function()
        require("dap").terminate()
      end,
      desc = 'Debug: Terminate.',
    },
    {
      '<leader>do',
      function()
        require("dapui").open()
      end,
      desc = 'Debug: Open dap-ui',
    },
    {
      "<leader>dw",
      function()
        require("dapui").eval(nil, { enter = false })
      end,
      desc = "Add word under cursor to Watches",
      mode = { "n", "v" },
    },
    {
      "<leader>dv",
      function()
        require("dapui").float_element("breakpoints")
      end,
      desc = "Debug: [v]iew breakpoints in floating window"
    },
    {
      "<leader>df",
      function()
        require("dap").focus_frame()
      end,
      desc = "Debug: [f]ocus on current frame"
    },
    { '<leader>dsu',
      function()
        require("dap").up()
      end ,
      desc = 'Debug: DAP Stack UP'
    },
    { '<leader>dsd',
      function()
        require("dap").down()
      end,
      desc = 'Debug: DAP Stack DOWN'
    },
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        'codelldb',
        'debugpy',
      },
    }

    -- This avoid unnecessary jumps
    dap.defaults.fallback.switchbuf = "usevisible,usetab,newtab"

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup({
      -- Set icons to characters that are more likely to work in every terminal.
      icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
      controls = { enabled = false }, -- no extra play/step buttons
      floating = { border = "rounded" },
      expand_lines = true,
      render = {
        max_type_length = 60,
        max_value_lines = 200,
      },
      element_mappings = {
        stacks = {
          open = "<CR>",
          expand = "o",
        }
      },
      layouts = {
        {
          elements = {
            {
              id = "watches",
              size = 0.50
            },
            {
              id = "console",
              size = 0.50
            },
          },
          position = "bottom",
          size = 10
        },
        {
          elements = {
            {
              id = "scopes",
              size = 0.50,
            },
            {
              id = "repl",
              size = 0.50,
            },
          },
          position = "bottom",
          size = 10
        },
        {
          elements = {
            {
              id = "stacks",
            },
          },
          position = "left",
          size = 3
        },
      },
    })

    -- Change breakpoint icons
    vim.api.nvim_set_hl(0, "DapBreak", { fg = "#e51400" })
    vim.api.nvim_set_hl(0, "DapStop", { fg = "#ffcc00" })
    local breakpoint_icons = vim.g.have_nerd_font and {
      Breakpoint = "",
      BreakpointCondition = "",
      BreakpointRejected = "",
      LogPoint = "",
      Stopped = "",
    } or { Breakpoint = "●", BreakpointCondition = "⊜", BreakpointRejected = "⊘", LogPoint = "◆", Stopped = "⭔" }
    for type, icon in pairs(breakpoint_icons) do
      local tp = "Dap" .. type
      local hl = (type == "Stopped") and "DapStop" or "DapBreak"
      vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    end

    dap.listeners.after.event_initialized["dapui_config"] = dapui.open
    dap.listeners.before.event_terminated["dapui_config"] = dapui.close
    dap.listeners.before.event_exited["dapui_config"] = dapui.close
    dap.listeners.after.event_stopped["bell_on_breakpoint"] = function(_, body)
      local reason = body and body.reason or nil
      if reason == "breakpoint"
        or reason == "function breakpoint"
        or reason == "instruction breakpoint"
        or reason == "data breakpoint" then
        vim.fn.chansend(vim.v.stderr, "\x07") -- Ring terminal bell
      end
    end

    dap.adapters.lldb = {
      type = "executable",
      command = vim.fn.exepath("lldb-dap-20"),
    }

    -- Name your running container here
    local CONTAINER = "hawk20_compiler"

    -- Helper: pick a PID from inside the container
    local function pick_container_process()
      -- list PIDs with command (customize ps columns if you like)
      local lines = vim.fn.systemlist(
        string.format([[docker exec %s sh -lc 'ps -eo pid,comm,args --no-headers']], CONTAINER)
      )
      if vim.v.shell_error ~= 0 or #lines == 0 then
        vim.notify("Could not list processes inside container " .. CONTAINER, vim.log.levels.ERROR)
        return nil
      end

      -- build choices: "1234  cmd  full args..."
      local choices = {}
      for _, l in ipairs(lines) do
        -- normalize whitespace; ensure PID is first field
        local pid, rest = l:match("^%s*(%d+)%s+(.+)$")
        if pid and rest then
          table.insert(choices, { pid = tonumber(pid), label = pid .. "  " .. rest })
        end
      end

      return coroutine.create(function(co)
        vim.ui.select(
          vim.tbl_map(function(it) return it.label end, choices),
          { prompt = "Select process (container):" },
          function(item)
            if not item then
              coroutine.resume(co, nil)
              return
            end
            -- map label back to pid
            for _, it in ipairs(choices) do
              if it.label == item then
                coroutine.resume(co, it.pid)
                return
              end
            end
            coroutine.resume(co, nil)
          end
        )
      end)
    end

    -- Debug adapter that runs inside the container
    dap.adapters.lldb_docker = {
      type = "executable",
      command = "docker",
      -- Use sh -lc so we can fall back between lldb-dap-20 and lldb-dap
      args = {
        "exec", "-i", CONTAINER, "sh", "-lc",
        [[command -v lldb-dap-20 >/dev/null 2>&1 && exec lldb-dap-20 || exec lldb-dap]]
      },
    }

    -- Path mapping: container -> host
    local source_map = {
      ["/home/nordbo_docker/catkin_ws"] = "/home/nordbo/catkin_ws_non_core",
      -- add more entries if needed
    }

    dap.configurations.cpp = {
      -- Attach to a running C++ process *inside the container*
      {
        name = "Attach (inside container)",
        type = "lldb_docker",
        request = "attach",
        pid = pick_container_process,     -- <— our custom picker
        sourceMap = source_map,           -- container → host mapping
        -- Optional quality-of-life:
        stopOnEntry = false,
        __sandbox = false,                -- keep lldb from sandboxing on some platforms
      },

      -- Launch an executable *inside the container*
      {
        name = "Docker launch",
        type = "lldb_docker",
        request = "launch",
        program = function()
          -- IMPORTANT: this path is *inside the container*.
          return vim.fn.input("Path to executable in container: ",
            "/home/nordbo_docker/catkin_ws/devel/lib/your_binary",
            "file"
          )
        end,
        args = function()
          local a = vim.fn.input("Program args (space-separated): ")
          return vim.split(vim.fn.trim(a), "%s+")
        end,
        cwd = function()
          -- Working directory *inside* the container. Adjust as needed.
          return vim.fn.input("Container working dir: ", "/home/nordbo_docker/catkin_ws", "dir")
        end,
        env = {},                         -- you can pass { KEY = "VALUE", ... } to the containered program
        stopOnEntry = false,
        sourceMap = source_map,           -- container → host mapping
        externalConsole = false,          -- use neovim console
      },
    }

        -- -- Install golang specific config
        -- require('dap-go').setup({
        --     dap_configurations = {
        --         {
        --             -- Must be "go" or it will be ignored by the plugin
        --             type = "go",
        --             name = "Attach remote",
        --             mode = "remote",
        --             request = "attach",
        --         },
        --         {
        --             type = "go",
        --             name = "Debug (Build Flags)",
        --             request = "launch",
        --             program = "${file}",
        --             buildFlags = require("dap-go").get_build_flags,
        --         },
        --         {
        --             type = "go",
        --             name = "Debug (Build Flags & Arguments)",
        --             request = "launch",
        --             program = "${file}",
        --             args = require("dap-go").get_arguments,
        --             buildFlags = require("dap-go").get_build_flags,
        --         },
        --     },
        --     delve = {
        --         -- using homebrew
        --         path = "/opt/homebrew/bin/dlv",
        --     }
        -- })
    require("nvim-dap-virtual-text").setup()
  end,
}
