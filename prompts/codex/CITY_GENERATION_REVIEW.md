# City generation architecture + quality pass

```text
Read AGENTS.md and inspect the CURRENT city/world generator before changing it.

Goal: larger, denser, more vertical, more memorable traversal city without duplicate old/new generation systems.

First clean duplicate ground, roads, parks, buildings, decorator calls and constants.
Then improve low/mid/high/skyscraper tiers, recognizable landmark towers, varied rooftops, alleys/avenues, swing corridors, deterministic generation, district parents and reasonable node count.

Do not modify character, animation, player physics, swing, combat, graffiti or audio.
Validate actual building count, height distribution, duplicate transforms, district structure and git diff --check.
Do not commit or push.
```
