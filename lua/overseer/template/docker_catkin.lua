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
  name = "Catkin build in container",
  desc = "Background build with path mapping",
  builder = function()
    local cmd = { "docker", "exec" }
    local args = {
      "-i",
      "-w", "/home/nordbo_docker/catkin_ws",
      profile.container,
      "catkin", "build",
    }
    return {
      cmd = cmd,
      args = args,
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
