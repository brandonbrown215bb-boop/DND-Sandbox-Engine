extends Node

const SLOT := "s037_class_levels_checkpoint"
const BAD_SLOT := "s037_class_levels_bad"
const MANIFEST := "user://s037_manifest.json"

func _ready() -> void:
	GameManager.test_mode=true
	DataLoader._load_json_file("res://data/fixtures/class_level_tables.json","class")
	if OS.get_environment("S037_CLASS_LEVELS_RELAUNCH_PHASE")=="prepare": _prepare()
	else: _recover()

func _prepare() -> void:
	var file := FileAccess.open(SaveManager.SAVE_DIR+SLOT+".sav",FileAccess.WRITE)
	if file==null: return _fail("Cannot stage checkpoint")
	file.store_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
	file.close()
	if not SaveManager.load_game(SLOT): return _fail("Base checkpoint refused")
	GameManager.current_state=GameManager.GameState.OVERWORLD
	GameManager.game_in_progress=true
	GameManager.active_dungeon_state.clear()
	var actor: Character = PartyManager.get_active_characters()[0]
	actor.level=8
	actor.class_levels={"fighter":1,"wizard":3,"cleric":4}
	for suffix in ["neutral","renamed"]:
		var feature: Dictionary = DataLoader.classes["fixture:class_table_"+suffix+"_class"].features_by_level["1"][0]
		if not ResourcePoolRules.acquire(actor,feature,"fixture:relaunch:"+suffix).get("success",false): return _fail("Source acquisition failed")
		if not ResourcePoolRules.spend(actor,"fixture:relaunch:"+suffix,1).get("success",false): return _fail("Source spend failed")
	if not SaveManager.save_game(SLOT): return _fail("Allowed save refused")
	var manifest := {"owner":actor.character_id,"classes":actor.class_levels,"pools":actor.numeric_resource_pools,"pid":OS.get_process_id()}
	file=FileAccess.open(MANIFEST,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("S037 CLASS LEVELS FRESH PREPARED: "+JSON.stringify(manifest))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if manifest.get("pid")==OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Fresh checkpoint recovery failed")
	var actor: Character = PartyManager.characters.get(str(manifest.owner))
	if actor==null or actor.class_levels!=manifest.classes or actor.numeric_resource_pools!=manifest.pools or actor.get_class_level("fighter")!=1 or actor.get_class_level("wizard")!=3 or actor.get_class_level("cleric")!=4 or actor.get_class_level("ranger")!=0: return _fail("Allocation or spent independent pools changed during restore")
	var saved := FileAccess.get_file_as_string(SaveManager.SAVE_DIR+SLOT+".sav")
	for bad in [{"fighter":1,"wizard":4,"cleric":4},{"fighter":true,"wizard":7},{"fighter":1,"unknown":7},{"wizard":8},[8]]:
		var payload: Dictionary = JSON.parse_string(saved)
		payload.party.characters[str(manifest.owner)].class_levels=bad
		var file := FileAccess.open(SaveManager.SAVE_DIR+BAD_SLOT+".sav",FileAccess.WRITE)
		file.store_string(JSON.stringify(payload))
		file.close()
		if SaveManager.load_game(BAD_SLOT) or PartyManager.characters.get(str(manifest.owner))!=actor or actor.class_levels!=manifest.classes or actor.numeric_resource_pools!=manifest.pools: return _fail("Malformed allocation replaced live state")
	print("S037 CLASS LEVELS FRESH RELAUNCH PASSED: exact allocation, absent class, two spent pools, numeric/die-size state, malformed full-save refusal before replacement; pid="+str(OS.get_process_id()))
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[S037ClassLevelsFreshRelaunchProbe] "+message)
	get_tree().quit(1)
