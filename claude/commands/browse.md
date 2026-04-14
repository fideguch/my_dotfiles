---
description: Open and manage browsers from terminal. Opens URLs, switches profiles, previews in w3m, manages Dia tabs.
---

# Browse Command

Terminal browser manager with profile switching, cookie-shared terminal preview, and Dia tab management.

## Usage

Execute the `browse` command from `~/my_dotfiles/.my_commands/browse` with the user's arguments.

### Common Patterns

```bash
# Open URL in default browser (Dia)
browse github.com

# Open in specific browser
browse -b brave github.com
browse -b safari github.com

# Profile management
browse -p work github.com          # Use profile alias
browse -p fumito github.com        # Fuzzy match profile name
browse --profiles                  # List available profiles

# Terminal preview (w3m with shared Dia cookies)
browse -v github.com               # Text preview in terminal
browse -s github.com               # Screenshot preview (imgcat)

# Browser picker (fzf)
browse -l                          # Interactive browser x profile picker

# Dia tab management
browse tabs                        # List all Dia tabs
browse tabs -s                     # Switch tab via fzf
browse tabs -c                     # Close tab via fzf

# Setup
browse --setup                     # Interactive setup wizard
```

## When to Use

- User asks to open a URL or website
- User wants to check what's open in Dia
- User wants to preview a page in the terminal
- User wants to switch browser profiles

## Implementation

The command is at `~/my_dotfiles/.my_commands/browse` (Python, already on PATH).
Config at `~/.config/browse/config.json`.

Run via Bash tool: `browse [args]`
