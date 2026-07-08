@tool
extends RefCounted
class_name BeckettRuntimeTools

## The DRIVE half of the play-test loop (L5 Drive): make the RUNNING game DO things.
## input injection, UI/3D/world clicks, drag, scroll, runtime writes/calls, frame
## stepping, input record/replay, and a property assertion.
##
## Every handler builds a `cmd` dict and ships it to the running game through
## server.bridge.send_command(). The game side (res://addons/beckett/runtime/mcp_runtime.gd,
## the BeckettRuntime autoload) already implements every one of these commands — it does
## NOT tier-check, so once this module is registered the agent can drive the game.
##
## This module is the Full-edition layer the free build withholds: it is distributed as
## source here so the agent can author + run + SEE the game for free, and DRIVE it by
## supplying this wrapper (which only forwards to a protocol the shipped runtime already
## speaks). No encryption, no patched binary — just the missing editor-side registration.

var server


func _register(registry) -> void:
	registry.register({
		"name": "runtime_call",
		"description": "Call a method on a node in the RUNNING game. Address by path (node path/name) OR a live selector: class (native or custom class_name) / name / text [+ nth, default 0]. args is a JSON array passed positionally via callv. Returns the method's result plus the 'resolved' path.",
		"readonly": false,
		"input_schema": {"type": "object", "properties": {
			"path": {"type": "string"}, "class": {"type": "string"}, "name": {"type": "string"},
			"text": {"type": "string"}, "nth": {"type": "integer"}, "under": {"type": "string"},
			"method": {"type": "string", "description": "method name to call"},
			"args": {"type": "array", "description": "positional args (JSON array)"},
		}, "required": ["method"]},
		"handler": Callable(self, "_runtime_call"),
	})
	registry.register({
		"name": "runtime_set_property",
		"description": "Set a property on a node in the RUNNING game. Address by path OR a live selector (class/name/text [+ nth]). Values are coerced to the live property's type, so stringified numbers/arrays land correctly. Returns the resolved path.",
		"readonly": false,
		"input_schema": {"type": "object", "properties": {
			"path": {"type": "string"}, "class": {"type": "string"}, "name": {"type": "string"},
			"text": {"type": "string"}, "nth": {"type": "integer"}, "under": {"type": "string"},
			"property": {"type": "string"}, "value": {"type": "string", "description": "value (any JSON; strings are coerced to the prop type)"},
		}, "required": ["property", "value"]},
		"handler": Callable(self, "_runtime_set"),
	})
	registry.register({
		"name": "simulate_input",
		"description": "Inject raw input events into the RUNNING game via Input.parse_input_event. events is an array of {type, ...} dicts: type=key {keycode, pressed?}, action {action, pressed?, strength?}, mouse_button {button, pressed?, position?}, mouse_motion {position, relative?}, joy_button, joy_axis, touch, touch_drag. Skips malformed entries. Returns the count dispatched.",
		"readonly": false,
		"input_schema": {"type": "object", "properties": {
			"events": {"type": "array", "description": "array of input-event dicts"},
		}, "required": ["events"]},
		"handler": Callable(self, "_simulate_input"),
	})
	registry.register({
		"name": "click_button_by_text",
		"description": "Find a BaseButton (or any Control, via class=) in the RUNNING game whose text contains `text`, and emit its 'pressed' signal. Matches by substring; use nth to pick among several; all=true lists every match instead of clicking. Under= scopes the search to a subtree. Bypasses the click-transform issues that swallow OS-level synthetic clicks.",
		"readonly": false,
		"input_schema": {"type": "object", "properties": {
			"text": {"type": "string"}, "class": {"type": "string"}, "under": {"type": "string"},
			"nth": {"type": "integer"}, "all": {"type": "boolean"},
		}, "required": ["text"]},
		"handler": Callable(self, "_click_text"),
	})
	registry.register({
		"name": "click_control",
		"description": "Click a Control in the RUNNING game by injecting press+release at its center in GUI space (viewport.push_input). Bypasses content-scale/stretch transforms that make parse_input_event miss buttons in containers. Target by path OR selector (class/name/text [+ nth, under]). Returns clicked + the gui-space point. If the control is clipped/off-screen it scrolls it into view and reports clicked=false so you can call again to land the hit.",
		"readonly": false,
		"input_schema": {"type": "object", "properties": {
			"path": {"type": "string"}, "class": {"type": "string"}, "name": {"type": "string"},
			"text": {"type": "string"}, "nth": {"type": "integer"}, "under": {"type": "string"},
			"button": {"type": "integer", "description": "mouse button index (1=left)"},
		}},
		"handler": Callable(self, "_click_control"),
	})
	registry.register({
		"name": "click_node3d",
		"description": "Click a Node3D in the RUNNING game by projecting its origin (or AABB center) to the screen via the active Camera3D, then injecting motion+press+release there. For games doing their own mouse picking. Target by path OR selector (class/name/text [+ nth, under]).",
		"readonly": false,
		"input_schema": {"type": "object", "properties": {
			"path": {"type": "string"}, "class": {"type": "string"}, "name": {"type": "string"},
			"text": {"type": "string"}, "nth": {"type": "integer"}, "under": {"type": "string"},
			"button": {"type": "integer"},
		}},
		"handler": Callable(self, "_click_node3d"),
	})
	registry.register({
		"name": "click_world",
		"description": "Click at a 3D WORLD position in the RUNNING game: unproject [x,y,z] via the active Camera3D, inject the click there. Use for clicking a point in space rather than a node.",
		"readonly": false,
		"input_schema": {"type": "object", "properties": {
			"position": {"type": "array", "description": "[x, y, z] world position"},
			"button": {"type": "integer"},
		}, "required": ["position"]},
		"handler": Callable(self, "_click_world"),
	})
	registry.register({
		"name": "scroll",
		"description": "Mouse-wheel scroll in the RUNNING game at a target Control's center (path/selector) or an explicit gui-space position. amount>0 scrolls down, <0 up; |amount| = wheel notches.",
		"readonly": false,
		"input_schema": {"type": "object", "properties": {
			"position": {"type": "array", "description": "[x, y] gui-space point"},
			"path": {"type": "string"}, "class": {"type": "string"}, "name": {"type": "string"},
			"text": {"type": "string"}, "nth": {"type": "integer"}, "under": {"type": "string"},
			"amount": {"type": "integer", "description": "wheel notches, sign = direction"},
		}},
		"handler": Callable(self, "_scroll"),
	})
	registry.register({
		"name": "drag",
		"description": "Press at `from`, glide through `steps` interpolated motions to `to`, release — in gui space. For sliders, drag-and-drop, camera pans. Coordinates are gui-space (like click_control).",
		"readonly": false,
		"input_schema": {"type": "object", "properties": {
			"from": {"type": "array", "description": "[x, y] start"},
			"to": {"type": "array", "description": "[x, y] end"},
			"button": {"type": "integer"}, "steps": {"type": "integer"},
		}, "required": ["from", "to"]},
		"handler": Callable(self, "_drag"),
	})
	registry.register({
		"name": "get_control_rect",
		"description": "Report a Control's rect in BOTH gui/canvas space and screen space (content-scale applied), so the agent can click with the right coordinates. Target by path OR selector (class/name/text [+ nth, under]).",
		"readonly": true,
		"input_schema": {"type": "object", "properties": {
			"path": {"type": "string"}, "class": {"type": "string"}, "name": {"type": "string"},
			"text": {"type": "string"}, "nth": {"type": "integer"}, "under": {"type": "string"},
		}},
		"handler": Callable(self, "_control_rect"),
	})
	registry.register({
		"name": "find_ui_elements",
		"description": "Find LIVE UI nodes in the RUNNING game by class/name/text (and optional subtree scope). Wraps the game-side 'find' command. Returns matched paths + classes (+ text). Use to locate a button before click_control.",
		"readonly": true,
		"input_schema": {"type": "object", "properties": {
			"class": {"type": "string"}, "name": {"type": "string"}, "text": {"type": "string"},
			"path": {"type": "string"}, "recursive": {"type": "boolean"}, "max": {"type": "integer"},
		}},
		"handler": Callable(self, "_find_ui"),
	})
	registry.register({
		"name": "record_input",
		"description": "Start or stop capturing the RUNNING game's real input stream. action='start' begins recording (print()/signal-driven events); action='stop' returns the captured event array. Pair with replay_input to reproduce a sequence.",
		"readonly": false,
		"input_schema": {"type": "object", "properties": {
			"action": {"type": "string", "description": "start | stop"},
		}, "required": ["action"]},
		"handler": Callable(self, "_record"),
	})
	registry.register({
		"name": "replay_input",
		"description": "Re-inject a previously captured (or hand-built) input event array into the RUNNING game, exactly like simulate_input. Pass the events array returned by record_input(action='stop').",
		"readonly": false,
		"input_schema": {"type": "object", "properties": {
			"events": {"type": "array"},
		}, "required": ["events"]},
		"handler": Callable(self, "_replay"),
	})
	registry.register({
		"name": "time_control",
		"description": "Frame/time control in the RUNNING game. action: freeze (pause), unfreeze (resume), step {frames}, step_until {condition, max_frames?, timeout_sec?}, time_scale {value 0.01..10}, status. Lets the agent advance the simulation deterministically and inspect state between frames.",
		"readonly": false,
		"input_schema": {"type": "object", "properties": {
			"action": {"type": "string", "description": "freeze | unfreeze | step | step_until | time_scale | status"},
			"frames": {"type": "integer"}, "condition": {"type": "string"},
			"max_frames": {"type": "integer"}, "timeout_sec": {"type": "number"},
			"value": {"type": "number"},
		}, "required": ["action"]},
		"handler": Callable(self, "_time_control"),
	})
	registry.register({
		"name": "assert_node_state",
		"description": "Assertion tool (read-only): read a node property in the RUNNING game and compare it to an expected value. Address by path OR selector. Returns {pass, property, expected, actual}. Float compares with epsilon; mismatched types fall back to string compare. Use inside the play-test loop to verify a click had the intended effect.",
		"readonly": true,
		"input_schema": {"type": "object", "properties": {
			"path": {"type": "string"}, "class": {"type": "string"}, "name": {"type": "string"},
			"text": {"type": "string"}, "nth": {"type": "integer"}, "under": {"type": "string"},
			"property": {"type": "string"}, "equals": {"type": "string", "description": "expected value (any JSON)"},
		}, "required": ["property", "equals"]},
		"handler": Callable(self, "_assert_node_state"),
	})


