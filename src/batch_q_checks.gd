class_name BatchQChecks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_q_party.json", "class")

static func fid(mode: String, suffix: String) -> String:
	return "fixture:q_%s_%s" % [mode, suffix]

static func actor(id: String, suffix: String, acquire: bool = true) -> Character:
	var c := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"STR":12,"DEX":20,"CON":14,"INT":18,"WIS":16,"CHA":12})
	c.initialize(id, "human", "fixture:q_class_"+suffix, scores)
	c.character_id = id
	c.max_hp = 100
	c.current_hp = 1
	c.willingness = "willing"
	if acquire:
		for feature in c.features: ResourcePoolRules.acquire(c, feature, str(feature.id))
	return c

static func weapon() -> Dictionary:
	return {"id":"fixture:q_blade", "type":"weapon", "damage":"1", "damage_type":"slashing", "ability":"STR", "range":1, "attack_bonus_override":0}

static func attack(c: Character, target: Dictionary, players: Array) -> Dictionary:
	FighterChecks._seed_die(20, 9)
	return CombatAction.resolve_weapon_attack(c,target,weapon(),false,false,{"allow_weapon_attack_bonus":true,"players":players,"monsters":[target]})

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "Q: plain/renamed definitions load " + str(DataLoader.get_load_errors()))
	var old_turn := CombatAction.active_turn_serial
	var old_clock := GameManager.campaign_elapsed_seconds
	GameManager.campaign_elapsed_seconds = 0
	for suffix in ["plain", "changed"]:
		var giver := actor("q_giver_"+suffix,suffix)
		var a := actor("q_a_"+suffix,suffix,false)
		var b := actor("q_b_"+suffix,suffix,false)
		var live: Array = [giver,a,b]
		var events: Array = []
		var listener := func(details: Dictionary): events.append(details.duplicate(true))
		Dice.dice_rolled.connect(listener)
		var engine := PartyAllocationRules.new()
		var id := fid("fixed_total",suffix)
		var budget := CombatTurnBudget.new()
		var before := giver.to_dict().duplicate(true)
		var request := engine.begin(giver,id,id,budget,live)
		check.call(not request.is_empty() and giver.to_dict()==before and events.is_empty(), "Q: fixed begin is pure "+suffix)
		var result := engine.settle(request.request_id,giver,[{"recipient_id":a.character_id,"amount":4},{"recipient_id":b.character_id,"amount":3}],live)
		check.call(result.get("success",false) and result.used==7 and result.total==int(giver.get_feature(id).allocation.total_formula) and not budget.bonus_action_available and giver.numeric_resource_pools[id].current==3 and events.is_empty(), "Q: fixed integer split spends original source/action once "+suffix)
		check.call((a.current_hp==5 and b.current_hp==4) if suffix=="plain" else (a.temp_hp==4 and b.temp_hp==3), "Q: split has actual per-recipient consequences "+suffix)
		check.call(not engine.settle(request.request_id,giver,[{"recipient_id":a.character_id,"amount":1}],live).get("success",true), "Q: completed allocation refuses replay "+suffix)
		for mutation in ["cap","total","duplicate","count","fraction","wrong_owner","same_id","unwilling","turn","clock","pool","budget","source"]:
			budget=CombatTurnBudget.new()
			request=engine.begin(giver,id,id,budget,live)
			var rows: Array=[{"recipient_id":a.character_id,"amount":4}]
			var settlement_actor := giver
			var members: Array = live.duplicate()
			before=giver.to_dict().duplicate(true)
			var hp_before := a.to_dict().duplicate(true)
			match mutation:
				"cap": rows[0].amount=8
				"total": rows=[{"recipient_id":a.character_id,"amount":7},{"recipient_id":b.character_id,"amount":7}]
				"duplicate": rows.append(rows[0].duplicate(true))
				"count": rows.append({"recipient_id":b.character_id,"amount":1}); rows.append({"recipient_id":giver.character_id,"amount":1})
				"fraction": rows[0].amount=1.5
				"wrong_owner": settlement_actor=b
				"same_id": members=[giver,actor(a.character_id,suffix,false),b]
				"unwilling": a.willingness="unknown"
				"turn": CombatAction.active_turn_serial+=1
				"clock": GameManager.campaign_elapsed_seconds+=1
				"pool": giver.numeric_resource_pools[id].current-=1
				"budget": budget.bonus_action_available=false
				"source":
					ResourcePoolRules.remove(giver,id)
					ResourcePoolRules.acquire(giver,giver.get_feature(id),id)
			var source_before := giver.to_dict().duplicate(true)
			var rolls_before := events.size()
			result=engine.settle(request.request_id,settlement_actor,rows,members)
			check.call(not result.get("success",true) and giver.to_dict()==source_before and events.size()==rolls_before and a.current_hp==hp_before.current_hp and a.temp_hp==hp_before.temp_hp, "Q: invalid allocation refuses atomically "+mutation+" "+suffix)
			a.willingness="willing"
			GameManager.campaign_elapsed_seconds=0
			CombatAction.active_turn_serial=old_turn
			giver.numeric_resource_pools[id].current=4
			engine.clear()
		budget=CombatTurnBudget.new()
		request=engine.begin(giver,id,id,budget,live)
		before=giver.to_dict().duplicate(true)
		result=engine.settle(request.request_id,giver,[],live)
		check.call(result.get("declined",false) and giver.to_dict()==before and budget.bonus_action_available, "Q: fixed cancel pays nothing "+suffix)
		var fixed_feature := giver.get_feature(id)
		fixed_feature.allocation.unspent_policy="require_full"
		budget=CombatTurnBudget.new()
		request=engine.begin(giver,id,id,budget,live)
		before=giver.to_dict().duplicate(true)
		result=engine.settle(request.request_id,giver,[{"recipient_id":a.character_id,"amount":1}],live)
		check.call(not result.get("success",true) and giver.to_dict()==before and budget.bonus_action_available,"Q: require-full remainder refuses without partial payment "+suffix)
		request=engine.begin(giver,id,id,budget,live)
		var half := int(request.total)/2
		result=engine.settle(request.request_id,giver,[{"recipient_id":a.character_id,"amount":half},{"recipient_id":b.character_id,"amount":int(request.total)-half}],live)
		check.call(result.get("success",false) and result.unspent==0,"Q: require-full exact integer split commits once "+suffix)
		fixed_feature.allocation.unspent_policy="forfeit"
		budget=CombatTurnBudget.new()
		request=engine.begin(giver,id,id,budget,live)
		before=giver.to_dict().duplicate(true)
		engine.clear()
		check.call(not engine.settle(request.request_id,giver,[{"recipient_id":a.character_id,"amount":1}],live).get("success",true) and giver.to_dict()==before and budget.bonus_action_available,"Q: allocation teardown revokes authority without spending "+suffix)
		id=fid("rolled_total",suffix)
		budget=CombatTurnBudget.new()
		var roll_count := events.size()
		request=engine.begin(giver,id,id,budget,live)
		check.call(events.size()==roll_count+1 and giver.numeric_resource_pools[id].current==3 and not budget.bonus_action_available and request.total==int(events[-1].total), "Q: rolled total captures one roll and original payment at reveal "+suffix)
		result=engine.settle(request.request_id,giver,[],live)
		check.call(result.get("forfeited",false) and giver.numeric_resource_pools[id].current==3 and events.size()==roll_count+1, "Q: rolled cancel cannot refund/fish for a free roll "+suffix)
		budget=CombatTurnBudget.new()
		request=engine.begin(giver,id,id,budget,live)
		var first := mini(7,int(request.total))
		var rows: Array=[{"recipient_id":a.character_id,"amount":first}]
		if int(request.total)>first: rows.append({"recipient_id":b.character_id,"amount":int(request.total)-first})
		result=engine.settle(request.request_id,giver,rows,live)
		check.call(result.get("success",false) and result.used==request.total and events.size()==roll_count+2 and giver.numeric_resource_pools[id].current==2, "Q: one captured rolled total split without per-target rerolls/payment "+suffix)
		id=fid("captured_dice",suffix)
		budget=CombatTurnBudget.new()
		request=engine.begin(giver,id,id,budget,live)
		var dice: Array=request.dice
		before=giver.to_dict().duplicate(true)
		roll_count=events.size()
		result=engine.settle(request.request_id,giver,[{"recipient_id":a.character_id,"dice_ids":[dice[2].die_id]},{"recipient_id":b.character_id,"dice_ids":[dice[2].die_id]}],live)
		check.call(not result.get("success",true) and giver.to_dict()==before and budget.bonus_action_available and events.size()==roll_count, "Q: duplicate die across recipients refuses before any spend "+suffix)
		request=engine.begin(giver,id,id,budget,live)
		result=engine.settle(request.request_id,giver,[{"recipient_id":a.character_id,"dice_ids":[dice[2].die_id]},{"recipient_id":b.character_id,"dice_ids":[dice[0].die_id]}],live)
		check.call(result.get("success",false) and result.results[0].allocated==dice[2].face and result.results[1].allocated==dice[0].face and giver.numeric_resource_pools[id].captured_dice==[dice[1],dice[3]] and giver.numeric_resource_pools[id].current==2 and events.size()==roll_count and not budget.bonus_action_available, "Q: selected non-prefix dice retain faces and untouched identities "+suffix)
		_bonus_checks(check,giver,a,b,suffix,events)
		for mode in ["fixed_total","rolled_total","captured_dice"]:
			var f := giver.get_feature(fid(mode,suffix)).duplicate(true)
			for mutation in ["field","mode","cap","cancel","effect"]:
				var bad := f.duplicate(true)
				match mutation:
					"field": bad.allocation.unknown=true
					"mode": bad.allocation.mode="reroll_each"
					"cap": bad.allocation.per_target_cap=0
					"cancel": bad.allocation.cancel_policy="refund_reveal"
					"effect": bad.allocation.effect="cast_spell"
				check.call(not ClassFeature.content_error(bad).is_empty(), "Q: malformed allocation rejected "+mode+"/"+mutation+" "+suffix)
		Dice.dice_rolled.disconnect(listener)
	SpellDamageRolls.clear_pending_requests()
	CombatAction.active_turn_serial=old_turn
	GameManager.campaign_elapsed_seconds=old_clock

