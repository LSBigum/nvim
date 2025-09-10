-- return {}
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
      '<leader>dsi',
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
      '<leader>dsb',
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
      '<leader>db',
      function()
        require("dap").toggle_breakpoint()
      end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>dB',
      function()
        require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end,
      desc = 'Debug: Set Breakpoint',
    },
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    {
      '<leader>dt',
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
      desc = 'Debug: See last session result.',
    },
    {
      '<leader>do',
      function()
        require("dapui").open()
      end,
      desc = 'Debug: Open dap-ui',
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
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
      controls = {
        icons = {
          pause = "⏸",
          play = "▶",
          step_into = "⏎",
          step_over = "⏭",
          step_out = "⏮",
          step_back = "b",
          run_last = "▶▶",
          terminate = "⏹",
          disconnect = "⏏",
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

    dap.adapters.lldb = {
      type = "executable",
      command = vim.fn.exepath("lldb-dap-18"),
    }

    -- dap.adapters.lldb_docker = {
    --   type = "executable",
    --   command = "docker",
    --   args = { "exec", "-i", "hawktest_compiler", "bash", "-c", "lldb-dap-18" },
    -- }
    --
    -- dap.configurations.cpp = {
    --   {
    --     name = "C++ attach",
    --     type = "lldb_docker",
    --     request = "attach",
    --     pid = require("dap.utils").pick_process,
    --     -- program = require('dap.utils').pick_file(),
    --     sourceMap = {
    --       { "/home/nordbo_docker/catkin_ws", "/home/nordbo/catkin_ws_test" },
    --     },
    --   },
    --   {
    --     name = "C++ docker launch",
    --     type = "lldb_docker",
    --     request = "launch",
    --     program = function()
    --     -- require('dap.utils').pick_file,
    --     end,
    --     sourceMap = {
    --       { "/home/nordbo_docker/catkin_ws", "/home/nordbo/catkin_ws_test" },
    --     },
    --   },
    -- }

    local dap = require("dap")

    -- Name your running container here
    local CONTAINER = "hawktest_compiler"

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
      -- Use sh -lc so we can fall back between lldb-dap-18 and lldb-dap
      args = {
        "exec", "-i", CONTAINER, "sh", "-lc",
        -- Prefer 18, fall back to plain lldb-dap if that binary name differs
        [[command -v lldb-dap-18 >/dev/null 2>&1 && exec lldb-dap-18 || exec lldb-dap]]
      },
    }

    -- Path mapping: container -> host
    local source_map = {
      ["/home/nordbo_docker/catkin_ws"] = "/home/nordbo/catkin_ws_test",
      -- add more entries if needed
    }

    dap.configurations.cpp = {
      -- Attach to a running C++ process *inside the container*
      {
        name = "C++ attach (inside container)",
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
        name = "C++ docker launch",
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
  end,
}
