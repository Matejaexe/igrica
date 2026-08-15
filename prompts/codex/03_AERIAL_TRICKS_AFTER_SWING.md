```text
Read AGENTS.md and TRAVERSAL_AND_TRICKS.md.

Implement/polish an ORIGINAL aerial trick presentation layer for high-speed
swing releases.

The user wants cool flips/rolls after leaving a swing, similar in spirit to
expressive traversal games, but without copying exact animations.

Requirements:
- tricks are primarily cosmetic presentation
- preserve physics velocity and collision behavior
- trigger only with enough speed/airtime/clearance
- do not force a trick after every tiny release
- support a small varied library: forward tuck, back layout, barrel roll,
  corkscrew, tuck-to-extend, dive transition
- avoid repeating the same trick constantly
- tricks must interrupt immediately for web attach, zip, wall contact, attack,
  or landing
- camera horizon remains readable; body can rotate much more than camera
- final body should extend/reach naturally into next swing

Prefer state/animation architecture that can later support manual trick input.

Do not change swing physics just to make the animation work.
Do not commit/push.
```
