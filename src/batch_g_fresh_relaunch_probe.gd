extends Node

const SLOT := "batch_g_checkpoint"
const BAD_SLOT := "batch_g_bad"
const MANIFEST := "user://batch_g_manifest.json"

func _ready() -> void:
	GameManager.test_mode=true
	DataLoader._load_json_file("res://data/fixtures/batch_g_protections.json","class")
	if OS.get_environment("BATCH_G_RELAUNCH_PHASE")=="prepare": _prepare()
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
	actor.inventory=Inventory.new()
	actor.ability_scores.from_dict({"STR":10,"DEX":14,"CON":10,"INT":10,"WIS":20,"CHA":10})
	actor._recalculate_ac()
	var templates: Array = DataLoader.classes["fixture:batch_g_protections"].features_by_level["1"]
	for pair in [[0,"g:durable:a"],[0,"g:durable:b"],[1,"g:durable:c"],[2,"g:durable:edge"]]:
		var feature: Dictionary = templates[int(pair[0])].duplicate(true)
		feature.source_instance_id=str(pair[1])
		actor.features.append(feature)
		if not ResourcePoolRules.acquire(actor,feature,str(pair[1])).get("success",false): return _fail("Source acquisition failed")
		if not ClassFeature.execute(actor,feature,null,null,str(pair[1])).get("success",false): return _fail("Protection activation failed")
		GameManager.advance_campaign_time(5)
	ClassProgression.apply_fixed_score_increase(actor,{"scores":{"STR":2},"maximum":20})
	var request := ProtectionRules.begin_choice(actor,"stance")
	if not ProtectionRules.answer(actor,request,str(actor.protection_grants[1].grant_instance_id)): return _fail("Exact selection refused")
	# An open request is deliberately absent from durable state.
	ProtectionRules.begin_choice(actor,"stance")
	if not SaveManager.save_game(SLOT): return _fail("Allowed checkpoint refused")
	var manifest := {"owner":actor.character_id,"grants":actor.protection_grants,"selections":actor.protection_selections,"pools":actor.numeric_resource_pools,"permanent":actor.ability_scores.to_dict(),"ac":actor.get_ac(),"score":actor.ability_scores.get_score("STR"),"clock":GameManager.campaign_elapsed_seconds,"pid":OS.get_process_id()}
	file=FileAccess.open(MANIFEST,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH G FRESH PREPARED: "+JSON.stringify(manifest))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if manifest.get("pid")==OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Fresh checkpoint recovery failed")
	var expected_scores := AbilityScores.new()
	expected_scores.from_dict(manifest.permanent)
	manifest.permanent=expected_scores.to_dict()
	var actor: Character = PartyManager.characters.get(str(manifest.owner))
	print("BATCH G RECOVERY STATE: "+JSON.stringify({"grants":actor.protection_grants,"selections":actor.protection_selections,"pools":actor.numeric_resource_pools,"permanent":actor.ability_scores.to_dict(),"ac":actor.get_ac(),"score":actor.ability_scores.get_score("STR"),"pending_empty":actor.pending_protection_choice.is_empty(),"grants_equal":actor.protection_grants==manifest.grants,"pools_equal":actor.numeric_resource_pools==manifest.pools,"permanent_equal":actor.ability_scores.to_dict()==manifest.permanent,"clock":GameManager.campaign_elapsed_seconds}))
	if actor==null or actor.protection_grants!=manifest.grants or actor.protection_selections!=manifest.selections or actor.numeric_resource_pools!=manifest.pools or actor.ability_scores.to_dict()!=manifest.permanent or actor.get_ac()!=int(manifest.ac) or actor.ability_scores.get_score("STR")!=int(manifest.score) or not actor.pending_protection_choice.is_empty(): return _fail("Exact protection, underlying score, pool, clock or transient menu changed on restore")
	var saved := FileAccess.get_file_as_string(SaveManager.SAVE_DIR+SLOT+".sav")
	for case_index in 14:
		var payload: Dictionary = JSON.parse_string(saved)
		var data: Dictionary = payload.party.characters[str(manifest.owner)]
		match case_index:
			0: data.protection_grants[0].owner_id="another_actor"
			1: data.protection_grants[0].source_instance_id="missing_source"
			2: data.protection_grants[0].expires_at_seconds+=1
			3: data.protection_grants[0].started_at_seconds=int(manifest.clock)+1
			4: data.protection_grants[0].effect.benefits[1].value=30
			5: data.protection_selections.stance="not_owned"
			6: data.protection_grants[0].effect.stacking="merge_all"
			7: data.protection_grants[0].order=true
			8: data.protection_grants.append(data.protection_grants[0].duplicate(true))
			9: data.protection_serial=0
			10: data.protection_grants={}
			11: data.protection_grants[0].effect.benefits[0].value={"selected_slot_level":true}
			12: data.numeric_resource_pools=[]
			13:
				payload.players[0].character=data.duplicate(true)
				payload.players[0].character.protection_selections={"wrong_group":data.protection_grants[0].grant_instance_id}
		var file := FileAccess.open(SaveManager.SAVE_DIR+BAD_SLOT+".sav",FileAccess.WRITE)
		file.store_string(JSON.stringify(payload))
		file.close()
		if SaveManager.load_game(BAD_SLOT) or PartyManager.characters.get(str(manifest.owner))!=actor or actor.protection_grants!=manifest.grants or actor.protection_selections!=manifest.selections or actor.numeric_resource_pools!=manifest.pools or actor.ability_scores.to_dict()!=manifest.permanent: return _fail("Malformed protection replaced live state: "+str(case_index))
	# B expires at its original start+60; C remains on its original start+90.
	var b: Dictionary = actor.protection_grants[1]
	var c: Dictionary = actor.protection_grants[2]
	GameManager.advance_campaign_time(int(b.expires_at_seconds)-int(GameManager.campaign_elapsed_seconds))
	if actor.protection_grants.size()!=2 or actor.get_ac()!=19 or actor.ability_scores.get_score("STR")!=17 or actor.protection_grants[0].expires_at_seconds!=c.expires_at_seconds or actor.numeric_resource_pools!=manifest.pools: return _fail("Fresh-process expiry fallback restarted a grant or refilled a pool")
	GameManager.advance_campaign_time(1000)
	if not actor.protection_grants.is_empty() or actor.ability_scores.get_score("STR")!=12 or actor.get_ac()!=12 or actor.numeric_resource_pools!=manifest.pools: return _fail("Large jump failed to restore permanent state without refill")
	print("BATCH G FRESH RELAUNCH PASSED: exact sources, equal-value selection, four spent pools, original clocks, permanent12 beneath setting18, transient menu absent, 14 malformed full-save refusals before replacement, exact expiry fallback; pid="+str(OS.get_process_id()))
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[BatchGFreshRelaunchProbe] "+message)
	get_tree().quit(1)
