## Bounded spell interaction with authored, unattended combat-room objects.
class_name CombatObjectRules
extends RefCounted

static func at(grid: HexGrid, position: Vector2i) -> Dictionary:
	var objects := all_at(grid, position)
	return objects[0] if not objects.is_empty() else {}


static func all_at(grid: HexGrid, position: Vector2i) -> Array[Dictionary]:
	var objects: Array[Dictionary] = []
	if grid == null:
		return objects
	for entity in grid.entities:
		if entity.get("world_object") is Dictionary and entity.get("hex_position", Vector2i.ZERO) == position:
			var object: Dictionary = entity["world_object"]
			if not bool(object.get("removed", false)) and int(object.get("hp", 1)) > 0:
				objects.append(object)
	return objects


static func target_key(object: Dictionary) -> String:
	var instance_id := str(object.get("instance_id", ""))
	return instance_id if not instance_id.is_empty() else str(object.get("id", ""))


static func by_key(grid: HexGrid, position: Vector2i, key: String) -> Dictionary:
	for object in all_at(grid, position):
		if target_key(object) == key:
			return object
	return {}


static func make_dropped_item(record: Dictionary, position: Vector2i, source_id: String) -> Dictionary:
	var instance_id := str(record.get("instance_id", ""))
	var definition_id := str(record.get("definition_id", ""))
	var item := DataLoader.get_item(definition_id)
	if instance_id.is_empty() or item.is_empty():
		return {}
	var object := _make_item_object(record, source_id, false, false, position)
	# Keep the whole copy, including nested cargo/attachments and source stamps.
	object["contents"] = [record.duplicate(true)]
	object["copy_state"] = object.contents[0].state
	return object


static func make_owned_item(record: Dictionary, source_id: String, worn: bool, position: Vector2i) -> Dictionary:
	return _make_item_object(record, source_id, true, worn, position)


static func _make_item_object(record: Dictionary, source_id: String, carried: bool, worn: bool, position: Vector2i) -> Dictionary:
	var instance_id := str(record.get("instance_id", ""))
	var definition_id := str(record.get("definition_id", ""))
	var item := DataLoader.get_item(definition_id)
	if instance_id.is_empty() or item.is_empty():
		return {}
	var item_state: Dictionary = record.get("state", {})
	var physical: Dictionary = item_state.get("physical", {})
	var item_hp := int(item_state.get("combat_object_hp", physical.get("hp", item.get("object_hp", 1))))
	var object := {
		"id": ("carried:" if carried else "dropped:") + instance_id,
		"instance_id": instance_id,
		"kind": "loose",
		"name": str(item.get("name", definition_id)),
		"item_id": definition_id,
		"definition_id": definition_id,
		"copy_state": record.get("state", {}).duplicate(true),
		"fixed": bool(item.get("fixed", false)),
		"hp": item_hp,
		"max_hp": maxi(item_hp, int(physical.get("max_hp", item.get("object_hp", 1)))),
		"magical": bool(item.get("magical", false)) or item.has("rarity"),
		"carried": carried,
		"worn": worn,
		"carried_by": source_id if carried else "",
		"worn_by": source_id if worn else "",
		"source": source_id,
		"removed": false,
		"position": [position.x, position.y],
	}
	# Absence is an unknown physical fact, not a one-pound Tiny object.
	for field in ["material", "size", "thickness_inches"]:
		if item.has(field): object[field] = item[field]
	if item.has("weight"): object["weight_lb"] = item.weight
	for field in ["material", "size", "weight_lb", "fixed"]:
		if physical.has(field): object[field] = physical[field]
	return object


static func owned_item_record_at(players: Array[Dictionary], position: Vector2i, instance_id: String) -> Dictionary:
	for player in players:
		if player.get("hex_position", Vector2i.ZERO) != position:
			continue
		var character: Character = player.get("character")
		if character == null:
			continue
		var record := character.inventory.get_instance(instance_id)
		if not record.is_empty():
			return {"character": character, "record": record}
	return {}


static func sync_owned_item_object(character: Character, instance_id: String, object: Dictionary) -> void:
	if character == null:
		return
	var record := character.inventory.get_instance(instance_id)
	if record.is_empty():
		return
	var state: Dictionary = record.get("state", {}).duplicate(true)
	state["combat_object_hp"] = int(object.get("hp", object.get("max_hp", 1)))
	record["state"] = state
	character.inventory.update_instance(record)


static func can_target(object: Dictionary) -> bool:
	if not ContainmentRules.internal_location(object).is_empty(): return false
	return not object.is_empty() and not bool(object.get("removed", false)) and int(object.get("hp", 1)) > 0


static func can_take_spell_damage(object: Dictionary, internal_authorized: bool = false) -> bool:
	var present := not object.is_empty() and not bool(object.get("removed", false)) and int(object.get("hp", 1)) > 0
	return present and (internal_authorized or can_target(object)) and not is_magical(object) and not bool(object.get("worn", false)) and not bool(object.get("carried", false)) and str(object.get("worn_by", "")).is_empty() and str(object.get("carried_by", "")).is_empty()


