local wk = require('which-key')
wk.add{ "<leader>cf", require("config.utils").copyFilePathAndLineNumber,    desc = "Copy File Path and Line Number" }
wk.add{ "<leader>cg", require("config.utils").copyFilePathAndLineNumberGit, desc = "Copy Git File Path and Line Number" }
