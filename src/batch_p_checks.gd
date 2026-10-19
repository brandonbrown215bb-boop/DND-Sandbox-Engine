class_name BatchPChecks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_p_grants.json", "class")

static func feature_id(mode: String, suffix: String = "plain") -> String:
	return "fixture:p_%s_%s" % [mode, suffix]

static func actor(id: String, suffix: String = "plain", acquire: bool = true) -> Character:
	var c := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"STR":12,"DEX":20,"CON":14,"INT":18,"WIS":16,"CHA":12})
	c.initialize(id, "human", "fixture:p_class_" + suffix, scores)
	c.character_id = id
	c.max_hp = 100
	c.current_hp = 1
	c.willingness = "willing"
	if acquire:
		for feature in c.features: ResourcePoolRules.acquire(c, feature, str(feature.id))
	return c

static func give(giver: Character, recipients: Array, mode: String, suffix: String = "plain") -> Dictionary:
	var budget := CombatTurnBudget.new()
	var engine := CapturedGrantRules.new()
	var id := feature_id(mode, suffix)
	var request := engine.begin(giver, id, id, budget, recipients)
	if request.is_empty(): return {"success":false}
	var ids: Array = []
	for c in recipients: ids.append(c.character_id)
	return engine.settle(request.request_id, giver, ids, recipients)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "P: neutral/renamed definitions load " + str(DataLoader.get_load_errors()))
	for suffix in ["plain", "changed"]:
		var giver := actor("p_giver_" + suffix, suffix)
		var a := actor("p_a_" + suffix, suffix, false)
		var b := actor("p_b_" + suffix, suffix, false)
		var events: Array = []
		var listener := func(details: Dictionary): events.append(details.duplicate(true))
		Dice.dice_rolled.connect(listener)
		var engine := CapturedGrantRules.new()
		var budget := CombatTurnBudget.new()
		var id := feature_id("stored", suffix)
		var pool: Dictionary = giver.numeric_resource_pools[id].duplicate(true)
		var before := giver.to_dict().duplicate(true)
		var request := engine.begin(giver, id, id, budget, [a])
		check.call(not request.is_empty() and giver.to_dict() == before and a.captured_grants.is_empty() and events.is_empty(), "P: opening transfer is pure " + suffix)
		check.call(engine.settle(request.request_id, giver, [], [a]).get("declined", false) and giver.to_dict() == before and budget.bonus_action_available, "P: decline keeps exact pool/action " + suffix)
		request = engine.begin(giver, id, id, budget, [a])
		var newer := engine.begin(giver, id, id, budget, [a])
		check.call(not engine.settle(request.request_id, giver, [a.character_id], [a]).get("success",true), "P: old answer cannot settle newer prompt " + suffix)
		check.call(not engine.settle(newer.request_id, actor(giver.character_id,suffix,false), [a.character_id], [a]).get("success",true), "P: same ID wrong giver object refuses " + suffix)
		var result := engine.settle(newer.request_id, giver, [a.character_id], [a])
		check.call(result.get("success",false) and a.captured_grants.size() == 1 and a.captured_grants[0].die == pool.captured_dice[0] and giver.numeric_resource_pools[id].captured_dice == pool.captured_dice.slice(1) and not budget.bonus_action_available and events.is_empty(), "P: exact oldest die moves with face/size/identity and one giver budget " + suffix)
		before = giver.to_dict().duplicate(true)
		check.call(not engine.settle(newer.request_id,giver,[b.character_id],[a,b]).get("success",true) and giver.to_dict()==before and b.captured_grants.is_empty(), "P: completed transfer replay refuses " + suffix)
		var gift: Dictionary = a.captured_grants[0].duplicate(true)
		giver.level = 5
		giver.ability_scores.wisdom = 20
		ResourcePoolRules.remove(giver,id)
		check.call(CapturedGrantRules.query(a)[0] == gift and not CapturedGrantRules.query(a)[0].die.is_empty(), "P: giver progression/removal does not rewrite existing gift " + suffix)
		var receiver_budget := CombatTurnBudget.new()
		receiver_budget.bonus_action_available = false
		check.call(not CapturedGrantRules.use(a,gift.grant_id,receiver_budget).get("success",true) and a.current_hp==1 and a.captured_grants.size()==1, "P: recipient must pay its own Bonus Action " + suffix)
		receiver_budget.bonus_action_available = true
		result = CapturedGrantRules.use(a,gift.grant_id,receiver_budget)
		check.call(result.get("success",false) and a.current_hp==1+int(gift.value) and not receiver_budget.bonus_action_available and events.is_empty(), "P: recipient uses original captured die without RNG " + suffix)
		check.call(not CapturedGrantRules.use(a,gift.grant_id,CombatTurnBudget.new()).get("success",true), "P: spent gift replay refuses " + suffix)
		# Shared value: one original payment and one roll, independent recipient uses.
		var shared_id := feature_id("shared",suffix)
		giver.ability_scores.wisdom = 16
		result = give(giver,[a,b],"shared",suffix)
		check.call(result.get("success",false) and events.size()==1 and a.captured_grants[0].group_id == b.captured_grants[0].group_id and a.captured_grants[0].value == b.captured_grants[0].value and giver.numeric_resource_pools[shared_id].current == 3, "P: shared die rolls/pays once for both recipients " + suffix)
		gift = a.captured_grants[0].duplicate(true)
		var b_gift: Dictionary = b.captured_grants[0].duplicate(true)
		a.reaction_available = false
		check.call(not CapturedGrantRules.use(a,gift.grant_id,CombatTurnBudget.new()).get("success",true) and b.captured_grants[0]==b_gift, "P: missing recipient Reaction preserves both gifts " + suffix)
		a.reaction_available = true
		var original_hp := a.current_hp
		var receiver := CombatTurnBudget.new()
		CapturedGrantRules.use(a,gift.grant_id,receiver)
		check.call(a.current_hp == original_hp+int(gift.value) and not a.reaction_available and receiver.action_available and receiver.bonus_action_available and b.captured_grants[0]==b_gift and events.size()==1, "P: one recipient Reaction does not spend sibling budgets/rolls " + suffix)
		# Both formula carriers snapshot their declared ability, distinct action consumers.
		for mode in ["token","permission"]:
			result = give(giver,[a],mode,suffix)
			gift = a.captured_grants[-1].duplicate(true)
			var value := 3 if suffix=="plain" else 4
			giver.ability_scores.wisdom = 20
			giver.ability_scores.intelligence = 20
			check.call(result.get("success",false) and gift.value==value and CapturedGrantRules.saved_error(a.to_dict(),int(GameManager.campaign_elapsed_seconds)).is_empty(), "P: captured "+mode+" permission retains authored generation value " + suffix)
			var action_budget := CombatTurnBudget.new()
			original_hp = a.current_hp
			CapturedGrantRules.use(a,gift.grant_id,action_budget)
			check.call(not action_budget.action_available and ((mode=="token" and a.temp_hp==value) or (mode=="permission" and a.current_hp==original_hp+value)) and events.size()==1, "P: captured "+mode+" consumes recipient Action once " + suffix)
			giver.ability_scores.wisdom = 16
			giver.ability_scores.intelligence = 18
		# Revalidate mutable sources, selected recipient object, willingness and budget.
		for mutation in ["source","pool","recipient","willingness","definition","budget","turn","clear","duplicate"]:
			var f := giver.get_feature(shared_id)
			budget = CombatTurnBudget.new()
			request = engine.begin(giver,shared_id,shared_id,budget,[a,b])
			before = giver.to_dict().duplicate(true)
			var live: Array = [a,b]
			var ids: Array = [a.character_id]
			match mutation:
				"source":
					ResourcePoolRules.remove(giver,shared_id)
					ResourcePoolRules.acquire(giver,f,shared_id)
				"pool": giver.numeric_resource_pools[shared_id].current -= 1
				"recipient": live = [actor(a.character_id,suffix,false),b]
				"willingness": a.willingness="unknown"
				"definition": f.transfer_grant.duration_seconds += 1
				"budget": budget.bonus_action_available=false
				"turn": CombatAction.active_turn_serial+=1
				"clear": engine.clear()
				"duplicate": ids.append(a.character_id)
			var now := giver.to_dict().duplicate(true)
			var count := events.size()
			var recipient_before := a.to_dict().duplicate(true)
			check.call(not engine.settle(request.get("request_id",""),giver,ids,live).get("success",true) and giver.to_dict()==now and a.to_dict()==recipient_before and events.size()==count, "P: stale/invalid " + mutation + " refuses without costs/RNG " + suffix)
			a.willingness="willing"
			if mutation=="definition": f.transfer_grant.duration_seconds-=1
			if mutation=="pool": giver.numeric_resource_pools[shared_id].current+=1
		# Duplicate faces remain separate exact transferred dice.
		ResourcePoolRules.acquire(giver,giver.get_feature(id),id)
		giver.numeric_resource_pools[id].captured_dice[0].face=1
		giver.numeric_resource_pools[id].captured_dice[1].face=1
		give(giver,[a],"stored",suffix)
		give(giver,[a],"stored",suffix)
		var last: Dictionary = a.captured_grants[-1]
		var prior: Dictionary = a.captured_grants[-2]
		check.call(last.value==prior.value and last.die.die_id!=prior.die.die_id and last.grant_id!=prior.grant_id, "P: equal faces retain independent gift/die identity " + suffix)
		var last_serial := int(giver.numeric_resource_pools[id].die_serial)
		ResourcePoolRules.remove(giver,id)
		ResourcePoolRules.acquire(giver,giver.get_feature(id),id)
		check.call(int(giver.numeric_resource_pools[id].captured_dice[0].serial)>last_serial and giver.transferred_die_serials[id]==giver.numeric_resource_pools[id].die_serial, "P: reacquisition cannot regenerate transferred die identities " + suffix)
		var overflow := actor("p_overflow_"+suffix,suffix,false)
		overflow.transferred_die_serials[id]=2147483647
		var count_before:=events.size()
		check.call(not ResourcePoolRules.acquire(overflow,overflow.get_feature(id),id).get("success",true) and overflow.numeric_resource_pools.is_empty() and events.size()==count_before, "P: exhausted identity serial refuses acquisition before RNG " + suffix)
		var restored := Character.new()
		restored.from_dict(a.to_dict())
		check.call(restored.captured_grants == a.captured_grants, "P: DTO restore preserves grants without regeneration " + suffix)
		for mutation in ["recipient","identity","deadline","value","face","size","kind","cost","source","duplicate","serial","payload"]:
			var bad := a.to_dict().duplicate(true)
			var record: Dictionary = bad.captured_grants[-1]
			match mutation:
				"recipient": record.recipient_id="other"
				"identity": record.grant_id="forged"
				"deadline": record.expires_at_seconds+=1
				"value": record.value=0
				"face": record.die.face=99
				"size": record.die_size=3
				"kind": record.kind="spell"
				"cost": record.use_cost="free"
				"source": record.source_instance_id="wrong"
				"duplicate": bad.captured_grants.append(record.duplicate(true))
				"serial": bad.grant_transfer_serial=-1
				"payload": record.die=false
			check.call(not CapturedGrantRules.saved_error(bad,int(GameManager.campaign_elapsed_seconds)).is_empty(), "P: malformed captured DTO refuses " + mutation + " " + suffix)
		var old_clock := int(GameManager.campaign_elapsed_seconds)
		GameManager.campaign_elapsed_seconds = int(last.expires_at_seconds)-1
		check.call(CapturedGrantRules.query(a).any(func(g): return g.grant_id==last.grant_id), "P: original deadline still live one second before " + suffix)
		GameManager.campaign_elapsed_seconds += 1
		check.call(not CapturedGrantRules.use(a,last.grant_id,CombatTurnBudget.new()).get("success",true), "P: exact original deadline refuses use " + suffix)
		CapturedGrantRules.prune(a,int(GameManager.campaign_elapsed_seconds))
		check.call(a.captured_grants.is_empty(), "P: expiry removes only expired recipient gifts " + suffix)
		GameManager.campaign_elapsed_seconds = old_clock
		Dice.dice_rolled.disconnect(listener)
	var template: Dictionary = DataLoader.get_character_class("fixture:p_class_plain").features_by_level["1"][1]
	for mutation in ["field","mode","effect","cost","duration","count","die","mixed"]:
		var bad := template.duplicate(true)
		match mutation:
			"field": bad.transfer_grant.unknown=true
			"mode": bad.transfer_grant.value_policy="reroll_each"
			"effect": bad.transfer_grant.effect="cast_spell"
			"cost": bad.transfer_grant.use_cost="free"
			"duration": bad.transfer_grant.duration_seconds=0
			"count": bad.transfer_grant.max_recipients=5
			"die": bad.transfer_grant.die_size=3
			"mixed": bad.effects=[{"type":"heal","amount":1}]
		check.call(not ClassFeature.content_error(bad).is_empty(), "P: unsupported definition refuses " + mutation)
	var stored: Dictionary = DataLoader.get_character_class("fixture:p_class_plain").features_by_level["1"][0].duplicate(true)
	stored.resource_pool.spend_choice = {"minimum":2,"maximum":2}
	check.call(not ClassFeature.content_error(stored).is_empty(), "P: one-die transfer cannot bypass an authored two-die minimum")
	DataLoader.load_all_data()
