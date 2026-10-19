## Bounded production checks for Batch 029:
## S-142 (Interruption/failure reserve and refund)
## S-115 (Whole pending cast cancellation)
## S-143 (Stopping-spell success/failure cost policy)
## S-116 (One recipient's incoming effect negation)
class_name Batch029Checks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_029/spells/target_refund.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_029/spells/target_commit.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_029/spells/stopping_spell.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_029/spells/spell_breaker.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_029/spells/multi_target_stepped.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_029/spells/review_settlement.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_029/items/items.json", "item")
	DataLoader._load_json_file("res://data/fixtures/batch_029/classes/negator.json", "class")


static func _make_caster(name: String, class_id: String = "wizard") -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 10, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	var caster := Character.new()
	caster.initialize(name, "human", class_id, scores)
	caster.character_id = name.to_lower().replace(" ", "_")
	caster.max_hp = 30
	caster.current_hp = 30
	caster.spell_slots = {"1": 4, "2": 3, "3": 2}
	return caster


static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "029 fixtures load through ordinary spell/item/class validation")

	# =========================================================================
	# Schema & contract checks
	# =========================================================================
	check.call(CastInterruptionRules.settlement_policy_error("commit").is_empty(), "029 accepts 'commit' settlement policy")
	check.call(CastInterruptionRules.settlement_policy_error("refund").is_empty(), "029 accepts 'refund' settlement policy")
	check.call(not CastInterruptionRules.settlement_policy_error("invalid").is_empty(), "029 rejects invalid settlement policy string")
	check.call(not CastInterruptionRules.settlement_policy_error({}).is_empty(), "029 rejects empty settlement policy object")

	var valid_cancel_rule := {
		"target_scope": "whole_cast",
		"min_spell_level": 1,
		"max_spell_level": 3,
		"schools": ["evocation", "abjuration"],
		"contest": {"type": "save", "ability": "CON", "dc_from": "stopping_caster"}
	}
	check.call(CastInterruptionRules.cancellation_rule_error(valid_cancel_rule).is_empty(), "029 accepts valid cancellation rule")
	var invalid_cancel_scope := valid_cancel_rule.duplicate()
	invalid_cancel_scope["target_scope"] = "invalid_scope"
	check.call(not CastInterruptionRules.cancellation_rule_error(invalid_cancel_scope).is_empty(), "029 rejects invalid cancellation target_scope")
	var recipient_cancel := valid_cancel_rule.duplicate()
	recipient_cancel["target_scope"] = "recipient_effect"
	check.call(not CastInterruptionRules.cancellation_rule_error(recipient_cancel).is_empty(), "029 rejects recipient-scoped stopping rule; negation owns recipient scope")
	var invalid_cancel_level := valid_cancel_rule.duplicate()
	invalid_cancel_level["min_spell_level"] = 5
	invalid_cancel_level["max_spell_level"] = 2
	check.call(not CastInterruptionRules.cancellation_rule_error(invalid_cancel_level).is_empty(), "029 rejects min_spell_level greater than max_spell_level")
	var invalid_cancel_school := valid_cancel_rule.duplicate()
	invalid_cancel_school["schools"] = ["not_a_school"]
	check.call(not CastInterruptionRules.cancellation_rule_error(invalid_cancel_school).is_empty(), "029 rejects invalid cancellation school")

	var valid_cost_policy := {
		"on_success": {"slot": "commit", "reaction": "commit"},
		"on_failure": {"slot": "refund", "reaction": "commit"}
	}
	check.call(CastInterruptionRules.stopping_cost_policy_error(valid_cost_policy).is_empty(), "029 accepts valid stopping cost policy")
	var invalid_cost_item := {
		"on_failure": {"item": "invalid_item_action"}
	}
	check.call(not CastInterruptionRules.stopping_cost_policy_error(invalid_cost_item).is_empty(), "029 rejects invalid stopping cost item action")

	var valid_negation_rule := {
		"target_scope": "recipient_effect",
		"max_spell_level": 3,
		"schools": ["evocation"]
	}
	check.call(CastInterruptionRules.incoming_negation_rule_error(valid_negation_rule).is_empty(), "029 accepts valid incoming negation rule")

	# =========================================================================
	# S-142: Interruption/failure reserve and refund
	# =========================================================================
	var caster_s142 := _make_caster("S142 Caster")
	var target_s142 := _make_caster("S142 Target")
	var refund_spell: Dictionary = DataLoader.get_spell("fixture:029_target_refund")
	var commit_spell: Dictionary = DataLoader.get_spell("fixture:029_target_commit")

	# Test reserve and commit on normal empty effect
	var empty_cast := SpellResolutionContext.new()
	empty_cast.caster = caster_s142
	empty_cast.target = target_s142
	empty_cast.spell = commit_spell
	empty_cast.spell_definition_id = str(commit_spell["id"])
	empty_cast.slot_level = 1
	empty_cast.incoming_slot_spent = true
	empty_cast.incoming_slot_key = "1"
	empty_cast.incoming_slot_pool_id = "ordinary"
	caster_s142.spell_slots["1"] = 3
	CastInterruptionRules.reserve_cast_payment(empty_cast, commit_spell)
	check.call(empty_cast.decisions.get("incoming_payment_kind") == "slot", "029 reserves slot payment kind")
	var empty_settle := CastInterruptionRules.settle_cast_outcome(empty_cast, "empty_effect")
	check.call(empty_settle.get("committed", false) and int(caster_s142.spell_slots["1"]) == 3, "029 empty effect commits payment by default without automatic refund")

	# Test refund on interruption when declared interruption_policy: "refund"
	var refund_cast := SpellResolutionContext.new()
	refund_cast.caster = caster_s142
	refund_cast.target = target_s142
	refund_cast.spell = refund_spell
	refund_cast.spell_definition_id = str(refund_spell["id"])
	refund_cast.slot_level = 1
	refund_cast.incoming_slot_spent = true
	refund_cast.incoming_slot_key = "1"
	refund_cast.incoming_slot_pool_id = "ordinary"
	CastInterruptionRules.reserve_cast_payment(refund_cast, refund_spell)
	var refund_settle := CastInterruptionRules.settle_cast_outcome(refund_cast, "interrupted")
	check.call(refund_settle.get("refunded", false) and int(caster_s142.spell_slots["1"]) == 4, "029 declared interruption_policy refund restores spent spell slot")

	# Test commit on interruption when declared interruption_policy: "commit"
	caster_s142.spell_slots["1"] = 3
	var commit_cast := SpellResolutionContext.new()
	commit_cast.caster = caster_s142
	commit_cast.target = target_s142
	commit_cast.spell = commit_spell
	commit_cast.spell_definition_id = str(commit_spell["id"])
	commit_cast.slot_level = 1
	commit_cast.incoming_slot_spent = true
	commit_cast.incoming_slot_key = "1"
	commit_cast.incoming_slot_pool_id = "ordinary"
	CastInterruptionRules.reserve_cast_payment(commit_cast, commit_spell)
	var commit_settle := CastInterruptionRules.settle_cast_outcome(commit_cast, "interrupted")
	check.call(commit_settle.get("committed", false) and int(caster_s142.spell_slots["1"]) == 3, "029 declared interruption_policy commit preserves spent slot on interruption")

	# Test free-cast refund
	var free_cast_char := _make_caster("Free Cast Char")
	free_cast_char.features.append({
		"id": "wizard_signature_spells",
		"name": "Signature Spells",
		"type": "passive"
	})
	free_cast_char.wizard_signature_spells.assign(["fixture:029_target_refund"])
	free_cast_char.feature_uses["wizard_signature_spell:fixture:029_target_refund"] = 0
	var free_ctx := SpellResolutionContext.new()
	free_ctx.caster = free_cast_char
	free_ctx.target = target_s142
	free_ctx.spell = refund_spell
	free_ctx.spell_definition_id = str(refund_spell["id"])
	free_ctx.decisions["cast_payment_receipt"] = {"kind":"free_cast","source_id":"wizard_signature_spells","amount":1,"spell_id":refund_spell.id}
	var free_refund := CastInterruptionRules.refund_cast_payment(free_ctx, "interrupted")
	check.call(free_refund.get("refunded", false) and free_cast_char.has_free_spell_cast("fixture:029_target_refund"), "029 free-cast payment refund restores free cast use")

	# Test item charge refund
	var item_char := _make_caster("Item Char")
	item_char.inventory.add_item("fixture:029_negation_talisman")
	var instance_id := str(item_char.inventory.copies.equipped.get("ring", item_char.inventory.backpack_instances()[0].instance_id))
	var copy: Dictionary = item_char.inventory.get_instance(instance_id)
	copy.state.charges = 2
	item_char.inventory.copies.records[instance_id] = copy
	var charge_ctx := SpellResolutionContext.new()
	charge_ctx.caster = item_char
	charge_ctx.target = target_s142
	charge_ctx.spell = refund_spell
	charge_ctx.spell_definition_id = str(refund_spell["id"])
	CastInterruptionRules.reserve_cast_payment(charge_ctx, {
		"_spell_payment_kind": "item_charges",
		"_spell_payment_source_id": instance_id,
		"_selected_spell_slot_level": 1
	})
	charge_ctx.decisions["cast_payment_receipt"] = {"kind":"item_charges","source_id":instance_id,"amount":1,"spell_id":refund_spell.id}
	var charge_refund := CastInterruptionRules.refund_cast_payment(charge_ctx, "interrupted")
	check.call(charge_refund.get("refunded", false) and int(item_char.inventory.get_instance(instance_id).state.charges) == 3, "029 item charge payment refund restores item copy charges")

	# =========================================================================
	# S-115: Whole pending cast cancellation
	# =========================================================================
	var stopping_spell: Dictionary = DataLoader.get_spell("fixture:029_stopping_spell")
	var stopping_rule: Dictionary = stopping_spell.get("cancellation_rule", {})

	# Test level predicate matching
	var lvl1_cast := SpellResolutionContext.new()
	lvl1_cast.spell = refund_spell
	lvl1_cast.spell_definition_id = str(refund_spell["id"])
	lvl1_cast.slot_level = 1
	check.call(bool(CastInterruptionRules.is_cast_matching_cancellation(lvl1_cast, stopping_rule).get("matches", false)), "029 cancellation rule matches qualifying spell level 1")

	var lvl5_spell := refund_spell.duplicate(true)
	lvl5_spell["level"] = 5
	var lvl5_cast := SpellResolutionContext.new()
	lvl5_cast.spell = lvl5_spell
	lvl5_cast.spell_definition_id = "fixture:029_high_level"
	lvl5_cast.slot_level = 5
	var lvl_mismatch := CastInterruptionRules.is_cast_matching_cancellation(lvl5_cast, stopping_rule)
	check.call(not bool(lvl_mismatch.get("matches", true)) and lvl_mismatch.get("reason") == "level_above_maximum", "029 cancellation rule rejects spell level above maximum (does not cancel unrelated casts)")

	# Test school predicate matching
	var necro_spell := refund_spell.duplicate(true)
	necro_spell["school"] = "necromancy"
	var necro_cast := SpellResolutionContext.new()
	necro_cast.spell = necro_spell
	necro_cast.spell_definition_id = "fixture:029_necro"
	necro_cast.slot_level = 1
	var school_mismatch := CastInterruptionRules.is_cast_matching_cancellation(necro_cast, stopping_rule)
	check.call(not bool(school_mismatch.get("matches", true)) and school_mismatch.get("reason") == "school_mismatch", "029 cancellation rule rejects non-matching school (preserves unrelated cast)")

	# Test whole cast cancellation through resolve_cancellation
	var stopper := _make_caster("Stopper Wizard")
	stopper.reaction_available = true
	SpellPermissionChecks.grant_slot_permission(stopper, [stopping_spell["id"]])
	var target_to_cancel := _make_caster("Casting Wizard")
	target_to_cancel.spell_slots["1"] = 0
	var test_cancellation_cast := SpellResolutionContext.new()
	test_cancellation_cast.caster = target_to_cancel
	test_cancellation_cast.target = stopper
	test_cancellation_cast.spell = refund_spell
	test_cancellation_cast.spell_definition_id = str(refund_spell["id"])
	test_cancellation_cast.slot_level = 1
	test_cancellation_cast.incoming_slot_spent = true
	test_cancellation_cast.incoming_slot_key = "1"
	test_cancellation_cast.incoming_slot_pool_id = "ordinary"
	test_cancellation_cast.observers = [stopper]
	var stopper_choices := SpellPermissionRules.payment_choices(stopper, stopping_spell["id"])
	var stopper_payment: Dictionary = stopper_choices[0] if not stopper_choices.is_empty() else {}
	test_cancellation_cast.decisions = {
		"stopping_spell:%s" % stopper.character_name: stopping_spell,
		SpellPermissionRules.reaction_key(stopper, stopping_spell["id"]): stopper_payment
	}
	CastInterruptionRules.reserve_cast_payment(test_cancellation_cast, refund_spell)
	var cancel_result := CastInterruptionRules.resolve_cancellation(test_cancellation_cast)
	check.call(cancel_result.get("canceled", false) and not cancel_result.get("success", true), "029 eligible pending cast is canceled by stopping reaction")
	check.call(test_cancellation_cast.interrupted and bool(cancel_result.get("incoming_spell_slot_refunded", false)) and int(target_to_cancel.spell_slots["1"]) == 1, "029 canceled cast terminates and refunds target slot per declared policy")
	check.call(not stopper.reaction_available and int(stopper.spell_slots["2"]) == 2, "029 stopping caster commits reaction and level-2 slot")

	# =========================================================================
	# S-143: Stopping-spell success/failure cost policy
	# =========================================================================
	var breaker_spell: Dictionary = DataLoader.get_spell("fixture:029_spell_breaker")
	var breaker_char := _make_caster("Breaker Wizard")
	breaker_char.reaction_available = true
	breaker_char.spell_slots["3"] = 2
	SpellPermissionChecks.grant_slot_permission(breaker_char, [breaker_spell["id"]])

	# Test stopping failure with on_failure: slot refund (Spell Breaker)
	var resilient_caster := _make_caster("Resilient Caster")
	resilient_caster.add_modifier("roll", "save:CON", 1000, 4)
	resilient_caster.spell_slots["1"] = 1

	var breaker_cast := SpellResolutionContext.new()
	breaker_cast.caster = resilient_caster
	breaker_cast.target = breaker_char
	breaker_cast.spell = commit_spell
	breaker_cast.spell_definition_id = str(commit_spell["id"])
	breaker_cast.slot_level = 1
	breaker_cast.incoming_slot_spent = true
	breaker_cast.incoming_slot_key = "1"
	breaker_cast.incoming_slot_pool_id = "ordinary"
	breaker_cast.observers = [breaker_char]
	var breaker_choices := SpellPermissionRules.payment_choices(breaker_char, breaker_spell["id"])
	var breaker_payment: Dictionary = breaker_choices[0] if not breaker_choices.is_empty() else {}
	breaker_cast.decisions = {
		"stopping_spell:%s" % breaker_char.character_name: breaker_spell,
		SpellPermissionRules.reaction_key(breaker_char, breaker_spell["id"]): breaker_payment
	}
	CastInterruptionRules.reserve_cast_payment(breaker_cast, commit_spell)
	var breaker_outcome := CastInterruptionRules.resolve_cancellation(breaker_cast)
	check.call(breaker_outcome.is_empty(), "029 failed stopping contest leaves target cast uncountered")
	check.call(not breaker_char.reaction_available and int(breaker_char.spell_slots["3"]) == 2, "029 Spell Breaker refunds stopping slot on failed stop while committing reaction")
	check.call(int(resilient_caster.spell_slots["1"]) == 1 and not breaker_cast.interrupted, "029 failed stop does not repay or alter original target spell")

	# Test item copy disposal on stopping scroll failure
	var scroll_char := _make_caster("Scroll Holder")
	scroll_char.inventory.add_item("fixture:029_stopping_scroll")
	var scroll_instance := str(scroll_char.inventory.backpack_instances()[0].instance_id)
	check.call(not scroll_char.inventory.get_instance(scroll_instance).is_empty(), "029 scroll instance present in inventory before attempt")
	var scroll_item := DataLoader.get_item("fixture:029_stopping_scroll")
	var scroll_settlement := CastInterruptionRules.settle_stopping_costs(scroll_char, scroll_item, false, {"payment":{"kind":"item_charges","source_id":scroll_instance,"amount":1,"spell_id":""}}, {})
	check.call(scroll_settlement.get("item_disposed", false) and scroll_char.inventory.get_instance(scroll_instance).is_empty(), "029 declared on_failure item disposal disposes scroll copy on failed check")

	# =========================================================================
	# S-116: One recipient's incoming effect negation
	# =========================================================================
	var negator_char := _make_caster("Negator Char", "fixture:029_class")
	var normal_char := _make_caster("Normal Char")
	var spell_caster := _make_caster("Offensive Caster")

	var stepped_multi: Dictionary = DataLoader.get_spell("fixture:029_multi_target_stepped")
	var multi_cast := SpellResolutionContext.new()
	multi_cast.caster = spell_caster
	multi_cast.target = normal_char
	multi_cast.spell = stepped_multi
	multi_cast.spell_definition_id = str(stepped_multi["id"])
	multi_cast.slot_level = 1

	# Test recipient negation detection on negator_char
	check.call(CastInterruptionRules.is_recipient_negated(multi_cast, negator_char), "029 negator character with passive ward negates matching incoming spell")
	check.call(not CastInterruptionRules.is_recipient_negated(multi_cast, normal_char), "029 normal character without ward is not negated")

	# Execute stepped spell across both targets and verify only negator is excluded
	var adapter = SharedStepExecutor.SpellAdapter.new(multi_cast)
	var step_save: Dictionary = stepped_multi["steps"][0]
	var step_damage: Dictionary = stepped_multi["steps"][1]

	var outcomes_save: Array = []
	for target in [negator_char, normal_char]:
		if adapter.is_recipient_negated(target, step_save):
			outcomes_save.append({
				"target": target,
				"target_name": adapter.get_target_name(target),
				"skipped": true,
				"negated": true,
				"reason": "recipient_effect_negated"
			})
		else:
			outcomes_save.append({
				"target": target,
				"target_name": adapter.get_target_name(target),
				"saved": false,
				"damage": 0
			})

	check.call(outcomes_save.size() == 2, "029 stepped save resolves two recipient records")
	check.call(bool(outcomes_save[0].get("negated", false)) and bool(outcomes_save[0].get("skipped", false)), "029 recipient A (negator) is excluded from incoming effect")
	check.call(not bool(outcomes_save[1].get("negated", false)) and not bool(outcomes_save[1].get("skipped", false)), "029 recipient B (normal) remains intact and takes incoming effect")

	# Single-target negation via SpellResolver
	var single_cast_negated := CombatAction.resolve_spell(spell_caster, negator_char, stepped_multi)
	check.call(single_cast_negated.get("success", false) and single_cast_negated.get("recipient_negated", false) and int(single_cast_negated.get("damage", 0)) == 0, "029 single-target negation returns 0 damage without reflection or retargeting")
	check.call(negator_char.current_hp == 30, "029 negated recipient suffers no HP loss")

	_review_regressions(check)
	_exact_item_regression(check)
	_default_policy_regression(check)
	_source_kind_regression(check)
	_contest_receipt_regression(check)
	print("BATCH_029_CHECKS_COMPLETE: ALL SLICES VERIFIED (S-142, S-115, S-143, S-116)")


