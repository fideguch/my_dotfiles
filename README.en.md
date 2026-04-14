# my_dotfiles

Personal dotfiles for macOS (Apple Silicon). A terminal environment centered around zsh, Neovim (LazyVim), and Starship.

## Setup

```bash
git clone https://github.com/fideguch/my_dotfiles.git ~/my_dotfiles
cd ~/my_dotfiles
chmod +x set_up.sh
./set_up.sh
```

The script automatically sets up Homebrew, Brewfile packages, symlinks, LazyVim, and vim-plug.

After setup:
```bash
nvim                                      # LazyVim first launch (auto-installs plugins)
$(brew --prefix)/opt/fzf/install          # fzf keybindings (first time only)
```

## File Structure

| File | Description |
|---|---|
| `.zshrc` | Zsh config (history, completion, aliases, PATH) |
| `nvim/` | **Neovim (LazyVim) config** (primary editor) |
| `.vimrc` | Vim config (legacy fallback) |
| `starship.toml` | Starship prompt |
| `Brewfile` | Homebrew package list |
| `.my_commands/` | Custom commands |
| `.vim/` | Vim color scheme, vim-plug |
| `ghostty/` | Ghostty/cmux config (Japanesque theme, font, keybindings) |
| `cmux/` | cmux macOS defaults script |
| `iterm2/` | iTerm2 Pokemon profile |
| `set_up.sh` | Setup script |

## Custom Commands (.my_commands/)

| Command | Description |
|---|---|
| `pokels [-n name] [-t type] [-r region] [-e]` | List Pokemon (with base stats) |
| `pokefind <name> [-t type] [-r region] [-s stats]` | Reverse Pokemon search (Japanese/English, base stats) |
| `poke [args]` | Change wallpaper + show Pokedex info. `poke 150` `poke -n gengar` etc. |
| `mka <name> <cmd>` | Add alias to .zshrc. `mka gs 'git status'` |
| `gccw <file>` | `gcc -Wall -Wextra -Werror` wrapper |

## Key Aliases

| Alias | Command | Note |
|---|---|---|
| `v`, `vi` | nvim | Primary editor |
| `vz` | nvim ~/.zshrc | Edit config |
| `vv` | nvim ~/.vimrc | Edit config |
| `vn` | nvim ~/my_dotfiles/nvim/ | Edit LazyVim config |
| `oldvim` | command vim | Legacy Vim fallback |
| `sovz` | source ~/.zshrc | Reload config |
| `g` | git | |
| `d` / `dc` | docker / docker-compose | |
| `cc` | claude | Claude Code |
| `ccc` | claude --continue | Continue previous session |
| `ccr` | claude --resume | Resume session |
| `ccf` | claude --dangerously-skip-permissions | Skip permissions |
| `ccp` | claude --print | Non-interactive mode |
| `mkcd <dir>` | mkdir + cd | Create directory & cd into it |

## Editor Keymaps

Same keybindings work in both Neovim (LazyVim) and legacy Vim (muscle memory preserved).

| Key | Action | Neovim | Legacy Vim |
|---|---|---|---|
| `Ctrl+e` | File tree toggle | Neo-tree | NERDTree |
| `Ctrl+n` | File search | Telescope | fzf |
| `Ctrl+p` | Buffer list | Telescope | fzf |
| `Ctrl+z` | Recent files | Telescope | fzf |
| `Ctrl+g` | Grep search | Telescope (live_grep) | fzf (ripgrep) |
| `Tab+l/h` | Tab navigation | shared | shared |

### LazyVim-specific Keys

| Key | Action |
|---|---|
| `Space` | which-key menu (entry point for all commands) |
| `<leader>gg` | lazygit |
| `<leader>ha` / `<leader>1-4` | Harpoon (fast file jump) |
| `<leader>pk` | Change Pokemon background |
| `gd` / `gr` / `K` | Go to definition / references / hover docs (LSP) |
| `<leader>cf` | Format file |

## Pokemon Background (iTerm2 / cmux / Neovim)

