# ==========================================================
# .zshrc
# ==========================================================

# ── 基本設定 ──────────────────────────────────────────────

# バックスペースの文字化け防止
stty erase '^?'

# Ctrl+Dでログアウトしてしまうことを防ぐ
setopt IGNOREEOF

# 日本語を使用
export LANG=ja_JP.UTF-8

# デフォルトエディタ (git commit, crontab 等で使用)
export EDITOR=nvim
export VISUAL=nvim

# colors関数を読み込む
autoload -Uz colors
colors

# ── PATH管理 (重複自動排除) ──────────────────────────────
typeset -gU PATH path

# Homebrew (Apple Silicon)
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && path=("$PYENV_ROOT/bin" $path)
command -v pyenv >/dev/null && eval "$(pyenv init -)"

# nodebrew
[[ -d "$HOME/.nodebrew/current/bin" ]] && path=("$HOME/.nodebrew/current/bin" $path)

# その他のパス
path=(
  "$HOME/.local/bin"
  "$HOME/my_dotfiles/.my_commands"
  "$HOME/bin"
  "/opt/homebrew/share/google-cloud-sdk/bin"
  $path
)

# ── 補完 ──────────────────────────────────────────────────
autoload -Uz compinit
# 補完キャッシュを1日1回だけ再構築 (起動高速化)
if [[ -n "$HOME/.zcompdump"(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# 補完後、メニュー選択モードになり左右キーで移動が出来る
zstyle ':completion:*:default' menu select=2
# 補完で大文字にもマッチ
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|=*' 'l:|=* r:|=*'
# 補完候補に色を付ける
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# 補完をキャッシュ
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "$HOME/.zsh/cache"

# ── キーバインド ──────────────────────────────────────────

# emacsキーバインド
bindkey -e

# backspace, deleteキーを使えるように
bindkey "^[[3~" delete-char

# Ctrl+rでヒストリーのインクリメンタルサーチ、Ctrl+sで逆順
bindkey '^r' history-incremental-pattern-search-backward
bindkey '^s' history-incremental-pattern-search-forward

# コマンドを途中まで入力後、historyから絞り込み
# 例: ls まで打ってCtrl+pでlsコマンドをさかのぼる、Ctrl+bで逆順
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^b" history-beginning-search-forward-end

# Ctrl+sのロック, Ctrl+qのロック解除を無効にする
setopt NO_FLOW_CONTROL

# ── ヒストリ ─────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

# 他のターミナルとヒストリーを共有
setopt SHARE_HISTORY
# ヒストリーに重複を表示しない
setopt HIST_IGNORE_ALL_DUPS
# スペースで始まるコマンドは保存しない (一時的なコマンド用)
setopt HIST_IGNORE_SPACE
# 余分な空白を削除して保存
setopt HIST_REDUCE_BLANKS
# 履歴展開時に確認してから実行
setopt HIST_VERIFY
# タイムスタンプ付きで保存
setopt EXTENDED_HISTORY

# ── ディレクトリ移動 ─────────────────────────────────────

# cdコマンドを省略して、ディレクトリ名のみの入力で移動
setopt AUTO_CD
# 自動でpushdを実行
setopt AUTO_PUSHD
# pushdから重複を削除
setopt PUSHD_IGNORE_DUPS

# cdrコマンドを有効 ログアウトしても有効なディレクトリ履歴
# cdr タブでリストを表示
autoload -Uz add-zsh-hook
autoload -Uz chpwd_recent_dirs cdr
add-zsh-hook chpwd chpwd_recent_dirs
zstyle ":chpwd:*" recent-dirs-default true

# cdの後にlsを実行
chpwd() { ls -ltrG }

# ── シェルオプション ─────────────────────────────────────

# コマンドミスを修正
setopt CORRECT
# インタラクティブシェルでコメントを許可
setopt INTERACTIVE_COMMENTS
# グロッピングでマッチしなくてもエラーにしない
setopt NONOMATCH
unsetopt NOMATCH

# ── エイリアス ────────────────────────────────────────────

# ls (macOSでは -G でカラー表示)
alias ls='ls -G'
alias la='ls -laG'
alias ll='ls -lG'

# ファイル操作 (安全装置)
alias cp='cp -i'
alias rm='rm -i'
alias mkdir='mkdir -p'

# ショートカット
alias so='source'
alias sovz='source ~/.zshrc'
alias v='nvim'
alias vi='nvim'
alias vz='nvim ~/my_dotfiles/.zshrc'
alias vv='nvim ~/my_dotfiles/.vimrc'
alias vn='nvim ~/my_dotfiles/nvim/'
alias oldvim='command vim'
alias c='cat'
alias g='git'
alias d='docker'
alias dc='docker-compose'
alias py='python'
alias mkd='mkdir'
alias tou='touch'

# ディレクトリ移動
alias ..='cd ..'
alias cdd='cd ~/Desktop/start'
alias cdlearn='cd ~/Desktop/Folders/Learn'
alias cdw='cd ~/Desktop/start/work'
alias cddev='cd ~/Products'
alias back='pushd'
alias cdtemp='cd $TEMPDIR'

# ネットワーク
alias ifcon='ifconfig'

# historyに日付を表示
alias h='fc -lt "%F %T" 1'
alias diff='diff -U1'

# 256色カラーパレット表示
alias colorls='for c in {000..255}; do echo -n "\e[38;5;${c}m $c" ; [ $(($c%16)) -eq 15 ] && echo;done;echo'

# Claude Code
alias cc='claude'
alias ccc='claude --continue'
alias ccr='claude --resume'
alias ccf='claude --dangerously-skip-permissions'
alias ccfc='claude --continue --dangerously-skip-permissions'
alias ccfr='claude --resume --dangerously-skip-permissions'
alias ccp='claude --print'

# ── 関数 ──────────────────────────────────────────────────

# mkdirとcdを同時実行
function mkcd() {
  if [[ -d $1 ]]; then
    echo "$1 already exists!"
    cd $1
  else
    mkdir -p $1 && cd $1
  fi
}

# 複数ファイルのmv 例: zmv *.txt *.txt.bk
autoload -Uz zmv
alias zmv='noglob zmv -W'

# ── 区切り文字 ────────────────────────────────────────────
autoload -Uz select-word-style
select-word-style default
zstyle ':zle:*' word-chars "_-./;@"
zstyle ':zle:*' word-style unspecified

# ── 見た目 ────────────────────────────────────────────────

# ls色: 背景画像に映える太字白ベース (黄色背景で見えるようシアン/青を回避)
# di=ディレクトリ(太字白), ln=シンボリックリンク(太字マゼンタ), ex=実行ファイル(太字赤)
export LSCOLORS=Hxfxhxdxbxhghdhbhgbchd
export LS_COLORS='di=1;37:ln=1;35:so=1;37:pi=1;37:ex=1;31:bd=1;37:cd=1;37:su=1;37:sg=1;37:tw=1;37:ow=1;37'
zstyle ':completion:*' list-colors 'di=1;37' 'ln=1;35' 'so=1;37' 'ex=1;31'

# プロンプト (Starship)
eval "$(starship init zsh)"

# ── fzf ───────────────────────────────────────────────────
if [[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]]; then
  source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
  source /opt/homebrew/opt/fzf/shell/completion.zsh
fi

# ── ポケモン背景 (iTerm2 / cmux/Ghostty) ────────────────────
# 新規シェル起動時のみランダム選出。source での再読み込み時は実行しない。
# `poke -n <name>` で手動変更可能。
if [[ -o interactive && -z "$_POKE_DONE" ]] \
   && [[ "$TERM_PROGRAM" == "iTerm.app" || "$TERM_PROGRAM" == "ghostty" ]] \
   && command -v pokemon &>/dev/null; then
  _poke_favorites=(
    gliscor froslass butterfree exploud volbeat poochyena starmie
    woobat swalot blastoise aurorus grumpig diggersby klink pangoro
    arbok pidove palkia dustox registeel spheal suicune mightyena
  )
  poke -n "${_poke_favorites[RANDOM % ${#_poke_favorites[@]} + 1]}"
  unset _poke_favorites
  typeset -g _POKE_DONE=1
fi

# Resize handler: re-prepare background at new dimensions
if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
  TRAPWINCH() {
    local current
    current=$(cat ~/.cache/poke-current 2>/dev/null)
    [[ -n "$current" ]] && poke -n "$current" 2>/dev/null
  }
fi


# bun completions
[ -s "/Users/fumito_ideguchi/.bun/_bun" ] && source "/Users/fumito_ideguchi/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ── iTerm2 Shell Integration ────────────────────────────────
# ペイン分割時のCWD引き継ぎ、コマンドマーカー等を提供
[[ "$TERM_PROGRAM" == "iTerm.app" ]] \
  && [[ -f "$HOME/.iterm2_shell_integration.zsh" ]] \
  && source "$HOME/.iterm2_shell_integration.zsh"
