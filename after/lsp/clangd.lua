-- clangd.lua — host->container compile_commands_dir fix
local utils_docker = require('config.utils_docker')

local M = {}
local DEBUG = (vim.env.CLANGD_LUA_DEBUG == "1")
local function log(msg)
  if DEBUG then
    vim.notify("[clangd.lua] " .. msg)
  end
end

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
    stop = vim.uv.os_homedir(),
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

-- Known catkin workspace directory names, checked in order. Each is matched
-- against the LSP root; the nearest package.xml's parent dir name becomes the
-- package name used to locate that workspace's per-package build dir.
local CATKIN_WORKSPACES = { "catkin_ws_20", "catkin_ws_non_core", "catkin_ws_core", "catkin_ws_test" }

local function find_catkin_compile_dir(root)
  for _, name in ipairs(CATKIN_WORKSPACES) do
    local ws = root:match("(.+/" .. name .. ")")
    if ws then
      local pkg_name = find_nearest_package_name(root)
      if pkg_name then
        local build_dir = path_join(path_join(ws, "build"), string.lower(pkg_name))
        local dir = prefer_compile_commands_dir(build_dir)
        if dir then
          log("host compile_commands_dir=" .. dir)
          return dir
        end
        log("Could not find " .. build_dir)
      end
      return nil
    end
  end
  return nil
end

-- `root` is the LSP root directory of the buffer being attached (see
-- root_markers below), not the editor's cwd: one nvim session can hold buffers
-- from Mimic and from a dependency checkout, and each needs its own answer.
local function find_host_compile_dir(mimic_profile, root)
  if mimic_profile then
    local dir = prefer_compile_commands_dir(mimic_profile.build_dir)
    if dir then
      log("Mimic compile_commands_dir=" .. dir)
      return dir
    end
  end

  local catkin_dir = find_catkin_compile_dir(root)
  if catkin_dir then
    return catkin_dir
  end

  do
    local ws, proj = root:match("(.+/external_projects)/([^/]+)")
    if ws and proj then
      local dir = prefer_compile_commands_dir(path_join(path_join(ws, "build"), proj))
      if dir then
        log("host compile_commands_dir=" .. dir)
        return dir
      end
      log("Could not find " .. path_join(path_join(ws, "build"), proj))
    end
  end

  -- Internal-dependency repos (RobWork, LCore, ...) built inside a mounted
  -- mimic-dev container use this fixed name by convention — see
  -- docker-compose.override.yml.example in the Mimic repo. Checked before the
  -- generic "build/<project>" fallback below since that one would never match
  -- it. host_cc_dir still has to be the *host* path here even on the docker
  -- branch below: map_host_to_container() translates it into the container's
  -- --compile-commands-dir from it.
  do
    local dir = prefer_compile_commands_dir(path_join(root, "build-docker"))
    if dir then
      log("host compile_commands_dir=" .. dir)
      return dir
    end
  end

  -- Standard CMake build at project root
  do
    -- Search parent directories for a build directory
    local build_dir = vim.fn.finddir('build', root .. ";")
    local project_name = vim.fn.fnamemodify(vim.trim(root), ":t")
    local project_build_dir = prefer_compile_commands_dir(path_join(build_dir, project_name))
    if (project_build_dir and dir_exists(project_build_dir)) then
      build_dir = project_build_dir
    end
    if build_dir and dir_exists(build_dir) then
      log("host compile_commands_dir=" .. build_dir)
      return build_dir
    end
  end

  -- Fallback to the root itself
  log("host compile_commands_dir fallback to root=" .. root)
  return root
end
-- command assembly -----------------------------------------------------------
local function build_clangd_cmd(root)
  local mimic_profile = utils_docker.get_mimic_profile(root)
  local host_cc_dir = find_host_compile_dir(mimic_profile, root)
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

  if mimic_profile then
    -- The Incus launcher when this worktree has one and its Docker container is
    -- not running. It needs no path mappings for the repo: paths are the same
    -- inside the container as outside.
    local incus_launcher = path_join(mimic_profile.root, "incus/clangd.sh")
    local launcher = path_join(mimic_profile.root, "docker/mimic-clangd.sh")
    if not mimic_profile.container and file_exists(incus_launcher) then
      launcher = incus_launcher
    end
    local cmd = { launcher }
    vim.list_extend(cmd, base_opts)
    log("using Mimic launcher: " .. table.concat(cmd, " "))
    return cmd
  end

  local profile = utils_docker.detect_profile(root)
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
  end

  local incus_profile = utils_docker.find_incus_dependency_profile(root)
  if incus_profile and file_exists(incus_profile.launcher) then
    -- The launcher passes the Mimic worktree's own --compile-commands-dir first;
    -- clangd keeps the last one given, so this one wins.
    local cmd = { incus_profile.launcher, "--compile-commands-dir=" .. incus_profile.build_dir }
    vim.list_extend(cmd, base_opts)
    log("using incus: " .. table.concat(cmd, " "))
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

-- :ClangdContainer — pick which running mimic-* container serves the current
-- buffer's repo (when several worktrees mount it), then restart clangd for it.
vim.api.nvim_create_user_command("ClangdContainer", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = "clangd" })[1]
  local root = client and client.config.root_dir or vim.fn.expand("%:p:h")
  utils_docker.choose_container(root, function(choice)
    if not choice then
      return
    end
    for _, running in ipairs(vim.lsp.get_clients({ name = "clangd" })) do
      if running.config.root_dir == root then
        vim.lsp.stop_client(running.id)
      end
    end
    vim.defer_fn(function()
      vim.cmd("edit")
    end, 100)
  end)
end, { desc = "Choose the mimic-dev container clangd runs in for this repo" })

-- public LSP config ----------------------------------------------------------
M.config = {
  -- A function rather than a fixed list: nvim calls it once per client, after
  -- resolving root_dir, so a Mimic buffer and an lcore buffer in the same
  -- session each get a clangd aimed at their own container and compile db.
  cmd = function(dispatchers, config)
    local cmd = build_clangd_cmd(config.root_dir or vim.fn.getcwd())
    return vim.lsp.rpc.start(cmd, dispatchers, {
      cwd = config.cmd_cwd,
      env = config.cmd_env,
      detached = config.detached,
    })
  end,
  filetypes = { "c", "cpp" },
  root_markers = { "compile_commands.json", ".clang", "package.xml", ".git" },
  init_options = { clangdFileStatus = true },
  settings = {},
}

return M.config
