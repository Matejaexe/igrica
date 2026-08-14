# Spider City — Game Design

This document is the source of truth for future development. When implementation and older documentation disagree with this document, follow this document unless it is deliberately amended.

## Game Identity

- Stylized 3D urban action/platformer.
- Visual target: PS2-era low-poly games mixed with Bomb Rush Cyberfunk / Jet Set Radio energy.
- Strong colors, stylized character proportions, graffiti, and a cel-shaded feel.
- Movement and traversal are the primary gameplay pillar.
- Original characters will eventually replace the current Spider-Man-style placeholders.

## Player Controls

- WASD: fast default movement. There is no sprint button.
- Characters always move at a fast run/jog by default.
- Shift: web swing / web pump.
- Space: jump, wall jump, and swing release.
- Q: web zip.
- Left Mouse Button: normal attack / combo.
- Right Mouse Button: character-specific special attack.
- Mouse: camera and aiming.

## Movement

- Camera-relative movement.
- Physics-based web swing.
- Where the player attaches the web must strongly affect the swing trajectory.
- Preserve tangential momentum.
- Good swing release timing should reward the player with momentum.
- Wall jump is available to all characters.
- Add a Bomb Rush Cyberfunk-style wall ride / wall run:
  - If the player reaches a wall with sufficient speed and a valid approach angle, automatically transition into wall riding.
  - Preserve momentum.
  - Allow wall jump directly out of it.
  - Allow web swing directly out of it.
  - Losing speed causes the player to fall away from the wall.
- Some characters may additionally have wall-cling / wall-crawl as a unique ability.
- Future goal: more procedural swing poses and aerial tricks.
- Future goal: dual-web swinging.

## Characters

For now, keep four temporary Spider-Man-inspired placeholder characters in different colors. These will later be replaced by original concept-art characters.

Current archetypes:

1. CRIMSON — Swing / Acrobat
2. AZURE — Tech / Zip
3. VIOLET — Trickster / Air
4. GOLD — Bruiser / Power

All characters share the basic controls, but their actual movement parameters and special abilities should differ.

Character stats shown in character select:

- Speed
- Acceleration
- Swing
- Air Control
- Combat
- Defense

These stats must correspond to actual gameplay values, not just UI labels.

## Character Select

- Show the full 3D character model.
- The selected model slowly rotates automatically so the player can inspect the full model.
- Later, allow manual rotation and zoom.
- Show character name, archetype, stats, movement style, special ability, passive/strength, and weakness.
- Selecting or locking a character should eventually trigger a signature animation.

## World

The world is split into four named areas.

### Main Contiguous Map

MDK3 and Jerković are directly connected with no loading screen between them.

### MDK3

- Denser urban area.
- Buildings and rooftops closer together.
- Graffiti.
- Narrower streets.
- Strong BRC/JSR urban atmosphere.

### Jerković

- More vertical.
- Taller buildings.
- More open streets.
- Antennas and billboards.
- Larger swing routes.

### Side Island: MLD

- Industrial zone.
- Factories, warehouses, pipes, cranes, and rails.
- Industrial traversal and grind routes.

### Side Island: Pančevo

- Lower buildings.
- Open spaces.
- Ramps, tunnels, and skate/trick areas.
- Large graffiti walls.

MLD and Pančevo are connected to the main MDK3/Jerković landmass by bridges.

The bridges should eventually act as natural streaming/loading corridors. Prefer background streaming. A stylized loading transition is acceptable if streaming cannot finish in time.

## Graffiti

Future system inspired by gesture graffiti games:

- Approach a graffiti spot.
- Camera focuses on the wall.
- Player draws lines through nodes/points using mouse or controller.
- Small, Medium, and Large graffiti patterns.
- Scoring such as Perfect, Clean, or Messy.
- Character-specific graffiti sets.
- Multiplayer players may paint over each other's graffiti.
- Possible future graffiti editor.

## Multiplayer

Target: 2–4 player co-op.

Future flow:

Title Screen -> Host/Join -> Lobby -> Character Select -> Game.

Eventually:

- Synchronize character movement/state, HP, combat, grapple anchor, and rope state.
- Enemies and bosses should be host/server authoritative.
- Do not network every visual segment of the web.
- Players should be able to choose different characters.

## Lobby

The long-term goal is a physical 3D graffiti hideout where players can move around, select characters, graffiti, and missions, and ready up.

## Combat

- LMB: normal combo.
- RMB: character-specific special.
- Air attacks later.
- Characters should eventually have different combat strengths.
- Regular enemies plus minibosses.
- One large traversal-focused boss is a major goal.

## Boss Design

The main boss should make use of traversal rather than being only a stationary HP bar:

- Swinging around it.
- Avoiding attacks.
- Hitting weak points.
- Potentially using webs/grapples on parts of the boss.
- Designed to be fun in co-op.

## Animation

Long-term goal:

- Multiple swing poses depending on velocity, anchor location, and swing phase.
- One-hand and two-hand swings.
- Tuck, stretched pose, and dive.
- Flips, barrel rolls, and corkscrews.
- Landing animations.
- Procedural limb/torso adjustment according to the grapple point.

## Audio

- Jungle / DnB soundtrack direction.
- Existing original tracks remain.
- Audio settings must persist:
  - Master Volume
  - Music
  - SFX
- The SFX bus currently has no actual SFX; these will be added later.

## General Development Rules

- Work incrementally.
- Keep gameplay systems modular.
- Do not make one enormous `main.gd` indefinitely; gradually separate major systems into reusable scenes and scripts as the project grows.
- Keep placeholder art replaceable.
- Prefer data-driven character stats and configuration.
- Godot target is 4.7.x.
- Multiplayer must be considered in the architecture even before full networking is implemented.
