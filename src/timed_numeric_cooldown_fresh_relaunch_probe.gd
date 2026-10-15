extends Node

const SLOT := "timed_numeric_cooldown_fresh_relaunch"
const BAD_SLOT := "timed_numeric_cooldown_malformed"
const BAD_ACTIVE_SOURCE_SLOT := "timed_numeric_cooldown_missing_active_source"
const BAD_COOLDOWN_SOURCE_SLOT := "timed_numeric_cooldown_missing_cooldown_source"
const BAD_DEADLINE_SLOT := "timed_numeric_cooldown_missing_deadline"
const MANIFEST := "user://timed_numeric_cooldown_manifest.json"

var game_manager: Node
var data_loader: Node
var party_manager: Node
var save_manager: Node


func _ready() -> void:
	game_manager = get_tree().get_root().get_node("GameManager")
	data_loader = get_tree().get_root().get_node("DataLoader")
	party_manager = get_tree().get_root().get_node("PartyManager")
	save_manager = get_tree().get_root().get_node("SaveManager")
	game_manager.test_mode = true
	data_loader._load_json_file("res://data/fixtures/shared_timed_numeric_cooldown.json", "class")
	var phase := OS.get_environment("TIMED_NUMERIC_COOLDOWN_RELAUNCH_PHASE")
	if phase == "prepare":
		_prepare()
	elif phase == "recover":
		_recover()
	else:
		_fail("unknown fresh-relaunch phase: %s" % phase)


func _prepare() -> void:
	save_manager.delete_save(SLOT)
	save_manager.delete_save(BAD_SLOT)
	save_manager.delete_save(BAD_ACTIVE_SOURCE_SLOT)
	save_manager.delete_save(BAD_COOLDOWN_SOURCE_SLOT)
	save_manager.delete_save(BAD_DEADLINE_SLOT)
	var fixture_text := FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json")
	var file := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % SLOT, FileAccess.WRITE)
	if fixture_text.is_empty() or file == null:
		_fail("could not stage the repository's allowed-checkpoint fixture")
		return
	file.store_string(fixture_text)
	file.close()
	if not save_manager.load_game(SLOT):
		_fail("base allowed-checkpoint fixture did not load")
		return
	game_manager.current_state = GameManager.GameState.OVERWORLD
	game_manager.game_in_progress = true
	game_manager.active_dungeon_state.clear()
	game_manager.campaign_elapsed_seconds = 1000
	var active_party: Array = party_manager.get_active_characters()
	if active_party.is_empty():
		_fail("base fixture did not restore an active character")
		return
	var hero: Character = active_party[0]
	var class_def: Dictionary = data_loader.get_character_class("fixture:campaign_guard_cooldown_class")
	var neutral: Dictionary = class_def.get("features_by_level", {}).get("1", [{}])[0].duplicate(true)
	var renamed: Dictionary = neutral.duplicate(true)
	var renamed_effect: Dictionary = renamed["effects"][0]
	var renamed_pool: Dictionary = renamed["resource_pool"]
	renamed["id"] = "fixture:campaign_guard_cooldown_fresh_renamed"
	renamed["name"] = "Fresh Renamed Guard"
	renamed_pool["id"] = "fixture:campaign_guard_cooldown_fresh_renamed_pool"
	renamed_pool["initial_quantity"] = 1
	renamed_effect["amount"] = 3
	renamed_effect["duration_seconds"] = 120
	renamed_effect["cooldown_seconds"] = 7200
	if class_def.is_empty() or ClassFeature.content_error(neutral).is_empty() == false or ClassFeature.content_error(renamed).is_empty() == false:
		_fail("neutral or renamed cooldown definition failed production validation")
		return
	var source_a := "fixture:timed_cooldown:fresh_active"
	var source_b := "fixture:timed_cooldown:fresh_cooldown_only"
	hero.features.append_array([neutral.duplicate(true), renamed.duplicate(true)])
	var acquired_a := ResourcePoolRules.acquire(hero, neutral, source_a)
	var acquired_b := ResourcePoolRules.acquire(hero, renamed, source_b)
	var baseline_ac := hero.get_modifier("stat", "AC")
	var activated_a := ClassFeature.execute(hero, neutral, null, null, source_a)
	var activated_b := ClassFeature.execute(hero, renamed, null, null, source_b)
	var grant_a: Dictionary = _grant_for_source(hero, source_a)
	var grant_b: Dictionary = _grant_for_source(hero, source_b)
	game_manager.advance_campaign_time(20)
	var dismissed_b := hero.dismiss_campaign_modifier(source_b, str(grant_b.get("grant_instance_id", "")), int(game_manager.campaign_elapsed_seconds))
	var cooldown_b := _cooldown_for_grant(hero, str(grant_b.get("grant_instance_id", "")))
	if not acquired_a.get("success", false) or not acquired_b.get("success", false) or not activated_a.get("success", false) or not activated_b.get("success", false) or grant_a.is_empty() or grant_b.is_empty() or not dismissed_b.get("success", false) or cooldown_b.is_empty():
		_fail("production activation/dismissal did not stage active and cooldown-only state")
		return
	if not save_manager.save_game(SLOT):
		_fail("allowed Overworld checkpoint did not save active/cooldown-only state")
		return
	var manifest := {
		"owner_id": hero.character_id,
		"source_a": source_a,
		"source_b": source_b,
		"grant_a": grant_a.duplicate(true),
		"grant_b": grant_b.duplicate(true),
		"cooldown_b": cooldown_b.duplicate(true),
		"pool_a": ResourcePoolRules.availability(hero, source_a).duplicate(true),
		"pool_b": ResourcePoolRules.availability(hero, source_b).duplicate(true),
		"baseline_ac": baseline_ac,
		"campaign_seconds": int(game_manager.campaign_elapsed_seconds),
		"grant_serial": hero.timed_modifier_grant_serial,
	}
	var manifest_file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if manifest_file == null:
		_fail("could not write fresh-relaunch manifest")
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()
	print("TIMED NUMERIC COOLDOWN FRESH PREPARED: %s" % JSON.stringify(manifest))
	get_tree().quit()


