return {
    '2kabhishek/seeker.nvim',
    dependencies = { 'folke/snacks.nvim' },
    cmd = { 'Seeker' },
    keys = {
        { '<leader>sf', ':Seeker files<CR>', desc = 'Seek Files' },
        { '<leader>sg', ':Seeker grep<CR>', desc = 'Seek Grep' },
        { '<leader>sG', ':Seeker git_files<CR>', desc = 'Seek [G]it Files' },
    },
    opts = {}
}
