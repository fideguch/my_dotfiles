# Terminal Pokemon Background

## Command

Change the terminal background Pokemon at any time:

```bash
poke -n <pokemon_name>   # by name (e.g., gliscor, froslass, gengar)
poke <pokedex_number>    # by Pokedex ID (e.g., 472)
poke                     # random
poke --clear             # remove background (Ghostty/cmux only)
```

## Supported Terminals

| Terminal | Backend | Detection |
|----------|---------|-----------|
| iTerm2 | AppleScript via pokemon-terminal | `$TERM_PROGRAM == "iTerm.app"` |
| cmux (Ghostty) | Kitty graphics protocol (z=-1) | `$TERM_PROGRAM == "ghostty"` |

Both terminals work in parallel. The `poke` command auto-detects which backend to use.

## Resize Handling (cmux/Ghostty)

Window resize triggers `TRAPWINCH` in `.zshrc`, which re-runs `poke` with the
saved Pokemon name from `~/.cache/poke-current`. This redraws the background
image at the new terminal dimensions.

## When to Use

- User asks to change the terminal background / Pokemon
- User says "poke" or references a Pokemon for the background

## Notes

- Default Pokemon on shell startup: random from curated favorites (see .zshrc)
- iTerm2: uses AppleScript (pokemon-terminal default behavior)
- cmux/Ghostty: uses Kitty graphics protocol with z=-1 (behind text)
  - Workaround for cmux CAMetalLayer opacity bug (cmux/issues/1674)
  - When cmux fixes native background-image, switch to config-file approach
- Current Pokemon saved to `~/.cache/poke-current` for resize redraw
