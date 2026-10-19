extends Node

const SLOT := "batch_p_checkpoint"
const MANIFEST := "user://batch_p_manifest.json"

func _ready() -> void:
	GameManager.test_mode = true
	BatchPChecks.load_fixtures()
	if OS.get_environment("BATCH_P_RELAUNCH_PHASE") == "prepare": _prepare()
	else: _recover()

func _prepare() -> void:
	var file := FileAccess.open(SaveManager.SAVE_DIR + SLOT + ".sav", FileAccess.WRITE)
	if file == null: return _fail("Cannot stage checkpoint")
	file.store_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
	file.close()
	if not SaveManager.load_game(SLOT): return _fail("Base checkpoint refused")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var giver := BatchPChecks.actor("fixture_hero")
	var a := BatchPChecks.actor("p_saved_a", "plain", false)
	var b := BatchPChecks.actor("p_saved_b", "plain", false)
	PartyManager.reset()
	while PlayerManager.get_player_count()<3: PlayerManager.add_player("Gift recipient")
	var members: Array = [giver,a,b]
	for index in members.size():
		PlayerManager.set_player_character(index,members[index])
		PartyManager.register_player_character(index,members[index])
	for mode in ["stored","token","permission"]:
		if not BatchPChecks.give(giver,[a],mode).get("success",false): return _fail("Transfer refused " + mode)
	if not BatchPChecks.give(giver,[a,b],"shared").get("success",false): return _fail("Shared transfer refused")
	var engine := CapturedGrantRules.new()
	var id := BatchPChecks.feature_id("shared")
	var request := engine.begin(giver,id,id,CombatTurnBudget.new(),[a,b])
	engine.clear()
	if engine.settle(request.request_id,giver,[b.character_id],[a,b]).get("success",true): return _fail("Canceled prompt replayed")
	# Retained payload is independent of giver progression and exact source loss.
	giver.level=3
	giver.ability_scores.wisdom=20
	ResourcePoolRules.remove(giver,BatchPChecks.feature_id("token"))
	ResourcePoolRules.remove(giver,BatchPChecks.feature_id("stored"))
	GameManager.advance_campaign_time(17)
	if not SaveManager.save_game(SLOT): return _fail("Allowed checkpoint refused")
	var manifest := {"pid":OS.get_process_id(),"clock":GameManager.campaign_elapsed_seconds,"giver":giver.to_dict(),"a":a.to_dict(),"b":b.to_dict()}
	file=FileAccess.open(MANIFEST,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH P FRESH PREPARED: " + JSON.stringify(manifest))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var events: Array=[]
	var listener := func(details: Dictionary): events.append(details.duplicate(true))
	Dice.dice_rolled.connect(listener)
	if manifest.pid==OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Distinct-process load refused")
	var giver: Character=PartyManager.characters.get("fixture_hero")
	var a: Character=PartyManager.characters.get("p_saved_a")
	var b: Character=PartyManager.characters.get("p_saved_b")
	if giver==null or a==null or b==null or giver.grant_transfer_serial!=int(manifest.giver.grant_transfer_serial) or a.captured_grants!=manifest.a.captured_grants or b.captured_grants!=manifest.b.captured_grants or giver.numeric_resource_pools!=manifest.giver.numeric_resource_pools or GameManager.campaign_elapsed_seconds!=int(manifest.clock) or not events.is_empty(): return _fail("Recovery changed captured identities/values/pools/deadlines")
	var base: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR+SLOT+".sav"))
	var refused:=0
	for mutation in ["owner","identity","deadline","face","size","value","definition","cost","duplicate","die_payload","serial","group","strip","giver_serial","die_history"]:
		for carrier in ["party","players"]:
			var bad:=base.duplicate(true)
			var dto: Dictionary=bad.party.characters.p_saved_a if carrier=="party" else bad.players[1].character
			var gift: Dictionary=dto.captured_grants[0]
			match mutation:
				"owner":gift.recipient_id="missing"
				"identity":gift.grant_id="forged"
				"deadline":gift.expires_at_seconds+=1
				"face":gift.die.face=99
				"size":gift.die_size=3
				"value":gift.value=0
				"definition":gift.feature_id="missing"
				"cost":gift.use_cost="free"
				"duplicate":dto.captured_grants.append(gift.duplicate(true))
				"die_payload":gift.die=false
				"serial":gift.serial=0
				"group":dto.captured_grants[-1].value=1 if int(dto.captured_grants[-1].value)!=1 else 2
				"strip":dto.erase("captured_grants")
				"die_history":
					var giver_dto: Dictionary=bad.party.characters.fixture_hero if carrier=="party" else bad.players[0].character
					giver_dto.transferred_die_serials={}
				"giver_serial":
					var giver_dto: Dictionary=bad.party.characters.fixture_hero if carrier=="party" else bad.players[0].character
					giver_dto.grant_transfer_serial=0
			var slot: String="batch_p_invalid_"+mutation+"_"+carrier
			var file:=FileAccess.open(SaveManager.SAVE_DIR+slot+".sav",FileAccess.WRITE)
			file.store_string(JSON.stringify(bad))
			file.close()
			var before:=a.to_dict().duplicate(true)
			if SaveManager.load_game(slot) or PartyManager.characters.get("p_saved_a")!=a or a.to_dict()!=before or not events.is_empty(): return _fail("Malformed load replaced session "+slot)
			refused+=1
	var receipts: Array=[]
	var shared_a: Dictionary=a.captured_grants[-1].duplicate(true)
	var shared_b: Dictionary=b.captured_grants[0].duplicate(true)
	for gift in a.captured_grants.duplicate(true):
		var result:=CapturedGrantRules.use(a,str(gift.grant_id),CombatTurnBudget.new())
		if not result.get("success",false): return _fail("Recovered recipient gift refused")
		receipts.append(result)
		if CapturedGrantRules.use(a,str(gift.grant_id),CombatTurnBudget.new()).get("success",true): return _fail("Recovered gift replayed")
	if b.captured_grants[0]!=shared_b or shared_a.value!=shared_b.value or not events.is_empty(): return _fail("Recipient spending changed sibling/shared roll")
	var newer:=BatchPChecks.give(giver,[a],"permission")
	if not newer.get("success",false) or int(newer.grants[0].serial)!=5 or int(newer.grants[0].expires_at_seconds)!=77: return _fail("Reload restarted giver serial or new grant deadline")
	GameManager.advance_campaign_time(42)
	if b.captured_grants.size()!=1: return _fail("Gift expired early")
	GameManager.advance_campaign_time(1)
	if a.captured_grants.size()!=1 or not b.captured_grants.is_empty() or CapturedGrantRules.use(b,str(shared_b.grant_id),CombatTurnBudget.new()).get("success",true): return _fail("Original deadline restarted")
	if not events.is_empty(): return _fail("Recovered use/expiry unexpectedly rolled")
	var stored_id:=BatchPChecks.feature_id("stored")
	if not ResourcePoolRules.acquire(giver,giver.get_feature(stored_id),stored_id).get("success",false) or int(giver.numeric_resource_pools[stored_id].captured_dice[0].serial)<=4: return _fail("Reload/reacquisition reused transferred die identity")
	print("BATCH P FRESH RELAUNCH PASSED: "+JSON.stringify({"pid":OS.get_process_id(),"full_saves_refused":refused,"shared_value":shared_a.value,"receipts":receipts,"clock":GameManager.campaign_elapsed_seconds,"rng_events_before_reacquisition":0,"reacquisition_rng_events":events.size(),"first_new_die":giver.numeric_resource_pools[stored_id].captured_dice[0]}))
	Dice.dice_rolled.disconnect(listener)
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[BatchPFreshRelaunchProbe] "+message)
	get_tree().quit(1)
