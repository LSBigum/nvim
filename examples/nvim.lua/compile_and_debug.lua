local overseer = require("overseer")

---- Base settings ----
local build_dir = "../../build"
local compiler = "cmake"
local root = vim.fn.getcwd()
local function git_toplevel_name()
  local file_dir = vim.fn.expand("%:p:h")

  local result = vim.system(
    { "git", "-C", file_dir, "rev-parse", "--show-toplevel" },
    { text = true }
  ):wait()

  if result.code ~= 0 then
    return nil
  end

  return vim.fn.fnamemodify(vim.trim(result.stdout), ":t")
end

---- Compiler flags ----
local compiler_flags = {
  "--build",
  git_toplevel_name(),
  "--",
  "-j20",
}

overseer.register_template({
  name = "_Build",
  tags = { overseer.TAG.BUILD },
  builder = function()
    local build_cwd = root .. "/" .. build_dir

    local args = vim.deepcopy(compiler_flags)

    return {
      cmd = compiler,
      args = args,
      cwd = build_cwd,
      components = {
        "default",
        { "on_output_quickfix", open_on_exit = "failure", open = false, set_diagnostics = true, relative_file_root = build_cwd },
      },
    }
  end
})

local cmake_flags = {
  "-B",
  git_toplevel_name(),
  "-S",
  root,
  "-DCMAKE_BUILD_TYPE=Debug",
  "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
}

overseer.register_template({
  name = "_Cmake",
  tags = { overseer.TAG.BUILD },
  builder = function()
    local build_cwd = root .. "/" .. build_dir
    vim.fn.mkdir(build_cwd, "p")

    local args = vim.deepcopy(cmake_flags)

    return {
      cmd = compiler,
      args = args,
      cwd = build_cwd,
      components = {
        "default",
        { "on_output_quickfix", open_on_exit = "failure", open = false, set_diagnostics = true, relative_file_root = build_cwd },
      },
    }
  end
})

overseer.register_template({
  name = "_Run",
  tags = { overseer.TAG.BUILD },
  builder = function()
    local build_cwd = root .. "/" .. build_dir .. "/" .. git_toplevel_name()

    return {
      cmd = "./ui/mimic",
      cwd = build_cwd,
      components = {
        "default",
        { "on_output_quickfix", open_on_exit = "failure", open = false, set_diagnostics = true, relative_file_root = build_cwd },
      },
    }
  end
})

local function get_git_root()
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  return vim.v.shell_error == 0 and git_root or vim.fn.getcwd()
end

local function project_binary_mimic()
  local git_root = get_git_root()
  local name = vim.fs.basename(git_root)

  return vim.fs.normalize(git_root .. "/../build/" .. name .. "/ui/mimic")
end


local dap = require("dap")
dap.configurations.cpp = dap.configurations.cpp or {}

table.insert(dap.configurations.cpp, 1,
{
  name = "Debug Mimic",
  type = "lldb",
  request = "launch",
  program = project_binary_mimic,
  cwd = get_git_root,
  args = {},
  stopOnEntry = false,
})
table.insert(dap.configurations.cpp, 1,
{
  name = "Compile and debug",
  type = "lldb",
  request = "launch",
  program = project_binary_mimic,
  cwd = get_git_root,
  args = {},
  stopOnEntry = false,
  preLaunchTask = "_Build",
})
