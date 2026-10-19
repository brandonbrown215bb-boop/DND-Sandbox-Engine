extends Node

const SLOT := "batch_k_checkpoint"
const MANIFEST := "user://batch_k_manifest.json"

func _ready() -> void:
	GameManager.test_mode = true
	DataLoader._load_json_file("res://data/fixtures/batch_k_choices.json", "class")
	# Test-only composed definition is identical in both fresh processes.
	var record: Dictionary = DataLoader.classes["fixture:batch_k"]
	var spell_feature: Dictionary = DataLoader.classes["cleric"].features_by_level["1"][0].duplicate(true)
	spell_feature.id = "fixture:k_spellcasting"
	spell_feature.effects[0].capacity_by_level = {}
	for level in range(1, 21):
		spell_feature.effects[0].capacity_by_level[str(level)] = {"cantrips":1, "prepared_spells":0}
	record.features_by_level["1"].append(spell_feature)
	record.features_by_level["1"][1].effects[0].options[1].class_id = "fighter"
	for index in [0, 1, 2]:
		record.features_by_level["1"][1].effects[0].options[index].effects.append({"type":"spellcasting_capacity_bonus", "kind":"cantrips", "amount":1})
	if not DataLoader._validate_content(record, "class", "batch-k-relaunch-composition"):
		return _fail("Composed checkpoint definition refused")
	if OS.get_environment("BATCH_K_RELAUNCH_PHASE") == "prepare":
		_prepare()
	else:
		_recover()

