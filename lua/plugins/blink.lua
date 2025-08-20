return {
    { "L3MON4D3/LuaSnip", keys = {} },
    {
        "saghen/blink.cmp",
        dependencies = {
            "rafamadriz/friendly-snippets",
        },
        -- event = "InsertEnter",
        version = "*",
        config = function()
            vim.cmd('highlight Pmenu guibg=none')
            vim.cmd('highlight PmenuExtra guibg=none')
            vim.cmd('highlight FloatBorder guibg=none')
            vim.cmd('highlight NormalFloat guibg=none')

            require("blink.cmp").setup({
                snippets = { preset = "luasnip" },
                signature = { enabled = true },
                appearance = {
                    use_nvim_cmp_as_default = false,
                    nerd_font_variant = "normal",
                },
                sources = {
                    per_filetype = {
                        codecompanion = { "codecompanion" },
                    },
                    default = { "lsp", "path", "snippets", "buffer" },
                    providers = {
                        cmdline = {
                            min_keyword_length = 2,
                        },
                    },
                },
                keymap = {
                    preset = 'default',
                    ['<C-k>'] = {
                      function(cmp)
                        cmp.select_prev { auto_insert = false }
                      end,
                    },
                    ['<C-j>'] = {
                      function(cmp)
                        cmp.select_next { auto_insert = false }
                      end,
                    },
                    ['<C-d>'] = {
                      function(cmp)
                        for _ = 1, 4 do
                          cmp.select_next { auto_insert = false }
                        end
                        return true
                      end,
                      'scroll_documentation_down',
                    },
                    ['<C-u>'] = {
                      function(cmp)
                        for _ = 1, 4 do
                          cmp.select_prev { auto_insert = false }
                        end
                        return true
                      end,
                      'scroll_documentation_up',
                    },
                    ['<C-h>'] = { 'snippet_backward', 'fallback' },
                    ['<C-l>'] = { 'snippet_forward', 'fallback' },
                    ['<C-S-k>'] = { 'show_signature', 'hide_signature', 'fallback' },
                },
                cmdline = {
                    enabled = true,
                    completion = {
                        -- menu = { auto_show = true },
                        -- ghost_text = { enabled = true },
                    },
                    keymap = {
                        preset = 'inherit',
                        -- ["<CR>"] = { "accept_and_enter", "fallback" },
                    },
                },
                completion = {
                    menu = {
                        border = nil,
                        scrolloff = 1,
                        scrollbar = false,
                        draw = {
                            columns = {
                                { "kind_icon" },
                                { "label",      "label_description", gap = 1 },
                                { "kind" },
                                { "source_name" },
                            },
                        },
                    },
                    documentation = {
                        window = {
                            border = nil,
                            scrollbar = false,
                            winhighlight = 'Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc',
                        },
                        auto_show = true,
                        auto_show_delay_ms = 500,
                    },
                },
            })

            require("luasnip.loaders.from_vscode").lazy_load()
        end,
    },
}
