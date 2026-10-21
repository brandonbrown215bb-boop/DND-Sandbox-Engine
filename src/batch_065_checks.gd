class_name Batch065Checks
extends RefCounted
## Batch 065 (queue item 6): data-declared reaction triggers. Brandon: "If
## something costs a reaction like 'Hellish Rebuke', then it should be able to
## happen on a defined trigger from the data." No engine default trigger.

const FEAT := "fixture:b065_riposte"
const MODE := "fixture:b065_riposte_stance"
const REBUKE := "fixture:b065_rebuke"

static func load_fixtures() -> void:
	if not DataLoader.get_feat(FEAT).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_065/feats/riposte.json", "feat")
	DataLoader._load_json_file("res://data/fixtures/batch_065/spells/rebuke.json", "spell")

static func kit(c: Character) -> Character:
	while c.level < 4: c.level_up()
	FeatRules.choose_level_feat(c, FEAT)
	return c

static func warlock(id: String) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 10, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 16})
	var c := Character.new()
	c.initialize(id, "human", "warlock", scores)
	c.character_id = id
	c.max_hp = 40
	c.current_hp = 40
	var fid := c.get_spellcasting_feature_id()
	var chosen: Array = c.feature_choices.get(fid, []).duplicate()
	if REBUKE not in chosen: chosen.append(REBUKE)
	c.feature_choices[fid] = chosen
	c.refresh_spell_selection_from_choices()
	return c

static func goblin() -> Dictionary:
	var m := DataLoader.get_monster("goblin").duplicate(true)
	m.merge({"id": "b065_goblin", "current_hp": 500, "max_hp": 500, "is_alive": true, "conditions": {}}, true)
	return m

static func slots(c: Character) -> String:
	return JSON.stringify([SpellSlotRules.pool_rows(c), c.reaction_available])

static func mode_state(c: Character) -> String:
	return JSON.stringify([c.feature_uses.get(MODE, -1), c.feature_modes.get(MODE, {}).get("mode", ""), c.reaction_available])

