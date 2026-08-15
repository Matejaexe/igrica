# BRC Spider Character Rig — Source of Truth

## Protected model

```text
res://models/spidey/spidey_funk_alt_v2.glb
```

The corrected GLB has known-good mesh/skin/rest behavior.

Do not edit the GLB to solve animation mistakes.

## Model-space orientation

Approximate:

```text
+Y = up
+Z = model forward
+X = character-left
```

Verify signs for any new operation from actual transforms.

## Torso

```text
hips -> s1 -> s2 -> neck -> head
```

Known rig calibration evidence:

- torso chain local X corresponds to the chain/twist axis
- local Y is the useful sagittal flexion plane
- local Z produces lateral side-bend and previously caused persistent lean when
  incorrectly used as forward flex

## Arms

```text
LEFT:  shldl -> arm1l -> arm2l -> handl
RIGHT: shldr -> arm1r -> arm2r -> handr
```

Think:

```text
shoulder/clavicle -> upper arm -> elbow/forearm -> hand
```

Do not treat the entire arm as one stick.

## Legs

```text
LEFT:  leg1l -> leg2l -> footl -> toesl
RIGHT: leg1r -> leg2r -> footr -> toesr
```

Think:

```text
hip/thigh -> knee/shin -> ankle/foot -> toes
```

## Approximate measured global/rest positions

```text
hips   [ 0.0000, 0.9867, -0.0153 ]
s1     [ 0.0000, 1.1406, -0.0117 ]
s2     [ 0.0000, 1.2846, -0.0189 ]
neck   [ 0.0000, 1.4345, -0.0332 ]
head   [ 0.0000, 1.4796, -0.0345 ]

shldl  [ 0.0161, 1.3967, -0.0360 ]
arm1l  [ 0.1019, 1.3717, -0.0360 ]
arm2l  [ 0.2770, 1.1940, -0.0360 ]
handl  [ 0.4489, 1.0072, -0.0338 ]

leg1l  [ 0.0697, 0.9150, -0.0153 ]
leg2l  [ 0.0910, 0.5504, -0.0313 ]
footl  [ 0.1035, 0.1557, -0.0475 ]
toesl  [ 0.1084, 0.0471,  0.1473 ]
```

Right side is approximately mirrored in X.

## Bone rest rule

Imported Bone Rest is the rig reference.

Do NOT use `Quaternion.IDENTITY` as a generic neutral imported pose.

But do not confuse:

```text
correct rig rest
```

with:

```text
ideal authored running pose
```

For example, a shoulder may need an intentional run correction from rest to
avoid wide abducted arms.

## Debug rule

For every bad arm pose, inspect actual positions:

```text
shoulder
elbow
hand
```

For every bad leg pose:

```text
hip
knee
foot
```

The visible model-space chain is the truth.

## Current run-arm visual target

Athletic, compact:

- shoulder/upper arm near torso
- elbow about 85–100 degrees as a game target
- upper arm drives forward/back swing
- forearm does not perform stride-driven independent twist
- hand remains outside torso
- no bird-wing / T-pose silhouette

## Web-hand rule

- grapple left of camera -> left hand
- grapple right of camera -> right hand
- near center -> alternate

Visible web should originate from the selected final hand pose.
