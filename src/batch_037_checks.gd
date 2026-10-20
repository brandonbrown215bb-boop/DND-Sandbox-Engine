class_name Batch037Checks
extends RefCounted

const STANCE := "fixture:b037_stance"
const ATTUNE := "fixture:b037_attune"
const DEEPEN := "fixture:b037_deepen"

static func load_fixtures() -> void:
	if not DataLoader.get_character_class("fixture:b037_class").is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_037/classes/modes.json", "class")

static func catalog(level_key: String, index: int) -> Dictionary:
	return DataLoader.get_character_class("fixture:b037_class").features_by_level[level_key][index]

static func actor(id: String, hp: int = 30) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 12, "DEX": 12, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	var a := Character.new()
	a.initialize(id, "human", "fixture:b037_class", scores)
	a.character_id = id
	a.max_hp = hp
	a.current_hp = hp
	return a

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "037 neutral mode-choice and rule-upgrade class loads: %s" % str(DataLoader.get_load_errors()))
	_validation(check)
	_rest_modes(check)
	_activation_modes(check)
	_upgrades(check)
	_saves(check)
	review_stress(check)

static func _validation(check: Callable) -> void:
	var good: Dictionary = catalog("1", 0).duplicate(true)
	check.call(FeatureModeRules.validate_rule(good).is_empty() and FeatureModeRules.validate_rule(catalog("1", 1)).is_empty(), "037 S-103 declared rest and activation mode rules validate")
	var one := good.duplicate(true); one.modes = [one.modes[0]]
	var rest_uses: Dictionary = catalog("1", 1).duplicate(true); rest_uses["uses"] = 2
	var dup := good.duplicate(true); dup.modes[1].id = "guard"
	var bad_end := good.duplicate(true); bad_end.end_on = ["sunset"]
	var bad_benefit := good.duplicate(true); bad_benefit.modes[0].benefits = [{"stat": "HP", "amount": 3}]
	var no_duration := good.duplicate(true); no_duration.erase("duration_seconds")
	var refused := [one, rest_uses, dup, bad_end, bad_benefit, no_duration].filter(func(r): return not FeatureModeRules.validate_rule(r).is_empty())
	check.call(refused.size() == 6, "037 S-103 loader refuses one-mode, rest-with-uses, duplicate, unknown-end, unsupported-benefit and undated rules (%d/6)" % refused.size())
	var ids := {STANCE: true, ATTUNE: true}
	var up: Dictionary = catalog("2", 0).duplicate(true)
	check.call(RuleUpgradeRules.validate_rule(up, ids).is_empty(), "037 S-084 declared upgrade of an owned rule validates")
	var missing := up.duplicate(true); missing.rule = "fixture:b037_nowhere"
	var param := up.duplicate(true); param.changes = {"range": {"add": 5}}
	var huge := up.duplicate(true); huge.changes = {"uses": {"add": 99}}
	var die := up.duplicate(true); die.changes = {"die": {"set": "d7"}}
	var self_ref := up.duplicate(true); self_ref.rule = DEEPEN
	var refused_up := [missing, param, huge, die, self_ref].filter(func(r): return not RuleUpgradeRules.validate_rule(r, ids).is_empty())
	check.call(refused_up.size() == 5, "037 S-084 loader refuses undeclared, unsupported, oversized, illegal-die and self upgrades (%d/5)" % refused_up.size())

static func _rest_modes(check: Callable) -> void:
	var a := actor("b037_rest")
	var ac := a.get_ac()
	var speed := a.get_speed()
	var choices_before := a.feature_choices.duplicate(true)
	var r := FeatureModeRules.choose(a, ATTUNE, "warded")
	check.call(r.success and a.get_ac() == ac + 1 and a.get_speed() == speed, "037 S-103 first rest-boundary choice grants only the selected mode")
	check.call(not FeatureModeRules.choose(a, ATTUNE, "swift").success and a.get_ac() == ac + 1, "037 S-103 rest mode cannot change before its declared rest")
	a.short_rest()
	check.call(not FeatureModeRules.choose(a, ATTUNE, "swift").success, "037 S-103 a different rest kind does not open a long-rest mode")
	a.long_rest()
	check.call(a.get_ac() == ac + 1, "037 S-103 completed rest opens the choice but keeps the prior grant until replaced")
	r = FeatureModeRules.choose(a, ATTUNE, "swift")
	check.call(r.success and r.replaced == "warded" and a.get_ac() == ac and a.get_speed() == speed + 1, "037 S-103 new rest choice replaces the prior mode's grants")
	var carriers := SourceBenefitRules.query(a).filter(func(c): return c.kind == "mode")
	check.call(carriers.size() == 1 and carriers[0].definition_id == "swift", "037 S-103 exactly one owned mode carrier remains")
	check.call(a.feature_choices == choices_before and not a.feature_choices.has(ATTUNE), "037 S-103 mode choices stay separate from permanent progression choices")
	check.call(not FeatureModeRules.choose(a, ATTUNE, "unknown").success and not FeatureModeRules.choose(a, "fixture:b037_nowhere", "swift").success, "037 S-103 undeclared mode or unowned rule refuses")

