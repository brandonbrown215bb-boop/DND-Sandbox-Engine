## Identity and per-copy state. Inventory retains catalog-ID projections for callers.
class_name InventoryCopies
extends RefCounted

var inventory_id: String
var next_id: int = 1
var records: Dictionary = {}
var backpack: Array[String] = []
var equipped: Dictionary = {}

static func display_name(record: Dictionary, ordinal: int) -> String:
	var name := str(DataLoader.get_item(str(record["definition_id"])).get("name", record["definition_id"]))
	var state: Dictionary = record.get("state", {})
	return "%s · %d%s" % [name, ordinal, " (%d charges)" % int(state["charges"]) if state.has("charges") else ""]

func _init() -> void:
	# Identity allocation must not consume the game's random dice stream.
	inventory_id = "bag_%s_%s" % [Time.get_unix_time_from_system(), get_instance_id()]

func create(definition_id: String) -> Dictionary:
	var id := "%s:%d" % [inventory_id, next_id]
	next_id += 1
	var state: Dictionary = {}
	var maximum_charges := int(DataLoader.get_item(definition_id).get("maximum_charges", 0))
	if maximum_charges > 0:
		state["charges"] = maximum_charges
	return {"instance_id": id, "definition_id": definition_id, "state": state}

## Accommodate older code that writes the catalog projections directly.
func sync(inventory: RefCounted) -> void:
	var used: Dictionary = {}
	var slots: Dictionary = {}
	for slot in inventory.equipped:
		var definition := str(inventory.equipped[slot])
		var id := str(equipped.get(slot, ""))
		if id.is_empty() or str(records.get(id, {}).get("definition_id", "")) != definition:
			id = _find_unused(definition, used)
		if id.is_empty():
			var record := create(definition)
			id = record["instance_id"]
			records[id] = record
		slots[slot] = id
		used[id] = true
	var bag: Array[String] = []
	for index in inventory.backpack.size():
		var definition := str(inventory.backpack[index])
		var id := backpack[index] if index < backpack.size() else ""
		if used.has(id) or str(records.get(id, {}).get("definition_id", "")) != definition:
			id = _find_unused(definition, used)
		if id.is_empty():
			var record := create(definition)
			id = record["instance_id"]
			records[id] = record
		bag.append(id)
		used[id] = true
	for id in records.keys():
		if not used.has(id): records.erase(id)
	backpack = bag
	equipped = slots

func _find_unused(definition: String, used: Dictionary) -> String:
	for id in backpack + equipped.values():
		if not used.has(id) and str(records.get(id, {}).get("definition_id", "")) == definition:
			return str(id)
	return ""

func serialize(inventory: RefCounted) -> Dictionary:
	sync(inventory)
	var slots: Dictionary = {}
	for slot in equipped: slots[Inventory.Slot.keys()[slot]] = equipped[slot]
	return {"inventory_id": inventory_id, "next_id": next_id, "records": records.duplicate(true), "backpack": backpack.duplicate(), "equipped": slots}

func restore(inventory: RefCounted, data: Dictionary) -> void:
	records.clear()
	backpack.clear()
	equipped.clear()
	if not data.is_empty():
		inventory_id = str(data["inventory_id"])
		next_id = int(data["next_id"])
		records = data["records"].duplicate(true)
		backpack.assign(data["backpack"])
		for slot in data["equipped"]:
			equipped[Inventory.Slot.keys().find(slot)] = data["equipped"][slot]
	sync(inventory)

static func saved_error(dto: Dictionary) -> String:
	if not dto.has("copies"): return ""
	var data: Variant = dto["copies"]
	if not data is Dictionary or not data.get("records") is Dictionary or not data.get("backpack") is Array or not data.get("equipped") is Dictionary:
		return "inventory copies are malformed"
	if not data.get("inventory_id") is String or str(data["inventory_id"]).is_empty() or not data.get("next_id") is float and not data.get("next_id") is int:
		return "inventory identity is invalid"
	if not is_finite(float(data["next_id"])) or float(data["next_id"]) != floorf(float(data["next_id"])) or int(data["next_id"]) < 1:
		return "inventory serial is invalid"
	var seen: Dictionary = {}
	var attunement_counts: Dictionary = {}
	var attuned_definitions: Dictionary = {}
	if data["backpack"].size() != dto.get("backpack", []).size(): return "inventory copy count differs from items"
	for index in data["backpack"].size():
		var id: Variant = data["backpack"][index]
		if not id is String or seen.has(id): return "duplicate inventory copy"
		seen[id] = str(dto["backpack"][index])
	if data["equipped"].size() != dto.get("equipped", {}).size(): return "equipment copies differ from items"
	for slot in data["equipped"]:
		var id: Variant = data["equipped"][slot]
		if slot not in Inventory.Slot.keys() or not id is String or seen.has(id) or not dto.get("equipped", {}).has(slot): return "invalid equipment copy"
		seen[id] = str(dto["equipped"][slot])
	if seen.size() != data["records"].size(): return "unowned inventory copy"
	for id in seen:
		var record: Variant = data["records"].get(id)
		if not record is Dictionary or record.get("instance_id") != id or record.get("definition_id") != seen[id] or not record.get("state") is Dictionary:
			return "inventory copy record differs from item"
		var item: Dictionary = DataLoader.get_item(str(record["definition_id"]))
		var state: Dictionary = record["state"]
		var state_error := record_state_error(record)
		if not state_error.is_empty(): return state_error
		if state.has("attuned_to") and bool(item.get("requires_attunement", false)):
			var owner := str(state["attuned_to"])
			attunement_counts[owner] = int(attunement_counts.get(owner, 0)) + 1
			if attunement_counts[owner] > 3:
				return "character exceeds the three-item attunement limit"
			var owner_items: Dictionary = attuned_definitions.get(owner, {})
			var definition := str(record["definition_id"])
			if definition == "ring_of_protection" and owner_items.has(definition):
				return "character is attuned to duplicate copies of one limited item"
			owner_items[definition] = true
			attuned_definitions[owner] = owner_items
		if str(id).begins_with(str(data["inventory_id"]) + ":") and str(id).get_slice(":", 1).to_int() >= int(data["next_id"]):
			return "inventory serial would reuse an identity"
	return ""

