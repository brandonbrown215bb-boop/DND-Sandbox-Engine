#!/usr/bin/env bash
# run_tests.sh — one-command in-engine test runner for Top Down Party Game.
# Boots the real Godot 4.7 engine and runs BOTH scene-based harnesses:
#   1. test_runner.tscn   — logic/unit tests (data, character, combat, ai, ...)
#   2. viewport_harness.tscn — real combat/overworld/dungeon/UI scenes in a
#      headless SubViewport (event dialog, character creation, shop, save/load)
# Both exercise actual game code, not Python mirrors. Exits non-zero if either
# harness reports a failure.
#
# Usage:  ./run_tests.sh [path/to/godot-binary]
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="${1:-/home/pigeon/Desktop/Godot_v4.7-stable_linux.x86_64}"
PROJECT="$DIR"

# Filter harmless headless teardown noise (no display -> leaked RIDs on quit).
REDACT='WARNING:.*leaked|ObjectDB instances were leaked|resources still in use'

if [ ! -x "$GODOT" ]; then
  echo "ERROR: Godot binary not found/executable: $GODOT" >&2
  echo "Pass it as arg 1, or edit GODOT default in this script." >&2
  exit 2
fi

run_harness() {
  # $1 = scene, $2 = success marker
  local scene="$1" marker="$2"
  echo ""
  echo "=================================================================="
  echo ">> Running: $scene"
  echo "=================================================================="
  local out
  out="$("$GODOT" --headless --path "$PROJECT" "$scene" 2>&1 | grep -vE "$REDACT")"
  echo "$out"
  if echo "$out" | grep -qE "\[FAIL\]|$marker"; then
    if echo "$out" | grep -q "$marker"; then
      echo ">> $scene: PASSED"
      return 0
    fi
  fi
  echo ">> $scene: FAILED"
  return 1
}

FAILED=0

run_harness "res://scenes/test_runner.tscn" "ALL TESTS PASSED" || FAILED=1
run_harness "res://scenes/viewport_harness.tscn" "VIEWPORT TESTS PASSED" || FAILED=1

echo ""
if [ "$FAILED" -ne 0 ]; then
  echo ">> OVERALL: FAILED (one or more harnesses reported failures)"
  exit 1
fi
echo ">> OVERALL: ALL TESTS PASSED"
exit 0
