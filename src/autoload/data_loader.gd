## Data Loader
## Autoloaded singleton for deterministic, validated content registration.
## Core records are loaded before mods. Every collision must be named in
## data/content_manifest.json so precedence cannot depend on enumeration order.
extends Node

signal data_loaded
signal load_error(message: String)

var classes: Dictionary = {}
var races: Dictionary = {}
var items: Dictionary = {}
var spells: Dictionary = {}
var monsters: Dictionary = {}
var events: Dictionary = {}
var campaigns: Dictionary = {}

const CORE_PATH := "res://data/core/"
const MODS_PATH := "res://data/mods/"
const MANIFEST_PATH := "res://data/content_manifest.json"

const CURATED_SPELL_ACCESS := {
	"artificer": {"0": ["fire_bolt"], "1": ["cure_wounds"], "2": ["misty_step"]},
	"bard": {"0": ["light"], "1": ["cure_wounds", "sleep"], "2": ["misty_step"]},
	"cleric": {"0": ["light"], "1": ["bless", "cure_wounds"]},
	"druid": {"0": ["ray_of_frost"], "1": ["cure_wounds", "thunderwave"], "2": ["misty_step"]},
	"paladin": {"1": ["bless", "cure_wounds"]},
	"ranger": {"1": ["cure_wounds", "hunters_mark"], "2": ["misty_step"]},
	"sorcerer": {"0": ["fire_bolt", "ray_of_frost"], "1": ["magic_missile", "shield"], "2": ["scorching_ray"], "3": ["fireball"]},
	"warlock": {"0": ["fire_bolt"], "1": ["magic_missile"], "2": ["misty_step"], "3": ["counterspell"]},
	"wizard": {"0": ["fire_bolt", "ray_of_frost", "light"], "1": ["magic_missile", "shield", "mage_armor", "sleep"], "2": ["misty_step", "scorching_ray"], "3": ["fireball", "counterspell"]},
}

const CURATED_PACT_MAGIC := {
	"1": {"slot_level": 1, "slots": 1},
	"2": {"slot_level": 2, "slots": 2},
	"3": {"slot_level": 2, "slots": 2},
	"4": {"slot_level": 2, "slots": 2},
	"5": {"slot_level": 3, "slots": 2},
}