static func _review_regressions(check: Callable) -> void:
	check.call(not CastInterruptionRules.settlement_policy_error({"on_failure":{"reaction":"refund"}}).is_empty(), "029 review: target settlement rejects unsupported Reaction refund")
	var malformed_ward := {"id":"fixture:malformed_ward","type":"passive","effects":[{"type":"incoming_spell_negation","step_types":"damage"}]}
	check.call(not DataLoader._feature_content_error(malformed_ward).is_empty(), "029 review: malformed class ward rejects before runtime")
	var malformed_item := {"id":"fixture:malformed_ward_item","name":"Bad ward","type":"ring","incoming_negation_rule":{"step_types":"damage"}}
	check.call(not DataLoader._validate_content(malformed_item, "item", "029 review malformed ward"), "029 review: malformed item ward rejects before runtime")
	DataLoader._load_errors.clear()
	var caster := _make_caster("029 review caster")
	var normal := _make_caster("029 review ordinary")
	var warded := _make_caster("029 review warded", "fixture:029_class")
	var empty := DataLoader.get_spell("fixture:029_target_commit").duplicate(true)
	empty.erase("damage")
	empty.erase("damage_type")
	empty.erase("attack_type")
	empty["effects"] = []
	empty["empty_effect_policy"] = "refund"
	var before := int(caster.spell_slots["1"])
	var resolved := CombatAction.resolve_spell(caster, normal, empty, true)
	check.call(resolved.get("success", false) and caster.spell_slots["1"] == before, "029 review: ordinary empty-effect refund reaches actual resolver")
	empty.erase("empty_effect_policy")
	empty["cast_settlement"] = {"on_success":{"slot":"refund"}}
	empty["effects"] = [{"type":"heal","value":1}]
	check.call(SharedSpell.content_error(empty).is_empty(), "029 review: documented cast_settlement branches validate")
	resolved = CombatAction.resolve_spell(caster, normal, empty, true)
	check.call(caster.spell_slots["1"] == before, "029 review: documented on_success branch refunds actual paid slot")

	# A damage-only ward leaves the preceding save and following independent effect intact.
	var stepped := DataLoader.get_spell("fixture:029_multi_target_stepped").duplicate(true)
	stepped["steps"][1].erase("gate")
	stepped["steps"][1].erase("gate_step")
	stepped["steps"][1]["damage"] = "5"
	stepped["steps"].append({"id":"independent_effect","type":"effect","effects":[{"type":"heal","value":1}]})
	normal.current_hp = 20
	var decisions := {"recipient_effect_negations":{SpellEffects.caster_id(normal):{"step_types":["damage"]}}}
	resolved = CombatAction.resolve_spell(caster, normal, stepped, true, decisions)
	var rows: Array = resolved.get("step_results", [])
	check.call(rows.size() == 3 and not rows[0].target_outcomes[0].get("skipped", false) and rows[1].target_outcomes[0].get("negated", false) and not rows[2].target_outcomes[0].get("skipped", false) and normal.current_hp == 21, "029 review: step-filtered ward preserves save and independent effect")

	# Resolve real area steps with the protected creature as primary target.
	var grid := HexGrid.new()
	grid.generate_procedural(9, 9)
	var area := stepped.duplicate(true)
	area.steps = [{"id":"area_damage","type":"damage","target":"area","shape":"sphere","radius":2,"damage":"5","damage_type":"lightning"}]
	warded.current_hp = 30
	normal.current_hp = 30
	var area_decisions := {"grid":grid,"target_coord":Vector2i.ZERO,"players":[{"character":warded,"hex_position":Vector2i.ZERO},{"character":normal,"hex_position":Vector2i(1,0)}],"monsters":[]}
	resolved = CombatAction.resolve_spell(caster, warded, area, true, area_decisions)
	check.call(resolved.get("step_results", []).size() == 1 and warded.current_hp == 30 and normal.current_hp == 25, "029 review: warded primary cannot cancel another area recipient")
	grid.free()

	# Stopping policies must settle the selected payment kind only.
	var reactor := _make_caster("029 review reactor")
	var stop := DataLoader.get_spell("fixture:029_spell_breaker")
	reactor.features.append({"id":"fixture:029_free_stop","type":"passive","effects":[{"type":"spell_free_cast","spells":[stop.id],"ability":"INT","uses":2}]})
	reactor.feature_uses["free_spell_cast:fixture:029_free_stop"] = 2
	var choice := SpellPermissionRules.payment_choices(reactor, stop.id)[0]
	var paid := SpellPermissionRules.spend_reaction(reactor, stop.id, {SpellPermissionRules.reaction_key(reactor, stop.id):choice})
	var slots := reactor.spell_slots.duplicate()
	var policy := stop.duplicate(true)
	policy["stopping_cost_policy"] = {"on_failure":{"slot":"refund","free_cast":"refund","reaction":"commit"}}
	CastInterruptionRules.settle_stopping_costs(reactor, policy, false, paid)
	CastInterruptionRules.settle_stopping_costs(reactor, policy, false, paid)
	check.call(reactor.spell_slots == slots and reactor.feature_uses["free_spell_cast:fixture:029_free_stop"] == 2 and not reactor.reaction_available, "029 review: free stopping payment refunds once without minting slot")

	# A copied stopping definition cannot change the real contest or refund policy.
	var forged := DataLoader.get_spell("fixture:029_stopping_spell").duplicate(true)
	forged.cancellation_rule.max_spell_level = 0
	SpellPermissionChecks.grant_slot_permission(reactor, [forged.id])
	reactor.reaction_available = true
	var selected := SpellPermissionRules.payment_choices(reactor, forged.id)[0]
	resolved = CombatAction.resolve_spell(caster, normal, DataLoader.get_spell("fixture:029_target_commit"), true, {"stopping_spell:%s" % reactor.character_name:forged,SpellPermissionRules.reaction_key(reactor, forged.id):selected}, [reactor])
	check.call(resolved.get("countered", false), "029 review: stopping definition uses canonical loaded rules")


