-- Keymaps migrated from .vimrc (muscle memory preservation)
-- Old Vim (fzf.vim) → New Neovim (Telescope/Neo-tree)
local map = vim.keymap.set

-- Ctrl+P → Buffer list (was :Buffers via fzf)
map("n", "<C-p>", "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>", {
  desc = "Buffers",
})

-- Ctrl+N → File finder (was :Files via fzf)
map("n", "<C-n>", "<cmd>Telescope find_files<cr>", {
  desc = "Find Files",
})

-- Ctrl+Z → Recent files (was :History via fzf)
-- NOTE: Intentionally overrides SIGTSTP (suspend). Same behavior as old .vimrc.
-- Use <leader>z or :suspend if you need to suspend Neovim.
map("n", "<C-z>", "<cmd>Telescope oldfiles<cr>", {
  desc = "Recent Files",
})

-- Ctrl+G → Live grep (was :Rg via fzf)
map("n", "<C-g>", "<cmd>Telescope live_grep<cr>", {
  desc = "Live Grep",
})

-- Ctrl+E → File explorer toggle (was NERDTree)
map("n", "<C-e>", function()
  require("neo-tree.command").execute({ toggle = true })
end, {
  desc = "Explorer Toggle",
})

-- Tab+l / Tab+h → Tab move (preserved from .vimrc)
map("n", "<Tab>l", "<cmd>+tabmove<cr>", { desc = "Move tab right" })
map("n", "<Tab>h", "<cmd>-tabmove<cr>", { desc = "Move tab left" })

-- ESC in terminal → Normal mode (preserved from .vimrc)
map("t", "<Esc>", "<C-\\><C-n>", { desc = "Terminal: Normal mode" })

-- Pokemon background change
map("n", "<leader>pk", function()
  vim.ui.input({ prompt = "Pokemon name (empty=random): " }, function(input)
    if input == nil then
      return
    end
    local cmd = input == "" and { "poke" } or { "poke", "-n", input }
    vim.fn.system(cmd)
    vim.notify("Pokemon changed: " .. (input == "" and "random" or input), vim.log.levels.INFO)
  end)
end, {
  desc = "Change Pokemon background",
})
