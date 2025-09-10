-- clangd.lua — host->container compile_commands_dir fix

local M = {}
local DEBUG = (vim.env.CLANGD_LUA_DEBUG == "1")
local function log(msg)
  if DEBUG then
    vim.notify("[clangd.lua] " .. msg)
  end
end
local cwd = vim.fn.getcwd()

-- utils ---------------------------------------------------------------------
local function path_join(a, b)
  return (a:sub(-1) == "/" and (a .. b) or (a .. "/" .. b))
end
local function file_exists(p)
  return vim.fn.filereadable(p) == 1
end
local function dir_exists(p) return vim.fn.isdirectory(p) == 1 end

local function is_container_running(name)
  local cmd = "docker ps --filter name=" .. name .. " --format '{{.Names}}' | grep -w " .. name .. " > /dev/null"
  return os.execute(cmd) == 0
end

-- workspace profiles ---------------------------------------------------------
-- NOTE: path_map is HOST_PREFIX -> CONTAINER_PREFIX
local workspace_profiles = {
  {
    match      = "(.+/catkin_ws_20)/src/hawk/([^/]+)",
    container  = "hawk20_compiler",
    clangd_bin = "clangd-18",
    path_map   = { ["/home/nordbo/catkin_ws_20"] = "/home/nordbo_docker/catkin_ws" },
  },
  {
    match      = "(.+/catkin_ws_20)/src/([^/]+)",
    container  = "hawk20_compiler",
    clangd_bin = "clangd-18",
    path_map   = { ["/home/nordbo/catkin_ws_20"] = "/home/nordbo_docker/catkin_ws" },
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

local function to_path_mappings(map)
  local parts = {}
  for host, cont in pairs(map or {}) do
    table.insert(parts, host .. "=" .. cont)
  end
  table.sort(parts)
  return table.concat(parts, ",")
end

local function map_host_to_container(host_path, map)
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

-- host-side compile_commands discovery --------------------------------------
local function prefer_compile_commands_dir(dir)
  if not dir or not dir_exists(dir) then
    return nil
  end
  local cc = path_join(dir, "compile_commands.json")
  if file_exists(cc) then
    return dir
  end
  return dir -- still helpful even if the json is generated later
end

local function find_host_compile_dir()
  -- All branches below return **host** paths only.

  -- 1) /…/catkin_ws_20/src/hawk/<proj> -> /…/catkin_ws_20/build/<proj>
  do
    local ws, proj = cwd:match("(.+/catkin_ws_20)/src/hawk/([^/]+)")
    if ws and proj then
      local dir = prefer_compile_commands_dir(path_join(path_join(ws, "build"), proj))
      if dir then
        log("host compile_commands_dir=" .. dir)
        return dir
      end
    end
  end

  -- 2) /…/catkin_ws_20/src/<proj> -> /…/catkin_ws_20/build/<proj>
  do
    local ws, proj = cwd:match("(.+/catkin_ws_20)/src/([^/]+)")
    if ws and proj then
      local dir = prefer_compile_commands_dir(path_join(path_join(ws, "build"), proj))
      if dir then
        log("host compile_commands_dir=" .. dir)
        return dir
      end
    end
  end

  -- 3) /…/catkin_ws_core/src/hawk-core/packages/<proj> -> /…/catkin_ws_core/build/<proj>
  do
    local ws, proj = cwd:match("(.+/catkin_ws_core)/src/hawk%-core/packages/([^/]+)")
    if ws and proj then
      local dir = prefer_compile_commands_dir(path_join(path_join(ws, "build"), proj))
      if dir then
        log("host compile_commands_dir=" .. dir)
        return dir
      end
    end
  end

  -- 4) /…/catkin_ws_test/src/hawk/<proj> -> /…/catkin_ws_test/build/<proj>
  do
    local ws, proj = cwd:match("(.+/catkin_ws_test)/src/hawk/([^/]+)")
    if ws and proj then
      local dir = prefer_compile_commands_dir(path_join(path_join(ws, "build"), proj))
      if dir then
        log("host compile_commands_dir=" .. dir)
        return dir
      end
    end
  end

  -- 5) Standard CMake build at project root
  do
    local dir = prefer_compile_commands_dir(path_join(cwd, "build"))
    if dir then
      log("host compile_commands_dir=" .. dir)
      return dir
    end
  end

  -- 6) Fallback to cwd
  log("host compile_commands_dir fallback to cwd=" .. cwd)
  return cwd
end

local function detect_profile()
  for _, prof in ipairs(workspace_profiles) do
    if cwd:match(prof.match) then
      return prof
    end
  end
  return nil
end

-- command assembly -----------------------------------------------------------
local function build_clangd_cmd()
  local host_cc_dir = find_host_compile_dir()
  local base_opts = {
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion-decorators",
    "--header-insertion=iwyu",
    "--pretty",
    "-j=8",
    "--log=verbose",
  }

  local prof = detect_profile()
  if prof and is_container_running(prof.container) then
    -- translate the verified HOST dir to the container path
    local cont_cc_dir = map_host_to_container(host_cc_dir, prof.path_map)
    local mappings = to_path_mappings(prof.path_map)
    local cmd = {
      "docker",
      "exec",
      "-i",
      prof.container,
      prof.clangd_bin,
      "--path-mappings=" .. mappings,
      "--compile-commands-dir=" .. cont_cc_dir,
    }
    vim.list_extend(cmd, base_opts)
    log("using docker: " .. table.concat(cmd, " "))
    return cmd
  else
    -- run on host with the host dir
    local cmd = vim.deepcopy(base_opts)
    table.insert(cmd, 1, "clangd")
    table.insert(cmd, "--compile-commands-dir=" .. host_cc_dir)
    log("using host: " .. table.concat(cmd, " "))
    return cmd
  end
end

local clangd_cmd = build_clangd_cmd()

-- root dir -------------------------------------------------------------------
local function clangd_root_dir(bufnr, cb)
  if cwd:match("(.+/catkin_ws_20)/src/[^/]+") then
    return cb(cwd)
  end
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local git_dir = vim.fs.find(".git", { path = fname, upward = true })[1]
  if git_dir then return cb(vim.fs.dirname(git_dir)) end
  return cb(cwd)
end

-- public LSP config ----------------------------------------------------------
M.config = {
  cmd = clangd_cmd,
  filetypes = { "c", "cpp" },
  root_dir = clangd_root_dir,
  root_markers = { "compile_commands.json", ".clang" },
  init_options = { clangdFileStatus = true },
  settings = {},
}

return M.config

