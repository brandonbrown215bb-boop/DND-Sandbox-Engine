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
}

## Equipped items: Slot -> item_id (String).
var equipped: Dictionary = {}

## Backpack items: Array of item_id strings.
var backpack: Array[String] = []

## Gold/currency.
var gold: int = 0

## Maximum backpack size.
const MAX_BACKPACK_SIZE := 20


## Add an item to the backpack.
func add_item(item_id: String) -> bool:
	if DataLoader.get_item(item_id).is_empty():
		push_warning("[Inventory] Unknown item, cannot add: %s" % item_id)
		return false
	if backpack.size() >= MAX_BACKPACK_SIZE:
		push_warning("[Inventory] Backpack full, cannot add: %s" % item_id)
		return false
	backpack.append(item_id)
	return true


## Remove an item from the backpack (first occurrence).
func remove_item(item_id: String) -> bool:
	var idx := backpack.find(item_id)
	if idx >= 0:
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
		"weapon": valid_slot = Slot.WEAPON
		"shield": valid_slot = Slot.SHIELD
		"armor": valid_slot = Slot.BODY
		"helmet": valid_slot = Slot.HEAD
		"ring": valid_slot = slot if slot in [Slot.RING_1, Slot.RING_2] else -1
	if valid_slot != slot:
		return false
	return allow_unowned or item_id in backpack or item_id in equipped.values()


## Equip an item to a compatible slot. Returns the previously equipped item (or
## empty string) and leaves state unchanged when validation fails.
func equip(slot: Slot, item_id: String, allow_unowned: bool = false) -> String:
	if not can_equip(slot, item_id, allow_unowned):
		push_warning("[Inventory] Cannot equip %s in slot %s." % [item_id, Slot.keys()[slot]])
		return ""
	var previous: String = equipped.get(slot, "")

	# Remove from backpack if present
	remove_item(item_id)

	# Unequip previous item to backpack
	if not previous.is_empty():
		backpack.append(previous)

	equipped[slot] = item_id
	return previous


## Unequip an item from a slot, moving it to the backpack.
func unequip(slot: Slot) -> String:
	var item_id: String = equipped.get(slot, "")
	if not item_id.is_empty():
		if backpack.size() >= MAX_BACKPACK_SIZE:
			push_warning("[Inventory] Backpack full, cannot unequip: %s" % item_id)
			return ""
		equipped.erase(slot)
		backpack.append(item_id)
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
					equip(Slot.WEAPON, item_id, true)
					auto_equipped = true
			"shield":
				if not is_slot_equipped(Slot.SHIELD):
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
	}


## Deserialize from dictionary.
func from_dict(data: Dictionary) -> void:
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
