## Shared player intent contract for non-combat domains.
## UI signals are translated into this value before exploration, event, or
## inventory state is allowed to change.
class_name PlayerCommand
extends RefCounted

const TYPES := [
	"move", "end_turn", "rest", "save", "menu", "settings", "sheet",
	"event_choice", "event_roll", "inventory_buy", "inventory_rest",
]

var kind: String
var payload: Dictionary


func _init(command_kind: String, data: Dictionary = {}) -> void:
	kind = command_kind
	payload = data.duplicate(true)


static func from_ui(command_kind: String, data: Dictionary = {}) -> PlayerCommand:
	if command_kind not in TYPES:
		return null
	var command := PlayerCommand.new(command_kind, data)
	return command if command.is_valid() else null


static func move(target: Vector2i) -> PlayerCommand:
	return from_ui("move", {"target_hex": [target.x, target.y]})


static func simple(command_kind: String) -> PlayerCommand:
	return from_ui(command_kind, {})


static func event_choice(option: Dictionary) -> PlayerCommand:
	return from_ui("event_choice", {"option": option})


static func event_roll() -> PlayerCommand:
	return simple("event_roll")


static func inventory_buy(player_index: int, item_id: String) -> PlayerCommand:
	return from_ui("inventory_buy", {"player_index": player_index, "item_id": item_id})


static func inventory_rest() -> PlayerCommand:
	return simple("inventory_rest")


func is_valid() -> bool:
	if kind not in TYPES:
		return false
	match kind:
		"move":
			var raw_target: Variant = payload.get("target_hex", [])
			return raw_target is Array and (raw_target as Array).size() == 2
		"event_choice":
			return payload.get("option", {}) is Dictionary and not payload.get("option", {}).is_empty()
		"inventory_buy":
			return int(payload.get("player_index", -1)) >= 0 and not str(payload.get("item_id", "")).is_empty()
	return true


func target_hex() -> Vector2i:
	var raw_target: Array = payload.get("target_hex", [0, 0])
	return Vector2i(int(raw_target[0]), int(raw_target[1]))
