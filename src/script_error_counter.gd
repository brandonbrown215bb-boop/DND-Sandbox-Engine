## Review cafa R1: a runtime SCRIPT ERROR aborts the check function it hits and
## silently drops the rest of that group, while the runner still counted only
## the asserts that ran ("ALL TESTS PASSED", exit 0). This logger counts script
## errors so the runner itself turns red, not only the wrapper's log grep.
class_name ScriptErrorCounter
extends Logger

var count := 0
var first := ""
var _lock := Mutex.new()

func _log_error(function: String, file: String, line: int, _code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != Logger.ERROR_TYPE_SCRIPT: return
	_lock.lock()
	count += 1
	if first.is_empty(): first = "%s (%s:%d in %s)" % [rationale if not rationale.is_empty() else _code, file, line, function]
	_lock.unlock()

func _log_message(_message: String, _error: bool) -> void:
	pass
