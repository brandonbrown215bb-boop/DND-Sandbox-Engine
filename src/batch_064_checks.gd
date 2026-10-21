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
	check.call(ModeControls.duration_label(6) == "6 s" and ModeControls.duration_label(600) == "10 min" and ModeControls.duration_label(5400) == "1 h 30 min" and ModeControls.duration_label(3661) == "1 h 1 min 1 s", "064 duration labels")
	GameManager.current_state = prior
