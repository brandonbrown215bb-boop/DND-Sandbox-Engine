extends Node

const SLOT := "batch_l_checkpoint"
const MANIFEST := "user://batch_l_manifest.json"

func _ready() -> void:
	GameManager.test_mode = true
	BatchLChecks.load_fixtures()
	if OS.get_environment("BATCH_L_RELAUNCH_PHASE") == "prepare": _prepare()
	else: _recover()

func _prepare() -> void:
	var file := FileAccess.open(SaveManager.SAVE_DIR + SLOT + ".sav", FileAccess.WRITE)
	if file == null: return _fail("Cannot stage base checkpoint")
	file.store_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
	file.close()
	if not SaveManager.load_game(SLOT): return _fail("Base checkpoint refused")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var previous: Character = PlayerManager.get_player(0).get("character")
	var c := BatchLChecks.actor()
	c.character_id = previous.character_id
	PlayerManager.set_player_character(0, c)
	PartyManager.characters[c.character_id] = c
	if not ClassProgression.choose_feature_option(c, "fixture:l_choice_plain", "l_grant_plain"): return _fail("Progression acquisition refused")
	# Train the represented spell so full-save progression validation remains authoritative.
	if c.spell_choices_pending and not ClassProgression.choose_spell_selection(c, ["fixture:l_spell_plain", "fixture:l_spell_focus"]): return _fail("Spell training refused")
	for index in 2: c.inventory.add_item("fixture:l_ring_plain")
	var copies := c.inventory.backpack_instances()
	if not c.inventory.equip_instance(Inventory.Slot.RING_1, str(copies[0].instance_id)) or not c.inventory.equip_instance(Inventory.Slot.RING_2, str(copies[1].instance_id)): return _fail("Item acquisition refused")
	for index in 2:
		if not SpellResolver.resolve(c, c, DataLoader.get_spell("fixture:l_spell_plain"), true).get("success", false): return _fail("Cast acquisition refused")
	if not SpellResolver.resolve(c, c, DataLoader.get_spell("fixture:l_spell_focus"), true).get("success", false): return _fail("Focus cast acquisition refused")
	var focus_source := str(c.spell_effects.keys()[-1])
	c.concentrating_on = {"spell_id":"fixture:l_spell_focus", "effect_source":focus_source, "targets":[c]}
	GameManager.advance_campaign_time(17)
	if SourceBenefitRules.query(c).size() != 6: return _fail("Expected six independent carriers")
	if not SaveManager.save_game(SLOT): return _fail("Allowed checkpoint refused")
	var manifest := {"owner":c.character_id, "carriers":SourceBenefitRules.query(c), "casts":c.spell_effects, "slots":c.spell_slots, "ac":c.get_ac(), "speed":c.get_speed(), "clock":GameManager.campaign_elapsed_seconds, "pid":OS.get_process_id()}
	file = FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH L FRESH PREPARED: " + JSON.stringify(manifest))
	# Release the test-owned live self-reference after the checkpoint is on disk.
	c.concentrating_on.clear()
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if manifest.get("pid") == OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Distinct-process recovery refused")
	var c: Character = PartyManager.characters.get(str(manifest.owner))
	if c != null: print("BATCH L RECOVERY COMPARISONS: " + JSON.stringify({"carriers":SourceBenefitRules.query(c) == manifest.carriers,"casts":c.spell_effects == manifest.casts,"slots":JSON.parse_string(JSON.stringify(c.spell_slots)) == manifest.slots,"ac":c.get_ac() == int(manifest.ac),"speed":c.get_speed() == int(manifest.speed),"clock":GameManager.campaign_elapsed_seconds == int(manifest.clock)}))
	if c != null: print("BATCH L RECOVERED: " + JSON.stringify({"carriers":SourceBenefitRules.query(c), "casts":c.spell_effects, "slots":c.spell_slots, "ac":c.get_ac(), "speed":c.get_speed(), "clock":GameManager.campaign_elapsed_seconds}))
	if c == null or SourceBenefitRules.query(c) != manifest.carriers or c.spell_effects != manifest.casts or JSON.parse_string(JSON.stringify(c.spell_slots)) != manifest.slots or c.get_ac() != int(manifest.ac) or c.get_speed() != int(manifest.speed) or GameManager.campaign_elapsed_seconds != int(manifest.clock): return _fail("Identity/payload/clock/cost changed during recovery")
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR + SLOT + ".sav"))
	var refused := 0
	for mutation in ["payload", "owner", "duration", "missing", "identity", "serial", "item", "choice", "focus_link", "focus_wrong_kind"]:
		for carrier in ["party", "players"]:
			var invalid := base.duplicate(true)
			var dto: Dictionary = invalid.party.characters[str(manifest.owner)] if carrier == "party" else invalid.players[0].character
			var source := str(dto.spell_effects.keys()[0])
			var record: Dictionary = dto.spell_effects[source]
			match mutation:
				"payload": record.source_benefits[0].amount = 9
				"owner": record.caster_id = "missing"
				"duration": record.remaining_seconds = 61
				"missing": record.erase("source_benefits")
				"identity":
					dto.spell_effects.erase(source)
					record.source_id = "spell:%s:9999" % c.character_id
					dto.spell_effects[record.source_id] = record
				"serial": dto.spell_cast_serial = 0
				"item": dto.inventory.copies.records.values()[0].definition_id = "missing"
				"focus_link": dto.spell_concentration.clear()
				"focus_wrong_kind":
					dto.spell_effects.erase(str(dto.spell_concentration.effect_source))
					dto.spell_concentration.effect_source = source
				"choice": dto.feature_choices["fixture:l_choice_plain"] = ["missing"]
			var slot: String = "batch_l_invalid_" + str(mutation) + "_" + str(carrier)
			var file := FileAccess.open(SaveManager.SAVE_DIR + slot + ".sav", FileAccess.WRITE)
			file.store_string(JSON.stringify(invalid))
			file.close()
			var before := c.to_dict().duplicate(true)
			if SaveManager.load_game(slot) or PartyManager.characters.get(str(manifest.owner)) != c or c.to_dict() != before or GameManager.campaign_elapsed_seconds != int(manifest.clock): return _fail("Malformed full save changed live state: " + slot)
			refused += 1
	# Removing one of each carrier after reload leaves all unrelated grants intact.
	var source := str(c.spell_effects.keys()[0])
	if not SourceBenefitRules.dismiss(c, source) or SourceBenefitRules.dismiss(c, source): return _fail("Recovered cast dismissal/replay failed")
	if not ClassProgression.replace_feature_option(c, "fixture:l_choice_plain", "l_grant_plain", "l_empty_plain"): return _fail("Recovered progression replacement failed")
	if c.inventory.unequip(Inventory.Slot.RING_1).is_empty() or SourceBenefitRules.query(c).size() != 3 or c.get_ac() != int(manifest.ac) - 6: return _fail("Recovered source removal affected siblings")
	GameManager.advance_campaign_time(42)
	if c.spell_effects.size() != 2: return _fail("Restored original deadline expired early")
	GameManager.advance_campaign_time(1)
	if c.spell_effects.size() != 1 or SourceBenefitRules.query(c).size() != 2 or c.get_ac() != int(manifest.ac) - 8: return _fail("Restored original deadline changed or removed unrelated item")
	var focus_source := str(c.concentrating_on.get("effect_source", ""))
	if not SourceBenefitRules.dismiss(c, focus_source) or not c.concentrating_on.is_empty() or SourceBenefitRules.query(c).size() != 1 or c.get_ac() != int(manifest.ac) - 12: return _fail("Recovered focus dismissal did not preserve item")
	print("BATCH L FRESH RELAUNCH PASSED: " + JSON.stringify({"pid":OS.get_process_id(),"owner":c.character_id,"full_saves_refused":refused,"remaining_carriers":SourceBenefitRules.query(c),"ac":c.get_ac(),"clock":GameManager.campaign_elapsed_seconds}))
	get_tree().quit()

func _fail(message: String) -> void:
	for member in PartyManager.characters.values():
		if member is Character: member.concentrating_on.clear()
	push_error("[BatchLFreshRelaunchProbe] " + message)
	get_tree().quit(1)