## Review 043 R1: per-copy state rules, shared by carried and contained copies.
static func record_state_error(record: Dictionary) -> String:
	var item: Dictionary = DataLoader.get_item(str(record.get("definition_id", "")))
	var state: Dictionary = record.get("state", {})
	var magic_error := MagicPropertyRules.record_error(record) # Review 044 R3.
	if not magic_error.is_empty(): return magic_error
	var active_error := ActiveTimeRules.record_error(record) # S-064.
	if not active_error.is_empty(): return active_error
	var work_error := WorkRules.record_error(record) # S-066.
	if not work_error.is_empty(): return work_error
	if state.has("food_remaining_daily_fraction"):
		var remaining_food: Variant = state["food_remaining_daily_fraction"]
		if str(record["definition_id"]) != "rations" or (not remaining_food is int and not remaining_food is float) or not is_finite(float(remaining_food)) or float(remaining_food) <= 0.0 or float(remaining_food) >= 1.0:
			return "ration portion state is invalid"
	if state.has("charges"):
		var charges: Variant = state["charges"]
		var maximum := int(item.get("maximum_charges", 0))
		if (not charges is int and not charges is float) or not is_finite(float(charges)) or float(charges) != floorf(float(charges)) or int(charges) < 0 or int(charges) > 10000 or (maximum > 0 and int(charges) > maximum):
			return "magic item charges are invalid"
	elif int(item.get("maximum_charges", 0)) > 0:
		return "charged magic item is missing its charge state"
	var degraded_error := LastChargeRules.saved_state_error(str(record["definition_id"]), state)
	if not degraded_error.is_empty(): return degraded_error
	if state.has("attuned_to") and (not state["attuned_to"] is String or str(state["attuned_to"]).is_empty()):
		return "magic item attunement is invalid"
	if bool(state.get("cursed_attunement", false)) and (not bool(item.get("cursed", false)) or not state.has("attuned_to")):
		return "cursed item attunement is invalid"
	return ""

## Party DTOs are canonical; player DTOs repeat the same seat-owned character.
## A current dungeon snapshot also repeats its ledger entry, not its item grants.
static func ownership_error(save: Dictionary) -> String:
	var seen: Dictionary = {}
	var party_characters: Dictionary = save.get("party", {}).get("characters", {}) if save.get("party") is Dictionary else {}
	var work_characters: Array = party_characters.values()
	var work_owners: Array = party_characters.keys()
	for player in save.get("players", []):
		var character: Variant = player.get("character")
		if not character is Dictionary: continue
		var owner := str(character.get("character_id", ""))
		if owner not in work_owners:
			work_characters.append(character)
			work_owners.append(owner)
	var work_error := WorkRules.party_error(work_characters)
	if not work_error.is_empty(): return work_error
	for character in party_characters.values():
		for id in character.get("inventory", {}).get("copies", {}).get("records", {}).keys() + ContainerRules.content_ids(character.get("inventory", {})) + AttachmentRules.attached_ids(character.get("inventory", {})) + ItemProjectionRules.copy_ids(character):
			if seen.has(id): return "item copy has multiple character owners"
			seen[id] = true
	for player in save.get("players", []):
		var character: Variant = player.get("character")
		if not character is Dictionary: continue
		var owner := str(character.get("character_id", ""))
		if party_characters.has(owner):
			if character.get("inventory", {}) != party_characters[owner].get("inventory", {}): return "player inventory differs from its party character"
			if character.get("item_projections", {}) != party_characters[owner].get("item_projections", {}): return "player item projections differ from its party character"
			continue
		for id in character.get("inventory", {}).get("copies", {}).get("records", {}).keys() + ContainerRules.content_ids(character.get("inventory", {})) + AttachmentRules.attached_ids(character.get("inventory", {})) + ItemProjectionRules.copy_ids(character):
			if seen.has(id): return "item copy has multiple character owners"
			seen[id] = true
	var dungeons: Dictionary = save.get("campaign_ledger", {}).get("dungeon_snapshots", {}).duplicate(true)
	var active: Dictionary = save.get("active_dungeon_state", {})
	if not active.is_empty(): dungeons[active["dungeon_id"]] = active
	for dungeon in dungeons.values():
		for room in dungeon.get("local_rooms", {}).values():
			for object in room["objects"]:
				for item in object["contents"]:
					if seen.has(item["instance_id"]): return "item copy has multiple world or inventory owners"
					seen[item["instance_id"]] = true
	return ""