static func is_magical(object: Dictionary) -> bool:
	if bool(object.get("magical", object.get("is_magical", false))):
		return true
	if str(object.get("kind", "")) != "loose":
		return false
	var contents: Array = object.get("contents", [])
	if contents.size() != 1:
		return false
	var definition_id := str(contents[0].get("definition_id", "")) if contents[0] is Dictionary else ""
	return not definition_id.is_empty() and bool(DataLoader.get_item(definition_id).get("magical", false))


static func make_resolution_target(object: Dictionary) -> Dictionary:
	var target := object.duplicate(true)
	target["world_object"] = object
	target["is_object"] = true
	target["current_hp"] = int(object.get("hp", 1))
	target["max_hp"] = int(object.get("max_hp", object.get("hp", 1)))
	target["is_alive"] = true
	target["conditions"] = target.get("conditions", {}).duplicate(true)
	target["damage_resistances"] = target.get("damage_resistances", []).duplicate()
	target["damage_immunities"] = target.get("damage_immunities", []).duplicate()
	return target


static func sync_resolution_target(object: Dictionary, target: Dictionary) -> void:
	if not ContainmentRules.internal_location(object).is_empty(): return
	object["hp"] = maxi(0, int(target.get("current_hp", object.get("hp", 1))))
	settle_destruction(object)


static func apply_damage(object: Dictionary, amount: int, damage_type: String, internal_authorized: bool = false) -> int:
	if not can_take_spell_damage(object, internal_authorized) or amount <= 0:
		return 0
	var resolved := amount
	if damage_type in object.get("damage_immunities", []):
		resolved = 0
	elif damage_type in object.get("damage_resistances", []):
		resolved = int(floor(float(resolved) / 2.0))
	if damage_type in object.get("damage_vulnerabilities", []):
		resolved *= 2
	var threshold := int(object.get("damage_threshold", 0))
	if threshold > 0 and resolved < threshold:
		resolved = 0
	var damage := mini(resolved, int(object.get("hp", 1)))
	object["hp"] = maxi(0, int(object.get("hp", 1)) - damage)
	settle_destruction(object)
	if object.has("tethers"):
		TetherRules.reconcile_object_anchor(object)
	return damage


## A destroyed exact copy cannot remain takeable; its cargo/parts spill in place.
static func settle_destruction(object: Dictionary) -> void:
	if int(object.get("hp", 1)) > 0: return
	object["burning"] = false
	object.erase("burning_next_tick_seconds")
	if str(object.get("kind", "")) == "loose" and not object.get("contents", []).is_empty():
		var spilled: Array = []
		for record in object.contents:
			for compartment in record.get("state", {}).get("contents", {}).values(): spilled.append_array(compartment)
			spilled.append_array(record.get("state", {}).get("attached", {}).values())
		object["copy_destroyed"] = true
		object["contents"] = spilled
		object["removed"] = spilled.is_empty()
		if not spilled.is_empty(): object["kind"] = "container"
	if str(object.get("kind", "")) in ["door", "container"]:
		object["open"] = true
		object["locked"] = false
	ContainmentRules.settle_object_destruction(object)
	if object.has("tethers"):
		TetherRules.reconcile_object_anchor(object)



static func resolve_meteor_swarm(caster: Character, object: Dictionary, spell_data: Dictionary, slot_level: int) -> Dictionary:
	if not can_take_spell_damage(object):
		return {"success": false, "damage": 0, "message": "That object is not an eligible unattended nonmagical object."}
	var total_damage := 0
	var components: Array[String] = []
	var declared: Array = spell_data.get("damage_components", [])
	for component_index in declared.size():
		var component: Dictionary = declared[component_index]
		var component_spell := {"damage": str(component.get("damage", "0")), "level": int(spell_data.get("level", 0)), "upcast": component.get("upcast", spell_data.get("upcast", {}))}
		var formula := SpellDamageRolls.spell_damage_formula(caster, component_spell, slot_level)
		var roll := SpellDamageRolls._roll_spell_damage(caster, formula, 1, {})
		var amount := int(roll.get("final_total", 0))
		if component_index == 0:
			amount += CombatAction.spell_damage_bonus(caster, spell_data)
		var damage_type := str(component.get("damage_type", "fire"))
		var dealt := apply_damage(object, amount, damage_type)
		total_damage += dealt
		components.append("%d %s" % [dealt, damage_type.capitalize()])
	var ignited := ignite(object)
	var message := "%s takes %s damage." % [str(object.get("name", "The object")), " and ".join(components)]
	if ignited:
		message += " It catches fire."
	return {"success": true, "damage": total_damage, "ignited": ignited, "message": message}


static func is_flammable(object: Dictionary) -> bool:
	if object.has("flammable"):
		return bool(object["flammable"])
	return str(object.get("material", "")).to_lower() in ["wood", "paper", "cloth", "plant", "leather"]


static func ignite(object: Dictionary) -> bool:
	if not can_target(object) or not is_flammable(object) or bool(object.get("carried", false)) or bool(object.get("worn", false)):
		return false
	if not bool(object.get("burning", false)):
		object["burning_next_tick_seconds"] = int(GameManager.campaign_elapsed_seconds) + 6
	object["burning"] = true
	return true


static func extinguish(object: Dictionary) -> bool:
	if object.is_empty() or not bool(object.get("burning", false)):
		return false
	object["burning"] = false
	object.erase("burning_next_tick_seconds")
	return true