const CURATED_FEATURE_EFFECTS := {
	"fighter_second_wind": {"effects": [{"type": "heal_self", "value": "1d10+level"}], "uses_per": "rest"},
	"fighter_action_surge": {"effects": [{"type": "grant_extra_action"}], "uses_per": "rest"},
	"fighter_extra_attack": {"type": "passive", "effects": [{"type": "extra_attack", "count": 1}]},
	"barbarian_rage": {"effects": [
		{"type": "grant_condition", "condition": "raging", "duration": 10},
		{"type": "stat_modifier", "key": "damage:physical", "amount": 2, "duration": 10}
	], "uses_per": "rest", "action_cost": "bonus_action"},
	"barbarian_unarmored_defense": {"type": "passive", "effects": [
		{"type": "unarmored_defense", "ability": "CON", "allows_shield": true}
	]},
	"barbarian_reckless_attack": {"type": "passive", "effects": [
		{"type": "reckless_attack"}
	]},
	"monk_patient_defense": {"effects": [
		{"type": "grant_condition", "condition": "dodging", "duration": 1}
	], "uses": 1, "uses_per": "turn", "action_cost": "bonus_action"},
	"monk_unarmored_defense": {"type": "passive", "effects": [{"type": "unarmored_defense"}]},
	"monk_step_of_the_wind": {"effects": [
		{"type": "step_of_the_wind"}
	], "uses": 1, "uses_per": "turn", "action_cost": "bonus_action"},
	"monk_martial_arts": {"effects": [
		{"type": "unarmed_attack"}
	], "uses": 1, "uses_per": "turn", "action_cost": "bonus_action"},
	"monk_bonus_unarmed_strike": {"effects": [
		{"type": "unarmed_attack"}
	], "uses": 1, "uses_per": "turn", "action_cost": "bonus_action"},
	"monk_flurry_of_blows": {"effects": [
		{"type": "unarmed_attack", "count": 2}
	], "uses": 1, "uses_per": "turn", "action_cost": "bonus_action"},
	"paladin_divine_smite": {"type": "passive", "effects": [
		{"type": "divine_smite", "base_dice": "2d8", "damage_type": "radiant"}
	]},
	"paladin_fighting_style": {"type": "passive", "effects": [
		{"type": "defense_style", "ac_bonus": 1, "requires_armor": true}
	]},
	"ranger_fighting_style": {"type": "passive", "effects": [
		{"type": "archery", "attack_bonus": 2, "requires_ranged": true}
	]},
	"paladin_lay_on_hands": {"effects": [
		{"type": "lay_on_hands", "pool": "level_times_five"}
	], "uses": 1, "uses_per": "rest", "action_cost": "action", "resource_formula": "level*5"},
	"paladin_divine_sense": {"effects": [
		{"type": "divine_sense", "duration": 2, "creature_types": ["celestial", "fiend", "undead"]}
	]},
	"bard_bardic_inspiration": {"effects": [
		{"type": "bardic_inspiration", "die": "1d6", "range": 12}
	]},
	"ranger_favored_foe": {"type": "passive", "effects": [
		{"type": "favored_foe", "base_dice": "1d4", "duration": 10}
	]},
	"barbarian_extra_attack": {"type": "passive", "effects": [{"type": "extra_attack", "count": 1}]},
	"ranger_extra_attack": {"type": "passive", "effects": [{"type": "extra_attack", "count": 1}]},
	"monk_extra_attack": {"type": "passive", "effects": [{"type": "extra_attack", "count": 1}]},
	"paladin_extra_attack": {"type": "passive", "effects": [{"type": "extra_attack", "count": 1}]},
	"rogue_sneak_attack": {"effects": [{"type": "sneak_attack", "dice": "1d6"}]},
	"rogue_uncanny_dodge": {"effects": [{"type": "reaction", "reaction": "uncanny_dodge"}]},
	"rogue_cunning_action": {"effects": [{"type": "cunning_action"}], "uses": 1, "uses_per": "turn", "action_cost": "bonus_action"},
	"wizard_arcane_recovery": {"effects": [{"type": "recover_spell_slots"}]},
	"cleric_channel_divinity:_harness_divine_power": {"effects": [{"type": "recover_spell_slots"}]},
	"warlock_pact_magic": {"type": "passive", "effects": [{"type": "pact_magic"}]},
	"warlock_magical_cunning": {"type": "active", "effects": [{"type": "pact_magic_recovery", "fraction": 0.5}], "uses": 1, "uses_per": "rest", "action_cost": "action"},
	"sorcerer_sorcery_points": {"type": "passive", "effects": [{"type": "sorcery_points"}]},
	"sorcerer_innate_sorcery": {"type": "active", "effects": [{"type": "innate_sorcery", "duration": 10}]},
	"sorcerer_metamagic": {"type": "passive", "effects": [{"type": "metamagic", "options": ["empowered_spell"]}]},
	"artificer_tinker's_magic": {"type": "active", "effects": [{"type": "give_item", "item_id": "ball_bearings"}]},
}

const CURATED_SPELL_EFFECTS := {
	"hunters_mark": {"concentration": true, "effects": [{
		"type": "hunters_mark", "dice": "1d6", "duration": 10
	}]},
}

const CURATED_MONSTER_TYPES := {
	"goblin": "humanoid",
	"goblin_chief": "humanoid",
	"skeleton": "undead",
	"zombie": "undead",
	"wight": "undead",
	"lich_king": "undead",
	"ooze": "ooze",
	"giant_spider": "beast",
}

const VALID_SPELL_CASTING_TIMES := ["action", "bonus_action", "reaction", "minute", "hour"]
const VALID_SPELL_TARGETS := ["self", "single", "single_ally", "multi", "area", "cone"]
const VALID_SPELL_SCHOOLS := ["abjuration", "conjuration", "divination", "enchantment", "evocation", "illusion", "necrotic", "transmutation"]
const VALID_DAMAGE_TYPES := ["acid", "bludgeoning", "cold", "fire", "force", "lightning", "necrotic", "piercing", "poison", "psychic", "radiant", "slashing", "thunder", "none"]
const VALID_ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const DICE_FIELDS := ["damage", "damage_per_dart", "healing", "hit_points", "versatile_damage", "dice"]

