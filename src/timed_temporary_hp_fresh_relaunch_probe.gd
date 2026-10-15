extends Node

const SLOT := "timed_temporary_hp_fresh_relaunch"
const BAD_SLOT := "timed_temporary_hp_malformed"
const MANIFEST := "user://timed_temporary_hp_manifest.json"

var game_manager: Node
var data_loader: Node
var party_manager: Node
var save_manager: Node
var neutral: Dictionary
var renamed_feature: Dictionary


func _ready() -> void:
	game_manager = get_tree().get_root().get_node("GameManager")
	data_loader = get_tree().get_root().get_node("DataLoader")
	party_manager = get_tree().get_root().get_node("PartyManager")
	save_manager = get_tree().get_root().get_node("SaveManager")
	game_manager.test_mode = true
	data_loader._load_json_file("res://data/fixtures/shared_timed_temporary_hp.json", "class")
	var fixture_class: Dictionary = data_loader.get_character_class("fixture:timed_guard_class")
	neutral = fixture_class.get("features_by_level", {}).get("1", [{}])[0].duplicate(true)
	var renamed_class: Dictionary = fixture_class.duplicate(true)
	renamed_class["id"] = "fixture:timed_guard_class_renamed"
	renamed_class["name"] = "Fixture Timed Guard Renamed"
	renamed_feature = renamed_class["features_by_level"]["1"][0]
	renamed_feature["id"] = "fixture:timed_guard_renamed"
	renamed_feature["name"] = "Timed Guard Renamed"
	renamed_feature["resource_pool"]["id"] = "fixture:timed_guard_pool_renamed"
	renamed_feature["resource_pool"]["capacity_formula"] = 2
	renamed_feature["resource_pool"]["initial_quantity"] = 1
	renamed_feature["effects"][0]["amount"] = 16
	renamed_feature["effects"][0]["duration_seconds"] = 120
	data_loader._register_content(renamed_class, "class", "res://data/fixtures/shared_timed_temporary_hp.json#checkpoint-renamed")
	var phase := OS.get_environment("TIMED_TEMPORARY_HP_RELAUNCH_PHASE")
	if phase == "prepare":
		_prepare()
	elif phase == "recover":
		_recover()
	else:
		_fail("unknown fresh-relaunch phase: %s" % phase)


