class_name Batch070Checks
extends RefCounted
## Batch 070 (S-084/S-085): data-authored Extra Attack count and base AC
## alternatives. Exclusive options choose one (SRD 5.2.1 "Only One Base AC";
## Extra Attack features don't stack); the exact attuned copy gates them;
## removal, suppression and reload restore the prior values.

const CLASS := "fixture:b070_class"
const BRACERS := "fixture:b070_bracers"
const EXTRA := "fixture:b070_extra_attack"
const GUARD := "fixture:b070_unarmored"

static func load_fixtures() -> void:
	if not DataLoader.get_item(BRACERS).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_070/classes/drill.json", "class")
	DataLoader._load_json_file("res://data/fixtures/batch_070/items/bracers.json", "item")

static func actor(id: String) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 16, "DEX": 14, "CON": 16, "INT": 10, "WIS": 12, "CHA": 10})
	var a := Character.new()
	a.initialize(id, "human", CLASS, scores)
	a.character_id = id
	a.max_hp = 40
	a.current_hp = 40
	return a

static func wear(a: Character, attune: bool = true) -> String:
	var id := Batch041Checks.add_copy(a, BRACERS)
	a.inventory.equip_instance(Inventory.Slot.HEAD, id)
	if attune: a.inventory.attune_instance(id, a.character_id)
	return id

static func _upgrade(changes: Dictionary, group: String = "g") -> Dictionary:
	var u := {"id": "u", "name": "U", "type": "rule_upgrade", "rule": EXTRA, "changes": changes}
	if not group.is_empty(): u["exclusive_group"] = group
	return u

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_item(BRACERS).is_empty() and not DataLoader.get_character_class(CLASS).is_empty(), "070 fixtures load: %s" % str(DataLoader.get_load_errors()))
	_validation(check)
	_values(check)
	_gates(check)
	_reload(check)
	_swings(check)
	_review_stacking(check)

static func _validation(check: Callable) -> void:
	check.call(RuleUpgradeRules.validate_rule(_upgrade({"attack_count": {"set": 2}})).is_empty(), "070 an attack_count set in an exclusive group validates")
	check.call(not RuleUpgradeRules.validate_rule(_upgrade({"attack_count": {"set": 2}}, "")).is_empty(), "070 an attack_count without exclusive_group is refused (choose one, never stack)")
	check.call(not RuleUpgradeRules.validate_rule(_upgrade({"attack_count": {"set": 0}})).is_empty() and not RuleUpgradeRules.validate_rule(_upgrade({"attack_count": {"set": 4}})).is_empty() and not RuleUpgradeRules.validate_rule(_upgrade({"attack_count": {"add": 1}})).is_empty(), "070 attack_count needs set 1-3; add or out-of-range values are refused")
	check.call(not RuleUpgradeRules.validate_rule(_upgrade({"base_ac": {"set": {"base": 13, "abilities": ["DEX"]}}})).is_empty(), "070 a base_ac without allows_shield is refused: no engine default")
	check.call(not RuleUpgradeRules.validate_rule(_upgrade({"base_ac": {"set": {"base": 13, "abilities": ["DEX", "DEX"], "allows_shield": true}}})).is_empty() and not RuleUpgradeRules.validate_rule(_upgrade({"base_ac": {"set": {"base": 13, "abilities": ["LUCK"], "allows_shield": true}}})).is_empty(), "070 repeated or unknown base_ac abilities are refused")
	check.call(not RuleUpgradeRules.validate_rule(_upgrade({"attack_count": {"set": 2}, "uses": {"add": 1}})).is_empty(), "070 consumer changes cannot be mixed with mode changes")
	check.call(RuleUpgradeRules.validate_rule(_upgrade({"attack_count": {"set": 2}}), {"other": true}).is_empty() and not RuleUpgradeRules.validate_rule(_upgrade({"uses": {"add": 1}}), {"other": true}).is_empty(), "070 an item consumer upgrade may name its wearer's rule; a mode upgrade still must name a local rule")
	check.call(OwnedFeatureSources.definition_error(DataLoader.get_item(BRACERS), "item").is_empty(), "070 the bracers definition passes the item feature validator")

