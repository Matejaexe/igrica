# Master Game Vision

## One-sentence pitch

A fast, stylish urban action-platformer where movement itself is the toy:
players sprint, web-swing, wall-run, zip, flip, climb, fight, graffiti, and
flow across a colorful vertical city alone or with friends.

## Core fantasy

The player should feel like a highly mobile street superhero / movement artist,
not a slow realistic pedestrian.

A good play session should naturally produce moments like:

```text
rooftop sprint
-> leap
-> web attach to a real nearby structure
-> deep swing arc
-> pump for speed
-> release at the right moment
-> keep earned velocity
-> stylish aerial roll / flip
-> web zip toward a taller building
-> wall-run around its corner
-> wall jump
-> attach another web
-> land on a billboard / rooftop
-> tag graffiti
```

The player should be able to perform this because the systems connect, not
because a cutscene takes control.

# Design pillars

## 1. Movement is the main toy

If all enemies and missions disappeared, moving around the map should still be
fun.

## 2. Style comes from motion

BRC's useful lesson is that style should not be merely cosmetic. Movement,
tricks, route choice, graffiti and character presentation all contribute to
identity.

## 3. Momentum matters

Swing release timing, wall entry angle, jump timing and route choice should
produce meaningfully different results.

Avoid flattening every traversal action into the same speed.

## 4. Readable exaggeration

The game can exaggerate poses, camera, FOV, flips and body extension, but the
joint chains should remain understandable.

## 5. City as movement playground

The city is not background decoration.

Its buildings, gaps, walls, bridges, rooftops, rails, tunnels, alleys and
vertical landmarks are traversal geometry.

## 6. Social street culture

Graffiti, music, crew identity, a physical lobby/hideout, character archetypes,
and co-op should make the world feel lived-in and expressive.

# Target player experience

The desired emotional loop:

```text
see cool route
-> attempt it
-> barely make it
-> learn why
-> repeat faster
-> add a trick
-> discover shortcut
-> show friend
```

# Game flow target

Long-term flow:

```text
Title
-> Main Menu
-> Single Player or Host/Join
-> Physical Lobby / Hideout
-> Character Select
-> Mission / Free Roam
-> World traversal / combat / graffiti
-> Return to hideout / next objective
```

# Controls

```text
WASD   camera-relative fast movement
Shift  web swing / pump
Space  jump; wall-jump; swing release
Q      web zip
LMB    basic combat combo
RMB    character-specific special
Mouse  camera / aim
```

There is no sprint button in the core design. Ground movement is already fast.

# Traversal states

Core movement vocabulary:

```text
GROUND RUN
JUMP
AIR
WEB SWING
SWING RELEASE
WEB ZIP
WALL RIDE / WALL RUN
WALL JUMP
FALL
LAND
```

Future/advanced:

```text
WALL CLING / CRAWL for specific characters
DUAL-WEB SWING
AERIAL TRICKS
DIVE
TUCK
BARREL ROLL
CORKSCREW
GRIND / RAIL interactions where appropriate
```

# Animation philosophy

The best architecture is not "procedural everything".

Preferred long-term structure:

```text
authored / donor base locomotion
+
Godot-native retargeting
+
state-specific pose layers
+
selective IK for real gameplay targets
+
small procedural secondary motion
```

Examples:

- authored run drives legs and torso rhythm
- run arm layer produces the intended athletic silhouette
- swing hand IK points the correct hand toward the anchor
- body pose responds to velocity/rope direction
- aerial trick animation rotates presentation without changing physics velocity

# Originality

The current Spider-like character is a prototype vehicle for movement.

The end goal is an original cast and original world identity.

References should teach the project how to feel, not what to copy.
