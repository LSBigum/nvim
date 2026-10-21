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
  -- {
  --   match      = "(.+/catkin_ws_non_core)/src/hawk%-non%-core/([^/]+)",
  --   container  = "hawk20_compiler",
  --   clangd_bin = "clangd-18",
  --   path_map   = { ["/home/nordbo/catkin_ws_non_core"] = "/home/nordbo_docker/catkin_ws" },
  -- },
  {
    match      = "(.+/catkin_ws_non_core)/src/([^/]+)",
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

-- Returns a container's bind mounts as { {source=, destination=}, ... }. Uses
-- `docker inspect` + vim.json.decode directly (no jq dependency, unlike
-- get_container_mappings above).
function M.container_bind_mounts(container)
  if not container or container == '' then
    return {}
  end

  local result = vim.system(
    { "docker", "inspect", container, "--format", "{{json .Mounts}}" },
    { text = true }
  ):wait()

  if result.code ~= 0 or not result.stdout or result.stdout == "" then
    return {}
  end

  local ok, mounts = pcall(vim.json.decode, result.stdout)
  if not ok or not mounts then
    return {}
  end

  local binds = {}
  for _, m in ipairs(mounts) do
    if m.Type == "bind" and m.Source and m.Destination then
      table.insert(binds, { source = m.Source, destination = m.Destination })
    end
  end
  return binds
end

-- Internal-dependency repos (RobWork, LCore, ...) mounted into a running
-- mimic-dev container via that repo's docker-compose.override.yml - see
-- get_mimic_profile below and docker-compose.override.yml.example in the Mimic
-- repo. Synthesizes a profile shaped like the static workspace_profiles above,
-- purely from the container's own bind mounts, so adding/removing a dependency
-- there never requires a change here.
--
-- Several Mimic worktrees can be up at once, each mounting the same dependency
-- checkout. The container is picked, in order, from: MIMIC_LSP_WORKTREE in the
-- environment (the worktree directory name, as `just` derives it), a choice made
-- earlier this session through choose_container / :ClangdContainer, and
-- otherwise the most recently created one, which is what `docker ps` lists
-- first. The pick is reported with vim.notify so it is never silent.

local function git_root(path)
  local result = vim.system(
    { "git", "-C", path, "rev-parse", "--show-toplevel" },
    { text = true }
  ):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.fs.normalize(vim.trim(result.stdout))
end

-- Running mimic-* containers that bind-mount this repo, newest first, as
-- { {container=, destination=}, ... }.
function M.mimic_dependency_candidates(root)
  -- "mimic-" is COMPOSE_PROJECT_NAME's fixed prefix (justfile), shared by every
  -- Mimic worktree's container.
  local containers = vim.fn.systemlist("docker ps --filter 'name=mimic-' --format '{{.Names}}'")
  local candidates = {}
  for _, container in ipairs(containers) do
    for _, mount in ipairs(M.container_bind_mounts(container)) do
      if vim.fs.normalize(mount.source) == root then
        table.insert(candidates, { container = container, destination = mount.destination })
      end
    end
  end
  return candidates
end

-- root -> container name chosen through choose_container this session.
local chosen_container = {}

local function pick_candidate(root, candidates)
  local worktree = vim.env.MIMIC_LSP_WORKTREE
  if worktree and worktree ~= "" then
    local prefix = "mimic-" .. worktree .. "-"
    for _, candidate in ipairs(candidates) do
      if candidate.container:sub(1, #prefix) == prefix then
        return candidate, "MIMIC_LSP_WORKTREE"
      end
    end
    vim.notify(
      "[clangd] MIMIC_LSP_WORKTREE=" .. worktree .. " has no running container mounting " .. root,
      vim.log.levels.WARN
    )
  end

  local chosen = chosen_container[root]
  if chosen then
    for _, candidate in ipairs(candidates) do
      if candidate.container == chosen then
        return candidate, ":ClangdContainer"
      end
    end
  end

  return candidates[1], (#candidates > 1) and "newest of " .. #candidates or "only candidate"
end

local function find_mimic_dependency_profile(path)
  local root = git_root(path)
  if not root then
    return nil
  end

  local candidates = M.mimic_dependency_candidates(root)
  if #candidates == 0 then
    return nil
  end

  local candidate, reason = pick_candidate(root, candidates)
  local level = (#candidates > 1 and reason:sub(1, 6) == "newest") and vim.log.levels.WARN or vim.log.levels.INFO
  local hint = (level == vim.log.levels.WARN) and "; :ClangdContainer to switch" or ""
  vim.notify(
    "[clangd] " .. vim.fs.basename(root) .. " -> " .. candidate.container .. " (" .. reason .. hint .. ")",
    level
  )

  return {
    container = candidate.container,
    clangd_bin = "clangd",
    path_map = { [root] = candidate.destination },
  }
end

-- Prompt for the container to use for the repo at `path`, remember it for the
-- session and call `on_done(container)` with the pick (nil if cancelled).
function M.choose_container(path, on_done)
  local root = git_root(path)
  local candidates = root and M.mimic_dependency_candidates(root) or {}
  if #candidates == 0 then
    vim.notify("[clangd] no running mimic-* container mounts " .. (root or path), vim.log.levels.WARN)
    return on_done(nil)
  end

  local names = {}
  for _, candidate in ipairs(candidates) do
    table.insert(names, candidate.container)
  end
  vim.ui.select(names, { prompt = "clangd container for " .. vim.fs.basename(root) }, function(choice)
    if choice then
      chosen_container[root] = choice
    end
    on_done(choice)
  end)
end

-- Internal-dependency repos mounted into a running Incus mimic-* container with
-- `just incus mount <dir>`. Incus mounts every directory at its host path, so
-- unlike the Docker profiles this needs no path_map. Returns the Mimic worktree
-- whose incus/clangd.sh starts clangd in that container, and the dependency's
-- build dir, named build-incus by the convention in that worktree's
-- incus/README.md.
function M.find_incus_dependency_profile(path)
  if vim.fn.executable("incus") ~= 1 then
    return nil
  end
  local root = git_root(path)
  if not root then
    return nil
  end

  local result = vim.system({ "incus", "list", "mimic-", "--format", "json" }, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  local ok, instances = pcall(vim.json.decode, result.stdout)
  if not ok or not instances then
    return nil
  end

  local candidates = {}
  for _, instance in ipairs(instances) do
    local devices = instance.expanded_devices or {}
    -- "repo" is the device mimic-incus.sh adds for the worktree itself.
    if instance.status == "Running" and devices.repo then
      for _, device in pairs(devices) do
        if device.type == "disk" and device.source and vim.fs.normalize(device.source) == root then
          table.insert(candidates, { container = instance.name, worktree = devices.repo.source })
          break
        end
      end
    end
  end
  if #candidates == 0 then
    return nil
  end

  local candidate = candidates[1]
  local level = (#candidates > 1) and vim.log.levels.WARN or vim.log.levels.INFO
  vim.notify(
    "[clangd] " .. vim.fs.basename(root) .. " -> Incus " .. candidate.container
      .. ((#candidates > 1) and (" (first of " .. #candidates .. ")") or ""),
    level
  )

  return {
    container = candidate.container,
    launcher = candidate.worktree .. "/incus/clangd.sh",
    build_dir = root .. "/build-incus",
  }
end

function M.detect_profile(cwd)
  for _, prof in ipairs(workspace_profiles) do
    if cwd:match(prof.match) then
      return prof
    end
  end
  return find_mimic_dependency_profile(cwd)
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

function M.get_mimic_profile(path)
  local result = vim.system(
    { "git", "-C", path or vim.fn.getcwd(), "rev-parse", "--show-toplevel" },
    { text = true }
  ):wait()

  if result.code ~= 0 then
    return nil
  end

  local root = vim.trim(result.stdout)
  local compose_file = root .. "/docker-compose.yml"
  local cmake_file = root .. "/mimic/CMakeLists.txt"

  if vim.fn.filereadable(compose_file) ~= 1 or vim.fn.filereadable(cmake_file) ~= 1 then
    return nil
  end

  local name = vim.fn.fnamemodify(root, ":t")
  name = name:gsub("[^%w_-]", "-"):gsub("^-+", ""):gsub("-+$", "")
  local project = "mimic-" .. name:lower()
  -- In-tree, fixed name (see docker_gitlab_ci/justfile's container_build_dir) —
  -- a subdirectory of root, so it needs no path_map entry of its own below.
  local build_dir = root .. "/build-docker"

  local container = vim.fn.systemlist({
    "docker", "compose", "-p", project, "-f", compose_file,
    "ps", "-q", "--status", "running", "mimic-dev",
  })[1]

  return {
    root = root,
    project = project,
    container = container and vim.trim(container) or nil,
    build_dir = vim.fs.normalize(build_dir),
    clangd_bin = "clangd",
    path_map = {
      [vim.fs.normalize(root)] = "/workspace/mimic",
    },
  }
end


return M
