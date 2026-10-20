## Inventory
## Manages a character's items and equipment slots.
class_name Inventory
extends RefCounted

## Equipment slot names.
enum Slot {
	WEAPON,
	SHIELD,
	HEAD,
	BODY,
	HANDS,
	FEET,
	RING_1,
	RING_2,
	OFFHAND,
}

## Equipped items: Slot -> item_id (String).
var equipped: Dictionary = {}

## Backpack items: Array of item_id strings.
var backpack: Array[String] = []

## Gold/currency.
var gold: int = 0

## Catalog projections above remain compatible; copies retain individual state.
var copies := InventoryCopies.new()
## S-060 receipt of the latest real spend; transient, not saved.
var last_charge_receipt: Dictionary = {}
## Test-only injection of the declared aftermath roll for the next spend.
var forced_last_charge_roll: int = 0
## Runtime owner link used only to publish actual equipment changes.
var owner_character_ref: WeakRef

## Maximum backpack size.
const MAX_BACKPACK_SIZE := 40

func _publish_equipment_change(definition_id: String, state: String, instance_id: String) -> void:
	var owner_character = owner_character_ref.get_ref() if owner_character_ref != null else null
	if owner_character != null:
		SpellEffects.publish_event(owner_character, {"type": "equipment", "actor_id": SpellEffects.caster_id(owner_character), "equipment": definition_id, "state": state, "instance_id": instance_id})


## Add an item to the backpack.
func add_item(item_id: String) -> bool:
	copies.sync(self)
	var item_data := DataLoader.get_item(item_id)
	if item_data.is_empty():
		push_warning("[Inventory] Unknown item, cannot add: %s" % item_id)
		return false
	if backpack.size() >= MAX_BACKPACK_SIZE:
		push_warning("[Inventory] Backpack full, cannot add: %s" % item_id)
		return false
	_add_single_item(item_id)
	return true


func _add_single_item(item_id: String) -> void:
	backpack.append(item_id)
	var record := copies.create(item_id)
	copies.records[record["instance_id"]] = record
	copies.backpack.append(record["instance_id"])


