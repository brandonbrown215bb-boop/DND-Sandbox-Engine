## G3 proof of the existing S-234 multiclass entry gate through loaded neutral
## class definitions, the production offer list and actual confirmation.
class_name CrownMulticlassEntryChecks
extends RefCounted

const IDS := ["base", "str", "any", "all"]

static func load_fixtures() -> void:
	for suffix in IDS:
		DataLoader._load_json_file("res://data/fixtures/crown_g3/" + suffix + ".json", "class")

static func actor(scores: Dictionary, pending: int = 1) -> Character:
	var c := Character.new()
	c.character_id = "g3:" + JSON.stringify(scores).md5_text().left(8)
	c.initialize("G3 entrant", "human", "fixture:g3_base", AbilityScores.new())
	var all := {"STR":10,"DEX":10,"CON":10,"INT":13,"WIS":10,"CHA":10}
	all.merge(scores, true)
	c.ability_scores.from_dict(all)
	for _i in pending: c.level_up()
	return c

static func confirm(c: Character, class_id: String) -> bool:
	return PermanentProgressionRules.advance(c, class_id, c.permanent_progression.duplicate(true))

static func run(check: Callable) -> void:
	load_fixtures()
	var previous_state: int = GameManager.current_state
	GameManager.current_state = GameManager.GameState.OVERWORLD
	for suffix in IDS:
		var record := DataLoader.get_character_class("fixture:g3_" + suffix)
		check.call(not record.is_empty() and PermanentProgressionRules.definition_error(record).is_empty(), "G3 loaded neutral entry class " + suffix)
	_malformed(check)
	_scores(check)
	_permanent_versus_projected(check)
	_stale_and_costs(check)
	_score_drop_and_history(check)
	_panel(check)
	GameManager.current_state = previous_state

static func _malformed(check: Callable) -> void:
	var record := DataLoader.get_character_class("fixture:g3_any").duplicate(true)
	var validator: Node = DataLoader.get_script().new()
	check.call(validator._validate_content(record.duplicate(true), "class", "g3-valid"), "G3 valid any/all declaration loads")
	var cases := {"not_object": ["STR"], "empty": {}, "unknown_key": {"all": ["STR"], "one_of": ["DEX"]}, "bad_ability": {"all": ["NOPE"]}, "not_list": {"any": "STR"}, "number": {"all": [13]}, "empty_lists": {"all": [], "any": []}}
	for name in cases:
		var bad := record.duplicate(true)
		bad.multiclass_prerequisite = cases[name]
		check.call(not validator._validate_content(bad, "class", "g3-invalid"), "G3 malformed multiclass_prerequisite refuses at load: " + name)
	validator.free()

