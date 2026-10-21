class_name Batch052Checks
extends RefCounted
## Batch 052 (card Q-20261021-004820-732c): ModeControls, the HUD's single
## view and entry point for owned modes and exclusive upgrade options.

const TIDE := "fixture:b052_tide"
const SURGE := "fixture:b052_tide_surge"
const MOOD := "fixture:b052_tide_mood"

static func load_fixtures() -> void:
	Batch051Checks.load_fixtures()
	if not DataLoader.get_feat(TIDE).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_052/feats/tide.json", "feat")

## Level-4 fighter: Origin feat Vigil, Tide taken through the level-up feat path, a Warding Blade wielded.
static func build(id: String) -> Dictionary:
	return kit(Batch050Checks.actor(id))

static func kit(c: Character) -> Dictionary:
	c.inventory.unequip(Inventory.Slot.SHIELD)
	FeatRules.choose_origin(c, Batch051Checks.VIGIL)
	while c.level < 4: c.level_up()
	FeatRules.choose_level_feat(c, TIDE)
	var blade := Batch050Checks.wield(c)
	return {"c": c, "blade": blade, "ward": Batch050Checks.ward(blade)}

static func find(c: Character, feature_id: String) -> Dictionary:
	for r in ModeControls.rows(c):
		if r.feature_id == feature_id: return r
	return {}

static func snapshot(c: Character) -> String:
	return JSON.stringify([c.feature_uses, c.feature_modes, c.rule_alternatives])

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_feat(TIDE).is_empty(), "052 Tide fixture feat loads: %s" % str(DataLoader.get_load_errors()))
	var b := build("b052_rows")
	var c: Character = b.c
	var rows := ModeControls.rows(c)
	var ids: Array = rows.map(func(r): return r.feature_id)
	check.call(ids.count(SURGE) == 1 and ids.count(MOOD) == 1 and ids.count(Batch051Checks.WATCH) == 1 and ids.count(b.ward) == 1, "052 the HUD view lists each owned mode once: feat, origin feat and exact item copy (%s)" % str(ids))
	var surge := find(c, SURGE)
	check.call(surge.actions == ["activate"] and ModeControls.label(surge) == "Mode: Tide Surge (2/2 uses)" and find(c, MOOD).actions == ["choose"] and find(c, b.ward).actions == ["activate", "alternative"], "052 rows show uses and offer only legal actions")
	_refusals(check, b)
	_flow(check, b)
	_gate(check)
	_reload(check, b)

static func _refusals(check: Callable, b: Dictionary) -> void:
	var c: Character = b.c
	var before := snapshot(c)
	var t: String = find(c, SURGE).token
	var canceled := ModeControls.apply(c, SURGE, "activate", "", t)
	var unknown := ModeControls.apply(c, SURGE, "activate", "nope", t)
	var illegal := ModeControls.apply(c, SURGE, "switch", "flow", t)
	var bad_kind := ModeControls.apply(c, SURGE, "end", "", t)
	check.call(canceled.reason == "canceled" and unknown.reason == "unknown_option" and illegal.reason == "unavailable" and not bad_kind.success and snapshot(c) == before, "052 checklist (a): cancel, unknown option, unoffered action and unknown kind spend nothing")
	var stale_token := t
	c.feature_uses[SURGE] = 1 # Something else spent a use after the popup opened.
	var stale := ModeControls.apply(c, SURGE, "activate", "ebb", stale_token)
	check.call(stale.reason == "stale" and int(c.feature_uses[SURGE]) == 1 and not bool(c.feature_modes.get(SURGE, {}).get("active", false)), "052 checklist (a): a stale popup answer is refused and spends nothing")
	c.feature_uses[SURGE] = 2

