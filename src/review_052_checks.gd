class_name Review052Checks
extends RefCounted
## Review 052 stress checks for ModeControls (card Q-20261021-004820-732c).

const SURGE := Batch052Checks.SURGE

static func run(check: Callable) -> void:
	Batch052Checks.load_fixtures()
	_t1_incapacitated(check)
	_t2_double_answer(check)
	_t3_two_copies(check)
	_t4_form_ends(check)
	_t5_switch_caps(check)
	_t6_feat_owned_reload(check)

## T1 (R1): an incapacitated actor is offered nothing at the activation boundary and a direct request spends nothing.
static func _t1_incapacitated(check: Callable) -> void:
	var b := Batch052Checks.build("r052_t1")
	var c: Character = b.c
	c.add_condition("stunned", 3)
	var r := Batch052Checks.find(c, SURGE)
	var before := Batch052Checks.snapshot(c)
	var via_hud := ModeControls.apply(c, SURGE, "activate", "ebb", r.token)
	var direct := FeatureModeRules.activate(c, SURGE, "ebb")
	check.call(r.actions.is_empty() and not r.available and r.reason == "incapacitated" and not via_hud.success and not direct.success and Batch052Checks.snapshot(c) == before and int(c.feature_uses[SURGE]) == 2, "R052 T1 a stunned actor is offered no activation and a request spends nothing (%s / %s / uses %s)" % [str(r.actions), str(direct.reason), str(c.feature_uses[SURGE])])

## T2: answering the same offer twice (double click) applies once.
static func _t2_double_answer(check: Callable) -> void:
	var b := Batch052Checks.build("r052_t2")
	var c: Character = b.c
	var t: String = Batch052Checks.find(c, SURGE).token
	var first := ModeControls.apply(c, SURGE, "activate", "ebb", t)
	var second := ModeControls.apply(c, SURGE, "activate", "flow", t)
	check.call(first.success and second.reason == "stale" and int(c.feature_uses[SURGE]) == 1 and c.feature_modes[SURGE].mode == "ebb", "R052 T2 a double-clicked answer applies once")

## T3: two identical blades show two rows with separate pools.
static func _t3_two_copies(check: Callable) -> void:
	var b := Batch052Checks.build("r052_t3")
	var c: Character = b.c
	var other := Batch050Checks.wield(c, Inventory.Slot.OFFHAND)
	var w2 := Batch050Checks.ward(other)
	var ids: Array = ModeControls.rows(c).map(func(r): return r.feature_id)
	var u2 := int(c.feature_uses.get(c.get_feature(w2).get("resource_id", w2), 0))
	var on := ModeControls.apply(c, b.ward, "activate", "protect", Batch052Checks.find(c, b.ward).token)
	var r2 := Batch052Checks.find(c, w2)
	check.call(ids.count(b.ward) == 1 and ids.count(w2) == 1 and on.success and r2.uses == u2 and u2 > 0 and "activate" in r2.actions, "R052 T3 two identical copies list separately and spend separate pools (%s)" % str(ids))

## T4: a popup offered during a form is stale after the form ends; one offered after it works.
static func _t4_form_ends(check: Callable) -> void:
	var m := Batch052Checks.build("r052_t4")
	var c: Character = m.c
	Batch041Checks.guise(c, "merged")
	var t: String = ModeControls.row(c, m.ward).token
	SpellEffects.end_concentration(c, [c])
	var before := Batch052Checks.snapshot(c)
	var late := ModeControls.apply(c, m.ward, "activate", "protect", t)
	var fresh := ModeControls.row(c, m.ward)
	check.call(not ActorProjectionRules.merged(c, m.blade) and late.reason == "stale" and Batch052Checks.snapshot(c) == before and fresh.available and "activate" in fresh.actions, "R052 T4 a popup from inside a form is stale once the form ends (%s)" % str(late.reason))

## T5: switching the upgrade back through the HUD caps held uses (038 R1).
static func _t5_switch_caps(check: Callable) -> void:
	var b := Batch052Checks.build("r052_t5")
	var c: Character = b.c
	var w: Dictionary = Batch052Checks.find(c, b.ward)
	var start: String = w.alternatives[0].chosen
	ModeControls.apply(c, b.ward, "alternative", "edge|deep@" + b.blade, w.token)
	var pool := str(c.get_feature(b.ward).get("resource_id", b.ward))
	c.feature_uses[pool] = 3
	var back := ModeControls.apply(c, b.ward, "alternative", "edge|" + start, Batch052Checks.find(c, b.ward).token)
	check.call(back.success and int(c.feature_uses[pool]) == c.get_feature_max_uses(pool) and c.get_feature_max_uses(pool) < 3, "R052 T5 switching back to the smaller option through the HUD caps held uses (%s/%s)" % [str(c.feature_uses[pool]), str(c.get_feature_max_uses(pool))])

## T6: feat-owned modes (051 Origin + level feat) survive a round trip and stay operable.
static func _t6_feat_owned_reload(check: Callable) -> void:
	var b := Batch052Checks.build("r052_t6")
	var c: Character = b.c
	ModeControls.apply(c, SURGE, "activate", "flow", Batch052Checks.find(c, SURGE).token)
	var back := Character.new()
	back.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var watch := Batch052Checks.find(back, Batch051Checks.WATCH)
	var s := Batch052Checks.find(back, SURGE)
	var re := ModeControls.apply(back, SURGE, "reselect", "ebb", s.token)
	check.call(not watch.is_empty() and watch.available and s.active and s.uses == 1 and re.success and int(back.feature_uses[SURGE]) == 1, "R052 T6 feat-owned modes reload and stay operable without spending")
