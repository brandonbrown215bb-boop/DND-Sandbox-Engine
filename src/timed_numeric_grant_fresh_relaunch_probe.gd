extends Node

const SLOT := "timed_numeric_grant_fresh_relaunch"
const BAD_SLOT := "timed_numeric_grant_malformed"
const MANIFEST := "user://timed_numeric_grant_manifest.json"

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
	data_loader._load_json_file("res://data/fixtures/shared_timed_numeric_grant.json", "class")
	var phase := OS.get_environment("TIMED_NUMERIC_GRANT_RELAUNCH_PHASE")
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
	var class_def: Dictionary = data_loader.get_character_class("fixture:campaign_guard_class")
	var feature: Dictionary = class_def.get("features_by_level", {}).get("1", [{}])[0].duplicate(true)
	var source_id := "fixture:campaign_guard:fresh_process"
	hero.features.append(feature.duplicate(true))
	var acquired := ResourcePoolRules.acquire(hero, feature, source_id)
	var base_modifier := hero.get_modifier("stat", "AC")
	var activated := ClassFeature.execute(hero, feature, null, null, source_id)
	var grant: Dictionary = {}
	for modifier in hero.modifiers:
		if str(modifier.get("source_instance_id", "")) == source_id and modifier.has("grant_instance_id"):
			grant = modifier.duplicate(true)
			break
	if not acquired.get("success", false) or not activated.get("success", false) or grant.is_empty() or int(grant.get("expires_at_seconds", -1)) != 1060:
		_fail("production activation did not create the expected exact-source +2 AC grant")
		return
	if not save_manager.save_game(SLOT):
		_fail("allowed Overworld checkpoint did not save the timed grant")
		return
	var manifest := {
		"owner_id": hero.character_id,
		"source_instance_id": source_id,
		"grant_instance_id": str(grant.get("grant_instance_id", "")),
		"amount": int(grant.get("amount", 0)),
		"base_modifier": base_modifier,
		"expires_at_seconds": int(grant.get("expires_at_seconds", -1)),
		"campaign_elapsed_seconds": int(game_manager.campaign_elapsed_seconds),
		"grant_serial": int(hero.timed_modifier_grant_serial),
		"pool_current": int(ResourcePoolRules.availability(hero, source_id).get("current", -1)),
	}
	var manifest_file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if manifest_file == null:
		_fail("could not write fresh-relaunch manifest")
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()
	print("TIMED NUMERIC GRANT FRESH PREPARED: %s" % JSON.stringify(manifest))
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
	var source_id := str(manifest.get("source_instance_id", ""))
	var hero: Character = party_manager.characters.get(owner_id)
	if hero == null or int(game_manager.campaign_elapsed_seconds) != int(manifest.get("campaign_elapsed_seconds", -1)):
		_fail("recovered owner or campaign clock does not match the manifest")
		return
	var grants: Array = hero.modifiers.filter(func(m): return str(m.get("source_instance_id", "")) == source_id and m.has("grant_instance_id"))
	var grant: Dictionary = grants[0] if grants.size() == 1 else {}
	var pool: Dictionary = hero.numeric_resource_pools.get(source_id, {})
	if str(grant.get("owner_id", "")) != owner_id or str(grant.get("source_instance_id", "")) != source_id or str(grant.get("grant_instance_id", "")) != str(manifest.get("grant_instance_id", "")) or int(grant.get("amount", 0)) != int(manifest.get("amount", 0)) or int(grant.get("expires_at_seconds", -1)) != int(manifest.get("expires_at_seconds", -2)):
		_fail("recovered timed grant owner/source/identity/payload/deadline changed")
		return
	if hero.timed_modifier_grant_serial != int(manifest.get("grant_serial", -1)) or int(pool.get("current", -1)) != int(manifest.get("pool_current", -2)):
		_fail("recovery replayed activation or changed the durable grant serial/pool count")
		return
	var base_modifier := int(manifest.get("base_modifier", 0))
	if hero.get_modifier("stat", "AC") != base_modifier + 2:
		_fail("recovered +2 AC contribution is missing or has restarted incorrectly")
		return

	# A malformed full save must fail SaveManager preflight without replacing this live session.
	var base_text := FileAccess.get_file_as_string(save_manager.SAVE_DIR + "%s.sav" % SLOT)
	var bad: Dictionary = JSON.parse_string(base_text)
	var saved_owner_data: Dictionary = bad.get("party", {}).get("characters", {}).get(owner_id, {})
	var saved_modifiers: Array = saved_owner_data.get("modifiers", [])
	var corrupted := false
	for modifier in saved_modifiers:
		if modifier is Dictionary and str(modifier.get("grant_instance_id", "")) == str(manifest.get("grant_instance_id", "")):
			modifier["owner_id"] = "fixture:wrong_owner"
			corrupted = true
			break
	if not corrupted:
		_fail("could not corrupt the persisted grant for malformed-save check")
		return
	var bad_file := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % BAD_SLOT, FileAccess.WRITE)
	if bad_file == null:
		_fail("could not write malformed save slot")
		return
	bad_file.store_string(JSON.stringify(bad, "\t"))
	bad_file.close()
	var clock_before := int(game_manager.campaign_elapsed_seconds)
	var refused: bool = not save_manager.load_game(BAD_SLOT)
	if not refused or party_manager.characters.get(owner_id) != hero or int(game_manager.campaign_elapsed_seconds) != clock_before or hero.get_modifier("stat", "AC") != base_modifier + 2:
		_fail("malformed grant save was accepted or mutated the live recovered session")
		return

	game_manager.advance_campaign_time(59)
	if hero.get_modifier("stat", "AC") != base_modifier + 2:
		_fail("fresh-process grant expired or restarted before the exact deadline")
		return
	game_manager.advance_campaign_time(1)
	if hero.get_modifier("stat", "AC") != base_modifier or hero.has_campaign_modifier_source(source_id):
		_fail("fresh-process grant did not expire at its original absolute deadline")
		return
	game_manager.advance_campaign_time(1)
	if hero.get_modifier("stat", "AC") != base_modifier:
		_fail("expired grant reappeared after the deadline")
		return
	save_manager.delete_save(SLOT)
	save_manager.delete_save(BAD_SLOT)
	if FileAccess.file_exists(MANIFEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST))
	print("TIMED NUMERIC GRANT FRESH RELAUNCH PASSED: deadline identity, malformed refusal, and no activation replay")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("[TimedNumericGrantFreshRelaunchProbe] %s" % message)
	get_tree().quit(1)
