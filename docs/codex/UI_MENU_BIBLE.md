# UI / Main Menu / Lobby / Character Select Bible

The UI should feel original, street-designed and energetic, while remaining
very easy to read.

Do not copy BRC/JSR screens 1:1.

# Main menu target

## Overall presentation

Preferred concept:

A living 3D scene rather than a sterile flat menu.

Possible background:

- rooftop / graffiti hideout
- city skyline visible behind it
- current selected character idling or doing a subtle movement loop
- animated lights/billboards
- music already playing

The camera can make small deliberate movements, not constant distracting orbit.

## Visual language

Use original graphic elements inspired by Y2K street culture:

- sticker-like panels
- spray strokes
- torn-paper/tape edges
- chunky arrows
- bold condensed type
- graffiti accent marks
- asymmetrical panel placement
- strong highlight states

Readability beats decoration.

## Suggested main menu information architecture

```text
PLAY
MULTIPLAYER
CHARACTERS
GRAFFITI / GALLERY
SETTINGS
QUIT
```

When appropriate:

```text
CONTINUE
```

Do not expose ten prototype/debug options in the final player-facing menu.

## Menu transitions

Prefer transitions that feel connected to the world:

- camera pushes toward a graffiti wall
- character walks into hideout area
- UI panels slide like stickers/posters
- character select camera pans to lineup/display area

Transitions should be short and skippable/responsive.

# Title screen

Working title/logo can use current Spider City branding during prototype.

Target:

- strong logo silhouette
- city/street scene visible immediately
- one clear "Press Any Button" / start action
- music identity starts early
- no clutter

# Character select

Established design:

- full 3D model
- slow automatic rotation
- future manual rotate/zoom
- character name
- archetype
- stats
- movement style
- special ability
- passive/strength
- weakness
- selecting/locking should eventually play a signature animation

Stats:

```text
Speed
Acceleration
Swing
Air Control
Combat
Defense
```

These must map to actual gameplay values.

## Character select layout target

Recommended composition:

```text
LEFT/CENTER:
large 3D character

RIGHT:
name
archetype
short movement description
special
strength / weakness
stat bars

BOTTOM:
character roster strip + confirm/back
```

Use original graffiti/sticker framing, not a clean esports dashboard.

# Multiplayer lobby

Long-term target is a physical 3D graffiti hideout.

Players should be able to:

- move around
- see each other
- choose/change characters
- graffiti
- inspect missions
- ready up
- mess around while waiting

The lobby itself should demonstrate the game's movement personality.

Do not make the final lobby only a static list of player names if a physical
space is practical.

# Pause menu

Suggested direction:

A compact graphic overlay or original in-world device/phone-like interface can
work, but do not copy BRC's phone UI.

Useful tabs:

```text
Map / Objectives
Characters / Stats
Graffiti
Settings
Return / Quit
```

# Settings

Must include persistent:

```text
Master volume
Music volume
SFX volume
```

Input/remapping/video options can expand later.

# UI motion

UI animation should be:

- fast
- snappy
- readable
- slightly exaggerated

Avoid slow cinematic easing for every ordinary menu selection.
