# Grounded combat checkpoint — 27.09.2026.

Continues animation checkpoint `1c679b9`; no character, city or controller rebuild.

## Blender source

Only **Punch, PunchLeft and Finisher** were edited in the existing working `.blend`. Their leg stance is slightly wider, both ankles remain in place, and the hips load downward before rising into contact. The finisher compresses more deeply. The existing upper-body strikes, contact timings and finger poses are retained. Analytical leg posing is baked into ordinary Blender keys; no live Blender constraints or new bones are needed by Godot.

`tools/refine_combat_support.py` documents the one-time edit, backs up first and refuses to apply twice. Do not use it for normal export. Continue editing the working actions and use `tools/export_character_animations.py`.

Preservation comparison with the pre-edit `.blend` confirmed all 32 actions remain: only those three changed; 29 other action curves are identical, including `Run_FromReference_01`. Mesh vertices and skin weights are identical. A save-time check caught Blender discarding that unassigned reference action; it was recovered from the backup, all actions now have fake users, and the final comparison passes. The immutable original `.blend`, historical protected GLB and rig contract were not changed.

## Runtime ownership

AnimationTree → `ground_support_modifier.gd` → swing arm IK → skinning.

The ground modifier is limited to **Idle and the three normal attacks**, on the floor at horizontal speed below 1.6 m/s. Two static-ground rays run on physics ticks. In presentation, a bounded pelvis drop and two-bone leg correction align soles with the sampled floor normal. The capsule position, velocity, input and rope solver are untouched. The measured source soles are at z≈0; ankle heights are approximately 0.1557 m before the existing 1.62 model scale.

Corrections are limited to 0.22 m, reject steep normals and missing ground, and reset on jumps, dodges, wall movement, swing, zip and respawn. Running and airborne legs retain their authored trajectories. This is local support correction, not dynamic gait foot locking or a stair-stepping locomotion solver. Combat ankle planting is authored in Blender; Godot adapts its height and slope.

## Validation

116 passing checks on the final GLB: support 19, hybrid animation 11, combat 17, extended traversal/arm IK 13, transitions 14, four-character smoke 20, patrol 9 and flight/vault 13. See `validation/support-*.txt`.

The support checks use real physics floors, including a 12-degree slope. Maximum flat-floor ankle-derived sole error is 1.51 mm (Idle); combat contact error is below 0.02 mm. Tests also cover missing floor, unchanged collision-body position/momentum, all three planted imported actions, disabling support in six traversal states and reset. These numerical checks complement visual review; they do not measure every skinned shoe vertex.

Ground-to-ground transitions release leg IK immediately and fade the pelvis offset out within 0.1 seconds, avoiding an abrupt height change. Airborne actions release it immediately. Two additional transition checks pass.

The rendered review contains 225 frames and 15 inspected stills, each with front, side and three-quarter views: Idle, three attacks and a sloped-floor attack. See `validation/support-animation-review.mp4`. A separate 90-frame automatic-modifier/AnimationTree capture (`support-transition-review.mp4`, four inspected stills) checks the Idle-to-Run fade. The older Run clip still lifts its feet high and needs the planned gait refinement.

Actual Forward+ patrol input playback cleared all three waves in 24.1 seconds with +150 XP, health 100. It is recorded separately in `support-patrol-gameplay.mp4` with its result log; this single input-bot run is not a balance/performance benchmark.

## Remaining work

Thumbs still extend too far from the fists, and the finisher needs a more distinctive upper-body silhouette. Locomotion foot phases, running attacks, landing clips and contact on moving platforms are not polished by this pass. Existing material initialization, isolated shader-cache and resource-shutdown diagnostics remain. Next: thumb/palm contact and finisher follow-through in the same Blender actions, with repeat import/transition/gameplay review; then locomotion/landing support.
