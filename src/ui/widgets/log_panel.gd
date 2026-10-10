class_name LogPanel
extends RichTextLabel

## LogPanel — severity-aware, auto-scrolling log used by every HUD.
## Wraps a RichTextLabel with log_info / warning / danger helpers that prepend
## a colored tag, cap history (ring buffer), and auto-scroll. Replaces the
## hand-rolled `add_log()` string-concat each HUD used to do (Pattern F,
## UI_OVERHAUL_RESEARCH.md). Severity colors come from the active UI profile.
## The visible Chronicle consumes resolved records; this hidden compatibility
## sink preserves legacy callers and their integration assertions.
##
## Wiring in BaseHUD: assign `log_text = some LogPanel` in each subclass _ready.
## The old `add_log(msg)` / `clear_logs()` API still works (delegates here), so
## existing HUD calls and harness assertions on `log_text` keep passing.

const MAX_LINES := 200

signal line_added(tag: String, color: String, msg: String)

func _ready() -> void:
	bbcode_enabled = true
	fit_content = false
	scroll_following = true

func _push(tag: String, color: String, msg: String) -> void:
	line_added.emit(tag, color, msg)
	var line := "[color=%s][%s][/color] %s" % [color, tag, msg]
	text += line + "\n"
	# ring buffer: trim oldest lines beyond cap
	var lines := text.split("\n", false)
	if lines.size() > MAX_LINES:
		text = "\n".join(lines.slice(lines.size() - MAX_LINES))
	# auto-scroll to bottom
	await get_tree().process_frame
	var sb = get_v_scroll_bar()
	if sb:
		sb.value = sb.max_value

func log_info(msg: String) -> void:
	_push("info", UiThemeProfile.current().color("state/info").to_html(), msg)

func log_success(msg: String) -> void:
	_push("ok", UiThemeProfile.current().color("state/success").to_html(), msg)

func log_warning(msg: String) -> void:
	_push("warn", UiThemeProfile.current().color("state/warning").to_html(), msg)

func log_danger(msg: String) -> void:
	_push("danger", UiThemeProfile.current().color("state/danger").to_html(), msg)

## Backwards-compatible shim: plain add_log now routes through info severity.
func add_log(msg: String) -> void:
	log_info(msg)

func clear_logs() -> void:
	text = ""
