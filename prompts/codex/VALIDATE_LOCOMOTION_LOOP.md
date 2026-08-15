# Continuous locomotion loop validation

```text
Read AGENTS.md and docs/codex/GODOT_ANIMATION_NOTES.md.
Audit ground locomotion playback.

Prevent this bug:
1 animation works for one clip
2 animation stops
3 velocity continues
4 character slides

Inspect donor loop modes, AnimationPlayer state, imported names, transitions, speed_scale and all play/stop/restart code.

Acceptance test: hold forward movement at least 30 seconds; animation must continuously cycle without sliding.
Do not modify player movement physics.
Run git diff --check. Do not commit or push.
```
