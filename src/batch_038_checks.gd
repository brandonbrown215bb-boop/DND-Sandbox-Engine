class_name Batch038Checks
extends RefCounted

const STANCE := "fixture:b038_stance"

static func load_fixtures() -> void:
	if not DataLoader.get_character_class("fixture:b038_class").is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_038/classes/switches.json", "class")

static func catalog(level_key: String, index: int) -> Dictionary:
	return DataLoader.get_character_class("fixture:b038_class").features_by_level[level_key][index]

static func actor(id: String, levels: int = 1) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 12, "DEX": 12, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	var a := Character.new()
	a.initialize(id, "human", "fixture:b038_class", scores)
	a.character_id = id
	for _i in levels - 1: a.level_up()
	a.max_hp = 30
	a.current_hp = 30
	a.feature_uses[STANCE] = a.get_feature_max_uses(STANCE)
	return a

static func run(check: Callable) -> void:
	load_fixtures()
	Batch037Checks.load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "038 neutral switch and option-upgrade class loads: %s" % str(DataLoader.get_load_errors()))
	_validation(check)
	_switches(check)
	_options(check)
	_exclusive(check)
	_saves(check)

static func _validation(check: Callable) -> void:
	var good: Dictionary = catalog("1", 0).duplicate(true)
	var ids := {STANCE: true}
	check.call(FeatureModeRules.validate_rule(good).is_empty() and [catalog("2", 0), catalog("2", 1), catalog("3", 0), catalog("3", 1)].all(func(u): return RuleUpgradeRules.validate_rule(u, ids).is_empty()), "038 declared switch events, mode options and exclusive alternatives validate")
	var bad_event := good.duplicate(true); bad_event.switch_events = ["miss"]
	var rest_switch: Dictionary = Batch037Checks.catalog("1", 1).duplicate(true); rest_switch["switch_events"] = ["turn_start"]
	var refused := [bad_event, rest_switch].filter(func(r): return not FeatureModeRules.validate_rule(r).is_empty())
	check.call(refused.size() == 2, "038 S-104 unknown switch event and rest-boundary switching refuse (%d/2)" % refused.size())
	var up: Dictionary = catalog("2", 0).duplicate(true)
	var dup_mode := up.duplicate(true); dup_mode.changes.modes.add.append(up.changes.modes.add[0].duplicate(true))
	var bad_benefit := up.duplicate(true); bad_benefit.changes.modes.add[0].benefits = [{"stat": "HP", "amount": 1}]
	var bad_op := up.duplicate(true); bad_op.changes.modes = {"replace": ["guard"]}
	var bad_group := up.duplicate(true); bad_group["exclusive_group"] = ""
	var bad_switch := up.duplicate(true); bad_switch.changes = {"switch_events": {"add": ["crit"]}}
	var refused_up := [dup_mode, bad_benefit, bad_op, bad_group, bad_switch].filter(func(u): return not RuleUpgradeRules.validate_rule(u, ids).is_empty())
	check.call(refused_up.size() == 5, "038 S-085 duplicate/illegal added modes, unknown operation, empty group and unknown event refuse (%d/5)" % refused_up.size())

static func _switches(check: Callable) -> void:
	var a := actor("b038_switch")
	var ac := a.get_ac()
	var speed := a.get_speed()
	FeatureModeRules.activate(a, STANCE, "guard")
	var uses := int(a.feature_uses[STANCE])
	check.call(not FeatureModeRules.switch(a, STANCE, "stride", "turn_start").success and not FeatureModeRules.choose(a, STANCE, "stride").success, "038 S-104 no switch outside a declared event window (and no free reselect)")
	SpellEffects.advance_time([a], 12)
	CombatAction.advance_combat_turn(a, 1)
	var r := FeatureModeRules.switch(a, STANCE, "stride", "turn_start")
	check.call(r.success and r.replaced == "guard" and a.get_ac() == ac and a.get_speed() == speed + 2 and int(a.feature_uses[STANCE]) == uses and int(a.feature_modes[STANCE].remaining_seconds) == 48 and int(a.feature_modes[STANCE].activation_serial) == 1, "038 S-104 own turn start switches the mode; parent cost, deadline and serial stay fixed")
	check.call(not FeatureModeRules.switch(a, STANCE, "guard", "turn_start").success, "038 S-104 one switch per opened window")
	var other := actor("b038_other")
	CombatAction.advance_combat_turn(other, 1)
	check.call(not FeatureModeRules.switch(a, STANCE, "guard", "turn_start").success, "038 S-104 another creature's turn start opens no window for this actor")
	CombatAction.advance_combat_turn(a, 2)
	check.call(not FeatureModeRules.switch(a, STANCE, "guard", "hit").success, "038 S-104 an undeclared hit event cannot switch the base rule")
	check.call(not FeatureModeRules.switch(a, STANCE, "missing", "turn_start").success and FeatureModeRules.switch(a, STANCE, "guard", "turn_start").success, "038 S-104 only declared modes are legal switch targets")
	SpellEffects.advance_time([a], 48)
	CombatAction.advance_combat_turn(a, 3)
	check.call(not a.feature_modes[STANCE].active and not FeatureModeRules.switch(a, STANCE, "stride", "turn_start").success, "038 S-104 ended activation opens no switch window")

