extends Node

const SLOT := "roll_token_fresh_relaunch"
const MALFORMED_SLOT := "roll_token_malformed_slot"
const MANIFEST_PATH := "user://roll_token_manifest.json"

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

	var phase := OS.get_environment("ROLL_TOKEN_RELAUNCH_PHASE")
	if phase == "prepare":
		_prepare()
	elif phase == "recover":
		_recover()
	else:
		_fail("unknown roll token relaunch phase: %s" % phase)


func _seed_d20(target_roll: int) -> void:
	for candidate in range(1, 5000):
		seed(candidate)
		if randi_range(1, 20) == target_roll:
			seed(candidate)
			return
	_fail("could not seed d20 for %d" % target_roll)


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
	var diviner := Character.new()
	diviner.initialize("Probe Diviner", "human", "wizard", scores)
	while diviner.level < 3:
		diviner.level_up()

	if not ClassProgression.choose_subclass(diviner, "diviner"):
		_fail("could not choose diviner subclass")
		return
	var initial_tokens := RollTokenRules.available_tokens(diviner, "diviner_portent")
	if initial_tokens.size() != 2 or diviner.roll_token_generation_serial != 1:
		_fail("expected initial diviner_portent pool with 2 tokens and generation_serial 1")
		return

	# Set deterministic Portent pool [18, 4] on serial 1
	diviner.roll_tokens["diviner_portent"] = [
		{"token_id": "diviner_portent:1:0", "value": 18, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20},
		{"token_id": "diviner_portent:1:1", "value": 4, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20},
	]

	var choice_err := ClassProgression.saved_choices_error(diviner.to_dict())
	if not choice_err.is_empty():
		_fail("diviner failed saved_choices_error: %s" % choice_err)
		return

	# Spend the first token (diviner_portent:1:0 = 18) via Character.saving_throw_test_to_dc
	CombatAction.advance_combat_turn(diviner)
	var save_res: Dictionary = diviner.saving_throw_test_to_dc(
		"WIS",
		15,
		false,
		false,
		{"roll_token_replacement": {"owner": diviner, "pool_id": "diviner_portent", "token_id": "diviner_portent:1:0"}}
	)
	if not bool(save_res.get("success", false)) or not bool(save_res.get("replaced_by_roll_token", false)) or int(save_res.get("natural", 0)) != 18:
		_fail("spending Portent token 18 on saving throw did not produce natural == 18")
		return
	if RollTokenRules.get_available_values(diviner, "diviner_portent") != [4]:
		_fail("expected only token value 4 remaining after spending token 18")
		return

	# Replace slot 0 character with diviner
	player_manager.set_player_character(0, diviner)
	party_manager.reset()
	party_manager.register_player_character(0, diviner)

	save_manager.delete_save(SLOT)
	if not save_manager.save_game(SLOT):
		_fail("could not save roll token state to disk")
		return

	var manifest := {
		"diviner_id": diviner.character_id,
		"subclass_id": diviner.subclass_id,
		"level": diviner.level,
		"roll_token_generation_serial": diviner.roll_token_generation_serial,
		"roll_tokens": diviner.roll_tokens.duplicate(true)
	}
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest_file == null:
		_fail("could not open manifest path for writing")
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()

	print("ROLL TOKEN FRESH PREPARED: spent Portent token and committed remaining pool to disk")
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
		_fail("fresh process could not load the prepared roll token save")
		return

	var active_party: Array = party_manager.get_active_characters()
	if active_party.size() != 1:
		_fail("expected recovered active party size 1, got %d" % active_party.size())
		return
	var diviner: Character = active_party[0]
	if diviner == null or diviner.character_id != str(manifest.get("diviner_id", "")):
		_fail("recovered diviner character_id does not match manifest")
		return
	if diviner.subclass_id != "diviner" or diviner.level != 3:
		_fail("recovered diviner subclass/level (%s/%d) invalid" % [diviner.subclass_id, diviner.level])
		return
	if diviner.roll_token_generation_serial != int(manifest.get("roll_token_generation_serial", -1)):
		_fail("recovered roll_token_generation_serial (%d) != manifest" % diviner.roll_token_generation_serial)
		return
	if _normalize(diviner.roll_tokens) != _normalize(manifest.get("roll_tokens", {})):
		_fail("recovered roll_tokens (%s) != manifest (%s)" % [
			JSON.stringify(diviner.roll_tokens),
			JSON.stringify(manifest.get("roll_tokens", {}))
		])
		return
	var tokens_after_load := RollTokenRules.get_available_tokens(diviner, "diviner_portent")
	if tokens_after_load.size() != 1 or str(tokens_after_load[0].get("token_id", "")) != "diviner_portent:1:1" or int(tokens_after_load[0].get("value", 0)) != 4:
		_fail("fresh process load did not preserve exact unspent token diviner_portent:1:1 == 4")
		return

	# Verify malformed roll_tokens saves are rejected before mutating live session
	var base_save_text := FileAccess.get_file_as_string(save_manager.SAVE_DIR + "%s.sav" % SLOT)
	if not _verify_malformed_roll_token_refusal(base_save_text, diviner):
		return
	print("ROLL TOKEN LOAD REFUSAL: malformed roll_tokens saves refused without mutating live session")

	# Level up to 14 (Greater Portent) and verify existing token is preserved while 1 new token is appended
	while diviner.level < 14:
		diviner.level_up()
	if diviner.level != 14:
		_fail("expected level 14 after Greater Portent level up, got %d" % diviner.level)
		return
	var tokens_at_14 := RollTokenRules.get_available_tokens(diviner, "diviner_portent")
	if tokens_at_14.size() != 2:
		_fail("expected 2 available tokens after Greater Portent upgrade (1 preserved + 1 appended), got %d" % tokens_at_14.size())
		return
	if str(tokens_at_14[0].get("token_id", "")) != "diviner_portent:1:1" or int(tokens_at_14[0].get("value", 0)) != 4:
		_fail("Greater Portent upgrade mutated or rerolled existing token diviner_portent:1:1")
		return
	var new_val := int(tokens_at_14[1].get("value", 0))
	if str(tokens_at_14[1].get("token_id", "")) != "diviner_portent:1:1" and (new_val < 1 or new_val > 20):
		_fail("Greater Portent upgrade did not append valid 1..20 token")
		return

	# Long Rest regenerates all 3 Greater Portent tokens and increments generation_serial to 2
	diviner.long_rest()
	var tokens_after_rest := RollTokenRules.get_available_tokens(diviner, "diviner_portent")
	if diviner.roll_token_generation_serial != 2 or tokens_after_rest.size() != 3:
		_fail("Long Rest at level 14 did not advance generation_serial to 2 and regenerate 3 tokens")
		return

	save_manager.delete_save(SLOT)
	save_manager.delete_save(MALFORMED_SLOT)
	if FileAccess.file_exists(MANIFEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST_PATH))

	print("ROLL TOKEN FRESH RELAUNCH PASSED: Portent token persistence, malformed refusal, Greater Portent upgrade, and Long Rest verified across processes")
	get_tree().quit()