static func _scores(check: Callable) -> void:
	# Primary-ability default: proposed class STR plus current class INT.
	var c := actor({"STR":12})
	check.call("fixture:g3_str" not in PermanentProgressionRules.available_classes(c) and "fixture:g3_base" in PermanentProgressionRules.available_classes(c), "G3 STR 12 hides default-primary class while current class stays offered")
	check.call(PermanentProgressionRules.multiclass_prerequisite_error(c, "fixture:g3_str") == "G3 str requires STR 13 (current score 12).", "G3 refusal names failing class, ability and score")
	c = actor({"STR":13})
	check.call("fixture:g3_str" in PermanentProgressionRules.available_classes(c), "G3 STR 13 offers default-primary class")
	# Every current class is checked, not only the proposed one.
	c = actor({"STR":13, "INT":12})
	check.call("fixture:g3_str" not in PermanentProgressionRules.available_classes(c) and PermanentProgressionRules.multiclass_prerequisite_error(c, "fixture:g3_str") == "G3 base requires INT 13 (current score 12).", "G3 current class primary at 12 blocks new entry")
	# any-of
	c = actor({"STR":12, "DEX":12})
	check.call("fixture:g3_any" not in PermanentProgressionRules.available_classes(c) and PermanentProgressionRules.multiclass_prerequisite_error(c, "fixture:g3_any") == "G3 any requires one of these scores to be 13: STR 12, DEX 12.", "G3 any-of refuses when every listed score is 12")
	for ability in ["STR", "DEX"]:
		c = actor({ability:13})
		check.call("fixture:g3_any" in PermanentProgressionRules.available_classes(c), "G3 any-of accepts " + ability + " 13 alone")
	# all-of overrides primary_ability (DEX) and needs WIS too.
	c = actor({"DEX":13, "WIS":12})
	check.call("fixture:g3_all" not in PermanentProgressionRules.available_classes(c) and PermanentProgressionRules.multiclass_prerequisite_error(c, "fixture:g3_all") == "G3 all requires WIS 13 (current score 12).", "G3 all-of refuses when one listed score is 12")
	c = actor({"DEX":13, "WIS":13})
	check.call("fixture:g3_all" in PermanentProgressionRules.available_classes(c) and confirm(c, "fixture:g3_all") and c.class_levels == {"fixture:g3_base":1, "fixture:g3_all":1}, "G3 all-of at 13 confirms through actual advance")
	# A third class checks the proposed class and both acquired classes.
	c.level_up()
	c.ability_scores.set_score("STR", 13)
	c.ability_scores.set_score("WIS", 12)
	var before := c.to_dict().duplicate(true)
	check.call("fixture:g3_str" not in PermanentProgressionRules.available_classes(c) and not confirm(c, "fixture:g3_str") and c.to_dict() == before, "G3 third class refuses on an acquired class's all-of score without cost")
	check.call(PermanentProgressionRules.multiclass_prerequisite_error(c, "fixture:g3_str") == "G3 all requires WIS 13 (current score 12).", "G3 third-class refusal names the acquired class")

static func _permanent_versus_projected(check: Callable) -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_g_protections.json", "class")
	var c := actor({"STR":12})
	var feature: Dictionary = DataLoader.classes["fixture:batch_g_protections"].features_by_level["1"][0].duplicate(true)
	feature.source_instance_id = "g3:projected"
	c.features.append(feature)
	var projected: bool = ResourcePoolRules.acquire(c, feature, "g3:projected").get("success", false) and ClassFeature.execute(c, feature, null, null, "g3:projected").get("success", false)
	check.call(projected and c.ability_scores.get_score("STR") == 18 and c.ability_scores.get_permanent_score("STR") == 12, "G3 projection raises current STR while permanent STR stays 12")
	var before := c.to_dict().duplicate(true)
	check.call("fixture:g3_str" not in PermanentProgressionRules.available_classes(c) and not confirm(c, "fixture:g3_str") and c.to_dict() == before, "G3 projected score does not satisfy the entry gate")

static func _stale_and_costs(check: Callable) -> void:
	# Offered, then the score drops before confirmation: re-checked on confirm.
	var c := actor({"STR":13})
	var captured := c.permanent_progression.duplicate(true)
	check.call("fixture:g3_str" in PermanentProgressionRules.available_classes(c), "G3 class offered before stale confirmation")
	c.ability_scores.set_score("STR", 12)
	var before := c.to_dict().duplicate(true)
	check.call(not PermanentProgressionRules.advance(c, "fixture:g3_str", captured) and c.to_dict() == before and int(c.permanent_progression.pending_levels) == 1 and c.max_hp == int(before.max_hp), "G3 stale offered class refuses on confirmation without spending level, HP or receipts")
	# Unknown or unenabled IDs and an ineligible direct confirm also cost nothing.
	for id in ["fixture:g3_missing", "wizard", "fixture:g3_any"]:
		before = c.to_dict().duplicate(true)
		check.call(not confirm(c, id) and c.to_dict() == before, "G3 unoffered confirmation refuses without cost: " + id)
	# Successful entry consumes exactly one entitlement and a replay cannot spend again.
	c.ability_scores.set_score("STR", 13)
	captured = c.permanent_progression.duplicate(true)
	check.call(PermanentProgressionRules.advance(c, "fixture:g3_str", captured) and c.level == 2 and int(c.permanent_progression.pending_levels) == 0, "G3 eligible confirmation spends one level")
	before = c.to_dict().duplicate(true)
	check.call(not PermanentProgressionRules.advance(c, "fixture:g3_str", captured) and c.to_dict() == before, "G3 stale replay of a confirmed entry is refused")

