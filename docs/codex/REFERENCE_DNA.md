# Reference DNA — What to Learn, What Not to Copy

This document converts reference games into design principles.

# Bomb Rush Cyberfunk

## Learn from

- movement itself is part of style
- free exploration of stylized 3D urban spaces
- strong street-culture identity
- graffiti integrated into territory/progression
- grinding/sliding/wallrunning/air tricks forming one movement vocabulary
- exaggerated readable silhouettes
- bold low-detail forms with strong color blocking
- environments made of obvious traversal shapes: ramps, rails, walls,
  platforms, cavities, extrusions, rooftops
- music and character presentation reinforcing gameplay rhythm

## For Igrica

Use BRC as the strongest reference for:

```text
street attitude
stylized proportions
movement readability
graffiti energy
color blocking
rooftop / wall-run playground design
```

Do not copy:

```text
New Amsterdam layouts
specific characters
specific graffiti
specific UI screens
exact shaders/textures
exact tricks/animations
logos
```

# Jet Set Radio / Jet Grind Radio

## Learn from

- graffiti as the identity of spaces and crews
- tricks/flips as character expression
- exaggerated caricature of a large city rather than realism
- clean, bold cel-shaded readability
- strong graphic-design language
- police / city pressure creating energy around free movement
- city landmarks and unusual geometry being more important than realistic
  architectural completeness

## For Igrica

Use JSR as a reference for:

```text
graphic confidence
street iconography
graffiti placement
city caricature
high-contrast signs
stylized menu attitude
```

# Spider-Man 2 (2004, Treyarch)

This is a key traversal-design reference.

## Learn from

- web movement feels better when the web attaches to real world geometry
- swing is fundamentally a locomotion challenge, not a canned animation
- momentum should survive release
- speed and danger produce satisfaction
- continuous movement through an open city supports practice and mastery
- accessible controls should preserve depth rather than delete physics

## For Igrica

Strong rules:

```text
anchor location matters
rope angle matters
incoming velocity matters
release timing matters
tangential momentum survives release
city geometry must support the swing system
```

Do not fake every web into the sky.

# Ultimate Spider-Man (2005)

## Learn from

- comic-book visual readability works extremely well with Spider-like movement
- wall run, web swing, web zip and aerial movement can coexist in one compact
  control vocabulary
- strong stylization can make a lower-detail city memorable
- responsive zip/jump options keep traversal from relying on swing alone

For this project, use its comic energy and traversal vocabulary as reference,
but prefer Spider-Man 2's stronger momentum/attachment philosophy for the core
swing physics.

# Modern Marvel's Spider-Man games — secondary movement reference

These are NOT the primary visual reference.

Useful lessons:

- transitions between swing, wall-run, zip and parkour should rarely kill flow
- attachment-point selection can preserve intended direction/momentum
- animation, camera and FOV can sell a superhuman feeling without needing
  perfectly realistic rope physics
- air tricks can give players expressive motion between traversal actions

For Igrica, take the polish philosophy, not the exact control scheme or visual
presentation.

# PS2-era visual language

"PS2 style" here does not mean intentionally ugly.

It means:

- readable low/medium poly silhouettes
- simplified architecture
- aggressive texture/color design
- less visual noise than modern photorealism
- chunky props and clear shapes
- animation with personality rather than mocap subtlety
- strong fog/sky/color grading where useful
- city density created with smart repetition and silhouettes

Combine this with modern rendering stability and quality-of-life.

# Reference priority matrix

| System | Primary reference | Secondary reference |
|---|---|---|
| Visual street energy | BRC | JSR |
| Graffiti identity | JSR/BRC | original street art research |
| Physics web swing | Spider-Man 2 (2004) | modern Spider-Man polish |
| Comic character readability | Ultimate Spider-Man | BRC |
| Wall traversal flow | BRC + modern Spider-Man | Ultimate Spider-Man |
| Aerial tricks | modern Spider-Man + BRC trick language | original acrobatics |
| City silhouette | JSR/BRC caricature | PS2 open-world simplicity |
| Menu/UI energy | original Y2K/graffiti language | BRC/JSR as mood only |