static func _activation_modes(check: Callable) -> void:
	var a := actor("b037_act")
	a.feature_uses[STANCE] = a.get_feature_max_uses(STANCE)
	var ac := a.get_ac()
	var speed := a.get_speed()
	check.call(int(a.feature_uses[STANCE]) == 2 and not FeatureModeRules.choose(a, STANCE, "guard").success, "037 S-103 activation mode cannot be chosen without activating")
	var r := FeatureModeRules.activate(a, STANCE, "guard")
	check.call(r.success and int(a.feature_uses[STANCE]) == 1 and a.get_ac() == ac + 2 and r.die == "d6" and r.rolled >= 1 and r.rolled <= 6 and a.temp_hp == r.rolled, "037 S-103 activation spends one parent use and grants the chosen mode")
	SpellEffects.advance_time([a], 24)
	var remaining := int(a.feature_modes[STANCE].remaining_seconds)
	var temp := a.temp_hp
	r = FeatureModeRules.choose(a, STANCE, "stride")
	check.call(r.success and r.replaced == "guard" and a.get_ac() == ac and a.get_speed() == speed + 2 and int(a.feature_uses[STANCE]) == 1 and int(a.feature_modes[STANCE].remaining_seconds) == remaining and remaining == 36 and a.temp_hp == temp, "037 S-103 reselect replaces grants without respending or restarting the parent")
	check.call(not FeatureModeRules.activate(a, STANCE, "guard").success and int(a.feature_uses[STANCE]) == 1, "037 S-103 a second activation while active refuses without spending")
	SpellEffects.advance_time([a], 36)
	check.call(not a.feature_modes[STANCE].active and a.get_speed() == speed and SourceBenefitRules.query(a).filter(func(c): return c.kind == "mode").is_empty(), "037 S-103 parent lifetime ends the mode's grants")
	FeatureModeRules.activate(a, STANCE, "guard")
	check.call(int(a.feature_uses[STANCE]) == 0 and int(a.feature_modes[STANCE].activation_serial) == 2 and not FeatureModeRules.activate(a, STANCE, "guard").success, "037 S-103 new activation is a new exact source and uses are bounded")
	a.add_condition("incapacitated", 10)
	check.call(a.get_ac() == ac and not a.feature_modes[STANCE].active, "037 S-103 declared incapacitated end predicate ends the activation")
	a.remove_condition("incapacitated")
	a.long_rest()
	check.call(int(a.feature_uses[STANCE]) == 2, "037 S-103 parent uses recover on their declared rest")
	var ally := actor("b037_ally")
	check.call(FeatureModeRules.activate(a, STANCE, "guard", [a, ally]).reason == "too_many_targets" and int(a.feature_uses[STANCE]) == 2, "037 S-103 base rule refuses more recipients than its targets")

static func _upgrades(check: Callable) -> void:
	var a := actor("b037_up")
	var before := JSON.stringify(catalog("1", 0))
	check.call(RuleUpgradeRules.effective(a, a.get_feature(STANCE)) == a.get_feature(STANCE) and a.get_feature_max_uses(STANCE) == 2, "037 S-084 without an owned upgrade the base rule applies")
	a.level_up()
	check.call(a.has_feature(DEEPEN), "037 S-084 the upgrade is acquired through ordinary progression")
	var eff := FeatureModeRules.rule(a, STANCE)
	check.call(a.get_feature_max_uses(STANCE) == 3 and eff.die == "d10" and int(eff.targets) == 2 and eff.end_on == ["long_rest", "zero_hp"] and eff.applied_upgrades == [DEEPEN], "037 S-084 upgrade changes count, die, targets and end predicates")
	check.call(JSON.stringify(catalog("1", 0)) == before and JSON.stringify(a.get_feature(STANCE)) == before, "037 S-084 catalog and owned base records are not mutated")
	a.feature_uses[STANCE] = a.get_feature_max_uses(STANCE)
	var ally := actor("b037_up_ally")
	var r := FeatureModeRules.activate(a, STANCE, "guard", [a, ally])
	check.call(r.success and r.die == "d10" and r.rolled >= 1 and r.rolled <= 10 and ally.temp_hp == r.rolled and a.temp_hp >= r.rolled, "037 S-084 upgraded die and target count apply on the real activation")
	var ac := a.get_ac()
	a.add_condition("incapacitated", 10)
	check.call(a.feature_modes[STANCE].active and a.get_ac() == ac, "037 S-084 removed end predicate no longer ends the activation")
	a.remove_condition("incapacitated")
	a.features.append(a.get_feature(DEEPEN))
	check.call(a.get_feature_max_uses(STANCE) == 3 and FeatureModeRules.rule(a, STANCE).applied_upgrades.size() == 1, "037 S-084 a repeated upgrade record applies once")
	a.features.pop_back()
	var back := Character.new()
	back.from_dict(a.to_dict())
	var back2 := Character.new()
	back2.from_dict(back.to_dict())
	check.call(back2.get_feature_max_uses(STANCE) == 3 and int(FeatureModeRules.rule(back2, STANCE).targets) == 2 and back2.features.filter(func(f): return f.id == DEEPEN).size() == 1 and JSON.stringify(back2.get_feature(STANCE)) == before, "037 S-084 two reloads neither duplicate nor stack the upgrade")
	check.call(int(back2.feature_uses[STANCE]) == int(a.feature_uses[STANCE]) and back2.feature_modes[STANCE].mode == "guard" and back2.get_ac() == a.get_ac(), "037 S-103 reload keeps the active mode, remaining uses and grants")

