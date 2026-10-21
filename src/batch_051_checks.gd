class_name Batch051Checks
extends RefCounted
## Batch 051 (card Q-20261021-004820-aaf1): Origin feat at creation and a feat
## in place of an Ability Score Improvement at level-up (SRD 5.2.1 p.83, p.87,
## class ASI features), acquired through OwnedFeatureSources.

const VIGIL := "fixture:b051_vigil"
const GRIT := "fixture:b051_grit"
const BRAINY := "fixture:b051_brainy"
const CAPSTONE := "fixture:b051_capstone"
const WATCH := "fixture:b051_vigil_watch"
const STANCE := "fixture:b051_grit_stance"

static func load_fixtures() -> void:
	Batch050Checks.load_fixtures()
	if not DataLoader.get_feat(GRIT).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_051/feats/choices.json", "feat")

## A real level-1 human fighter (STR 16), as character creation builds one.
static func fresh(id: String) -> Character:
	return Batch031Checks._character(id, 40)

static func _feat_loads(data: Dictionary) -> bool:
	var before := DataLoader._load_errors.size()
	var ok: bool = DataLoader._validate_content(data, "feat", "batch_051_probe")
	DataLoader._load_errors.resize(before)
	return ok

static func _count(c: Character, id: String) -> int:
	return c.features.filter(func(f): return str(f.get("id", "")) == id).size()

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_feat(GRIT).is_empty(), "051 origin/general/epic fixture feats load: %s" % str(DataLoader.get_load_errors()))
	_loader(check)
	_origin(check)
	_level(check)
	_reload(check)
	_tamper(check)

static func _loader(check: Callable) -> void:
	var base := {"id": "p", "name": "P", "features": []}
	var no_cat := base.duplicate(true)
	var rep := base.duplicate(true)
	rep["category"] = "general"
	rep["repeatable"] = true
	rep["features"] = DataLoader.get_feat(VIGIL).features.duplicate(true)
	var bad_pre := base.duplicate(true)
	bad_pre["category"] = "general"
	bad_pre["prerequisite"] = {"level": 4, "class": "fighter"}
	var good := base.duplicate(true)
	good["category"] = "origin"
	check.call(_feat_loads(good) and not _feat_loads(no_cat) and not _feat_loads(rep) and not _feat_loads(bad_pre), "051 loader refuses a feat without category, a repeatable feat with features and an unsupported prerequisite")

static func _origin(check: Callable) -> void:
	var c := fresh("b051_origin")
	var general := FeatRules.choose_origin(c, GRIT)
	check.call(not general.success and c.origin_feat.is_empty() and not c.has_feature(STANCE), "051 checklist (a): a General feat is refused as the Origin feat and nothing changes")
	var ok := FeatRules.choose_origin(c, VIGIL)
	var again := FeatRules.choose_origin(c, Batch049Checks.FEAT)
	check.call(ok.success and c.origin_feat == VIGIL and c.has_feature(WATCH) and int(c.feature_uses[WATCH]) == 1 and not again.success and c.origin_feat == VIGIL, "051 the Origin feat is acquired once at creation with its rule and uses; a second Origin pick is refused")
	check.call(VIGIL not in FeatRules.options(c, "origin") and FeatRules.options(c, "origin").has(Batch049Checks.FEAT), "051 an owned non-repeatable feat is no longer offered")

static func _level(check: Callable) -> void:
	var c := fresh("b051_level")
	FeatRules.choose_origin(c, VIGIL)
	var early := FeatRules.choose_level_feat(c, GRIT)
	check.call(not early.success and c.feature_choices.size() == fresh("b051_level_probe").feature_choices.size(), "051 checklist (a): no feat can be taken without a pending Ability Score Improvement")
	while c.level < 4: c.level_up()
	var pending := ClassProgression.pending_improvements(c)
	var choices_before := c.feature_choices.duplicate(true)
	var spent_before := int(c.fighter_training.get("asi_spent", 0))
	var refused := [FeatRules.choose_level_feat(c, BRAINY), FeatRules.choose_level_feat(c, CAPSTONE), FeatRules.choose_level_feat(c, VIGIL), FeatRules.choose_level_feat(c, "fixture:b051_nope")]
	check.call(pending.size() == 1 and refused.all(func(r): return not r.success) and c.feature_choices == choices_before and int(c.fighter_training.get("asi_spent", 0)) == spent_before and ClassProgression.pending_improvements(c) == pending, "051 checklist (a): unmet ability, level, duplicate and unknown feats are refused before the improvement is spent")
	check.call("requires INT 18+" in str(refused[0].message) and "level 19" in str(refused[1].message), "051 refusal messages name the unmet prerequisite (%s / %s)" % [refused[0].message, refused[1].message])
	check.call(GRIT in FeatRules.options(c, "") and BRAINY not in FeatRules.options(c, ""), "051 the level-up list offers only feats the character qualifies for")
	var took := FeatRules.choose_level_feat(c, GRIT)
	check.call(took.success and ClassProgression.pending_improvements(c).is_empty() and c.feature_choices[pending[0]] == ["feat:" + GRIT] and c.has_feature(STANCE) and c.get_feature_max_uses(STANCE) == 3 and int(c.feature_uses[STANCE]) == 3 and int(c.fighter_training.asi_spent) == spent_before + 1, "051 taking a feat spends the improvement and acquires its rule with its own upgrade (3 uses)")