var _load_errors: Array[String] = []
var _validation_warnings: Array[String] = []
var _manifest: Dictionary = {}
var _registered_sources: Dictionary = {}


func _ready() -> void:
	load_all_data()


func load_all_data() -> void:
	_load_errors.clear()
	_validation_warnings.clear()
	_registered_sources.clear()
	for registry in [classes, races, items, spells, monsters, events, campaigns]:
		registry.clear()
	_manifest = _read_manifest()

	_load_directory(CORE_PATH)
	_load_directory(MODS_PATH)
	_populate_class_spell_access()
	_validate_cross_references()

	if not _validation_warnings.is_empty():
		push_warning("[DataLoader] Rejected %d unsupported effectless feature records; they remain unavailable until curated." % _validation_warnings.size())
	for err in _load_errors:
		push_error("[DataLoader] %s" % err)
		load_error.emit(err)

	print("[DataLoader] Loaded: %d classes, %d races, %d items, %d spells, %d monsters, %d event tables, %d campaigns" % [
		classes.size(), races.size(), items.size(), spells.size(), monsters.size(), events.size(), campaigns.size()
	])
	if OS.is_debug_build():
		print("[DataLoader] Layers: %s | packs: %s | approved overrides: %d | validation failures: %d" % [
			", ".join(get_content_layers()), ", ".join(get_content_pack_ids()), _manifest.get("overrides", []).size(), _load_errors.size()
		])
	if _load_errors.is_empty():
		data_loaded.emit()


func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_load_errors.append("Missing content manifest: %s" % MANIFEST_PATH)
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_load_errors.append("Cannot open content manifest: %s" % MANIFEST_PATH)
		return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK or not json.data is Dictionary:
		_load_errors.append("Invalid content manifest: %s" % MANIFEST_PATH)
		return {}
	var manifest: Dictionary = json.data
	if int(manifest.get("schema_version", 0)) != 1:
		_load_errors.append("Unsupported content manifest schema in %s" % MANIFEST_PATH)
		return {}
	_validate_manifest(manifest)
	return manifest


func _validate_manifest(manifest: Dictionary) -> void:
	var packs: Array = manifest.get("packs", [])
	if packs.is_empty():
		_load_errors.append("Content manifest must declare at least one content pack")
		return
	var pack_ids: Dictionary = {}
	for pack in packs:
		if not pack is Dictionary:
			_load_errors.append("Content manifest contains a non-object pack entry")
			continue
		var pack_id := str(pack.get("id", ""))
		if pack_id.is_empty() or str(pack.get("version", "")).is_empty() or str(pack.get("ruleset_compatibility", "")).is_empty():
			_load_errors.append("Content pack metadata requires id, version, and ruleset_compatibility")
			continue
		if pack_ids.has(pack_id):
			_load_errors.append("Duplicate content pack ID '%s'" % pack_id)
		else:
			pack_ids[pack_id] = true
	for pack in packs:
		if not pack is Dictionary:
			continue
		var pack_id := str(pack.get("id", ""))
		var dependencies: Array = pack.get("dependencies", [])
		if not dependencies is Array:
			_load_errors.append("Content pack '%s' dependencies must be an array" % pack_id)
			continue
		for dependency in dependencies:
			if str(dependency) == pack_id or not pack_ids.has(str(dependency)):
				_load_errors.append("Content pack '%s' has invalid dependency '%s'" % [pack_id, dependency])
	for layer in manifest.get("layers", []):
		if not layer is Dictionary:
			_load_errors.append("Content manifest contains a non-object layer entry")
			continue
		var layer_id := str(layer.get("id", ""))
		if layer_id.is_empty() or not layer.has("precedence") or str(layer.get("path", "")).is_empty() or not pack_ids.has(str(layer.get("pack_id", ""))):
			_load_errors.append("Content layer '%s' requires id, precedence, path, and a declared pack_id" % layer_id)


