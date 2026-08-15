# City / World Design Bible

The world is a traversal playground first and a believable city second.

# Macro layout

## Main contiguous landmass

```text
MDK3 <----------------> Jerković
```

No loading screen between them.

## Side islands

```text
MLD -------- bridge -------- main landmass
Pančevo ---- bridge -------- main landmass
```

Bridges are natural streaming/loading corridors.

Prefer background streaming. A stylized transition is acceptable only if
streaming cannot complete invisibly.

# Zone identity

## MDK3 — dense street core

Target:

- dense blocks
- closer rooftops
- narrower streets
- lots of graffiti
- BRC/JSR street-culture energy
- frequent short traversal decisions
- rooftop-to-rooftop movement
- alleys, fire escapes, signs, rails

Movement feeling:

```text
technical / close / reactive
```

## Jerković — vertical skyline

Target:

- taller buildings
- more open streets
- long swing canyons
- antennas
- billboards
- rooftop height variation
- several major skyscraper landmarks

Movement feeling:

```text
fast / high / long arcs / vertical
```

This is where the city should most strongly support huge swing release moments.

## MLD — industrial traversal island

Target:

- factories
- warehouses
- pipes
- cranes
- rails
- tanks
- industrial catwalks
- grind/traversal routes

Movement feeling:

```text
mechanical / route-combo / obstacle-rich
```

## Pančevo — open trick island

Target:

- lower buildings
- open areas
- ramps
- tunnels
- trick spaces
- large graffiti walls

Movement feeling:

```text
air tricks / experimentation / speed playground
```

# City silhouette

Do not build a uniform box grid.

Use height tiers:

```text
low       ~8–20 m
mid       ~20–50 m
high      ~50–95 m
landmark  ~110–180+ m
```

These are design ranges, not strict engineering constraints.

Most buildings should be low/mid.

Use a small number of very tall landmarks.

# Landmark philosophy

Landmarks serve three jobs:

1. orientation
2. visual identity
3. traversal goals

Examples of original landmark types:

- needle tower with billboard crown
- twin apartment slabs connected by skybridge
- old brutalist communications tower
- industrial crane megastructure
- water-tower-covered residential block
- broadcast mast on a stepped skyscraper

Do not copy real/game landmarks exactly.

# Traversal block design

Every block should ask:

```text
Can I swing through it?
Can I run over it?
Can I climb out of a mistake?
Is there a higher route?
Is there a risky shortcut?
Can I see the next target?
```

Mix:

- broad avenues for long swing arcs
- narrow alleys for technical wall-run/zip routes
- stepped rooftops
- gaps that reward momentum
- low recovery buildings
- high challenge buildings

# Rooftops

Rooftops should not all be empty flat rectangles.

Use traversal-relevant props:

- HVAC blocks
- vents
- antennas
- water tanks
- signs
- roof rooms
- ramps
- rails
- billboards

But avoid prop spam that makes movement frustrating.

# Facade detail

Prioritize silhouette first.

A building can be memorable with:

```text
shape + color rhythm + roof prop + sign
```

rather than 300 individual window nodes.

# Procedural generation rules

If using procedural generation:

- deterministic seed
- block-aware placement
- district-specific parameters
- prevent duplicate transforms
- meaningful building-count statistics
- reusable materials
- simple collision
- district parent nodes for future streaming

Do not stack old and new city generators together.

# Performance

Prefer:

- shared materials
- repeated meshes / MultiMesh for decorative repetition where useful
- simple building collision volumes
- no collision for tiny decorative objects unless gameplay needs it
- spatial district parents
- distance culling/streaming later when profiling justifies it

Do not prematurely build a giant streaming framework before the basic city is
fun.

# City success test

A successful city lets the player spend several minutes moving without using
the same exact route twice.

It should create visually distinct clips/screenshots depending on district.
