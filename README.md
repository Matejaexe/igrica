# Spider City / v0.1 Foundation

Early Godot 4 prototype for the stylized PS2/Bomb-Rush-inspired co-op traversal game.

## New v0.1 foundation
- Title screen -> character select -> gameplay flow.
- Four temporary web-hero characters with different palettes.
- Full rotating 3D character preview in character select.
- Visible gameplay stats, movement style, special, strengths and weaknesses.
- Stats now modify real gameplay values (speed, acceleration, air control, swing, zip, combat damage, damage resistance).
- Shift web swing with momentum-preserving release, Q web zip, automatic wall ride, wall jump, missions, drones and city prototype.
- LMB combo and character-specific RMB specials; combat and defense stats affect gameplay.
- Procedural placeholder poses now cover running, jumping/falling, swing phases, release, zip, wall riding, wall jumping, combos and specials.
- Traversal-speed FOV, subtle wall camera roll, landing feedback and a temporary movement-state HUD aid playtesting.
- City blocks have varied dense, medium and larger gaps so swing routes require more deliberate lines.

## Temporary roster
- CRIMSON — Swing / Acrobat
- AZURE — Tech / Zip
- VIOLET — Trickster / Air
- GOLD — Bruiser / Power

These are placeholders and will later be replaced by original character concepts.

## Planned world
- MDK3 + Jerkovic: main connected landmass.
- MLD: smaller industrial island connected by bridge.
- Pancevo: smaller trick/skate/graffiti island connected by bridge.
- Zone streaming/loading transitions will be used where useful.

## Controls
- Enter: title -> character select / lock character
- A / D: change character in select
- WASD: movement
- Mouse: camera / aim
- Shift: web swing / pump
- Q: web zip
- Space: jump / wall jump / swing release
- LMB: normal attack / combo
- RMB: character-specific special


## Audio pass
Three original jungle / drum & bass tracks are included:
- Concrete Canopy
- Neon Underpass
- Bridge Velocity

Press **O** on the title screen for Audio Settings.
The game exposes persistent sliders for:
- Master Volume
- Music
- SFX

Audio values are saved to `user://audio_settings.cfg`.
