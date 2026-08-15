# Human Locomotion and Stylized Character Motion

This is a practical game-animation reference.

It combines broad human biomechanics principles with an intentionally stylized
game target.

The exact pose values in this project are artistic targets, not claims that all
humans move at exactly those angles.

# Idle

Desired relaxed stance:

- feet slightly apart
- knees soft, not hyper-locked
- pelvis balanced
- shoulders relaxed/down
- elbows lower than action pose
- hands outside torso
- small breathing/weight-shift motion only if subtle

Avoid:

- feet on one centerline
- T-pose shoulders
- elbows held high
- constant jitter

# Ground run

The default movement is already fast; there is no sprint button.

The run should feel athletic and stylized.

## Arms

Project target:

```text
shoulder/upper arm = main forward/back driver
elbow              = stable strong bend (~85–100° visual target)
forearm             = follows; no independent stride-driven roll
hand                = stable, outside torso
```

Front view:

```text
        torso
       /     \
   elbow     elbow
     |         |
   hand      hand
```

Reject:

```text
elbow -------- torso -------- elbow
```

and reject hands crossing the torso centerline.

## Arm/leg opposition

Readable natural pattern:

```text
left leg forward  -> right arm forward
right leg forward -> left arm forward
```

## Torso

Use subtle counter-rotation and forward athletic intent.

Do not over-twist the chest to compensate for bad arm animation.

## Legs

Readable cycle:

```text
contact
-> support/compression
-> push-off
-> recovery with knee bend / heel rise
-> forward swing
-> next contact
```

Avoid:

- rigid straight knees
- permanent tiptoe stance
- foot never recovering
- sliding after animation loop ends

# Jump

Jump should clearly leave the run cycle.

Use:

- leg extension at takeoff
- body extension
- optional arm response

Ground IK must fade out.

# Fall

Allow a readable airborne silhouette.

High-speed fall can use a more extended/dive-like pose.

Do not let the character look frozen in run.

# Landing

Landing should absorb impact through:

```text
ankle + knee + hip
```

Strong landing:

- lower center of mass
- readable compression
- recover to movement without long animation lock

# Swing body language

Swing animation should follow actual physics state.

Useful inputs:

- velocity direction
- speed
- rope direction
- anchor side
- swing phase
- distance from bottom of arc
- release timing

Possible pose families:

```text
one-hand reach
two-hand extension
tuck
long stretched line
dive
compressed bottom-of-arc pose
release extension
```

# Wall run

Wall run is not ground run rotated sideways.

Desired:

- body leans toward wall
- forward direction follows projected wall tangent
- feet/legs read as running along surface
- wall-side arm can compact/brace
- outer arm balances
- no deep wall clipping

# Visual validation

Always inspect:

```text
front
side
three-quarter
```

For run also inspect three phases:

```text
left arm forward
neutral crossing
left arm backward
```
