local M = {}

M.copyFilePathAndLineNumberGit = function()
  local current_file = vim.fn.expand("%:p")
  local current_line = vim.fn.line(".")
  local is_git_repo = vim.fn.system("git rev-parse --is-inside-work-tree"):match("true")

  if is_git_repo then
    local current_repo = vim.fn.systemlist("git remote get-url origin")[1]
    local current_branch = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1]

    -- Convert Git URL to GitHub web URL format
    current_repo = current_repo:gsub("git@github.com:", "https://github.com/")
    current_repo = current_repo:gsub("%.git$", "")

    -- Remove leading system path to repository root
    local repo_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
    if repo_root then
      current_file = current_file:sub(#repo_root + 2)
    end

    local url = string.format("%s/blob/%s/%s#L%s", current_repo, current_branch, current_file, current_line)
    vim.fn.setreg("+", url)
    print("Copied to clipboard: " .. url)
  else
    print("Not a git repository, can't copy filepath and linenumber!")
  end
end

-- Copy the current file path and line number to the clipboard, use GitHub URL if in a Git repository
M.copyFilePathAndLineNumber = function()
  local current_file = vim.fn.expand("%:p")
  local current_line = vim.fn.line(".")

  vim.fn.setreg("+", current_file .. ":" .. current_line)
  print("Copied full path to clipboard: " .. current_file .. ":" .. current_line)
end

function M.get_package_name()
  local package_xml = vim.fn.findfile('package.xml', '.;')
  if package_xml == '' then
    vim.notify('Unable to find package.xml from ' .. vim.fn.getcwd(), vim.log.levels.ERROR)
    return
  end
  local lines = vim.fn.readfile(package_xml)
  for _, line in ipairs(lines) do
    local name = line:match '<name>(.-)</name>'
    if name then
      return name
    end
  end
  vim.notify('Unable to get package name from ' .. package_xml, vim.log.levels.ERROR)
end

return M
