extends Node

const SLOT := "short_rest_fresh_relaunch"
const MANIFEST_PATH := "user://short_rest_manifest.json"

var game_manager: Node
var data_loader: Node
var player_manager: Node
var party_manager: Node
var save_manager: Node


func _ready() -> void:
	game_manager = get_tree().get_root().get_node("GameManager")
	data_loader = get_tree().get_root().get_node("DataLoader")
	player_manager = get_tree().get_root().get_node("PlayerManager")
	party_manager = get_tree().get_root().get_node("PartyManager")
	save_manager = get_tree().get_root().get_node("SaveManager")
	game_manager.test_mode = true

	var phase := OS.get_environment("SHORT_REST_RELAUNCH_PHASE")
	if phase == "prepare":
		_prepare()
	elif phase == "recover":
		_recover()
	else:
		_fail("unknown short-rest relaunch phase: %s" % phase)


func _prepare() -> void:
	RestRules.reset_windows()
	save_manager.delete_save(SLOT)
	if FileAccess.file_exists(MANIFEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST_PATH))

	var fixture_text := FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json")
	var fixture_file := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % SLOT, FileAccess.WRITE)
	if fixture_text.is_empty() or fixture_file == null:
		_fail("could not stage repository save fixture")
		return
	fixture_file.store_string(fixture_text)
	fixture_file.close()

	if not save_manager.load_game(SLOT):
		_fail("repository save fixture did not load")
		return

	game_manager.current_state = GameManager.GameState.OVERWORLD
	game_manager.transition_context = {}
	game_manager.game_in_progress = true
	game_manager.active_dungeon_state.clear()
	game_manager.campaign_elapsed_seconds = 1000

	var scores := AbilityScores.new()
	scores.from_dict({"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 12, "CHA": 10})
	var wizard := Character.new()
	wizard.initialize("Probe Wizard", "human", "wizard", scores)
	while wizard.level < 5:
		wizard.level_up()
	if not ClassProgression.choose_subclass(wizard, "diviner"):
		_fail("could not choose diviner subclass for level 5 wizard")
		return

	# Expend 2xL1, 1xL2, and 1xL3 slots (budget at level 5 = ceil(5/2) = 3).
	wizard.spell_slots["1"] = 2 # max 4 -> 2 missing
	wizard.spell_slots["2"] = 2 # max 3 -> 1 missing
	wizard.spell_slots["3"] = 1 # max 2 -> 1 missing
	wizard.wizard_memorize_spell_pending = false

	player_manager.set_player_character(0, wizard)
	party_manager.reset()
	party_manager.register_player_character(0, wizard)

	var short_res := RestRules.complete_short_rest([wizard])
	if not bool(short_res.get("success", false)) or not bool(short_res.get("pending_recovery", false)):
		_fail("Short Rest did not open Arcane Recovery window")
		return
	if game_manager.campaign_elapsed_seconds != 4600:
		_fail("Short Rest did not advance campaign_elapsed_seconds from 1000 to 4600 (got %d)" % game_manager.campaign_elapsed_seconds)
		return

	# Recover 1xL2 + 1xL1 = 3/3 budget
	var settled := RestRules.settle_recovery_window({"selected_slots": {"1": 1, "2": 1}})
	if not bool(settled.get("success", false)) or int(settled.get("budget_spent", 0)) != 3:
		_fail("Arcane Recovery did not settle 1xL1 + 1xL2 (3/3 budget)")
		return
	if int(wizard.spell_slots.get("1", 0)) != 3 or int(wizard.spell_slots.get("2", 0)) != 3 or int(wizard.spell_slots.get("3", 0)) != 1:
		_fail("unexpected spell_slots after Arcane Recovery: %s" % JSON.stringify(wizard.spell_slots))
		return
	if int(wizard.feature_uses.get("wizard_arcane_recovery", -1)) != 0:
		_fail("Arcane Recovery feature use was not consumed")
		return

	var choice_err := ClassProgression.saved_choices_error(wizard.to_dict())
	if not choice_err.is_empty():
		_fail("wizard failed saved_choices_error: %s" % choice_err)
		return

	save_manager.delete_save(SLOT)
	if not save_manager.save_game(SLOT):
		_fail("could not save short-rest state to disk")
		return

	var manifest := {
		"wizard_id": wizard.character_id,
		"level": wizard.level,
		"campaign_elapsed_seconds": game_manager.campaign_elapsed_seconds,
		"spell_slots": wizard.spell_slots.duplicate(true),
		"arcane_recovery_uses": int(wizard.feature_uses.get("wizard_arcane_recovery", -1)),
		"memorize_spell_pending": wizard.wizard_memorize_spell_pending,
	}
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest_file == null:
		_fail("could not open manifest path for writing")
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()

	print("SHORT REST FRESH PREPARED: completed 1-hour Short Rest, recovered 1xL1 + 1xL2 via Arcane Recovery, and committed save to disk")
	get_tree().quit()


func _recover() -> void:
	RestRules.reset_windows()
	if not FileAccess.file_exists(MANIFEST_PATH):
		_fail("manifest file missing in recover process")
		return
	var manifest_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not (manifest_parsed is Dictionary):
		_fail("manifest JSON invalid in recover process")
		return
	var manifest: Dictionary = manifest_parsed

	if not save_manager.load_game(SLOT):
		_fail("fresh process could not load the prepared short-rest save")
		return

	if game_manager.campaign_elapsed_seconds != int(manifest.get("campaign_elapsed_seconds", -1)):
		_fail("recovered campaign_elapsed_seconds (%d) != manifest (%d)" % [
			game_manager.campaign_elapsed_seconds,
			int(manifest.get("campaign_elapsed_seconds", -1))
		])
		return

	var active_party: Array = party_manager.get_active_characters()
	if active_party.size() != 1:
		_fail("expected recovered active party size 1, got %d" % active_party.size())
		return
	var wizard: Character = active_party[0]
	if wizard == null or wizard.character_id != str(manifest.get("wizard_id", "")):
		_fail("recovered wizard character_id does not match manifest")
		return
	if _normalize(wizard.spell_slots) != _normalize(manifest.get("spell_slots", {})):
		_fail("recovered spell_slots (%s) != manifest (%s)" % [
			JSON.stringify(wizard.spell_slots),
			JSON.stringify(manifest.get("spell_slots", {}))
		])
		return
	if int(wizard.feature_uses.get("wizard_arcane_recovery", -1)) != 0:
		_fail("recovered wizard_arcane_recovery uses expected 0, got %d" % int(wizard.feature_uses.get("wizard_arcane_recovery", -1)))
		return
	if not wizard.wizard_memorize_spell_pending:
		_fail("expected wizard_memorize_spell_pending = true to survive reload after level 5 Short Rest")
		return

	# Verify a second Short Rest in the recovered process does not offer Arcane Recovery again
	var second_short := RestRules.complete_short_rest([wizard])
	if not bool(second_short.get("success", false)) or bool(second_short.get("pending_recovery", true)):
		_fail("second Short Rest in recovered process unexpectedly offered Arcane Recovery before Long Rest")
		return
	if game_manager.campaign_elapsed_seconds != 8200:
		_fail("second Short Rest in recovered process did not advance campaign_elapsed_seconds to 8200")
		return

	# Verify Long Rest restores Arcane Recovery use and full slots
	wizard.long_rest()
	if int(wizard.feature_uses.get("wizard_arcane_recovery", 0)) != 1 or int(wizard.spell_slots.get("3", 0)) != 2:
		_fail("Long Rest in recovered process did not restore Arcane Recovery use and level 3 slots")
		return

	save_manager.delete_save(SLOT)
	if FileAccess.file_exists(MANIFEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST_PATH))

	print("SHORT REST FRESH RELAUNCH PASSED: Short Rest clock, recovered spell slots, spent Arcane Recovery use, second-rest suppression, and Long Rest reset verified across processes")
	get_tree().quit()


func _normalize(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))


func _fail(message: String) -> void:
	push_error("[ShortRestFreshRelaunchProbe] %s" % message)
	get_tree().quit(1)
