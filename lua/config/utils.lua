local M = {}

local function get_selected_line_range()
  local mode = vim.fn.mode()
  if not mode:match("[vV\22]") then
    return nil
  end

  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  return start_line, end_line
end

local function get_current_line_range()
  local start_line, end_line = get_selected_line_range()
  if start_line then
    return start_line, end_line
  end

  local current_line = vim.fn.line(".")
  return current_line, current_line
end

local function format_path_with_line_range(path)
  local start_line, end_line = get_current_line_range()
  if start_line == end_line then
    return path .. ":" .. start_line
  end

  return string.format("%s:%s-%s", path, start_line, end_line)
end

M.copyFilePathAndLineNumberGit = function()
  local current_file = vim.fn.expand("%:p")
  local start_line, end_line = get_current_line_range()
  local is_git_repo = vim.fn.system("git rev-parse --is-inside-work-tree"):match("true")

  if is_git_repo then
    local current_repo = vim.fn.systemlist("git remote get-url origin")[1]
    local current_branch = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1]

    -- Convert Git URL to GitHub/GitLab web URL format
    current_repo = current_repo:gsub("git@github.com:", "https://github.com/")
    current_repo = current_repo:gsub("git@gitlab.com:", "https://gitlab.com/")
    current_repo = current_repo:gsub("%.git$", "")

    -- Remove leading system path to repository root
    local repo_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
    if repo_root then
      current_file = current_file:sub(#repo_root + 2)
    end

    local line_fragment = start_line == end_line
      and ("#L" .. start_line)
      or string.format("#L%s-L%s", start_line, end_line)
    local url = string.format("%s/blob/%s/%s%s", current_repo, current_branch, current_file, line_fragment)
    vim.fn.setreg("+", url)
    print("Copied to clipboard: " .. url)
  else
    print("Not a git repository, can't copy filepath and linenumber!")
  end
end

M.copyFilePathRelative = function()
  local current_file = vim.fn.expand("%:.")
  vim.fn.setreg("+", current_file)
  print("Copied relative path to clipboard: " .. current_file)
end

M.copyFilePathAndLineNumberRelative = function()
  local current_file = vim.fn.expand("%:.")
  local value = format_path_with_line_range(current_file)
  vim.fn.setreg("+", value)
  print("Copied relative path with line number to clipboard: " .. value)
end

M.copyFilePathAbsolute = function()
  local current_file = vim.fn.expand("%:p")
  vim.fn.setreg("+", current_file)
  print("Copied absolute path to clipboard: " .. current_file)
end

-- Copy the current file path and line number to the clipboard, use GitHub URL if in a Git repository
M.copyFilePathAndLineNumberAbsolute = function()
  local current_file = vim.fn.expand("%:p")
  local value = format_path_with_line_range(current_file)

  vim.fn.setreg("+", value)
  print("Copied absolute path with line number to clipboard: " .. value)
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
