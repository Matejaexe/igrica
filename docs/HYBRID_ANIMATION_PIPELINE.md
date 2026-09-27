# Blender + Godot animation pipeline — 27.09.2026.

## Ownership

The current character and rig are preserved. Blender owns authored actions; Godot owns state selection, crossfades, playback rate, IK and physics reactions. All clips remain in-place. The gameplay controller alone moves the collision body.

- Immutable source: `assets/characters/spidey/blender/spidey_run_from_reference_v1.blend`.
- Editable source with the existing mesh, armature and all actions: `assets/characters/spidey/blender/spidey_animation_working.blend`.
- Runtime export: `assets/characters/spidey/spidey_traversal.glb`.
- Pre-change Godot skeleton contract: `assets/characters/spidey/rig_contract.json`. Do not regenerate this baseline to hide a mismatch.
- Protected historical model `models/spidey/spidey_funk_alt_v2.glb` remains untouched.

The live rig uses `Hips`, `Spine`, `LeftArm`, `LeftForeArm`, `LeftHand`, etc. Older retarget documents describe another rig's `arm1l` names; do not rename the current bones to match those documents.

## Normal authoring/export loop

1. Open **spidey_animation_working.blend** in Blender. Edit its existing actions/keys, preserve armature rest transforms, bone names and hierarchy. Keep horizontal root/hips translation in-place; vertical compression is allowed.
2. Save the working file. Export with:

```sh
'/home/exe/.local/share/Steam/steamapps/common/Blender/blender' --background --factory-startup --python-exit-code 1 --python tools/export_character_animations.py
```

This script loads the working file and validates its armature against original source data before exporting. It does not generate poses, rename bones, save over the original, or overwrite the working file. Normal GLB export thus preserves artist edits. It was actually run and produced `ANIMATION_EXPORT_OK`.

3. Import the GLB in Godot 4.7.2, then run `tests/hybrid_animation_test.gd`, the relevant gameplay tests and a graphical capture. For example:

```sh
GODOT_BIN='/home/exe/.local/share/Steam/steamapps/common/Godot Engine/godot.x11.opt.tools.64'
XDG_DATA_HOME=/tmp/spider-animation-check "$GODOT_BIN" --headless --editor --path . --import
XDG_DATA_HOME=/tmp/spider-animation-check "$GODOT_BIN" --headless --path . --script tests/hybrid_animation_test.gd
SPIDER_CAPTURE_DIR=/tmp/spider-animation-frames XDG_DATA_HOME=/tmp/spider-animation-check "$GODOT_BIN" --path . --script tests/capture_hybrid_animation.gd
```

Inspect front, side, three-quarter, anticipation/contact/recovery and actual gameplay. Passing an import test alone does not finish an animation. Add changed clips to the capture list when reviewing other actions.

`tools/build_traversal_clips.py` is the **prototype action builder**, not the normal export command. It refuses to replace an existing working file unless `-- --rebuild-working-copy` is explicitly passed. That opt-in regeneration first backs up the working file outside the project. Use only when deliberately rebuilding procedural draft actions, because it will replace hand-edited actions. The source character is never rebuilt or reskinned.

## Runtime

`spidey_blender_animation_driver.gd` creates one AnimationTree, with a state machine and a playback-rate node. Its AnimationPlayer supplies imported animation resources and does not independently play clips. The driver manually advances the tree once per presentation update; tests use the same evaluator.

Walk, Run and Sprint share a normalized cycle clock, so changing speed preserves stride phase. Other action states use authored seconds. Direct transitions allow gameplay interruptions; landing and combat use shorter crossfades. Repeated same-state attacks reset the action, rather than freezing at its final pose. The implementation uses Godot's documented [state-machine playback](https://docs.godotengine.org/en/stable/classes/class_animationnodestatemachineplayback.html) and [custom animation timelines](https://docs.godotengine.org/en/stable/classes/class_animationnodeanimation.html).

Order: controller state → AnimationTree base pose/blend → existing `swing_pose_modifier.gd` arm IK → skinning/final web-hand position. Swing/tuck selection still responds to measured velocity and anchor side; IK aims the actual arm chain toward the actual physics anchor. The web originates at the final corrected hand. This pass preserves the existing rope physics and visual root lean; it does not replace swinging with a fixed baked trajectory.

## Changes in this checkpoint

- Existing 30 states retained; a Blender-authored **Sprint** clip adds the 31st. It is selected above 22 m/s on the ground, held down to 20 m/s, without introducing a new sprint button or changing Shift/web controls.
- Punch, PunchLeft and Finisher have guard, anticipation, contact, follow-through and recovery keys; existing finger bones close the hands. Source geometry/skin/bind are unchanged.
- Normal hit contact is at 40% of the clip: 0.133 s for the two 10-frame punches, 0.2 s for the 15-frame finisher at 30 fps. Imported durations are tested against controller timing.
- Damage no longer happens immediately on button press. Range/line of sight are checked again at contact. Dodge, special and respawn cancel pending normal contact. Character specials otherwise retain their earlier behavior; they do not yet have dedicated refined clips.

## Validation and limits

111 checks pass across hybrid rig/tree tests (11), combat (17), traversal (11), extended traversal/IK (13), transitions (14), game smoke (20), patrol (9), flight/vault (13), and rendered civilian/stride checks (3). The hybrid checks compare all bone names, parents and rest matrices with the pre-edit GLB, validate all 31 states, verify finite poses, no horizontal hips drift, unchanged physics/momentum, phase continuity, combat durations and grounded Sprint selection.

Twelve three-angle stills and 162 rendered review frames cover the four changed/new clips at multiple phases. See `validation/hybrid-animation-review.mp4` and `hybrid-*.png`. All twelve stills were inspected. Separate actual-input patrol playbacks won in headless simulation (21.0 s) and Forward+ rendering (37.6 s), with +150 XP; see `hybrid-patrol-gameplay.mp4` and logs. The bot now follows attack cooldowns and reacts to drone windups with dodge. The earlier fixed-rate attack-only bot failed under the new contact timing; that failure was observed, not omitted from the balance assessment. These bot runs are not a deterministic performance benchmark or a substitute for player feedback.

The motion is still a prototype. Further work is needed on thumb/palm contact, grounded foot planting, weight transfer, finisher differentiation and hit reactions. Most existing idle/jump/fall/landing/swing/wall-run clips were preserved, not newly polished or declared finished. Normal attacks still use the game's range/occlusion hit query, not a swept fist collider. Existing null-material initialization and retained audio-resource shutdown diagnostics remain. Blender exports also report existing armature-parent/texture-sampler warnings; imported skeleton checks and rendered skinning succeeded, but those warnings are not claimed fixed.

Next: refine feet/weight transfer and combat contact presentation on this same rig, then connect traversal and patrol through an authored encounter route. No further city expansion is needed before that work.