static func open_window(c: Character) -> void:
	if not bool(c.feature_modes.get(MODE, {}).get("active", false)): FeatureModeRules.activate(c, MODE, "guard")
	FeatureModeRules.on_event(c, "hit")

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_feat(FEAT).is_empty(), "065 Riposte fixture and Hellish Rebuke trigger load: %s" % str(DataLoader.get_load_errors()))
	# Vocabulary and loader.
	var bad: Array = []
	for t in [null, [], {}, {"event": "on_sneeze"}, {"event": "on_attacked", "range": 60}, {"event": "on_attacked", "range_feet": 0}, {"event": "on_attacked", "range_feet": 62}, {"event": "on_attacked", "range_feet": 1005}, {"event": "on_attacked", "range_feet": "60"}, {"event": "on_attacked", "requires_sight": 1}]:
		if ReactionTriggers.trigger_error(t).is_empty(): bad.append(t)
	var good: Array = []
	for e in ReactionTriggers.EVENTS:
		good.append(ReactionTriggers.trigger_error({"event": e, "range_feet": 60, "requires_sight": true}))
	check.call(bad.is_empty() and good.all(func(g): return g.is_empty()), "065 trigger vocabulary accepts the four events with range/sight filters and refuses bad shapes (%s)" % str(bad))
	var rebuke := DataLoader.get_spell("hellish_rebuke")
	var action_spell := rebuke.duplicate(true)
	action_spell.casting_time = "action"
	var rt: Dictionary = rebuke.get("reaction_trigger", {})
	check.call(rt.size() == 3 and rt.get("event") == "on_damaged_by_creature" and int(rt.get("range_feet", 0)) == 60 and rt.get("requires_sight") == true and not ReactionTriggers.spell_trigger_error(action_spell).is_empty() and ReactionTriggers.spell_trigger_error(DataLoader.get_spell("shield")).is_empty() and not DataLoader.get_spell("shield").has("reaction_trigger"), "065 real Hellish Rebuke data declares SRD 5.2.1's trigger (damage from a creature you can see within 60 ft); only reaction spells may declare one; Shield declares none")
	var base: Dictionary = DataLoader.get_feat(FEAT).features[0]
	var no_trigger := base.duplicate(true)
	no_trigger.erase("reaction_trigger")
	var stray: Dictionary = DataLoader.get_feat("fixture:b057_rush").features[0].duplicate(true) if not DataLoader.get_feat("fixture:b057_rush").is_empty() else base.duplicate(true)
	stray["reaction_trigger"] = {"event": "on_hit_with_attack"}
	stray.erase("costs")
	var activate_reaction := base.duplicate(true)
	activate_reaction.costs = {"activate": "reaction", "switch": "reaction"}
	var wrong_event := base.duplicate(true)
	wrong_event.reaction_trigger = {"event": "on_attacked"}
	var no_hit := base.duplicate(true)
	no_hit.switch_events = ["turn_start"]
	var refused := [no_trigger, stray, activate_reaction, wrong_event, no_hit].map(func(f): return FeatureModeRules.validate_rule(f))
	check.call(FeatureModeRules.validate_rule(base).is_empty() and refused.all(func(r): return not r.is_empty()) and str(refused[0]).contains("no default"), "065 loader: a reaction switch cost needs a declared trigger (no default), a trigger needs a reaction cost, only switch may cost a reaction, and it fires through switch_events hit (%s)" % str(refused))
	Batch057Checks.load_fixtures()
	check.call(FeatureModeRules.validate_rule(DataLoader.get_feat("fixture:b057_rush").features[0]).is_empty() and CombatTurnBudget.cost_label("reaction") == "Reaction", "065 legacy: 057 Rush still validates; Reaction has a cost label")
	# Hellish Rebuke offers and filters.
	var w := warlock("b065_warlock")
	var g := goblin()
	var choices := SpellPermissionRules.payment_choices(w, REBUKE)
	check.call(not choices.is_empty(), "065 the warlock fixture can pay the Rebuke fixture (%d choices)" % choices.size())
	var ev := ReactionTriggers.make_event("on_damaged_by_creature", w, g, 30, true)
	var offers := ReactionTriggers.offers(w, ev)
	check.call(offers.size() == 1 and offers[0].id == REBUKE and offers[0].cost == "reaction", "065 taking damage from a seen creature within 60 ft offers the Rebuke fixture at a Reaction cost (%s)" % str(offers))
	var none_offered := {
		"far": ReactionTriggers.offers(w, ReactionTriggers.make_event("on_damaged_by_creature", w, g, 65, true)),
		"unseen": ReactionTriggers.offers(w, ReactionTriggers.make_event("on_damaged_by_creature", w, g, 30, false)),
		"other_event": ReactionTriggers.offers(w, ReactionTriggers.make_event("on_hit_by_attack", w, g, 30, true)),
		"other_reactor": ReactionTriggers.offers(w, ReactionTriggers.make_event("on_damaged_by_creature", warlock("b065_other"), g, 30, true)),
	}
	w.reaction_available = false
	none_offered["reaction_used"] = ReactionTriggers.offers(w, ReactionTriggers.make_event("on_damaged_by_creature", w, g, 30, true))
	w.reaction_available = true
	w.add_condition("stunned", 2)
	none_offered["incapacitated"] = ReactionTriggers.offers(w, ReactionTriggers.make_event("on_damaged_by_creature", w, g, 30, true))
	w.remove_condition("stunned")
	check.call(none_offered.values().all(func(v): return v.is_empty()), "065 out of range, unseen, another event, another reactor, Reaction used and Incapacitated offer nothing (%s)" % str(none_offered.keys().filter(func(k): return not none_offered[k].is_empty())))
	# No default trigger: the same spell with its trigger removed is never offered.
	var original: Dictionary = DataLoader.spells[REBUKE]
	var stripped := original.duplicate(true)
	stripped.erase("reaction_trigger")
	DataLoader.spells[REBUKE] = stripped
	var undeclared := ReactionTriggers.offers(w, ReactionTriggers.make_event("on_damaged_by_creature", w, g, 30, true))
	DataLoader.spells[REBUKE] = original
	check.call(undeclared.is_empty(), "065 a reaction spell with no declared trigger is never offered (no engine default)")
	# Refuse before paying.
	var before := slots(w)
	ev = ReactionTriggers.make_event("on_damaged_by_creature", w, g, 30, true)
	var offer: Dictionary = ReactionTriggers.offers(w, ev)[0]
	var r := {}
	r["canceled"] = ReactionTriggers.confirm(w, offer, ev, false, choices[0])
	r["payment_canceled"] = ReactionTriggers.confirm(w, offer, ev, true, {})
	w.reaction_available = false
	r["reaction_used"] = ReactionTriggers.confirm(w, offer, ev, true, choices[0])
	w.reaction_available = true
	w.add_condition("stunned", 2)
	r["incapacitated"] = ReactionTriggers.confirm(w, offer, ev, true, choices[0])
	w.remove_condition("stunned")
	var other := ReactionTriggers.make_event("on_damaged_by_creature", w, g, 30, true)
	r["other_event"] = ReactionTriggers.confirm(w, offer, other, true, choices[0])
	var far := ReactionTriggers.make_event("on_damaged_by_creature", w, g, 30, true)
	var far_offer: Dictionary = ReactionTriggers.offers(w, far)[0]
	far.distance_feet = 65
	r["out_of_range"] = ReactionTriggers.confirm(w, far_offer, far, true, choices[0])
	var closed := ReactionTriggers.make_event("on_damaged_by_creature", w, g, 30, true)
	var closed_offer: Dictionary = ReactionTriggers.offers(w, closed)[0]
	ReactionTriggers.close(closed)
	r["stale_closed"] = ReactionTriggers.confirm(w, closed_offer, closed, true, choices[0])
	var reasons := {}
	for k in r: reasons[k] = r[k].reason
	check.call(r.values().all(func(x): return not x.success and not x.reaction_spent) and slots(w) == before and reasons.canceled == "canceled" and reasons.reaction_used == "reaction_used" and reasons.incapacitated == "incapacitated" and reasons.out_of_range == "out_of_range" and reasons.other_event == "stale" and reasons.stale_closed == "stale", "065 checklist: cancelled prompt/payment, Reaction used, Incapacitated, out of range and stale triggers spend no slot and no Reaction (%s)" % str(reasons))
	var paid := ReactionTriggers.confirm(w, offer, ev, true, choices[0])
	var after := slots(w)
	var again := ReactionTriggers.confirm(w, offer, ev, true, choices[0])
	check.call(paid.success and paid.reaction_spent and not w.reaction_available and after != before and slots(w) == after and not again.success and not bool(ev.open), "065 a confirmed Rebuke pays its slot and the Reaction once, only on confirmation; the closed trigger refuses a second answer")
	var cast := CombatAction.resolve_spell(w, g, paid.spell, false, {}, [], int(paid.get("slot_level", 0)), 30)
	check.call(cast.get("success", false) and slots(w) == after and int(g.get("current_hp", 500)) < 500, "065 the paid Rebuke resolves against the creature without paying again (%s)" % str(cast.get("message", "")))
	# The costed on-hit mode switch.
	var f := kit(Batch050Checks.actor("b065_fighter"))
	open_window(f)
	var mev := ReactionTriggers.make_event("on_hit_with_attack", f, g, 5, true)
	var mode_offers := ReactionTriggers.offers(f, mev)
	check.call(mode_offers.size() == 1 and mode_offers[0].kind == "mode" and mode_offers[0].id == MODE and FeatureModeRules.activation_seconds(f, MODE, "switch") == 0, "065 an own hit within the declared 30 ft offers the Reaction-cost stance switch (%s)" % str(mode_offers))
	var direct := ModeControls.apply(f, MODE, "switch", "lunge", ModeControls.row(f, MODE).token, ModeControls.outside_combat())
	var direct_null := ModeControls.apply(f, MODE, "switch", "lunge", ModeControls.row(f, MODE).token, null)
	var mb := mode_state(f)
	var mr := {}
	mr["canceled"] = ReactionTriggers.confirm(f, mode_offers[0], mev, false, "lunge")
	mr["no_choice"] = ReactionTriggers.confirm(f, mode_offers[0], mev, true, "")
	f.reaction_available = false
	mr["reaction_used"] = ReactionTriggers.confirm(f, mode_offers[0], mev, true, "lunge")
	f.reaction_available = true
	f.add_condition("stunned", 2)
	mr["incapacitated"] = ReactionTriggers.confirm(f, mode_offers[0], mev, true, "lunge")
	f.remove_condition("stunned")
	open_window(f) # A newer hit re-opens the window: the old offer is stale.
	mr["stale"] = ReactionTriggers.confirm(f, mode_offers[0], mev, true, "lunge")
	var mreasons := {}
	for k in mr: mreasons[k] = mr[k].reason
	check.call(direct.reason == "reaction_trigger_only" and direct_null.reason == "reaction_trigger_only" and mr.values().all(func(x): return not x.success) and mode_state(f) == mb and mreasons.stale == "stale" and mreasons.reaction_used == "reaction_used", "065 a direct HUD/room switch is refused (trigger only); cancelled, no choice, Reaction used, Incapacitated and stale answers spend nothing (%s)" % str(mreasons))
	var fresh := ReactionTriggers.make_event("on_hit_with_attack", f, g, 5, true)
	var far_mode := ReactionTriggers.offers(f, ReactionTriggers.make_event("on_hit_with_attack", f, g, 35, true))
	var fo: Dictionary = ReactionTriggers.offers(f, fresh)[0]
	var switched := ReactionTriggers.confirm(f, fo, fresh, true, "lunge")
	check.call(far_mode.is_empty() and switched.success and switched.cost == "reaction" and not f.reaction_available and str(f.feature_modes[MODE].mode) == "lunge" and int(f.feature_uses.get(MODE, -1)) == 1, "065 a confirmed switch spends the Reaction (not a use) and switches; beyond 30 ft nothing is offered")
	# Legacy save shape: no new saved field.
	var saved := f.to_dict()
	check.call(not JSON.stringify(saved).contains("reaction_trigger") and FeatureModeRules.saved_error(saved).is_empty(), "065 saves gain no field; the saved feature modes stay valid")
