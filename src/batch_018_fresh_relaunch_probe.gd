extends Node

const SLOT := "batch_018_checkpoint"
const MANIFEST := "user://batch_018_manifest.json"

func _ready() -> void:
	GameManager.test_mode = true
	Batch018Checks.load_fixtures()
	if OS.get_environment("BATCH_018_RELAUNCH_PHASE") == "prepare": _prepare()
	else: _recover()

func _prepare() -> void:
	var file := FileAccess.open(SaveManager.SAVE_DIR + SLOT + ".sav",FileAccess.WRITE)
	if file == null: return _fail("Cannot stage base checkpoint")
	file.store_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
	file.close()
	if not SaveManager.load_game(SLOT): return _fail("Base checkpoint refused")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var previous: Character = PlayerManager.get_player(0).get("character")
	var c := Batch018Checks.actor()
	c.character_id = previous.character_id
	PlayerManager.set_player_character(0,c)
	PartyManager.characters[c.character_id] = c
	for id in ["fixture:018_secondary_plain",c.class_id]:
		c.level_up()
		if not PermanentProgressionRules.advance(c,id,c.permanent_progression.duplicate(true)): return _fail("Prepare acquisition refused")
	if not c.inventory.remove_item("dagger"): return _fail("Cannot remove granted copy before checkpoint")
	c.level_up() # An unspent entitlement must survive reload as well.
	c.current_hp = 7
	if not SaveManager.save_game(SLOT): return _fail("Allowed checkpoint refused")
	var manifest := {"owner":c.character_id,"dto":c.to_dict(),"pid":OS.get_process_id()}
	file = FileAccess.open(MANIFEST,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH 018 FRESH PREPARED: " + JSON.stringify(manifest))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var events: Array = []
	var listener := func(details: Dictionary): events.append(details.duplicate(true))
	Dice.dice_rolled.connect(listener)
	if int(manifest.pid) == OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Distinct-process load refused")
	var c: Character = PartyManager.characters.get(str(manifest.owner))
	if c == null or not PermanentProgressionRules.same_json(c.to_dict(), manifest.dto) or not events.is_empty(): return _fail("Recovery replayed or changed permanent state/inventory/HP")
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR + SLOT + ".sav"))
	var refused := 0
	for mutation in ["strip","history","receipt","allocation","pending","payload","proficiency","extra","secondary","basis"]:
		for carrier in ["party","players"]:
			var bad := base.duplicate(true)
			var dto: Dictionary = bad.party.characters[str(manifest.owner)] if carrier == "party" else bad.players[0].character
			match mutation:
				"strip": dto.erase("permanent_progression")
				"history": dto.permanent_progression.history[0] = "wizard"
				"receipt": dto.permanent_progression.receipts.erase(c.class_id+"|starting")
				"allocation": dto.class_levels[c.class_id] = 1
				"pending": dto.permanent_progression.pending_levels = -1
				"payload": dto.permanent_progression.receipts[c.class_id+"|starting"].grants = []
				"proficiency": dto.skill_proficiencies = []
				"extra": dto.permanent_progression.receipts["forged"] = {}
				"secondary": dto.permanent_progression.history[1] = "missing"
				"basis": dto.permanent_progression.receipts[c.class_id+"|starting"].boundary = "multiclass"
			var slot: String = "batch_018_invalid_"+mutation+"_"+carrier
			var file := FileAccess.open(SaveManager.SAVE_DIR+slot+".sav",FileAccess.WRITE)
			file.store_string(JSON.stringify(bad))
			file.close()
			var before := c.to_dict().duplicate(true)
			if SaveManager.load_game(slot) or PartyManager.characters.get(str(manifest.owner)) != c or c.to_dict() != before or not events.is_empty(): return _fail("Malformed full save replaced session: " + slot)
			refused += 1
	var old_state := c.permanent_progression.duplicate(true)
	var gear := c.inventory.backpack.count("dagger")
	if not PermanentProgressionRules.advance(c,c.class_id,old_state) or c.level != 4 or c.get_class_level() != 3 or c.inventory.backpack.count("dagger") != gear+1 or not events.is_empty(): return _fail("Recovered pending level did not settle exactly once")
	var after := c.to_dict().duplicate(true)
	if PermanentProgressionRules.advance(c,c.class_id,old_state) or c.to_dict() != after: return _fail("Recovered acquisition replayed")
	print("BATCH 018 FRESH RELAUNCH PASSED: " + JSON.stringify({"pid":OS.get_process_id(),"owner":c.character_id,"full_saves_refused":refused,"dto":c.to_dict(),"rng_events":events.size()}))
	Dice.dice_rolled.disconnect(listener)
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[Batch018FreshRelaunchProbe] " + message)
	get_tree().quit(1)
