-- --@type vim.lsp.Config
-- return {
-- 	cmd = {
-- 		"clangd",
-- 		"--background-index",
-- 		"--clang-tidy",
-- 		"--header-insertion=iwyu",
-- 		"--completion-style=detailed",
-- 		"--function-arg-placeholders",
-- 		"--fallback-style=llvm",
-- 	},
-- 	init_options = {
-- 		usePlaceholders = true,
-- 		completeUnimported = true,
-- 		clangdFileStatus = true,
-- 	},
-- 	filetypes = {
-- 		"c",
-- 		"cpp",
-- 	},
-- 	root_markers = { "compile_commands.json", ".clang" },
-- }

-- function to compute where compile_commands.json lives:
local function get_compile_commands_dir()
  local cwd = vim.fn.getcwd()

  -- 1) hawk-namespaced packages
  --    /…/catkin_ws/src/hawk/<proj> → /…/catkin_ws/build/<proj>
  local ws, proj = cwd:match '(.+/catkin_ws_20)/src/hawk/([^/]+)'
  if ws and proj then
    local ret = ws .. '/build/' .. proj
    -- local ret = '/home/nordbo_docker/catkin_ws/build/' .. proj
    print("compile_commands_dir=" .. ret)
    return ret
  end

  -- 2) top-level packages
  --    /…/catkin_ws/src/<proj> → /…/catkin_ws/build/<proj>
  local ws2, proj2 = cwd:match '(.+/catkin_ws_20)/src/([^/]+)'
  if ws2 and proj2 then
    local ret = '/home/nordbo_docker/catkin_ws/build/' .. proj2
    print("compile_commands_dir=" .. ret)
    return ret
  end

  local ws3, proj3 = cwd:match '(.+/catkin_ws_core)/src/hawk%-core/packages/([^/]+)'
  if ws3 and proj3 then
    local ret = '/catkin_ws/build/' .. proj3
    print("compile_commands_dir=" .. ret)
    return ret
  end

  -- 3) fallback: assume you generated it next to your sources
  return cwd
end

local function is_container_running(name)
  local cmd = 'docker ps --filter name=' .. name .. " --format '{{.Names}}' | grep -w " .. name .. ' > /dev/null'
  return os.execute(cmd) == 0
end

local clangd_options = {
  '--background-index',
  '--clang-tidy',
  '--completion-style=detailed',
  '--compile-commands-dir=' .. get_compile_commands_dir(),
  '--header-insertion-decorators',
  '--header-insertion=iwyu',
  -- '--cross-file-rename',
  '--pretty',
  '-j=8',
  '--log=verbose',
}
local clangd_cmd = {}

local cwd = vim.fn.getcwd()
if cwd:match '(.+/catkin_ws_20)/src/hawk/([^/]+)' and is_container_running 'hawk20_compiler' then
  local path_mappings = '/home/nordbo/catkin_ws_20=/home/nordbo_docker/catkin_ws'
  local docker_cmd = {
    'docker',
    'exec',
    '-i',
    'hawk20_compiler',
    'clangd-18',
    '--path-mappings=' .. path_mappings,
  }
  for _, v in ipairs(clangd_options) do
    table.insert(docker_cmd, v)
  end
  clangd_cmd = docker_cmd
elseif cwd:match '(.+/catkin_ws_core)/src/hawk%-core/packages/([^/]+)' and is_container_running('hawk-core-builder') then
  local path_mappings = '/home/nordbo/catkin_ws_core=/catkin_ws'
  local docker_cmd = {
    'docker',
    'exec',
    '-i',
    'hawk-core-builder',
    'clangd-18',
    '--path-mappings=' .. path_mappings,
  }
  for _, v in ipairs(clangd_options) do
    table.insert(docker_cmd, v)
  end
  clangd_cmd = docker_cmd
else
  clangd_cmd = clangd_options
  table.insert(clangd_cmd, 1, 'clangd')
end
print(table.concat(clangd_cmd, " "))


-- custom root_dir:
--  • first look for compile_commands.json / .git
--  • then detect ROS workspace as above
--  • finally fall back to git ancestor or cwd
local function clangd_root_dir(bufnr, cb)
  -- a) standard cmake/git lookup
  -- local root = util.root_pattern('compile_commands.json', '.git')(fname)
  -- if root then
  --   return root
  -- end

  -- b) any catkin_ws package (hawk-namespace or not) is its own project
  if cwd:match '(.+/catkin_ws_20)/src/[^/]+' then
    return cb(cwd)
  end

  -- c) finally, fall back to Git ancestor or cwd
  local git_dir = vim.fs.find('.git', { path = fname, upward = true })[1]
  if git_dir then
    return cb(vim.fs.dirname(git_dir))
  end

  return cb(cwd)
end
-- put it all together:
return {
  cmd = function() return vim.lsp.rpc.start(clangd_cmd) end,
  filetypes = { 'c', 'cpp' },
  root_dir = clangd_root_dir,
  -- any additional clangd-specific settings go here:
  settings = {
    -- e.g. clangd-extension settings or inlay hints
  },
  root_markers = { "compile_commands.json", ".clang"},
  init_options = {
    -- usePlaceholders = true,
    -- completeUnimported = true,
    clangdFileStatus = true,
  },
--   on_attach = function(client, bufnr)
--     -- only map when the LSP client is clangd
--     print("client name: " .. client.name)
--     if client.name == 'clangd' then
--       local opts = { noremap = true, silent = true, buffer = bufnr, desc = 'C++: Switch between source and header file' }
--       vim.keymap.set('n', '<leader>lm', '<cmd>ClangdSwitchSourceHeader<CR>', opts)
--     end
--   end,
}
