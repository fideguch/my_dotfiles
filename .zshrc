# バックスペースが文字化けするので殺しておく
stty erase '^?'
# Unicodeの絵文字共
# EMOJI_1=$'\U1F525 '
# EMOJI_2=$'\U1f33f '
# colors関数を読み込む
autoload -Uz colors
colors
# Ctrl+Dでログアウトしてしまうことを防ぐ
setopt IGNOREEOF

# 日本語を使用
export LANG=ja_JP.UTF-8

# パスを追加したい場合
export PATH="$HOME/bin:$PATH"

# 補完
autoload -Uz compinit
compinit

# emacsキーバインド
bindkey -e

# 他のターミナルとヒストリーを共有
setopt share_history

# ヒストリーに重複を表示しない
setopt histignorealldups

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# cdコマンドを省略して、ディレクトリ名のみの入力で移動
setopt auto_cd

# 自動でpushdを実行
setopt auto_pushd

# pushdから重複を削除
setopt pushd_ignore_dups

# コマンドミスを修正
setopt correct

#エイリアス
# --colerオプションはlinux専用なので、macosでは-Gオプションに変更
#alias lst='ls -ltr --color=auto'
#alias l='ls -ltr --color=auto'
#alias la='ls -la --color=auto'
#alias ll='ls -l --color=auto'
alias ls='ls -G'
alias la='ls -laG'
# alias la='ls -ltraG'
alias ll='ls -lG'
# alias ll='ls -ltrG'
alias so='source'
alias sovz='source ~/.zshrc'
alias v='vim'
alias vi='vim'
alias vz='vim ~/dotfiles/.zshrc'
alias vv='vim ~/dotfiles/.vimrc'
alias c='cat'
alias ifcon='ifconfig'
alias g='git'
alias d='docker'
alias dc='docker-compose'
alias py='python'
alias cdd='cd ~/Desktop/dir'
alias cdlearn='cd ~/Desktop/Folders/Learn'
alias cddev='cd ~/Products'
alias mkd='mkdir'
alias tou='touch'
# historyに日付を表示
alias h='fc -lt '%F %T' 1'
alias cp='cp -i'
alias rm='rm -i'
alias mkdir='mkdir -p'
alias ..='c ../'
alias back='pushd'
alias diff='diff -U1'
alias colorls='for c in {000..255}; do echo -n "\e[38;5;${c}m $c" ; [ $(($c%16)) -eq 15 ] && echo;done;echo'
alias cdtemp='cd $TEMPDIR'

# backspace,deleteキーを使えるように
stty erase ^H
bindkey "^[[3~" delete-char

# cdの後にlsを実行。ここもLinuxとMacOSでオプションが異なる
#chpwd() { ls -ltr --color=auto }
chpwd() { ls -ltrG }

# どこからでも参照できるディレクトリパス
# cdpath=(~)

# 区切り文字の設定
autoload -Uz select-word-style
select-word-style default
zstyle ':zle:*' word-chars "_-./;@"
zstyle ':zle:*' word-style unspecified

# Ctrl+sのロック, Ctrl+qのロック解除を無効にする
setopt no_flow_control

# プロンプト
eval "$(starship init zsh)"

# 補完後、メニュー選択モードになり左右キーで移動が出来る
zstyle ':completion:*:default' menu select=2

# 補完で大文字にもマッチ
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Ctrl+rでヒストリーのインクリメンタルサーチ、Ctrl+sで逆順
bindkey '^r' history-incremental-pattern-search-backward
bindkey '^s' history-incremental-pattern-search-forward

# コマンドを途中まで入力後、historyから絞り込み
# 例 ls まで打ってCtrl+pでlsコマンドをさかのぼる、Ctrl+bで逆順
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^b" history-beginning-search-forward-end

# cdrコマンドを有効 ログアウトしても有効なディレクトリ履歴
# cdr タブでリストを表示
autoload -Uz add-zsh-hook
autoload -Uz chpwd_recent_dirs cdr
add-zsh-hook chpwd chpwd_recent_dirs
# cdrコマンドで履歴にないディレクトリにも移動可能に
zstyle ":chpwd:*" recent-dirs-default true

# 複数ファイルのmv 例　zmv *.txt *.txt.bk
autoload -Uz zmv
alias zmv='noglob zmv -W'

# mkdirとcdを同時実行
function mkcd() {
  if [[ -d $1 ]]; then
      echo "$1 already exists!"
      cd $1
  else
      mkdir -p $1 && cd $1
  fi
                 }

# lsに色をつける
export LSCOLORS=gxfxcxdxbxegedabagacad
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion:*' list-colors 'di=34' 'ln=35' 'so=32' 'ex=31' 'bd=46;34' 'cd=43;34'

# グロッピング（シェルが * ? {} [] ~ などの文字列を解釈し、ファイル名として展開すること）を防ぐ
setopt nonomatch
unsetopt nomatch

# 環境変数PATHの重複回避
typeset -gU PATH

# rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
# pyenv
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
export PYTHONIOENCODING=utf-8

# 自作コマンドのパス
export PATH="$HOME/dotfiles/.my_commands:$PATH"
