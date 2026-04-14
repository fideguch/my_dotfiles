-- Autocommands migrated from .vimrc
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Highlight full-width (zenkaku) spaces
local zenkaku_group = augroup("ZenkakuSpace", { clear = true })
autocmd("VimEnter", {
  group = zenkaku_group,
  callback = function()
    vim.fn.matchadd("ZenkakuSpace", "\xe3\x80\x80")
  end,
})
vim.api.nvim_set_hl(0, "ZenkakuSpace", { underline = true, fg = "#5fafff" })

-- Note: cursor position restore is handled by LazyVim defaults
-- Note: QuickFix auto-open is handled by LazyVim defaults