static func _saves(check: Callable) -> void:
	var a := actor("b037_save")
	a.feature_uses[STANCE] = a.get_feature_max_uses(STANCE)
	FeatureModeRules.activate(a, STANCE, "stride")
	FeatureModeRules.choose(a, ATTUNE, "warded")
	var dto := a.to_dict()
	check.call(FeatureModeRules.saved_error(dto).is_empty(), "037 S-103 live rest and activation modes validate")
	var defects := {
		"unknown mode": func(d): d.feature_modes[STANCE].mode = "flying",
		"unowned rule": func(d): d.feature_modes["fixture:b037_nowhere"] = {"mode": "guard", "open": false},
		"overlong": func(d): d.feature_modes[STANCE].remaining_seconds = 999,
		"extra field": func(d): d.feature_modes[ATTUNE]["uses"] = 3,
		"active empty": func(d): d.feature_modes[STANCE].mode = "",
		"bad roll": func(d): d.feature_modes[STANCE].rolled = 40,
	}
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		check.call(not FeatureModeRules.saved_error(bad).is_empty(), "037 S-103 saved feature mode refuses %s" % label)
	var legacy := dto.duplicate(true)
	legacy.erase("feature_modes")
	var old := Character.new()
	old.from_dict(legacy)
	check.call(FeatureModeRules.saved_error(legacy).is_empty() and old.feature_modes.is_empty() and old.get_feature_max_uses(STANCE) == 2, "037 legacy save without feature modes still loads")

