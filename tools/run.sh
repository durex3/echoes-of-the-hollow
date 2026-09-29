#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-}"
mode=game
baseline=false
boss=false

usage() {
    echo 'Usage: tools/run.sh [--editor | --preview [--baseline] [--boss]] [--godot PATH]' >&2
}

while (($#)); do
    case "$1" in
        --editor) mode=editor ;;
        --preview) mode=preview ;;
        --baseline) baseline=true ;;
        --boss) boss=true ;;
        --godot)
            if (($# < 2)); then usage; exit 2; fi
            godot_bin="$2"
            shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage; echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

if { "$baseline" || "$boss"; } && [[ "$mode" != preview ]]; then
    echo '--baseline requires --preview.' >&2
    exit 2
fi
if [[ -z "$godot_bin" ]]; then
    if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
        godot_bin=/Applications/Godot.app/Contents/MacOS/Godot
    elif command -v godot >/dev/null 2>&1; then
        godot_bin="$(command -v godot)"
    else
        echo 'Godot not found. Use --godot PATH or set GODOT_BIN.' >&2
        exit 1
    fi
fi
if [[ ! -x "$godot_bin" ]]; then
    echo "Godot is not executable: $godot_bin" >&2
    exit 1
fi

case "$mode" in
    editor) exec "$godot_bin" --path "$project_root" --editor ;;
    preview)
        preview_args=()
        if "$baseline"; then preview_args+=(--baseline); fi
        if "$boss"; then preview_args+=(--boss); fi
        if ((${#preview_args[@]})); then
            exec "$godot_bin" --path "$project_root" res://features/world/prototypes/bell_court_preview.tscn -- "${preview_args[@]}"
        fi
        exec "$godot_bin" --path "$project_root" res://features/world/prototypes/bell_court_preview.tscn ;;
    game) exec "$godot_bin" --path "$project_root" ;;
esac
