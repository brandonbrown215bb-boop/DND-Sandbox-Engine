extends Node

const SLOT := "batch_q_checkpoint"
const MANIFEST := "user://batch_q_manifest.json"

func _ready() -> void:
	GameManager.test_mode=true
	BatchQChecks.load_fixtures()
	if OS.get_environment("BATCH_Q_RELAUNCH_PHASE")=="prepare": _prepare()
	else: _recover()

func _prepare() -> void:
	var file:=FileAccess.open(SaveManager.SAVE_DIR+SLOT+".sav",FileAccess.WRITE)
	if file==null: return _fail("Cannot stage checkpoint")
	file.store_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
	file.close()
	if not SaveManager.load_game(SLOT): return _fail("Base checkpoint refused")
	GameManager.current_state=GameManager.GameState.OVERWORLD
	GameManager.game_in_progress=true
	GameManager.active_dungeon_state.clear()
	var giver:=BatchQChecks.actor("fixture_hero","plain")
	var a:=BatchQChecks.actor("q_saved_a","plain",false)
	var b:=BatchQChecks.actor("q_saved_b","plain",false)
	PartyManager.reset()
	while PlayerManager.get_player_count()<3: PlayerManager.add_player("Party recipient")
	var members: Array=[giver,a,b]
	for index in members.size():
		PlayerManager.set_player_character(index,members[index])
		PartyManager.register_player_character(index,members[index])
	var id:=BatchQChecks.fid("gift","plain")
	var engine:=CapturedGrantRules.new()
	var request:=engine.begin(giver,id,id,CombatTurnBudget.new(),[a,b])
	if not engine.settle(request.request_id,giver,[a.character_id,b.character_id],[a,b]).get("success",false): return _fail("Bonus transfer refused")
	var allocator:=PartyAllocationRules.new()
	id=BatchQChecks.fid("captured_dice","plain")
	request=allocator.begin(giver,id,id,CombatTurnBudget.new(),[a,b])
	var dice: Array=request.dice
	if not allocator.settle(request.request_id,giver,[{"recipient_id":a.character_id,"dice_ids":[dice[2].die_id]}],[a,b]).get("success",false): return _fail("Selected die allocation refused")
	# No new pending choice is durable. Completed pool subset and gift are.
	giver.level=3
	ResourcePoolRules.remove(giver,BatchQChecks.fid("gift","plain"))
	GameManager.advance_campaign_time(17)
	if not SaveManager.save_game(SLOT): return _fail("Allowed checkpoint refused")
	var manifest: Dictionary={"pid":OS.get_process_id(),"clock":GameManager.campaign_elapsed_seconds,"giver":giver.to_dict(),"a":a.to_dict(),"b":b.to_dict()}
	file=FileAccess.open(MANIFEST,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH Q FRESH PREPARED: "+JSON.stringify(manifest))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var events: Array=[]
	var listener:=func(details: Dictionary): events.append(details.duplicate(true))
	Dice.dice_rolled.connect(listener)
	if manifest.pid==OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Distinct-process load refused")
	var giver: Character=PartyManager.characters.get("fixture_hero")
	var a: Character=PartyManager.characters.get("q_saved_a")
	var b: Character=PartyManager.characters.get("q_saved_b")
	if giver==null or a==null or b==null or a.captured_grants!=manifest.a.captured_grants or b.captured_grants!=manifest.b.captured_grants or giver.numeric_resource_pools!=manifest.giver.numeric_resource_pools or GameManager.campaign_elapsed_seconds!=int(manifest.clock) or not events.is_empty(): return _fail("Recovery changed captured bonuses/pool subset/expiry")
	var base: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR+SLOT+".sav"))
	var refused:=0
	for mutation in ["effect","cost","value","deadline","recipient","dice_duplicate","dice_quantity"]:
		for carrier in ["party","players"]:
			var bad:=base.duplicate(true)
			var dto: Dictionary=bad.party.characters.q_saved_a if carrier=="party" else bad.players[1].character
			var gift: Dictionary=dto.captured_grants[0]
			var giver_dto: Dictionary=bad.party.characters.fixture_hero if carrier=="party" else bad.players[0].character
			var pool: Dictionary=giver_dto.numeric_resource_pools[BatchQChecks.fid("captured_dice","plain")]
			match mutation:
				"effect": gift.effect="unavailable_bonus"
				"cost": gift.use_cost="free"
				"value": gift.value=99
				"deadline": gift.expires_at_seconds+=1
				"recipient": gift.recipient_id="missing"
				"dice_duplicate": pool.captured_dice[1]=pool.captured_dice[0].duplicate(true)
				"dice_quantity": pool.current+=1
			var slot: String="batch_q_invalid_"+mutation+"_"+carrier
			var file:=FileAccess.open(SaveManager.SAVE_DIR+slot+".sav",FileAccess.WRITE)
			file.store_string(JSON.stringify(bad))
			file.close()
			var before:=a.to_dict().duplicate(true)
			if SaveManager.load_game(slot) or PartyManager.characters.get("q_saved_a")!=a or a.to_dict()!=before or not events.is_empty(): return _fail("Malformed save replaced session "+slot)
			refused+=1
	var target: Dictionary={"id":"q_recovered_target","name":"Target","armor_class":10,"current_hp":100,"is_alive":true,"conditions":{}}
	var results: Array=[]
	for recipient in [a,b]:
		recipient.reaction_available=true
		var gift: Dictionary=recipient.captured_grants[0].duplicate(true)
		var pending:=BatchQChecks.attack(recipient,target,[{"character":recipient}])
		var count:=events.size()
		var settled:=SpellDamageRolls.settle_weapon_attack_bonus(recipient,target,pending,str(gift.grant_id))
		if settled.get("refused",false) or settled.attack_roll!=int(pending.attack_roll)+int(gift.value) or not recipient.captured_grants.is_empty() or recipient.reaction_available or events.size()!=count: return _fail("Recovered bonus changed value or rolled again")
		results.append({"recipient":recipient.character_id,"original":pending.attack_roll,"bonus":gift.value,"final":settled.attack_roll,"payment":settled.selected_payment})
	# Retained selected-die subset can be used again without regeneration.
	var id:=BatchQChecks.fid("captured_dice","plain")
	var allocator:=PartyAllocationRules.new()
	var request:=allocator.begin(giver,id,id,CombatTurnBudget.new(),[a])
	var die: Dictionary=request.dice[1].duplicate(true)
	var count:=events.size()
	var allocation:=allocator.settle(request.request_id,giver,[{"recipient_id":a.character_id,"dice_ids":[die.die_id]}],[a])
	if not allocation.get("success",false) or allocation.results[0].allocated!=die.face or events.size()!=count: return _fail("Recovered selected die regenerated")
	Dice.dice_rolled.disconnect(listener)
	print("BATCH Q FRESH RELAUNCH PASSED: "+JSON.stringify({"prepare_pid":manifest.pid,"recover_pid":OS.get_process_id(),"clock":GameManager.campaign_elapsed_seconds,"malformed_refusals":refused,"bonuses":results,"allocation":allocation,"remaining_dice":giver.numeric_resource_pools[id].captured_dice}))
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[BatchQFreshRelaunchProbe] "+message)
	get_tree().quit(1)
