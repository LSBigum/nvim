return {
  name = "Build",
  desc = "Background build with notification",
  builder = function()
    return {
      cmd = { "cmake" },
      args = { "--build", "build" },
      components = {
        -- "default",           -- usual logging, quickfix parsing, etc.
        -- { "on_complete_notify", system = "always" }, -- show a notification when done
        -- { "open_output", on_complete = "failure", on_start = "never" },
        { "on_output_quickfix", open = true, set_diagnostics = true, items_only  = false },
        -- optionally "on_complete_dispose" to auto-remove finished tasks
      },
    }
  end,
}