static func _exact_item_regression(check: Callable) -> void:
	var caster := _make_caster("029 ring target caster")
	var reactor := _make_caster("029 ring reactor")
	for index in 2: reactor.inventory.add_item("fixture:029_charge_ring")
	var copies: Array = reactor.inventory.backpack_instances().filter(func(copy): return copy.definition_id == "fixture:029_charge_ring")
	var first := str(copies[0].instance_id)
	var second := str(copies[1].instance_id)
	reactor.inventory.equip_instance(Inventory.Slot.RING_1, first)
	reactor.inventory.equip_instance(Inventory.Slot.RING_2, second)
	var stop := DataLoader.get_spell("fixture:029_charge_stop")
	var choice: Dictionary = SpellPermissionRules.payment_choices(reactor, stop.id).filter(func(row): return row.get("_spell_payment_source_id") == first)[0]
	var slots := reactor.spell_slots.duplicate()
	var result := CombatAction.resolve_spell(caster, reactor, DataLoader.get_spell("fixture:029_target_refund"), true, {"stopping_spell:%s" % reactor.character_name:stop,SpellPermissionRules.reaction_key(reactor, stop.id):choice,"stopping_item_instance_id":second}, [reactor])
	check.call(result.get("countered", false) and reactor.inventory.get_instance(first).is_empty() and reactor.inventory.get_instance(second).state.charges == 5 and reactor.spell_slots == slots and not reactor.reaction_available, "029 review: actual charged stopping source disposes exact paid copy, ignores sibling override and cannot mint slot")