static func _built() -> Character:
	var c := fresh("b051_reload")
	FeatRules.choose_origin(c, VIGIL)
	while c.level < 4: c.level_up()
	FeatRules.choose_level_feat(c, GRIT)
	FeatureModeRules.activate(c, STANCE, "brace")
	FeatureModeRules.activate(c, WATCH, "alert")
	FeatureModeRules.advance_time(c, 12)
	return c

static func _reload(check: Callable) -> void:
	var c := _built()
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	check.call(ClassProgression.saved_choices_error(dto).is_empty() and FeatureModeRules.saved_error(dto).is_empty() and dto.origin_feat == VIGIL, "051 origin and level-up feat state pass both save checks")
	var back := Character.new()
	back.from_dict(dto)
	var twice := Character.new()
	twice.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())))
	for x in [back, twice]:
		check.call(x.origin_feat == VIGIL and _count(x, STANCE) == 1 and _count(x, WATCH) == 1 and x.feature_modes == c.feature_modes and int(x.feature_uses[STANCE]) == 2 and int(x.feature_uses[WATCH]) == 0 and SourceBenefitRules.total(x, "AC") == SourceBenefitRules.total(c, "AC") and ClassProgression.pending_improvements(x).is_empty(), "051 reload keeps both feats, choices, uses and deadlines exactly once")
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(fresh("b051_legacy").to_dict()))
	legacy.erase("origin_feat")
	var old := Character.new()
	old.from_dict(legacy)
	check.call(ClassProgression.saved_choices_error(legacy).is_empty() and old.origin_feat.is_empty(), "051 a legacy save without origin_feat still loads")

static func _tamper(check: Callable) -> void:
	var dto: Dictionary = JSON.parse_string(JSON.stringify(_built().to_dict()))
	var asi := ""
	for id in dto.feature_choices:
		if dto.feature_choices[id] == ["feat:" + GRIT]: asi = id
	var epic := dto.duplicate(true)
	epic.feature_choices[asi] = ["feat:" + CAPSTONE]
	var unmet_ability := dto.duplicate(true)
	unmet_ability.feature_choices[asi] = ["feat:" + BRAINY]
	var dex_only := dto.duplicate(true)
	dex_only.ability_scores["STR"] = 10
	dex_only.ability_scores["DEX"] = 13
	check.call(not ClassProgression.saved_choices_error(unmet_ability).is_empty() and ClassProgression.saved_choices_error(dex_only).is_empty(), "051 saves enforce the feat's permanent ability prerequisite and accept either qualifying ability")
	var malformed_refused := true
	for invalid in [null, "18", [], {}, 13.5]:
		var malformed := dto.duplicate(true)
		malformed.ability_scores["STR"] = invalid
		malformed_refused = malformed_refused and not ClassProgression.saved_choices_error(malformed).is_empty()
	check.call(malformed_refused, "051 malformed saved feat ability score types refuse without conversion errors")
	var wrong_origin := dto.duplicate(true)
	wrong_origin.origin_feat = GRIT
	var dup := dto.duplicate(true)
	dup.feature_choices[asi] = ["feat:" + VIGIL]
	var unknown := dto.duplicate(true)
	unknown.feature_choices[asi] = ["feat:fixture:b051_nope"]
	var unearned := dto.duplicate(true)
	unearned.feature_choices["fixture:not_an_asi"] = ["feat:" + BRAINY]
	var modes_without := dto.duplicate(true)
	modes_without.feature_choices.erase(asi)
	check.call([epic, wrong_origin, dup, unknown, unearned].all(func(d): return not ClassProgression.saved_choices_error(d).is_empty()) and not FeatureModeRules.saved_error(modes_without).is_empty(), "051 saves with an under-level, non-origin, duplicate, unknown or unearned feat are refused, and a feat mode without its feat is unowned")
