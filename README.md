# Spider City / v0.1 Foundation

## September 25 city and traversal update

**F** on the title screen opens free roam: 900 × 900m city, 320 buildings, 280 walking pedestrians and batched street detail. Movement adds assisted real-surface web targeting, swing hand IK, release tricks and short upward wall runs. See [results and known limits](docs/DEVELOPMENT_V2.md). Linux launch: `./run-linux.sh`.

## September 24 traversal slice

Open `project.godot` with Godot **4.7.2**, then run. Press **T** on the title screen for the compact Flow Block; **Tab** returns to the main city. **LMB/RMB = web/zip**, **J/K = combat**; **F2** switches to the original mouse-combat layout below. Shift/Q still work. **R** restarts the practice block.

Portable GLB import needs no Blender installation. The original Blender source is preserved. See [development results, tests, tasks and asset audit](docs/DEVELOPMENT_HANDOFF.md).

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
The default shuffle-bag playlist uses five original jungle / drum & bass tracks:
- Rooftop Static
- Highrise Rush
- Factory Pressure
- Concrete Tricks
- Redline Pursuit

Concrete Canopy, Neon Underpass and Bridge Velocity remain available in the inactive legacy pool. Tracks crossfade without changing the saved Music bus volume.

Press **O** on the title screen for Audio Settings.
The game exposes persistent sliders for:
- Master Volume
- Music
- SFX

Audio values are saved to `user://audio_settings.cfg`.

### Graphics pass

Default rendering now uses Forward+ with 4x MSAA, ambient occlusion, warm sunlight, procedural masonry/glass and raised facade trims. See [graphics validation](docs/GRAPHICS_PASS.md). For older GPUs, start `./run-linux.sh --rendering-method gl_compatibility`.

### Civilians and character animation

See [the character motion pass](docs/CHARACTER_MOTION_PASS.md) for the new crowd presentation, athletic run cycle, animation transitions, validation and remaining limitations.

### Movement transitions

The controlled character now has 24 runtime animation states. [SM2 reference and transition pass](docs/SM2_MOTION_REFERENCE.md) records the eight new actions, 58 passing checks, rendered demonstration and remaining scope.

### Skyline Flight — playable update

Press **F** at the menu, then **H** for the seven-gate rooftop flight route. **E** toggles glide, **Ctrl** dives, and **LMB/RMB** reconnect web/zip. **Space** uses a contextual vault pose at low obstacles. [Build notes and validation](docs/SKYLINE_FLIGHT_BUILD.md); [actual gameplay recording](docs/validation/skyline-flight-gameplay.mp4).