static func _default_policy_regression(check: Callable) -> void:
	var caster := _make_caster("029 default policy caster")
	var reactor := _make_caster("029 default policy reactor")
	var spell := DataLoader.get_spell("fixture:029_target_commit").duplicate(true)
	spell.erase("interruption_policy")
	var stop := DataLoader.get_spell("fixture:029_stopping_spell")
	SpellPermissionChecks.grant_slot_permission(reactor, [stop.id, "counterspell"])
	var selected: Dictionary = SpellPermissionRules.payment_choices(reactor, stop.id)[0]
	var result := CombatAction.resolve_spell(caster, reactor, spell, true, {"stopping_spell:%s" % reactor.character_name:stop,SpellPermissionRules.reaction_key(reactor, stop.id):selected}, [reactor])
	check.call(result.get("countered", false) and caster.spell_slots["1"] == 3, "029 review: generic stopping interruption commits target payment by default")
	reactor.reaction_available = true
	caster.add_modifier("roll", "save:CON", -1000, 2)
	selected = SpellPermissionRules.payment_choices(reactor, "counterspell")[0]
	result = CombatAction.resolve_spell(caster, reactor, spell, true, {"counterspell":true,SpellPermissionRules.reaction_key(reactor,"counterspell"):selected}, [reactor])
	check.call(result.get("countered", false) and caster.spell_slots["1"] == 3, "029 review: canonical Counterspell defaults to refunding actual target slot")


