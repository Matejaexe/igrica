# Movement reference: Marvel’s Spider-Man 2

Selected by the user on 2026-09-27. The request is the controlled character's full movement set and transitions. No original Insomniac animation files are present. Current work is original animation on the existing rig; it is not a verified 1:1 reproduction.

Official reference material:
- https://blog.playstation.com/2023/05/24/marvels-spider-man-2-gameplay-revealed/
- https://www.playstation.com/en-ca/games/marvels-spider-man-2/whats-new-in-marvels-spider-man-2/

These pages establish traversal scope, including Web Wings, rather than providing skeleton animation or frame-by-frame pose data. No exact animation timing has been inferred from their prose.

## Implemented in this pass

Eight additional clips bring the runtime state set to 24:
- StartRun and StopRun: short acceleration and braking strides.
- LandRun: contact compression transitioning into movement.
- HardLand: deeper stationary impact compression and recovery.
- WallJumpLeft / WallJumpRight: mirrored wall push-off poses.
- AirJumpLeft / AirJumpRight: asymmetric variants of the project's existing second jump. This does not claim that the game's air-jump mechanic matches the reference.

Player physics now emits measured contact metadata from pre-slide vertical velocity. The driver consumes each landing once, chooses running/stationary/heavy recovery, and interrupts it immediately when the player becomes airborne. Input cancels braking. Grabbing a web takes precedence over airborne poses. No input lock, movement impulse, root motion or collision change was added.

New grounded clips compensate pelvis height to keep the supporting ankle near its rest height. Full runtime foot IK, hand contact and fingertip poses remain unfinished.

## Verification

Godot 4.7.2: 11 traversal checks, 13 traversal/arm checks, 20 full-game smoke checks and 14 new transition checks all pass (58 total). The new test includes a real drop onto a roof and verifies measured heavy contact triggers HardLand. New clips load for all four character presets. Original protected GLB and Blender source remain unchanged. `git diff --check` passes.

Actual Forward+ rendered poses and sequences were inspected. `validation/movement-transitions.mp4` is a fixed-camera in-place clip/transition demonstration, not a reference-game comparison or a full traversal recording. Existing material/audio warnings remain; this capture also reports an unavailable shader cache directory without preventing rendering.

## Remaining scope for the full request

- Compare actual reference footage from front, side and behind, with agreed Peter/Miles motion style.
- Refine running contacts, fingers, turning, starts and stops.
- Add context-aware obstacle vaults, ledge transitions, wall corners and ledge perch transitions.
- Expand swing entry/release variations and interruption-safe aerial tricks.
- Implement and animate gliding/Web Wings if required for the full traversal scope; currently absent.
- Extend combat/dodge movement and animation selection separately.
- Retarget source animation files if supplied; exact 1:1 equivalence remains unverified without them.

## Subsequent update

The [Skyline Flight build](SKYLINE_FLIGHT_BUILD.md) now adds a playable glide and contextual low-obstacle jump, with a completed seven-gate city route. The earlier remaining-scope list records the state before that update; full contact-aware parkour and reference parity remain unfinished.
