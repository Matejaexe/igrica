```text
Read AGENTS.md plus the rig/locomotion/animation docs first.

Fix ONLY the BRC Spider ground-run arm silhouette.

Target an athletic run:
- shoulders compact and relaxed
- elbows close to ribs
- elbows visually around 85-100 degrees
- upper arms swing forward/back
- forearms do not independently twist with stride
- hands stay outside torso
- no bird-wing/T-pose shape

Inspect every system that writes shld/arm1/arm2/hand bones and establish ONE
final owner for ground run.

Do not assume shoulder rest is automatically a good run shoulder pose.
Measure actual shoulder/elbow/hand Skeleton3D-space positions.

Validate front, side, and three stride phases.

Do not change legs, city, player physics, BRC GLB, swing, wall run, or idle.
Run git diff --check.
Do not commit or push.
```
