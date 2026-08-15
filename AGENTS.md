<<'EOF'
# Igrica — Codex Project Instructions

## Project

This is a Godot 4.7.x 3D platformer/action game.

The current main playable character uses the imported BRC-style Spider model.

Important character model:

- `res://models/spidey/spidey_funk_alt_v2.glb`

This GLB currently has correct mesh, skinning and bind/rest pose.

DO NOT modify, regenerate or replace this GLB unless explicitly requested.

---

## General workflow

Before changing anything:

1. Inspect the existing implementation.
2. Understand how the current scene/script is connected.
3. Prefer modifying the existing system over creating another competing system.
4. Check relevant Godot APIs before inventing custom math.
5. Preserve unrelated gameplay systems.

After changes:

- run `git diff --check`
- inspect the diff
- report exactly which files changed
- do NOT commit
- do NOT push
- do NOT change branches unless explicitly requested

Never use `git reset --hard`, destructive checkout/restore, or delete user work without explicit permission.

---

# Character rig rules

Treat the character as connected articulated joint chains.

Do NOT think of an entire arm or leg as one rigid stick.

## Torso

hips -> lower spine -> upper spine -> neck -> head

BRC bones:

- `hips`
- `s1`
- `s2`
- `neck`
- `head`

## Left arm

shoulder -> upper arm -> elbow -> forearm -> wrist/hand

BRC bones:

- `shldl`
- `arm1l`
- `arm2l`
- `handl`

## Right arm

- `shldr`
- `arm1r`
- `arm2r`
- `handr`

## Left leg

hip -> thigh -> knee -> shin -> ankle/foot -> toes

- `leg1l`
- `leg2l`
- `footl`
- `toesl`

## Right leg

- `leg1r`
- `leg2r`
- `footr`
- `toesr`

Always judge animation by actual resulting joint positions and silhouette,
not just Euler/quaternion values.

---

# Important rig facts

Approximate model orientation:

- +Y = up
- +Z = model forward
- +X = character left

The imported Godot Bone Pose includes Bone Rest.

DO NOT assume `Quaternion.IDENTITY` is the correct neutral pose.

Use the imported bone rest as the neutral/reference pose.

---

# Animation architecture

Prefer Godot-native animation systems:

- `AnimationPlayer`
- `AnimationTree`
- `Skeleton3D`
- `SkeletonModifier3D`
- `SkeletonProfileHumanoid`
- `RetargetModifier3D`
- `TwoBoneIK3D`
- `BoneAttachment3D`

Avoid custom cross-rig quaternion retargeting if Godot native retargeting can do it.

The current donor locomotion source is the official Godot 3D Platformer model:

- `res://third_party/godot_platformer/player.glb`

Ground locomotion may use its authored:

- idle
- walk
- run
- jump
- falling

with native retargeting to the BRC skeleton.

Make sure locomotion clips LOOP continuously.

The character must never:

1. animate for ~1–2 seconds
2. stop animating
3. continue moving by sliding

If a looping locomotion animation unexpectedly stops, investigate and fix the
loop/playback state.

---

# Running animation

The desired run is stylized Spider-Man / BRC-like.

## Arms

For the current simple run target:

- elbows should remain approximately 90 degrees
- shoulders should remain relaxed
- arms move primarily FORWARD and BACKWARD
- do NOT rotate arms inward/outward excessively
- do NOT create a T-pose / bird-wing silhouette
- wrists should not randomly twist
- hands must never pass through the torso
- hands should remain slightly outside the torso
- left/right arm swing should oppose the legs naturally

For debugging:

Do not blindly flip rotation signs.

Inspect actual model-space positions of:

- shoulder
- elbow
- hand

If the elbow and hand are in bad positions, solve the joint geometry instead.

## Legs

Running must visibly use:

hip -> knee -> ankle -> foot

Requirements:

- knees visibly bend
- heel recovery should occur
- feet must not stay permanently on the toes
- legs must not look like rigid sticks

---

# Idle pose

Idle should look like a normal relaxed person.

Desired characteristics:

- elbows lower than the previous raised-arm pose
- arms relaxed beside torso
- hands safely outside torso
- legs slightly apart
- knees not perfectly locked
- feet placed naturally rather than both exactly on the center line

Do not spread the legs with arbitrary bone-axis guesses if IK/target positions
can solve the stance more reliably.

---

# IK rules

For arms, reason using:

- hand target
- elbow pole
- shoulder position

For legs, reason using:

- foot target
- knee pole
- hip position

When using `TwoBoneIK3D`:

- use anatomical root -> middle -> end chains
- ensure pole targets bend the joint in the expected anatomical direction
- avoid targets that force limbs through the torso
- inspect real resulting joint positions

---

# Web swing

Existing movement/web physics must be preserved unless explicitly requested.

Web hand selection:

- grapple left of camera -> left hand
- grapple right of camera -> right hand
- near center -> alternate hand

Visible web should originate from the selected hand.

Prefer `BoneAttachment3D` or hand-bone-derived origins.

---

# Gameplay preservation

Do not break or rewrite unrelated systems while fixing animation.

Preserve:

- player physics
- acceleration
- jump
- web swing
- zip
- wall ride
- camera
- combat
- graffiti
- multiplayer-related code
- audio

Animation should follow gameplay physics, not replace it.

---

# Visual target

Style:

- PS2 / low-poly
- Bomb Rush Cyberfunk / Jet Set Radio inspiration
- readable exaggerated silhouettes

The player prefers animation that looks intentionally authored rather than
overly procedural.

When a screenshot/video reference is supplied, prioritize the visible desired
pose over abstract assumptions.

---

# Debugging expectations

When fixing character animation:

1. inspect bone names and hierarchy
2. inspect current rest transforms
3. inspect existing animation/IK code
4. reproduce the issue
5. make the smallest architectural fix possible
6. validate visually if possible
7. check continuous animation looping
8. run `git diff --check`

Do not repeatedly add new animation systems on top of broken old systems.

Remove or disable conflicting logic when replacing it.

---

# Git

The repository may contain uncommitted user work.

Treat all unrelated modifications as important user work.

Never commit or push unless explicitly requested.

Never overwrite unrelated changes.

Before editing a file that already has modifications, inspect the current
version first.

EOF
