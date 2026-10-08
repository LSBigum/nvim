local ensure_installed = {
    "bash",
    "c",
    "cpp",
    "html",
    "json",
    "lua",
    "luadoc",
    "luap",
    "markdown",
    "markdown_inline",
    "python",
    "query",
    "regex",
    "tsx",
    "typescript",
    "vim",
    "vimdoc",
    "yaml",
    "rust",
    "go",
    "gomod",
    "gowork",
    "gosum",
    "terraform",
    "proto",
    "zig",
}

-- Incremental selection (removed from nvim-treesitter's main branch)
local selection_stack = {}

local function select_node(node)
    local srow, scol, erow, ecol = node:range()
    if ecol == 0 then
        erow, ecol = erow - 1, #vim.fn.getline(erow)
    end
    vim.cmd("normal! \27")
    vim.api.nvim_win_set_cursor(0, { srow + 1, scol })
    vim.cmd("normal! v")
    vim.api.nvim_win_set_cursor(0, { erow + 1, math.max(ecol - 1, 0) })
end

local function init_selection()
    local node = vim.treesitter.get_node()
    if not node then return end
    selection_stack = { node }
    select_node(node)
end

local function node_incremental()
    local node = selection_stack[#selection_stack]
    if not node then return init_selection() end
    local parent = node:parent()
    -- Skip parents that span the exact same range
    while parent and vim.deep_equal({ parent:range() }, { node:range() }) do
        parent = parent:parent()
    end
    if not parent then return select_node(node) end
    table.insert(selection_stack, parent)
    select_node(parent)
end

local function node_decremental()
    if #selection_stack > 1 then
        table.remove(selection_stack)
    end
    local node = selection_stack[#selection_stack]
    if node then select_node(node) end
end

return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            local ts = require("nvim-treesitter")
            ts.install(ensure_installed)

            local available = {}
            for _, lang in ipairs(ts.get_available()) do
                available[lang] = true
            end

            vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("treesitter_setup", { clear = true }),
                callback = function(event)
                    local lang = vim.treesitter.language.get_lang(event.match)
                    if not lang or not available[lang] then return end

                    local function attach()
                        if not vim.api.nvim_buf_is_valid(event.buf) then return end
                        if not pcall(vim.treesitter.start, event.buf, lang) then return end
                        vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                    end

                    if vim.list_contains(ts.get_installed(), lang) then
                        attach()
                    else
                        -- auto_install
                        ts.install(lang):await(function() vim.schedule(attach) end)
                    end
                end,
            })

            vim.keymap.set("n", "<leader>vv", init_selection, { desc = "Start treesitter selection" })
            vim.keymap.set("x", "+", node_incremental, { desc = "Expand treesitter selection" })
            vim.keymap.set("x", "_", node_decremental, { desc = "Shrink treesitter selection" })
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        branch = "main",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            require("nvim-treesitter-textobjects").setup({
                select = {
                    lookahead = true,
                    selection_modes = {
                        ["@parameter.outer"] = "v",   -- charwise
                        ["@parameter.inner"] = "v",   -- charwise
                        ["@function.outer"] = "v",    -- charwise
                        ["@conditional.outer"] = "V", -- linewise
                        ["@loop.outer"] = "V",        -- linewise
                        ["@class.outer"] = "<c-v>",   -- blockwise
                    },
                    include_surrounding_whitespace = false,
                },
                move = {
                    set_jumps = true, -- whether to set jumps in the jumplist
                },
            })

            local select = require("nvim-treesitter-textobjects.select")
            local selects = {
                -- You can use the capture groups defined in textobjects.scm
                ["af"] = { "@function.outer", "around a function" },
                ["if"] = { "@function.inner", "inner part of a function" },
                ["ac"] = { "@class.outer", "around a class" },
                ["ic"] = { "@class.inner", "inner part of a class" },
                ["ai"] = { "@conditional.outer", "around an if statement" },
                ["ii"] = { "@conditional.inner", "inner part of an if statement" },
                ["al"] = { "@loop.outer", "around a loop" },
                ["il"] = { "@loop.inner", "inner part of a loop" },
                ["ap"] = { "@parameter.outer", "around parameter" },
                ["ip"] = { "@parameter.inner", "inside a parameter" },
            }
            for lhs, spec in pairs(selects) do
                vim.keymap.set({ "x", "o" }, lhs, function()
                    select.select_textobject(spec[1], "textobjects")
                end, { desc = spec[2] })
            end

            local move = require("nvim-treesitter-textobjects.move")
            local moves = {
                ["[f"] = { "goto_previous_start", "@function.outer", "Previous function" },
                ["[c"] = { "goto_previous_start", "@class.outer", "Previous class" },
                ["[p"] = { "goto_previous_start", "@parameter.inner", "Previous parameter" },
                ["]f"] = { "goto_next_start", "@function.outer", "Next function" },
                ["]c"] = { "goto_next_start", "@class.outer", "Next class" },
                ["]p"] = { "goto_next_start", "@parameter.inner", "Next parameter" },
            }
            for lhs, spec in pairs(moves) do
                vim.keymap.set({ "n", "x", "o" }, lhs, function()
                    move[spec[1]](spec[2], "textobjects")
                end, { desc = spec[3] })
            end
        end,
    },
}
