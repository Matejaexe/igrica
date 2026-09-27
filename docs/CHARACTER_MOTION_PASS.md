# Civilians and character motion — 2026-09-26

## Implemented

280 civilians retain their original city routes and avoidance rules. Their presentation now includes varied height/build, tapered clothing, collars, pockets, zippers, optional caps/backpacks/hoods, faces, ears, varied trousers and articulated joints. All geometry uses the existing batched crowd system; these remain stylized procedural figures, not final authored/skinned NPC assets.

Walking uses distance-driven stance and swing phases, lifted recovery feet, analytic two-segment knees, opposing arm motion and subtle torso sway. Start/stop motion ramps smoothly. The existing close-player/follower stop remains immediate to avoid drifting into another actor. The leg solution is for flat pavement; uneven-terrain foot placement is not implemented.

The hero has an original RunFlow clip with stronger heel recovery, bent elbows and torso counter-rotation. Walk and wall-run arms now bend in the corrected anatomical plane. Jump compresses over time; landing compresses and recovers. Walk/run state selection has hysteresis, transitions retain normalized stride phase, and idle/locomotion/landing use different blend durations. Original source run remains in the generated GLB. No proprietary animation data was imported.

Physics still owns movement. Animation does not change momentum, body collision or jump height. The protected original GLB and authored Blender file are unchanged.

## Validation

Godot 4.7.2; actual Forward+ rendering on RTX 3080. Rendered walk/jump poses and multiple run phases reviewed; a reproducible in-place motion sample is `validation/character-motion.mp4`. It demonstrates animation clips and transitions, not a full gameplay traversal recording. Four civilian stride samples are `validation/civilians-walk-0.png` through `-3.png`.

- 11 traversal checks pass, including all 16 states and continuous 30-second run playback.
- 13 traversal/arm reach checks pass.
- 20 game smoke checks pass, including 280 civilians, clear routes and practice save/reload.
- 3 new rendered checks pass: soles never penetrate the flat pavement over 60 stride samples, both leg lengths stay constant, and walk-to-run retains normalized phase.
- The new test requires a rendering device: headless dummy MultiMesh readback returns identity transforms and cannot validate visual geometry. Run `./run-linux.sh --script tests/civil_animation_test.gd`.
- `git diff --check` passes. Existing null-material initialization and audio-resource shutdown warnings remain; one capture environment also reported unavailable shader cache storage, without blocking rendering.

## Remaining work

The animation is a procedural authored approximation of athletic superhero motion, not a reproduction of Insomniac's animation library or production quality. Further work: polished hand/finger poses, ground contact on the hero, more responsive moving landings, richer acrobatic transitions and dedicated NPC meshes.
