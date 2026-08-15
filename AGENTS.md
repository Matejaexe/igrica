# Igrica — Codex Project Instructions

## Authority order

When instructions conflict, use this order:

1. The user's current explicit request.
2. `GAME_DESIGN.md` for established game-design decisions.
3. This `AGENTS.md`.
4. Detailed documents under `docs/codex/`.
5. Older README/comments/prototype behavior.

Do not silently change established game direction because the current prototype
happens to behave differently.

## Project identity

Igrica / working title **Spider City** is a Godot 4.7.x stylized 3D urban
traversal/action-platformer with future 2–4 player co-op.

The game's visual and movement DNA combines:

- PS2-era low-poly readability
- Bomb Rush Cyberfunk street-culture energy
- Jet Set Radio graffiti/cel-shaded urban attitude
- the physical, momentum-sensitive traversal philosophy of classic
  Spider-Man 2 (2004)
- comic-book readability and fast traversal ideas associated with
  Ultimate Spider-Man (2005)
- modern traversal polish only where it helps flow: seamless wall-run / swing /
  zip transitions and optional aerial trick presentation

These are references, not licenses to copy assets, characters, UI, maps,
animations, logos, or exact copyrighted designs.

The final game must develop its own identity.

## Read before relevant tasks

### Whole game / architecture
- `docs/codex/MASTER_GAME_VISION.md`
- `docs/codex/REFERENCE_DNA.md`
- `docs/codex/CODEX_WORKFLOW.md`

### Visuals / city / environment
- `docs/codex/VISUAL_STYLE_BIBLE.md`
- `docs/codex/CITY_WORLD_BIBLE.md`

### Character / animation / traversal
- `docs/codex/CHARACTER_RIG.md`
- `docs/codex/HUMAN_LOCOMOTION.md`
- `docs/codex/TRAVERSAL_AND_TRICKS.md`
- `docs/codex/GODOT_ANIMATION_NOTES.md`
- `docs/codex/ANIMATION_DEBUG_CHECKLIST.md`

### UI / menus / lobby
- `docs/codex/UI_MENU_BIBLE.md`
- `docs/codex/CHARACTERS_MULTIPLAYER.md`

### Graffiti / combat / audio
- `docs/codex/GRAFFITI_COMBAT_AUDIO.md`

### Research URLs
- `docs/codex/REFERENCES.md`

## Protected BRC Spider model

Known-good imported model:

```text
res://models/spidey/spidey_funk_alt_v2.glb
```

The current mesh/skin/rest/bind relationship is considered known-good.

DO NOT modify, regenerate, reskin, or replace this GLB unless explicitly asked.

Fix animation in the animation/retarget/IK/modifier layer.

## Current donor

```text
res://third_party/godot_platformer/player.glb
```

Prefer native Godot retargeting/modifiers where appropriate.

## Core movement philosophy

Movement is the primary gameplay pillar.

The player should enjoy moving through the city even with no mission active.

Priorities:

1. momentum
2. flow
3. readable player control
4. stylish animation
5. meaningful traversal choices
6. fast transitions between movement states
7. forgiving enough to learn, deep enough to master

Physics and animation have different jobs:

- physics determines where the player actually goes
- animation sells speed, weight, style, and intent

Do not let a cosmetic trick animation destroy earned momentum.

## Core controls

Established target:

```text
WASD   fast default movement; no sprint button
Shift  web swing / web pump
Space  jump / wall jump / swing release
Q      web zip
LMB    normal combo
RMB    character-specific special
Mouse  camera / aiming
```

## World

Main contiguous landmass:

```text
MDK3 <-> Jerković
```

No loading screen between them.

Bridge-connected side areas:

```text
MLD
Pančevo
```

Bridges may hide background streaming/loading.

## Character placeholders

Current archetypes:

```text
CRIMSON — Swing / Acrobat
AZURE   — Tech / Zip
VIOLET  — Trickster / Air
GOLD    — Bruiser / Power
```

They are temporary Spider-inspired placeholders and are intended to become
original characters later.

## Git safety

The working tree can contain important user work.

Unless explicitly requested, never:

- commit
- push
- switch branch
- hard reset
- destructive restore/checkout
- delete unrelated files

Before editing:

```bash
git status --short
```

After editing:

```bash
git diff --check
git status --short
git diff
```

## Engineering behavior

Before changing a system:

1. inspect the CURRENT implementation
2. identify all systems that already affect it
3. identify final ownership/order
4. avoid stacking a new system over conflicting obsolete systems
5. prefer the smallest robust integration
6. preserve unrelated gameplay
7. validate in the actual game when possible

For animation, never judge only by quaternion numbers. Judge final joint
positions and silhouette.

For city generation, never judge only by building count. Judge skyline,
traversal routes, repetition, and performance.

## Do not over-copy references

When using BRC, JSR, Spider-Man, or other games as references:

Extract principles such as:

- rhythm
- silhouette
- movement flow
- city density
- color blocking
- UI energy
- transition philosophy

Do not reproduce exact maps, characters, logos, graffiti, menus, textures,
animations, or proprietary assets.