static func _values(check: Callable) -> void:
	var a := actor("b070_values")
	check.call(RuleUpgradeRules.extra_attacks(a) == 1 and a.get_ac() == 13, "070 base: one Extra Attack and AC 10 + DEX 2 + WIS 1 = 13 (%d/%d)" % [RuleUpgradeRules.extra_attacks(a), a.get_ac()])
	var id := wear(a, false)
	check.call(RuleUpgradeRules.extra_attacks(a) == 1 and a.get_ac() == 13, "070 worn but unattuned: the copy owns nothing")
	a.inventory.attune_instance(id, a.character_id)
	check.call(RuleUpgradeRules.extra_attacks(a) == 2 and a.get_ac() == 15, "070 attuned: the first option of each group applies once (2 extra attacks, AC 13 + DEX = 15; %d/%d)" % [RuleUpgradeRules.extra_attacks(a), a.get_ac()])
	var rows := ModeControls.rows(a)
	var ids: Array = rows.map(func(r): return str(r.feature_id))
	check.call(EXTRA in ids and GUARD in ids and rows.all(func(r): return r.feature_id not in [EXTRA, GUARD] or r.actions == ["alternative"]), "070 the HUD/room rows offer Choose upgrade (only) for both passive rules")
	var row := ModeControls.row(a, GUARD)
	var stale := str(row.token)
	check.call(ModeControls.apply(a, GUARD, "alternative", "", stale).reason == "canceled" and a.get_ac() == 15, "070 cancel changes nothing")
	var done := ModeControls.apply(a, GUARD, "alternative", "base_ac|guard_b@" + id, stale)
	check.call(done.success and a.get_ac() == 15 and a.base_ac == 15, "070 Sturdy Frame: AC 10 + DEX 2 + CON 3 = 15 (%d)" % a.get_ac())
	check.call(ModeControls.apply(a, GUARD, "alternative", "base_ac|guard_a@" + id, stale).reason == "stale" and a.rule_alternatives[GUARD + "|base_ac"] == "guard_b@" + id, "070 a stale popup answer is refused and changes nothing")
	a.inventory.add_item("shield")
	a.inventory.equip(Inventory.Slot.SHIELD, "shield")
	check.call(a.get_ac() == 14, "070 Sturdy Frame disallows a shield: 10 + DEX + shield 2 = 14 (%d)" % a.get_ac())
	RuleUpgradeRules.choose_alternative(a, GUARD, "base_ac", "guard_a@" + id)
	check.call(a.get_ac() == 17, "070 Hardened Skin allows a shield: 13 + DEX + 2 = 17 (%d)" % a.get_ac())
	a.inventory.unequip(Inventory.Slot.SHIELD)
	check.call(RuleUpgradeRules.choose_alternative(a, EXTRA, "drill", "drill_b@" + id) and RuleUpgradeRules.extra_attacks(a) == 1, "070 Steady Drill sets the count back to one extra attack")
	check.call(not RuleUpgradeRules.choose_alternative(a, EXTRA, "drill", "drill_a@inv_other") and a.rule_alternatives[EXTRA + "|drill"] == "drill_b@" + id, "070 an option another copy owns is refused")

static func _gates(check: Callable) -> void:
	var a := actor("b070_gates")
	var id := wear(a)
	var muted := MagicPropertyRules.apply(a, {"source_id": "b070_mute", "caster_id": a.character_id, "spell_id": "b070"}, {"type": "suppress_item_magic", "properties": ["features"]})
	check.call(muted.get("applied", false) and RuleUpgradeRules.extra_attacks(a) == 1 and a.get_ac() == 13, "070 suppressed item features apply no count or base AC (MagicPropertyRules gate)")
	a.spell_effects.erase("b070_mute")
	check.call(RuleUpgradeRules.extra_attacks(a) == 2 and a.get_ac() == 15, "070 suppression ending restores the copy's options")
	RuleUpgradeRules.choose_alternative(a, GUARD, "base_ac", "guard_b@" + id)
	a.inventory.unequip(Inventory.Slot.HEAD)
	var record: Dictionary = a.inventory.copies.records[id]
	check.call(RuleUpgradeRules.extra_attacks(a) == 1 and a.get_ac() == 13 and a.base_ac == 13 and a.rule_alternatives.is_empty(), "070 removing the copy restores one extra attack and AC 13; no orphan choice stays")
	check.call(record.state.get("rule_alternatives", {}).get(GUARD + "|base_ac", "") == "guard_b@" + id and InventoryCopies.record_state_error(record).is_empty(), "070 the leaving copy remembers its chosen base AC on record.state, which passes record_state_error")
	var forged: Dictionary = record.duplicate(true)
	forged.state["rule_alternatives"] = {GUARD + "|base_ac": "guard_b@inv_other"}
	check.call(not InventoryCopies.record_state_error(forged).is_empty(), "070 a stamped option naming another copy is refused")
	a.inventory.equip_instance(Inventory.Slot.HEAD, id)
	check.call(a.rule_alternatives.get(GUARD + "|base_ac", "") == "guard_b@" + id and a.get_ac() == 15, "070 re-wearing the copy restores its remembered option")

