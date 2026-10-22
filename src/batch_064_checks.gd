class_name Batch064Checks
extends RefCounted
## Batch 064 (follow-up to 062): a mode used outside combat exposes the time its
## data declares (activation_seconds, else one 6-second round for a costed act).
## No clock is advanced: time passing is PARTIAL.

const WARD := "fixture:b064_slow_ward"
const MODE := "fixture:b064_slow_ward_mode"

static func load_fixtures() -> void:
	Batch057Checks.load_fixtures()
	if not DataLoader.get_feat(WARD).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_064/feats/ward.json", "feat")
	Batch049Checks.load_fixtures()
	DataLoader._load_json_file("res://data/fixtures/batch_064/items/slow_circlet.json", "item")

static func kit(c: Character) -> Character:
	while c.level < 4: c.level_up()
	FeatRules.choose_level_feat(c, WARD)
	return c

static func state(c: Character) -> String:
	return JSON.stringify([c.feature_uses.get(MODE, -1), c.feature_modes.get(MODE, {})])

static func _tok(c: Character) -> String:
	return ModeControls.row(c, MODE).token

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_feat(WARD).is_empty(), "064 Slow Ward fixture loads: %s" % str(DataLoader.get_load_errors()))
	# Loader validation of units.
	var base: Dictionary = DataLoader.get_feat(WARD).features[0]
	var bad: Array = []
	for t in [{}, 600, {"dismiss": 6}, {"activate": 0}, {"activate": 86401}, {"activate": 1.5}, {"activate": "10 minutes"}, {"activate": -6}]:
		var f := base.duplicate(true)
		f.activation_seconds = t
		if FeatureModeRules.validate_rule(f).is_empty(): bad.append(t)
	var rest := {"id": "x", "name": "x", "type": "mode_choice", "boundary": "rest", "rest": "long_rest", "modes": [{"id": "a"}, {"id": "b"}], "activation_seconds": {"activate": 6}}
	check.call(bad.is_empty() and not FeatureModeRules.validate_rule(rest).is_empty() and FeatureModeRules.validate_rule(base).is_empty(), "064 loader refuses non-object, unknown act, non-integer and out-of-range (1-86400 s) activation_seconds and rest modes declaring it (%s)" % str(bad))
	var prior: int = GameManager.current_state
	GameManager.current_state = GameManager.GameState.DUNGEON
	var out := ModeControls.outside_combat()
	var c := kit(Batch050Checks.actor("b064_ward"))
	check.call(FeatureModeRules.activation_seconds(c, MODE, "activate") == 600 and FeatureModeRules.activation_seconds(c, MODE, "reselect") == 6 and FeatureModeRules.activation_seconds(c, MODE, "choose") == 0, "064 declared activate time is read from data; an undeclared costed act takes one 6 s round")
	var offers := LocalRoomModes.offers(c)
	check.call(offers.size() == 1 and str(offers[0].text).contains("(Action; no turn outside combat) [takes 10 min; time not advanced]") and int(offers[0].activation_seconds) == 600, "064 room label shows the data duration (%s)" % str(offers.map(func(o): return o.text)))
	# (a) Refuse before paying: nothing spent, no duration reported.
	var before := state(c)
	var clock := int(GameManager.campaign_elapsed_seconds)
	var canceled := ModeControls.apply(c, MODE, "activate", "", _tok(c), out)
	var stale := ModeControls.apply(c, MODE, "activate", "warded", "old", out)
	c.add_condition("stunned", 2)
	var stunned := ModeControls.apply(c, MODE, "activate", "warded", _tok(c), out)
	c.remove_condition("stunned")
	GameManager.current_state = GameManager.GameState.COMBAT
	var in_combat := ModeControls.apply(c, MODE, "activate", "warded", _tok(c), out)
	GameManager.current_state = GameManager.GameState.DUNGEON
	var refusals := [canceled, stale, stunned, in_combat]
	check.call(not refusals.any(func(r): return r.success or r.has("activation_seconds")) and state(c) == before and int(GameManager.campaign_elapsed_seconds) == clock, "064 checklist (a): cancelled, stale, incapacitated and in-combat attempts spend nothing and report no time (%s)" % str(refusals.map(func(r): return r.reason)))
	var on := ModeControls.apply(c, MODE, "activate", "warded", _tok(c), out)
	check.call(on.success and int(on.get("activation_seconds", 0)) == 600 and on.get("time_advanced", true) == false and on.get("cost_outside_combat", "") == "action" and int(c.feature_uses[MODE]) == 1 and int(GameManager.campaign_elapsed_seconds) == clock, "064 the outside receipt carries the 600 s data duration; the clock is not advanced and one use is charged")
	var re := ModeControls.apply(c, MODE, "reselect", "swift", _tok(c), out)
	check.call(re.success and int(re.get("activation_seconds", 0)) == 6 and int(c.feature_uses[MODE]) == 1, "064 an undeclared costed reselect reports one 6 s round")
	# In combat the receipt is unchanged (the turn budget is the time).
	var b := Batch057Checks.Budget.new()
	b.active_character = c
	var in_re := ModeControls.apply(c, MODE, "reselect", "warded", _tok(c), b)
	check.call(in_re.success and not in_re.has("activation_seconds") and b.spent == ["bonus_action"], "064 in combat no duration is added to the receipt")
	# Legacy: an undeclared free mode reports nothing; 057 Rush unchanged.
	var f: Character = Batch052Checks.build("b064_free").c
	var free := ModeControls.apply(f, Batch052Checks.SURGE, "activate", "ebb", Batch052Checks.find(f, Batch052Checks.SURGE).token, out)
	check.call(free.success and not free.has("activation_seconds") and FeatureModeRules.validate_rule(DataLoader.get_feat(Batch057Checks.RUSH).features[0]).is_empty(), "064 legacy: a free undeclared mode reports no time; 057 Rush validates")
	# (b)/(d): no new saved field.
	var back := Character.new()
	back.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check.call(state(back) == state(c) and FeatureModeRules.saved_error(c.to_dict()).is_empty() and not JSON.stringify(c.to_dict()).contains("activation_seconds"), "064 checklist (b)/(d): no new saved state")
	# (e) merged/suppressed gate still runs before any duration is reported.
	var g := kit(Batch050Checks.actor("b064_gate"))
	var feat_copy: Dictionary = g.get_feature(MODE)
	check.call(str(feat_copy.get("source_instance_id", "")).is_empty() or ModeControls.row(g, MODE).available, "064 (e): the fixture is a feat (no item copy); the 057/062 merged/suppressed gate path is unchanged")
	_review_item_gate(check, out)
	check.call(ModeControls.duration_label(6) == "6 s" and ModeControls.duration_label(600) == "10 min" and ModeControls.duration_label(5400) == "1 h 30 min" and ModeControls.duration_label(3661) == "1 h 1 min 1 s", "064 duration labels")
	GameManager.current_state = prior

