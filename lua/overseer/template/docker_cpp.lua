local utils_docker = require("config.utils_docker")
local cwd = vim.fn.getcwd()
local profile = utils_docker.detect_profile(cwd)

-- helper to map container path -> host path
local function map_path(p)
  if type(p) ~= "string" then return p end
  for host, container in pairs(profile.path_map or {}) do
    -- Your map is host->container. We need the reverse (container->host).
    if vim.startswith(p, container) then
      return host .. p:sub(#container + 1)
    end
  end
  return p
end

return {
  name = "Build in container",
  desc = "Background build with path mapping",
  builder = function()
    return {
      cmd = { "docker", "exec" },
      args = {
        "-i",
        profile.container,
        "cmake", "--build", utils_docker.map_host_to_container(cwd, profile) .. "/build",
      },
      components = {
        "default",

        -- Parse gcc/clang style lines: file:line:col: <type>: message
        {
          "on_output_parse",
          parser = {
            diagnostics = {
              {
                "extract",
                { regex = true, append = false },
                [[\v^([^:\r\n]+):(\d+):(\d+):\s+(warning|error):\s+(.*)$]],
                "filename", "lnum", "col", "type", "text",
              },
              {
                "append",
                {
                  postprocess = function(item)
                    -- Some parsed items (rare) may be missing fields; guard them.
                    if item and item.filename then
                      item.filename = map_path(item.filename)
                    end
                  end,
                },
              },
            },
          },
        },

        { "on_result_diagnostics", open = true },
      },
    }
  end,
}

-- local utils_docker = require("config.utils_docker")
-- local cwd = vim.fn.getcwd()
-- local profile = utils_docker.detect_profile(cwd)
-- vim.notify("cwd: " .. cwd, vim.log.levels.INFO)
-- vim.notify(utils_docker.map_host_to_container(cwd, profile), vim.log.levels.INFO)
--
-- return {
--   name = "Build in container",
--   desc = "Background build with notification",
--   builder = function(params)
--     return {
--       cmd = { "docker", "exec" },
--       args = {
--         "-it",
--         profile.container,
--         "cmake",
--         "--build",
--         utils_docker.map_host_to_container(cwd, profile) .. "/build",
--       },
--       -- components = {
--       --   "default", -- usual logging, quickfix parsing, etc.
--       --   "on_complete_notify", -- show a notification when done
--       --   { "on_output_quickfix", open = true },
--       --   -- optionally "on_complete_dispose" to auto-remove finished tasks
--       -- },
--       components = {
--         "default", -- usual logging, quickfix parsing, etc.
--         "on_complete_notify", -- show a notification when done
--         { "on_output_quickfix", open = true },
--         {
--           "on_output_parse",
--           parser = {
--             {
--               "append",
--               {
--                 postprocess = function(item)
--                   -- vim.notify("parsing_output")
--                   for host, container in pairs(profile.path_map) do
--                     if item.filename:sub(1, #container) == container then
--                       item.filename = host .. item.filename:sub(#container + 1)
--                       vim.notify(item.filename)
--                     end
--                   end
--                 end,
--               },
--             },
--           },
--         },
--         "on_result_diagnostics",
--       },
--     }
--   end,
--   -- condition = {
--   --   filetype = { "cpp" },
--   --   callback = function()
--   --     if not profile then
--   --       return false
--   --     end
--   --     return utils_docker.is_container_running(profile.container)
--   --   end
--   -- },
-- }
--
-- Assumes: profile = { container = "...", path_map = { ["/home/nordbo/catkin_ws_20"] = "/home/nordbo_docker/catkin_ws", ... } }
