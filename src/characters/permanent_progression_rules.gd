## Opt-in permanent class acquisition. Receipts are restored, never executed on load.
class_name PermanentProgressionRules
extends RefCounted

const PROFICIENCIES := ["skill_proficiencies", "tool_proficiencies", "weapon_proficiencies", "armor_proficiencies", "saving_throw_proficiencies"]

static func definition_error(data: Dictionary, resolve_references: bool = true) -> String:
	if not data.has("permanent_progression"): return ""
	if "|" in str(data.get("id", "")): return "Progression class ID cannot contain a receipt delimiter."
	if resolve_references and (not DataLoader.get_subclasses_for_class(str(data.get("id", ""))).is_empty() or not str(data.get("legacy_subclass", "")).is_empty()): return "Subclass progression is unavailable in this host."
	for field in PROFICIENCIES + ["starting_equipment", "skill_choices", "tool_choices", "spell_slots_by_character_level", "spell_slots_by_level", "pact_magic_by_level"]:
		if (not data.get(field, []) is Array and not data.get(field, []) is Dictionary) or not data.get(field, []).is_empty(): return "Permanent progression replaces native acquisition/slot fields."
	if not data.get("features_by_level", {}) is Dictionary: return "Invalid progression features."
	for features in data.get("features_by_level", {}).values():
		if not features is Array: return "Invalid progression feature level."
		for feature in features:
			if not feature is Dictionary or feature.get("type", "") != "passive" or feature.has("resource_pool"): return "This progression host supports passive proficiency choices only."
			if not feature.get("effects", []) is Array or not feature.get("passive_effects", []) is Array: return "Invalid progression effects."
			for effect in feature.get("effects", []) + feature.get("passive_effects", []):
				if not effect is Dictionary or effect.get("type", "") != "feature_choice": return "This progression host supports passive proficiency choices only."
				if not effect.get("options", []) is Array: return "Invalid progression options."
				for option in effect.get("options", []):
					if not option is Dictionary or not option.get("effects", []) is Array: return "Invalid progression option effects."
					var option_error := grants_error(option.get("effects", []), resolve_references)
					if not option_error.is_empty(): return option_error
					for grant in option.get("effects", []):
						if not grant is Dictionary or grant.get("type", "") != "proficiency_grant": return "Unsupported progression choice payload."
						for field in grant:
							if field not in ["type", "weapon_proficiencies", "armor_proficiencies", "skill_proficiencies"]: return "Progression choices support weapon, armor and skill proficiencies only."
	var p: Variant = data.permanent_progression
	if not p is Dictionary or p.size() != 4 or not p.has_all(["starting", "multiclass", "levels", "level_hit_points"]): return "Permanent progression requires starting, multiclass, levels and level_hit_points."
	if not ResourcePoolRules._integer(p.level_hit_points, 1, 20): return "Invalid permanent level HP."
	for boundary in ["starting", "multiclass"]:
		var error := grants_error(p[boundary], resolve_references)
		if not error.is_empty(): return error
	if not p.levels is Array or p.levels.size() > 80: return "Progression levels must be a bounded array."
	var ids: Array = []
	for entry in p.levels:
		if not entry is Dictionary or entry.size() != 4 or not entry.has_all(["id", "basis", "at", "grants"]): return "Invalid progression level entry."
		if not entry.id is String or entry.id.is_empty() or "|" in entry.id or entry.id in ids: return "Progression entry IDs must be distinct."
		ids.append(entry.id)
		if entry.basis not in ["class", "character"] or not ResourcePoolRules._integer(entry.at, 1, 20): return "Invalid progression level boundary."
		var error := grants_error(entry.grants, resolve_references)
		if not error.is_empty(): return error
	return ""