static func _source_kind_regression(check: Callable) -> void:
	var reactor := _make_caster("029 exact source kind")
	reactor.features.append({"id":"wizard_signature_spells","name":"Signature Spells","type":"passive"})
	reactor.wizard_signature_spells.assign(["counterspell"])
	reactor.feature_uses["wizard_signature_spell:counterspell"] = 1
	var selected: Dictionary = SpellPermissionRules.payment_choices(reactor, "counterspell").filter(func(row): return row.get("_spell_payment_kind") == "free_cast")[0]
	var paid := SpellPermissionRules.spend_reaction(reactor, "counterspell", {SpellPermissionRules.reaction_key(reactor,"counterspell"):selected})
	var context := SpellResolutionContext.new()
	context.caster = reactor
	context.spell = selected
	context.spell_definition_id = "counterspell"
	context.slot_level = 3
	context.decisions["cast_payment_receipt"] = paid.get("payment", {})
	check.call(not paid.is_empty() and SpellPermissionRules.selected_permission(reactor, selected).is_empty() and CastInterruptionRules.is_cast_matching_cancellation(context, {"sources":["feature"]}).get("matches", false) and not CastInterruptionRules.is_cast_matching_cancellation(context, {"sources":["item"]}).get("matches", true), "029 review: exhausted last-use permission retains actual paid source kind for cancellation predicates")


static func _contest_receipt_regression(check: Callable) -> void:
	var caster := _make_caster("029 explicit contest caster")
	var reactor := _make_caster("029 explicit contest reactor")
	var stop := DataLoader.get_spell("fixture:029_explicit_dc_stop")
	SpellPermissionChecks.grant_slot_permission(reactor, [stop.id])
	var selected: Dictionary = SpellPermissionRules.payment_choices(reactor, stop.id)[0]
	var result := CombatAction.resolve_spell(caster, reactor, DataLoader.get_spell("fixture:029_target_refund"), true, {"stopping_spell:%s" % reactor.character_name:stop,SpellPermissionRules.reaction_key(reactor,stop.id):selected}, [reactor])
	check.call(result.get("countered", false) and result.get("counterspell_save_dc", 0) == 99, "029 review: custom cancellation receipt retains actual explicit contest DC")