func _load_directory(base_path: String) -> void:
	_load_content_type(base_path + "classes/", "class")
	_load_content_type(base_path + "races/", "race")
	_load_content_type(base_path + "items/", "item")
	_load_content_type(base_path + "spells/", "spell")
	_load_content_type(base_path + "monsters/", "monster")
	_load_content_type(base_path + "events/", "event")
	_load_content_type(base_path + "campaigns/", "campaign")


func _load_content_type(dir_path: String, content_type: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_load_errors.append("Cannot open directory: %s" % dir_path)
		return
	var file_names: PackedStringArray = dir.get_files()
	file_names.sort()
	for file_name in file_names:
		if file_name.ends_with(".json"):
			_load_json_file(dir_path + file_name, content_type)


func _load_json_file(file_path: String, content_type: String) -> void:
	if not FileAccess.file_exists(file_path):
		_load_errors.append("File not found: %s" % file_path)
		return
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_load_errors.append("Cannot open file: %s" % file_path)
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		_load_errors.append("JSON parse error in %s line %d: %s" % [file_path, json.get_error_line(), json.get_error_message()])
		return
	if json.data is Dictionary:
		_register_content(json.data, content_type, "%s#1" % file_path)
	elif json.data is Array:
		var index := 0
		for entry in json.data:
			index += 1
			if entry is Dictionary:
				_register_content(entry, content_type, "%s#%d" % [file_path, index])
			else:
				_load_errors.append("Non-dictionary entry in array in %s" % file_path)
	else:
		_load_errors.append("Content root must be an object or array in %s" % file_path)


func _register_content(raw_data: Dictionary, content_type: String, source_path: String) -> void:
	var data := raw_data.duplicate(true)
	var id := str(data.get("id", data.get("table_id", "")))
	if id.is_empty():
		_load_errors.append("Missing 'id' or 'table_id' in %s" % source_path)
		return
	if not _validate_content(data, content_type, source_path):
		return
	data["_source"] = source_path.get_slice("#", 0)
	data["_source_record"] = source_path

	var existing_source := _source_for(content_type, id)
	if not existing_source.is_empty():
		var override := _find_override(content_type, id, existing_source, source_path)
		if override.is_empty():
			_load_errors.append("Unapproved duplicate %s ID '%s': %s conflicts with %s" % [content_type, id, source_path, existing_source])
			return
		var winner := str(override.get("winner", ""))
		var replaces: Array = override.get("replaces", [])
		if source_path == winner:
			data = _merge_missing_fields(data, _get_registry(content_type).get(id, {}))
			_set_registry(content_type, id, data)
			_set_source(content_type, id, source_path)
		elif source_path in replaces and existing_source == winner:
			return
		else:
			_load_errors.append("Invalid override manifest for %s ID '%s'" % [content_type, id])
		return
	else:
		_set_registry(content_type, id, data)
		_set_source(content_type, id, source_path)


func _validate_content(data: Dictionary, content_type: String, source: String) -> bool:
	var required: Array = ["id", "name"]
	match content_type:
		"class": required = ["id", "name", "hit_die", "primary_ability"]
		"race": required = ["id", "name"]
		"item": required = ["id", "name", "type"]
		"spell": required = ["id", "name", "level"]
		"monster": required = ["id", "name", "hit_points", "armor_class", "speed", "attacks", "ai_behavior"]
		"event": required = ["table_id"] if not data.has("id") else ["id"]
		"campaign": required = ["id", "name", "win_condition", "map", "dungeons"]
	for field in required:
		if not data.has(field):
			_load_errors.append("%s missing required field '%s' in %s" % [content_type.capitalize(), field, source])
			return false
	if content_type == "item" and str(data.get("type", "")) not in ["weapon", "armor", "shield", "consumable", "tool", "currency"]:
		_load_errors.append("Item has unsupported type '%s' in %s" % [data.get("type"), source])
		return false
	if content_type == "class":
		_curate_feature_effects(data)
		_sanitize_class_features(data, source)
	if content_type == "spell":
		_curate_spell_effects(data)
	if content_type == "monster":
		_curate_monster_data(data)
	if content_type == "spell" and int(data.get("level", -1)) < 0:
		_load_errors.append("Spell has invalid level in %s" % source)
		return false
	if not _validate_semantics(data, content_type, source):
		return false
	return true


func _validate_semantics(data: Dictionary, content_type: String, source: String) -> bool:
	var valid := true
	if content_type == "spell":
		valid = _validate_enum(data, "casting_time", VALID_SPELL_CASTING_TIMES, content_type, source) and valid
		valid = _validate_enum(data, "target", VALID_SPELL_TARGETS, content_type, source) and valid
		valid = _validate_enum(data, "school", VALID_SPELL_SCHOOLS, content_type, source) and valid
		var level := int(data.get("level", 0))
		if level < 0 or level > 9:
			_load_errors.append("Spell level must be between 0 and 9 in %s" % source)
			valid = false
	if data.has("damage_type") and str(data.get("damage_type")) not in VALID_DAMAGE_TYPES:
		_load_errors.append("Unsupported damage type '%s' in %s" % [data.get("damage_type"), source])
		valid = false
	if data.has("ability") and str(data.get("ability")) not in VALID_ABILITIES:
		_load_errors.append("Unsupported ability '%s' in %s" % [data.get("ability"), source])
		valid = false
	if data.has("range") and (not (data.get("range") is int or data.get("range") is float) or float(data.get("range")) < 0):
		_load_errors.append("Range must be a non-negative number in %s" % source)
		valid = false
	valid = _validate_nested_values(data, source) and valid
	return valid


func _validate_enum(data: Dictionary, field: String, allowed: Array, content_type: String, source: String) -> bool:
	if not data.has(field):
		return true
	if str(data.get(field)) in allowed:
		return true
	_load_errors.append("%s has unsupported %s '%s' in %s" % [content_type.capitalize(), field, data.get(field), source])
	return false


func _validate_nested_values(value, source: String) -> bool:
	var valid := true
	if value is Dictionary:
		for key in value:
			var child = value[key]
			if str(key) in DICE_FIELDS and child is String and not str(child).is_valid_float():
				var expression := str(child).replace(" ", "")
				var dice_pattern := RegEx.new()
				dice_pattern.compile("^[0-9]*[dD][0-9]+([+-]([0-9]+|[A-Za-z_][A-Za-z0-9_]*))?$")
				if dice_pattern.search(expression) == null:
					_load_errors.append("Invalid dice expression '%s' in %s" % [child, source])
					valid = false
			if str(key) in ["uses", "duration", "count", "max_targets", "dart_count"] and child is int and int(child) < 0:
				_load_errors.append("Numeric field '%s' cannot be negative in %s" % [key, source])
				valid = false
			valid = _validate_nested_values(child, source) and valid
	elif value is Array:
		for child in value:
			valid = _validate_nested_values(child, source) and valid
	return valid


func _sanitize_class_features(data: Dictionary, source: String) -> void:
	var by_level: Dictionary = data.get("features_by_level", {})
	var sanitized: Dictionary = {}
	for level_key in by_level:
		var kept: Array = []
		var raw_features = by_level[level_key]
		if not raw_features is Array:
			sanitized[str(level_key)] = kept
			continue
		for feature in raw_features:
			if not feature is Dictionary:
				continue
			var has_effects: bool = feature.get("effects", []) is Array and not feature.get("effects", []).is_empty()
			var has_resolver := not str(feature.get("resolver", "")).is_empty()
			if not has_effects and not has_resolver:
				_validation_warnings.append("Rejected unsupported effectless feature '%s' in %s" % [feature.get("id", ""), source])
				continue
			kept.append(feature)
		sanitized[str(level_key)] = kept
	data["features_by_level"] = sanitized


func _curate_feature_effects(data: Dictionary) -> void:
	var by_level: Dictionary = data.get("features_by_level", {})
	for level_key in by_level:
		var raw_features = by_level[level_key]
		if not raw_features is Array:
			continue
		for index in raw_features.size():
			var feature = raw_features[index]
			if not feature is Dictionary:
				continue
			var feature_id := str(feature.get("id", ""))
			if feature_id not in CURATED_FEATURE_EFFECTS or not feature.get("effects", []).is_empty():
				continue
			var curated: Dictionary = CURATED_FEATURE_EFFECTS[feature_id]
			feature.merge(curated, true)
			raw_features[index] = feature


func _curate_spell_effects(data: Dictionary) -> void:
	var spell_id := str(data.get("id", ""))
	if spell_id not in CURATED_SPELL_EFFECTS or not data.get("effects", []).is_empty():
		return
	data.merge(CURATED_SPELL_EFFECTS[spell_id], true)


func _curate_monster_data(data: Dictionary) -> void:
	var monster_id := str(data.get("id", ""))
	if monster_id in CURATED_MONSTER_TYPES and not data.has("creature_type"):
		data["creature_type"] = CURATED_MONSTER_TYPES[monster_id]


func _find_override(content_type: String, id: String, existing: String, candidate: String) -> Dictionary:
	for entry in _manifest.get("overrides", []):
		if entry is Dictionary and str(entry.get("type", "")) == content_type and str(entry.get("id", "")) == id:
			var sources: Array = entry.get("replaces", [])
			if str(entry.get("winner", "")) in [existing, candidate] and (existing in sources or candidate in sources):
				return entry
	return {}


func _merge_missing_fields(winner: Dictionary, fallback: Dictionary) -> Dictionary:
	var merged := winner.duplicate(true)
	for key in fallback:
		if key not in merged or key in ["_source", "_source_record"]:
			merged[key] = fallback[key]
	return merged


func _get_registry(content_type: String) -> Dictionary:
	match content_type:
		"class": return classes
		"race": return races
		"item": return items
		"spell": return spells
		"monster": return monsters
		"event": return events
		"campaign": return campaigns
	return {}


func _set_registry(content_type: String, id: String, data: Dictionary) -> void:
	_get_registry(content_type)[id] = data


func _source_for(content_type: String, id: String) -> String:
	return str(_registered_sources.get(content_type, {}).get(id, ""))


func _set_source(content_type: String, id: String, source: String) -> void:
	if not _registered_sources.has(content_type):
		_registered_sources[content_type] = {}
	_registered_sources[content_type][id] = source


func _populate_class_spell_access() -> void:
	for class_id in CURATED_SPELL_ACCESS:
		if not classes.has(class_id):
			continue
		var class_data: Dictionary = classes[class_id]
		var access: Dictionary = CURATED_SPELL_ACCESS[class_id]
		var known: Dictionary = {}
		for level_key in access:
			var ids: Array = access[level_key]
			if level_key == "0":
				class_data["cantrips_known"] = ids.duplicate()
			else:
				known[level_key] = ids.duplicate()
		class_data["spells_known_by_level"] = known
		if class_id == "warlock":
			class_data["pact_magic_by_level"] = CURATED_PACT_MAGIC.duplicate(true)


func _validate_cross_references() -> void:
	for class_id in classes:
		var class_data: Dictionary = classes[class_id]
		for level_key in class_data.get("spells_known_by_level", {}):
			for spell_id in class_data["spells_known_by_level"][level_key]:
				if not spells.has(str(spell_id)):
					_load_errors.append("Class '%s' references missing spell '%s'" % [class_id, spell_id])
		for spell_id in class_data.get("cantrips_known", []):
			if not spells.has(str(spell_id)):
				_load_errors.append("Class '%s' references missing cantrip '%s'" % [class_id, spell_id])

	for campaign_id in campaigns:
		var campaign: Dictionary = campaigns[campaign_id]
		for goal in campaign.get("win_condition", {}).get("goals", []):
			var goal_type := str(goal.get("type", ""))
			var goal_id := str(goal.get("item_id", goal.get("monster_id", "")))
			if goal_type == "collect_item" and not items.has(goal_id):
				_load_errors.append("Campaign '%s' references missing goal item '%s'" % [campaign_id, goal_id])
			if goal_type == "defeat_monster" and not monsters.has(goal_id):
				_load_errors.append("Campaign '%s' references missing goal monster '%s'" % [campaign_id, goal_id])
		for dungeon_id in campaign.get("dungeons", {}):
			var dungeon: Dictionary = campaign["dungeons"][dungeon_id]
			var boss_id := str(dungeon.get("boss", {}).get("monster_id", ""))
			if not monsters.has(boss_id):
				_load_errors.append("Campaign '%s' dungeon '%s' references missing boss '%s'" % [campaign_id, dungeon_id, boss_id])
			for monster_id in dungeon.get("monster_pool", []):
				if not monsters.has(str(monster_id)):
					_load_errors.append("Campaign '%s' dungeon '%s' references missing monster '%s'" % [campaign_id, dungeon_id, monster_id])
			for loot in dungeon.get("loot", []):
				var item_id := str(loot.get("item_id", ""))
				if not items.has(item_id):
					_load_errors.append("Campaign '%s' dungeon '%s' references missing loot '%s'" % [campaign_id, dungeon_id, item_id])
			var event_table := str(dungeon.get("event_table", ""))
			if not events.has(event_table):
				_load_errors.append("Campaign '%s' dungeon '%s' references missing event table '%s'" % [campaign_id, dungeon_id, event_table])

	for monster_id in monsters:
		var monster: Dictionary = monsters[monster_id]
		for loot in monster.get("loot_table", []):
			var loot_item_id := str(loot.get("item_id", ""))
			if not loot_item_id.is_empty() and not items.has(loot_item_id):
				_load_errors.append("Monster '%s' references missing loot item '%s'" % [monster_id, loot_item_id])

	for table_id in events:
		_validate_event_references(events[table_id], str(table_id))


func _validate_event_references(value, source: String) -> void:
	if value is Dictionary:
		if str(value.get("type", "")) == "give_item":
			var item_id := str(value.get("item_id", ""))
			if not item_id.is_empty() and not items.has(item_id):
				_load_errors.append("Event '%s' references missing item '%s'" % [source, item_id])
		if str(value.get("type", "")) == "start_combat":
			for monster_id in value.get("monsters", []):
				if not monsters.has(str(monster_id)):
					_load_errors.append("Event '%s' references missing combat monster '%s'" % [source, monster_id])
		for key in value:
			_validate_event_references(value[key], source)
	elif value is Array:
		for child in value:
			_validate_event_references(child, source)


func get_all_classes() -> Array:
	return _sorted_values(classes)

func get_character_class(id: String) -> Dictionary:
	return classes.get(id, {})

func get_all_races() -> Array:
	return _sorted_values(races)

func get_race(id: String) -> Dictionary:
	return races.get(id, {})

func get_all_items() -> Array:
	return _sorted_values(items)

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

func get_all_spells() -> Array:
	return _sorted_values(spells)

func get_spell(id: String) -> Dictionary:
	return spells.get(id, {})

func get_all_monsters() -> Array:
	return _sorted_values(monsters)

func get_monster(id: String) -> Dictionary:
	return monsters.get(id, {})

func get_event_table(table_id: String) -> Dictionary:
	return events.get(table_id, {})

func get_all_campaigns() -> Array:
	return _sorted_values(campaigns)

func get_campaign(id: String) -> Dictionary:
	return campaigns.get(id, {})

func get_load_errors() -> Array[String]:
	return _load_errors

func get_validation_warnings() -> Array[String]:
	return _validation_warnings


func get_content_layers() -> Array[String]:
	var layers: Array[String] = []
	for layer in _manifest.get("layers", []):
		if layer is Dictionary:
			layers.append(str(layer.get("id", "")))
	return layers


func get_content_pack_ids() -> Array[String]:
	var pack_ids: Array[String] = []
	for pack in _manifest.get("packs", []):
		if pack is Dictionary:
			pack_ids.append(str(pack.get("id", "")))
	return pack_ids

func get_registry_hash() -> String:
	var snapshot: Array = []
	for content_type in ["class", "race", "item", "spell", "monster", "event", "campaign"]:
		var registry := _get_registry(content_type)
		var ids: Array = registry.keys()
		ids.sort()
		for id in ids:
			snapshot.append({"type": content_type, "id": id, "data": registry[id]})
	return JSON.stringify(snapshot)

func _sorted_values(registry: Dictionary) -> Array:
	var ids: Array = registry.keys()
	ids.sort()
	var result: Array = []
	for id in ids:
		result.append(registry[id])
	return result

func reload() -> void:
	load_all_data()
