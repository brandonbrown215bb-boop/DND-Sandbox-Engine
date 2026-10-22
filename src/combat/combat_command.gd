## Validated player intent entering the combat domain.
## Device and HUD signals remain presentation details; combat receives only
## commands with a known action type and the payload required by that type.
class_name CombatCommand
extends RefCounted

const TYPES := ["command_created_actor", "choose_aura_protection", "use_captured_grant", "dismiss_source_benefit", "attack", "cast_spell", "activate_magic_item", "use_feature", "use_item", "eat_goodberry", "font_of_magic_convert", "font_of_magic_create", "toggle_find_steed_mount", "move_dancing_lights", "move_moonbeam", "move_cloud_of_daggers", "move_conjure_animals", "move_conjure_celestial", "move_conjure_fey", "conjure_woodland_beings_disengage", "dismiss_light", "dismiss_timed_numeric_modifier", "choose_protection", "detect_magic_inspect", "control_mage_hand", "dismiss_mage_hand", "dodge", "end_turn", "cancel", "move"]

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
			if spell_id.is_empty():
				return null
			var production_spell := DataLoader.get_spell(spell_id).duplicate(true)
			if production_spell.is_empty() or not str(production_spell.get("trigger", "")).is_empty():
				return null
			var permissions := SpellPermissionRules.for_spell(character, production_spell)
			var permission_id := str(spell.get("_source_permission_id", ""))
			var permission: Dictionary = {}
			for candidate in permissions:
				if not permission_id.is_empty() and str(candidate.get("id", "")) == permission_id:
					permission = candidate
					break
			if permission.is_empty():
				return null
			if not SpellPermissionRules.selection_valid(character, spell):
				return null
			var selected_payment := str(spell.get("_spell_payment_kind", ""))
			production_spell["_source_permission_id"] = str(permission.get("id", ""))
			production_spell["_source_permissions"] = permissions.duplicate(true)
			production_spell["_spellcasting_ability"] = str(permission.get("ability", character.get_spellcasting_ability()))
			production_spell["_spell_payment_kind"] = selected_payment
			for field in ["_spell_payment_source_id", "_selected_spell_slot_level", "_spell_slot_pool_id"]:
				if spell.has(field):
					production_spell[field] = spell[field]
			production_spell["_force_spell_slot"] = selected_payment == "slot"
			production_spell["_arcanum_payment"] = selected_payment == "free_cast" and permission.source_id == "warlock_mystic_arcanum"
			command.payload["spell"] = production_spell.duplicate(true)
		"use_captured_grant":
			var grant_id := str(command.payload.get("grant_id", ""))
			if not CapturedGrantRules.query(character).any(func(grant): return grant.grant_id == grant_id): return null
			command.payload = {"grant_id":grant_id}
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
			if owned_feature.has("resource_pool"):
				var source_instance_id := str(feature.get("source_instance_id", ""))
				var pool_state := ResourcePoolRules.availability(character, source_instance_id)
				if source_instance_id.is_empty() or not pool_state.has("owner_id") or str(character.numeric_resource_pools.get(source_instance_id, {}).get("definition_id", "")) != str(owned_feature["resource_pool"].get("id", "")):
					return null
				owned_feature["source_instance_id"] = source_instance_id
				if owned_feature["resource_pool"].has("die_size") and not owned_feature.has("transfer_grant") and not owned_feature.has("allocation"):
					var selected_quantity: Variant = feature.get("selected_pool_quantity", null)
					if not selected_quantity is int:
						return null
					var pool_availability := ClassFeature.availability(character, owned_feature, null, source_instance_id, int(selected_quantity))
					if not pool_availability.get("available", false):
						return null
					owned_feature["selected_pool_quantity"] = int(selected_quantity)
			if owned_feature.has("resource_exchange"):
				var exchange: Variant = owned_feature["resource_exchange"]
				if not exchange is Dictionary:
					return null
				var payment_source_id := str(feature.get("selected_payment_source_instance_id", ""))
				var restoration_source_id := str(feature.get("selected_restoration_source_instance_id", ""))
				var exchange_state := ResourcePoolRules.exchange(character, payment_source_id, restoration_source_id, str(exchange.get("payment_pool_id", "")), int(exchange.get("payment_quantity", 0)), str(exchange.get("restoration_pool_id", "")), int(exchange.get("restoration_quantity", 0)), false, str(exchange.get("restoration_recipient", "self")) == "party_member")
				if not exchange_state.get("success", false):
					return null
				owned_feature["selected_payment_source_instance_id"] = payment_source_id
				owned_feature["selected_restoration_source_instance_id"] = restoration_source_id
			if has_slot_recovery:
				owned_feature["selected_spell_slot_level"] = selected_spell_slot_level
			if feature.has("selected_action"):
				var allowed: Array = owned_feature.get("options", ["dash", "disengage", "hide"] if owned_feature.get("id", "") == "rogue_cunning_action" else [])
				if str(feature["selected_action"]) not in allowed:
					return null
				owned_feature["selected_action"] = str(feature["selected_action"])
			command.payload["feature"] = owned_feature
		"choose_aura_protection":
			var group := str(command.payload.get("group", ""))
			if AuraProtectionRules.offers(character, group).is_empty(): return null
			command.payload = {"group":group}
		"choose_protection":
			var group := str(command.payload.get("group",""))
			if not ProtectionRules.owned(character).any(func(g): return g.effect.group==group and g.effect.stacking=="exclusive"): return null
			command.payload={"group":group}
		"command_created_actor": # Batch 055 S-156: only an exact actor id, a declared order and an optional target id travel.
			var created_id: String = str(command.payload.get("actor_id", ""))
			var created_order: String = str(command.payload.get("order", ""))
			if created_id.is_empty() or created_order not in CreatedCommandRules.ORDERS: return null
			var created_data: Dictionary = {"actor_id": created_id, "order": created_order}
			if command.payload.has("target_id"): created_data["target_id"] = str(command.payload.get("target_id", ""))
			command.payload = created_data
		"dismiss_source_benefit":
			var source := str(command.payload.get("source_instance_id", ""))
			if not SourceBenefitRules.can_dismiss(character, source): return null
			command.payload = {"source_instance_id":source}
		"dismiss_timed_numeric_modifier":
			var source_id := str(command.payload.get("source_instance_id", ""))
			var grant_id := str(command.payload.get("grant_instance_id", ""))
			if source_id.is_empty() or grant_id.is_empty() or not character.has_campaign_modifier_grant(source_id, grant_id, int(GameManager.campaign_elapsed_seconds)):
				return null
		"detect_magic_inspect":
			if not SpellEffects.has_spell(character, "detect_magic"):
				return null
		"use_item":
			var item: Dictionary = command.payload.get("item", {})
			var item_id := str(item.get("id", ""))
			var production := DataLoader.get_item(item_id).duplicate(true)
			if production.get("type") != "consumable" or not character.inventory.has_item(item_id): return null
			if item.has("instance_id"):
				var copy := character.inventory.get_instance(str(item.instance_id))
				if copy.get("definition_id") != item_id or not character.inventory.backpack_instances().any(func(entry): return entry.instance_id == item.instance_id): return null
				production["instance_id"] = str(item.instance_id)
			command.payload = {"item":production}
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
		"choose_protection", "choose_aura_protection":
			return payload.size()==1 and payload.get("group") is String and str(payload.group).is_valid_identifier()
		"command_created_actor":
			return not str(payload.get("actor_id", "")).is_empty() and str(payload.get("order", "")) in CreatedCommandRules.ORDERS
		"dismiss_source_benefit":
			return payload.size() == 1 and not str(payload.get("source_instance_id", "")).is_empty()
		"dismiss_timed_numeric_modifier":
			return not str(payload.get("source_instance_id", "")).is_empty() and not str(payload.get("grant_instance_id", "")).is_empty()
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
