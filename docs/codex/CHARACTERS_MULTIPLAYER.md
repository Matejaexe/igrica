# Characters and Multiplayer

# Temporary archetypes

These are prototype roles and colors, not final licensed characters.

## CRIMSON — Swing / Acrobat

Identity:

- best pure swing expression
- acrobatic release poses
- balanced high-speed movement

Potential special themes:

- stronger swing pump
- better release control
- extra aerial trick utility

## AZURE — Tech / Zip

Identity:

- precise movement
- stronger/faster zip tools
- technical route correction

## VIOLET — Trickster / Air

Identity:

- best aerial control
- more expressive tricks
- longer/more controllable airborne states

## GOLD — Bruiser / Power

Identity:

- heavier silhouette
- stronger combat/defense
- movement still fun, but less agile than Acrobat

Do not make GOLD slow enough that traversal stops being enjoyable.

# Shared controls, real parameter differences

All characters share core controls.

Differences should come from real parameters/abilities:

- speed
- acceleration
- swing
- air control
- combat
- defense
- zip behavior
- special ability

Character-select stat bars must reflect real values.

# Original cast future

The current Spider-like placeholders are development tools.

Long-term:

- original silhouettes
- original outfits
- distinct traversal animation flavor
- distinct specials
- shared skeleton compatibility where possible to reduce animation cost

# Multiplayer target

```text
2–4 player co-op
```

Flow:

```text
Title
-> Host / Join
-> Lobby
-> Character Select
-> Game
```

# Networking priorities

Synchronize gameplay state that matters:

- player transform/movement state
- HP
- combat state
- grapple anchor / rope state needed to reconstruct visuals
- character selection
- mission state

Do NOT network every visual web segment.

Enemies/bosses should be host/server authoritative.

# Co-op traversal

Do not force players to stay shoulder-to-shoulder constantly.

The city should allow:

- racing to landmarks
- splitting across nearby routes
- regrouping
- shared graffiti objectives
- boss weak-point coordination

# Multiplayer readability

Players need clear:

- character colors/silhouettes
- name indicators at useful distance
- grapple/web readability without excessive lines
- ready state in lobby
