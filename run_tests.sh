#!/usr/bin/env bash
set -uo pipefail

PROJECT="$(cd "$(dirname "$0")" && pwd)"
GODOT="${1:-${GODOT_BIN:-}}"
if [ -z "$GODOT" ]; then GODOT="$(command -v godot 2>/dev/null || true)"; fi
if [ -z "$GODOT" ]; then GODOT="$(command -v godot4 2>/dev/null || true)"; fi
if [ -z "$GODOT" ]; then
  echo "ERROR: Godot 4.7.x was not found. Set GODOT_BIN or pass the portable executable as arg 1." >&2
  exit 2
fi
if [ ! -x "$GODOT" ]; then
  echo "ERROR: Godot binary is not executable: $GODOT" >&2
  exit 2
fi

PARSE_TIMEOUT_SECONDS="${PARSE_TIMEOUT_SECONDS:-60}"
BOOT_TIMEOUT_SECONDS="${BOOT_TIMEOUT_SECONDS:-30}"
LOGIC_TIMEOUT_SECONDS="${LOGIC_TIMEOUT_SECONDS:-300}"
SCENARIO_TIMEOUT_SECONDS="${SCENARIO_TIMEOUT_SECONDS:-60}"
if [ -n "${TEST_LOG_DIR:-}" ]; then
  LOG_DIR="$TEST_LOG_DIR"
  mkdir -p "$LOG_DIR"
else
  LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/top-down-party-game-tests.XXXXXX")"
fi

# The Windows host can emit this certificate-store warning before the project
# starts. Leaks and resource errors are evidence and must remain visible.
IGNORED_ENGINE_NOISE='Failed to read the root certificate store'
FAILED=0

run_case() {
  local name="$1" scene="$2" marker="$3" timeout_seconds="$4"
  shift 4
  local log_file="$LOG_DIR/${name}.log"
  local user_data_dir="$LOG_DIR/${name}.user-data"
  mkdir -p "$user_data_dir/data" "$user_data_dir/config" "$user_data_dir/cache" "$user_data_dir/state"
  local -a command=("$GODOT" --headless --log-file "$LOG_DIR/${name}.godot.log" --path "$PROJECT" "$scene" "$@")
  echo ""
  echo "=================================================================="
  echo ">> Running: $name"
  echo "    Scene: $scene"
  echo "    Log:   $log_file"
  echo "=================================================================="
  XDG_DATA_HOME="$user_data_dir/data" \
  XDG_CONFIG_HOME="$user_data_dir/config" \
  XDG_CACHE_HOME="$user_data_dir/cache" \
  XDG_STATE_HOME="$user_data_dir/state" \
    timeout "$timeout_seconds" "${command[@]}" >"$log_file" 2>&1
  local exit_code=$?
  cat "$log_file"
  local engine_errors
  engine_errors="$(grep -iE '(^|[[:space:]])(ERROR:|SCRIPT ERROR|Parse Error|Nonexistent function|Invalid call|Invalid get index|Cannot infer)' "$log_file" | grep -vE "$IGNORED_ENGINE_NOISE" || true)"
  if [ "$exit_code" -eq 124 ]; then
    echo ">> $name: FAILED (timed out after ${timeout_seconds}s)"
    return 1
  fi
  if [ "$exit_code" -ne 0 ]; then
    echo ">> $name: FAILED (Godot exit code $exit_code)"
    return 1
  fi
  if [ -n "$engine_errors" ]; then
    echo ">> $name: FAILED (unexpected Godot engine error)"
    echo "$engine_errors" | sed 's/^/    /'
    return 1
  fi
  if ! grep -Fq "$marker" "$log_file"; then
    echo ">> $name: FAILED (missing result marker: $marker)"
    return 1
  fi
  echo ">> $name: PASSED"
  return 0
}

if ! run_case "parse_gate" "res://scenes/parse_gate.tscn" "PARSE GATE PASSED" "$PARSE_TIMEOUT_SECONDS"; then
  # Review cafa R2: an unparseable runner or check file makes test_runner.tscn idle
  # until LOGIC_TIMEOUT_SECONDS (300 s). Stop here, as run_tests.ps1 already does.
  echo ">> Stopped: project parsing failed. Logs: $LOG_DIR"
  echo ">> OVERALL: FAILED"
  exit 1
fi
run_case "boot_gate" "res://scenes/boot_gate.tscn" "BOOT GATE PASSED" "$BOOT_TIMEOUT_SECONDS" || FAILED=1
TEST_SUITE="${TEST_SUITE:-all}"
case "$TEST_SUITE" in
  all|logic|integration) ;;
  *) echo "ERROR: TEST_SUITE must be all, logic, or integration" >&2; exit 2 ;;
esac

if [ "$TEST_SUITE" = "all" ] || [ "$TEST_SUITE" = "logic" ]; then
  run_case "logic" "res://scenes/test_runner.tscn" "ALL TESTS PASSED" "$LOGIC_TIMEOUT_SECONDS" || FAILED=1
  # Card cafa: the runner must have checked every registered check script.
  if ! grep -Eq 'CHECK SCRIPT GATE: [0-9]+ registered check scripts, 0 failed' "$LOG_DIR/logic.log"; then
    echo ">> logic: FAILED (check script gate missing or red: a registered check file did not load/parse)"
    FAILED=1
  fi
fi

# Keep this list synchronized with _run_scenario in viewport_harness.gd.
SCENARIOS=(combat combat_ai_loop combat_victory overworld main_menu_load dungeon event_dialog character_creation shop save_load combat_resolution event_choice_resolution event_dialog_choice_click character_sheet)
SCENARIOS+=(shared_spell_flow)
if [ "$TEST_SUITE" = "all" ] || [ "$TEST_SUITE" = "integration" ]; then
  for scenario in "${SCENARIOS[@]}"; do
    run_case "$scenario" "res://scenes/viewport_harness.tscn" "SCENARIO PASSED: $scenario" "$SCENARIO_TIMEOUT_SECONDS" "--scenario=$scenario" || FAILED=1
  done
fi

echo ""
echo ">> Test logs retained at: $LOG_DIR"
if [ "$FAILED" -ne 0 ]; then
  echo ">> OVERALL: FAILED"
  exit 1
fi
echo ">> OVERALL: ALL TESTS PASSED"
exit 0
