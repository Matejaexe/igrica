# Skyline Flight build — 2026-09-27

This is the next playable iteration of Spider City using the existing project. It adds traversal and a complete small activity toward the user's Spider-Man 2 reference. It is not the full Marvel game or a 1:1 reproduction.

## Play

Run `./run-linux.sh` (or open `project.godot` in Godot 4.7.2). Press F at the main menu for free roam, then H to start Skyline Flight. Run forward and jump off the launch deck, then press E while airborne to glide. WASD steers; Ctrl trades height for speed. E folds the wings. A successful LMB web or RMB zip attach interrupts flight. Existing Shift/Q alternatives and F2 mouse presets remain available.

Space selects a tuck/vault animation when running toward a low obstacle, while the ordinary jump and capsule collision do the actual traversal. This is a contextual jump, not a hand-planted vault, ledge grab or teleport.

## Added

- Momentum-preserving glide entry/exit, controlled descent, bounded steering and diving. Insufficient speed rejects opening the wings. Contact or respawn ends flight.
- Original procedural wing membranes driven by the current shoulder, hand and hip positions; dedicated Glide and Vault clips. The runtime now resolves 26 animation states.
- Seven sequential route gates, launch deck on a real city rooftop, live time/distance HUD, gold/silver/bronze result, replay/cancel and persistent best time.
- The activity restores the previous respawn point on cancellation/completion. Gate completion requires order; it cannot be skipped by entering a later ring.
- HUD control hints moved below the gameplay view to avoid overlapping the status panel.

## Validation

Godot 4.7.2 on Linux. 11 traversal checks, 13 traversal/arm checks, 14 transition checks, 20 city/game smoke checks, 13 new flight/vault checks, six activity checks and one wall-run playback pass (78 checks total).

The flight/vault checks exercise actual capsule traversal over a low obstacle and a real building anchor interrupting flight. Physics steering was compared at 30/60/120 Hz. The activity tests separately verify gate ordering, cancellation and disk persistence using simulated contact with gates.

In addition, a complete physical route playback succeeded in both headless simulation and an actual Forward+ window: 7/7 gates in approximately 22.1 seconds. The playback uses movement/jump/dive actions and camera-yaw steering. Beyond the activity's normal initial launch placement, it does not teleport the character or replace its velocity. See `validation/skyline-flight-gameplay.mp4` and `skyline-route-playback.txt`.

The video samples rendered gameplay every four physics ticks; its encoded duration is about 21.4 seconds because the initial launch setup is not included. Screenshots `skyline-glide.png` and `skyline-result.png` show flight and completion. They are actual game captures.

Protected original model and Blender source are unchanged; only the derived traversal GLB was regenerated. `git diff --check` passes. Existing null-material initialization and retained audio resource warnings remain, and isolated rendering runs can report unavailable shader cache storage. No new script parse or shader compilation failure was observed.

## Remaining work

Glide uses a tuned arcade flight model. Wing meshes and character motion remain prototypes. A full parkour system still needs obstacle-specific hand contact, ledge grabs, rooftop edge transitions and wall corners. Combat, enemy variety, authored missions, character/civilian assets, world composition and presentation need further development before calling this a finished game.
