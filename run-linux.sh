#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
godot_executable="${GODOT_BIN:-}"
if [[ -z "$godot_executable" ]]; then
    for candidate in godot godot4; do
        if command -v "$candidate" >/dev/null 2>&1; then
            godot_executable="$(command -v "$candidate")"
            break
        fi
    done
fi
if [[ -z "$godot_executable" ]]; then
    for candidate in "$HOME/.local/share/Steam/steamapps/common/Godot Engine/godot.x11.opt.tools.64" "$HOME/.steam/steam/steamapps/common/Godot Engine/godot.x11.opt.tools.64"; do
        if [[ -x "$candidate" ]]; then
            godot_executable="$candidate"
            break
        fi
    done
fi
if [[ -z "$godot_executable" ]]; then
    printf 'Godot 4.7.2 nije pronađen. Postavi GODOT_BIN na njegovu izvršnu datoteku.\n' >&2
    exit 1
fi
exec "$godot_executable" --path "$project_dir" "$@"
