extends Node

const SLOT := "next_melee_hit_grant_fresh_relaunch"
const BAD_SLOT := "next_melee_hit_grant_malformed"
const MANIFEST := "user://next_melee_hit_grant_manifest.json"

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
	data_loader._load_json_file("res://data/fixtures/shared_next_melee_hit_grant.json", "class")
	var fixture_class: Dictionary = data_loader.get_character_class("fixture:flame_on_edge_class")
	neutral = fixture_class.get("features_by_level", {}).get("1", [{}])[0].duplicate(true)
	var renamed_class := fixture_class.duplicate(true)
	renamed_class["id"] = "fixture:flame_on_edge_class_renamed"
	renamed_class["name"] = "Fixture Flame on the Edge Renamed"
	renamed_feature = renamed_class["features_by_level"]["1"][0]
	renamed_feature["id"] = "fixture:flame_on_edge_renamed"
	renamed_feature["name"] = "Flame on the Edge Renamed"
	renamed_feature["resource_pool"]["id"] = "fixture:flame_on_edge_pool_renamed"
	renamed_feature["effects"][0]["amount"] = 3
	renamed_feature["effects"][0]["damage_type"] = "cold"
	renamed_feature["effects"][0]["duration_seconds"] = 3600
	data_loader._register_content(renamed_class, "class", "res://data/fixtures/shared_next_melee_hit_grant.json#checkpoint-renamed")
	var phase := OS.get_environment("NEXT_MELEE_HIT_GRANT_RELAUNCH_PHASE")
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
	var source_a := "fixture:next_hit:fresh:neutral"
	var source_b := "fixture:next_hit:fresh:renamed"
	var acquire_a := ResourcePoolRules.acquire(hero, neutral, source_a)
	var acquire_b := ResourcePoolRules.acquire(hero, renamed_feature, source_b)
	var activate_a := ClassFeature.execute(hero, neutral, null, null, source_a)
	game_manager.campaign_elapsed_seconds = 1010
	var activate_b := ClassFeature.execute(hero, renamed_feature, null, null, source_b)
	var grants := hero.next_weapon_hit_grants.duplicate(true)
	if not acquire_a.get("success", false) or not acquire_b.get("success", false) or not activate_a.get("success", false) or not activate_b.get("success", false) or grants.size() != 2:
		_fail("production activation did not prepare two pending typed next-hit grants")
		return
	if not save_manager.get_save_block_reason().is_empty() or not save_manager.save_game(SLOT):
		_fail("allowed Overworld checkpoint refused the pending grant state")
		return
	var manifest := {
		"owner_id": hero.character_id,
		"source_a": source_a,
		"source_b": source_b,
		"grants": grants,
		"grant_serial": hero.next_weapon_hit_grant_serial,
		"campaign_elapsed_seconds": int(game_manager.campaign_elapsed_seconds),
		"pool_a": ResourcePoolRules.availability(hero, source_a),
		"pool_b": ResourcePoolRules.availability(hero, source_b),
	}
	var manifest_file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if manifest_file == null:
		_fail("could not write fresh-relaunch manifest")
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()
	print("NEXT MELEE HIT GRANT FRESH PREPARED: %s" % JSON.stringify(manifest))
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
	var hero: Character = party_manager.characters.get(owner_id)
	var expected_grants: Array = manifest.get("grants", [])
	if hero == null or hero.next_weapon_hit_grants != expected_grants or hero.next_weapon_hit_grant_serial != int(manifest.get("grant_serial", -1)) or int(game_manager.campaign_elapsed_seconds) != int(manifest.get("campaign_elapsed_seconds", -1)):
		_fail("fresh recovery changed grant identity/order/payload/deadline, serial or campaign clock")
		return
	if not Character.saved_next_weapon_hit_grants_error(hero.to_dict(), int(game_manager.campaign_elapsed_seconds)).is_empty():
		_fail("recovered grants fail production Character state validation")
		return
	var source_a := str(manifest.get("source_a", ""))
	var source_b := str(manifest.get("source_b", ""))
	var pool_a: Dictionary = ResourcePoolRules.availability(hero, source_a)
	var pool_b: Dictionary = ResourcePoolRules.availability(hero, source_b)
	var expected_pool_a: Dictionary = manifest.get("pool_a", {})
	var expected_pool_b: Dictionary = manifest.get("pool_b", {})
	if int(pool_a.get("current", -1)) != int(expected_pool_a.get("current", -2)) or int(pool_a.get("capacity", -1)) != int(expected_pool_a.get("capacity", -2)) or int(pool_b.get("current", -1)) != int(expected_pool_b.get("current", -2)) or int(pool_b.get("capacity", -1)) != int(expected_pool_b.get("capacity", -2)):
		_fail("recovery replayed payment or changed either pool")
		return
	var live_grants := hero.next_weapon_hit_grants.duplicate(true)
	var live_owner := hero
	var live_clock := int(game_manager.campaign_elapsed_seconds)
	var base_text := FileAccess.get_file_as_string(save_manager.SAVE_DIR + "%s.sav" % SLOT)
	var malformed: Dictionary = JSON.parse_string(base_text)
	var saved_owner: Dictionary = malformed.get("party", {}).get("characters", {}).get(owner_id, {})
	var saved_grants: Array = saved_owner.get("next_weapon_hit_grants", [])
	if saved_grants.is_empty():
		_fail("saved character payload did not contain pending grants")
		return
	saved_grants[0]["amount"] = 101
	var bad_file := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % BAD_SLOT, FileAccess.WRITE)
	if bad_file == null:
		_fail("could not write malformed full save slot")
		return
	bad_file.store_string(JSON.stringify(malformed, "\t"))
	bad_file.close()
	if save_manager.load_game(BAD_SLOT) or party_manager.characters.get(owner_id) != live_owner or hero.next_weapon_hit_grants != live_grants or int(game_manager.campaign_elapsed_seconds) != live_clock:
		_fail("malformed grant full-save was accepted or replaced the live session before refusal")
		return
	var first_deadline := int(expected_grants[0].get("expires_at_seconds", 0))
	var second_deadline := int(expected_grants[1].get("expires_at_seconds", 0))
	if first_deadline != 1060 or second_deadline != 4610:
		_fail("neutral and renamed deadlines do not match their distinct authored durations")
		return
	game_manager.advance_campaign_time(first_deadline - live_clock - 1)
	if hero.next_weapon_hit_grants.size() != 2:
		_fail("freshly recovered grants did not remain through just before expiry")
		return
	game_manager.advance_campaign_time(1)
	if hero.next_weapon_hit_grants.size() != 1 or str(hero.next_weapon_hit_grants[0].get("source_instance_id", "")) != source_b:
		_fail("first recovered grant did not expire exactly while preserving the other source")
		return
	game_manager.advance_campaign_time(second_deadline - int(game_manager.campaign_elapsed_seconds) + 7200)
	if not hero.next_weapon_hit_grants.is_empty():
		_fail("large clock jump left a recovered grant active or restarted its deadline")
		return
	save_manager.delete_save(SLOT)
	save_manager.delete_save(BAD_SLOT)
	if FileAccess.file_exists(MANIFEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST))
	print("NEXT MELEE HIT GRANT FRESH RELAUNCH PASSED: exact typed state/order, malformed refusal and original deadlines")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("[NextMeleeHitGrantFreshRelaunchProbe] %s" % message)
	get_tree().quit(1)
