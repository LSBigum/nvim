return {
    '2kabhishek/seeker.nvim',
    dependencies = { 'folke/snacks.nvim' },
    cmd = { 'Seeker' },
    keys = {
        { '<leader>sf', ':Seeker files<CR>', desc = 'Seek Files' },
        { '<leader>sg', ':Seeker grep<CR>', desc = 'Seek Grep' },
    },
    opts = {}
}
