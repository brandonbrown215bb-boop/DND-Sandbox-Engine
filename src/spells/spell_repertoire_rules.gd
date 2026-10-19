## Separate preparation for additional acquired classes and opt-in class sources.
## Choices reuse feature_choices; receipts retain each source's replacement window.
class_name SpellRepertoireRules
extends RefCounted

static func sources(character: Character) -> Array[Dictionary]:
	return sources_for(character.class_id, character.level, character.class_levels)

static func sources_for(primary: String, level: int, allocation: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var levels := allocation.duplicate()
	if levels.is_empty(): levels[primary] = level
	for class_id in levels:
		var data := DataLoader.get_character_class(str(class_id))
		var class_level := int(levels[class_id])
		for key in data.get("features_by_level", {}):
			if int(key) > class_level: continue
			for feature in data.features_by_level[key]:
				for effect in feature.get("effects", []):
					if effect.get("type", "") != "spellcasting": continue
					if not bool(effect.get("separate_repertoire", false)): continue
					var source: Dictionary = effect.duplicate(true)
					source["id"] = str(feature.id)
					source["class_id"] = str(class_id)
					source["name"] = str(data.get("name", class_id))
					source["level"] = class_level
					source["maximum_spell_level"] = mini(int(effect.get("maximum_spell_level", 9)), ClassProgression._max_spell_slot_level(data, class_level))
					out.append(source)
	return out

static func capacity(source: Dictionary, kind: String) -> int:
	var threshold := 0
	for key in source.get("capacity_by_level", {}):
		if int(key) <= int(source.level): threshold = maxi(threshold, int(key))
	return int(source.get("capacity_by_level", {}).get(str(threshold), {}).get(kind, 0))

static func options(source: Dictionary, cantrips: bool, supported_only: bool = true) -> Array[String]:
	var out: Array[String] = []
	for spell in DataLoader.get_spell_list_options(source.get("spell_lists", [])):
		var level := int(spell.get("level", -1))
		if (cantrips and level != 0) or (not cantrips and (level < 1 or level > int(source.maximum_spell_level))): continue
		if supported_only and not SpellSupport.is_available(spell): continue
		if not SpellPermissionRules._components_allowed(spell, source): continue
		if source.has("book_spells") and level > 0 and spell.id not in source.book_spells: continue
		out.append(str(spell.id))
	return out

static func permissions(character: Character, spell: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for source in sources(character):
		var ability := str(source.get("ability", "")).to_upper()
		if ability not in AbilityScores.ABILITIES: continue
		var prepared: bool = str(spell.get("id", "")) in character.feature_choices.get(source.id, []) and str(spell.get("id", "")) in options(source, int(spell.get("level", 0)) == 0, false)
		if prepared:
			var permission := SpellPermissionRules._permission(str(source.id), "class", ability, spell, source)
			permission["class_id"] = str(source.class_id)
			permission["label"] = str(source.name)
			out.append(permission)
		elif str(spell.get("id", "")) in source.get("ritual_spells", []) and bool(spell.get("ritual", false)) and int(spell.get("level", 0)) <= int(source.maximum_spell_level) and SpellPermissionRules._components_allowed(spell, source):
			var ritual_permission := SpellPermissionRules._permission(str(source.id), "ritual", ability, spell, source)
			ritual_permission["class_id"] = str(source.class_id)
			ritual_permission["label"] = str(source.name) + " ritual"
			out.append(ritual_permission)
	return out

static func can_edit(character: Character, source: Dictionary) -> bool:
	if GameManager.current_state == GameManager.GameState.COMBAT: return false
	var old: Array = character.feature_choices.get(source.id, [])
	var receipt: Dictionary = character.spell_repertoire_state.get(source.id, {})
	if old.is_empty(): return true
	if old.size() < mini(capacity(source, "cantrips"), options(source, true).size()) + mini(capacity(source, "prepared_spells"), options(source, false).size()): return true
	match str(source.get("replacement", "level")):
		"level": return int(receipt.get("level", source.level)) < int(source.level)
		"long_rest": return bool(receipt.get("rest_open", false))
	return false

static func choose(character: Character, source_id: String, ids: Array[String], captured: Dictionary) -> bool:
	var source: Dictionary = {}
	for candidate in sources(character):
		if candidate.id == source_id: source = candidate
	if source.is_empty() or source != captured or not can_edit(character, source): return false
	var cantrips := options(source, true)
	var spells := options(source, false)
	var seen: Array[String] = []
	var chosen_cantrips := 0
	var chosen_spells := 0
	for id in ids:
		if id in seen: return false
		if id in cantrips: chosen_cantrips += 1
		elif id in spells: chosen_spells += 1
		else: return false
		seen.append(id)
	if chosen_cantrips != mini(capacity(source, "cantrips"), cantrips.size()) or chosen_spells != mini(capacity(source, "prepared_spells"), spells.size()): return false
	var old: Array = character.feature_choices.get(source_id, [])
	var removed := old.filter(func(id): return id not in seen).size()
	var receipt: Dictionary = character.spell_repertoire_state.get(source_id, {})
	var window := (str(source.get("replacement", "level")) == "level" and int(receipt.get("level", source.level)) < int(source.level)) or (str(source.get("replacement", "level")) == "long_rest" and bool(receipt.get("rest_open", false)))
	if removed > 0 and (not window or removed > int(source.get("replacement_count", 1))): return false
	character.feature_choices[source_id] = seen
	character.spell_repertoire_state[source_id] = {"level":int(source.level), "rest_open":false}
	character.refresh_spell_selection_from_choices()
	return true

static func long_rest(character: Character) -> void:
	for source in sources(character):
		if source.get("replacement", "level") != "long_rest" or not character.feature_choices.has(source.id): continue
		var receipt: Dictionary = character.spell_repertoire_state.get(source.id, {"level":int(source.level)})
		receipt["rest_open"] = true
		character.spell_repertoire_state[source.id] = receipt

static func prune_removed(character: Character) -> void:
	var owned := {}
	var removed: Array = []
	for source in sources(character): owned[source.id] = true
	for id in character.spell_repertoire_state.keys():
		if owned.has(id): continue
		removed.append_array(character.feature_choices.get(id, []))
		character.feature_choices.erase(id)
		character.spell_repertoire_state.erase(id)
	for id in removed:
		if SpellPermissionRules.for_spell(character, DataLoader.get_spell(str(id))).is_empty(): character.known_spells.erase(str(id))

static func saved_error(dto: Dictionary) -> String:
	var state: Variant = dto.get("spell_repertoire_state", {})
	if not state is Dictionary: return "Spell repertoire state is not an object"
	var choices: Dictionary = dto.get("feature_choices", {})
	var available := sources_for(str(dto.get("class_id", "")), int(dto.get("level", 1)), dto.get("class_levels", {}))
	var sources_by_id := {}
	for source in available:
		sources_by_id[source.id] = source
		var ids: Variant = choices.get(source.id, [])
		if not ids is Array: return "Spell repertoire choices are not an array"
		var cantrips := options(source, true, false)
		var spells := options(source, false, false)
		var seen := {}
		var counts := [0, 0]
		for id in ids:
			if not id is String or seen.has(id): return "Spell repertoire contains invalid or duplicate choices"
			seen[id] = true
			if id in cantrips: counts[0] += 1
			elif id in spells: counts[1] += 1
			else: return "Spell repertoire borrows an unavailable spell or list"
		if counts[0] > capacity(source, "cantrips") or counts[1] > capacity(source, "prepared_spells"): return "Spell repertoire exceeds its source capacity"
	for id in state:
		if not sources_by_id.has(id) or not choices.has(id): return "Spell repertoire receipt has no acquired source"
		var receipt: Variant = state[id]
		if not receipt is Dictionary or receipt.size() != 2 or not receipt.get("rest_open") is bool: return "Spell repertoire receipt is invalid"
		var trained: Variant = receipt.get("level")
		if not (trained is int or trained is float) or not is_finite(float(trained)) or float(trained) != floorf(float(trained)) or int(trained) < 1 or int(trained) > int(sources_by_id[id].level): return "Spell repertoire training level is invalid"
		if receipt.rest_open and sources_by_id[id].get("replacement", "level") != "long_rest": return "Spell repertoire has the wrong replacement boundary"
	return ""
