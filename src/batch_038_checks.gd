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
	review_stress(check)
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

## Reviewer stress cases (Batch 038 review).
static func review_stress(check: Callable) -> void:
	load_fixtures()
	# RW1 window discipline: no window without an event; one switch per window; later events close it; parent fixed.
	var a := actor("b038_rw_a", 1)
	FeatureModeRules.activate(a, STANCE, "guard")
	var before: Dictionary = a.feature_modes[STANCE].duplicate(true)
	var uses := int(a.feature_uses[STANCE])
	check.call(FeatureModeRules.switch(a, STANCE, "stride", "turn_start").reason == "no_window", "038 review RW1 switching with no open window refuses")
	check.call(FeatureModeRules.on_event(a, "hit").is_empty() and FeatureModeRules.switch(a, STANCE, "stride", "hit").reason == "no_window", "038 review RW1 an undeclared event (hit at level 1) opens no window")
	FeatureModeRules.on_event(a, "turn_start")
	var s1 := FeatureModeRules.switch(a, STANCE, "stride", "turn_start")
	var st: Dictionary = a.feature_modes[STANCE]
	check.call(s1.success and int(a.feature_uses[STANCE]) == uses and int(st.remaining_seconds) == int(before.remaining_seconds) and int(st.activation_serial) == int(before.activation_serial) and int(st.rolled) == int(before.rolled), "038 review RW1 switch keeps uses, deadline, serial and roll")
	check.call(not FeatureModeRules.switch(a, STANCE, "guard", "turn_start").success, "038 review RW1 one window allows one switch")
	FeatureModeRules.on_event(a, "turn_start")
	FeatureModeRules.on_event(a, "hit")
	check.call(FeatureModeRules.switch(a, STANCE, "guard", "turn_start").reason == "no_window", "038 review RW1 a later event closes the older window")
	# RW2 a miss never opens a hit window (level 2 declares hit).
	var b := actor("b038_rw_b", 2)
	FeatureModeRules.activate(b, STANCE, "guard")
	var wall := {"id": "b038_wall", "name": "Wall", "armor_class": 1000, "current_hp": 50, "max_hp": 50, "is_alive": true, "conditions": {}}
	var res := CombatAction.resolve_weapon_attack(b, wall, DataLoader.get_item("longsword").duplicate(true), false, false, {})
	check.call(not res.get("hit", true) and not b.feature_modes[STANCE].has("window"), "038 review RW2 a missed attack opens no hit window")
	var soft := {"id": "b038_soft", "name": "Soft", "armor_class": -100, "current_hp": 500, "max_hp": 500, "is_alive": true, "conditions": {}}
	res = CombatAction.resolve_weapon_attack(b, soft, DataLoader.get_item("longsword").duplicate(true), false, false, {})
	check.call(res.get("hit", false) and str(b.feature_modes[STANCE].get("window", {}).get("event", "")) == "hit" and FeatureModeRules.switch(b, STANCE, "bulwark", "hit").success, "038 review RW2 a settled hit opens one window usable for an added mode")
	# RW3 removed mode cannot be switched to or activated; reload keeps state safe.
	check.call(FeatureModeRules.on_event(b, "turn_start").size() == 1 and FeatureModeRules.switch(b, STANCE, "stride", "turn_start").reason == "unknown_mode", "038 review RW3 a mode removed by an upgrade is not a legal switch target")
	var b2 := Character.new()
	b2.from_dict(b.to_dict())
	check.call(FeatureModeRules.saved_error(b.to_dict()).is_empty() and str(b2.feature_modes[STANCE].mode) == "bulwark" and b2.feature_modes[STANCE].has("window") == b.feature_modes[STANCE].has("window") and b2.get_ac() == b.get_ac(), "038 review RW3 reload keeps switched mode, window and one grant")
	check.call(FeatureModeRules.switch(b2, STANCE, "guard", "turn_start").success and not FeatureModeRules.switch(b2, STANCE, "bulwark", "turn_start").success, "038 review RW3 a reloaded window is still single-use")
	# RW4 tampered windows/events refuse; legacy (no window/event_serial, no rule_alternatives) loads.
	var dto := b.to_dict()
	dto.feature_modes[STANCE]["event_serial"] = 3
	dto.feature_modes[STANCE]["window"] = {"event": "hit", "serial": 3}
	check.call(FeatureModeRules.saved_error(dto).is_empty(), "038 review RW4 a consistent saved window validates")
	for defect in ["future", "event", "inactive", "shape"]:
		var bad := dto.duplicate(true)
		match defect:
			"future": bad.feature_modes[STANCE].window.serial = 9
			"event": bad.feature_modes[STANCE].window.event = "crit"
			"inactive":
				bad.feature_modes[STANCE].active = false
				bad.feature_modes[STANCE].mode = ""
			"shape": bad.feature_modes[STANCE].window["extra"] = 1
		check.call(not FeatureModeRules.saved_error(bad).is_empty(), "038 review RW4 tampered window %s refuses" % defect)
	var legacy := dto.duplicate(true)
	legacy.feature_modes[STANCE].erase("window")
	legacy.feature_modes[STANCE].erase("event_serial")
	legacy.erase("rule_alternatives")
	check.call(FeatureModeRules.saved_error(legacy).is_empty() and RuleUpgradeRules.saved_error(legacy).is_empty(), "038 review RW4 legacy state without window/alternatives loads")
	# RW5 exclusive alternatives: default, choice, no stacking, no free uses, clamp on switching away, refusal while active.
	var c := actor("b038_rw_c", 3)
	var eff := FeatureModeRules.rule(c, STANCE)
	check.call(eff.alternatives.focus.chosen == "fixture:b038_alt_a" and int(eff.get("targets", 1)) == 2 and int(eff.uses) == 2, "038 review RW5 default alternative applies alone (targets+1, uses unchanged)")
	check.call(RuleUpgradeRules.choose_alternative(c, STANCE, "focus", "fixture:b038_alt_b") and int(FeatureModeRules.rule(c, STANCE).uses) == 3 and int(FeatureModeRules.rule(c, STANCE).get("targets", 1)) == 1 and int(c.feature_uses[STANCE]) == 2, "038 review RW5 choosing the other alternative swaps (uses+1, targets back) without granting a use")
	c.long_rest()
	check.call(int(c.feature_uses[STANCE]) == 3, "038 review RW5 the new maximum fills at the next Long Rest")
	RuleUpgradeRules.choose_alternative(c, STANCE, "focus", "fixture:b038_alt_a")
	check.call(int(c.feature_uses[STANCE]) <= c.get_feature_max_uses(STANCE), "038 review RW5 switching away from the uses alternative cannot keep uses above the new maximum (%d > %d)" % [int(c.feature_uses[STANCE]), c.get_feature_max_uses(STANCE)])
	FeatureModeRules.activate(c, STANCE, "guard")
	check.call(not RuleUpgradeRules.choose_alternative(c, STANCE, "focus", "fixture:b038_alt_b") and not RuleUpgradeRules.choose_alternative(c, STANCE, "focus", "fixture:not_owned"), "038 review RW5 alternatives refuse while active and for unowned options")
	# RW6 saved alternatives: owned choice loads; unowned/under-level/tampered refuse and restore safely.
	var cd := c.to_dict()
	check.call(RuleUpgradeRules.saved_error(cd).is_empty(), "038 review RW6 owned alternative DTO validates")
	for defect in ["id", "level", "key"]:
		var bad := cd.duplicate(true)
		match defect:
			"id": bad.rule_alternatives[STANCE + "|focus"] = "fixture:b038_widen"
			"level": bad["level"] = 2
			"key": bad.rule_alternatives = {"nonsense": "fixture:b038_alt_b"}
		var r: Character = Character.new()
		r.from_dict(bad)
		check.call(not RuleUpgradeRules.saved_error(bad).is_empty() and r.rule_alternatives.is_empty(), "038 review RW6 tampered alternative %s refuses and restores nothing" % defect)
	# RW7 F1 fails safe: a non-class (appended) rule's state refuses the save instead of being trusted.
	var f1 := Batch037Checks.actor("b038_rw_f1")
	f1.features.append(catalog("1", 0).duplicate(true))
	f1.feature_uses[STANCE] = 2
	FeatureModeRules.activate(f1, STANCE, "guard")
	var fd := f1.to_dict()
	var f2 := Character.new()
	f2.from_dict(fd)
	check.call(not FeatureModeRules.saved_error(fd).is_empty() and not f2.feature_modes.has(STANCE), "038 review RW7 F1 non-class mode state is refused, not restored half-trusted")
