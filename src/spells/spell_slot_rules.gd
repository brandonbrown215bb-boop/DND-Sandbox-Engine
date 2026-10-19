## Source-owned slot progression for opted-in spellcasting profiles.
class_name SpellSlotRules
extends RefCounted

const MULTICLASS_SLOTS := [
	[], [2], [3], [4, 2], [4, 3], [4, 3, 2], [4, 3, 3], [4, 3, 3, 1],
	[4, 3, 3, 2], [4, 3, 3, 3, 1], [4, 3, 3, 3, 2], [4, 3, 3, 3, 2, 1],
	[4, 3, 3, 3, 2, 1], [4, 3, 3, 3, 2, 1, 1], [4, 3, 3, 3, 2, 1, 1],
	[4, 3, 3, 3, 2, 1, 1, 1], [4, 3, 3, 3, 2, 1, 1, 1],
	[4, 3, 3, 3, 2, 1, 1, 1, 1], [4, 3, 3, 3, 3, 1, 1, 1, 1],
	[4, 3, 3, 3, 3, 2, 1, 1, 1], [4, 3, 3, 3, 3, 2, 2, 1, 1]
]

static func casting_sources(character: Character) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var allocation: Dictionary = character.class_levels.duplicate(true)
	if allocation.is_empty(): allocation[character.class_id] = character.level
	for class_id in allocation:
		var class_level := int(allocation[class_id])
		var data := DataLoader.get_character_class(str(class_id))
		for level_key in data.get("features_by_level", {}):
			if int(level_key) > class_level: continue
			for feature in data.features_by_level[level_key]:
				for effect in feature.get("effects", []):
					if effect.get("type", "") != "spellcasting": continue
					var source: Dictionary = effect.duplicate(true)
					source["class_id"] = str(class_id)
					source["class_level"] = class_level
					source["feature_id"] = str(feature.get("id", ""))
					out.append(source)
	return out

static func ordinary_maximum(character: Character) -> Dictionary:
	var sources := casting_sources(character)
	var non_pact: Array[Dictionary] = []
	for source in sources:
		if _contribution_mode(str(source.class_id)).is_empty(): continue
		non_pact.append(source)
	if non_pact.is_empty(): return {}
	if non_pact.size() == 1:
		return _class_slots(str(non_pact[0].class_id), int(non_pact[0].class_level))
	var caster_level := 0
	for source in non_pact:
		var mode := _contribution_mode(str(source.class_id))
		var class_level := int(source.class_level)
		match mode:
			"full": caster_level += class_level
			"half_up": caster_level += int(ceil(float(class_level) / 2.0))
			"half_down": caster_level += int(floor(float(class_level) / 2.0))
			"third_down": caster_level += int(floor(float(class_level) / 3.0))
			_: return {}
	caster_level = clampi(caster_level, 0, 20)
	if caster_level <= 0: return {}
	var counts: Array = MULTICLASS_SLOTS[caster_level]
	var slots := {}
	for index in counts.size(): slots[str(index + 1)] = int(counts[index])
	return slots

static func pact_maximum(character: Character) -> Dictionary:
	var allocation: Dictionary = character.class_levels.duplicate(true)
	if allocation.is_empty(): allocation[character.class_id] = character.level
	for class_id in allocation:
		var data := DataLoader.get_character_class(str(class_id))
		var table: Dictionary = data.get("pact_magic_by_level", {})
		var row: Dictionary = table.get(str(int(allocation[class_id])), {})
		if not row.is_empty(): return {str(int(row.get("slot_level", 1))): int(row.get("slots", 0))}
	return {}

static func pool_rows(character: Character) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var pact_in_legacy_pool := character.pact_spell_slots.is_empty() and not pact_maximum(character).is_empty() and character.get_max_spell_slots() == pact_maximum(character)
	for key in character.spell_slots:
		rows.append({"pool_id":"pact" if pact_in_legacy_pool else "ordinary", "level":int(key), "remaining":int(character.spell_slots[key])})
	for key in character.pact_spell_slots:
		rows.append({"pool_id":"pact", "level":int(key), "remaining":int(character.pact_spell_slots[key])})
	return rows

static func default_pool_id(character: Character) -> String:
	var rows := pool_rows(character)
	if not rows.is_empty() and rows.all(func(row): return str(row.pool_id) == "pact"): return "pact"
	return "ordinary"

static func remaining(character: Character, pool_id: String, level: int) -> int:
	for row in pool_rows(character):
		if str(row.pool_id) == pool_id and int(row.level) == level: return int(row.remaining)
	return 0

static func spend(character: Character, pool_id: String, level: int) -> bool:
	if remaining(character, pool_id, level) <= 0: return false
	if pool_id == "pact" and not character.pact_spell_slots.is_empty():
		character.pact_spell_slots[str(level)] = int(character.pact_spell_slots[str(level)]) - 1
	else:
		character.spell_slots[str(level)] = int(character.spell_slots[str(level)]) - 1
	return true

static func restore(character: Character, pool_id: String, level: int) -> void:
	if pool_id == "pact" and not character.pact_spell_slots.is_empty():
		character.pact_spell_slots[str(level)] = int(character.pact_spell_slots.get(str(level), 0)) + 1
	else:
		character.spell_slots[str(level)] = int(character.spell_slots.get(str(level), 0)) + 1

static func available(character: Character, minimum_level: int, pool_id: String = "") -> bool:
	for row in pool_rows(character):
		if (pool_id.is_empty() or str(row.pool_id) == pool_id) and int(row.level) >= minimum_level and int(row.remaining) > 0: return true
	return false

static func _class_slots(class_id: String, class_level: int) -> Dictionary:
	var data := DataLoader.get_character_class(class_id)
	var table: Dictionary = data.get("spell_slots_by_character_level", {})
	var rows: Array = table.get(str(class_level), [])
	var result := {}
	for index in rows.size():
		if int(rows[index]) > 0: result[str(index + 1)] = int(rows[index])
	return result

static func _contribution_mode(class_id: String) -> String:
	var data := DataLoader.get_character_class(class_id)
	var table: Dictionary = data.get("spell_slots_by_character_level", {})
	if table.is_empty(): return ""
	var full_match := true
	var half_up_match := true
	for level in range(1, 21):
		var actual: Array = table.get(str(level), [])
		if not _rows_equal(actual, MULTICLASS_SLOTS[level]): full_match = false
		var half_level := int(ceil(float(level) / 2.0))
		if not _rows_equal(actual, MULTICLASS_SLOTS[half_level]): half_up_match = false
	if full_match: return "full"
	if half_up_match: return "half_up"
	return ""

static func _rows_equal(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size(): return false
	for index in expected.size():
		if int(actual[index]) != int(expected[index]): return false
	return true
