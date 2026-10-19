extends Node

const SLOT := "s031_damage_history_checkpoint"
const BAD_SLOT := "s031_damage_history_malformed"
const MANIFEST := "user://s031_damage_history_manifest.json"

var game_manager: Node
var party_manager: Node
var save_manager: Node


func _ready() -> void:
	game_manager = get_tree().get_root().get_node("GameManager")
	party_manager = get_tree().get_root().get_node("PartyManager")
	save_manager = get_tree().get_root().get_node("SaveManager")
	game_manager.test_mode = true
	var phase := OS.get_environment("S031_DAMAGE_HISTORY_RELAUNCH_PHASE")
	if phase == "prepare":
		_prepare()
	elif phase == "recover":
		_recover()
	else:
		_fail("unknown fresh-relaunch phase: %s" % phase)


func _prepare() -> void:
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
	game_manager.campaign_elapsed_seconds = 5000
	var active_party: Array = party_manager.get_active_characters()
	if active_party.is_empty():
		_fail("base fixture did not restore a damage target")
		return
	var target: Character = active_party[0]
	var source_a := Character.new()
	source_a.character_id = "fixture:s031:source_actor_a"
	var source_b := Character.new()
	source_b.character_id = "fixture:s031:source_actor_b"
	target.feature_uses["damage_immunities"] = []
	target.temp_hp = 2
	var first: Dictionary = CombatAction.resolve_damage(target, 10, "fire", {"damage_source_instance_id": "fixture:s031:damage_source_a"}, false, false, source_a)
	target.feature_uses["damage_immunities"] = ["fire"]
	var second: Dictionary = CombatAction.resolve_damage(target, 5, "fire", {"damage_source_instance_id": "fixture:s031:damage_source_b"}, false, false, source_b)
	if int(first.get("raw", -1)) != 10 or int(first.get("absorbed", -1)) != 2 or int(first.get("hp_loss", -1)) != 8 or int(second.get("resolved", -1)) != 0 or int(second.get("prevented", -1)) != 5:
		_fail("production damage resolver did not produce the two expected distinct settlement receipts")
		return
	target.feature_uses["damage_immunities"] = []
	var expected := target.recent_damage_history.duplicate(true)
	if expected.size() != 2 or not Character.saved_damage_history_error(target.to_dict(), 5000).is_empty():
		_fail("prepared target history is missing a source or fails Character state validation")
		return
	if not save_manager.get_save_block_reason().is_empty() or not save_manager.save_game(SLOT):
		_fail("allowed Overworld checkpoint refused source-attributed damage history")
		return
	var manifest := {
		"owner_id": target.character_id,
		"source_actor_id": source_a.character_id,
		"second_source_actor_id": source_b.character_id,
		"entries": expected,
		"process_id": OS.get_process_id(),
		"campaign_elapsed_seconds": int(game_manager.campaign_elapsed_seconds),
		"first_receipt": first,
		"second_receipt": second
	}
	var manifest_file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if manifest_file == null:
		_fail("could not write S-031 fresh-relaunch manifest")
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()
	print("S031 DAMAGE HISTORY FRESH PREPARED: %s" % JSON.stringify(manifest))
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
	if int(manifest.get("process_id", -1)) == OS.get_process_id():
		_fail("recovery did not run in a fresh operating-system process")
		return
	if not save_manager.load_game(SLOT):
		_fail("fresh process could not recover the allowed checkpoint")
		return
	var owner_id := str(manifest.get("owner_id", ""))
	var target: Character = party_manager.characters.get(owner_id)
	var expected: Array = manifest.get("entries", [])
	if target == null or target.recent_damage_history != expected or int(game_manager.campaign_elapsed_seconds) != int(manifest.get("campaign_elapsed_seconds", -1)):
		_fail("fresh process changed damage source/target identities, measures or their absolute clock boundary")
		return
	if not Character.saved_damage_history_error(target.to_dict(), int(game_manager.campaign_elapsed_seconds)).is_empty():
		_fail("recovered recent history fails production Character validation")
		return
	var source_id := str(manifest.get("source_actor_id", ""))
	var second_source_id := str(manifest.get("second_source_actor_id", ""))
	game_manager.advance_campaign_time(59)
	var source_a: Dictionary = target.recent_damage_measure(source_id, "fixture:s031:damage_source_a", "hp_loss", int(game_manager.campaign_elapsed_seconds))
	var source_b: Dictionary = target.recent_damage_measure(second_source_id, "fixture:s031:damage_source_b", "prevented", int(game_manager.campaign_elapsed_seconds))
	if int(source_a.get("value", -1)) != 8 or int(source_b.get("value", -1)) != 5:
		_fail("fresh process did not recover independently queryable measures by exact source")
		return
	var live_target := target
	var live_history := target.recent_damage_history.duplicate(true)
	var live_clock := int(game_manager.campaign_elapsed_seconds)
	var saved_text := FileAccess.get_file_as_string(save_manager.SAVE_DIR + "%s.sav" % SLOT)
	for mutation in [{"source_instance_id": ""}, {"hp_loss": -1}, {"at_seconds": 5001}]:
		var malformed: Dictionary = JSON.parse_string(saved_text)
		var saved_entries: Array = malformed["party"]["characters"][owner_id].get("recent_damage_history", [])
		if saved_entries.is_empty():
			_fail("checkpoint payload does not contain durable damage history")
			return
		saved_entries[0].merge(mutation, true)
		var bad_file := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % BAD_SLOT, FileAccess.WRITE)
		if bad_file == null:
			_fail("could not write malformed full-save fixture")
			return
		bad_file.store_string(JSON.stringify(malformed, "\t"))
		bad_file.close()
		if save_manager.load_game(BAD_SLOT) or party_manager.characters.get(owner_id) != live_target or live_target.recent_damage_history != live_history or int(game_manager.campaign_elapsed_seconds) != live_clock:
			_fail("malformed source/quantity/boundary history was accepted or replaced the live session before refusal")
			return
	var before := int(target.recent_damage_measure(second_source_id, "fixture:s031:damage_source_b", "prevented", int(game_manager.campaign_elapsed_seconds)).get("value", -1))
	game_manager.advance_campaign_time(1)
	var at := int(target.recent_damage_measure(second_source_id, "fixture:s031:damage_source_b", "prevented", int(game_manager.campaign_elapsed_seconds)).get("value", -1))
	game_manager.advance_campaign_time(3940)
	var jump := int(target.recent_damage_measure(second_source_id, "fixture:s031:damage_source_b", "prevented", int(game_manager.campaign_elapsed_seconds)).get("value", -1))
	if before != 5 or at != 0 or jump != 0:
		_fail("freshly recovered deadline did not expire at equality or large time jump")
		return
	print("S031 DAMAGE HISTORY FRESH RELAUNCH PASSED: allowed Overworld save, exact source/target recovery, measures, malformed-load refusal and absolute 60-second equality expiry")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("[S031DamageHistoryFreshRelaunchProbe] %s" % message)
	get_tree().quit(1)
