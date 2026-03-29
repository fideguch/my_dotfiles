# my_dotfiles

Personal dotfiles for macOS (Apple Silicon). A terminal environment centered around zsh, Vim, and Starship.

## Setup

```bash
git clone https://github.com/fideguch/my_dotfiles.git ~/my_dotfiles
cd ~/my_dotfiles
chmod +x set_up.sh
./set_up.sh
```

The script automatically sets up Homebrew, Brewfile packages, symlinks, and vim-plug.

After setup:
```bash
vim +PlugInstall +qall                    # Vim plugins
$(brew --prefix)/opt/fzf/install          # fzf keybindings (first time only)
```

## File Structure

| File | Description |
|---|---|
| `.zshrc` | Zsh config (history, completion, aliases, PATH) |
| `.vimrc` | Vim config (plugins, keymaps) |
| `starship.toml` | Starship prompt |
| `Brewfile` | Homebrew package list |
| `.my_commands/` | Custom commands |
| `.vim/` | Vim color scheme, vim-plug |
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
| `v`, `vi` | vim | |
| `vz` | vim ~/.zshrc | Edit config |
| `vv` | vim ~/.vimrc | Edit config |
| `sovz` | source ~/.zshrc | Reload config |
| `g` | git | |
| `d` / `dc` | docker / docker-compose | |
| `cc` | claude | Claude Code |
| `ccc` | claude --continue | Continue previous session |
| `ccr` | claude --resume | Resume session |
| `mkcd <dir>` | mkdir + cd | Create directory & cd into it |

## Vim Keymaps

| Key | Action |
|---|---|
| `Ctrl+e` | Toggle NERDTree |
| `Ctrl+n` | File search (fzf) |
| `Ctrl+p` | Buffer list (fzf) |
| `Ctrl+z` | Recent files (fzf) |
| `Ctrl+g` | Grep search (ripgrep) |
| `Tab+l/h` | Tab navigation |

## Pokemon Background (iTerm2)

Displays Pokemon as iTerm2 background using [Pokemon-Terminal](https://github.com/LazoCoder/Pokemon-Terminal).
Automatically switches via `preexec` hook when launching Claude Code.

| State | Pokemon |
|---|---|
| Normal | Darkrai |
| During Claude Code | Zoroark |

```bash
poke -n darkrai  # Switch to Darkrai
poke 150         # Mewtwo
poke             # Random from all Pokemon
```

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
- **iTerm2**: Checks app existence before setup

Re-run after `git pull` to safely apply configuration updates.

## Updating

```bash
cd ~/my_dotfiles && git pull
brew bundle install --file=Brewfile
vim +PlugUpdate +qall
```

## Requirements

- macOS (Apple Silicon)
- [Nerd Font](https://www.nerdfonts.com) (for icon display)
