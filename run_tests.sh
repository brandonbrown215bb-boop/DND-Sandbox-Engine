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

# ---------------------------------------------------------------------------
# Pre-flight parse gate: syntax-check EVERY script in the project before
# booting any scene. A typo only surfaces at runtime otherwise, and a broken
# script referenced by a harness scene makes that scene fail to parse -> the
# run hangs (engine idles) instead of erroring.
#
# NOTE: a whole-project `--check-only` HANGS on a broken script (does not fail
# fast), so we check file-by-file. Each file gets its own `timeout` guard so a
# single file that hangs still aborts instead of stalling the whole gate.
# Per-file `--check-only --script` returns in ~0.3s and prints the error.
# ---------------------------------------------------------------------------
echo "=================================================================="
echo ">> Pre-flight: parsing all scripts (--check-only, per-file)"
echo "=================================================================="
PARSE_FAILS=0
# Collect every .gd under src/ and scenes/ (exclude theme/ dev utilities which
# use project class_names and are not game code).
mapfile -t GD_FILES < <(find "$PROJECT/src" "$PROJECT/scenes" -name '*.gd' 2>/dev/null | grep -vE "/theme/" | sort)
for f in "${GD_FILES[@]}"; do
  rel="res://$(realpath --relative-to="$PROJECT" "$f")"
  # Single per-file parse check with a hard timeout so a hanging file cannot
  # stall the gate. ~0.3s per file when clean; prints the error if broken.
  out="$(timeout 25 "$GODOT" --headless --path "$PROJECT" --check-only --script "$rel" 2>&1)"
  rc=$?
  err="$(echo "$out" | grep -iE 'Parse Error|Expected .* but found|SCRIPT ERROR.*Parse' | head -1)"
  if [ -n "$err" ] || [ "$rc" -eq 124 ]; then
    echo "  [BAD] $rel"
    [ -n "$err" ] && echo "        $err"
    [ "$rc" -eq 124 ] && echo "        (timed out — likely a hang/parse loop)"
    PARSE_FAILS=$((PARSE_FAILS + 1))
  fi
done
if [ "$PARSE_FAILS" -ne 0 ]; then
  echo ">> Pre-flight: FAILED ($PARSE_FAILS script(s) with parse errors) — aborting before scene boot."
  exit 1
fi
echo ">> Pre-flight: all ${#GD_FILES[@]} scripts parsed clean"

# ---------------------------------------------------------------------------
# Boot-error gate: a harness can report "0 failed" while the engine still
# logged SCRIPT ERRORs the assertions never tripped (see CHANGELOG 2026-07-07
# honesty addendum). A real headless boot surfaces those. Fail the run if any
# runtime error/parse error fires during boot. The game does not self-terminate,
# so the boot is wrapped in `timeout 30` (we only need the first frames of
# startup to surface scene-parse / script errors). Filter the harmless headless
# teardown leaks (no display -> leaked RIDs on quit).
# ---------------------------------------------------------------------------
echo ""
echo "=================================================================="
echo ">> Boot-error gate: booting main.tscn headless, scanning for errors"
echo "=================================================================="
BOOT_OUT="$(timeout 30 "$GODOT" --headless --path "$PROJECT" "res://scenes/main.tscn" 2>&1 | grep -vE "$REDACT")"
BOOT_ERR="$(echo "$BOOT_OUT" | grep -iE 'SCRIPT ERROR|Nonexistent function|Parse Error|Cannot infer' | grep -v 'leaked' | head -5)"
BOOT_GATE_FAIL=0
if [ -n "$BOOT_ERR" ]; then
  echo ">> Boot-error gate: FAILED — engine logged runtime/parse errors:"
  echo "$BOOT_ERR" | sed 's/^/    /'
  BOOT_GATE_FAIL=1
else
  echo ">> Boot-error gate: clean (no SCRIPT ERROR / Nonexistent function / Parse Error)"
fi

FAILED=0

run_harness "res://scenes/test_runner.tscn" "ALL TESTS PASSED" || FAILED=1
run_harness "res://scenes/viewport_harness.tscn" "VIEWPORT TESTS PASSED" || FAILED=1

if [ "$BOOT_GATE_FAIL" -ne 0 ]; then
  FAILED=1
fi

echo ""
if [ "$FAILED" -ne 0 ]; then
  echo ">> OVERALL: FAILED (one or more harnesses reported failures)"
  exit 1
fi
echo ">> OVERALL: ALL TESTS PASSED"
exit 0
