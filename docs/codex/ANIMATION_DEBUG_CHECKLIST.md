# Animation Debug Checklist

# 1. Find bone writers

Search all code touching affected bones.

For run arms:

```bash
rg -n 'shldl|shldr|arm1l|arm1r|arm2l|arm2r|handl|handr' .
```

Make a temporary ownership table:

| Bone | Retarget | IK | Direct override | Final owner |
|---|---:|---:|---:|---|
| shldl | | | | |
| arm1l | | | | |
| arm2l | | | | |
| handl | | | | |

Repeat right side.

# 2. Measure actual positions

At useful animation phases print/inspect:

```text
shoulder
elbow
hand
```

Do not decide from local Euler values alone.

# 3. Three run phases

Inspect:

```text
left arm forward
neutral
left arm backward
```

At all three:

- elbow near torso
- elbow bend stable
- no forearm twist
- no hand/torso intersection
- opposite arm coordinated

# 4. Front view

Check:

- bird-wing arm spread
- hands crossing torso
- asymmetrical bad pose
- feet too narrow

# 5. Side view

Check:

- real forward/back arm travel
- knee recovery
- torso lean
- foot contact

# 6. Run loop

Hold movement at least 30 seconds.

Check:

- animation still cycling
- no sliding
- no gradual pose drift

# 7. Swing

Check:

- correct hand selected
- web origin follows final hand
- pose reacts to anchor side
- release preserves physics velocity
- trick does not alter trajectory unexpectedly

# 8. Aerial trick

Check:

- character rotates, camera remains readable
- trick can be interrupted
- no collision/physics freeze
- landing blends out before feet contact

# 9. Wall run

Check:

- body facing follows wall tangent
- lean toward wall
- no huge visual offset/floating
- limbs do not clip wall
- transition to jump/swing works

# 10. Code hygiene

```bash
git diff --check
git status --short
git diff
```

Report what was runtime-tested and what was only statically inspected.
