# Graffiti, Combat and Audio Bible

# Graffiti

Graffiti is not just decoration; it is a game interaction and street-identity
system.

Established future flow:

```text
approach graffiti spot
-> camera focuses wall
-> draw gesture through nodes/points
-> evaluate result
-> place graffiti
```

Sizes:

```text
Small
Medium
Large
```

Possible scoring:

```text
Perfect
Clean
Messy
```

Features:

- character-specific graffiti sets
- multiplayer players can paint over one another
- future graffiti editor possible

## Graffiti minigame feel

Should be quick enough not to destroy movement flow.

Use:

- mouse/controller gesture input
- clear node order
- strong stroke feedback
- satisfying spray/paint audio

Do not turn every tag into a long menu.

# Combat

Core:

```text
LMB = normal combo
RMB = character-specific special
```

Future:

- air attacks
- character-specific combat strengths
- regular enemies
- minibosses

Combat must respect mobility.

Avoid locking the player in long grounded attack animations that make traversal
feel irrelevant.

# Boss design

Major target: a large traversal-focused boss.

The boss should use:

- swinging around it
- avoiding large attacks
- hitting weak points
- web/grapple interactions on boss parts if appropriate
- vertical arena movement
- co-op coordination

It should not be only a stationary HP bar.

# Audio identity

Music direction:

```text
original jungle / DnB
fast street energy
STRAFTAT-like intensity as a vibe reference, without copying tracks
```

Existing original tracks referenced in project context:

```text
Concrete Canopy
Neon Underpass
Bridge Velocity
```

Audio buses/settings:

```text
Master
Music
SFX
```

Sliders should persist.

# Traversal SFX

Important sonic feedback:

- web fire
- web tension / rope movement
- release
- zip
- wall contact
- wall-run scrape/steps
- jump
- landing intensity
- high-speed wind
- graffiti spray
- trick whoosh only when useful

Do not spam loud whooshes every half-second.

# Music transitions

Long-term music can respond to:

- free roam
- combat
- boss
- mission intensity
- district

Crossfades should avoid restarting songs constantly during ordinary traversal.
