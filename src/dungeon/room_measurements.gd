class_name RoomMeasurements
extends RefCounted
## S-032/S-196 (Batch 069): a room copy's material, size and weight are facts
## from its item data or its authored room object. Absence means unknown; it is
## never read as zero, one pound, "Tiny" or "wood". Volume stays PARTIAL.
##
## Saves written before d450b24 stamped every dropped ("placed:") copy with
## material "mixed", size "Tiny" and weight 1 lb whatever its data said. That
## exact three-value stamp on a placed copy is legacy invention, not data, so
## it is dropped for each fact the item definition does not record. Authored
## room objects never carry a "placed:" identity and are never touched.

const LEGACY_STAMP := {"material": "mixed", "size": "Tiny", "weight_lb": 1.0} # weight_lb was item weight, else 1
const ITEM_KEYS := {"material": "material", "size": "size", "weight_lb": "weight"}

static func _placed_identity(fields: Dictionary) -> bool:
	return str(fields.get("object_id", fields.get("id", ""))).begins_with("placed:")

## The invented fields (subset of material/size/weight_lb) in a legacy stamp.
static func legacy_invented(fields: Dictionary, definition_id: String) -> Array[String]:
	var result: Array[String] = []
	if not _placed_identity(fields): return result
	var item := DataLoader.get_item(definition_id)
	if item.is_empty(): return result
	for key in LEGACY_STAMP:
		if not fields.has(key): return result
	if str(fields.material) != "mixed" or str(fields.size) != "Tiny": return result
	# The legacy formula was item.get("weight", 1): only that exact value is a stamp.
	var stamped_weight := float(item.weight) if (item.get("weight") is int or item.get("weight") is float) else 1.0
	if not (fields.weight_lb is int or fields.weight_lb is float) or not is_equal_approx(float(fields.weight_lb), stamped_weight): return result
	for key in ITEM_KEYS:
		if not item.has(ITEM_KEYS[key]): result.append(key)
	return result

## A copy of `fields` without legacy-invented measurements.
static func known_fields(fields: Dictionary, definition_id: String) -> Dictionary:
	var result := fields.duplicate(true)
	for key in legacy_invented(fields, definition_id): result.erase(key)
	return result

## Load migration for every local room of a dungeon snapshot. Returns the
## number of facts returned to unknown.
static func migrate_dungeon(dungeon: Variant) -> int:
	var count := 0
	if not dungeon is Dictionary or not dungeon.get("local_rooms") is Dictionary: return 0
	for room in dungeon.local_rooms.values():
		if not room is Dictionary or not room.get("objects") is Array: continue
		for object in room.objects:
			if not object is Dictionary or str(object.get("kind", "")) != "loose": continue
			var contents: Variant = object.get("contents", [])
			if not contents is Array or contents.size() != 1 or not contents[0] is Dictionary: continue
			var record: Dictionary = contents[0]
			var definition_id := str(record.get("definition_id", ""))
			for key in legacy_invented(object, definition_id):
				object.erase(key)
				count += 1
			var state: Variant = record.get("state", {})
			if state is Dictionary and state.get("physical") is Dictionary:
				for key in legacy_invented(state.physical, definition_id):
					state.physical.erase(key)
					count += 1
	return count

static func _weight_text(value: Variant) -> String:
	var known: Variant = PhysicalFactsRules._known_measure(value)
	if known == null: return "unknown weight"
	return "%s lb" % LocalRoomRules._quantity_text(float(known))

## Player-facing measurement text for a room object; absent facts say unknown.
static func describe_object(object: Dictionary) -> String:
	var material := str(object.get("material", ""))
	var size := str(object.get("size", ""))
	return "%s, %s, %s" % [material if not material.is_empty() else "unknown material", size if not size.is_empty() else "unknown size", _weight_text(object.get("weight_lb", null))]

## S-032/S-196 (Batch 078): a room container's item-count capacity is a data fact
## (`capacity`). Absent means undeclared; the engine never presents a number as
## the container's capacity. TECHNICAL_CONTENTS_LIMIT is a separate engine bound
## on stored records (save size), labeled as such wherever it is shown.
const TECHNICAL_CONTENTS_LIMIT := 20

static func declared_capacity(object: Dictionary) -> Variant:
	var value: Variant = object.get("capacity", null)
	if object.has("capacity") and capacity_error(object).is_empty(): return int(value)
	return null

static func capacity_error(object: Dictionary) -> String:
	if not object.has("capacity"): return ""
	var value: Variant = object.capacity
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 0.0:
		return "The container's declared capacity must be a whole non-negative item count."
	return ""

static func capacity_text(object: Dictionary) -> String:
	var declared: Variant = declared_capacity(object)
	if declared != null: return "capacity %d items (declared)" % int(declared)
	return "capacity undeclared; engine technical limit %d items (not a game rule)" % TECHNICAL_CONTENTS_LIMIT

## Empty when one more item may be stowed. Declared capacity is enforced; an
## undeclared container is bounded only by the labeled technical limit.
static func put_error(object: Dictionary) -> String:
	var error := capacity_error(object)
	if not error.is_empty(): return error
	var count: int = object.get("contents", []).size()
	var declared: Variant = declared_capacity(object)
	if declared != null and count >= int(declared): return "The container is full (declared capacity %d items)." % int(declared)
	if count >= TECHNICAL_CONTENTS_LIMIT: return "Engine technical limit reached (%d items; not a game rule)." % TECHNICAL_CONTENTS_LIMIT
	return ""

## Player-facing measurement text for a carried copy's item data.
static func describe_item(definition_id: String) -> String:
	var item := DataLoader.get_item(definition_id)
	return "Weight: %s; volume: %s." % [_weight_text(item.get("weight", null)).replace("unknown weight", "unknown"), ("%s cu. ft." % LocalRoomRules._quantity_text(float(item.volume))) if item.has("volume") else "unknown (volume limits are PARTIAL)"]

## Saved per-copy physical facts: absent is unknown; a present value must be real.
static func physical_error(record: Dictionary) -> String:
	var state: Variant = record.get("state", {})
	if not state is Dictionary or not state.has("physical"): return ""
	var physical: Variant = state.physical
	if not physical is Dictionary: return "item physical facts are invalid"
	if physical.has("weight_lb") and PhysicalFactsRules._known_measure(physical.weight_lb) == null: return "item physical weight must be a non-negative number or absent when unknown"
	for key in ["material", "size"]:
		if physical.has(key) and (not physical[key] is String or str(physical[key]).is_empty()): return "item physical %s must be text or absent when unknown" % key
	return ""
