# Graphics pass — 2026-09-25

The main city now uses Forward+ with 4x MSAA, screen-space ambient occlusion, four shadow splits and a restrained warm/cool lighting palette. Compatibility remains available through `./run-linux.sh --rendering-method gl_compatibility`; its lighting differs and it does not provide all Forward+ effects.

Six procedural facade styles replace the flat SVG window grids visually. Original SVGs remain intact. Window bays follow actual building dimensions; materials include filtered masonry joints, window frames, blinds, warm occupied windows, glass roughness and recessed borders. These are shader impressions of depth, not modeled interiors. Buildings also receive real raised cornices and corner piers. Road surfaces use world-space asphalt detail with distance filtering.

The city still has 320 buildings and 280 pedestrians. Static decorations increased from 25,190 to 29,742 pieces while retaining 418 spatial MultiMesh batches. Gameplay, original character assets, collision and pedestrian routes were preserved. New shader and trim work is original project code; no new external asset license is required.

## Validation

- Godot 4.7.2, NVIDIA RTX 3080, 1280×720, actual windowed rendering in both modes.
- All 20 game smoke checks pass, including city loading, pedestrian routes, character loading, mission entry, movement input and practice save/reload.
- First sandbox test used the normal user-data location and could not write the practice save. Re-run with an isolated writable XDG_DATA_HOME passed; see `validation/graphics-smoke.txt`.
- Forward+ fixed street camera: median 6.973 ms, p95 7.671 ms, 1,309 draw calls. Compatibility: median 6.931 ms, p95 8.671 ms. These are short frame-interval samples in a single stationary scene, not minimum FPS promises for the whole game.
- Actual rendered images: `validation/graphics-street.png`, `graphics-skyline.png`, and the `graphics-compat-*` alternatives. `graphics-before-skyline.png` uses the same skyline camera before this pass. Pedestrians are time-driven and not frame-identical between captures.
- Known pre-existing null-material messages still occur during character initialization. Headless shutdown can also report retained audio resources. These remain unresolved and are not shader compilation failures.

## Remaining visual work

Building silhouettes and pedestrians still use simple geometry. Next steps are more varied authored building shapes, richer storefronts and interiors, better pedestrian meshes, and street composition. This pass improves materials and lighting; it is not a claim of finished production graphics.