static func _options(check: Callable) -> void:
	var a := actor("b038_opts", 2)
	var before := JSON.stringify(catalog("1", 0))
	var eff := FeatureModeRules.rule(a, STANCE)
	var ids: Array = eff.modes.map(func(m): return m.id)
	check.call(ids == ["guard", "bulwark"] and eff.switch_events == ["turn_start", "hit"] and JSON.stringify(catalog("1", 0)) == before, "038 S-085 owned upgrades add a mode, remove another and add the hit permission without touching the catalog")
	check.call(not FeatureModeRules.activate(a, STANCE, "stride").success and int(a.feature_uses[STANCE]) == 2, "038 S-085 a removed mode is no longer legal and costs nothing")
	var ac := a.get_ac()
	check.call(FeatureModeRules.activate(a, STANCE, "bulwark").success and a.get_ac() == ac + 3, "038 S-085 an added mode activates with its own grant")
	FeatureModeRules.on_event(a, "hit")
	var r := FeatureModeRules.switch(a, STANCE, "guard", "hit")
	check.call(r.success and a.get_ac() == ac + 2, "038 S-085/S-104 the added hit permission opens a switch window")
	var lone := actor("b038_lone", 1)
	var removal := {"id": "x", "type": "rule_upgrade", "rule": STANCE, "changes": {"modes": {"remove": ["guard", "stride"]}}}
	lone.features.append(removal)
	check.call(FeatureModeRules.rule(lone, STANCE).modes.size() == 2, "038 S-085 removals never leave fewer than two legal modes")
	var back := Character.new()
	back.from_dict(a.to_dict())
	check.call(back.feature_modes[STANCE].mode == "guard" and back.get_ac() == a.get_ac() and FeatureModeRules.rule(back, STANCE).modes.size() == 2 and JSON.stringify(back.get_feature(STANCE)) == before, "038 S-085 reload keeps the added-mode state without duplicating options")

static func _exclusive(check: Callable) -> void:
	var a := actor("b038_alt", 3)
	var eff := FeatureModeRules.rule(a, STANCE)
	check.call(int(eff.targets) == 2 and a.get_feature_max_uses(STANCE) == 2 and eff.alternatives.focus.chosen == "fixture:b038_alt_a" and eff.alternatives.focus.options.size() == 2, "038 S-085 two owned exclusive alternatives apply only one (default first), never both")
	check.call(RuleUpgradeRules.choose_alternative(a, STANCE, "focus", "fixture:b038_alt_b") and int(FeatureModeRules.rule(a, STANCE).get("targets", 1)) == 1 and a.get_feature_max_uses(STANCE) == 3, "038 S-085 choosing the other alternative replaces, not adds, its policy")
	check.call(not RuleUpgradeRules.choose_alternative(a, STANCE, "focus", "fixture:b038_widen") and not RuleUpgradeRules.choose_alternative(a, STANCE, "other", "fixture:b038_alt_a"), "038 S-085 non-member or unknown-group alternatives refuse")
	a.feature_uses[STANCE] = 3
	FeatureModeRules.activate(a, STANCE, "guard")
	check.call(not RuleUpgradeRules.choose_alternative(a, STANCE, "focus", "fixture:b038_alt_a") and a.get_feature_max_uses(STANCE) == 3, "038 S-085 alternatives cannot change during an active activation")
	var back := Character.new()
	back.from_dict(a.to_dict())
	var back2 := Character.new()
	back2.from_dict(back.to_dict())
	check.call(back2.rule_alternatives == a.rule_alternatives and back2.get_feature_max_uses(STANCE) == 3 and int(FeatureModeRules.rule(back2, STANCE).get("targets", 1)) == 1, "038 S-085 the chosen alternative survives two reloads without stacking")

static func _saves(check: Callable) -> void:
	var a := actor("b038_save", 3)
	RuleUpgradeRules.choose_alternative(a, STANCE, "focus", "fixture:b038_alt_b")
	FeatureModeRules.activate(a, STANCE, "bulwark")
	FeatureModeRules.on_event(a, "hit")
	var dto := a.to_dict()
	check.call(FeatureModeRules.saved_error(dto).is_empty() and RuleUpgradeRules.saved_error(dto).is_empty(), "038 live window, added mode and alternative validate")
	var defects := {
		"window event": func(d): d.feature_modes[STANCE].window.event = "miss",
		"window serial": func(d): d.feature_modes[STANCE].window.serial = 99,
		"alternative": func(d): d.rule_alternatives["%s|focus" % STANCE] = "fixture:b038_widen",
		"alternative key": func(d): d.rule_alternatives["nowhere|focus"] = "fixture:b038_alt_a",
		"unowned added mode": func(d): d.level = 1,
	}
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		var err := FeatureModeRules.saved_error(bad) + RuleUpgradeRules.saved_error(bad)
		check.call(not err.is_empty(), "038 saved state refuses %s" % label)
	var legacy := dto.duplicate(true)
	legacy.erase("rule_alternatives")
	for state in legacy.feature_modes.values():
		state.erase("window")
		state.erase("event_serial")
	var old := Character.new()
	old.from_dict(legacy)
	check.call(RuleUpgradeRules.saved_error(legacy).is_empty() and FeatureModeRules.saved_error(legacy).is_empty() and old.rule_alternatives.is_empty() and old.feature_modes[STANCE].mode == "bulwark", "038 legacy save without alternatives or switch windows still loads")
