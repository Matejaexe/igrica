# Godot 4.7 Animation / Skeleton Notes

# Skeleton3D

Bone hierarchy contains rest and pose transforms.

Critical project rule:

Imported Bone Pose neutral/reference behavior includes the imported rest
relationship. Do not assume `Quaternion.IDENTITY` means "return this imported
bone to its correct neutral orientation".

Skeleton3D global bone pose is skeleton/model space, not scene world space.

# RetargetModifier3D

Use for cross-rig pose transfer where appropriate.

Current concept:

```text
donor animated skeleton
-> donor canonical proxy
-> RetargetModifier3D
-> BRC canonical proxy
-> real BRC skeleton
```

For the current BRC experiment, rotation-only retargeting preserves target body
proportions.

# SkeletonProfileHumanoid

Canonical humanoid mapping currently used conceptually:

```text
DONOR
hip       -> Hips
waist     -> Spine
chest     -> Chest
neck      -> Neck
head      -> Head
l-arm     -> LeftUpperArm
l-forearm -> LeftLowerArm
r-arm     -> RightUpperArm
r-forearm -> RightLowerArm
l-thigh   -> LeftUpperLeg
l-leg     -> LeftLowerLeg
l-foot    -> LeftFoot
r-thigh   -> RightUpperLeg
r-leg     -> RightLowerLeg
r-foot    -> RightFoot

BRC
hips  -> Hips
s1    -> Spine
s2    -> Chest
neck  -> Neck
head  -> Head
shldl -> LeftShoulder
arm1l -> LeftUpperArm
arm2l -> LeftLowerArm
handl -> LeftHand
shldr -> RightShoulder
arm1r -> RightUpperArm
arm2r -> RightLowerArm
handr -> RightHand
leg1l -> LeftUpperLeg
leg2l -> LeftLowerLeg
footl -> LeftFoot
toesl -> LeftToes
leg1r -> RightUpperLeg
leg2r -> RightLowerLeg
footr -> RightFoot
toesr -> RightToes
```

# TwoBoneIK3D

Godot 4.7 has a native two-bone IK solver.

Use anatomical chains:

```text
arm1 -> arm2 -> hand
leg1 -> leg2 -> foot
```

Target determines end location.

Pole target determines bending plane.

A correct target with a bad pole can still produce a bad elbow/knee twist.

# Modifier ordering

Possible pipeline:

```text
AnimationPlayer / AnimationTree
-> RetargetModifier3D
-> target SkeletonModifier3D / IK
-> final state-specific override if intentionally authoritative
-> skinning
```

If multiple systems write the same bone, identify the final owner.

Do not add another animation layer until ownership is clear.

# Manual processing

`Skeleton3D.advance(delta)` can be useful when exact modifier ordering is
required.

Avoid:

- advancing twice
- never advancing a manual skeleton
- running direct overrides before a later modifier that immediately overwrites
  them

# Looping clips

Ground idle/walk/run must loop continuously.

Acceptance test:

```text
hold forward movement 30 seconds
```

Reject:

```text
2 seconds of animation -> static pose -> sliding
```

# AnimationTree long-term

A clean eventual structure may use:

```text
locomotion state machine
idle / run / air / land
+
movement modifiers
+
state-specific IK
```

Do not migrate just for architecture aesthetics while the current system is
being actively debugged unless the migration solves real complexity.