static func _bonus_checks(check: Callable, giver: Character, a: Character, b: Character, suffix: String, events: Array) -> void:
	var id := fid("gift",suffix)
	var engine := CapturedGrantRules.new()
	var req := engine.begin(giver,id,id,CombatTurnBudget.new(),[a,b])
	var count := events.size()
	var gifts := engine.settle(req.request_id,giver,[a.character_id,b.character_id],[a,b])
	check.call(gifts.get("success",false) and events.size()==count+1 and a.captured_grants[0].value==b.captured_grants[0].value, "Q/S083: one shared bonus face captured for both recipients "+suffix)
	var gift: Dictionary=a.captured_grants[0].duplicate(true)
	var sibling: Dictionary=b.captured_grants[0].duplicate(true)
	var players: Array=[{"character":a},{"character":b},{"character":giver}]
	# Hide helpers so this first roll proves the recipient's independent budget.
	giver.reaction_available=false
	b.reaction_available=false
	a.reaction_available=true
	var target := {"id":"q_target_"+suffix,"name":"Target","armor_class":10,"current_hp":100,"is_alive":true,"conditions":{}}
	var pending := attack(a,target,players)
	check.call(pending.has("weapon_attack_bonus_request"), "Q/S083: real weapon resolver offers stored bonus "+suffix)
	if not pending.has("weapon_attack_bonus_request"): return
	var original := int(pending.attack_roll)
	count=events.size()
	var result := SpellDamageRolls.settle_weapon_attack_bonus(a,target,pending,str(gift.grant_id))
	check.call(not result.get("refused",false) and int(result.attack_roll)==original+int(gift.value) and a.captured_grants.is_empty() and not a.reaction_available and b.captured_grants[0]==sibling and result.selected_payment.owner_id==a.character_id and events.size()==count, "Q/S083: captured face modifies actual roll, recipient Reaction only, no reroll "+suffix)
	check.call(SpellDamageRolls.settle_weapon_attack_bonus(a,target,pending,str(gift.grant_id)).get("refused",false), "Q/S083: completed bonus refuses replay "+suffix)
	b.reaction_available=true
	pending=attack(b,target,[{"character":b}])
	count=events.size()
	result=SpellDamageRolls.settle_weapon_attack_bonus(b,target,pending,str(sibling.grant_id))
	check.call(not result.get("refused",false) and b.captured_grants.is_empty() and not b.reaction_available and events.size()==count and result.selected_payment.captured_value==gift.value, "Q/S083: second beneficiary independently uses original shared face "+suffix)
	# Another actor contributes one fixed modifier through the same occurrence.
	var help_id := fid("help",suffix)
	for mutation in ["wrong_owner","missing_reaction","source","replacement","turn","clock","unwilling","changed_definition","decline","success"]:
		giver.reaction_available=true
		a.reaction_available=false # An ally can help even after the attacker's Reaction is spent.
		players=[{"character":a},{"character":giver}]
		pending=attack(a,target,players)
		check.call(pending.has("weapon_attack_bonus_request"), "Q: eligible helper offered "+mutation+" "+suffix)
		if not pending.has("weapon_attack_bonus_request"): continue
		var record := SpellDamageRolls.weapon_attack_bonus_record(a,target,pending)
		var selected := str(record.options[0].source_instance_id)
		var before := giver.to_dict().duplicate(true)
		var old_turn := CombatAction.active_turn_serial
		match mutation:
			"missing_reaction": giver.reaction_available=false
			"source":
				ResourcePoolRules.remove(giver,help_id)
				ResourcePoolRules.acquire(giver,giver.get_feature(help_id),help_id)
			"replacement": players[1]["character"]=actor(giver.character_id,suffix)
			"turn": CombatAction.active_turn_serial+=1
			"clock": GameManager.campaign_elapsed_seconds+=1
			"unwilling": giver.willingness="unknown"
			"changed_definition": giver.get_feature(help_id).roll_intervention.amount+=1
		count=events.size()
		var live_before := giver.to_dict().duplicate(true)
		result=SpellDamageRolls.settle_weapon_attack_bonus(giver if mutation=="wrong_owner" else a,target,pending,"" if mutation=="decline" else selected)
		if mutation=="success":
			check.call(not result.get("refused",false) and result.attack_roll==int(pending.attack_roll)+int(giver.get_feature(help_id).roll_intervention.amount) and giver.numeric_resource_pools[help_id].current==int(before.numeric_resource_pools[help_id].current)-1 and not giver.reaction_available and not a.reaction_available and events.size()==count and result.selected_payment.owner_id==giver.character_id, "Q: helper owns exact payment/Reaction and captured attack resumes once "+suffix)
		elif mutation=="decline":
			check.call(not result.get("refused",false) and result.attack_roll==pending.attack_roll and giver.to_dict()==live_before and events.size()==count, "Q: decline keeps captured miss without helper payment "+suffix)
		else:
			check.call(result.get("refused",false) and giver.to_dict()==live_before and events.size()==count, "Q: stale/wrong helper answer refuses before payment "+mutation+" "+suffix)
		giver.willingness="willing"
		if mutation=="changed_definition": giver.get_feature(help_id).roll_intervention.amount-=1
		CombatAction.active_turn_serial=old_turn
		GameManager.campaign_elapsed_seconds=0
		SpellDamageRolls.clear_pending_requests()
	# Expiry during a visible bonus request cannot consume an old gift or change its roll.
	giver.reaction_available=false
	var gift_id := fid("gift",suffix)
	var transfer := CapturedGrantRules.new()
	var request := transfer.begin(giver,gift_id,gift_id,CombatTurnBudget.new(),[a])
	transfer.settle(request.request_id,giver,[a.character_id],[a])
	a.reaction_available=true
	var expired: Dictionary=a.captured_grants[0].duplicate(true)
	pending = attack(a,target,[{"character":a}])
	GameManager.campaign_elapsed_seconds=int(expired.expires_at_seconds)
	count = events.size()
	var before := a.to_dict().duplicate(true)
	var settled := SpellDamageRolls.settle_weapon_attack_bonus(a,target,pending,str(expired.grant_id))
	check.call(settled.get("refused",false) and a.to_dict()==before and events.size()==count,"Q/S083: expiry during pending attack refuses without reroll/recipient payment "+suffix)
	SpellDamageRolls.clear_pending_requests()
	check.call(SpellDamageRolls.settle_weapon_attack_bonus(a,target,pending,str(expired.grant_id)).get("refused",false) and a.to_dict()==before,"Q/S083: host teardown revokes old bonus answer "+suffix)
	GameManager.campaign_elapsed_seconds=0