## Reviewer stress cases (Batch 037 review).
static func review_stress(check: Callable) -> void:
	load_fixtures()
	# RV1 refusal before cost: dead recipient, too many targets, unknown mode, zero uses.
	var a := actor("b037_rv_a")
	var dead := actor("b037_rv_dead")
	CorpseRules.mark_dead(dead, "test")
	var uses := int(a.feature_uses[STANCE])
	var refusals := [FeatureModeRules.activate(a, STANCE, "guard", [a, dead]), FeatureModeRules.activate(a, STANCE, "guard", [a, actor("b037_rv_x")]), FeatureModeRules.activate(a, STANCE, "bogus")]
	check.call(refusals.all(func(r): return not r.success) and int(a.feature_uses[STANCE]) == uses and a.feature_modes.is_empty() and a.temp_hp == 0, "037 review RV1 invalid recipient/too many targets/unknown mode refuse before any use, roll or state")
	a.feature_uses[STANCE] = 0
	check.call(FeatureModeRules.activate(a, STANCE, "guard").reason == "no_uses" and a.feature_modes.is_empty(), "037 review RV1 zero uses refuses with no state")
	a.feature_uses[STANCE] = uses
	# RV2 downed actor cannot activate a zero_hp-ending mode (no cost).
	a.current_hp = 0
	check.call(FeatureModeRules.activate(a, STANCE, "guard").reason == "end_condition_met" and int(a.feature_uses[STANCE]) == uses, "037 review RV2 0-HP activation is refused before cost")
	a.current_hp = 30
	# RV3 active mode ends at 0 HP and its grant vanishes; reactivation spends a new use with a new serial.
	var base_ac := a.get_ac()
	var r := FeatureModeRules.activate(a, STANCE, "guard")
	check.call(r.success and a.get_ac() == base_ac + 2, "037 review RV3 active guard grants +2 AC")
	a.current_hp = 0
	check.call(a.get_ac() == base_ac and not a.feature_modes[STANCE].active, "037 review RV3 dropping to 0 HP ends the mode and its grant")
	a.current_hp = 30
	var r2 := FeatureModeRules.activate(a, STANCE, "stride")
	check.call(r2.success and int(r2.activation_serial) == int(r.activation_serial) + 1 and int(a.feature_uses[STANCE]) == uses - 2, "037 review RV3 reactivation is a new parent use and serial")
	# RV4 the shared clock (GameManager.advance_campaign_time -> SpellEffects.advance_time) expires a 60 s mode.
	SpellEffects.advance_time([a], 59)
	var still := bool(a.feature_modes[STANCE].active)
	SpellEffects.advance_time([a], 3600)
	check.call(still and not bool(a.feature_modes[STANCE].active) and a.get_ac() == base_ac, "037 review RV4 59 s keeps the mode; an hour of shared time ends it and its grant")
	# RV5 rest mode: one choice per boundary, survives reload closed, reopens only at its rest.
	var b := actor("b037_rv_b")
	check.call(FeatureModeRules.choose(b, ATTUNE, "warded").success and not FeatureModeRules.choose(b, ATTUNE, "swift").success, "037 review RV5 rest mode cannot be changed twice in one boundary")
	var b2 := Character.new()
	b2.from_dict(b.to_dict())
	check.call(b2.feature_modes.get(ATTUNE, {}).get("mode", "") == "warded" and not FeatureModeRules.choose(b2, ATTUNE, "swift").success and b2.get_ac() == b.get_ac(), "037 review RV5 reload keeps the closed rest choice and its single grant")
	b2.short_rest()
	check.call(not FeatureModeRules.choose(b2, ATTUNE, "swift").success, "037 review RV5 a Short Rest does not reopen a Long Rest mode")
	# RV6 activation reload mid-use: no refill, no second grant, same serial, reselect does not respend.
	var c := actor("b037_rv_c")
	FeatureModeRules.activate(c, STANCE, "guard")
	var ac_live := c.get_ac()
	var dto := c.to_dict()
	check.call(FeatureModeRules.saved_error(dto).is_empty(), "037 review RV6 mid-activation DTO validates")
	var c2 := Character.new()
	c2.from_dict(dto)
	check.call(c2.get_ac() == ac_live and int(c2.feature_uses[STANCE]) == int(c.feature_uses[STANCE]) and int(c2.feature_modes[STANCE].activation_serial) == int(c.feature_modes[STANCE].activation_serial) and c2.temp_hp == c.temp_hp, "037 review RV6 reload keeps one grant, spent uses, serial and Temporary HP")
	check.call(FeatureModeRules.choose(c2, STANCE, "stride").success and int(c2.feature_uses[STANCE]) == int(c.feature_uses[STANCE]) and FeatureModeRules.activate(c2, STANCE, "guard").reason == "already_active", "037 review RV6 reloaded reselect does not respend; reactivation while active refuses")
	# RV7 tampered DTOs refuse; legacy DTO without the field loads.
	for defect in ["mode", "remaining", "inactive_mode", "unowned", "key"]:
		var bad := dto.duplicate(true)
		match defect:
			"mode": bad.feature_modes[STANCE].mode = "bogus"
			"remaining": bad.feature_modes[STANCE].remaining_seconds = 99999
			"inactive_mode": bad.feature_modes[STANCE].active = false
			"unowned": bad.feature_modes["fixture:not_owned"] = {"mode": "guard", "open": false}
			"key": bad.feature_modes[STANCE]["uses"] = 9
		check.call(not FeatureModeRules.saved_error(bad).is_empty(), "037 review RV7 tampered %s refuses" % defect)
	var legacy := dto.duplicate(true)
	legacy.erase("feature_modes")
	var c3 := Character.new()
	c3.from_dict(legacy)
	check.call(FeatureModeRules.saved_error(legacy).is_empty() and c3.feature_modes.is_empty(), "037 review RV7 legacy DTO loads with no modes")
	# RV8 upgrade: applies once even if the upgrade feature is duplicated; catalog unchanged; reload not duplicated.
	var d := actor("b037_rv_d")
	d.level_up()
	d.features.append(catalog("2", 0).duplicate(true))
	var eff := FeatureModeRules.rule(d, STANCE)
	check.call(eff.die == "d10" and int(eff.targets) == 2 and "incapacitated" not in eff.end_on and eff.applied_upgrades.size() == 1 and catalog("1", 0).die == "d6" and int(catalog("1", 0).uses) == 2, "037 review RV8 duplicated upgrade applies once and catalog is unchanged")
	var d2 := Character.new()
	d2.from_dict(d.to_dict())
	check.call(FeatureModeRules.rule(d2, STANCE).get("applied_upgrades", []).size() <= 1 and d2.get_feature_max_uses(STANCE) == d.get_feature_max_uses(STANCE), "037 review RV8 reload does not duplicate the upgrade (max uses %d vs %d)" % [d2.get_feature_max_uses(STANCE), d.get_feature_max_uses(STANCE)])
