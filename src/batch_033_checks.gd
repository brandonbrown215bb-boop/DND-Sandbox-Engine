class_name Batch033Checks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_033/classes/stand.json", "class")
	DataLoader._load_json_file("res://data/fixtures/batch_033/monsters/cinder.json", "monster")
	DataLoader._load_json_file("res://data/fixtures/batch_033/spells/damage.json", "spell")

static func rule(index: int = 0) -> Dictionary:
	return DataLoader.get_character_class("fixture:b033_class").features_by_level["1"][index].duplicate(true)

static func setup(a: Character) -> void:
	a.class_id = "fixture:b033_class"
	a.subclass_id = ""
	a.weapon_masteries.clear()
	a.fighter_training.clear()
	a.feature_choices.clear()
	a.features.append(rule())
	a.class_levels = {"wizard": 3, "fixture:b033_class": 1}
	a.level = 4
	a.add_condition("blessed", 999)
	ResourcePoolRules.acquire(a, {"id": "fixture:b033_fuel", "resource_pool": {"id": "fuel", "capacity_formula": 10, "initial_quantity": 10}}, "b033:pool")

static func revive(a: Character, hp: int = 3) -> void:
	a.current_hp = hp
	a.is_alive = true
	a.corpse_state.clear()
	a.death_save_failures = 0
	a.remove_condition("unconscious")

