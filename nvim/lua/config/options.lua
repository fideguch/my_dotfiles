-- Options migrated from .vimrc with upgrades for Neovim
local opt = vim.opt

-- File handling
opt.swapfile = false
opt.undofile = true -- UPGRADE: persistent undo (was noundofile in .vimrc)

-- Display
opt.ruler = true
opt.cmdheight = 1
opt.laststatus = 3 -- UPGRADE: global statusline
opt.title = true
opt.showcmd = true
opt.number = true
opt.relativenumber = true -- UPGRADE: relative line numbers
opt.showmatch = true
opt.list = true
opt.listchars = { tab = "» ", extends = "…", trail = "·" }
opt.synmaxcol = 200
opt.startofline = false
opt.background = "dark"
opt.termguicolors = true -- UPGRADE: true color support

-- Search
opt.smartcase = true
opt.ignorecase = true
opt.hlsearch = true
opt.incsearch = true

-- Editing
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.smarttab = true
opt.hidden = true
opt.whichwrap:append("b,s,h,l,<,>,[,]")
opt.formatoptions = "qjcroql"

-- Sound
opt.visualbell = true
opt.errorbells = false

-- System
opt.encoding = "utf-8"
opt.clipboard = "unnamedplus" -- Neovim clipboard integration
opt.updatetime = 250
