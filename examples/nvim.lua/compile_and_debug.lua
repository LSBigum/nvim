local overseer = require("overseer")
local dap = require("dap")

---- Project settings ----
-- Everything project specific lives in this table. Paths are relative to the
-- directory of this file unless stated otherwise.
local project = {
  name = "Clay",

  -- Source dir, relative to the git worktree root of the current buffer
  source_dir = "./",
  build_dir = "build",
  -- Build each git worktree into build_dir/<worktree name> so worktrees don't
  -- clobber each other's build trees
  per_worktree_build = true,

  build_type = "Debug",
  generator = nil, -- e.g. "Ninja"; nil lets cmake pick
  cmake_args = {
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
  },
  jobs = vim.uv.available_parallelism(),
  build_target = nil, -- e.g. "my_app"; nil builds all
  build_args = {}, -- extra args passed after `--` to the native build tool

  -- Executable relative to the build dir. Leave empty to be prompted on debug
  -- and use :ProjectPickBinary to set it for the session.
  binary = "",
  -- `fd` search used by the picker, run in the build dir
  binary_search = {
    dir = "examples/",
    pattern = "^[^.]+$", -- files without an extension
  },

  -- Arguments and environment shared by `_Run` and the debug configs
  args = {},
  env = {},

  -- Working directory: "build", "source", "worktree" or an absolute path
  run_cwd = "build",
  debug_cwd = "worktree",

  debug = {
    adapter = "lldb",
    filetypes = { "cpp", "c" },
    stop_on_entry = false,
  },

  -- Flag the terminal window urgent (via xdotool) when a task finishes
  mark_urgent = true,
}

