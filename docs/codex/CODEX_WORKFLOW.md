# Codex Workflow

# New chat

Start important tasks with:

```text
Read AGENTS.md and the docs relevant to this task.
Inspect the current working tree before editing.
```

# Extra-high reasoning tasks

Use high reasoning effort for:

- animation/rig architecture
- retarget/modifier conflicts
- swing physics
- traversal state architecture
- city generator refactor
- streaming/performance architecture
- multiplayer networking
- boss architecture

Simple parameter changes do not need an architecture rewrite.

# Implementation loop

```text
1. Read source of truth.
2. Inspect current repo/status.
3. Inspect actual implementation.
4. Find conflicts / ownership.
5. Plan minimal robust fix.
6. Implement.
7. Run Godot/runtime checks when possible.
8. Inspect visuals if task is visual.
9. Run git diff --check.
10. Report exact changes.
```

# Visual tasks

A screenshot/video is stronger evidence than a comment saying "looks fixed".

If visual reference exists:

- inspect it
- identify visible failure
- define measurable pose/layout correction
- compare result

# Do not let prompts drift

A run-arm task should not redesign the city.

A city task should not rewrite swing physics.

A main-menu task should not replace gameplay architecture.

# Research

For uncertain Godot APIs, use official Godot docs for the relevant version.

For reference games, extract principles. Do not copy proprietary assets.
