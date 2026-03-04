-- return {}
return {
    'stevearc/overseer.nvim',
    ---@module 'overseer'
    ---@type overseer.SetupOpts
    opts = {
        project_root = function()
          return require("lspconfig.util").root_pattern(
            ".git",
            ".overseer.lua",
            "CMakeLists.txt"
          )
        end,
        templates = {
            "builtin",
            "docker_cpp",
            "cpp",
        },
        log = {
            {
                type = "file",
                filename = "overseer.log",
                level = vim.log.levels.DEBUG, -- or TRACE for max verbosity
            },
        },
        task_list = {
            bindings = {
                h = "DecreaseDetail",
                l = "IncreaseDetail",
              ["<C-h>"] = false,
              ["<C-j>"] = false,
              ["<C-k>"] = false,
              ["<C-l>"] = false,
            },
        },
    },
    keys = {
        {
            '<leader>or',
            '<cmd>OverseerRun<CR>',
            desc = '[R]un task'
        },
        {
            '<leader>ot',
            '<cmd>OverseerToggle<CR>',
            desc = '[T]oggle output'
        },
    },
    config = function(_, opts)
        require('overseer').setup(opts)
        local wk = require('which-key')
        wk.add({
            {'<leader>o', group = "[O]verseer" }
        })
    end
}
