#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${GODOT_BIN:-}" ]]; then
    exec "$GODOT_BIN" --path "$project_dir" "$@"
fi
for engine in godot godot4 "$HOME/Disk/Godot_v4.6.1-stable_linux.x86_64"; do
    if command -v "$engine" >/dev/null 2>&1; then
        exec "$engine" --path "$project_dir" "$@"
    fi
done
printf '%s\n' 'Godot 4.6 is required. Set GODOT_BIN to the editor executable.' >&2
exit 1