func _prepare() -> void:
	var file := FileAccess.open(SaveManager.SAVE_DIR + SLOT + ".sav", FileAccess.WRITE)
	if file == null:
		return _fail("Cannot stage checkpoint")
	file.store_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
	file.close()
	if not SaveManager.load_game(SLOT):
		return _fail("Base checkpoint refused")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var actor: Character = PartyManager.get_active_characters()[0]
	actor.class_id = "fixture:batch_k"
	actor.level = 2
	actor.class_levels = {"fixture:batch_k":1, "fighter":1}
	actor.weapon_masteries.clear()
	actor.fighter_training.clear()
	actor.feature_choices.clear()
	actor.creation_choices = ClassProgression.default_creation_choices(actor.class_id, actor.race_id)
	actor.features.assign(DataLoader.classes[actor.class_id].features_by_level["1"])
	actor.weapon_proficiencies = ["simple"]
	actor.armor_proficiencies = ["light"]
	actor.spell_choices_pending = true

	if not ClassProgression.choose_feature_option(actor, "fixture:k_boon", "k_blade"):
		return _fail("Failed to choose k_blade")
	if not ClassProgression.choose_feature_options(actor, "fixture:k_invocations", ["k_thirsting_blade", "k_armor_of_shadows"]):
		return _fail("Failed to choose k_invocations")
	if not BatchKChecks.train_spells(actor):
		return _fail("Failed to train multi-pick cantrip capacity")

	if not SaveManager.save_game(SLOT):
		return _fail("Allowed checkpoint refused")

	var manifest := {
		"owner": actor.character_id,
		"choices": actor.feature_choices,
		"weapons": actor.weapon_proficiencies,
		"armor": actor.armor_proficiencies,
		"extra_attacks": actor.extra_attacks,
		"class_levels": actor.class_levels,
		"spells": actor.known_spells,
		"cantrip_capacity": actor.get_spellcasting_capacity("cantrips"),
		"clock": GameManager.campaign_elapsed_seconds,
		"pid": OS.get_process_id()
	}
	file = FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH K FRESH PREPARED: " + JSON.stringify(manifest))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if manifest.get("pid") == OS.get_process_id() or not SaveManager.load_game(SLOT):
		return _fail("Fresh process recovery failed")
	var actor: Character = PartyManager.characters.get(str(manifest.owner))
	if actor == null:
		return _fail("Actor not found after recovery")
	if actor.feature_choices != manifest.choices:
		return _fail("Recovered feature_choices mismatch")
	if actor.weapon_proficiencies != manifest.weapons:
		return _fail("Recovered weapon_proficiencies mismatch")
	if actor.armor_proficiencies != manifest.armor:
		return _fail("Recovered armor_proficiencies mismatch")
	if actor.extra_attacks != int(manifest.extra_attacks):
		return _fail("Recovered extra_attacks mismatch")
	if actor.class_levels != manifest.class_levels or actor.known_spells != manifest.spells or actor.get_spellcasting_capacity("cantrips") != int(manifest.cantrip_capacity):
		return _fail("Recovered allocation/spells/multi-pick capacity mismatch")
	if GameManager.campaign_elapsed_seconds != int(manifest.clock):
		return _fail("Recovered clock mismatch")
	var before := actor.to_dict().duplicate(true)
	if ClassProgression.replace_feature_option(actor, "fixture:k_invocations", "k_armor_of_shadows", "k_veteran_ward") or actor.to_dict() != before:
		return _fail("Recovered trained spell dependency did not refuse atomically")

	# S-046: verify replacement refusal and clean replacement in recovered process
	if ClassProgression.can_replace_feature_option(actor, "fixture:k_boon", "k_blade", "k_tome").get("allowed", true):
		return _fail("Dependent replacement not refused after recovery")

	if not ClassProgression.replace_feature_option(actor, "fixture:k_invocations", "k_armor_of_shadows", "k_agonizing_blast"):
		return _fail("Safe replacement failed after recovery")
	if "medium" in actor.armor_proficiencies:
		return _fail("Replaced armor grant not revoked after recovery")
	if "martial" not in actor.weapon_proficiencies or actor.extra_attacks != 1:
		return _fail("Unreplaced grants not intact after recovery")

	# Test preflight errors on malformed saves
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR + SLOT + ".sav"))
	var char_dto: Dictionary = base.party.characters[str(manifest.owner)]

	# Malformed count
	var bad_dto := char_dto.duplicate(true)
	bad_dto.feature_choices["fixture:k_invocations"] = ["k_thirsting_blade"]
	if ClassProgression.saved_choices_error(bad_dto).is_empty():
		return _fail("Preflight failed to reject malformed count")

	# Orphaned dependent choice
	var orphaned_dto := char_dto.duplicate(true)
	orphaned_dto.feature_choices["fixture:k_boon"] = ["k_tome"]
	orphaned_dto.feature_choices["fixture:k_invocations"] = ["k_thirsting_blade", "k_agonizing_blast"]
	if ClassProgression.saved_choices_error(orphaned_dto).is_empty():
		return _fail("Preflight failed to reject orphaned dependent choice")
	var missing_class := char_dto.duplicate(true)
	missing_class.class_levels = {"fixture:batch_k":2}
	var excess_spells := char_dto.duplicate(true)
	for spell_id in actor.get_spell_option_ids(true):
		if spell_id not in excess_spells.feature_choices["fixture:k_spellcasting"]:
			excess_spells.feature_choices["fixture:k_spellcasting"].append(spell_id)
			break
	var corruptions := {"count":bad_dto, "dependent":orphaned_dto, "class":missing_class, "capacity":excess_spells}
	var refused := 0
	for key in corruptions:
		for carrier in ["party", "players"]:
			var invalid := base.duplicate(true)
			if carrier == "party": invalid.party.characters[str(manifest.owner)] = corruptions[key]
			else: invalid.players[0].character = corruptions[key]
			var slot: String = "batch_k_invalid_" + str(key) + "_" + str(carrier)
			var file := FileAccess.open(SaveManager.SAVE_DIR + slot + ".sav", FileAccess.WRITE)
			file.store_string(JSON.stringify(invalid))
			file.close()
			before = actor.to_dict().duplicate(true)
			if SaveManager.load_game(slot) or PartyManager.characters.get(str(manifest.owner)) != actor or actor.to_dict() != before or GameManager.campaign_elapsed_seconds != int(manifest.clock):
				return _fail("Malformed full save changed live state: " + slot)
			refused += 1

	print("BATCH K FRESH RELAUNCH PASSED: " + JSON.stringify({"pid":OS.get_process_id(), "owner": actor.character_id, "choices": actor.feature_choices, "weapons": actor.weapon_proficiencies, "armor": actor.armor_proficiencies, "class_levels":actor.class_levels, "spells":actor.known_spells, "cantrip_capacity":actor.get_spellcasting_capacity("cantrips"), "full_saves_refused":refused}))
	get_tree().quit()

func _fail(message: String) -> void:
	printerr("[BatchKFreshRelaunchProbe] " + message)
	get_tree().quit(1)
