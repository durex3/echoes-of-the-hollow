#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
artifacts="$project_root/artifacts"
visual=false
full=false
godot_bin="${GODOT_BIN:-}"

usage() {
    echo "Usage: tools/check.sh [--full] [--visual] [--godot PATH]" >&2
}

while (($#)); do
    case "$1" in
        --full|-Full) full=true ;;
        --visual|-Visual) visual=true ;;
        --godot|-GodotPath)
            if (($# < 2)); then usage; exit 2; fi
            godot_bin="$2"
            shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage; echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

if [[ -z "$godot_bin" ]]; then
    if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
        godot_bin=/Applications/Godot.app/Contents/MacOS/Godot
    elif command -v godot >/dev/null 2>&1; then
        godot_bin="$(command -v godot)"
    else
        echo "Godot not found. Use --godot PATH or set GODOT_BIN." >&2
        exit 1
    fi
fi
if [[ ! -x "$godot_bin" ]]; then
    echo "Godot is not executable: $godot_bin" >&2
    exit 1
fi

if command -v python3 >/dev/null 2>&1; then
    python_bin="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
    python_bin="$(command -v python)"
else
    echo "Python 3 is required for tools/static_check.py." >&2
    exit 1
fi

mkdir -p "$artifacts"
touch "$artifacts/.gdignore"
version="$("$godot_bin" --headless --version)"
if [[ ! "$version" =~ ^4\.7\.2\. ]]; then
    echo "Expected Godot 4.7.2; got $version" >&2
    exit 1
fi
echo "Engine: $version"
"$python_bin" "$project_root/tools/static_check.py"

run_godot() {
    local name="$1"
    shift
    local log="$artifacts/$name.log"
    echo "Running $name..."
    if ! "$godot_bin" --path "$project_root" "$@" >"$log" 2>&1; then
        tail -n 50 "$log" >&2
        echo "$name failed; see $log" >&2
        exit 1
    fi
    if grep -Eq '^(SCRIPT ERROR:|ERROR:|FAIL:)' "$log"; then
        grep -En '^(SCRIPT ERROR:|ERROR:|FAIL:)' "$log" | head -n 20 >&2
        echo "$name reported an engine/test error; see $log" >&2
        exit 1
    fi
    if [[ "$name" == integration || "$name" == visual || "$name" == current || "$name" == current_visual ]]; then
        require_marker "$name" 'TEST_RESULT: [0-9]+ checks, 0 failures'
    fi
    grep -E '(RESULT:|ROUTE_PASS:|CHAPTER_TWO_PASS:|CISTERN_EXPLORATION_PASS:)' "$log" | tail -n 8 || true
}

require_marker() {
    local name="$1" pattern="$2"
    if ! grep -Eq "$pattern" "$artifacts/$name.log"; then
        echo "$name did not finish with expected result: $pattern" >&2
        exit 1
    fi
}

run_godot import --headless --editor --import

stagger_args=(--headless --fixed-fps 60 res://tests/enemy_stagger_suite.tscn)
ai_args=(--headless --fixed-fps 60 res://tests/bell_ai_suite.tscn)
chapter_ai_args=(--headless --fixed-fps 60 res://tests/chapter_enemy_ai_suite.tscn)
wall_args=(--headless --fixed-fps 60 res://tests/wall_echo_metrics.tscn)
bell_args=(--headless --fixed-fps 60 res://tests/bell_court_suite.tscn)
if "$visual"; then
    stagger_args=(--fixed-fps 60 --max-fps 60 res://tests/enemy_stagger_suite.tscn -- --visual)
    ai_args=(--fixed-fps 60 --max-fps 60 res://tests/bell_ai_suite.tscn -- --visual)
    chapter_ai_args=(--fixed-fps 60 --max-fps 60 res://tests/chapter_enemy_ai_suite.tscn -- --visual)
    wall_args=(--fixed-fps 60 --max-fps 60 res://tests/wall_echo_metrics.tscn -- --visual)
    bell_args=(--fixed-fps 60 --max-fps 60 res://tests/bell_court_suite.tscn -- --visual)
fi

run_godot enemy_stagger "${stagger_args[@]}"
require_marker enemy_stagger 'ENEMY_STAGGER_RESULT: [0-9]+ checks, 0 failures'
run_godot counter_damage --headless --fixed-fps 60 res://tests/counter_damage_suite.tscn
require_marker counter_damage 'COUNTER_DAMAGE_RESULT: [0-9]+ checks, 0 failures'
run_godot bell_ai "${ai_args[@]}"
require_marker bell_ai 'BELL_AI_RESULT: [0-9]+ checks, 0 failures'
run_godot chapter_enemy_ai "${chapter_ai_args[@]}"
require_marker chapter_enemy_ai 'CHAPTER_ENEMY_AI_RESULT: [0-9]+ checks, 0 failures'
run_godot wall_echo "${wall_args[@]}"
require_marker wall_echo 'WALL_ECHO_RESULT: [0-9]+ checks, 0 failures'
run_godot bell_court "${bell_args[@]}"
require_marker bell_court 'BELL_COURT_RESULT: [0-9]+ checks, 0 failures'
require_marker bell_court 'BELL_ROUTE_PASS:'
run_godot bell_court_baseline --headless --fixed-fps 60 res://tests/bell_court_suite.tscn -- --baseline
require_marker bell_court_baseline 'BELL_COURT_RESULT: [0-9]+ checks, 0 failures'
require_marker bell_court_baseline 'BELL_ROUTE_PASS:.*baseline=true'
if "$visual"; then
    run_godot bell_branch --fixed-fps 60 --max-fps 60 res://tests/bell_branch_suite.tscn -- --visual
else
    run_godot bell_branch --headless --fixed-fps 60 res://tests/bell_branch_suite.tscn
fi
require_marker bell_branch 'BELL_BRANCH_RESULT: [0-9]+ checks, 0 failures'
if "$visual"; then
	run_godot bell_heart --fixed-fps 60 --max-fps 60 res://tests/bell_heart_suite.tscn -- --visual
else
	run_godot bell_heart --headless --fixed-fps 60 res://tests/bell_heart_suite.tscn
fi
require_marker bell_heart 'BELL_HEART_RESULT: [0-9]+ checks, 0 failures'
if "$visual"; then
	run_godot confluence_bridge --fixed-fps 60 --max-fps 60 res://tests/confluence_bridge_suite.tscn -- --visual
else
	run_godot confluence_bridge --headless --fixed-fps 60 res://tests/confluence_bridge_suite.tscn
fi
require_marker confluence_bridge 'CONFLUENCE_RESULT: [0-9]+ checks, 0 failures'
if "$visual"; then
	run_godot bell_warden --fixed-fps 60 --max-fps 60 res://tests/bell_warden_suite.tscn -- --visual
else
	run_godot bell_warden --headless --fixed-fps 60 res://tests/bell_warden_suite.tscn
fi
require_marker bell_warden 'BELL_WARDEN_RESULT: [0-9]+ checks, 0 failures'

if ! "$full"; then
    if "$visual"; then
        run_godot current_visual --fixed-fps 60 --max-fps 60 res://tests/test_runner.tscn -- --current --visual
    else
        run_godot current --headless --fixed-fps 60 res://tests/test_runner.tscn -- --current
    fi
    echo 'Current chapter checks passed. Use --full for complete regression.'
    exit 0
fi

run_godot integration --headless --fixed-fps 60 res://tests/test_runner.tscn
run_godot chapter_route --headless --fixed-fps 60 res://tests/chapter_route.tscn
require_marker chapter_route 'ROUTE_PASS: combat_first'
require_marker chapter_route 'ROUTE_PASS: wind_first'
run_godot chapter_two_route --headless --fixed-fps 60 res://tests/chapter_two_route.tscn
require_marker chapter_two_route 'CHAPTER_TWO_PASS: flow_first'
require_marker chapter_two_route 'CHAPTER_TWO_PASS: pressure_first'
run_godot cistern_exploration --headless --fixed-fps 60 res://tests/cistern_exploration_route.tscn
require_marker cistern_exploration 'CISTERN_EXPLORATION_PASS:'
run_godot save_write --headless --script res://tests/save_process.gd -- --write
run_godot save_read --headless --script res://tests/save_process.gd -- --read
run_godot chapter_two_save_write --headless --script res://tests/chapter_two_save_process.gd -- --write
run_godot chapter_two_save_read --headless --script res://tests/chapter_two_save_process.gd -- --read
run_godot language_write --headless --script res://tests/settings_process.gd -- --write
run_godot language_read --headless --script res://tests/settings_process.gd -- --read
if "$visual"; then
    run_godot visual --fixed-fps 60 --max-fps 60 res://tests/test_runner.tscn -- --visual
fi
echo 'All required checks passed.'
