**Two Worlds Dark** — prototype v1.1

A dark-fantasy souls-like where every place exists twice:

- **The Veil** (exploration): a faded, pixel-art world seen from a fixed 2D-style camera.
- **The Flesh** (combat): when a foe sees you, the Veil tears and the world becomes sharp, realistic 3D.

Everything — textures, character models, animations, sprites, sounds and music — is generated in code.
There are no imported assets.

## What's in v1.1

- **Story & cutscenes**: a Dark Souls–style prologue, then a Bloodborne-style awakening with the Veilkeeper,
  a blood pool and something that crawls out of it. A boss entrance, a victory and an ending. Cutscenes can be skipped (press E twice).
- **A full level**: Waking Chapel → Corridor of Whispers → Hall of Arms → Vestibule lantern → Ashen Graveyard →
  Steps of the Pale Cathedral → the white fog → the Sanctum of the Sundered Gate → the Gate itself (end of level).
- **Souls-style tutorial**: glowing messages on the ground (press E to read), lanterns that act as checkpoints,
  Blood Vials, "YOU DIED", and the dead return when you rest.
- **Choose your weapon** in the Hall of Arms: Hunter's Longsword (balanced), Ashen Greataxe (slow, brutal),
  Twin Fangs (fast daggers). Taking one wakes the dead in the hall, and the gate stays shut until they fall.
- **Enemies**: husks (swing + lunge) and a brute (overhead smash + sweep). Every attack is telegraphed: the weapon flares red.
- **Boss — Morvaith, the Pale Warden**: cleave, sweep, dashing thrust and a leap slam. At half health he enters phase 2:
  faster, red, with a three-hit combo and a blood nova. His poise breaks under heavy hits, and he turns slowly, so get behind him.
- **Characters**: jointed 3D models (hunter, husk, brute, warden, Veilkeeper, beast), each animated with keyframed and
  procedural animations: walk cycles, rolls, light/heavy combos per weapon, staggers, deaths, healing, rising, roars. Weapons leave trails.
- **Two texture sets**: stone, brick, cobble, earth, wood, iron, marble and moss each have an HD version with normal maps (the Flesh)
  and a 4-tone dithered pixel version (the Veil). The pixel sprites are rasterised from the same 3D rig, so both worlds animate in sync.
- Title screen, pause menu, area titles, boss bar, hitstop, camera shake, procedural sound and music.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Rotate / tilt camera (both worlds) | Mouse (click the window to grab it) or arrow keys | Right stick |
| Zoom | Mouse wheel or + / - | |
| Roll | Space | B |
| Light attack | J / Left mouse | X |
| Heavy attack | K / Right mouse | Y |
| Lock on | Q | R3 |
| Drink Blood Vial | F | LB |
| Interact / read / rest | E | A |
| Pause | Esc | Start |

## Running

Open the project in Godot 4.7 and press Play (main scene: `scenes/main.tscn`).

## Tests

- `godot --headless res://tests/test_game.tscn` plays the whole level automatically, from the title through the boss to the ending, and checks every step.
- `tests/tour.tscn`, `tests/pose_gallery.tscn` and `tests/bench.tscn` are dev tools that save screenshots and timings (they need a display).

vibe coded.

ver1.1
