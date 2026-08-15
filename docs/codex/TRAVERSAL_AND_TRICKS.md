# Traversal, Web Swing, Wall Run and Aerial Trick Bible

This is one of the most important project documents.

# Core rule

Traversal systems must chain together without unnecessary speed loss.

The desired feeling is:

```text
run -> jump -> swing -> release -> trick -> zip -> wall run -> wall jump -> swing
```

The player should rarely feel that the game says "stop, play animation, now
continue".

# Web swing

## Physics philosophy

Primary reference principle from Spider-Man 2 (2004): swinging should be tied
to physical geometry and momentum, not just a decorative web animation.

Requirements:

- web attaches to a valid world anchor
- anchor position affects trajectory
- rope length matters
- incoming velocity matters
- tangential momentum matters
- player input can pump/steer without replacing the pendulum behavior
- release preserves earned velocity

Do NOT add a synthetic release impulse just to make every release identical if
physics already produced good speed.

## Swing accessibility

Physics depth should not mean constant failure.

Use assistance carefully:

- sensible anchor selection among valid nearby surfaces
- forgiving attach cones
- mild steering/pumping
- camera that shows intended direction
- predictable rope behavior

Do not completely automate the trajectory.

## Anchor selection

Anchor selection should consider:

```text
camera aim / direction
player velocity
surface position
height advantage
rope angle
clearance
```

The selected hand follows anchor side.

## Swing animation phases

Useful visual phases:

### Attach
- selected hand reaches toward anchor
- torso acknowledges rope direction

### Descent
- body stretches into velocity
- legs trail

### Bottom of arc
- strongest speed pose
- compressed or long body depending style
- FOV/camera can subtly emphasize speed

### Ascent
- body starts preparing release
- legs may tuck slightly

### Release
- hand lets go
- body extends along current velocity
- physics velocity is preserved

# Aerial release tricks

The user explicitly wants cool airborne rolls/flips after leaving a swing.

This should become a deliberate traversal presentation system.

## Important separation

Aerial tricks should usually be **animation/presentation**, not a new physics
trajectory.

Keep:

```text
physics velocity
position
collision
```

independent from cosmetic body spin whenever possible.

## Trick trigger

A high-quality system can trigger a trick when:

- a swing is released at sufficient speed
- player is safely airborne
- there is enough expected clearance/time before landing
- player is not immediately entering wall-run/zip/attack state

Future manual trick input can be added, but an automatic contextual trick is
acceptable for the current goal.

## Trick library

Recommended original trick families:

```text
FORWARD TUCK FLIP
- knees pull toward chest
- compact fast rotation

BACK LAYOUT
- chest opens
- longer elegant backward rotation

BARREL ROLL
- long-axis body roll
- good after lateral swing release

CORKSCREW
- combined flip + roll
- reserve for high speed / long airtime

SIDE AERIAL / CARTWHEEL-LIKE AIR ROLL
- use sparingly

DIVE TRANSITION
- not a full trick; body lines up with velocity

TUCK -> EXTEND
- compact then opens before next web attach
```

Do not play the same flip after every release.

## Trick selection inputs

Use context:

```text
release speed
vertical velocity
horizontal velocity
swing curvature / rope side
estimated airtime
current facing
recent trick history
next traversal target
```

Example logic:

```text
short airtime -> quick half/compact roll or no trick
medium airtime -> forward/back tuck
long fast airtime -> barrel roll / corkscrew
immediate next anchor -> extend/reach instead of full flip
```

## Trick interruption

Tricks must be interruptible by gameplay transitions:

```text
web attach
web zip
wall contact
wall run
attack
ground landing
```

Blend out visually; do not delay the action waiting for the flip to finish.

## Trick safety

Avoid camera nausea:

- the character can rotate much more than the camera
- camera roll should be restrained
- do not rotate the world/horizon with every body flip

# Web zip

Zip is a direct traversal connector.

Desired uses:

- reach a nearby roof edge
- correct height after release
- bridge two swing opportunities
- start wall-run
- recover from low trajectory

It should not completely replace swing as the fastest/most interesting route.

# Wall ride / wall run

## Entry

Automatic entry when:

- player has enough speed
- approach angle is valid
- collision surface is suitable

## Motion

- project velocity along wall tangent
- preserve meaningful incoming momentum
- reduce gravity/fall speed while attached
- gradual speed bleed rather than instant fixed speed
- short contact grace around seams/edges

## Exit

Allow:

```text
Space -> wall jump
Shift -> web swing
natural edge exit -> air
speed loss -> fall away
```

## Visual

- face along wall tangent
- lean toward wall
- feet read against the wall
- body stays upright enough to remain readable
- avoid full-body clipping

# Traversal combo philosophy

No score system is required immediately, but internally think in traversal
strings:

```text
swing -> release flip -> zip -> wall run -> wall jump -> swing
```

Later this can feed:

- style meter
- missions
- character abilities
- score challenges
- graffiti access routes

# Dual-web future

Future goal only.

Do not implement casually until single-web movement is polished.

Potential uses:

- slingshot
- direction correction
- special character ability
- dramatic traversal puzzles
