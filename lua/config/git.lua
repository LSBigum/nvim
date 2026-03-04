-- -- Put this somewhere in your config (e.g. lua/git_review.lua)
-- local function qf_files_changed_since_main()
--   local files = vim.fn.systemlist({ "git", "diff", "--name-only", "main...HEAD" })
--   local items = {}
--   for _, f in ipairs(files) do
--     if f ~= "" then
--       table.insert(items, { filename = f, lnum = 1, col = 1, text = "changed vs main" })
--     end
--   end
--   vim.fn.setqflist({}, "r", { title = "Files changed since main", items = items })
--   vim.cmd("copen")
-- end
--
-- vim.api.nvim_create_user_command("ChangedSinceMain", qf_files_changed_since_main, {})
--
-- -- In the quickfix window: Enter opens Diffview, with working tree on the right (LSP-friendly).
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "qf",
--   callback = function(ev)
--     vim.keymap.set("n", "<CR>", function()
--       local qf = vim.fn.getqflist({ idx = 0, items = 0 })
--       local item = vim.fn.getqflist()[qf.idx]
--       if not item or not item.filename then return end
--
--       vim.cmd("cclose")
--       -- Open diffview for the whole comparison; then jump to the file.
--       -- (Diffview will show working tree on the right because of --imply-local.)
--       vim.cmd("DiffviewOpen main...HEAD --imply-local")
--       vim.cmd("edit " .. vim.fn.fnameescape(item.filename))
--     end, { buffer = ev.buf, silent = true })
--   end,
-- })
--
local function changed_since_main()
  local files = vim.fn.systemlist({ "git", "diff", "--name-only", "main...HEAD" })

  local items = {}
  for _, f in ipairs(files) do
    if f ~= "" then
      -- make sure quickfix entries resolve to real buffers
      local bufnr = vim.fn.bufadd(f) -- creates buffer entry without opening
      table.insert(items, {
        bufnr = bufnr,
        lnum = 1,
        col = 1,
        text = "changed vs main",
        valid = 1,
      })
    end
  end

  vim.fn.setqflist({}, "r", { title = "Changed since main", items = items })

  -- show with Trouble if available, else native quickfix
  local ok = pcall(require, "trouble")
  if ok then
    vim.cmd("Trouble qflist open")
  else
    vim.cmd("copen")
  end
end

vim.api.nvim_create_user_command("ChangedSinceMain", changed_since_main, {})

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

local function diffview_open_prompt_with_qf()
  local default = "main...HEAD"
  local range = vim.fn.input("Diffview range/rev: ", default)
  if not range or range == "" then
    return
  end

  -- Populate quickfix with cwd-relative paths
  qf_from_git_range(range)

  -- Show quickfix via Trouble if available; fallback to :copen
  if pcall(require, "trouble") then
    vim.cmd("Trouble qflist open")
  else
    vim.cmd("copen")
  end

  -- Open Diffview with working-tree on the right
  vim.cmd("DiffviewOpen " .. range .. " --imply-local")
end

vim.keymap.set("n", "<leader>mr", diffview_open_prompt_with_qf, {
  desc = "DiffviewOpen (prompt) + Trouble qflist (cwd-relative) --imply-local",
})