func _recover() -> void:
	if not FileAccess.file_exists(MANIFEST):
		_fail("fresh-relaunch manifest missing")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary:
		_fail("fresh-relaunch manifest is invalid")
		return
	var manifest: Dictionary = parsed
	if not save_manager.load_game(SLOT):
		_fail("fresh process could not recover the prepared allowed checkpoint")
		return
	var owner_id := str(manifest.get("owner_id", ""))
	var source_a := str(manifest.get("source_a", ""))
	var source_b := str(manifest.get("source_b", ""))
	var expected_a: Dictionary = manifest.get("grant_a", {})
	var expected_b: Dictionary = manifest.get("grant_b", {})
	var expected_cooldown_b: Dictionary = manifest.get("cooldown_b", {})
	var hero: Character = party_manager.characters.get(owner_id)
	if hero == null or int(game_manager.campaign_elapsed_seconds) != int(manifest.get("campaign_seconds", -1)):
		_fail("recovered owner or campaign clock does not match the manifest")
		return
	var grant_a := _grant_for_source(hero, source_a)
	var grant_b := _grant_for_source(hero, source_b)
	var cooldown_b := _cooldown_for_grant(hero, str(expected_cooldown_b.get("grant_instance_id", "")))
	if not grant_a == expected_a or not grant_b.is_empty() or not cooldown_b == expected_cooldown_b:
		_fail("fresh recovery changed the active grant or cooldown-only identity/payload/deadline")
		return
	var actual_pool_a: Dictionary = ResourcePoolRules.availability(hero, source_a)
	var actual_pool_b: Dictionary = ResourcePoolRules.availability(hero, source_b)
	if hero.timed_modifier_grant_serial != int(manifest.get("grant_serial", -1)) or not _same_pool(actual_pool_a, manifest.get("pool_a", {})) or not _same_pool(actual_pool_b, manifest.get("pool_b", {})):
		_fail("recovery replayed activation or changed durable serial/pool quantities")
		return
	var baseline_ac := int(manifest.get("baseline_ac", 0))
	if hero.get_modifier("stat", "AC") != baseline_ac + 2:
		_fail("recovered active grant's AC contribution is missing")
		return

	# Malformed full save preflight must leave this recovered live session intact.
	var base_text := FileAccess.get_file_as_string(save_manager.SAVE_DIR + "%s.sav" % SLOT)
	var bad: Dictionary = JSON.parse_string(base_text)
	var saved_owner: Dictionary = bad.get("party", {}).get("characters", {}).get(owner_id, {})
	var saved_cooldowns: Array = saved_owner.get("campaign_modifier_cooldowns", [])
	var corrupted := false
	for cooldown in saved_cooldowns:
		if cooldown is Dictionary and str(cooldown.get("grant_instance_id", "")) == str(expected_cooldown_b.get("grant_instance_id", "")):
			cooldown["ready_at_seconds"] = int(cooldown.get("ready_at_seconds", 0)) + 1
			corrupted = true
			break
	if not corrupted:
		_fail("could not corrupt the persisted cooldown record")
		return
	var clock_before := int(game_manager.campaign_elapsed_seconds)
	var modifiers_before := hero.modifiers.duplicate(true)
	var cooldowns_before := hero.campaign_modifier_cooldowns.duplicate(true)
	if not _assert_malformed_save_refused(BAD_SLOT, bad, owner_id, hero, clock_before, modifiers_before, cooldowns_before):
		_fail("mismatched cooldown deadline save was accepted or replaced the live session")
		return
	var missing_active_pool := _mutated_save(base_text, owner_id, str(manifest.get("source_a", "")), "missing_pool", str(expected_a.get("grant_instance_id", "")))
	if not _assert_malformed_save_refused(BAD_ACTIVE_SOURCE_SLOT, missing_active_pool, owner_id, hero, clock_before, modifiers_before, cooldowns_before):
		_fail("active timed grant with no matching pool source was accepted or replaced the live session")
		return
	var missing_cooldown_pool := _mutated_save(base_text, owner_id, str(manifest.get("source_b", "")), "missing_pool", str(expected_cooldown_b.get("grant_instance_id", "")))
	if not _assert_malformed_save_refused(BAD_COOLDOWN_SOURCE_SLOT, missing_cooldown_pool, owner_id, hero, clock_before, modifiers_before, cooldowns_before):
		_fail("cooldown-only state with no matching pool source was accepted or replaced the live session")
		return
	var missing_active_deadline := _mutated_save(base_text, owner_id, str(manifest.get("source_a", "")), "missing_deadline", str(expected_a.get("grant_instance_id", "")))
	if not _assert_malformed_save_refused(BAD_DEADLINE_SLOT, missing_active_deadline, owner_id, hero, clock_before, modifiers_before, cooldowns_before):
		_fail("tagged timed grant with no absolute deadline was accepted or replaced the live session")
		return

	game_manager.advance_campaign_time(39)
	if hero.get_modifier("stat", "AC") != baseline_ac + 2 or not hero.has_campaign_modifier_grant(source_a, str(expected_a.get("grant_instance_id", "")), 1059):
		_fail("recovered active benefit did not remain through one second before deadline")
		return
	game_manager.advance_campaign_time(1)
	var cooldown_a := _cooldown_for_grant(hero, str(expected_a.get("grant_instance_id", "")))
	if hero.get_modifier("stat", "AC") != baseline_ac or int(cooldown_a.get("started_at_seconds", -1)) != 1060 or int(cooldown_a.get("ready_at_seconds", -1)) != 4660 or int(cooldown_b.get("ready_at_seconds", -1)) != 8220 or hero.timed_modifier_grant_serial != int(manifest.get("grant_serial", -1)):
		_fail("original active deadline did not expire without replay or alter the saved cooldown-only grant")
		return
	game_manager.advance_campaign_time(1)
	if hero.get_modifier("stat", "AC") != baseline_ac:
		_fail("expired active benefit reappeared after recovery")
		return
	save_manager.delete_save(SLOT)
	save_manager.delete_save(BAD_SLOT)
	save_manager.delete_save(BAD_ACTIVE_SOURCE_SLOT)
	save_manager.delete_save(BAD_COOLDOWN_SOURCE_SLOT)
	save_manager.delete_save(BAD_DEADLINE_SLOT)
	if FileAccess.file_exists(MANIFEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST))
	print("TIMED NUMERIC COOLDOWN FRESH RELAUNCH PASSED: active/cooldown-only identity, malformed refusal, and no replay")
	get_tree().quit()


