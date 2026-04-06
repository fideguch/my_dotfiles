# Terminal Pokemon Background

## Command

```bash
poke -n <pokemon_name>   # by name (e.g., gliscor, froslass, gengar)
poke <pokedex_number>    # by Pokedex ID (e.g., 472)
poke                     # random
poke --clear             # remove background
```

## Supported Terminals

| Terminal | Backend | Detection |
|----------|---------|-----------|
| iTerm2 | AppleScript via pokemon-terminal | `$TERM_PROGRAM == "iTerm.app"` |
| cmux (Ghostty) | config-file + `cmux themes set` reload | `$TERM_PROGRAM == "ghostty"` |

## cmux/Ghostty Implementation

### How It Works

1. Gets front window size via AppleScript (falls back to TIOCGWINSZ → cache)
2. Resizes image to match window dimensions (stretch, ignore aspect ratio)
3. Darkens to 15% brightness for text readability
4. Writes prepared image path to `~/.config/ghostty/background`
5. Triggers `cmux themes set <current_theme>` to reload config instantly
6. Background changes **immediately** (no restart needed)

### Key Discovery

`cmux themes set` triggers a full config reload including `background-image`.
This enables iTerm2-equivalent instant background changes.

### Resize Handling

TRAPWINCH in `.zshrc` re-runs `poke` with the current pokemon name
when the terminal is resized, re-preparing the image at new dimensions.

### Known Limitations

- `background-image` is global across all cmux windows (Ghostty limitation)
- When tabs are separated into multiple windows with different sizes,
  the image is sized for the front window; other windows may have slight gaps
- `background-image-fit/opacity/position` are NOT supported in cmux 0.63.1

## When to Use

- User asks to change the terminal background / Pokemon
- User says "poke" or references a Pokemon for the background

## Notes

- Default Pokemon on shell startup: random from curated favorites (see .zshrc)
- Prepared images cached at `~/.cache/poke-bg/`
- Current Pokemon saved to `~/.cache/poke-current`
- Window size cached at `~/.cache/poke-surface-size` (fallback for no-TTY)