## ---- helpers -------------------------------------------------------------

func _game_err() -> Dictionary:
	return {"error": "game not running (runtime channel not connected) — play_scene, then wait_until condition=game_connected"}


func _send(cmd: Dictionary) -> Dictionary:
	if server == null or server.bridge == null or not server.bridge.is_game_connected():
		return _game_err()
	return server.bridge.send_command(cmd)


## Wrap a game reply: ok -> {json: reply}, not ok -> {error}.
func _json(r: Dictionary) -> Dictionary:
	if not bool(r.get("ok", false)):
		return {"error": str(r.get("error", "command failed"))}
	return {"json": r}


## Copy path + selector fields (class/name/text/nth/under) from tool args into a
## bridge cmd, so every runtime node op accepts either a path or a live selector.
func _add_target(cmd: Dictionary, args: Dictionary) -> void:
	for k in ["path", "class", "name", "text", "nth", "under"]:
		if args.has(k):
			cmd[k] = args[k]


## ---- handlers ------------------------------------------------------------

func _runtime_call(args: Dictionary) -> Dictionary:
	var cmd := {"cmd": "call", "method": str(args.get("method", ""))}
	if args.has("args"):
		cmd["args"] = args["args"] if args["args"] is Array else [args["args"]]
	_add_target(cmd, args)
	return _json(_send(cmd))


