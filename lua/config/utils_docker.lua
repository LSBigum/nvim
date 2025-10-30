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
end

function M.get_container_mappings(container)
  local cmd = 'docker inspect ' .. container .. ' | jq -r \'[.[0].Mounts[] | select(.Type=="bind") | "\\(.Source)=\\(.Destination)"] | join(",")\''
  return vim.fn.system(cmd)
end

return M
