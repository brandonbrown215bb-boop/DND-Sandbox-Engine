extends Node

const SLOT := "ward_fresh_relaunch"
const MALFORMED_SLOT := "ward_malformed_slot"
const MANIFEST_PATH := "user://ward_manifest.json"

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

	var phase := OS.get_environment("WARD_RELAUNCH_PHASE")
	if phase == "prepare":
		_prepare()
	elif phase == "recover":
		_recover()
	else:
		_fail("unknown ward relaunch phase: %s" % phase)


func _prepare() -> void:
	save_manager.delete_save(SLOT)
	save_manager.delete_save(MALFORMED_SLOT)
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
	game_manager.campaign_elapsed_seconds = 0

	var active_party: Array = party_manager.get_active_characters()
	if active_party.is_empty():
		_fail("repository save fixture did not restore a party")
		return

	var scores := AbilityScores.new()
	scores.from_dict({"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 12, "CHA": 10})
	var abjurer := Character.new()
	abjurer.initialize("Probe Abjurer", "human", "wizard", scores)
	while abjurer.level < 3:
		abjurer.level_up()

	if not ClassProgression.choose_subclass(abjurer, "abjurer"):
		_fail("could not choose abjurer subclass")
		return
	if WardRules.is_ward_active(abjurer, "arcane_ward") or WardRules.current_ward_hp(abjurer, "arcane_ward") != 0 or WardRules.max_ward_hp(abjurer, "arcane_ward") != 10:
		_fail("expected lazy inactive arcane_ward with 0/10 HP before first Abjuration slot cast")
		return

	abjurer.known_spells.append_array(["mage_armor", "shield"])
	var cast_res := CombatAction.resolve_spell(abjurer, abjurer, DataLoader.get_spell("mage_armor"), true)
	if not bool(cast_res.get("success", false)) or not WardRules.is_ward_active(abjurer, "arcane_ward") or WardRules.current_ward_hp(abjurer, "arcane_ward") != 10:
		_fail("casting Mage Armor with slot did not create Arcane Ward at 10/10 HP")
		return

	var dmg_res := CombatAction.resolve_damage(abjurer, 6, "bludgeoning")
	if int(dmg_res.get("ward_absorbed", 0)) != 6 or int(dmg_res.get("resolved", -1)) != 0 or WardRules.current_ward_hp(abjurer, "arcane_ward") != 4:
		_fail("Arcane Ward did not absorb 6 damage to leave 4/10 HP")
		return

	var choice_err := ClassProgression.saved_choices_error(abjurer.to_dict())
	if not choice_err.is_empty():
		_fail("abjurer failed saved_choices_error: %s" % choice_err)
		return

	player_manager.set_player_character(0, abjurer)
	party_manager.reset()
	party_manager.register_player_character(0, abjurer)

	save_manager.delete_save(SLOT)
	if not save_manager.save_game(SLOT):
		_fail("could not save ward state to disk")
		return

	var manifest := {
		"abjurer_id": abjurer.character_id,
		"subclass_id": abjurer.subclass_id,
		"level": abjurer.level,
		"damage_wards": abjurer.damage_wards.duplicate(true)
	}
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest_file == null:
		_fail("could not open manifest path for writing")
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()

	print("WARD FRESH PREPARED: created Arcane Ward, absorbed 6 damage to 4/10 HP, and committed save to disk")
	get_tree().quit()


func _recover() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_fail("manifest file missing in recover process")
		return
	var manifest_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not (manifest_parsed is Dictionary):
		_fail("manifest JSON invalid in recover process")
		return
	var manifest: Dictionary = manifest_parsed

	if not save_manager.load_game(SLOT):
		_fail("fresh process could not load the prepared ward save")
		return

	var active_party: Array = party_manager.get_active_characters()
	if active_party.size() != 1:
		_fail("expected recovered active party size 1, got %d" % active_party.size())
		return
	var abjurer: Character = active_party[0]
	if abjurer == null or abjurer.character_id != str(manifest.get("abjurer_id", "")):
		_fail("recovered abjurer character_id does not match manifest")
		return
	if abjurer.subclass_id != "abjurer" or abjurer.level != 3:
		_fail("recovered abjurer subclass/level (%s/%d) invalid" % [abjurer.subclass_id, abjurer.level])
		return
	if _normalize(abjurer.damage_wards) != _normalize(manifest.get("damage_wards", {})):
		_fail("recovered damage_wards (%s) != manifest (%s)" % [
			JSON.stringify(abjurer.damage_wards),
			JSON.stringify(manifest.get("damage_wards", {}))
		])
		return
	if not WardRules.is_ward_active(abjurer, "arcane_ward") or WardRules.current_ward_hp(abjurer, "arcane_ward") != 4 or WardRules.max_ward_hp(abjurer, "arcane_ward") != 10:
		_fail("fresh process load did not preserve active Arcane Ward at 4/10 HP")
		return

	var base_save_text := FileAccess.get_file_as_string(save_manager.SAVE_DIR + "%s.sav" % SLOT)
	if not _verify_malformed_ward_refusal(base_save_text, abjurer):
		return
	print("WARD LOAD REFUSAL: malformed damage_wards saves refused without mutating live session")

	while abjurer.level < 6:
		abjurer.level_up()
	if abjurer.level != 6 or not abjurer.has_feature("abjurer_projected_ward"):
		_fail("expected level 6 Abjurer with Projected Ward")
		return
	if WardRules.current_ward_hp(abjurer, "arcane_ward") != 4 or WardRules.max_ward_hp(abjurer, "arcane_ward") != 16:
		_fail("expected Arcane Ward 4/16 HP after leveling to 6, got %d/%d" % [
			WardRules.current_ward_hp(abjurer, "arcane_ward"),
			WardRules.max_ward_hp(abjurer, "arcane_ward")
		])
		return

	var recharge_res := WardRules.spend_slot_for_ward_recharge(abjurer, "arcane_ward", 2)
	if not bool(recharge_res.get("success", false)) or WardRules.current_ward_hp(abjurer, "arcane_ward") != 8:
		_fail("Bonus Action slot expenditure did not restore Arcane Ward to 8/16 HP")
		return

	abjurer.long_rest()
	if WardRules.is_ward_active(abjurer, "arcane_ward") or WardRules.current_ward_hp(abjurer, "arcane_ward") != 0 or bool(WardRules.pool_state(abjurer, "arcane_ward").get("created_since_long_rest", true)):
		_fail("Long Rest did not expire Arcane Ward and reset creation state")
		return

	save_manager.delete_save(SLOT)
	save_manager.delete_save(MALFORMED_SLOT)
	if FileAccess.file_exists(MANIFEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST_PATH))

	print("WARD FRESH RELAUNCH PASSED: Arcane Ward persistence, malformed refusal, level-up scaling, Bonus Action recharge, and Long Rest expiry verified across processes")
	get_tree().quit()


func _verify_malformed_ward_refusal(base_save_text: String, abjurer: Character) -> bool:
	var wards_snap: Dictionary = abjurer.damage_wards.duplicate(true)
	var variants: Array[Dictionary] = []

	# Variant 1: current_hp > max_hp
	var v1: Dictionary = JSON.parse_string(base_save_text)
	v1["party"]["characters"][abjurer.character_id]["damage_wards"]["pools"]["arcane_ward"]["current_hp"] = 99
	variants.append(v1)

	# Variant 2: undeclared pool id
	var v2: Dictionary = JSON.parse_string(base_save_text)
	v2["party"]["characters"][abjurer.character_id]["damage_wards"]["pools"]["undeclared_ward"] = v2["party"]["characters"][abjurer.character_id]["damage_wards"]["pools"]["arcane_ward"].duplicate(true)
	variants.append(v2)

	# Variant 3: tampered max_hp
	var v3: Dictionary = JSON.parse_string(base_save_text)
	v3["party"]["characters"][abjurer.character_id]["damage_wards"]["pools"]["arcane_ward"]["max_hp"] = 50
	variants.append(v3)

	# Variant 4: active = true when created_since_long_rest = false
	var v4: Dictionary = JSON.parse_string(base_save_text)
	v4["party"]["characters"][abjurer.character_id]["damage_wards"]["pools"]["arcane_ward"]["created_since_long_rest"] = false
	variants.append(v4)

	for idx in range(variants.size()):
		var f := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % MALFORMED_SLOT, FileAccess.WRITE)
		if f == null:
			_fail("could not write malformed ward save variant %d" % idx)
			return false
		f.store_string(JSON.stringify(variants[idx]))
		f.close()
		if save_manager.load_game(MALFORMED_SLOT):
			_fail("SaveManager accepted malformed damage_wards variant %d" % idx)
			return false
		var post_party: Array = party_manager.get_active_characters()
		if post_party.size() != 1 or post_party[0] != abjurer or _normalize(abjurer.damage_wards) != _normalize(wards_snap):
			_fail("rejected malformed damage_wards variant %d mutated live session" % idx)
			return false
	return true


func _normalize(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))


func _fail(message: String) -> void:
	push_error("[WardFreshRelaunchProbe] %s" % message)
	get_tree().quit(1)
