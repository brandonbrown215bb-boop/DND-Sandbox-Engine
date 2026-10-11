## Validated player intent entering the combat domain.
## Device and HUD signals remain presentation details; combat receives only
## commands with a known action type and the payload required by that type.
class_name CombatCommand
extends RefCounted

const TYPES := ["attack", "cast_spell", "activate_magic_item", "use_feature", "use_item", "eat_goodberry", "font_of_magic_convert", "font_of_magic_create", "toggle_find_steed_mount", "move_dancing_lights", "move_moonbeam", "move_cloud_of_daggers", "move_conjure_animals", "move_conjure_celestial", "move_conjure_fey", "conjure_woodland_beings_disengage", "dismiss_light", "detect_magic_inspect", "control_mage_hand", "dismiss_mage_hand", "dodge", "end_turn", "cancel", "move"]

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
		"activate_magic_item":
			var instance_id := str(command.payload.get("instance_id", ""))
			var charges := int(command.payload.get("charges", 0))
			var item := character.inventory.get_instance(instance_id)
			if str(item.get("definition_id", "")) != "wand_of_magic_missiles" or character.inventory.equipped_instance_id(Inventory.Slot.HANDS) != instance_id or charges < 1 or charges > mini(3, int(item.get("state", {}).get("charges", 0))):
				return null
			command.payload["instance_id"] = instance_id
			command.payload["charges"] = charges
			var wand_spell := DataLoader.get_spell("magic_missile")
			if wand_spell.is_empty():
				return null
			wand_spell["_magic_item_activation"] = true
			wand_spell["_magic_item_instance_id"] = instance_id
			wand_spell["_magic_item_charges"] = charges
			wand_spell["_selected_spell_slot_level"] = charges
			wand_spell["_ignore_material_components"] = true
			wand_spell["_skip_counterspell"] = true
			command.payload["spell"] = wand_spell
		"cast_spell":
			var spell: Dictionary = command.payload.get("spell", {})
			var spell_id := str(spell.get("id", ""))
			if spell_id.is_empty() or spell_id not in character.known_spells:
				return null
			var production_spell := DataLoader.get_spell(spell_id)
			if production_spell.is_empty() or not str(production_spell.get("trigger", "")).is_empty():
				return null
			var wants_wizard_free_cast := bool(spell.get("_wizard_free_cast", false))
			var wants_wizard_slot_cast := bool(spell.get("_force_spell_slot", false))
			if wants_wizard_free_cast or wants_wizard_slot_cast:
				var free_cast: Dictionary = character.free_spell_cast_feature(spell_id)
				var is_wizard_capstone: bool = character.class_id == "wizard" and str(free_cast.get("feature_id", "")) in ["wizard_spell_mastery", "wizard_signature_spells"]
				if not is_wizard_capstone or wants_wizard_free_cast == wants_wizard_slot_cast:
					return null
				if wants_wizard_slot_cast and CombatAction.get_spell_slot_level(character, production_spell) <= 0:
					return null
				if wants_wizard_slot_cast:
					var eligible_slot := false
					for slot_level in character.spell_slots:
						if int(slot_level) >= int(production_spell.get("level", 0)) and int(character.spell_slots[slot_level]) > 0:
							eligible_slot = true
							break
					if not eligible_slot:
						return null
				production_spell["_wizard_free_cast"] = wants_wizard_free_cast
				production_spell["_force_spell_slot"] = wants_wizard_slot_cast
			command.payload["spell"] = production_spell.duplicate(true)
		"use_feature":
			var feature: Dictionary = command.payload.get("feature", {})
			var selected_spell_slot_level := int(feature.get("selected_spell_slot_level", 0))
			var owned_feature := character.get_feature(str(feature.get("id", ""))).duplicate(true)
			if owned_feature.is_empty():
				owned_feature = FamiliarRules.command_feature(character, str(feature.get("id", "")))
			if owned_feature.is_empty():
				owned_feature = CreatedCreatureRules.command_feature(character, str(feature.get("id", "")))
			var has_slot_recovery := false
			for effect in owned_feature.get("effects", []):
				if effect.get("type", "") == "resource_from_spell_slot":
					has_slot_recovery = true
				elif effect.get("type", "") == "damage_ward_pool" and bool(effect.get("bonus_action_slot_recharge", false)):
					has_slot_recovery = true
			if owned_feature.is_empty() or (str(owned_feature.get("type", "")) != "active" and not has_slot_recovery):
				return null
			if has_slot_recovery:
				owned_feature["selected_spell_slot_level"] = selected_spell_slot_level
			if feature.has("selected_action"):
				var allowed: Array = owned_feature.get("options", ["dash", "disengage", "hide"] if owned_feature.get("id", "") == "rogue_cunning_action" else [])
				if str(feature["selected_action"]) not in allowed:
					return null
				owned_feature["selected_action"] = str(feature["selected_action"])
			command.payload["feature"] = owned_feature
		"detect_magic_inspect":
			if not SpellEffects.has_spell(character, "detect_magic"):
				return null
		"use_item":
			var item: Dictionary = command.payload.get("item", {})
			var item_id := str(item.get("id", ""))
			if item_id.is_empty() or str(item.get("type", "")) != "consumable" or not character.inventory.has_item(item_id):
				return null
		"eat_goodberry":
			if SpellEffects.goodberry_count_for_party(PartyManager.characters.values()) <= 0:
				return null
		"font_of_magic_convert":
			var conversion_level := int(command.payload.get("slot_level", 0))
			if character.class_id != "sorcerer" or conversion_level not in SorcererRules.available_slot_conversion_levels(character):
				return null
			command.payload["slot_level"] = conversion_level
		"font_of_magic_create":
			var creation_level := int(command.payload.get("slot_level", 0))
			if character.class_id != "sorcerer" or creation_level not in SorcererRules.available_created_slot_levels(character):
				return null
			command.payload["slot_level"] = creation_level
		"move_dancing_lights":
			if str(character.concentrating_on.get("spell_id", "")) != "dancing_lights":
				return null
		"move_moonbeam":
			if str(character.concentrating_on.get("spell_id", "")) != "moonbeam":
				return null
		"move_cloud_of_daggers":
			if str(character.concentrating_on.get("spell_id", "")) != "cloud_of_daggers":
				return null
		"move_conjure_animals":
			if str(character.concentrating_on.get("spell_id", "")) != "conjure_animals":
				return null
		"move_conjure_celestial":
			if str(character.concentrating_on.get("spell_id", "")) != "conjure_celestial":
				return null
		"move_conjure_fey":
			if str(character.concentrating_on.get("spell_id", "")) != "conjure_fey":
				return null
		"conjure_woodland_beings_disengage":
			if str(character.concentrating_on.get("spell_id", "")) != "conjure_woodland_beings":
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
		"activate_magic_item":
			return not str(payload.get("instance_id", "")).is_empty() and int(payload.get("charges", 0)) in [1, 2, 3]
		"font_of_magic_convert", "font_of_magic_create":
			return int(payload.get("slot_level", 0)) > 0
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