const SLOW := "fixture:b064_slow_circlet"

## Review R1 (e): an item-copy mode with a declared time. A merged or
## suppressed copy is refused before any time or use is reported; a live copy
## reports its 60 s.
static func _wear(id: String) -> Array:
	var a := Batch049Checks.actor(id)
	var cid := Batch041Checks.add_copy(a, SLOW)
	a.inventory.equip_instance(Inventory.Slot.HEAD, cid)
	a.inventory.attune_instance(cid, a.character_id)
	return [a, Batch049Checks.focus(cid)]

static func _review_item_gate(check: Callable, out: Variant) -> void:
	var live: Array = _wear("b064_r_live")
	var lc: Character = live[0]
	var ok := ModeControls.apply(lc, live[1], "activate", "ward", ModeControls.row(lc, live[1]).token, out)
	check.call(ok.success and int(ok.get("activation_seconds", 0)) == 60 and int(lc.feature_uses[live[1]]) == 1, "064 review (e): a live item-copy mode reports its declared 60 s (%s)" % str(ok))
	var m: Array = _wear("b064_r_merged")
	var mc: Character = m[0]
	var tok := str(ModeControls.row(mc, m[1]).token)
	Batch041Checks.guise(mc, "merged")
	var mr := ModeControls.apply(mc, m[1], "activate", "ward", str(ModeControls.row(mc, m[1]).get("token", tok)), out)
	var s: Array = _wear("b064_r_muted")
	var sc: Character = s[0]
	var stok := str(ModeControls.row(sc, s[1]).token)
	MagicPropertyRules.apply(sc, {"source_id": "b064_r_mute", "caster_id": sc.character_id, "spell_id": "b064_r"}, {"type": "suppress_item_magic", "properties": ["features"]})
	var sr := ModeControls.apply(sc, s[1], "activate", "ward", str(ModeControls.row(sc, s[1]).get("token", stok)), out)
	check.call(not mr.success and not mr.has("activation_seconds") and int(mc.feature_uses[m[1]]) == 2 and not sr.success and not sr.has("activation_seconds") and int(sc.feature_uses[s[1]]) == 2 and _mine(mc, m[1]) == 0 and _mine(sc, s[1]) == 0, "064 review (e): merged and suppressed item copies are refused before any use or time is reported (%s / %s; uses %s %s; offers %d %d)" % [str(mr.get("reason", "")), str(sr.get("reason", "")), str(mc.feature_uses.get(m[1])), str(sc.feature_uses.get(s[1])), _mine(mc, m[1]), _mine(sc, s[1])])

static func _mine(a: Character, fid: String) -> int:
	return LocalRoomModes.offers(a).filter(func(o): return o.feature_id == fid).size()
