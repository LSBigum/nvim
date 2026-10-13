local function qf_from_git_range(range)
  -- Get changed files for the range
  local files = vim.fn.systemlist({ "git", "diff", "--name-only", range })
  local items = {}

  for _, f in ipairs(files) do
    if f ~= "" then
      -- Make path relative to current Neovim cwd
      local abs = vim.fn.fnamemodify(f, ":p")
      local rel = vim.fn.fnamemodify(abs, ":.") -- relative to :pwd

      -- Prefer bufnr so Trouble/qf can jump reliably
      local bufnr = vim.fn.bufadd(rel)

      table.insert(items, {
        bufnr = bufnr,
        lnum = 1,
        col = 1,
        text = "changed vs " .. range,
        valid = 1,
      })
    end
  end

  vim.fn.setqflist({}, "r", { title = "Changed files: " .. range, items = items })
end

-- origin/HEAD is set at clone time; repos cloned before the remote's default
-- branch changed may need `git remote set-head origin --auto`
local function trunk_branch()
  local result = vim.system({ "git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD" }, { text = true }):wait()
  if result.code == 0 then
    return vim.trim(result.stdout)
  end
  for _, branch in ipairs({ "main", "master" }) do
    if vim.system({ "git", "rev-parse", "--verify", "--quiet", branch }):wait().code == 0 then
      return branch
    end
  end
  return nil
end

local diffview_imply_local = true

local function diffview_prompt_title()
  local mode = diffview_imply_local and "working tree" or "commits only"
  return "Diffview range/rev (" .. mode .. ", <C-l> toggles)"
end

local function diffview_open_with_qf(range)
  -- Populate quickfix with cwd-relative paths
  qf_from_git_range(range)

  -- Show quickfix via Trouble if available; fallback to :copen
  if pcall(require, "trouble") then
    vim.cmd("Trouble qflist open")
  else
    vim.cmd("copen")
  end

  -- --imply-local puts the working tree on the right (LSP-friendly), which also
  -- pulls in uncommitted and untracked changes
  vim.cmd("DiffviewOpen " .. range .. (diffview_imply_local and " --imply-local" or ""))
end

local function diffview_open_prompt_with_qf()
  local trunk = trunk_branch()
  Snacks.input({
    prompt = diffview_prompt_title(),
    default = trunk and (trunk .. "...HEAD") or nil,
    win = {
      keys = {
        toggle_imply_local = {
          "<C-l>",
          function(self)
            diffview_imply_local = not diffview_imply_local
            self:set_title(diffview_prompt_title())
          end,
          mode = { "i", "n" },
        },
      },
    },
  }, function(range)
    if range then
      diffview_open_with_qf(range)
    end
  end)
end

vim.keymap.set("n", "<leader>gdo", diffview_open_prompt_with_qf, {
  desc = "DiffviewOpen (prompt) + Trouble qflist (cwd-relative)",
})