func _pack_content_ids(item_data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var contents: Variant = item_data.get("pack_contents", [])
	if not contents is Array:
		return result
	for entry in contents:
		if not entry is Dictionary:
			return []
		var child_id := str(entry.get("item_id", ""))
		var quantity := int(entry.get("quantity", 0))
		if child_id.is_empty() or DataLoader.get_item(child_id).is_empty() or quantity < 1 or quantity > MAX_BACKPACK_SIZE:
			return []
		for _index in quantity:
			result.append(child_id)
	return result


func expand_pack_instance(instance_id: String) -> Dictionary:
	copies.sync(self)
	var record: Dictionary = copies.records.get(instance_id, {})
	var item_id := str(record.get("definition_id", ""))
	var pack_contents := _pack_content_ids(DataLoader.get_item(item_id))
	if pack_contents.is_empty():
		return {"success": false, "message": "This item is not an expandable pack."}
	var backpack_index := copies.backpack.find(instance_id)
	if backpack_index < 0:
		return {"success": false, "message": "The pack must be in the backpack."}
	if backpack.size() - 1 + pack_contents.size() > MAX_BACKPACK_SIZE:
		return {"success": false, "message": "There is not enough backpack space to expand this pack."}
	backpack.remove_at(backpack_index)
	copies.backpack.remove_at(backpack_index)
	copies.records.erase(instance_id)
	for child_item_id in pack_contents:
		_add_single_item(child_item_id)
	return {"success": true, "contents_added": pack_contents.size(), "message": "%s expanded into %d supplies." % [DataLoader.get_item(item_id).get("name", item_id), pack_contents.size()]}


## Remove an item from the backpack (first occurrence).
func remove_item(item_id: String) -> bool:
	copies.sync(self)
	var idx := backpack.find(item_id)
	if idx >= 0:
		if bool(copies.records.get(copies.backpack[idx], {}).get("state", {}).get("cursed_attunement", false)):
			return false
		copies.records.erase(copies.backpack[idx])
		copies.backpack.remove_at(idx)
		backpack.remove_at(idx)
		return true
	return false


## Check if the backpack contains a specific item.
func has_item(item_id: String) -> bool:
	return item_id in backpack


## Count how many of a specific item are in the backpack.
func count_item(item_id: String) -> int:
	var count := 0
	for item in backpack:
		if item == item_id:
			count += 1
	return count


## Check for a specific consumed spell component that meets its listed value.
func has_spell_component(item_id: String, minimum_value: int) -> bool:
	if not has_item(item_id):
		return false
	return int(DataLoader.get_item(item_id).get("value", 0)) >= minimum_value


## Return the owned copy that can satisfy a priced or consumed Material
## component. Matching by copy lets the cast consume the right item later.
func required_spell_component_instance(spell_data: Dictionary) -> String:
	var consumed := bool(spell_data.get("material_component_consumed", false))
	var minimum_value := int(spell_data.get("material_component_cost", 0))
	if not consumed and minimum_value <= 0:
		return ""
	var item_id := str(spell_data.get("material_component_item_id", spell_data.get("consumed_material_item_id", "")))
	if item_id.is_empty():
		return ""
	copies.sync(self)
	for instance_id in copies.backpack:
		var record: Dictionary = copies.records.get(instance_id, {})
		if str(record.get("definition_id", "")) == item_id and int(DataLoader.get_item(item_id).get("value", 0)) >= minimum_value:
			return str(instance_id)
	return ""


func has_spellcasting_focus(class_id: String) -> bool:
	for item_id in backpack:
		if _is_compatible_spellcasting_focus(item_id, class_id):
			return true
	return false


func _is_compatible_spellcasting_focus(item_id: String, class_id: String) -> bool:
	if item_id == "component_pouch":
		return true
	if item_id in ["arcane_crystal", "arcane_orb", "arcane_rod", "arcane_staff", "arcane_wand"]:
		return class_id in ["sorcerer", "warlock", "wizard"]
	if item_id == "wooden_staff":
		return class_id in ["druid", "ranger"]
	if item_id == "holy_symbol":
		return class_id in ["cleric", "paladin"]
	if item_id in ["lute", "bagpipes", "drum", "dulcimer", "flute", "horn", "lyre", "pan_flute", "shawm", "viol"]:
		return class_id == "bard"
	return false


## Spell components and a spellcasting focus or pouch need one usable hand.
## Equipped weapons and a shield occupy their normal hands; a two-handed
## weapon occupies both. The cast can be attempted only when a hand is free.
func available_spellcasting_hands() -> int:
	var occupied := 0
	var weapon_id := str(equipped.get(Slot.WEAPON, ""))
	if not weapon_id.is_empty():
		occupied += 2 if "two_handed" in DataLoader.get_item(weapon_id).get("properties", []) else 1
	if not str(equipped.get(Slot.SHIELD, "")).is_empty():
		occupied += 1
	if not str(equipped.get(Slot.OFFHAND, "")).is_empty():
		occupied += 1
	var hand_item := str(equipped.get(Slot.HANDS, ""))
	if not hand_item.is_empty() and str(DataLoader.get_item(hand_item).get("type", "")) == "wand":
		occupied += 1
	return maxi(0, 2 - occupied)


## Context-matched tool bonuses apply to checks while the copy is carried.
## Equal bonuses do not stack; the best matching tool is used.
func skill_tool_bonus(skill: String, context: String) -> int:
	if skill.is_empty() or context.is_empty():
		return 0
	var best_bonus := 0
	var item_ids: Array = backpack.duplicate()
	item_ids.append_array(equipped.values())
	for item_id in item_ids:
		for effect in DataLoader.get_item(str(item_id)).get("effects", []):
			if not effect is Dictionary or str(effect.get("type", "")) != "skill_bonus":
				continue
			if str(effect.get("skill", "")).to_lower() != skill.to_lower() or str(effect.get("context", "")) != context:
				continue
			best_bonus = maxi(best_bonus, int(effect.get("bonus", 0)))
	return best_bonus


## Resolve one task-specific tool benefit from an exact carried tool copy.
## Check context can select an authored match, but never supplies its own bonus.
func skill_check_context_bonus(ability: String, skill: String, check_context: Dictionary) -> Dictionary:
	var empty := {
		"bonus": 0,
		"tool_item_id": "",
		"tool_instance_id": "",
		"tool_location": {},
		"tool_effect_id": "",
		"origin_event_id": str(check_context.get("origin_event_id", "")),
		"origin_check_id": str(check_context.get("origin_check_id", "")),
	}
	var task_id := str(check_context.get("task_id", ""))
	var purpose_id := str(check_context.get("purpose_id", ""))
	var required_tool_id := str(check_context.get("required_tool_id", ""))
	var origin_event_id := str(check_context.get("origin_event_id", ""))
	var origin_check_id := str(check_context.get("origin_check_id", ""))
	if ability.is_empty() or skill.is_empty() or task_id.is_empty() or purpose_id.is_empty() or required_tool_id.is_empty() or origin_event_id.is_empty() or origin_check_id.is_empty():
		return empty
	copies.sync(self)
	var best := empty.duplicate(true)
	for instance_id in copies.backpack + copies.equipped.values():
		var item_instance: Dictionary = copies.records.get(instance_id, {})
		var item_id := str(item_instance.get("definition_id", ""))
		if item_id != required_tool_id:
			continue
		var item := DataLoader.get_item(item_id)
		if str(item.get("type", "")) != "tool":
			continue
		for effect_value in item.get("effects", []):
			if not effect_value is Dictionary or str(effect_value.get("type", "")) != "skill_check_context_bonus":
				continue
			var effect: Dictionary = effect_value
			if str(effect.get("ability", "")).to_upper() != ability.to_upper() or str(effect.get("skill", "")).to_lower() != skill.to_lower():
				continue
			if str(effect.get("task_id", "")) != task_id or str(effect.get("purpose_id", "")) != purpose_id or str(effect.get("required_tool_id", "")) != item_id:
				continue
			if str(effect.get("source_event_id", "")) != origin_event_id or str(effect.get("source_check_id", "")) != origin_check_id:
				continue
			var candidate := {
				"bonus": int(effect.get("bonus", 0)),
				"tool_item_id": item_id,
				"tool_instance_id": str(instance_id),
				"tool_location": _context_tool_location(str(instance_id)),
				"tool_effect_id": str(effect.get("id", "")),
				"origin_event_id": origin_event_id,
				"origin_check_id": origin_check_id,
			}
			if int(candidate["bonus"]) > int(best["bonus"]) or (int(candidate["bonus"]) == int(best["bonus"]) and str(candidate["tool_instance_id"]) < str(best["tool_instance_id"])):
				best = candidate
	return best


func _context_tool_location(instance_id: String) -> Dictionary:
	var backpack_index := copies.backpack.find(instance_id)
	if backpack_index >= 0:
		return {"kind": "backpack", "index": backpack_index}
	for slot in copies.equipped:
		if str(copies.equipped[slot]) == instance_id:
			return {"kind": "equipped", "slot": int(slot)}
	return {}


## Check Material requirements and hand use without spending or consuming items.
func has_required_spell_component(spell_data: Dictionary, class_id: String = "") -> bool:
	var components: Array = spell_data.get("components", [])
	var ignore_material := bool(spell_data.get("_ignore_material_components", false))
	var has_material := "M" in components and not ignore_material
	var has_somatic := "S" in components
	if has_material and str(spell_data.get("id", "")) == "true_strike":
		# The equipped weapon is this spell's Material component; its hand also
		# performs the Somatic component. Proficiency is checked by cast validation.
		var weapon := DataLoader.get_item(get_weapon())
		return str(weapon.get("type", "")) == "weapon" and int(weapon.get("value", 0)) > 0
	var needs_hand := has_material or has_somatic
	if needs_hand and available_spellcasting_hands() < 1:
		return false
	var consumed := bool(spell_data.get("material_component_consumed", false))
	var minimum_value := int(spell_data.get("material_component_cost", 0))
	if has_material and (consumed or minimum_value > 0):
		return not required_spell_component_instance(spell_data).is_empty()
	if has_material and not has_spellcasting_focus(class_id):
		return false
	return true


## Consume a mechanics-backed consumable on a character. Unsupported imported
## records stay in the backpack but cannot mutate gameplay state.
func consume(item_id: String, target: Character) -> Dictionary:
	if target == null or not has_item(item_id):
		return {"success": false, "message": "Item is not available to use."}
	var item_data := DataLoader.get_item(item_id)
	if str(item_data.get("type", "")) != "consumable":
		return {"success": false, "message": "That item cannot be consumed."}
	var effects: Array = item_data.get("effects", [])
	if effects.is_empty():
		return {"success": false, "message": "%s has no implemented effect yet." % item_data.get("name", item_id)}
	for effect in effects:
		if not EventResolver.is_effect_supported(str(effect.get("type", ""))):
			return {"success": false, "message": "%s has an unsupported effect." % item_data.get("name", item_id)}
	if target.is_dead(): return {"success": false, "message": "Ordinary consumables cannot revive a dead party member."}
	var results := EventResolver.apply_effects(target, effects)
	if results.is_empty():
		return {"success": false, "message": "%s had no effect." % item_data.get("name", item_id)}
	remove_item(item_id)
	return {"success": true, "item_id": item_id, "results": results, "message": "%s used." % item_data.get("name", item_id)}


## Return whether an item is valid for a slot and owned by this inventory.
## Starting equipment may use the explicit allow_unowned path during character
## creation; normal gameplay must equip items from the backpack.
func can_equip(slot: Slot, item_id: String, allow_unowned: bool = false) -> bool:
	var item_data := DataLoader.get_item(item_id)
	if item_data.is_empty():
		return false
	var item_type := str(item_data.get("type", ""))
	var valid_slot := -1
	match item_type:
		"weapon": valid_slot = slot if slot in [Slot.WEAPON, Slot.OFFHAND] else -1
		"shield": valid_slot = Slot.SHIELD
		"armor": valid_slot = Slot.BODY
		"helmet": valid_slot = Slot.HEAD
		"ring": valid_slot = slot if slot in [Slot.RING_1, Slot.RING_2] else -1
		"wand": valid_slot = Slot.HANDS
	if valid_slot != slot:
		return false
	var equipped_copy := str(copies.equipped.get(slot, ""))
	if bool(copies.records.get(equipped_copy, {}).get("state", {}).get("cursed_attunement", false)) and not CurseRules.removal_allowed(copies.records.get(equipped_copy, {})):
		return false
	if slot == Slot.OFFHAND:
		if "light" not in item_data.get("properties", []) or is_slot_equipped(Slot.SHIELD) or "light" not in DataLoader.get_item(get_weapon()).get("properties", []):
			return false
	if item_type == "weapon" and "two_handed" in item_data.get("properties", []) and (is_slot_equipped(Slot.SHIELD) or is_slot_equipped(Slot.OFFHAND)):
		return false
	if slot == Slot.WEAPON and is_slot_equipped(Slot.OFFHAND) and "light" not in item_data.get("properties", []):
		return false
	if slot == Slot.SHIELD and is_slot_equipped(Slot.OFFHAND):
		return false
	if slot == Slot.SHIELD and "two_handed" in DataLoader.get_item(get_weapon()).get("properties", []):
		return false
	return allow_unowned or item_id in backpack or equipped.get(slot, "") == item_id


## Equip an item to a compatible slot. Returns the previously equipped item (or
## empty string) and leaves state unchanged when validation fails.
func equip(slot: Slot, item_id: String, allow_unowned: bool = false) -> String:
	copies.sync(self)
	var wearer = owner_character_ref.get_ref() if owner_character_ref != null else null
	if wearer != null and not ActorProjectionRules.equip_error(wearer).is_empty(): return ""
	if not can_equip(slot, item_id, allow_unowned):
		return ""
	var previous := str(equipped.get(slot, ""))
	if previous == item_id: return ""
	var index := backpack.find(item_id)
	if index >= 0:
		if not equip_instance(slot, copies.backpack[index]): return ""
	elif allow_unowned:
		var record := copies.create(item_id)
		var old_id := str(copies.equipped.get(slot, ""))
		if not old_id.is_empty():
			backpack.append(previous)
			copies.backpack.append(old_id)
		copies.records[record["instance_id"]] = record
		copies.equipped[slot] = record["instance_id"]
		equipped[slot] = item_id
		_publish_equipment_change(item_id, "equipped", str(record["instance_id"]))
	return previous


## Unequip an item from a slot, moving it to the backpack.
func unequip(slot: Slot) -> String:
	copies.sync(self)
	var item_id: String = equipped.get(slot, "")
	if not item_id.is_empty():
		var instance_id := str(copies.equipped.get(slot, ""))
		if bool(copies.records.get(instance_id, {}).get("state", {}).get("cursed_attunement", false)) and not CurseRules.removal_allowed(copies.records.get(instance_id, {})):
			push_warning("[Inventory] A cursed attuned item cannot be removed before its curse is broken.")
			return ""
		if backpack.size() >= MAX_BACKPACK_SIZE:
			push_warning("[Inventory] Backpack full, cannot unequip: %s" % item_id)
			return ""
		equipped.erase(slot)
		backpack.append(item_id)
		_publish_equipment_change(item_id, "unequipped", instance_id)
	return item_id


## Get the item equipped in a slot (empty string if nothing).
func get_equipped(slot: Slot) -> String:
	return equipped.get(slot, "")


## Check if a slot has an item equipped.
func is_slot_equipped(slot: Slot) -> bool:
	return slot in equipped and not equipped[slot].is_empty()


## Get the weapon item ID (shortcut).
func get_weapon() -> String:
	return get_equipped(Slot.WEAPON)


## Get the armor item ID (body slot, shortcut).
func get_armor() -> String:
	return get_equipped(Slot.BODY)


## Get all equipped item IDs as an array.
func get_all_equipped() -> Array[String]:
	var items: Array[String] = []
	for slot in equipped:
		if not equipped[slot].is_empty():
			items.append(equipped[slot])
	return items


## Calculate total AC bonus from equipped armor/shield.
## Requires access to DataLoader for item stats.
func calculate_ac_bonus() -> int:
	var bonus := 0
	for slot in equipped:
		var item_id: String = equipped[slot]
		if item_id.is_empty():
			continue
		var item_data: Dictionary = DataLoader.get_item(item_id)
		bonus += int(item_data.get("ac_bonus", 0))
	return bonus


func attune_instance(instance_id: String, character_id: String) -> Dictionary:
	copies.sync(self)
	var record: Dictionary = copies.records.get(instance_id, {})
	if record.is_empty() or (instance_id not in copies.backpack and instance_id not in copies.equipped.values()):
		return {"success": false, "message": "That item is not in this character's inventory."}
	var item := DataLoader.get_item(str(record.get("definition_id", "")))
	if not bool(item.get("requires_attunement", false)):
		return {"success": false, "message": "This item does not require attunement."}
	var state: Dictionary = record.get("state", {})
	var current_owner := str(state.get("attuned_to", ""))
	if current_owner == character_id:
		return {"success": false, "message": "This copy is already attuned to this character."}
	if not current_owner.is_empty():
		return {"success": false, "message": "This copy is attuned to someone else."}
	var attuned_count := 0
	for owned_record in copies.records.values() + ContainerRules.contained_records(self):
		if str(owned_record.get("state", {}).get("attuned_to", "")) == character_id:
			attuned_count += 1
			if str(owned_record.get("definition_id", "")) == str(record.get("definition_id", "")) and str(record.get("definition_id", "")) == "ring_of_protection":
				return {"success": false, "message": "A character can be attuned to only one Ring of Protection at a time."}
	var lingering := CurseRules.attune_error(owner_character_ref.get_ref() if owner_character_ref != null else null)
	if not lingering.is_empty():
		return {"success": false, "message": lingering}
	if attuned_count >= 3:
		return {"success": false, "message": "A character can be attuned to no more than three items."}
	state["attuned_to"] = character_id
	if bool(item.get("cursed", false)):
		state["cursed_attunement"] = true
	record["state"] = state
	copies.records[instance_id] = record
	return {"success": true, "message": "Attunement takes 1 hour. %s is attuned." % item.get("name", "The item"), "seconds": 3600}


func unattune_instance(instance_id: String, character_id: String, break_curse: bool = false) -> Dictionary:
	copies.sync(self)
	var record: Dictionary = copies.records.get(instance_id, {})
	if record.is_empty() or str(record.get("state", {}).get("attuned_to", "")) != character_id:
		return {"success": false, "message": "This item is not attuned to this character."}
	var state: Dictionary = record.get("state", {})
	if bool(state.get("cursed_attunement", false)) and not break_curse:
		return {"success": false, "message": "The curse prevents voluntary unattunement. Remove Curse can break this attunement."}
	state.erase("attuned_to")
	state.erase("cursed_attunement")
	record["state"] = state
	copies.records[instance_id] = record
	return {"success": true, "message": "The item is no longer attuned."}


func break_cursed_item_attunements(character_id: String) -> int:
	copies.sync(self)
	var broken := 0
	for instance_id in copies.records.keys():
		var record: Dictionary = copies.records[instance_id]
		var state: Dictionary = record.get("state", {})
		if str(state.get("attuned_to", "")) != character_id or not bool(state.get("cursed_attunement", false)):
			continue
		# S-202: a declared curse breaks only through CurseRules' exact requirements.
		if not CurseRules.policy(str(record.get("definition_id", ""))).is_empty():
			continue
		state.erase("attuned_to")
		state.erase("cursed_attunement")
		record["state"] = state
		copies.records[instance_id] = record
		broken += 1
	return broken


func has_equipped_attuned_item(definition_id: String, character_id: String) -> bool:
	copies.sync(self)
	for instance_id in copies.equipped.values():
		var record: Dictionary = copies.records.get(instance_id, {})
		var holder = owner_character_ref.get_ref() if owner_character_ref != null else null
		if holder != null and ActorProjectionRules.merged(holder, str(instance_id)): continue
		if holder != null and not MagicPropertyRules.active(holder, str(instance_id), "item_effects"): continue # Review 044 R2.
		if str(record.get("definition_id", "")) == definition_id and str(record.get("state", {}).get("attuned_to", "")) == character_id:
			return true
	return false


func magic_item_saving_bonus(character_id: String) -> int:
	return 1 if has_equipped_attuned_item("ring_of_protection", character_id) else 0


func magic_item_aura_instances() -> Array[Dictionary]:
	copies.sync(self)
	var result: Array[Dictionary] = []
	for instance_id in copies.backpack + copies.equipped.values():
		var record: Dictionary = copies.records.get(instance_id, {})
		var item := DataLoader.get_item(str(record.get("definition_id", "")))
		if bool(item.get("magical", false)) or item.has("rarity"):
			result.append({"instance_id": str(instance_id), "item_id": str(record.get("definition_id", "")), "name": str(item.get("name", "Magic item"))})
	return result


func recover_daily_charges() -> void:
	copies.sync(self)
	for instance_id in copies.records.keys():
		var record: Dictionary = copies.records[instance_id]
		var item: Dictionary = DataLoader.get_item(str(record.get("definition_id", "")))
		var recovery: Dictionary = item.get("charge_recovery", {})
		if str(recovery.get("cadence", "")) != "dawn":
			continue
		var state: Dictionary = record.get("state", {})
		if bool(state.get("degraded", false)):
			continue
		var maximum := int(item.get("maximum_charges", 0))
		var amount := Dice.roll(int(recovery.get("maximum", 0)) - int(recovery.get("minimum", 0)) + 1) + int(recovery.get("minimum", 0)) - 1
		state["charges"] = mini(maximum, int(state.get("charges", 0)) + amount)
		record["state"] = state
		copies.records[instance_id] = record


## Add a list of starting equipment items.
func add_starting_equipment(item_ids: Array) -> void:
	for item_id in item_ids:
		# Try to auto-equip weapons and armor
		var item_data: Dictionary = DataLoader.get_item(item_id)
		var item_type: String = item_data.get("type", "")
		var auto_equipped := false

		match item_type:
			"weapon":
				if not is_slot_equipped(Slot.WEAPON):
					if "two_handed" in item_data.get("properties", []) and is_slot_equipped(Slot.SHIELD):
						unequip(Slot.SHIELD)
					if can_equip(Slot.WEAPON, item_id, true):
						equip(Slot.WEAPON, item_id, true)
						auto_equipped = true
			"shield":
				if not is_slot_equipped(Slot.SHIELD) and can_equip(Slot.SHIELD, item_id, true):
					equip(Slot.SHIELD, item_id, true)
					auto_equipped = true
			"armor":
				if not is_slot_equipped(Slot.BODY):
					equip(Slot.BODY, item_id, true)
					auto_equipped = true
			"helmet":
				if not is_slot_equipped(Slot.HEAD):
					equip(Slot.HEAD, item_id, true)
					auto_equipped = true

		if not auto_equipped:
			add_item(item_id)


## Serialize to dictionary.
func to_dict() -> Dictionary:
	var equipped_dict := {}
	for slot in equipped:
		equipped_dict[Slot.keys()[slot]] = equipped[slot]

	return {
		"equipped": equipped_dict,
		"backpack": backpack.duplicate(),
		"gold": gold,
		"copies": copies.serialize(self),
	}


## Deserialize from dictionary.
func from_dict(data: Dictionary) -> void:
	var copy_error := InventoryCopies.saved_error(data)
	if not copy_error.is_empty():
		push_error(copy_error)
		return
	backpack.clear()
	equipped.clear()

	var equipped_data: Dictionary = data.get("equipped", {})
	for slot_name in equipped_data:
		var slot_idx := Slot.keys().find(slot_name)
		if slot_idx >= 0:
			equipped[slot_idx] = equipped_data[slot_name]

	var bp: Array = data.get("backpack", [])
	for item_id in bp:
		backpack.append(str(item_id))

	gold = int(data.get("gold", 0))
	copies.restore(self, data.get("copies", {}))


func backpack_instances() -> Array[Dictionary]:
	copies.sync(self)
	var result: Array[Dictionary] = []
	for id in copies.backpack: result.append(copies.records[id].duplicate(true))
	return result


func owned_instances() -> Array[Dictionary]:
	copies.sync(self)
	var result: Array[Dictionary] = []
	for id in copies.backpack + copies.equipped.values():
		if copies.records.has(id):
			result.append(copies.records[id].duplicate(true))
	return result


func get_instance(id: String) -> Dictionary:
	copies.sync(self)
	return copies.records.get(id, {}).duplicate(true)


func update_instance(record: Dictionary) -> bool:
	copies.sync(self)
	var instance_id := str(record.get("instance_id", ""))
	var current: Dictionary = copies.records.get(instance_id, {})
	if current.is_empty() or not record.get("state") is Dictionary or str(current.get("definition_id", "")) != str(record.get("definition_id", "")):
		return false
	copies.records[instance_id] = record.duplicate(true)
	return true


## Spend charges from one exact owned magic-item copy.
func spend_instance_charges(instance_id: String, amount: int) -> bool:
	copies.sync(self)
	if amount <= 0 or instance_id not in copies.backpack and instance_id not in copies.equipped.values():
		return false
	var record: Dictionary = copies.records.get(instance_id, {})
	var state: Dictionary = record.get("state", {}).duplicate(true)
	if record.is_empty() or int(state.get("charges", 0)) < amount:
		return false
	var charges_before := int(state["charges"])
	state["charges"] = charges_before - amount
	record["state"] = state
	copies.records[instance_id] = record
	last_charge_receipt = LastChargeRules.settle(self, instance_id, charges_before, int(state["charges"]), forced_last_charge_roll)
	forced_last_charge_roll = 0
	return true


## Destroy one exact item copy, whether it is carried or equipped.
func destroy_instance(instance_id: String) -> Dictionary:
	copies.sync(self)
	if not copies.records.has(instance_id):
		return {}
	var record: Dictionary = copies.records[instance_id].duplicate(true)
	var slot_to_clear := -1
	for slot in copies.equipped:
		if str(copies.equipped[slot]) == instance_id:
			slot_to_clear = int(slot)
			break
	if slot_to_clear >= 0:
		copies.equipped.erase(slot_to_clear)
		equipped.erase(slot_to_clear)
		_publish_equipment_change(str(record.get("definition_id", "")), "destroyed", instance_id)
	else:
		var index := copies.backpack.find(instance_id)
		if index >= 0:
			copies.backpack.remove_at(index)
			backpack.remove_at(index)
	copies.records.erase(instance_id)
	# Review 043 R3: an ordinary container's destruction spills its exact contents to the holder.
	if record.get("state", {}).get("contents") is Dictionary:
		var left := {}
		for key in record.state.contents:
			for child in record.state.contents[key]:
				if not receive_instance(child): left[key] = left.get(key, []) + [child]
		if left.is_empty(): record.state.erase("contents")
		else: record.state["contents"] = left
	CurseRules.on_removed(owner_character_ref.get_ref() if owner_character_ref != null else null, record)
	BondRules.on_copy_removed(owner_character_ref.get_ref() if owner_character_ref != null else null)
	return record


func equipped_instance_id(slot: Slot) -> String:
	copies.sync(self)
	return str(copies.equipped.get(slot, ""))


## Remove an equipped copy from this inventory while preserving its saved state.
func drop_equipped_instance(slot: Slot) -> Dictionary:
	copies.sync(self)
	var instance_id := str(copies.equipped.get(slot, ""))
	if instance_id.is_empty():
		return {}
	var record: Dictionary = copies.records.get(instance_id, {}).duplicate(true)
	if record.is_empty():
		return {}
	copies.equipped.erase(slot)
	copies.records.erase(instance_id)
	equipped.erase(slot)
	_publish_equipment_change(str(record.get("definition_id", "")), "dropped", instance_id)
	CurseRules.on_removed(owner_character_ref.get_ref() if owner_character_ref != null else null, record)
	BondRules.on_copy_removed(owner_character_ref.get_ref() if owner_character_ref != null else null)
	return record


func receive_instance(record: Dictionary) -> bool:
	copies.sync(self)
	var id := str(record.get("instance_id", ""))
	var definition := str(record.get("definition_id", ""))
	if id.is_empty() or copies.records.has(id) or DataLoader.get_item(definition).is_empty() or not record.get("state") is Dictionary or backpack.size() >= MAX_BACKPACK_SIZE:
		return false
	copies.records[id] = record.duplicate(true)
	copies.backpack.append(id)
	backpack.append(definition)
	return true


func take_instance(id: String) -> Dictionary:
	copies.sync(self)
	var index := copies.backpack.find(id)
	if index < 0: return {}
	if bool(copies.records.get(id, {}).get("state", {}).get("cursed_attunement", false)):
		return {}
	var record: Dictionary = copies.records[id].duplicate(true)
	backpack.remove_at(index)
	copies.backpack.remove_at(index)
	copies.records.erase(id)
	BondRules.on_copy_removed(owner_character_ref.get_ref() if owner_character_ref != null else null)
	return record


func transfer_instance(id: String, destination: Inventory) -> bool:
	if destination == null or destination == self: return false
	copies.sync(self)
	if bool(copies.records.get(id, {}).get("state", {}).get("cursed_attunement", false)):
		return false
	if id not in copies.backpack or not destination.receive_instance(copies.records[id]): return false
	take_instance(id)
	return true


func equip_instance(slot: Slot, id: String) -> bool:
	copies.sync(self)
	if id not in copies.backpack: return false
	var wearer = owner_character_ref.get_ref() if owner_character_ref != null else null
	if wearer != null and not ActorProjectionRules.equip_error(wearer).is_empty(): return false
	var definition := str(copies.records[id]["definition_id"])
	if not can_equip(slot, definition): return false
	var previous := str(copies.equipped.get(slot, ""))
	var index := copies.backpack.find(id)
	copies.backpack.remove_at(index)
	backpack.remove_at(index)
	if not previous.is_empty():
		copies.backpack.append(previous)
		backpack.append(str(copies.records[previous]["definition_id"]))
		_publish_equipment_change(str(copies.records[previous]["definition_id"]), "unequipped", previous)
	copies.equipped[slot] = id
	equipped[slot] = definition
	_publish_equipment_change(definition, "equipped", id)
	return true


func consume_instance(id: String, target: Character) -> Dictionary:
	copies.sync(self)
	if id not in copies.backpack: return {"success": false, "message": "Item is not in the backpack."}
	var definition := str(copies.records[id]["definition_id"])
	var item := DataLoader.get_item(definition)
	var light_source: Dictionary = item.get("light_source", {})
	if not light_source.is_empty():
		var record: Dictionary = copies.records[id].duplicate(true)
		var state: Dictionary = record.get("state", {}).duplicate(true)
		if bool(state.get("light_source_lit", false)):
			return {"success": false, "message": "%s is already lit." % item.get("name", definition)}
		var fuel_item_id := str(light_source.get("fuel_item_id", ""))
		if not fuel_item_id.is_empty():
			var fuel_instance_id := ""
			for owned_id in copies.backpack:
				if str(owned_id) == id:
					continue
				if str(copies.records.get(str(owned_id), {}).get("definition_id", "")) == fuel_item_id:
					fuel_instance_id = str(owned_id)
					break
			if fuel_instance_id.is_empty():
				return {"success": false, "message": "%s needs one %s to light." % [item.get("name", definition), DataLoader.get_item(fuel_item_id).get("name", fuel_item_id)]}
			take_instance(fuel_instance_id)
		state["light_source_lit"] = true
		state["light_source_remaining_seconds"] = maxi(1, int(light_source.get("duration_seconds", 0)))
		record["state"] = state
		update_instance(record)
		return {"success": true, "item_id": definition, "instance_id": id, "consumed": false, "results": [{"message": "%s is lit and sheds Bright Light for %d feet and Dim Light for an additional %d feet." % [item.get("name", definition), int(light_source.get("bright_radius_feet", 0)), maxi(0, int(light_source.get("dim_radius_feet", 0)) - int(light_source.get("bright_radius_feet", 0)))]}]}
	var effects: Array = item.get("effects", [])
	if target == null or str(item.get("type", "")) != "consumable" or effects.is_empty():
		return {"success": false, "message": "This item has no supported use."}
	for effect in effects:
		if not EventResolver.is_effect_supported(str(effect.get("type", ""))):
			return {"success": false, "message": "This item has an unsupported effect."}
	var results := EventResolver.apply_effects(target, effects)
	if results.is_empty(): return {"success": false, "message": "Item had no effect."}
	take_instance(id)
	return {"success": true, "results": results, "message": "%s used." % item.get("name", definition)}


func consume_ration_portion(id: String, target: Character, daily_fraction: float) -> Dictionary:
	copies.sync(self)
	if id not in copies.backpack:
		return {"success": false, "message": "That ration copy is not in the backpack."}
	var record: Dictionary = copies.records[id].duplicate(true)
	if str(record.get("definition_id", "")) != "rations":
		return {"success": false, "message": "Choose a ration copy."}
	if target == null or not target.is_alive or CombatAction.is_incapacitated(target):
		return {"success": false, "message": "That character cannot eat now."}
	if not is_finite(daily_fraction) or daily_fraction <= 0.0 or daily_fraction > 1.0:
		return {"success": false, "message": "Choose a ration portion from one quarter-day up to one full day."}
	var item_state: Dictionary = record.get("state", {}).duplicate(true)
	var saved_fraction: Variant = item_state.get("food_remaining_daily_fraction", 1.0)
	if (not saved_fraction is int and not saved_fraction is float) or not is_finite(float(saved_fraction)) or float(saved_fraction) <= 0.0 or float(saved_fraction) > 1.0:
		return {"success": false, "message": "That ration copy has invalid saved portions."}
	var remaining_fraction := float(saved_fraction)
	var consumed_fraction := minf(daily_fraction, remaining_fraction)
	if consumed_fraction <= 0.0:
		return {"success": false, "message": "That ration copy is empty."}
	var consumed_pounds := SurvivalRules.food_need_for_character(target) * consumed_fraction
	item_state["food_remaining_daily_fraction"] = maxf(0.0, remaining_fraction - consumed_fraction)
	record["state"] = item_state
	if item_state["food_remaining_daily_fraction"] <= 0.0001:
		take_instance(id)
	else:
		update_instance(record)
	target.record_food_intake(consumed_pounds)
	return {"success": true, "consumed_fraction": consumed_fraction, "consumed_pounds": consumed_pounds, "remaining_fraction": float(item_state["food_remaining_daily_fraction"]), "message": "%s eats %s of a day's ration (%s lb)." % [target.character_name, _ration_fraction_text(consumed_fraction), _quantity_text(consumed_pounds)]}


func _ration_fraction_text(fraction: float) -> String:
	if is_equal_approx(fraction, 1.0): return "a full day"
	if is_equal_approx(fraction, 0.5): return "half"
	if is_equal_approx(fraction, 0.25): return "a quarter"
	return "%.2f of a day" % fraction


func _quantity_text(quantity: float) -> String:
	return str(int(roundf(quantity))) if is_equal_approx(quantity, roundf(quantity)) else "%.2f" % quantity