Displays Pokemon as terminal background using [Pokemon-Terminal](https://github.com/LazoCoder/Pokemon-Terminal).
On terminal startup, randomly selects from a curated list of 22 dark-toned Pokemon.

```bash
poke -n gliscor  # Switch to Gliscor
poke 150         # Mewtwo
poke             # Random from all Pokemon
poke --clear     # Clear background (cmux only)
```

### Neovim Integration

Neovim (LazyVim) uses catppuccin-mocha with `transparent_background = true`, so the Pokemon terminal background shows through the editor. The dashboard displays the current Pokemon name on startup. Press `<leader>pk` to change Pokemon from within Neovim.

> You can also change the background during a Claude Code session via the `poke` command.

## Claude Code (`claude/`)

Full Claude Code configuration. `set_up.sh` creates symlinks to `~/.claude/`.

| Directory | Description |
|---|---|
| `claude/CLAUDE.md` | Global config (language, stack, workflow) |
| `claude/rules/` | Coding standards (common + 10 languages) |
| `claude/agents/` | Specialized sub-agents (28) |
| `claude/skills/` | Task-specific references (48) |
| `claude/hooks/` | Automation hooks (pre/post-tool) |
| `claude/commands/` | Custom commands |

> Sensitive files (`settings.local.json`, `mcp-configs/`) are excluded via `.gitignore`.
> See `claude/settings.local.template.json` for the template.

### 3-Layer Architecture

The Claude Code environment is managed across 3 layers. On a new machine, run `set_up.sh` first, then manually install Layer 3.

**Layer 1: dotfiles (this repo)** -- symlinked by `set_up.sh`

Contains ECC (Everything Claude Code) skills, rules, agents, commands, and hooks. This repository directly includes 28 agents and 48 skills.

**Layer 2: Self-made GitHub repos** -- auto-cloned by `set_up.sh`

`set_up.sh` clones skill repositories from `fideguch/` and places them under `~/.claude/skills/`.

| Skill | Repository | Location |
|-------|-----------|----------|
| bochi | fideguch/bochi | `~/.claude/skills/bochi` (direct clone) |
| pm-data-analysis | fideguch/pm_data_analysis | `~/.claude/skills/pm-data-analysis` (direct clone) |
| pm-ad-analysis | fideguch/pm_ad_analysis | `~/pm_ad_analysis` → symlink |
| speckit-bridge | fideguch/speckit-bridge | `~/.claude/skills/speckit-bridge` (direct clone) |
| requirements_designer | fideguch/requirements_designer | `~/.agents/skills/` → via npx skills |
| google-workspace | fideguch/google-workspace | `~/google_mcps` → symlink |

> Note: `pm-ad-operations` has been merged into `pm-ad-analysis` and no longer exists as a separate skill.

**Layer 3: External skills** -- manual install (see `INSTALL_SKILLS.md`)

Installed via `npx skills add`: PM skills (45+), Vercel Labs skills, official plugins (skill-creator, discord), etc. See `claude/INSTALL_SKILLS.md` for full details.

### Deployment Strategy

`set_up.sh` deploys files to `~/.claude/` using the following rules:

| Target | Method | Reason |
|------|------|------|
| `CLAUDE.md`, `settings.json` etc. | Per-file symlinks | Individual management |
| `rules/`, `agents/`, `hooks/`, `commands/` | Per-directory symlinks | Bulk management |
| `skills/` | **Per-skill merge** | Avoid breaking Layer 2/3 skills |

## Re-run Safety (Idempotency)

`set_up.sh` is safe to run multiple times:

- **Homebrew**: Checks existence with `command -v brew`, skips if already installed
- **Brewfile**: `brew bundle install` is idempotent (skips already-installed packages)
- **Symlinks**: Existing links are removed and recreated; regular files are backed up with timestamp before linking
- **Directories**: `mkdir -p` does nothing if already exists
- **vim-plug**: Checks existence before installing
- **Neovim/LazyVim**: Symlinks `nvim/` directory, runs headless `Lazy! sync` (failure doesn't abort script)
- **iTerm2**: Checks app existence before setup

Re-run after `git pull` to safely apply configuration updates.

## Updating

```bash
cd ~/my_dotfiles && git pull
brew bundle install --file=Brewfile
nvim --headless "+Lazy! sync" +qa        # LazyVim plugin update
vim +PlugUpdate +qall                    # Legacy Vim plugin update (optional)
```

## Requirements

- macOS (Apple Silicon)
- [Nerd Font](https://www.nerdfonts.com) (for icon display)
- Terminal: [cmux](https://www.cmux.dev/) (recommended) or [iTerm2](https://iterm2.com/)
- Pokemon background: `pip3 install --user git+https://github.com/LazoCoder/Pokemon-Terminal.git`
