local M = {}

function M.get_container_name()
  local cwd = vim.fn.getcwd()
  if string.find(cwd, 'hawk%-core') then
    return 'hawk-core-builder'
  end
  if string.find(cwd, 'catkin_ws_test') then
    return 'hawktest_compiler'
  end
  if string.find(cwd, 'catkin_ws_20') then
    return 'hawk20_compiler'
  end
  if string.find(cwd, 'catkin_ws_non_core') then
    return 'hawk20_compiler'
  end
end

function M.get_container_mappings(container)
  local cmd = 'docker inspect ' .. container .. ' | jq -r \'[.[0].Mounts[] | select(.Type=="bind") | "\\(.Source)=\\(.Destination)"] | join(",")\''
  return vim.fn.system(cmd)
end

-- workspace profiles ---------------------------------------------------------
-- NOTE: path_map is HOST_PREFIX -> CONTAINER_PREFIX
local workspace_profiles = {
  {
    match      = "(.+/catkin_ws_20)/src/hawk/([^/]+)",
    container  = "hawk20_compiler",
    -- clangd_bin = "clangd-18",
    clangd_bin = "/home/nordbo_docker/catkin_ws/clangd_21.1.0/bin/clangd",
    path_map   = { ["/home/nordbo/catkin_ws_20"] = "/home/nordbo_docker/catkin_ws" },
  },
  {
    match      = "(.+/catkin_ws_20)/src/([^/]+)",
    container  = "hawk20_compiler",
    clangd_bin = "clangd-18",
    path_map   = { ["/home/nordbo/catkin_ws_20"] = "/home/nordbo_docker/catkin_ws" },
  },
  {
    match      = "(.+/catkin_ws_non_core)/src/hawk%-non%-core/([^/]+)",
    container  = "hawk20_compiler",
    clangd_bin = "clangd-18",
    path_map   = { ["/home/nordbo/catkin_ws_non_core"] = "/home/nordbo_docker/catkin_ws" },
  },
  {
    match      = "(.+/catkin_ws_core)/src/hawk%-core/packages/([^/]+)",
    container  = "hawk-core-builder",
    clangd_bin = "clangd-18",
    path_map   = { ["/home/nordbo/catkin_ws_core"] = "/catkin_ws" },
  },
  {
    match      = "(.+/catkin_ws_test)/src/hawk/([^/]+)",
    container  = "hawktest_compiler",
    clangd_bin = "clangd-18",
    path_map   = { ["/home/nordbo/catkin_ws_test"] = "/home/nordbo_docker/catkin_ws" },
  },
  {
    match      = "(.+/external_projects)",
    container  = "hawktest_compiler",
    clangd_bin = "clangd-18",
    path_map   = { ["/home/nordbo"] = "/home/nordbo_docker" },
  },
}

function M.detect_profile(cwd)
  for _, prof in ipairs(workspace_profiles) do
    if cwd:match(prof.match) then
      return prof
    end
  end
  return nil
end

function M.is_container_running(name)
  if not name or name == '' then
    return false
  end
  local cmd = "docker ps --filter name=" .. name .. " --format '{{.Names}}' | grep -w " .. name .. " > /dev/null"
  return os.execute(cmd) == 0
end

function M.map_host_to_container(host_path, map)
  if not (host_path and map) then
    return host_path
  end
  -- choose the longest matching host prefix to avoid partial-prefix issues
  local best_host, best_cont, best_len = nil, nil, -1
  for h, c in pairs(map) do
    if host_path:sub(1, #h) == h and #h > best_len then
      best_host, best_cont, best_len = h, c, #h
    end
  end
  if not best_host then
    return host_path
  end
  local suffix = host_path:sub(best_len + 1)
  local cont_path = best_cont .. suffix
  return cont_path
end


return M
