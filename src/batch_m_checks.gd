class_name BatchMChecks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_m_dice.json", "class")

static func actor(suffix: String = "plain") -> Character:
	var c := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"STR":12,"DEX":12,"CON":14,"INT":12,"WIS":14,"CHA":12})
	c.initialize("Captured dice " + suffix, "human", "fixture:m_class_" + suffix, scores)
	c.character_id = "m_owner_" + suffix
	c.level = 2
	c.class_levels = {c.class_id:1,"wizard":1}
	c.max_hp = 100
	c.current_hp = 1
	return c

static func feature(c: Character, suffix: String = "plain") -> Dictionary:
	return c.get_feature("fixture:m_dice_" + suffix)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "M: neutral/renamed capture fixtures load: " + str(DataLoader.get_load_errors()))
	var events: Array = []
	var listener := func(details: Dictionary): events.append(details.duplicate(true))
	Dice.dice_rolled.connect(listener)
	for suffix in ["plain", "changed"]:
		var c := actor(suffix)
		var f := feature(c, suffix)
		var start := events.size()
		check.call(ResourcePoolRules.acquire(c, f, "first").get("success", false), "M: acquire source " + suffix)
		check.call(ResourcePoolRules.acquire(c, f, "sibling").get("success", false), "M: acquire independent identical source " + suffix)
		check.call(events.size() == start + 6, "M: acquisition rolls exactly three dice per source " + suffix)
		var original: Dictionary = c.numeric_resource_pools.first.duplicate(true)
		var sibling: Dictionary = c.numeric_resource_pools.sibling.duplicate(true)
		var before := c.to_dict().duplicate(true)
		start = events.size()
		for index in 3: ClassFeature.availability(c, f, null, "first", 2)
		check.call(c.to_dict() == before and events.size() == start and not ResourcePoolRules.acquire(c, f, "first").get("success", true), "M: query/acquisition replay never rerolls " + suffix)
		# Equal faces are legal, separate owned dice, never a face-keyed set.
		c.numeric_resource_pools.first.captured_dice[0].face = 1
		c.numeric_resource_pools.first.captured_dice[1].face = 1
		var equal: Array = c.numeric_resource_pools.first.captured_dice.duplicate(true)
		var budget := CombatTurnBudget.new()
		budget.reset(c, [])
		var result := ClassFeature.execute(c, f, c, budget, "first", 2)
		var receipt: Dictionary = result.get("results", [{}])[0]
		check.call(result.get("success", false) and receipt.get("rolls") == [1,1] and receipt.get("captured_dice") == equal.slice(0,2) and equal[0].die_id != equal[1].die_id and c.current_hp == 3, "M: equal-face identities spend once and heal from stored faces " + suffix)
		check.call(events.size() == start and not budget.bonus_action_available and c.numeric_resource_pools.first.captured_dice == equal.slice(2) and c.numeric_resource_pools.sibling == sibling, "M: no spend-time RNG, exact action/source/count " + suffix)
		before = c.to_dict().duplicate(true)
		check.call(not ClassFeature.execute(c, f, c, budget, "first", 2).get("success", true) and c.to_dict() == before and events.size() == start, "M: repeated/unaffordable activation refuses without RNG " + suffix)
		c.level = 4
		c.class_levels = {c.class_id:1,"wizard":1,"fighter":2}
		check.call(ResourcePoolRules.recalculate_capacity(c,f,"first").get("success",false) and c.numeric_resource_pools.first.capacity == 3 and c.numeric_resource_pools.first.die_size == original.die_size, "M: unrelated class levels do not upgrade pool " + suffix)
		c.class_levels = {c.class_id:1,"wizard":3}
		check.call(ResourcePoolRules.recalculate_capacity(c,f,"first").get("success",false) and c.numeric_resource_pools.first.capacity == 5 and c.numeric_resource_pools.first.current == 1 and c.numeric_resource_pools.first.captured_dice == equal.slice(2), "M: own class progression grows without refill or changing old dice " + suffix)
		var recovered := ResourcePoolRules.recover(c,f,"first","short_rest_completed")
		var mixed: Array = c.numeric_resource_pools.first.captured_dice.duplicate(true)
		check.call(recovered.get("recovered") == 1 and events.size() == start + 1 and mixed[0] == equal[2] and mixed[1].die_size == (8 if suffix == "plain" else 10) and mixed[1].generation_level == 4 and mixed[1].serial == 4, "M: recovery creates only new dice using new size/identity " + suffix)
		check.call(ResourcePoolRules.saved_state_error(c.to_dict()).is_empty(), "M: mixed generation DTO validates " + suffix)
		var restored := Character.new()
		restored.from_dict(c.to_dict())
		check.call(restored.numeric_resource_pools == c.numeric_resource_pools and events.size() == start + 1, "M: DTO restore preserves faces without acquisition RNG " + suffix)
		for mutation in ["face","duplicate","owner","source","serial","quantity","policy","missing","size","level","strip"]:
			var bad := c.to_dict().duplicate(true)
			var pool: Dictionary = bad.numeric_resource_pools.first
			match mutation:
				"face": pool.captured_dice[0].face = 0
				"duplicate": pool.captured_dice[1] = pool.captured_dice[0].duplicate(true)
				"owner": pool.captured_dice[0].owner_id = "wrong"
				"source": pool.captured_dice[0].source_instance_id = "sibling"
				"serial": pool.die_serial = 0
				"quantity": pool.current = 1
				"policy": pool.upgrade_policy = "reroll"
				"missing": pool.erase("captured_dice")
				"size": pool.captured_dice[0].die_size = 3
				"level": pool.captured_dice[0].generation_level = 0
				"strip":
					for field in ["capture_policy","upgrade_policy","captured_dice","die_serial"]: pool.erase(field)
			check.call(not ResourcePoolRules.saved_state_error(bad).is_empty(), "M: malformed captured DTO refused " + suffix + " " + mutation)
		c.level = 2
		c.class_levels = {c.class_id:1,"wizard":1}
		ResourcePoolRules.recalculate_capacity(c,f,"first")
		ResourcePoolRules.recover(c,f,"first","long_rest_completed")
		var full: Array = c.numeric_resource_pools.first.captured_dice.duplicate(true)
		var shrink := f.duplicate(true)
		shrink.resource_pool.capacity_formula = 1
		check.call(ResourcePoolRules.recalculate_capacity(c,shrink,"first").get("success", false) and c.numeric_resource_pools.first.captured_dice == full.slice(0,1), "M: shrink retains oldest exact dice deterministically " + suffix)
		start = events.size()
		check.call(not ResourcePoolRules.reserve_payment(c,"first",1).get("success",true), "M: numeric payment reservations cannot corrupt captured inventory " + suffix)
		check.call(ResourcePoolRules.remove(c,"first") and c.numeric_resource_pools.sibling == sibling and events.size() == start, "M: source removal preserves sibling, no random replay " + suffix)
	Dice.dice_rolled.disconnect(listener)
	var f: Dictionary = DataLoader.get_character_class("fixture:m_class_plain").features_by_level["1"][0]
	for mutation in ["missing_upgrade","bad_capture","bad_upgrade","no_die"]:
		var bad: Dictionary = f.duplicate(true)
		match mutation:
			"missing_upgrade": bad.resource_pool.erase("upgrade_policy")
			"bad_capture": bad.resource_pool.capture_policy = "on_query"
			"bad_upgrade": bad.resource_pool.upgrade_policy = "reroll"
			"no_die": bad.resource_pool.erase("die_size")
		check.call(not ClassFeature.content_error(bad).is_empty(), "M: invalid capture definition refused " + mutation)
	DataLoader.load_all_data()
