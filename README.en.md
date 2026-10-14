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
| `LaunchAgents/` | macOS launchd plists (bochi S3 safety net & weekly health check) |
| `pokemon-terminal/` | Pokemon Terminal skin (starship / MOTD / LazyVim / Claude Code), see [pokemon-terminal/README.md](pokemon-terminal/README.md) |
| `claude/` | Full Claude Code config (symlinked into `~/.claude/`) |
| `codex/` | Codex CLI config (`config.template.toml` → `~/.codex/config.toml`) |
| `set_up.sh` | Setup script |

## Custom Commands (.my_commands/)

| Command | Description |
|---|---|
| `pokels [-n name] [-t type] [-r region] [-e]` | List Pokemon (with base stats) |
| `pokefind <name> [-t type] [-r region] [-s stats]` | Reverse Pokemon search (Japanese/English, base stats) |
| `poke [args]` | Change wallpaper + show Pokedex info. `poke 150` `poke -n gengar` etc. |
| `mka <name> <cmd>` | Add alias to .zshrc. `mka gs 'git status'` |
| `gccw <file>` | `gcc -Wall -Wextra -Werror` wrapper |
| `ssh-tcc-doctor [--fix]` | Diagnose/guide the macOS TCC `Operation not permitted` failure over SSH |
| `lidwork [on\|off\|status]` | Keep the MacBook awake with the lid closed (see [below](#lid-closed-mode-lidwork)) |
| `design-md [list\|<brand>\|update]` | Fetch a brand's `DESIGN.md` from [awesome-design-md](https://github.com/VoltAgent/awesome-design-md) into the current directory |

## Lid-Closed Mode (lidwork)

Without an external display, macOS force-sleeps on lid close, and `caffeinate` cannot prevent it. `lidwork` is a safe wrapper around `sudo pmset disablesleep 1|0`, so local Claude Code work keeps running with the lid closed.

```bash
lidwork on       # Do not sleep on lid close (sudo; asks first when on battery)
lidwork off      # Restore normal sleep behavior
lidwork          # Show the current state
```

| Component | Location |
|---|---|
| Command | `.my_commands/lidwork` (on PATH via `.zshrc`) |
| Startup warning | `.zshrc` — new shells print "⚠️ lidwork ON" while it is still enabled |
| Claude Code skill | `claude/skills/lidwork/` (triggers on "lidwork", "keep awake", "lid close", etc.) |

- The setting **survives reboots**. Always run `lidwork off` when done
- While ON, **do not put the Mac in a bag** (it cannot shed heat) and **keep it on AC power**
- Claude's shell has no TTY, so it cannot type the sudo password. To let Claude toggle it directly, set up `/etc/sudoers.d/lidwork` yourself with NOPASSWD limited to `pmset disablesleep 1|0` (steps in `claude/skills/lidwork/SKILL.md`)

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
| `claude/rules/` | Coding standards (common + python / swift / typescript) |
| `claude/agents/` | Specialized sub-agents (17) |
| `claude/skills/` | Task-specific skills (34) |
| `claude/scripts/` | Automation hooks (`scripts/hooks/`) and the npx skill sync script |
| `claude/commands/` | Custom slash commands |

> Sensitive files (`settings.local.json`, `mcp-configs/`) are excluded via `.gitignore`.
> See `claude/settings.local.template.json` for the template.

### 3-Layer Architecture

The Claude Code environment is managed across 3 layers. On a new machine, run `set_up.sh` first, then manually install Layer 3.

**Layer 1: dotfiles (this repo)** -- symlinked by `set_up.sh`

Contains ECC (Everything Claude Code) skills, small self-made skills (lidwork, etc.), rules, agents, commands, and hooks. This repository directly includes 17 agents and 34 skills.

**Layer 2: Self-made GitHub repos** -- auto-cloned by `set_up.sh`

`set_up.sh` clones skill repositories from `fideguch/` and places them under `~/.claude/skills/`.

| Skill | Repository | Location |
|-------|-----------|----------|
| bochi | fideguch/bochi | `~/.claude/skills/bochi` (direct clone) |
| pm-data-analysis | fideguch/pm-data-analysis | `~/.claude/skills/pm-data-analysis` (direct clone) |
| speckit-bridge | fideguch/speckit-bridge | `~/.claude/skills/speckit-bridge` (direct clone) |
| my_pm_tools | fideguch/my_pm_tools | `~/.claude/skills/my_pm_tools` (direct clone) |
| figma-refine | fideguch/figma-refine | `~/.claude/skills/figma-refine` (direct clone) |
| claude-to-codex | fideguch/claude-to-codex | `~/.claude/skills/claude-to-codex` (direct clone) |
| fable-for-opus | fideguch/fable-for-opus | `~/.claude/skills/fable-for-opus` (direct clone) |
| model-director | fideguch/model-director | `~/.claude/skills/model-director` (direct clone) |
| pm-ad-analysis | fideguch/pm_ad_analysis | `~/pm_ad_analysis` → symlink |
| google-workspace | fideguch/google-workspace | `~/google_mcps/google-workspace` → symlink |
| pokemon-champions | fideguch/ai-pokemen | `~/ai-pokemen` → symlink |
| mobile-dev-bridge | fideguch/mobile-dev-bridge | `~/mobile-dev-bridge` → symlink |
| specs-evals | fideguch/specs-evals | `~/specs-evals` → symlink |
| requirements_designer | fideguch/requirements_designer | `~/.agents/skills/` → via npx skills (same as Layer 3) |

> Note: `pm-ad-operations` has been merged into `pm-ad-analysis` and no longer exists as a separate skill.

**Layer 3: External skills** -- manual install (list in `~/.agents/.skill-lock.json`)

Installed via `npx skills add`: PM skills (45+), Vercel Labs skills, official plugins (skill-creator, discord), etc. The full list lives in `~/.agents/.skill-lock.json`.

### Deployment Strategy

`set_up.sh` deploys files to `~/.claude/` using the following rules:

| Target | Method | Reason |
|------|------|------|
| `CLAUDE.md`, `settings.json` etc. | Per-file symlinks | Individual management |
| `rules/`, `agents/`, `commands/`, `scripts/` | Per-directory symlinks | Bulk management |
| `skills/` | **Per-skill merge** | Avoid breaking Layer 2/3 skills |

## bochi-data Bidirectional Sync (Mac ↔ S3 ↔ Discord/Lightsail)

Bidirectionally syncs the bochi skill's generated memos, topics, and newspapers (`~/.claude/bochi-data/`) between the Mac CLI and the Discord bot (Lightsail), via S3 (`bochi-sync-fumito`, `ap-northeast-1`).

### Sync script layout

Six scripts under `claude/scripts/hooks/bochi-s3-*.sh` plus two launchd agents:

| Script | Role | Trigger |
|--------|------|---------|
| `bochi-s3-push.sh` | Push bochi-data Write/Edit to S3 immediately (async). Logs failures; macOS notification at 3+/h | PostToolUse(Write\|Edit) hook |
| `bochi-s3-pull.sh` | Pull from S3 on session start | SessionStart hook |
| `bochi-s3-pull-on-read.sh` | Pull from S3 before Read/Grep (5s debounce) | PreToolUse(Read\|Grep) hook |
| `bochi-s3-safety-push.sh` | Redundant 10-min push (covers hook bypass such as bash redirects) | launchd `StartInterval=600` |
| `bochi-s3-safety-pull.sh` | Redundant 5-min cron pull (1-min offset) | cron `1-56/5 * * * *` |
| `bochi-s3-healthcheck.sh` | Monday 09:00 JST round-trip test over SSH to Lightsail | launchd `StartCalendarInterval` |

All hook bindings are consolidated in `claude/settings.json` under the `hooks` key. launchd plists live in `LaunchAgents/com.fideguch.bochi-*.plist`; enable them with `launchctl load -w` (details in `claude/scripts/hooks/README-launchd.md`).

### Write Ownership

To avoid push conflicts, the scripts split directory ownership by `uname`:

| Environment | Owns (push only) |
|-------------|------------------|
| Mac (`Darwin`) | `memos/`, `index.jsonl`, `context-seeds/` |
| Lightsail (`Linux`) | `topics/`, `newspaper/`, `conversations/`, `reflections/`, `seen.jsonl`, `sources/`, `stats/`, `user-profile.yaml`, `cache/` |

### Known issues and fixes (2026-04-30)

- **BUG-1: `find` does not follow symlinks** → On Lightsail, `~/.claude/bochi-data` is a symlink, so `find` returned empty and the push was silently halted for 3+ weeks. Fixed by switching to `find -L`
- **BUG-2: same-size/different-content files were skipped by `aws s3 sync`** → Added `--exact-timestamps` to all pull scripts so mtime is also compared
- **Nested-structure recurrence guard (`bochi-data/bochi-data/`)** → Added a pre-flight check to every sync script. On detection, emits a WARNING to stderr (sync continues; user is prompted to `rm -rf`)

## Re-run Safety (Idempotency)

`set_up.sh` is safe to run multiple times:

- **Homebrew**: Checks existence with `command -v brew`, skips if already installed
- **Brewfile**: `brew bundle install` is idempotent (skips already-installed packages)
- **Symlinks**: Existing links are removed and recreated; regular files are backed up with timestamp before linking
- **Directories**: `mkdir -p` does nothing if already exists
- **vim-plug**: Checks existence before installing
- **Neovim/LazyVim**: Symlinks `nvim/` directory, runs headless `Lazy! sync` (failure doesn't abort script)
- **Claude Code self-made skills / awesome-design-md**: Skips the clone if the destination already exists
- **Codex CLI**: Generates `codex/config.toml` from the template only when missing, then links it to `~/.codex/config.toml`
- **Ghostty/cmux**: Config is copied; the background is seed-copied (runtime state); cmux defaults script is run
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
