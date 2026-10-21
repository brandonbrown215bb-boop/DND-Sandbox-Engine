class_name Review051Checks
extends RefCounted
## Runtime Reviewer stress cases for Batch 051 (feat acquisition).



static func run(check: Callable) -> void:
	Batch051Checks.load_fixtures()
	var GRIT := Batch051Checks.GRIT
	var VIGIL := Batch051Checks.VIGIL
	# T1 a "feat:" value on any non-ASI choice must not grant a feat through a save.
	var c := Batch051Checks.fresh("r051_t1")
	FeatRules.choose_origin(c, VIGIL)
	while c.level < 4: c.level_up()
	FeatRules.choose_level_feat(c, GRIT)
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var leaked: Array = []
	for id in dto.feature_choices:
		if dto.feature_choices[id] == ["feat:" + GRIT]: continue
		var forged: Dictionary = dto.duplicate(true)
		forged.feature_choices[id] = ["feat:" + Batch051Checks.BRAINY]
		if ClassProgression.saved_choices_error(forged).is_empty(): leaked.append(id)
	check.call(leaked.is_empty(), "R051 T1 a forged feat on a non-improvement choice is refused (leaked through: %s)" % str(leaked))
	# T2 repeatable feats may repeat; non-repeatable never.
	var rep := {"id": "fixture:r051_rep", "name": "R051 Repeatable", "category": "origin", "repeatable": true, "features": []}
	check.call(Batch051Checks._feat_loads(rep), "R051 T2 a repeatable feat without features loads")
	DataLoader.feats[rep.id] = rep
	var r := Batch051Checks.fresh("r051_t2")
	var o := FeatRules.choose_origin(r, rep.id)
	while r.level < 8: r.level_up()
	var first := FeatRules.choose_level_feat(r, rep.id)
	var second := FeatRules.choose_level_feat(r, rep.id)
	var rdto: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	check.call(o.success and first.success and second.success and ClassProgression.saved_choices_error(rdto).is_empty(), "R051 T2 a repeatable feat is taken at creation and at two improvements, and the save validates (%s/%s/%s, %s)" % [o.message, first.message, second.message, ClassProgression.saved_choices_error(rdto)])
	# T3 a Fighter mixes an ability improvement and a feat; the spent count stays consistent through a save.
	var f := Batch051Checks.fresh("r051_t3")
	while f.level < 6: f.level_up()
	var scores_ok := ClassProgression.improve_scores(f, "CON", "CON")
	var feat_ok := FeatRules.choose_level_feat(f, GRIT)
	var fdto: Dictionary = JSON.parse_string(JSON.stringify(f.to_dict()))
	var back := Character.new()
	back.from_dict(fdto)
	check.call(f.class_id == "fighter" and scores_ok and feat_ok.success and int(f.fighter_training.asi_spent) == 2 and ClassProgression.saved_choices_error(fdto).is_empty() and back.has_feature(Batch051Checks.STANCE) and back.ability_scores.get_permanent_score("CON") == f.ability_scores.get_permanent_score("CON"), "R051 T3 a level-6 Fighter takes +2 CON then a feat; asi_spent 2 and the save round-trips (%s)" % ClassProgression.saved_choices_error(fdto))
	# T4 the ability cap of 20 still binds improvements, and a feat is still available instead.
	var capped := Batch051Checks.fresh("r051_t4")
	while capped.level < 4: capped.level_up()
	capped.ability_scores.set_score("STR", 20)
	var before := capped.feature_choices.duplicate(true)
	var over := ClassProgression.improve_scores(capped, "STR", "DEX")
	check.call(not over and capped.feature_choices == before and capped.ability_scores.get_permanent_score("STR") == 20 and FeatRules.choose_level_feat(capped, GRIT).success, "R051 T4 STR 20 refuses +1 STR without spending the improvement; a feat can still be taken")
	# T5 049 integration: feat pools recover on their declared rest, owned max includes the feat's own upgrade.
	var g := Batch051Checks.fresh("r051_t5")
	while g.level < 4: g.level_up()
	FeatRules.choose_level_feat(g, GRIT)
	g.feature_uses[Batch051Checks.STANCE] = 0
	g.short_rest()
	check.call(int(g.feature_uses[Batch051Checks.STANCE]) == 3, "R051 T5 a short rest refills the feat's mode pool to its upgraded 3 (got %d)" % int(g.feature_uses[Batch051Checks.STANCE]))
	# T6 the origin picker only offers Origin feats; the level picker may offer an Origin feat (SRD p.87: no category named = any).
	var h := Batch051Checks.fresh("r051_t6")
	check.call(FeatRules.options(h, "origin").all(func(id): return str(DataLoader.get_feat(id).category) == "origin"), "R051 T6 the creation picker lists only Origin feats")
	DataLoader.feats.erase(rep.id)
