class_name Batch057Checks
extends RefCounted
## Batch 057: authored combat-budget costs for mode activation, reselect and switch.

const RUSH := "fixture:b057_rush"
const STANCE := "fixture:b057_rush_stance"

class Budget:
	extends RefCounted
	var active_character: Character
	var budget := {"action": 1, "bonus_action": 1}
	var spent: Array = []
	func can_pay_mode_cost(cost: String) -> bool: return int(budget.get(cost, 0)) > 0
	func _spend_action_cost(cost: String) -> bool:
		if int(budget.get(cost, 0)) <= 0: return false
		budget[cost] = int(budget[cost]) - 1
		spent.append(cost)
		return true

static func load_fixtures() -> void:
	Batch052Checks.load_fixtures()
	if not DataLoader.get_feat(RUSH).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_057/feats/rush.json", "feat")

static func kit(c: Character) -> Character:
	while c.level < 4: c.level_up()
	FeatRules.choose_level_feat(c, RUSH)
	return c

static func state(c: Character) -> String:
	return JSON.stringify([c.feature_uses.get(STANCE, -1), c.feature_modes.get(STANCE, {})])

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_feat(RUSH).is_empty(), "057 Rush fixture feat loads: %s" % str(DataLoader.get_load_errors()))
	var base: Dictionary = DataLoader.get_feat(RUSH).features[0]
	var bad: Array = []
	for costs in [{"activate": "reaction"}, {"dismiss": "action"}, {}, "action", {"activate": 1}]:
		var f := base.duplicate(true)
		f.costs = costs
		bad.append(FeatureModeRules.validate_rule(f))
	var no_reselect := base.duplicate(true)
	no_reselect.erase("allow_reselect")
	bad.append(FeatureModeRules.validate_rule(no_reselect))
	var no_switch := base.duplicate(true)
	no_switch.erase("switch_events")
	bad.append(FeatureModeRules.validate_rule(no_switch))
	var rest_cost: Dictionary = DataLoader.get_feat(Batch052Checks.TIDE).features[1].duplicate(true)
	rest_cost.costs = {"activate": "action"}
	bad.append(FeatureModeRules.validate_rule(rest_cost))
	check.call(FeatureModeRules.validate_rule(base).is_empty() and bad.all(func(e): return not e.is_empty()), "057 loader refuses bad cost types, unknown acts, empty costs, costs for undeclared reselect/switch and costs on rest modes (%s)" % str(bad))
	var c := kit(Batch050Checks.actor("b057_costs"))
	var b := Budget.new()
	b.active_character = c
	var row := Batch052Checks.find(c, STANCE)
	var before := state(c)
	var canceled := ModeControls.apply(c, STANCE, "activate", "", row.token, b)
	c.feature_uses[STANCE] = 1
	var stale := ModeControls.apply(c, STANCE, "activate", "guard", row.token, b)
	c.feature_uses[STANCE] = 2
	before = state(c)
	row = Batch052Checks.find(c, STANCE)
	var other := Batch050Checks.actor("b057_other")
	b.active_character = other
	var wrong := ModeControls.apply(c, STANCE, "activate", "guard", row.token, b)
	b.active_character = c
	c.add_condition("stunned", 2)
	var stunned := ModeControls.apply(c, STANCE, "activate", "guard", Batch052Checks.find(c, STANCE).token, b)
	c.remove_condition("stunned")
	b.budget.bonus_action = 0
	var broke := ModeControls.apply(c, STANCE, "activate", "guard", Batch052Checks.find(c, STANCE).token, b)
	var outside := ModeControls.apply(c, STANCE, "activate", "guard", Batch052Checks.find(c, STANCE).token, null)
	check.call(canceled.reason == "canceled" and stale.reason == "stale" and wrong.reason == "wrong_turn" and stunned.reason in ["incapacitated", "unavailable"] and broke.reason == "unaffordable" and outside.reason == "not_in_combat" and state(c) == before and b.spent.is_empty() and b.budget.action == 1, "057 checklist (a): cancelled, stale, wrong-turn, incapacitated, unaffordable and out-of-combat attempts spend neither use nor budget (%s)" % str([stunned.reason]))
	b.budget.bonus_action = 1
	var on := ModeControls.apply(c, STANCE, "activate", "guard", Batch052Checks.find(c, STANCE).token, b)
	check.call(on.success and on.cost == "bonus_action" and b.spent == ["bonus_action"] and int(c.feature_uses[STANCE]) == 1 and c.feature_modes[STANCE].mode == "guard", "057 activation spends its declared Bonus Action and one use exactly once")
	var twice := ModeControls.apply(c, STANCE, "activate", "dash", Batch052Checks.find(c, STANCE).token, b)
	check.call(not twice.success and b.spent == ["bonus_action"] and int(c.feature_uses[STANCE]) == 1, "057 a second activation while active is refused and spends nothing")
	b.budget.action = 0
	var re_broke := ModeControls.apply(c, STANCE, "reselect", "dash", Batch052Checks.find(c, STANCE).token, b)
	b.budget.action = 1
	var re := ModeControls.apply(c, STANCE, "reselect", "dash", Batch052Checks.find(c, STANCE).token, b)
	check.call(re_broke.reason == "unaffordable" and re.success and b.spent == ["bonus_action", "action"] and c.feature_modes[STANCE].mode == "dash" and int(c.feature_uses[STANCE]) == 1, "057 reselect follows its declared policy: an Action, no use; refused without one")
	FeatureModeRules.on_event(c, "turn_start")
	var sw_broke := ModeControls.apply(c, STANCE, "switch", "guard", Batch052Checks.find(c, STANCE).token, b)
	b.budget.bonus_action = 1
	var sw := ModeControls.apply(c, STANCE, "switch", "guard", Batch052Checks.find(c, STANCE).token, b)
	check.call(sw_broke.reason == "unaffordable" and sw.success and b.spent == ["bonus_action", "action", "bonus_action"] and c.feature_modes[STANCE].mode == "guard" and int(c.feature_uses[STANCE]) == 1, "057 switch follows its declared policy: a Bonus Action in the open window, no use")
	# Undeclared costs stay free, in or out of combat (052 Tide).
	var t: Character = Batch052Checks.build("b057_free").c
	var tb := Budget.new()
	tb.active_character = t
	var free := ModeControls.apply(t, Batch052Checks.SURGE, "activate", "ebb", Batch052Checks.find(t, Batch052Checks.SURGE).token, tb)
	var free_re := ModeControls.apply(t, Batch052Checks.SURGE, "reselect", "flow", Batch052Checks.find(t, Batch052Checks.SURGE).token, tb)
	check.call(free.success and free_re.success and tb.spent.is_empty() and not free.has("cost") and int(t.feature_uses[Batch052Checks.SURGE]) == 1, "057 a mode with no declared cost keeps the free fixture behaviour")
	# Merged/suppressed gate: an unavailable copy is refused before any budget check.
	var g: Dictionary = Batch052Checks.build("b057_gate")
	Batch050Checks.mute(g.c, "b057_mute")
	var gb := Budget.new()
	gb.active_character = g.c
	var gate := ModeControls.apply(g.c, g.ward, "activate", "protect", ModeControls.row(g.c, g.ward).token, gb)
	check.call(not gate.success and gb.spent.is_empty() and ModeControls.cost(g.c, g.ward, "activate") == "none", "057 merged/suppressed gate: a suppressed copy spends neither use nor budget")
	# (b)/(d): costs live in authored data; saved state is unchanged and reloads.
	var back := Character.new()
	back.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check.call(ModeControls.cost(back, STANCE, "activate") == "bonus_action" and state(back) == state(c) and not JSON.stringify(c.to_dict()).contains("\"costs\""), "057 checklist (b)/(d): reload keeps the mode state; costs come from authored data, not the save")