static func choice(a: Character, index: int = 0) -> Dictionary:
	var live := a.features.filter(func(f): return f.get("source_instance_id") == rule(index).source_instance_id)
	return {"zero_hp_choice": {"target": a, "rule": rule(index), "live_rule": live[0] if not live.is_empty() else null, "used": false}}

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "033 neutral class/creature and changed consumers load: %s" % str(DataLoader.get_load_errors()))
	var a := Batch031Checks._character("b033_logic", 100)
	setup(a)
	revive(a)
	a.add_modifier("roll", "save:CON", 100, 999)
	var observed := []
	var watch := func(_details: Dictionary): observed.append({"attempts": int(a.zero_hp_history.get("b033:stand", {}).get("attempts", 0)), "fuel": int(ResourcePoolRules.availability(a, "b033:pool").current)})
	Dice.dice_rolled.connect(watch)
	var r := CombatAction.resolve_damage(a, 7, "fire", choice(a))
	Dice.dice_rolled.disconnect(watch)
	check.call(not observed.is_empty() and observed.all(func(v): return v.attempts == 1 and v.fuel == 9), "033 attempted history/payment settle before the save dice event")
	check.call(a.current_hp == 6 and a.is_alive and r.zero_hp_receipt.saves[0].dc == 10 and r.zero_hp_receipt.attempts_after == 1 and r.zero_hp_receipt.paid == 1, "033 first eligible CON save replaces before defeat with twice class level and pays once")
	var first_dto := a.to_dict()
	check.call(SharedStepExecutor.saved_zero_hp_history_error(first_dto).is_empty(), "033 R2 valid first attempt agrees with receipt and lifetime count")
	for defect in ["current_count", "before_count", "after_count", "reset_count"]:
		var bad := first_dto.duplicate(true)
		var entry: Dictionary = bad.zero_hp_history["b033:stand"]
		match defect:
			"current_count": entry.attempts = 0
			"before_count": entry.last_receipt.attempts_before = 1
			"after_count": entry.last_receipt.attempts_after = 0
			"reset_count": entry.last_receipt.reset_count = 1
		check.call(not SharedStepExecutor.saved_zero_hp_history_error(bad).is_empty(), "033 R2 first-attempt inconsistent %s refuses" % defect)
	revive(a)
	r = CombatAction.resolve_damage(a, 7, "fire", choice(a))
	check.call(a.current_hp == 6 and r.zero_hp_receipt.saves[0].dc == 15 and a.zero_hp_history["b033:stand"].attempts == 2 and ResourcePoolRules.availability(a, "b033:pool").current == 8, "033 second independent damage escalates from retained exact-source history")
	for excluded in ["radiant", "critical", "massive", "decline", "condition", "temporary", "invalid"]:
		revive(a)
		var before := a.zero_hp_history.duplicate(true)
		var fuel: int = ResourcePoolRules.availability(a, "b033:pool").current
		var d := choice(a)
		if excluded == "critical": d["damage_is_critical"] = true
		if excluded == "decline": d.clear()
		if excluded == "condition": a.remove_condition("blessed")
		if excluded == "temporary": a.temp_hp = 20
		if excluded == "invalid": d.zero_hp_choice.rule.steps[1].replacement_hp = {"selected_slot_level": true}
		r = CombatAction.resolve_damage(a, 110 if excluded == "massive" else 7, "radiant" if excluded == "radiant" else "fire", d)
		check.call(a.zero_hp_history == before and ResourcePoolRules.availability(a, "b033:pool").current == fuel and r.zero_hp_receipt.is_empty(), "033 %s excludes without history/payment/RNG replacement" % excluded)
		a.add_condition("blessed", 999)
		a.temp_hp = 0
	revive(a)
	a.add_modifier("roll", "save:CON", -200, 999)
	r = CombatAction.resolve_damage(a, 7, "fire", choice(a))
	check.call(a.current_hp == 0 and not a.is_alive and not r.zero_hp_receipt.saved and r.zero_hp_receipt.saves[0].dc == 20 and r.zero_hp_receipt.attempts_after == 3 and r.zero_hp_receipt.paid == 1, "033 failed save retains proposed zero outcome and attempted cost/history once")
	revive(a)
	var old := rule()
	a.features = a.features.filter(func(f): return f.get("source_instance_id") != "b033:stand")
	var before := a.zero_hp_history.duplicate(true)
	CombatAction.resolve_damage(a, 7, "fire", choice(a))
	check.call(a.zero_hp_history == before, "033 removed exact source cannot use a previously captured choice")
	a.features.append(old)
	revive(a)
	a.add_modifier("roll", "save:CON", 200, 999)
	r = CombatAction.resolve_damage(a, 7, "fire", choice(a))
	check.call(r.zero_hp_receipt.saves[0].dc == 25 and r.zero_hp_receipt.attempts_after == 4, "033 reacquisition preserves original DC without refund")
	a.features.append(rule(1))
	a.add_condition("shielded", 999)
	a.add_modifier("roll", "save:WIS", 100, 999)
	revive(a)
	r = CombatAction.resolve_damage(a, 7, "fire", choice(a, 1))
	check.call(a.current_hp == 5 and r.zero_hp_receipt.saves[0].ability == "WIS" and r.zero_hp_receipt.saves[0].dc == 7 and r.zero_hp_receipt.paid == 0 and a.zero_hp_history["b033:anchor"].attempts == 1 and a.zero_hp_history["b033:stand"].attempts == 4, "033 renamed sibling uses changed WIS/formula/success-history/failure-payment independently")
	var rest := RestRules.complete_short_rest([a], {"allow_in_test": true, "skip_campaign_time": true})
	check.call(rest.success and a.zero_hp_history["b033:stand"].attempts == 0 and a.zero_hp_history["b033:stand"].resets == 1 and a.zero_hp_history["b033:anchor"].attempts == 1, "033 real completed Short Rest resets only declared sources")
	RestRules.complete_long_rest([a], {"allow_in_test": true, "skip_campaign_time": true})
	check.call(a.zero_hp_history["b033:anchor"].attempts == 0 and a.zero_hp_history["b033:anchor"].last_reset == "long_rest_completed", "033 real completed Long Rest records its reset event")
	check.call(SharedStepExecutor.saved_zero_hp_history_error(a.to_dict()).is_empty(), "033 both completed source histories produce valid DTO state")
	# Ordinary class acquisition must create a new live occurrence reference.
	var acquired := Batch031Checks._character("b033_acquisition", 100)
	setup(acquired)
	acquired.features.clear()
	acquired._unlock_features_for_level(1, false)
	acquired.add_modifier("roll", "save:CON", 100, 999)
	var stale_choice := choice(acquired)
	acquired.features = acquired.features.filter(func(f): return f.get("source_instance_id") != "b033:stand")
	acquired._unlock_features_for_level(1, false)
	revive(acquired)
	CombatAction.resolve_damage(acquired, 7, "fire", stale_choice)
	check.call(acquired.current_hp == 0 and acquired.zero_hp_history.is_empty() and ResourcePoolRules.availability(acquired, "b033:pool").current == 10, "033 real class reacquisition gives a new live source occurrence and rejects old authorization")
	# A changed policy uses failure-only history and success-only payment.
	var other := Batch031Checks._character("b033_failure_policy", 100)
	setup(other)
	var policy: Dictionary = other.features.filter(func(f): return f.get("source_instance_id") == "b033:stand")[0]
	policy.history.increment = "failure"
	policy.payment.on = "success"
	other.add_modifier("roll", "save:CON", -100, 999)
	revive(other)
	var answer := {"zero_hp_choice": {"target": other, "rule": policy.duplicate(true), "live_rule": policy, "used": false}}
	var changed := CombatAction.resolve_damage(other, 7, "fire", answer)
	check.call(other.zero_hp_history["b033:stand"].attempts == 1 and changed.zero_hp_receipt.paid == 0, "033 failure-event history increments while success-only payment retains fuel")
	revive(other)
	other.add_modifier("roll", "save:CON", 200, 999)
	answer.zero_hp_choice.used = false
	changed = CombatAction.resolve_damage(other, 7, "fire", answer)
	check.call(other.current_hp == 6 and other.zero_hp_history["b033:stand"].attempts == 1 and changed.zero_hp_receipt.paid == 1, "033 successful save leaves failure-history unchanged and settles success payment once")
	for event in ["attempted", "accepted", "success", "failure"]:
		var actor := Batch031Checks._character("b033_history_" + event, 100)
		setup(actor)
		var owned: Dictionary = actor.features.filter(func(f): return f.get("source_instance_id") == "b033:stand")[0]
		owned.history.increment = event
		actor.add_modifier("roll", "save:CON", 100, 999)
		for success in [true, false]:
			revive(actor)
			if not success: actor.add_modifier("roll", "save:CON", -200, 999)
			var selected := {"zero_hp_choice": {"target": actor, "rule": owned.duplicate(true), "live_rule": owned, "used": false}}
			CombatAction.resolve_damage(actor, 7, "fire", selected)
			var dto := {"character_id": actor.character_id, "zero_hp_history": actor.zero_hp_history.duplicate(true), "zero_hp_attempt_serial": actor.zero_hp_attempt_serial}
			check.call(SharedStepExecutor.saved_zero_hp_history_error(dto).is_empty(), "033 R2 coherent %s history remains valid on %s" % [event, "success" if success else "failure"])
			dto.zero_hp_history["b033:stand"].last_receipt.attempts_after += 1
			check.call(not SharedStepExecutor.saved_zero_hp_history_error(dto).is_empty(), "033 R2 %s receipt must increment exactly at its declared result" % event)
	var monster := DataLoader.get_monster("fixture:b033_cinder").duplicate(true)
	monster.merge({"id": "b033_live", "current_hp": 3, "max_hp": 30, "is_alive": true, "saving_throw_bonuses": {"CON": 100}}, true)
	r = CombatAction.resolve_damage(monster, 7, "fire")
	check.call(monster.current_hp == 4 and r.zero_hp_receipt.saves[0].dc == 12, "033 selected creature host uses typed save/replace steps and incoming-damage DC")
	# Legacy native regressions live in spells/barbarian groups; this directly
	# protects an authored no-save rule using the same executor.
	var automatic := rule()
	automatic["source_instance_id"] = "b033:automatic"
	automatic.erase("optional")
	automatic.erase("payment")
	automatic.erase("history")
	automatic.erase("required_condition")
	automatic["steps"] = [{"id": "remain", "type": "replace_hp", "target": "target", "replacement_hp": {"op": "add", "left": 2, "right": {"caster_proficiency_bonus": true}}}]
	a.features = [automatic]
	revive(a)
	r = CombatAction.resolve_damage(a, 7, "cold")
	check.call(a.current_hp == 4 and r.zero_hp_replacement_saved, "033 authored unconditional replacement reuses shared executor without rolling a save")
	for defect in ["history", "optional", "bypass_outright_death", "formula"]:
		var bad := rule()
		match defect:
			"history": bad.history.increment = "query"
			"optional": bad.optional = "yes"
			"bypass_outright_death": bad.bypass_outright_death = 1
			"formula": bad.steps[1].replacement_hp = {"unknown": true}
		check.call(not SharedStepExecutor.validate_zero_hp_replacement_rule(bad).is_empty(), "033 malformed %s refuses at content validation" % defect)