func _grant_for_source(hero: Character, source_id: String) -> Dictionary:
	for modifier in hero.modifiers:
		if str(modifier.get("source_instance_id", "")) == source_id and modifier.has("grant_instance_id"):
			return modifier.duplicate(true)
	return {}


func _cooldown_for_grant(hero: Character, grant_id: String) -> Dictionary:
	for cooldown in hero.campaign_modifier_cooldowns:
		if str(cooldown.get("grant_instance_id", "")) == grant_id:
			return cooldown.duplicate(true)
	return {}


func _same_pool(actual: Dictionary, expected: Dictionary) -> bool:
	return bool(actual.get("available", false)) == bool(expected.get("available", false)) and int(actual.get("current", -1)) == int(expected.get("current", -2)) and int(actual.get("capacity", -1)) == int(expected.get("capacity", -2)) and str(actual.get("owner_id", "")) == str(expected.get("owner_id", "")) and str(actual.get("source_instance_id", "")) == str(expected.get("source_instance_id", ""))


func _mutated_save(base_text: String, owner_id: String, source_id: String, mutation: String, grant_id: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(base_text)
	if not parsed is Dictionary:
		return {}
	var saved_owner: Dictionary = parsed.get("party", {}).get("characters", {}).get(owner_id, {})
	if mutation == "missing_pool":
		var pools: Dictionary = saved_owner.get("numeric_resource_pools", {})
		pools.erase(source_id)
	elif mutation == "missing_deadline":
		var modifiers: Array = saved_owner.get("modifiers", [])
		for modifier in modifiers:
			if modifier is Dictionary and str(modifier.get("grant_instance_id", "")) == grant_id:
				modifier.erase("expires_at_seconds")
				return parsed
		return {}
	return parsed


func _assert_malformed_save_refused(slot: String, malformed: Dictionary, owner_id: String, hero: Character, clock_before: int, modifiers_before: Array, cooldowns_before: Array) -> bool:
	if malformed.is_empty():
		return false
	var bad_file := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % slot, FileAccess.WRITE)
	if bad_file == null:
		return false
	bad_file.store_string(JSON.stringify(malformed, "\t"))
	bad_file.close()
	var refused: bool = not save_manager.load_game(slot)
	var session_intact: bool = refused and party_manager.characters.get(owner_id) == hero and int(game_manager.campaign_elapsed_seconds) == clock_before and hero.modifiers == modifiers_before and hero.campaign_modifier_cooldowns == cooldowns_before
	save_manager.delete_save(slot)
	return session_intact


func _fail(message: String) -> void:
	push_error("[TimedNumericCooldownFreshRelaunchProbe] %s" % message)
	get_tree().quit(1)
