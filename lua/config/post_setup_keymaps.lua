local wk = require('which-key')
wk.add{ "<leader>cf", require("config.utils").copyFilePathAndLineNumber,    desc = "Copy File Path and Line Number" }
wk.add{ "<leader>cg", require("config.utils").copyFilePathAndLineNumberGit, desc = "Copy Git File Path and Line Number" }

-- Toggle quickfix
local function toggle_qf()
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 then
      vim.cmd("cclose")
      return
    end
  end
  vim.cmd("copen")
end
wk.add{"<leader>q", group = "[Q]uickfix/[Q]uit"}
wk.add{"<leader>qf", toggle_qf, desc = "Toggle quickfix" }
wk.add{"<leader>q<cr>", "<cmd>q<cr>", desc = "Quit" }

wk.add{ "<leader>w", group = "[W]rite..."}
wk.add{ "<leader>w<cr>", "<cmd>w<cr>", desc = "Save file" }
wk.add{ "<leader>wq", group = "[W]rite and quit..." }
wk.add{ "<leader>wq<cr>", "<cmd>wq<cr>", desc = "Save file and quit" }