static func grants_error(grants: Variant, resolve_references: bool = true) -> String:
	if not grants is Array or grants.size() > 32: return "Permanent grants must be a bounded array."
	for grant in grants:
		if not grant is Dictionary: return "Permanent grant must be an object."
		match grant.get("type", ""):
			"proficiency_grant":
				if grant.size() < 2: return "Empty proficiency grant."
				for field in grant:
					if field == "type": continue
					if field not in PROFICIENCIES + ["expertise"] or not grant[field] is Array or grant[field].is_empty() or grant[field].size() > 30: return "Invalid proficiency field."
					var seen: Array = []
					for value in grant[field]:
						if not value is String or value.is_empty() or value in seen: return "Invalid or duplicate proficiency."
						seen.append(value)
						if field in ["skill_proficiencies", "expertise"] and value not in DataLoader.VALID_SKILLS: return "Unknown skill."
						if field == "armor_proficiencies" and value not in ["light", "medium", "heavy", "shields"]: return "Unknown armor proficiency."
						if resolve_references and field == "weapon_proficiencies" and value not in ["simple", "martial"] and DataLoader.get_item(value).get("type", "") != "weapon": return "Unknown weapon proficiency."
						if field == "saving_throw_proficiencies" and value not in AbilityScores.ABILITIES: return "Unknown saving throw."
						if resolve_references and field == "tool_proficiencies" and DataLoader.get_item(value).get("type", "") != "tool": return "Unknown tool."
			"equipment_grant":
				if grant.size() != 3 or not grant.has_all(["item_id", "quantity"]) or not grant.item_id is String or grant.item_id.is_empty() or (resolve_references and DataLoader.get_item(grant.item_id).is_empty()) or not ResourcePoolRules._integer(grant.quantity, 1, 20): return "Invalid equipment grant."
			"ability_delta":
				if grant.size() != 4 or not grant.has_all(["ability", "amount", "maximum"]) or grant.ability not in AbilityScores.ABILITIES or not ResourcePoolRules._integer(grant.amount, 1, 10) or not ResourcePoolRules._integer(grant.maximum, 1, 30): return "Invalid permanent ability delta."
			"max_hp_delta":
				if grant.size() != 2 or not ResourcePoolRules._integer(grant.get("amount"), 1, 100): return "Invalid permanent HP delta."
			_: return "Unsupported permanent grant."
	return ""

static func enabled(class_id: String) -> bool:
	return DataLoader.get_character_class(class_id).has("permanent_progression")

## Reconstruct the required acquisition receipts from the actual ordered level choices.
static func expected_receipts(history: Array) -> Dictionary:
	var receipts := {}
	var allocation := {}
	for index in history.size():
		var id: String = history[index]
		allocation[id] = int(allocation.get(id, 0)) + 1
		var p: Dictionary = DataLoader.get_character_class(id).permanent_progression
		if int(allocation[id]) == 1:
			var boundary := "starting" if index == 0 else "multiclass"
			receipts[id + "|" + boundary] = {"class_id":id, "boundary":boundary, "character_level":index+1, "class_level":1, "grants":p[boundary].duplicate(true)}
		for owned_id in allocation:
			var owned: Dictionary = DataLoader.get_character_class(owned_id).permanent_progression
			for entry in owned.levels:
				var key: String = owned_id + "|level:" + entry.id
				var value := int(allocation[owned_id]) if entry.basis == "class" else index+1
				if value >= int(entry.at) and not receipts.has(key):
					receipts[key] = {"class_id":owned_id, "boundary":entry.basis, "character_level":index+1, "class_level":allocation[owned_id], "grants":entry.grants.duplicate(true)}
	return receipts

static func saved_error(dto: Dictionary) -> String:
	var state: Variant = dto.get("permanent_progression", {})
	if not enabled(str(dto.get("class_id", ""))):
		return "Unexpected permanent progression state." if not state is Dictionary or not state.is_empty() else ""
	var allocation_error := Character.saved_class_levels_error(dto)
	if not allocation_error.is_empty(): return allocation_error
	if not state is Dictionary or state.size() != 3 or not state.has_all(["history", "receipts", "pending_levels"]): return "Permanent progression state is missing or malformed."
	if not state.history is Array or state.history.is_empty() or state.history.size() != int(dto.get("level", 0)) or state.history.size() > 20 or state.history[0] != dto.get("class_id"): return "Invalid ordered class history."
	if not ResourcePoolRules._integer(state.pending_levels, 0, 20-state.history.size()): return "Invalid pending progression levels."
	var allocation := {}
	for id in state.history:
		if not id is String or not enabled(id) or not definition_error(DataLoader.get_character_class(id)).is_empty(): return "Progression class is unavailable."
		if id != dto.class_id and not DataLoader.get_character_class(id).get("features_by_level", {}).is_empty(): return "Secondary native features are unavailable in this progression host."
		allocation[id] = int(allocation.get(id, 0)) + 1
	if allocation.size() > 12: return "Too many progression classes."
	if int(dto.get("proficiency_bonus", 0)) != 2 + int((state.history.size()-1)/4): return "Permanent proficiency bonus disagrees with character level."
	var saved_allocation: Dictionary = dto.get("class_levels", {})
	if saved_allocation.size() != allocation.size(): return "Progression history disagrees with class allocation."
	for id in allocation:
		if int(saved_allocation.get(id, -1)) != int(allocation[id]): return "Progression history disagrees with class allocation."
	if not state.receipts is Dictionary or not same_json(state.receipts, expected_receipts(state.history)): return "Permanent acquisition receipts are missing or changed."
	for receipt in state.receipts.values():
		for grant in receipt.grants:
			if grant.type != "proficiency_grant": continue
			for field in PROFICIENCIES:
				if not dto.get(field, []) is Array: return "Malformed permanent proficiency array."
				for value in grant.get(field, []):
					if value not in dto.get(field, []): return "Missing permanent proficiency."
			for skill in grant.get("expertise", []):
				if skill not in dto.get("skill_proficiencies", []): return "Permanent expertise requires its proficiency."
	return ""