func _runtime_set(args: Dictionary) -> Dictionary:
	var cmd := {"cmd": "set", "prop": str(args.get("property", "")), "value": args.get("value", null)}
	_add_target(cmd, args)
	return _json(_send(cmd))


func _simulate_input(args: Dictionary) -> Dictionary:
	var events = args.get("events", [])
	if not (events is Array):
		return {"error": "events must be an array of input-event dicts"}
	return _json(_send({"cmd": "input", "events": events}))


func _click_text(args: Dictionary) -> Dictionary:
	var cmd := {"cmd": "click_text", "text": str(args.get("text", ""))}
	if str(args.get("class", "")) != "":
		cmd["class"] = args["class"]
	if args.has("under"):
		cmd["under"] = args["under"]
	if args.has("nth"):
		cmd["nth"] = args["nth"]
	if bool(args.get("all", false)):
		cmd["all"] = true
	return _json(_send(cmd))


func _click_control(args: Dictionary) -> Dictionary:
	var cmd := {"cmd": "click_control"}
	_add_target(cmd, args)
	if args.has("button"):
		cmd["button"] = args["button"]
	return _json(_send(cmd))


func _click_node3d(args: Dictionary) -> Dictionary:
	var cmd := {"cmd": "click_node3d"}
	_add_target(cmd, args)
	if args.has("button"):
		cmd["button"] = args["button"]
	return _json(_send(cmd))


