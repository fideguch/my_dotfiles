# iTerm2 Pokemon Background

## Command

Change the iTerm2 background Pokemon at any time:

```bash
poke -n <pokemon_name>   # by name (e.g., gliscor, froslass, gengar)
poke <pokedex_number>    # by Pokedex ID (e.g., 472)
poke                     # random
```

## When to Use

- User asks to change the terminal background / Pokemon
- User says "poke" or references a Pokemon for the background

## Notes

- Default Pokemon on shell startup: random from curated favorites (see .zshrc)
- The `poke` command sets the iTerm2 background image and prints Pokedex info
- Only works in iTerm2 (`$TERM_PROGRAM == "iTerm.app"`)