static func _score_drop_and_history(check: Callable) -> void:
	var c := actor({"STR":13}, 3)
	check.call(confirm(c, "fixture:g3_str") and confirm(c, "fixture:g3_str"), "G3 multiclass entry then a second level")
	c.ability_scores.set_score("STR", 8)
	c.ability_scores.set_score("INT", 8)
	var offered := PermanentProgressionRules.available_classes(c)
	check.call("fixture:g3_str" in offered and "fixture:g3_base" in offered and "fixture:g3_any" not in offered, "G3 acquired classes stay offered after scores drop; new entry is refused")
	check.call(PermanentProgressionRules.multiclass_prerequisite_error(c, "fixture:g3_str") == "" and PermanentProgressionRules.multiclass_prerequisite_error(c, "fixture:g3_base") == "", "G3 acquired classes report no entry refusal")
	var dto := c.to_dict().duplicate(true)
	check.call(PermanentProgressionRules.saved_error(dto).is_empty(), "G3 multiclass history with dropped scores passes checkpoint validation")
	var restored := Character.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(dto)))
	check.call(restored.permanent_progression.history == ["fixture:g3_base", "fixture:g3_str", "fixture:g3_str"] and PermanentProgressionRules.same_json(restored.class_levels, {"fixture:g3_base":1, "fixture:g3_str":2}) and PermanentProgressionRules.same_json(restored.permanent_progression, c.permanent_progression) and restored.max_hp == c.max_hp, "G3 restore keeps ordered class history without replaying grants (history=%s levels=%s hp=%d/%d)" % [str(restored.permanent_progression.get("history")), str(restored.class_levels), restored.max_hp, c.max_hp])
	check.call(confirm(restored, "fixture:g3_str") and restored.get_class_level("fixture:g3_str") == 3, "G3 restored character continues an acquired class after scores dropped")
	var forged := dto.duplicate(true)
	forged.permanent_progression.history[1] = "fixture:g3_any"
	check.call(not PermanentProgressionRules.saved_error(forged).is_empty(), "G3 forged class history refuses at checkpoint")

## The real Class Progression controls offer only eligible classes and show the
## gate's refusal when an offered choice went stale before Confirm.
static func _panel(check: Callable) -> void:
	var c := actor({"STR":13})
	var panel := ClassTraining.new()
	var refreshes: Array = []
	panel.configure(c, func(): refreshes.append(true))
	var options: OptionButton = panel.find_child("ProgressionClass", true, false)
	var button: Button = panel.find_child("AcquireClassLevel", true, false)
	var refusal: Label = panel.find_child("ProgressionRefusal", true, false)
	var labels: Array = []
	for i in options.item_count: labels.append(options.get_item_text(i))
	check.call(options != null and button != null and "G3 str" in labels and "G3 any" in labels and "G3 all" not in labels, "G3 panel offers only eligible loaded classes (%s)" % str(labels))
	options.select(labels.find("G3 str"))
	c.ability_scores.set_score("STR", 12)
	var before := c.to_dict().duplicate(true)
	button.pressed.emit()
	check.call(refreshes.is_empty() and c.to_dict() == before and refusal.text == "G3 str requires STR 13 (current score 12).", "G3 panel Confirm on a stale offer shows the exact refusal and spends nothing (%s)" % refusal.text)
	panel.free()
	var empty := actor({"INT":12})
	panel = ClassTraining.new()
	panel.configure(empty, func(): pass)
	options = panel.find_child("ProgressionClass", true, false)
	labels = []
	for i in options.item_count: labels.append(options.get_item_text(i))
	check.call("G3 base" in labels and "G3 str" not in labels and "G3 any" not in labels, "G3 panel still offers the current class when its own primary is 12 (%s)" % str(labels))
	panel.free()
