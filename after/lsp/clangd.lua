-- clangd.lua — host->container compile_commands_dir fix
local utils_docker = require('config.utils_docker')

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

local function to_path_mappings(map)
  local parts = {}
  for host, cont in pairs(map or {}) do
    table.insert(parts, host .. "=" .. cont)
  end
  table.sort(parts)
  return table.concat(parts, ",")
end

local function find_nearest_package_name(start_path)
  local pkg_xml = vim.fs.find("package.xml", {
    path = start_path,
    upward = true,
    stop = vim.loop.os_homedir(),
  })[1]

  if not pkg_xml then
    return nil, nil
  end

  local pkg_dir = vim.fs.dirname(pkg_xml)
  local pkg_name = vim.fs.basename(pkg_dir)
  return pkg_name, pkg_dir
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
  -- First try catkin workspaces by locating the nearest package.xml and
  -- using its parent directory name as the package name.

  do
    local ws = cwd:match("(.+/catkin_ws_20)")
    if ws then
      local pkg_name = find_nearest_package_name(cwd)
      if pkg_name then
        local dir = prefer_compile_commands_dir(path_join(path_join(ws, "build"), string.lower(pkg_name)))
        if dir then
          log("host compile_commands_dir=" .. dir)
          return dir
        end
        log("Could not find " .. path_join(path_join(ws, "build"), pkg_name))
      end
    end
  end

  do
    local ws = cwd:match("(.+/catkin_ws_non_core)")
    if ws then
      local pkg_name = find_nearest_package_name(cwd)
      if pkg_name then
        local dir = prefer_compile_commands_dir(path_join(path_join(ws, "build"), string.lower(pkg_name)))
        if dir then
          log("host compile_commands_dir=" .. dir)
          return dir
        end
        log("Could not find " .. path_join(path_join(ws, "build"), pkg_name))
      end
    end
  end

  do
    local ws = cwd:match("(.+/catkin_ws_core)")
    if ws then
      local pkg_name = find_nearest_package_name(cwd)
      if pkg_name then
        local dir = prefer_compile_commands_dir(path_join(path_join(ws, "build"), string.lower(pkg_name)))
        if dir then
          log("host compile_commands_dir=" .. dir)
          return dir
        end
        log("Could not find " .. path_join(path_join(ws, "build"), pkg_name))
      end
    end
  end

  do
    local ws = cwd:match("(.+/catkin_ws_test)")
    if ws then
      local pkg_name = find_nearest_package_name(cwd)
      if pkg_name then
        local dir = prefer_compile_commands_dir(path_join(path_join(ws, "build"), string.lower(pkg_name)))
        if dir then
          log("host compile_commands_dir=" .. dir)
          return dir
        end
        log("Could not find " .. path_join(path_join(ws, "build"), pkg_name))
      end
    end
  end

  do
    local ws, proj = cwd:match("(.+/external_projects)/([^/]+)")
    if ws and proj then
      local dir = prefer_compile_commands_dir(path_join(path_join(ws, "build"), proj))
      if dir then
        log("host compile_commands_dir=" .. dir)
        return dir
      end
      log("Could not find " .. path_join(path_join(ws, "build"), proj))
    end
  end

  -- Standard CMake build at project root
  do
    local dir = prefer_compile_commands_dir(path_join(cwd, "build"))
    if dir then
      log("host compile_commands_dir=" .. dir)
      return dir
    end
  end

  -- Fallback to cwd
  log("host compile_commands_dir fallback to cwd=" .. cwd)
  return cwd
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
    "--query-driver=/usr/bin/c++",
    -- "--log=verbose",
  }

  local profile = utils_docker.detect_profile(cwd)
  if profile and utils_docker.is_container_running(profile.container) then
    -- translate the verified HOST dir to the container path
    local cont_cc_dir = utils_docker.map_host_to_container(host_cc_dir, profile.path_map)
    local mappings = to_path_mappings(profile.path_map)
    local cmd = {
      "docker",
      "exec",
      "-i",
      profile.container,
      profile.clangd_bin,
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

-- root dir -------------------------------------------------------------------

-- local function clangd_root_dir(bufnr, cb)
--   if cwd:match("(.+/catkin_ws_20)/src/[^/]+") then
--     return cb(cwd)
--   end
--   local fname = vim.api.nvim_buf_get_name(bufnr)
--   local contains_build_dir = vim.fs.find("build", { path = fname, upward = true })[1]
--   if contains_build_dir then
--     log("root_dir = contains_build_dir: " .. vim.fs.dirname(contains_build_dir))
--   return cb(vim.fs.dirname(contains_build_dir))
--   end
--   local git_dir = vim.fs.find(".git", { path = fname, upward = true })[1]
--   if git_dir then
--     log("root_dir = git_dir: " .. vim.fs.dirname(git_dir))
--     return cb(vim.fs.dirname(git_dir))
--   end
--   return cb(cwd)
-- end

-- public LSP config ----------------------------------------------------------
M.config = {
  cmd = build_clangd_cmd(),
  filetypes = { "c", "cpp" },
  -- root_dir = clangd_root_dir,
  root_markers = { "compile_commands.json", ".clang", "package.xml", ".git" },
  init_options = { clangdFileStatus = true },
  settings = {},
}
-- log("using root_dir: " .. table.concat(M.config))

return M.config

