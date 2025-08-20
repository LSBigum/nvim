return {
    {
        "mason-org/mason-lspconfig.nvim",
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            "neovim/nvim-lspconfig",
            "WhoIsSethDaniel/mason-tool-installer.nvim",
        },
        config = function ()
            local mason = require('mason')
            local mason_lspconfig = require("mason-lspconfig")
            local mason_tool_installer = require("mason-tool-installer")

            -- enable mason and configure icons
            mason.setup({
                ui = {
                    icons = {
                        package_installed = "✓",
                        package_pending = "➜",
                        package_uninstalled = "✗",
                    },
                }
            })
            mason_lspconfig.setup({
                automatic_enable = true,
                -- list of servers for mason to install
                ensure_installed = {
                    "bashls",
                    "clangd",
                    "cmake",
                    "docker_compose_language_service",
                    "dockerls",
                    "gitlab_ci_ls",
                    "lua_ls",
                    "pyright",
                    "pylsp",
                },
            })
            mason_tool_installer.setup({
                ensure_installed = {
                    "beautysh", -- bash formatter
                    "black", -- python
                    "buf",
                    "cmakelint",
                    "commitlint",
                    "clang-format", -- cpp formatter
                    "cpplint", -- cpp linter
                    "isort", -- python
                    "jsonlint",
                    "selene", -- lua
                    "protolint",
                    "shellcheck", -- bash linter
                    "stylua", -- lua
                    "yaml-language-server",
                    "yamllint",
                    "yamlfix",
                    "yamlfmt",
                },
            })
        end,
    },
}