func _verify_malformed_roll_token_refusal(base_save_text: String, diviner: Character) -> bool:
	var tokens_snap: Dictionary = diviner.roll_tokens.duplicate(true)
	var variants: Array[Dictionary] = []

	# Variant 1: out-of-range die value 21
	var v1: Dictionary = JSON.parse_string(base_save_text)
	v1["party"]["characters"][diviner.character_id]["roll_tokens"]["diviner_portent"][0]["value"] = 21
	variants.append(v1)

	# Variant 2: undeclared pool id
	var v2: Dictionary = JSON.parse_string(base_save_text)
	v2["party"]["characters"][diviner.character_id]["roll_tokens"]["undeclared_pool"] = []
	variants.append(v2)

	# Variant 3: duplicate token id
	var v3: Dictionary = JSON.parse_string(base_save_text)
	v3["party"]["characters"][diviner.character_id]["roll_tokens"]["diviner_portent"] = [
		{"token_id": "diviner_portent:1:1", "value": 4, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20},
		{"token_id": "diviner_portent:1:1", "value": 12, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20}
	]
	variants.append(v3)

	# Variant 4: too many tokens for level-3 Diviner (capacity 2, 3 stored)
	var v4: Dictionary = JSON.parse_string(base_save_text)
	v4["party"]["characters"][diviner.character_id]["roll_tokens"]["diviner_portent"] = [
		{"token_id": "diviner_portent:1:0", "value": 4, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20},
		{"token_id": "diviner_portent:1:1", "value": 12, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20},
		{"token_id": "diviner_portent:1:2", "value": 19, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20}
	]
	variants.append(v4)

	for idx in range(variants.size()):
		var f := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % MALFORMED_SLOT, FileAccess.WRITE)
		if f == null:
			_fail("could not write malformed roll token variant %d" % idx)
			return false
		f.store_string(JSON.stringify(variants[idx], "\t"))
		f.close()
		if save_manager.load_game(MALFORMED_SLOT):
			_fail("malformed roll_tokens save variant %d was unexpectedly accepted" % idx)
			return false

	if _normalize(diviner.roll_tokens) != _normalize(tokens_snap):
		_fail("refused malformed roll_tokens save mutated live diviner.roll_tokens")
		return false
	return true


func _normalize(v: Variant) -> Variant:
	if v is float and is_finite(v) and v == floor(v):
		return int(v)
	if v is Array:
		var out: Array = []
		for item in v:
			out.append(_normalize(item))
		return out
	if v is Dictionary:
		var out: Dictionary = {}
		for k in v:
			out[str(k)] = _normalize(v[k])
		return out
	return v


func _fail(message: String) -> void:
	push_error("[RollTokenFreshRelaunchProbe] " + message)
	get_tree().quit(1)
