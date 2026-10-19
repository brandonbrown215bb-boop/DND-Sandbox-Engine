extends Node

const SLOT := "batch_024_checkpoint"
const MANIFEST := "user://batch_024_manifest.json"

func _ready() -> void:
	GameManager.test_mode = true
	DataLoader._load_json_file("res://data/fixtures/batch_024_recovery.json", "class")
	if OS.get_environment("BATCH_024_RELAUNCH_PHASE") == "prepare": _prepare()
	else: _recover()

func _prepare() -> void:
	var file := FileAccess.open(SaveManager.SAVE_DIR + SLOT + ".sav", FileAccess.WRITE)
	if file == null: return _fail("Cannot stage 2024 checkpoint")
	file.store_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
	file.close()
	if not SaveManager.load_game(SLOT): return _fail("Base 2024 checkpoint refused")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	PlayerManager.reset()
	PartyManager.reset()
	var scores := AbilityScores.new()
	scores.from_dict({"STR":10,"DEX":12,"CON":14,"INT":12,"WIS":16,"CHA":10})
	var owner := Character.new()
	owner.initialize("Batch 024 Durable Owner", "human", "fixture:batch024_plain", scores)
	owner.character_id = "fixture:batch024:durable_owner"
	owner.class_levels = {"fixture:batch024_plain":1}
	GameManager.campaign_elapsed_seconds = 0
	var dawn_feature: Dictionary = DataLoader.classes["fixture:batch024_plain"].features_by_level["1"][0]
	var cooldown_feature: Dictionary = DataLoader.classes["fixture:batch024_plain"].features_by_level["1"][2]
	var dawn_source := "fixture:batch024:durable:dawn"
	var cooldown_source := "fixture:batch024:durable:cooldown"
	var dawn_acquired := ResourcePoolRules.acquire(owner, dawn_feature, dawn_source)
	var cooldown_acquired := ResourcePoolRules.acquire(owner, cooldown_feature, cooldown_source)
	if not bool(dawn_acquired.get("success", false)) or not bool(cooldown_acquired.get("success", false)): return _fail("Recovery pools refused acquisition")
	if not ResourcePoolRules.spend(owner, cooldown_source).get("success", false): return _fail("Cooldown payment refused")
	PlayerManager.add_player(owner.character_name)
	PlayerManager.set_player_character(0, owner)
	PartyManager.register_player_character(0, owner)
	GameManager.campaign_elapsed_seconds = 21599
	GameManager.advance_campaign_time(1)
	if int(owner.numeric_resource_pools[dawn_source].current) != 2 or int(owner.numeric_resource_pools[dawn_source].recovery_occurrences.dawn) != 21600: return _fail("Scheduled dawn did not recover before save")
	if int(owner.numeric_resource_pools[cooldown_source].current) != 1 or int(owner.numeric_resource_pools[cooldown_source].recovery_occurrences.cooldown) != 1800: return _fail("Captured cooldown did not recover before save: " + JSON.stringify({"time":GameManager.campaign_elapsed_seconds,"pool":owner.numeric_resource_pools[cooldown_source]}))
	if not SaveManager.save_game(SLOT): return _fail("Recovery state save refused")
	var manifest := {"pid":OS.get_process_id(),"owner":owner.character_id,"dawn_source":dawn_source,"cooldown_source":cooldown_source,"dawn":owner.numeric_resource_pools[dawn_source],"cooldown":owner.numeric_resource_pools[cooldown_source],"elapsed":GameManager.campaign_elapsed_seconds}
	file = FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH 024 FRESH PREPARED: " + JSON.stringify(manifest))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if int(manifest.get("pid", 0)) == OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Distinct-process recovery refused")
	var owner: Character = PartyManager.characters.get(str(manifest.owner))
	if owner == null: return _fail("Durable owner missing after relaunch")
	if _plain(owner.numeric_resource_pools[str(manifest.dawn_source)]) != manifest.dawn or _plain(owner.numeric_resource_pools[str(manifest.cooldown_source)]) != manifest.cooldown or GameManager.campaign_elapsed_seconds != int(manifest.elapsed): return _fail("Recovery quantity, exact source or occurrence cursor changed on relaunch")
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR + SLOT + ".sav"))
	var invalid := base.duplicate(true)
	var owner_id := str(manifest.owner)
	invalid.party.characters[owner_id].numeric_resource_pools[str(manifest.dawn_source)].recovery_occurrences.dawn = "21600"
	for player in invalid.players:
		if str(player.get("character", {}).get("character_id", "")) == owner_id:
			player.character.numeric_resource_pools[str(manifest.dawn_source)].recovery_occurrences.dawn = "21600"
	var bad_slot := "batch_024_invalid_occurrence"
	var file := FileAccess.open(SaveManager.SAVE_DIR + bad_slot + ".sav", FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid))
	file.close()
	var before := owner.to_dict().duplicate(true)
	if SaveManager.load_game(bad_slot) or PartyManager.characters.get(owner_id) != owner or owner.to_dict() != before: return _fail("Malformed occurrence save changed live campaign state")
	print("BATCH 024 FRESH RELAUNCH PASSED: " + JSON.stringify({"pid":OS.get_process_id(),"owner":owner_id,"dawn":owner.numeric_resource_pools[str(manifest.dawn_source)],"cooldown":owner.numeric_resource_pools[str(manifest.cooldown_source)],"malformed_refused":true}))
	get_tree().quit()

func _plain(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func _fail(message: String) -> void:
	push_error("[Batch024FreshRelaunchProbe] " + message)
	get_tree().quit(1)