---- Paths ----
local wrapper_root = vim.fs.normalize(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h"))
local urgent_component = "project.mark_urgent_on_complete"

local function current_path()
  local file = vim.api.nvim_buf_get_name(0)

  if file ~= "" then
    return vim.fn.fnamemodify(file, ":p:h")
  end

  return vim.fn.getcwd()
end

local function get_git_root(path)
  local result = vim.system(
    { "git", "-C", path or current_path(), "rev-parse", "--show-toplevel" },
    { text = true }
  ):wait()

  if result.code ~= 0 then
    return nil
  end

  return vim.fs.normalize(vim.trim(result.stdout))
end

local function get_worktree_root()
  return get_git_root() or get_git_root(wrapper_root .. "/" .. project.source_dir) or wrapper_root
end

local function get_source_root()
  return vim.fs.normalize(get_worktree_root() .. "/" .. project.source_dir)
end

-- Directory cmake is invoked from
local function get_build_root()
  return vim.fs.normalize(wrapper_root .. "/" .. project.build_dir)
end

-- Directory holding the actual build tree, relative to get_build_root()
local function build_tree_name()
  return project.per_worktree_build and vim.fs.basename(get_worktree_root()) or "."
end

local function get_build_cwd()
  return vim.fs.normalize(get_build_root() .. "/" .. build_tree_name())
end

local function resolve_cwd(kind)
  if kind == "build" then
    return get_build_cwd()
  elseif kind == "source" then
    return get_source_root()
  elseif kind == "worktree" then
    return get_worktree_root()
  end

  return vim.fs.normalize(kind)
end

local function project_binary()
  return vim.fs.normalize(get_build_cwd() .. "/" .. project.binary)
end

---- Urgent window component ----
local function get_current_window_id()
  if vim.env.WINDOWID and vim.env.WINDOWID ~= "" then
    return vim.trim(vim.env.WINDOWID)
  end

  local result = vim.system({ "xdotool", "getactivewindow" }, { text = true }):wait()

  if result.code ~= 0 or not result.stdout or result.stdout == "" then
    return nil
  end

  return vim.trim(result.stdout)
end

local use_urgent = project.mark_urgent and vim.fn.executable("xdotool") == 1

package.preload["overseer.component." .. urgent_component] = function()
  return {
    desc = "Mark the terminal window urgent when task completes",
    editable = false,
    serializable = false,
    constructor = function()
      return {
        window_id = nil,
        on_start = function(self)
          self.window_id = get_current_window_id()
        end,
        on_complete = function(self, _, status)
          if status ~= "SUCCESS" and status ~= "FAILURE" then
            return
          end

          local window_id = self.window_id or get_current_window_id()

          if window_id then
            vim.system({ "xdotool", "set_window", "--urgency", "1", window_id })
          end
        end,
      }
    end,
  }
end

local function task_components(cwd)
  local components = {
    "default",
    { "on_output_quickfix", open_on_exit = "failure", open = false, set_diagnostics = true, relative_file_root = cwd },
  }

  if use_urgent then
    table.insert(components, urgent_component)
  end

  return components
end

---- Tasks ----
local function cmake_flags()
  local args = {
    "-B",
    build_tree_name(),
    "-S",
    get_source_root(),
    "-DCMAKE_BUILD_TYPE=" .. project.build_type,
  }

  if project.generator then
    vim.list_extend(args, { "-G", project.generator })
  end

  return vim.list_extend(args, project.cmake_args)
end

local function build_flags()
  local args = { "--build", build_tree_name(), "--parallel", tostring(project.jobs) }

  if project.build_target then
    vim.list_extend(args, { "--target", project.build_target })
  end

  if #project.build_args > 0 then
    table.insert(args, "--")
    vim.list_extend(args, project.build_args)
  end

  return args
end

overseer.register_template({
  name = "_Cmake",
  tags = { overseer.TAG.BUILD },
  builder = function()
    local build_root = get_build_root()
    vim.fn.mkdir(build_root, "p")

    return {
      cmd = "cmake",
      args = cmake_flags(),
      cwd = build_root,
      components = task_components(build_root),
    }
  end,
})

overseer.register_template({
  name = "_Build",
  tags = { overseer.TAG.BUILD },
  builder = function()
    local build_root = get_build_root()

    return {
      cmd = "cmake",
      args = build_flags(),
      cwd = build_root,
      components = task_components(build_root),
    }
  end,
})

overseer.register_template({
  name = "_Run",
  tags = { overseer.TAG.RUN },
  builder = function()
    if project.binary == "" then
      error("No binary set for " .. project.name .. ", run :ProjectPickBinary first")
    end

    local cwd = resolve_cwd(project.run_cwd)

    return {
      cmd = project_binary(),
      args = project.args,
      env = project.env,
      cwd = cwd,
      components = task_components(cwd),
    }
  end,
})

---- Binary picker ----
local fd = vim.fn.executable("fd") == 1 and "fd" or "fdfind" -- Debian/Ubuntu ship fd as `fdfind`

local function pick_binary(on_choice)
  local cwd = get_build_cwd()

  if vim.fn.isdirectory(cwd) == 0 then
    vim.notify(cwd .. " does not exist, run _Cmake first", vim.log.levels.ERROR)
    return on_choice(nil)
  end

  local search = project.binary_search
  local result = vim.system({ fd, "-tx", search.pattern, search.dir }, { text = true, cwd = cwd }):wait()

  if result.code ~= 0 then
    vim.notify(fd .. " failed:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
    return on_choice(nil)
  end

  local entries = vim.split(vim.trim(result.stdout or ""), "\n", { trimempty = true })

  if #entries == 0 then
    vim.notify("No executables found under " .. search.dir .. " in " .. cwd, vim.log.levels.WARN)
    return on_choice(nil)
  end

  table.sort(entries)
  vim.ui.select(entries, { prompt = "Select executable", format_item = vim.fs.basename }, on_choice)
end

-- Pick an executable and make it the default for `_Run` and the debug configs
vim.api.nvim_create_user_command("ProjectPickBinary", function()
  pick_binary(function(choice)
    if choice then
      project.binary = choice
      vim.notify("Binary set to " .. choice)
    end
  end)
end, { desc = "Pick the executable used by _Run and the " .. project.name .. " debug configs" })

-- nvim-dap waits on a returned coroutine, so the picker can run asynchronously
local function pick_project_binary()
  return coroutine.create(function(dap_run_co)
    pick_binary(function(choice)
      coroutine.resume(dap_run_co, choice and vim.fs.normalize(get_build_cwd() .. "/" .. choice) or dap.ABORT)
    end)
  end)
end

-- Use the configured binary, or prompt for one when none is set
local function configured_or_picked_binary()
  if project.binary == "" then
    return pick_project_binary()
  end

  return project_binary()
end

---- Debug configs ----
local function debug_config(name, program, extra)
  return vim.tbl_extend("force", {
    name = name,
    type = project.debug.adapter,
    request = "launch",
    program = program,
    cwd = function()
      return resolve_cwd(project.debug_cwd)
    end,
    args = function()
      return project.args
    end,
    env = function()
      return project.env
    end,
    stopOnEntry = project.debug.stop_on_entry,
  }, extra or {})
end

local configs = {
  debug_config("Debug picked executable", pick_project_binary),
  debug_config("Compile and debug " .. project.name, configured_or_picked_binary, { preLaunchTask = "_Build" }),
  debug_config("Debug " .. project.name, configured_or_picked_binary),
}

local config_names = {}
for _, config in ipairs(configs) do
  config_names[config.name] = true
end

for _, filetype in ipairs(project.debug.filetypes) do
  -- Drop entries from a previous load so re-sourcing this file doesn't duplicate them
  local existing = vim.tbl_filter(function(config)
    return not config_names[config.name]
  end, dap.configurations[filetype] or {})

  dap.configurations[filetype] = vim.list_extend(vim.deepcopy(configs), existing)
end
