# Patrol checkpoint — 2026-09-27

Continues the combat work already in progress before the previous context limit.

From the menu press F for free roam, then C for the rooftop patrol. J/K attack, Alt dodges on the ground. Complete waves of 2, 3 and 4 drones for 150 XP. C cancels/restarts. H switches to the existing Skyline Flight activity. Victories, XP and best patrol time persist.

Drones now telegraph strikes, respect walls and stagger when hit. Melee checks line of sight. The character has alternating combo clips, a finisher and left/right dodge clips; repeated attacks restart the correct clip. The derived GLB resolves 30 states. Physics remains in the controller, visuals in the animation driver.

Validation: 12 combat checks, 9 patrol lifecycle/persistence checks, and a complete physical-input playback in the Steam Godot 4.7.2 Forward+ renderer. All three waves completed in 18.8 seconds with +150 XP. `validation/patrol-gameplay.mp4` samples actual gameplay at 15 fps; `patrol-combat.png` and `patrol-result.png` were visually inspected. The test attacks and steers toward the arena; it does not directly damage enemies or teleport the character after the activity starts. Lifecycle unit checks do use direct damage to verify rewards and cleanup.

The final lifecycle fix prevents cancelling a patrol from replacing the new mission's respawn point. Existing traversal, flight and city regression tests passed before this continuation; logs remain in validation/work. No original Blender source or protected GLB was changed.

The arena, drone shapes and combat poses are still prototype quality. This automated playback proves completion, not encounter balance or polished animation. Existing null-material startup and audio-resource shutdown diagnostics remain; the build is not warning-free.