func _click_world(args: Dictionary) -> Dictionary:
	var p = args.get("position", null)
	if not (p is Array and (p as Array).size() >= 3):
		return {"error": "position must be [x, y, z]"}
	var cmd := {"cmd": "click_world", "position": p}
	if args.has("button"):
		cmd["button"] = args["button"]
	return _json(_send(cmd))


func _scroll(args: Dictionary) -> Dictionary:
	var cmd := {"cmd": "scroll"}
	if args.has("position"):
		cmd["position"] = args["position"]
	else:
		_add_target(cmd, args)
	if args.has("amount"):
		cmd["amount"] = args["amount"]
	return _json(_send(cmd))


func _drag(args: Dictionary) -> Dictionary:
	var cmd := {"cmd": "drag", "from": args.get("from", []), "to": args.get("to", [])}
	if args.has("button"):
		cmd["button"] = args["button"]
	if args.has("steps"):
		cmd["steps"] = args["steps"]
	return _json(_send(cmd))


func _control_rect(args: Dictionary) -> Dictionary:
	var cmd := {"cmd": "control_rect"}
	_add_target(cmd, args)
	return _json(_send(cmd))


func _find_ui(args: Dictionary) -> Dictionary:
	var cmd := {"cmd": "find"}
	for k in ["class", "name", "text", "path", "recursive", "max"]:
		if args.has(k):
			cmd[k] = args[k]
	return _json(_send(cmd))


func _record(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	if action == "start":
		return _json(_send({"cmd": "record_start"}))
	if action == "stop":
		return _json(_send({"cmd": "record_stop"}))
	return {"error": "record_input action must be 'start' or 'stop'"}


func _replay(args: Dictionary) -> Dictionary:
	var events = args.get("events", [])
	if not (events is Array):
		return {"error": "events must be an array"}
	return _json(_send({"cmd": "input", "events": events}))


func _time_control(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"freeze":
			return _json(_send({"cmd": "tc_freeze"}))
		"unfreeze":
			return _json(_send({"cmd": "tc_unfreeze"}))
		"step":
			return _json(_send({"cmd": "tc_step", "frames": maxi(1, int(args.get("frames", 1)))}))
		"step_until":
			return _json(_send({"cmd": "tc_step_until",
				"condition": str(args.get("condition", "")),
				"max_frames": int(args.get("max_frames", 0)),
				"timeout_sec": float(args.get("timeout_sec", 10.0))}))
		"time_scale":
			return _json(_send({"cmd": "tc_time_scale", "value": float(args.get("value", 1.0))}))
		"status":
			return _json(_send({"cmd": "tc_status"}))
		_:
			return {"error": "unknown time_control action: %s (freeze|unfreeze|step|step_until|time_scale|status)" % action}


func _assert_node_state(args: Dictionary) -> Dictionary:
	var cmd := {"cmd": "get", "prop": str(args.get("property", ""))}
	_add_target(cmd, args)
	var r := _send(cmd)
	if not bool(r.get("ok", false)):
		return {"error": str(r.get("error", "get failed"))}
	var actual = r.get("value")
	var expected = args.get("equals", null)
	var passed := _values_equal(actual, expected)
	return {"json": {
		"pass": passed,
		"property": str(args.get("property", "")),
		"expected": expected,
		"actual": actual,
		"resolved": str(r.get("resolved", "")),
	}}


## Compare two values for an assertion: equal types compare directly; floats use an
## epsilon; otherwise fall back to stringified comparison so "19" == 19 reads as equal.
func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) == typeof(b):
		if typeof(a) == TYPE_FLOAT:
			return absf(float(a) - float(b)) < 0.0001
		return a == b
	var sa := str(a)
	var sb := str(b)
	if sa == sb:
		return true
	if sa.is_valid_float() and sb.is_valid_float():
		return absf(float(sa) - float(sb)) < 0.0001
	return false
