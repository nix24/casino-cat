# Casino Cat

A free roguelike about a gambling-addicted tuxedo cat climbing a neon city. Pick a path on a
branching map, fight one-on-one with a card-suit type triangle, and decide when to roll the dice.

Status: **M0 scaffold**. Gameplay starts at M1.

## Run it

Requirements:
- Godot 4.7.2 (official build).
- For linting: `gdtoolkit` 4.5+ (`uv tool install gdtoolkit`).

```bash
godot --path . --editor        # open in the editor
godot --path .                 # run the game
scripts/export_web.sh --serve  # web build at http://127.0.0.1:8060
```

## Credits

See [`CREDITS.md`](CREDITS.md).
