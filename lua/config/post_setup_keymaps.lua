local wk = require('which-key')
wk.add{ "<leader>cr", group = "[R]elative" }
wk.add{ "<leader>ca", group = "[A]bsolute" }
wk.add{ "<leader>crf", require("config.utils").copyFilePathRelative,              desc = "Copy File Path (relative)" }
wk.add{ "<leader>crl", require("config.utils").copyFilePathAndLineNumberRelative, desc = "Copy File Path and Line Number (relative)" }
wk.add{ "<leader>caf", require("config.utils").copyFilePathAbsolute,              desc = "Copy File Path (absolute)" }
wk.add{ "<leader>cal", require("config.utils").copyFilePathAndLineNumberAbsolute, desc = "Copy File Path and Line Number (absolute)" }
wk.add{ "<leader>cg",  require("config.utils").copyFilePathAndLineNumberGit,      desc = "Copy Git File Path and Line Number" }

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