static func _reload(check: Callable) -> void:
	var a := actor("b070_reload")
	var id := wear(a)
	RuleUpgradeRules.choose_alternative(a, EXTRA, "drill", "drill_a@" + id)
	RuleUpgradeRules.choose_alternative(a, GUARD, "base_ac", "guard_b@" + id)
	var dto: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	var b := Character.new()
	b.from_dict(dto)
	var feature_ids: Array = b.features.map(func(f): return str(f.get("id", "")))
	check.call(RuleUpgradeRules.extra_attacks(b) == 2 and b.get_ac() == 15 and feature_ids.count("drill_a@" + id) == 1 and b.extra_attacks == 1, "070 a reload rebuilds the chosen count and AC once; the base count is not rewritten")
	check.call(RuleUpgradeRules.saved_error(dto).is_empty(), "070 saved alternatives pass validation")
	var forged: Dictionary = dto.duplicate(true)
	forged["rule_alternatives"] = {EXTRA + "|drill": "drill_z@" + id}
	check.call(not RuleUpgradeRules.saved_error(forged).is_empty(), "070 a forged saved option is refused on load")
	var legacy: Dictionary = dto.duplicate(true)
	legacy.erase("rule_alternatives")
	var c := Character.new()
	c.from_dict(legacy)
	check.call(RuleUpgradeRules.extra_attacks(c) == 2 and c.get_ac() == 15 - 2 + 2, "070 a save without rule_alternatives loads with each group's first option")
	b.inventory.unequip(Inventory.Slot.HEAD)
	var d := Character.new()
	d.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
	check.call(RuleUpgradeRules.extra_attacks(d) == 1 and d.get_ac() == 13 and d.rule_alternatives.is_empty(), "070 removal then reload keeps the restored values")

## The combat ledger: switching keeps spent swings spent, never refunds.
static func _swings(check: Callable) -> void:
	var a := actor("b070_swings")
	var id := wear(a)
	var combat := CombatState.new()
	combat.active_character = a
	combat.attack_action_total = 1 + RuleUpgradeRules.extra_attacks(a)
	combat.remaining_attack_swings = combat.attack_action_total - 1
	RuleUpgradeRules.choose_alternative(a, EXTRA, "drill", "drill_b@" + id)
	combat.reclamp_attack_units()
	var down := combat.remaining_attack_swings
	RuleUpgradeRules.choose_alternative(a, EXTRA, "drill", "drill_a@" + id)
	combat.reclamp_attack_units()
	check.call(down == 1 and combat.remaining_attack_swings == 1, "070 3-swing action with one spent: switching to 2 leaves 1, switching back does not refund (%d/%d)" % [down, combat.remaining_attack_swings])
	a.inventory.unequip(Inventory.Slot.HEAD)
	combat.reclamp_attack_units()
	check.call(combat.remaining_attack_swings == 1, "070 removal with 1 spent of 2 base swings keeps the 1 remaining")
	combat.free()

## Review 070: two Extra Attack rules never stack, upgraded or not.
static func _review_stacking(check: Callable) -> void:
	var a := actor("b070_stack")
	var id := wear(a)
	a.features.append({"id": "b070_review_other_ea", "name": "Other Extra Attack", "type": "passive", "effects": [{"type": "extra_attack", "count": 2}]})
	a.extra_attacks = 2
	check.call(RuleUpgradeRules.extra_attacks(a) == 2, "R070 an upgraded set 2 beside another rule's count 2 gives 2, not 3 (%d)" % RuleUpgradeRules.extra_attacks(a))
	RuleUpgradeRules.choose_alternative(a, EXTRA, "drill", "drill_b@" + id)
	check.call(RuleUpgradeRules.extra_attacks(a) == 2, "R070 lowering one rule's count never lowers below another source (%d)" % RuleUpgradeRules.extra_attacks(a))
	a.features.pop_back()
	a.extra_attacks = 1
	RuleUpgradeRules.choose_alternative(a, EXTRA, "drill", "drill_a@" + id)
	check.call(RuleUpgradeRules.extra_attacks(a) == 2, "R070 single rule upgraded to set 2 still gives 2 (%d)" % RuleUpgradeRules.extra_attacks(a))
