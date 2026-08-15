# Athlete-style ground run arms

```text
Read AGENTS.md and all relevant docs/codex animation docs first.

Fix ONLY the BRC Spider ground-running arm silhouette. Treat attached screenshot/video as acceptance criteria.

TARGET
- shoulders compact and relaxed
- elbows close to torso
- elbow visually around 85-100 degrees
- upper arms swing forward/back
- forearms do NOT independently twist/roll with stride
- hands stay outside torso
- no bird-wing/T-pose silhouette
- no 6-7/meme-like inward/outward forearm sweep

First inspect every system writing:
shldl shldr arm1l arm1r arm2l arm2r handl handr

There must be ONE authoritative ground-run result.

Preferred simple final behavior:
- shoulder: intentional compact run pose derived from BRC geometry
- arm1: only stride-driven forward/back rotation
- arm2: stable local elbow-bend pose
- hand: stable local orientation

Do NOT assume shoulder Bone Rest itself is a good authored run pose.
Measure actual Skeleton3D-space shoulder/elbow/hand positions.
Do not blindly flip quaternion signs.
Do not reintroduce moving run elbow poles unless absolutely necessary.
If run TwoBoneIK causes forearm rotation, fade/disable that run IK.

The final run-arm pose must execute after donor retarget and after any modifier that could overwrite it.

Validate left-forward, neutral, left-backward phases. At all phases verify compact elbows, stable elbow bend, hands outside torso, no forearm twist, true forward/back side-view motion, small lateral spread.

Do not modify legs, city, movement physics, BRC GLB, swing, wall-run, combat or idle.

Run git diff --check. Do not commit or push.
Report conflicting logic removed, final owner per arm bone, how swing is generated, how elbow bend is held, and how shoulder abduction is prevented.
```