static func _flow(check: Callable, b: Dictionary) -> void:
	var c: Character = b.c
	var on := ModeControls.apply(c, SURGE, "activate", "ebb", find(c, SURGE).token)
	var r := find(c, SURGE)
	check.call(on.success and int(c.feature_uses[SURGE]) == 1 and r.active and r.mode == "ebb" and r.actions == ["reselect"] and ModeControls.label(r) == "Mode: Tide Surge (1/2 uses) [ebb, 60s left]", "052 activate spends one use; the row shows the mode and remaining time")
	var again := ModeControls.apply(c, SURGE, "activate", "flow", r.token)
	var re := ModeControls.apply(c, SURGE, "reselect", "flow", find(c, SURGE).token)
	check.call(again.reason == "unavailable" and re.success and c.feature_modes[SURGE].mode == "flow" and int(c.feature_uses[SURGE]) == 1, "052 an active power cannot be activated twice; reselect changes the mode without spending")
	FeatureModeRules.on_event(c, "turn_start")
	r = find(c, SURGE)
	var sw := ModeControls.apply(c, SURGE, "switch", "ebb", r.token)
	check.call("switch" in r.actions and sw.success and c.feature_modes[SURGE].mode == "ebb" and "switch" not in find(c, SURGE).actions and int(c.feature_uses[SURGE]) == 1, "052 a declared turn-start window offers one switch")
	var mood := ModeControls.apply(c, MOOD, "choose", "storm", find(c, MOOD).token)
	check.call(mood.success and find(c, MOOD).actions.is_empty() and ModeControls.label(find(c, MOOD)) == "Mode: Tide Mood [storm]", "052 a rest mode is chosen once until the next Long Rest")
	var w: Dictionary = find(c, b.ward)
	var options := ModeControls.options(w, "alternative")
	var pick := ModeControls.apply(c, b.ward, "alternative", "edge|deep@" + b.blade, w.token)
	check.call(options == ["edge|deep@" + b.blade] and pick.success and c.get_feature_max_uses(b.ward) == 3 and find(c, b.ward).alternatives[0].chosen == "deep@" + b.blade, "052 the upgrade picker lists the other exclusive option and choosing it applies (3 uses)")
	var won := ModeControls.apply(c, b.ward, "activate", "protect", find(c, b.ward).token)
	check.call(won.success and "alternative" not in find(c, b.ward).actions, "052 upgrade options are not offered while the upgraded power is active")

static func _gate(check: Callable) -> void:
	var b := build("b052_gate")
	var c: Character = b.c
	Batch050Checks.mute(c, "b052_mute")
	var r := find(c, b.ward)
	var before := snapshot(c)
	var refused := ModeControls.apply(c, b.ward, "activate", "protect", r.token)
	var alt := ModeControls.apply(c, b.ward, "alternative", "edge|deep@" + b.blade, r.token)
	check.call(not r.available and r.reason == "suppressed" and r.actions.is_empty() and ModeControls.label(r).ends_with("[Unavailable: suppressed]") and not refused.success and not alt.success and snapshot(c) == before, "052 merged/suppressed gate: a suppressed copy shows unavailable and its controls spend nothing")
	var offered: String = find(c, b.ward).token
	c.spell_effects.erase("b052_mute")
	var late := ModeControls.apply(c, b.ward, "activate", "protect", offered)
	check.call(late.reason == "stale" and snapshot(c) == before and find(c, b.ward).available, "052 a popup offered while suppressed is stale once suppression ends")
	var m := build("b052_merged")
	Batch041Checks.guise(m.c, "merged")
	var mr := ModeControls.row(m.c, m.ward)
	var m_before := snapshot(m.c)
	var m_refused := ModeControls.apply(m.c, m.ward, "activate", "protect", mr.token)
	check.call(ActorProjectionRules.merged(m.c, m.blade) and not mr.available and mr.reason == "merged" and not m_refused.success and snapshot(m.c) == m_before, "052 merged/suppressed gate: a copy merged into a form shows unavailable and spends nothing")

static func _reload(check: Callable, b: Dictionary) -> void:
	var c: Character = b.c
	var back := Character.new()
	back.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var strip := func(rows): return rows.map(func(r): return [r.feature_id, ModeControls.label(r), r.actions, r.alternatives])
	check.call(strip.call(ModeControls.rows(back)) == strip.call(ModeControls.rows(c)), "052 checklist (d): reload shows the same modes, uses, time and upgrade choices")
