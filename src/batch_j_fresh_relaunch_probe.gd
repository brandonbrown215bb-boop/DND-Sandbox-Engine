extends Node

const SLOT := "batch_j_checkpoint"
const BAD_SLOT := "batch_j_bad"
const MANIFEST := "user://batch_j_manifest.json"
const SOURCE := "j:durable"

func _ready() -> void:
	GameManager.test_mode = true
	DataLoader._load_json_file("res://data/fixtures/batch_j_limits.json", "class")
	if OS.get_environment("BATCH_J_RELAUNCH_PHASE") == "prepare": _prepare()
	else: _recover()

func _target() -> Dictionary:
	return {"id": "j:durable-target", "is_alive": true, "current_hp": 100, "max_hp": 100, "conditions": {}}

func _prepare() -> void:
	var file := FileAccess.open(SaveManager.SAVE_DIR + SLOT + ".sav", FileAccess.WRITE)
	if file == null: return _fail("Cannot stage checkpoint")
	file.store_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
	file.close()
	if not SaveManager.load_game(SLOT): return _fail("Base checkpoint refused")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var actor: Character = PartyManager.get_active_characters()[0]
	actor.class_id = "fixture:batch_j"
	actor.weapon_masteries.clear()
	actor.fighter_training.clear()
	actor.feature_choices.clear()
	actor.creation_choices = ClassProgression.default_creation_choices(actor.class_id, actor.race_id)
	actor.numeric_resource_pools.clear()
	actor.modifiers.clear()
	var feature: Dictionary = DataLoader.classes[actor.class_id].features_by_level["1"][3].duplicate(true)
	feature.source_instance_id = SOURCE
	actor.features = [feature]
	if not ResourcePoolRules.acquire(actor, feature, SOURCE).get("success", false): return _fail("Source acquisition failed")
	if not ClassFeature.execute(actor, feature, null, null, SOURCE).get("success", false): return _fail("Activation failed")
	var hit := CombatAction.resolve_weapon_damage_riders(actor, _target(), {}, {"type": "weapon", "range": 1})
	if hit.size() != 1 or int(ResourcePoolRules.availability(actor, SOURCE).current) != 8: return _fail("First grant use failed")
	GameManager.advance_campaign_time(5)
	if not SaveManager.save_game(SLOT): return _fail("Allowed checkpoint refused")
	var manifest := {"owner": actor.character_id, "modifiers": actor.modifiers, "pools": actor.numeric_resource_pools, "clock": GameManager.campaign_elapsed_seconds, "pid": OS.get_process_id()}
	file = FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH J FRESH PREPARED: " + JSON.stringify(manifest))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if manifest.get("pid") == OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Fresh process recovery failed")
	var actor: Character = PartyManager.characters.get(str(manifest.owner))
	if actor == null or actor.numeric_resource_pools != manifest.pools or actor.modifiers != manifest.modifiers or GameManager.campaign_elapsed_seconds != manifest.clock: return _fail("Recovered identity/quantities/deadline/locks changed")
	var target := _target()
	if not CombatAction.resolve_weapon_damage_riders(actor, target, {}, {"type": "weapon", "range": 1}).is_empty() or int(target.current_hp) != 100 or actor.numeric_resource_pools != manifest.pools: return _fail("Reload gave an extra active-instance use")
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR + SLOT + ".sav"))
	for bad in ["string", "duplicate", "invalid", "too_many", "wrong_owner", "wrong_source", "missing_deadline", "orphan_locks"]:
		var malformed := base.duplicate(true)
		var modifier: Dictionary = malformed.party.characters[str(manifest.owner)].modifiers[0]
		match bad:
			"string": modifier.used_rider_options = "j_active"
			"duplicate": modifier.used_rider_options = ["j_active", "j_active"]
			"invalid": modifier.used_rider_options = ["not valid"]
			"too_many":
				modifier.used_rider_options = []
				for i in 101: modifier.used_rider_options.append("option_%d" % i)
			"wrong_owner": modifier.owner_id = "someone_else"
			"wrong_source": modifier.source_instance_id = "missing_source"
			"missing_deadline": modifier.erase("expires_at_seconds")
			"orphan_locks":
				modifier.clear()
				modifier.merge({"kind": "stat", "key": "AC", "amount": 1, "used_rider_options": ["j_active"]})
		var file := FileAccess.open(SaveManager.SAVE_DIR + BAD_SLOT + ".sav", FileAccess.WRITE)
		file.store_string(JSON.stringify(malformed))
		file.close()
		if SaveManager.load_game(BAD_SLOT) or PartyManager.characters.get(str(manifest.owner)) != actor or actor.numeric_resource_pools != manifest.pools or actor.modifiers != manifest.modifiers: return _fail("Malformed full save replaced live session: " + bad)
	var deadline := int(actor.modifiers[0].expires_at_seconds)
	GameManager.advance_campaign_time(deadline - int(GameManager.campaign_elapsed_seconds))
	if not actor.modifiers.is_empty() or actor.numeric_resource_pools != manifest.pools: return _fail("Original deadline or spent quantity changed")
	var feature: Dictionary = actor.get_feature("fixture:j_active")
	if not ClassFeature.execute(actor, feature, null, null, SOURCE).get("success", false): return _fail("Fresh activation after expiry refused")
	var next := CombatAction.resolve_weapon_damage_riders(actor, target, {}, {"type": "weapon", "range": 1})
	if next.size() != 1 or str(next[0].grant_instance_id) == str(manifest.modifiers[0].grant_instance_id) or int(ResourcePoolRules.availability(actor, SOURCE).current) != 6: return _fail("Next activation did not acquire an independent allowance")
	print("BATCH J FRESH RELAUNCH PASSED: exact source/grant/used option, pool8, original clock/deadline; reload refuses extra hit; eight malformed full saves refuse before live replacement; original expiry and new grant pool6; pid=" + str(OS.get_process_id()))
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[BatchJFreshRelaunchProbe] " + message)
	get_tree().quit(1)
