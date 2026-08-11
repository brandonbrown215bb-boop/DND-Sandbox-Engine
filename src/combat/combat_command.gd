## Validated player intent entering the combat domain.
## Device and HUD signals remain presentation details; combat receives only
## commands with a known action type and the payload required by that type.
class_name CombatCommand
extends RefCounted

const TYPES := ["attack", "cast_spell", "use_feature", "use_item", "dodge", "end_turn", "cancel", "move"]

var action_type: String
var payload: Dictionary


func _init(kind: String, data: Dictionary = {}) -> void:
	action_type = kind
	payload = data.duplicate(true)


static func from_hud(kind: String, data: Dictionary) -> CombatCommand:
	if kind not in TYPES:
		return null
	var command := CombatCommand.new(kind, data)
	if not command.is_valid():
		return null
	return command


## Validate a command against the active character before combat state changes.
## The generic HUD boundary checks shape; this boundary checks ownership and
## production content access.
static func from_hud_for_character(kind: String, data: Dictionary, character: Character) -> CombatCommand:
	var command := from_hud(kind, data)
	if command == null or character == null:
		return null
	match command.action_type:
		"cast_spell":
			var spell: Dictionary = command.payload.get("spell", {})
			var spell_id := str(spell.get("id", ""))
			if spell_id.is_empty() or spell_id not in character.known_spells:
				return null
		"use_feature":
			var feature: Dictionary = command.payload.get("feature", {})
			if not character.has_feature(str(feature.get("id", ""))):
				return null
		"use_item":
			var item: Dictionary = command.payload.get("item", {})
			var item_id := str(item.get("id", ""))
			if item_id.is_empty() or str(item.get("type", "")) != "consumable" or not character.inventory.has_item(item_id):
				return null
	return command


static func movement(target: Vector2i) -> CombatCommand:
	return CombatCommand.new("move", {"target_hex": [target.x, target.y]})


func is_valid() -> bool:
	if action_type not in TYPES:
		return false
	match action_type:
		"cast_spell":
			return payload.get("spell", {}) is Dictionary and not payload.get("spell", {}).is_empty()
		"use_feature":
			return payload.get("feature", {}) is Dictionary and not payload.get("feature", {}).is_empty()
		"use_item":
			return payload.get("item", {}) is Dictionary and not payload.get("item", {}).is_empty()
		"move":
			var raw_target: Variant = payload.get("target_hex", [])
			if not raw_target is Array:
				return false
			var target: Array = raw_target
			return target.size() == 2
	return true


func target_hex() -> Vector2i:
	var target: Array = payload.get("target_hex", [0, 0])
	return Vector2i(int(target[0]), int(target[1]))
