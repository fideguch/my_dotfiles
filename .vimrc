noremap! <C-?> <C-h>

" ==========================================================
" プラグイン
" ==========================================================
call plug#begin('~/.vim/plugged')

" --- ファイルナビゲーション ---
" カレントディレクトリのtreeを表示
Plug 'preservim/nerdtree'
" ファジーファインダー (Unite.vimの後継)
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" --- Git ---
Plug 'tpope/vim-fugitive'
" 変更行をガターに表示
Plug 'airblade/vim-gitgutter'

" --- 編集支援 ---
" コメントON/OFFを手軽に実行
Plug 'tomtom/tcomment_vim'
" シングルクオートとダブルクオートの入れ替え等
Plug 'tpope/vim-surround'
" .でリピート
Plug 'tpope/vim-repeat'
" endを自動挿入
Plug 'tpope/vim-endwise'
" ブロック移動の拡張
Plug 'andymass/vim-matchup'

" --- 見た目 ---
" インデントに色を付けて見やすくする
Plug 'nathanaelkane/vim-indent-guides'
" 行末の半角スペースを可視化
Plug 'bronson/vim-trailing-whitespace'
" CSVをカラム単位に色分けする
Plug 'mechatroner/rainbow_csv'
" 多言語シンタックスハイライト
Plug 'sheerun/vim-polyglot'

" --- ステータスバー ---
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
" treeのアイコン
Plug 'ryanoasis/vim-devicons'

call plug#end()

" ==========================================================
" 基本設定
" ==========================================================

" スワップファイルは使わない
set noswapfile
" undoファイルは作成しない
set noundofile
" カーソル位置を表示
set ruler
" コマンドラインの行数
set cmdheight=2
" ステータスラインを常時表示
set laststatus=2
" ステータス行の表示内容
set statusline=%<%f\ %m%r%h%w%{'['.(&fenc!=''?&fenc:&enc).']['.&ff.']'}%=%l,%c%V%8P
" ウインドウのタイトルバーにパス情報を表示
set title
" コマンドラインモードで<Tab>キーによるファイル名補完
set wildmenu
" 入力中のコマンドを表示
set showcmd
" バックアップディレクトリ
set backupdir=$HOME/.vimbackup
" バッファで開いているファイルのディレクトリでエクスプローラを開始
set browsedir=buffer
" 小文字のみで検索したときに大文字小文字を無視
set smartcase
set ignorecase
" 検索結果をハイライト表示
set hlsearch
" 暗い背景色に合わせた配色
set background=dark
" タブ入力を複数の空白入力に置き換える
set expandtab
" 検索ワードの最初の文字を入力した時点で検索を開始
set incsearch
" 保存されていないファイルがあるときでも別のファイルを開ける
set hidden
" 不可視文字を表示
set list
" タブと行の続きを可視化
set listchars=tab:>\ ,extends:<
" 行番号を表示
set number
" 対応する括弧やブレースを表示
set showmatch
" インデント設定
set autoindent
set smartindent
set tabstop=2
set shiftwidth=2
set smarttab
" カーソルを行頭、行末で止まらないようにする
set whichwrap=b,s,h,l,<,>,[,]
" 構文毎に文字色を変化させる
syntax on
" カラースキーマ
colorscheme material-theme
set t_Co=256
" 行番号の色
highlight LineNr ctermfg=darkyellow
" 勝手に改行するのを防ぐ
set formatoptions=q
" クラッシュ防止
set synmaxcol=200
" G押下時にカラム位置を保持
set nostartofline
" ビープ音を無効
set visualbell t_vb=
set noerrorbells
" UTF-8
set encoding=UTF-8
" クリップボード連携
if has("clipboard")
  set clipboard=unnamed
endif
" タグファイル
set tags=~/.tags

" ==========================================================
" キーマップ
" ==========================================================

" --- fzf (旧Unite.vimのキーバインドを維持) ---
" バッファ一覧 (旧: :Unite buffer)
noremap <C-P> :Buffers<CR>
" ファイル一覧 (旧: :Unite file)
noremap <C-N> :Files<CR>
" 最近使ったファイルの一覧 (旧: :Unite file_mru)
noremap <C-Z> :History<CR>
" ファイル内容をgrepで検索 (ripgrep)
noremap <C-G> :Rg<CR>

" --- NERDTree ---
" Ctrl+eで起動
nnoremap <silent><C-e> :NERDTreeToggle<CR>

" --- タブ操作 ---
nnoremap <Tab>l :+tabmove<CR>
nnoremap <Tab>h :-tabmove<CR>

" --- ターミナル ---
" ターミナル起動時にESCでnormalモードへ
tnoremap <ESC> <C-\><C-n>

" ==========================================================
" プラグイン設定
" ==========================================================

" --- vim-airline ---
let g:airline#extensions#tabline#enabled = 1

" --- vim-indent-guides ---
let g:indent_guides_enable_on_vim_startup = 1

" --- fzf ---
" fzfウィンドウをフローティングで表示
let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }

" --- vim-gitgutter ---
" 更新間隔を短くする (ms)
set updatetime=250

" ==========================================================
" 自動コマンド
" ==========================================================
augroup MyAutoCommands
  autocmd!

  " grep検索の実行後にQuickFix Listを表示
  autocmd QuickFixCmdPost *grep* cwindow

  " 最後のカーソル位置を復元
  autocmd BufReadPost *
    \ if line("'\"") > 0 && line ("'\"") <= line("$") |
    \   exe "normal! g'\"" |
    \ endif
augroup END

" ==========================================================
" クリップボードからのペースト整頓
" ==========================================================
if &term =~ "xterm"
  let &t_SI .= "\e[?2004h"
  let &t_EI .= "\e[?2004l"
  let &pastetoggle = "\e[201~"

  function! XTermPasteBegin(ret)
    set paste
    return a:ret
  endfunction

  inoremap <special> <expr> <Esc>[200~ XTermPasteBegin("")
endif

" ==========================================================
" 全角スペースの表示
" ==========================================================
function! ZenkakuSpace()
  highlight ZenkakuSpace cterm=underline ctermfg=lightblue guibg=darkgray
endfunction

augroup ZenkakuSpaceGroup
  autocmd!
  autocmd ColorScheme * call ZenkakuSpace()
  autocmd VimEnter,WinEnter,BufRead * let w:m1=matchadd('ZenkakuSpace', '　')
augroup END
call ZenkakuSpace()

" ==========================================================
" 挿入モード時、ステータスラインの色を変更
" ==========================================================
let g:hi_insert = 'highlight StatusLine guifg=darkblue guibg=darkyellow gui=none ctermfg=blue ctermbg=yellow cterm=none'

let s:slhlcmd = ''
function! s:StatusLine(mode)
  if a:mode == 'Enter'
    silent! let s:slhlcmd = 'highlight ' . s:GetHighlight('StatusLine')
    silent exec g:hi_insert
  else
    highlight clear StatusLine
    silent exec s:slhlcmd
  endif
endfunction

function! s:GetHighlight(hi)
  redir => hl
  exec 'highlight '.a:hi
  redir END
  let hl = substitute(hl, '[\r\n]', '', 'g')
  let hl = substitute(hl, 'xxx', '', '')
  return hl
endfunction

augroup InsertHighlight
  autocmd!
  autocmd InsertEnter * call s:StatusLine('Enter')
  autocmd InsertLeave * call s:StatusLine('Leave')
augroup END

" ==========================================================
" 自動閉じ括弧
" ==========================================================
imap { {}<LEFT>
imap [ []<LEFT>
imap ( ()<LEFT>

" filetypeの自動検出
filetype on