func _prepare() -> void:
	save_manager.delete_save(SLOT)
	save_manager.delete_save(BAD_SLOT)
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
	hero.features.append(neutral.duplicate(true))
	hero.features.append(renamed_feature.duplicate(true))
	var source_a := "fixture:timed_hp:fresh:neutral"
	var source_b := "fixture:timed_hp:fresh:renamed"
	var acquired_a := ResourcePoolRules.acquire(hero, neutral, source_a)
	var acquired_b := ResourcePoolRules.acquire(hero, renamed_feature, source_b)
	var activated_a := ClassFeature.execute(hero, neutral, null, null, source_a)
	if not acquired_a.get("success", false) or not acquired_b.get("success", false) or not activated_a.get("success", false) or hero.temp_hp != 10:
		_fail("neutral production activation did not create its source-owned amount")
		return
	hero.take_damage(4)
	game_manager.campaign_elapsed_seconds = 1010
	var activated_b := ClassFeature.execute(hero, renamed_feature, null, null, source_b)
	if not activated_b.get("success", false) or hero.temp_hp != 16 or hero.timed_temporary_hp_grants.size() != 2:
		_fail("renamed production activation did not replace the partially absorbed buffer")
		return
	var grants := hero.timed_temporary_hp_grants.duplicate(true)
	var current_pool_a: int = int(ResourcePoolRules.availability(hero, source_a).get("current", -1))
	var current_pool_b: int = int(ResourcePoolRules.availability(hero, source_b).get("current", -1))
	if not save_manager.get_save_block_reason().is_empty() or not save_manager.save_game(SLOT):
		_fail("allowed Overworld checkpoint refused timed Temporary HP state")
		return
	var manifest := {
		"owner_id": hero.character_id,
		"source_a": source_a,
		"source_b": source_b,
		"current_grant_id": hero.timed_temporary_hp_current_grant_id,
		"grant_serial": hero.timed_temporary_hp_grant_serial,
		"grants": grants,
		"remaining": hero.temp_hp,
		"campaign_elapsed_seconds": int(game_manager.campaign_elapsed_seconds),
		"pool_a": current_pool_a,
		"pool_b": current_pool_b,
	}
	var manifest_file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if manifest_file == null:
		_fail("could not write fresh-relaunch manifest")
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()
	print("TIMED TEMPORARY HP FRESH PREPARED: %s" % JSON.stringify(manifest))
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
	var hero: Character = party_manager.characters.get(owner_id)
	if hero == null or int(game_manager.campaign_elapsed_seconds) != int(manifest.get("campaign_elapsed_seconds", -1)):
		_fail("recovered owner or campaign clock differs from the prepared snapshot")
		return
	var expected_grants: Array = manifest.get("grants", [])
	if hero.timed_temporary_hp_grants != expected_grants or hero.timed_temporary_hp_grant_serial != int(manifest.get("grant_serial", -1)) or hero.timed_temporary_hp_current_grant_id != str(manifest.get("current_grant_id", "")) or hero.temp_hp != int(manifest.get("remaining", -1)):
		_fail("fresh process changed grant provenance, remaining amount, serial or deadline")
		return
	if not Character.saved_timed_temporary_hp_error(hero.to_dict(), int(game_manager.campaign_elapsed_seconds)).is_empty():
		_fail("recovered grant state fails production validation")
		return
	if int(ResourcePoolRules.availability(hero, source_a).get("current", -1)) != int(manifest.get("pool_a", -2)) or int(ResourcePoolRules.availability(hero, source_b).get("current", -1)) != int(manifest.get("pool_b", -2)):
		_fail("checkpoint recovery replayed either pool payment")
		return
	var live_hero := hero
	var live_grants := hero.timed_temporary_hp_grants.duplicate(true)
	var live_current := hero.timed_temporary_hp_current_grant_id
	var live_remaining := hero.temp_hp
	var live_clock := int(game_manager.campaign_elapsed_seconds)
	var saved_text := FileAccess.get_file_as_string(save_manager.SAVE_DIR + "%s.sav" % SLOT)
	var saved: Dictionary = JSON.parse_string(saved_text)
	var saved_character: Dictionary = saved.get("party", {}).get("characters", {}).get(owner_id, {})

	var missing_deadline: Dictionary = saved.duplicate(true)
	var deadline_character: Dictionary = missing_deadline.get("party", {}).get("characters", {}).get(owner_id, {})
	var deadline_grants: Array = deadline_character.get("timed_temporary_hp_grants", [])
	for grant in deadline_grants:
		if str(grant.get("grant_instance_id", "")) == live_current:
			grant.erase("expires_at_seconds")
			break
	if not _write_bad_save(missing_deadline):
		_fail("could not write missing-deadline save")
		return
	if not _refused_without_replacing(hero, live_hero, live_grants, live_current, live_remaining, live_clock, "missing grant deadline"):
		return

	var missing_field: Dictionary = saved.duplicate(true)
	var field_character: Dictionary = missing_field.get("party", {}).get("characters", {}).get(owner_id, {})
	field_character.erase("timed_temporary_hp_current_grant_id")
	if not _write_bad_save(missing_field):
		_fail("could not write missing-provenance-field save")
		return
	if not _refused_without_replacing(hero, live_hero, live_grants, live_current, live_remaining, live_clock, "missing provenance field"):
		return

	var orphaned: Dictionary = saved.duplicate(true)
	var orphan_character: Dictionary = orphaned.get("party", {}).get("characters", {}).get(owner_id, {})
	var pools: Dictionary = orphan_character.get("numeric_resource_pools", {})
	pools.erase(source_b)
	if not _write_bad_save(orphaned):
		_fail("could not write orphan-source save")
		return
	if not _refused_without_replacing(hero, live_hero, live_grants, live_current, live_remaining, live_clock, "orphan source pool"):
		return

	var deadline_a := int(expected_grants[0].get("expires_at_seconds", 0))
	var current_deadline := 0
	for grant in expected_grants:
		if str(grant.get("grant_instance_id", "")) == live_current:
			current_deadline = int(grant.get("expires_at_seconds", 0))
	if deadline_a != 1060 or current_deadline != 1130:
		_fail("captured neutral and renamed deadlines are incorrect")
		return
	game_manager.advance_campaign_time(deadline_a - live_clock)
	if hero.temp_hp != 16 or hero.timed_temporary_hp_current_grant_id != live_current or hero.timed_temporary_hp_grants.size() != 1:
		_fail("expiry of the older non-current grant erased or reset the newer buffer")
		return
	game_manager.advance_campaign_time(current_deadline - int(game_manager.campaign_elapsed_seconds))
	if hero.temp_hp != 0 or not hero.timed_temporary_hp_current_grant_id.is_empty() or not hero.timed_temporary_hp_grants.is_empty():
		_fail("current timed Temporary HP did not clear at its original absolute deadline")
		return
	game_manager.advance_campaign_time(3600)
	if hero.temp_hp != 0:
		_fail("depleted or expired Temporary HP reappeared after a large time jump")
		return
	save_manager.delete_save(SLOT)
	save_manager.delete_save(BAD_SLOT)
	if FileAccess.file_exists(MANIFEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST))
	print("TIMED TEMPORARY HP FRESH RELAUNCH PASSED: provenance, remaining amount, malformed refusal and captured deadlines")
	get_tree().quit()


func _write_bad_save(data: Dictionary) -> bool:
	var file := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % BAD_SLOT, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func _refused_without_replacing(hero: Character, live_hero: Character, grants: Array, current_id: String, remaining: int, clock: int, label: String) -> bool:
	var refused: bool = not save_manager.load_game(BAD_SLOT)
	if not refused or party_manager.characters.get(hero.character_id) != live_hero or hero.timed_temporary_hp_grants != grants or hero.timed_temporary_hp_current_grant_id != current_id or hero.temp_hp != remaining or int(game_manager.campaign_elapsed_seconds) != clock:
		_fail("%s full save was accepted or replaced the live session before refusal" % label)
		return false
	return true


func _fail(message: String) -> void:
	push_error("[TimedTemporaryHPFreshRelaunchProbe] %s" % message)
	get_tree().quit(1)
