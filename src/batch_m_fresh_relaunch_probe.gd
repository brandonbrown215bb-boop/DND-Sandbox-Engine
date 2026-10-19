extends Node

const SLOT := "batch_m_checkpoint"
const MANIFEST := "user://batch_m_manifest.json"

func _ready() -> void:
	GameManager.test_mode = true
	BatchMChecks.load_fixtures()
	if OS.get_environment("BATCH_M_RELAUNCH_PHASE") == "prepare": _prepare()
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
	var c := BatchMChecks.actor()
	c.character_id = previous.character_id
	PlayerManager.set_player_character(0,c)
	PartyManager.characters[c.character_id] = c
	var f := BatchMChecks.feature(c)
	if not ResourcePoolRules.acquire(c,f,"first").get("success",false) or not ResourcePoolRules.acquire(c,f,"sibling").get("success",false): return _fail("Acquisition refused")
	if not ClassFeature.execute(c,f,c,null,"first",2).get("success",false): return _fail("Spend refused")
	c.level = 4
	c.class_levels = {c.class_id:1,"wizard":3}
	if not ResourcePoolRules.recalculate_capacity(c,f,"first").get("success",false): return _fail("Progression refused")
	if not ResourcePoolRules.recover(c,f,"first","short_rest_completed").get("success",false): return _fail("Recovery refused")
	if not SaveManager.save_game(SLOT): return _fail("Allowed checkpoint refused")
	var manifest := {"owner":c.character_id,"pools":c.numeric_resource_pools,"hp":c.current_hp,"pid":OS.get_process_id()}
	file = FileAccess.open(MANIFEST,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH M FRESH PREPARED: " + JSON.stringify(manifest))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var events: Array = []
	var listener := func(details: Dictionary): events.append(details.duplicate(true))
	Dice.dice_rolled.connect(listener)
	if manifest.get("pid") == OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Distinct-process recovery refused")
	var c: Character = PartyManager.characters.get(str(manifest.owner))
	if c == null or c.numeric_resource_pools != manifest.pools or c.current_hp != int(manifest.hp) or not events.is_empty(): return _fail("Reload changed faces/identities/quantities or rolled again")
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR + SLOT + ".sav"))
	var refused := 0
	for mutation in ["face","duplicate","owner","source","serial","quantity","policy","missing","size","level","strip"]:
		for carrier in ["party","players"]:
			var bad := base.duplicate(true)
			var dto: Dictionary = bad.party.characters[str(manifest.owner)] if carrier == "party" else bad.players[0].character
			var pool: Dictionary = dto.numeric_resource_pools.first
			match mutation:
				"face": pool.captured_dice[0].face = 99
				"duplicate": pool.captured_dice[1] = pool.captured_dice[0].duplicate(true)
				"owner": pool.captured_dice[0].owner_id = "missing"
				"source": pool.captured_dice[0].source_instance_id = "sibling"
				"serial": pool.die_serial = 0
				"quantity": pool.current = 0
				"policy": pool.upgrade_policy = "reroll"
				"missing": pool.erase("captured_dice")
				"size": pool.captured_dice[0].die_size = 3
				"level": pool.captured_dice[0].generation_level = 0
				"strip":
					for field in ["capture_policy","upgrade_policy","captured_dice","die_serial"]: pool.erase(field)
			var slot: String = "batch_m_invalid_" + str(mutation) + "_" + str(carrier)
			var file := FileAccess.open(SaveManager.SAVE_DIR + slot + ".sav",FileAccess.WRITE)
			file.store_string(JSON.stringify(bad))
			file.close()
			var before := c.to_dict().duplicate(true)
			if SaveManager.load_game(slot) or PartyManager.characters.get(str(manifest.owner)) != c or c.to_dict() != before or not events.is_empty(): return _fail("Malformed full save replaced session: " + slot)
			refused += 1
	var dice: Array = c.numeric_resource_pools.first.captured_dice.duplicate(true)
	var sibling: Dictionary = c.numeric_resource_pools.sibling.duplicate(true)
	var result := ClassFeature.execute(c,BatchMChecks.feature(c),c,null,"first",2)
	if not result.get("success",false) or result.results[0].captured_dice != dice or c.current_hp != int(manifest.hp) + int(dice[0].face) + int(dice[1].face) or not events.is_empty() or c.numeric_resource_pools.first.current != 0 or c.numeric_resource_pools.sibling != sibling: return _fail("Recovered mixed-size spend changed faces or sibling")
	if ClassFeature.execute(c,BatchMChecks.feature(c),c,null,"first",1).get("success",true): return _fail("Depleted captured dice replayed")
	print("BATCH M FRESH RELAUNCH PASSED: " + JSON.stringify({"pid":OS.get_process_id(),"owner":c.character_id,"full_saves_refused":refused,"spent_dice":dice,"pools":c.numeric_resource_pools,"rng_events":events.size()}))
	Dice.dice_rolled.disconnect(listener)
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[BatchMFreshRelaunchProbe] " + message)
	get_tree().quit(1)