static func initialize(c: Character) -> void:
	c.class_levels = {c.class_id:1}
	c.permanent_progression = {"history":[c.class_id], "receipts":{}, "pending_levels":0}
	_apply_new(c)

static func request_level(c: Character) -> bool:
	if not saved_error(c.to_dict()).is_empty() or c.level + int(c.permanent_progression.pending_levels) >= 20: return false
	c.permanent_progression.pending_levels += 1
	return true

static func available_classes(c: Character) -> Array[String]:
	var out: Array[String] = []
	if c == null or not enabled(c.class_id): return out
	for id in DataLoader.classes:
		var data := DataLoader.get_character_class(id)
		if enabled(id) and definition_error(data).is_empty() and (id == c.class_id or data.get("features_by_level", {}).is_empty()): out.append(id)
	out.sort()
	return out

static func advance(c: Character, class_id: String, captured_state: Dictionary) -> bool:
	if c == null or GameManager.current_state == GameManager.GameState.COMBAT or c.permanent_progression != captured_state or not saved_error(c.to_dict()).is_empty(): return false
	if int(c.permanent_progression.get("pending_levels", 0)) <= 0 or c.level >= 20 or class_id not in available_classes(c): return false
	if not c.class_levels.has(class_id) and c.class_levels.size() >= 12: return false
	var history: Array = c.permanent_progression.history.duplicate()
	history.append(class_id)
	if not can_fit(c, expected_receipts(history)): return false
	c.level += 1
	c.class_levels[class_id] = int(c.class_levels.get(class_id, 0)) + 1
	c.permanent_progression.history.append(class_id)
	c.permanent_progression.pending_levels -= 1
	c.proficiency_bonus = 2 + int((c.level-1)/4)
	var p: Dictionary = DataLoader.get_character_class(class_id).permanent_progression
	var hp_gain := maxi(1, int(p.level_hit_points) + AbilityScores.get_modifier(c.ability_scores.get_permanent_score("CON")))
	c.max_hp += hp_gain
	if c.is_alive and not c.is_dead(): c.current_hp = c.max_hp
	_apply_new(c)
	if class_id == c.class_id: c._unlock_features_for_level(c.get_class_level())
	c._recalculate_ac()
	return true

static func can_fit(c: Character, receipts: Dictionary) -> bool:
	var count := 0
	for key in receipts:
		if c.permanent_progression.get("receipts", {}).has(key): continue
		for grant in receipts[key].grants:
			if grant.type == "equipment_grant": count += int(grant.quantity)
	return c.inventory.backpack.size() + count <= Inventory.MAX_BACKPACK_SIZE

static func _apply_new(c: Character) -> void:
	var expected := expected_receipts(c.permanent_progression.history)
	for key in expected:
		if c.permanent_progression.receipts.has(key): continue
		for grant in expected[key].grants:
			match grant.type:
				"proficiency_grant":
					for field in PROFICIENCIES:
						var values: Array = c.get(field)
						for value in grant.get(field, []):
							if value not in values: values.append(value)
					for skill in grant.get("expertise", []):
						if skill not in c.skill_proficiencies: c.skill_proficiencies.append(skill)
				"equipment_grant":
					for _copy in int(grant.quantity): c.inventory.add_item(grant.item_id)
				"ability_delta":
					var hp_before := c.current_hp
					var was_dead := c.is_dead() or not c.is_alive
					var amount := mini(int(grant.amount), maxi(0, int(grant.maximum)-c.ability_scores.get_permanent_score(grant.ability)))
					if amount > 0: ClassProgression.increase_score(c, grant.ability, amount)
					if was_dead: c.current_hp = hp_before
				"max_hp_delta":
					c.max_hp += int(grant.amount)
					if c.is_alive and not c.is_dead(): c.current_hp += int(grant.amount)
		c.permanent_progression.receipts[key] = expected[key].duplicate(true)

static func retains(c: Character, field: String, value: String) -> bool:
	for receipt in c.permanent_progression.get("receipts", {}).values():
		for grant in receipt.grants:
			if grant.type == "proficiency_grant" and (value in grant.get(field, []) or (field == "skill_proficiencies" and value in grant.get("expertise", []))): return true
	return false

static func expertise(c: Character, skill: String) -> bool:
	return retains(c, "expertise", skill)


## Godot's Dictionary equality distinguishes JSON floats from integral runtime values.
## Compare the same plain JSON representation after validating the bounded state.
static func same_json(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
