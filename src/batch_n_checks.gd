class_name BatchNChecks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_n_recovery.json", "class")

static func source(kind: String, suffix: String = "plain") -> String:
	return "fixture:n_%s_%s" % [kind, suffix]

static func actor(suffix: String = "plain") -> Character:
	var c := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"STR":12,"DEX":20,"CON":14,"INT":12,"WIS":16,"CHA":12})
	c.initialize("Recovery " + suffix, "human", "fixture:n_class_" + suffix, scores)
	c.character_id = "n_owner_" + suffix
	for feature in c.features:
		if feature.has("resource_pool"): ResourcePoolRules.acquire(c, feature, str(feature.id))
	ResourcePoolRules.acquire(c, c.get_feature(source("fixed",suffix)), "sibling")
	return c

static func quantity(c: Character, kind: String, suffix: String = "plain") -> int:
	return int(c.numeric_resource_pools[source(kind,suffix)].current)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "N: neutral and renamed recovery definitions load " + str(DataLoader.get_load_errors()))
	for suffix in ["plain","changed"]:
		var c := actor(suffix)
		var fixed := 1 if suffix == "plain" else 2
		var floor_amount := 2 if suffix == "plain" else 3
		var engine := CombatPoolRecovery.new()
		var before := c.to_dict().duplicate(true)
		check.call(engine.begin(c,"location_changed",0).is_empty() and c.to_dict() == before, "N: location changes are not recovery events " + suffix)
		check.call(not ResourcePoolRules.recover(c,c.get_feature(source("fixed",suffix)),source("fixed",suffix),"turn_started").get("success",true), "N: rest adapter cannot manufacture combat boundaries " + suffix)
		var requests := engine.begin(c,"initiative_rolled",0)
		check.call(requests.size() == 1 and requests[0].offers.size() == 2 and quantity(c,"floor",suffix) == floor_amount and quantity(c,"fixed",suffix) == 0 and quantity(c,"fill",suffix) == 0, "N: Initiative recovers only declared floor and offers one exclusive group " + suffix)
		if requests.is_empty(): continue
		var request: Dictionary = requests[0]
		var impostor := actor(suffix)
		check.call(not engine.settle(request.request_id,impostor,"0").get("success",true) and quantity(c,"choice_a",suffix) == 0, "N: same ID on wrong actor cannot settle " + suffix)
		check.call(not engine.settle(request.request_id,c,"forged").get("success",true), "N: unknown selection has no effect " + suffix)
		# Public offers are presentation, never the canonical amount or source.
		request.offers[0].amount = 100
		request.offers[0].source_instance_id = source("floor",suffix)
		var result := engine.settle(request.request_id,c,"0")
		check.call(result.get("success",false) and quantity(c,"choice_a",suffix) == fixed+1 and quantity(c,"choice_b",suffix) == 0 and result.get("before") == 0, "N: one canonical choice recovers exact source and authored amount " + suffix)
		before = c.to_dict().duplicate(true)
		check.call(not engine.settle(request.request_id,c,"1").get("success",true) and engine.begin(c,"initiative_rolled",0).is_empty() and c.to_dict() == before, "N: replay cannot choose sibling or emit Initiative again " + suffix)
		requests = engine.begin(c,"turn_started",1)
		check.call(quantity(c,"fixed",suffix) == fixed and int(c.numeric_resource_pools.sibling.current) == fixed and quantity(c,"fill",suffix) == 4+fixed and quantity(c,"floor",suffix) == floor_amount+1, "N: actual turn fixed/fill/floor retain exact sources and declared event amounts " + suffix)
		request = requests[0]
		check.call(engine.settle(request.request_id,c,"").get("declined",false), "N: decline closes group " + suffix)
		ResourcePoolRules.spend(c,source("fixed",suffix),fixed)
		before = c.to_dict().duplicate(true)
		check.call(engine.begin(c,"turn_started",1).is_empty() and c.to_dict() == before, "N: budget reset/re-entered same turn cannot refill spent quantity " + suffix)
		requests = engine.begin(c,"turn_started",2)
		request = requests[0]
		var chosen := source("choice_b",suffix)
		ResourcePoolRules.remove(c,chosen)
		ResourcePoolRules.acquire(c,c.get_feature(chosen),chosen)
		check.call(not engine.settle(request.request_id,c,"1").get("success",true) and quantity(c,"choice_b",suffix) == 0, "N: removed then reacquired same source cannot steal an old choice " + suffix)
		request = engine.begin(c,"turn_started",3)[0]
		engine.clear()
		var newer := engine.begin(c,"turn_started",3)[0]
		check.call(not engine.settle(request.request_id,c,"0").get("success",true) and request.request_id != newer.request_id, "N: teardown invalidates old request IDs " + suffix)
		engine.settle(newer.request_id,c,"1")
		check.call(quantity(c,"choice_b",suffix) == 8, "N: chosen fill reaches capacity without overflow " + suffix)
		var restored := Character.new()
		before = c.to_dict().duplicate(true)
		restored.from_dict(before)
		check.call(restored.numeric_resource_pools == c.numeric_resource_pools and ResourcePoolRules.saved_state_error(before).is_empty(), "N: existing checkpoint DTO retains recovered quantities without replay " + suffix)
		# Formula input changes and source/definition loss while a choice is open.
		var f := c.get_feature(source("choice_a",suffix))
		f.resource_pool.recovery.turn_started.amount_formula = {"caster_ability_modifier":"WIS"}
		request = engine.begin(c,"turn_started",4)[0]
		c.ability_scores.wisdom = 18
		check.call(not engine.settle(request.request_id,c,"0").get("success",true), "N: changed live formula refuses captured choice " + suffix)
		request = engine.begin(c,"turn_started",5)[0]
		f.resource_pool.recovery.turn_started.amount_formula = 1
		check.call(not engine.settle(request.request_id,c,"0").get("success",true), "N: edited definition cannot replace captured policy " + suffix)
		# Floors never reduce quantity, and clamp to the actual owned capacity.
		var floor_feature := c.get_feature(source("floor",suffix))
		floor_feature.resource_pool.recovery.initiative_rolled.amount_formula = 100
		var fresh := CombatPoolRecovery.new()
		fresh.begin(c,"initiative_rolled",0)
		check.call(quantity(c,"floor",suffix) == 6, "N: oversized floor clamps to source capacity " + suffix)
		floor_feature.resource_pool.recovery.initiative_rolled.amount_formula = 1
		fresh.begin(c,"initiative_rolled",1)
		check.call(quantity(c,"floor",suffix) == 6, "N: lower floor never reduces existing uses " + suffix)
		var dice: Array = []
		var listener := func(details: Dictionary): dice.append(details)
		Dice.dice_rolled.connect(listener)
		var missing := c.get_feature(source("fixed",suffix))
		missing.resource_pool.recovery.turn_started.amount_formula = {"caster_class_level":"wizard"}
		before = c.numeric_resource_pools.duplicate(true)
		fresh.begin(c,"turn_started",10)
		check.call(c.numeric_resource_pools[source("fixed",suffix)] == before[source("fixed",suffix)] and c.numeric_resource_pools.sibling == before.sibling and dice.is_empty(), "N: unavailable class formula cannot recover or roll " + suffix)
		Dice.dice_rolled.disconnect(listener)
	var definition: Dictionary = DataLoader.get_character_class("fixture:n_class_plain").features_by_level["1"][0]
	for policy in [{"mode":"restore_fixed"},{"mode":"restore_to_floor","amount_formula":0},{"mode":"restore_to_floor","amount_formula":"1d6"},{"mode":"restore_fixed","amount_formula":{"selected_slot_level":true}},{"mode":"restore_to_capacity","amount_formula":1},{"mode":"restore_fixed","amount_formula":1,"choice_group":""},{"mode":"restore_fixed","amount_formula":1,"amount":2},false]:
		var bad := definition.duplicate(true)
		bad.resource_pool.recovery.turn_started = policy
		check.call(not ResourcePoolRules.definition_error(bad).is_empty(), "N: malformed/unsupported policy refused " + str(policy))
	DataLoader.load_all_data()
