# Relaxed idle stance

```text
Read AGENTS.md and the character/locomotion docs.
Fix ONLY the BRC ground idle stance.

Target:
- relaxed human standing silhouette
- elbows lower
- hands outside torso
- shoulders not T-posed
- feet slightly separated
- knees not locked
- no shared centerline feet
- no toe-tip stance

Do not guess leg spread with random axis signs. Prefer understandable foot/knee target geometry if appropriate. Idle correction must fade cleanly when locomotion starts and must not fight the donor run.

Validate front, side, three-quarter. Do not modify run architecture, city, physics or BRC GLB.
Run git diff --check. Do not commit or push.
```
