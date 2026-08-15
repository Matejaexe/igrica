# Visual Style Bible

# Target identity

The visual target is:

```text
PS2-era low-poly clarity
+
BRC / JSR street-culture energy
+
comic-book character readability
+
original city / characters / graffiti
```

# Character rendering

Desired:

- stylized proportions
- strong silhouette from gameplay camera distance
- clear color separation
- readable hands/feet/limbs
- low-to-medium-poly forms
- cel/toon-like light separation where practical
- controlled outlines only if they remain stable/performance-friendly
- textures that feel designed, not realistic PBR noise

Avoid:

- realistic skin/material rendering on stylized bodies
- extremely tiny costume details unreadable at gameplay distance
- overly smooth featureless mannequin look
- procedural Lego/blockout character as final visual target

# Environment rendering

## Geometry

Use large readable shapes first:

- tower massing
- roof steps
- water tanks
- antenna silhouettes
- billboards
- HVAC blocks
- fire escapes / rails where they affect traversal
- bridges
- cranes/pipes in industrial zones

Facade micro-detail is secondary.

## Color

The city should not be gray-on-gray realism.

Use district color tendencies while preserving cohesion.

Example direction:

```text
MDK3      dense warm/cool graffiti contrast, concrete, saturated signage
Jerković  taller cool skyline, bold billboard/neon accents
MLD       industrial rust/cyan/yellow hazard accents
Pančevo   open sun-faded concrete, colorful ramps/tunnels/graffiti
```

These are directional palettes, not mandatory exact hex values.

## Materials

Prefer reusable stylized material families:

- concrete
- painted concrete
- dark glass
- bright glass/sign panels
- metal
- rooftop tar
- brick/stucco abstractions
- graffiti overlays/decals

Do not instantiate hundreds of unique materials if palette variants can be
shared.

# PS2-inspired detail budget

From gameplay distance, a building needs:

1. distinct silhouette
2. clear base/mid/roof read
3. a few strong facade rhythms
4. one or two memorable props/colors

It does NOT need every window as a unique object.

# Animation presentation

Animation is part of visual style.

Use:

- readable poses
- sharp anticipation/release
- exaggerated but coherent limbs
- clear airborne tuck/layout shapes
- strong wall-run lean
- strong swing body line

Avoid noisy constant procedural movement that makes the character look broken.

# Camera

Camera should support speed without causing sickness.

Useful tools:

- subtle speed FOV increase
- small landing response
- restrained wall-run roll
- camera lag only if it improves speed feeling
- stable horizon during ordinary running

Do not use heavy shake as a substitute for good movement.

# Graffiti / graphic language

Graffiti should feel authored and varied.

UI and world can share a graphic language:

- stickers
- tape
- spray strokes
- stencil blocks
- scribbled arrows
- chunky iconography
- asymmetrical framing

But gameplay text must remain readable.

# Originality guardrail

Do not recreate a BRC or JSR screenshot 1:1.

Ask:

```text
What principle makes this reference cool?
```

Then implement that principle with original assets/layouts.
