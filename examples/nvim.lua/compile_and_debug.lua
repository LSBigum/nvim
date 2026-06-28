local overseer = require("overseer")

---- Base settings ----
local compiler = "cmake"
local wrapper_root = vim.fs.normalize(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h"))
local project = {
  source_dir = "mimic",
  build_dir = "build",
  binary = "ui/mimic",
  build_type = "Debug",
  name = "Mimic",
  urgent_component = "project.mark_urgent_on_complete",
  build_args = { "--", "-j20" },
  cmake_args = {
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
  },
}

local function debug_name()
  return "Debug " .. project.name
end

local function compile_and_debug_name()
  return "Compile and debug " .. project.name
end

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

local function git_toplevel_name()
  return vim.fs.basename(get_worktree_root())
end

local function get_source_root()
  return vim.fs.normalize(get_worktree_root() .. "/" .. project.source_dir)
end

local function get_build_root()
  return vim.fs.normalize(wrapper_root .. "/" .. project.build_dir)
end

local function get_build_cwd()
  local git_name = git_toplevel_name()

  if not git_name then
    return get_build_root()
  end

  return vim.fs.normalize(get_build_root() .. "/" .. git_name)
end

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

package.preload["overseer.component." .. project.urgent_component] = function()
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

---- Compiler flags ----
local function compiler_flags()
  return vim.list_extend({
    "--build",
    git_toplevel_name(),
  }, project.build_args)
end

overseer.register_template({
  name = "_Build",
  tags = { overseer.TAG.BUILD },
  builder = function()
    local build_cwd = get_build_root()

    local args = compiler_flags()

    return {
      cmd = compiler,
      args = args,
      cwd = build_cwd,
      components = {
        "default",
        project.urgent_component,
        { "on_output_quickfix", open_on_exit = "failure", open = false, set_diagnostics = true, relative_file_root = build_cwd },
      },
    }
  end
})

local function cmake_flags()
  return vim.list_extend({
    "-B",
    git_toplevel_name(),
    "-S",
    get_source_root(),
    "-DCMAKE_BUILD_TYPE=" .. project.build_type,
  }, project.cmake_args)
end

overseer.register_template({
  name = "_Cmake",
  tags = { overseer.TAG.BUILD },
  builder = function()
    local build_cwd = get_build_root()
    vim.fn.mkdir(build_cwd, "p")

    local args = cmake_flags()

    return {
      cmd = compiler,
      args = args,
      cwd = build_cwd,
      components = {
        "default",
        project.urgent_component,
        { "on_output_quickfix", open_on_exit = "failure", open = false, set_diagnostics = true, relative_file_root = build_cwd },
      },
    }
  end
})

overseer.register_template({
  name = "_Run",
  tags = { overseer.TAG.BUILD },
  builder = function()
    local build_cwd = get_build_cwd()

    return {
      cmd = "./" .. project.binary,
      cwd = build_cwd,
      components = {
        "default",
        project.urgent_component,
        { "on_output_quickfix", open_on_exit = "failure", open = false, set_diagnostics = true, relative_file_root = build_cwd },
      },
    }
  end
})

local function project_binary()
  local name = git_toplevel_name()

  return vim.fs.normalize(get_build_root() .. "/" .. name .. "/" .. project.binary)
end


local dap = require("dap")
dap.configurations.cpp = dap.configurations.cpp or {}

table.insert(dap.configurations.cpp, 1,
{
  name = debug_name(),
  type = "lldb",
  request = "launch",
  program = project_binary,
  cwd = get_worktree_root,
  args = {},
  stopOnEntry = false,
})
table.insert(dap.configurations.cpp, 1,
{
  name = compile_and_debug_name(),
  type = "lldb",
  request = "launch",
  program = project_binary,
  cwd = get_worktree_root,
  args = {},
  stopOnEntry = false,
  preLaunchTask = "_Build",
})
