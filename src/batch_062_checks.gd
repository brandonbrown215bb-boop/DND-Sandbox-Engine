class_name Batch062Checks
extends RefCounted
## Batch 062 (queue item 4): costed modes are usable outside combat. No action
## economy is spent outside initiative; uses are still charged exactly once.

const STANCE := Batch057Checks.STANCE

static func _tok(c: Character) -> String:
	return Batch052Checks.find(c, STANCE).token

static func run(check: Callable) -> void:
	Batch057Checks.load_fixtures()
	var prior: int = GameManager.current_state
	GameManager.current_state = GameManager.GameState.DUNGEON
	var out := ModeControls.outside_combat()
	var c := Batch057Checks.kit(Batch050Checks.actor("b062_out"))
	var before := Batch057Checks.state(c)
	var offered := LocalRoomModes.offers(c)
	check.call(offered.size() == 1 and offered[0].kind == "activate" and str(offered[0].text).contains("(Bonus Action; no turn outside combat)") and ModeControls.cost_error(c, STANCE, "activate", out).is_empty(), "062 room offers the costed activation outside combat with its cost shown (%s)" % str(offered.map(func(o): return o.text)))
	# (a) Refuse before paying.
	var canceled := ModeControls.apply(c, STANCE, "activate", "", _tok(c), out)
	var t := _tok(c)
	c.feature_uses[STANCE] = 1
	var stale := ModeControls.apply(c, STANCE, "activate", "guard", t, out)
	c.feature_uses[STANCE] = 2
	c.add_condition("stunned", 2)
	var stunned_offers := LocalRoomModes.offers(c)
	var stunned := ModeControls.apply(c, STANCE, "activate", "guard", _tok(c), out)
	var stunned_cost := ModeControls.cost_error(c, STANCE, "activate", out)
	c.remove_condition("stunned")
	c.feature_uses[STANCE] = 0
	var empty_offers := LocalRoomModes.offers(c)
	var empty := ModeControls.apply(c, STANCE, "activate", "guard", _tok(c), out)
	c.feature_uses[STANCE] = 2
	GameManager.current_state = GameManager.GameState.COMBAT
	var in_combat := ModeControls.apply(c, STANCE, "activate", "guard", _tok(c), out)
	GameManager.current_state = GameManager.GameState.DUNGEON
	var legacy_null := ModeControls.apply(c, STANCE, "activate", "guard", _tok(c), null)
	check.call(canceled.reason == "canceled" and stale.reason == "stale" and stunned.reason in ["incapacitated", "unavailable"] and stunned_cost == "incapacitated" and stunned_offers.is_empty() and empty.reason == "unavailable" and empty_offers.is_empty() and in_combat.reason == "in_combat" and legacy_null.reason == "not_in_combat" and Batch057Checks.state(c) == before, "062 checklist (a): cancelled, stale, incapacitated, no-uses and in-combat outside attempts spend nothing; a null budget keeps 057's refusal (%s)" % str([stunned.reason, empty.reason]))
	var on := ModeControls.apply(c, STANCE, "activate", "guard", _tok(c), out)
	check.call(on.success and on.get("cost_outside_combat", "") == "bonus_action" and not on.has("cost") and int(c.feature_uses[STANCE]) == 1 and c.feature_modes[STANCE].mode == "guard", "062 outside activation charges one use exactly once and no action economy")
	var twice := ModeControls.apply(c, STANCE, "activate", "dash", _tok(c), out)
	var re := ModeControls.apply(c, STANCE, "reselect", "dash", _tok(c), out)
	check.call(not twice.success and re.success and re.get("cost_outside_combat", "") == "action" and int(c.feature_uses[STANCE]) == 1 and c.feature_modes[STANCE].mode == "dash", "062 outside reselect follows its policy and spends no use; a second activation is refused")
	# Carry-over into combat: the live state is the same record the combat budget sees.
	var b := Batch057Checks.Budget.new()
	b.active_character = c
	var row := Batch052Checks.find(c, STANCE)
	var in_re := ModeControls.apply(c, STANCE, "reselect", "guard", row.token, b)
	check.call("activate" not in row.actions and "reselect" in row.actions and in_re.success and b.spent == ["action"] and int(c.feature_uses[STANCE]) == 1 and c.feature_modes[STANCE].mode == "guard", "062 an outside-activated mode carries into combat: no re-activation, reselect pays the combat Action")
	# (b)/(d): no new saved field; state reloads.
	var back := Character.new()
	back.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check.call(Batch057Checks.state(back) == Batch057Checks.state(c) and FeatureModeRules.saved_error(c.to_dict()).is_empty() and not JSON.stringify(c.to_dict()).contains("outside_combat"), "062 checklist (b)/(d): no new saved state; the mode reloads unchanged")
	# Free modes unchanged outside combat (052 Tide).
	var f: Character = Batch052Checks.build("b062_free").c
	var free := ModeControls.apply(f, Batch052Checks.SURGE, "activate", "ebb", Batch052Checks.find(f, Batch052Checks.SURGE).token, out)
	check.call(free.success and not free.has("cost_outside_combat") and not free.has("cost"), "062 an undeclared-cost mode stays free outside combat")
	# Merged/suppressed gate holds outside combat.
	var g: Dictionary = Batch052Checks.build("b062_gate")
	Batch050Checks.mute(g.c, "b062_mute")
	var gate := ModeControls.apply(g.c, g.ward, "activate", "protect", ModeControls.row(g.c, g.ward).token, out)
	check.call(not gate.success and gate.reason == "unavailable", "062 merged/suppressed gate: a suppressed copy is refused outside combat")
	GameManager.current_state = prior
