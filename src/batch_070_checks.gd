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
	_base_choice(check)

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
	a.armor_proficiencies.append("shields")
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


static func _base_choice(check: Callable) -> void:
	var a := actor("cxm07_base_choice")
	var row := ModeControls.row(a, ModeControls.BASE_AC_CONTROL)
	var ordinary := JSON.stringify(["unarmored"])
	check.call(row.actions == ["base_ac"] and a.get_ac() == 13, "CXM-07 competing loaded base formulas expose a choice with highest fallback")
	check.call(ModeControls.apply(a, ModeControls.BASE_AC_CONTROL, "base_ac", ordinary, row.token).success and a.get_ac() == 12, "CXM-07 player can select ordinary AC even when an owned formula is higher")
	var stale := ModeControls.row(a, ModeControls.BASE_AC_CONTROL)
	a.ability_scores.wisdom = 16
	var feature_id := ""
	for candidate in a.base_ac_candidates():
		if candidate.name == "Unarmored Guard": feature_id = candidate.id
	check.call(not feature_id.is_empty() and ModeControls.apply(a, ModeControls.BASE_AC_CONTROL, "base_ac", feature_id, stale.token).reason == "stale" and a.get_ac() == 12, "CXM-07 changed ability invalidates the offered AC choice")
	row = ModeControls.row(a, ModeControls.BASE_AC_CONTROL)
	check.call(ModeControls.apply(a, ModeControls.BASE_AC_CONTROL, "base_ac", feature_id, row.token).success and a.get_ac() == 15, "CXM-07 exact loaded feature formula can be selected")
	var armor_copy := Batch041Checks.add_copy(a, "chain_mail")
	a.inventory.equipment_control_equip(Inventory.Slot.BODY, armor_copy)
	var temporarily_armored := a.to_dict()
	var recovered_armored := Character.new()
	recovered_armored.from_dict(JSON.parse_string(JSON.stringify(temporarily_armored)))
	a.inventory.equipment_control_unequip(Inventory.Slot.BODY)
	recovered_armored.inventory.equipment_control_unequip(Inventory.Slot.BODY)
	check.call(temporarily_armored.base_ac_choice == feature_id and a.base_ac_choice == feature_id and a.get_ac() == 15 and recovered_armored.base_ac_choice == feature_id and recovered_armored.get_ac() == 15, "CXM-07 saving through temporary armor ineligibility preserves the owned feature preference")
	a.add_condition("mage_armor", 20)
	var mage_id := ""
	for candidate in a.base_ac_candidates():
		if candidate.name == "Mage Armor": mage_id = candidate.id
	row = ModeControls.row(a, ModeControls.BASE_AC_CONTROL)
	check.call(not mage_id.is_empty() and ModeControls.apply(a, ModeControls.BASE_AC_CONTROL, "base_ac", mage_id, row.token).success and a.get_ac() == 15, "CXM-07 Mage Armor is a separate selectable base")
	row = ModeControls.row(a, ModeControls.BASE_AC_CONTROL)
	check.call(ModeControls.apply(a, ModeControls.BASE_AC_CONTROL, "base_ac", ordinary, row.token).success and a.get_ac() == 12, "CXM-07 explicit ordinary base wins over Mage Armor as well")
	var dto: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	var restored := Character.new()
	restored.from_dict(dto)
	check.call(Character.saved_base_ac_choice_error(dto).is_empty() and restored.base_ac_choice == ordinary and restored.get_ac() == 12, "CXM-07 exact base preference survives character DTO recovery")
	dto.base_ac_choice = "bad"
	check.call(not Character.saved_base_ac_choice_error(dto).is_empty(), "CXM-07 malformed saved base choice is refused")
	for forged in [JSON.stringify(["armor", "unowned_copy"]), JSON.stringify(["protection", "unowned_grant"]), JSON.stringify(["feature", "unowned_feature", "", ""])]:
		dto.base_ac_choice = forged
		check.call(not Character.saved_base_ac_choice_error(dto).is_empty(), "CXM-07 forged AC source is refused: %s" % forged)
	row = ModeControls.row(a, ModeControls.BASE_AC_CONTROL)
	check.call(ModeControls.apply(a, ModeControls.BASE_AC_CONTROL, "base_ac", JSON.stringify(["automatic"]), row.token).success and a.get_ac() == 15, "CXM-07 automatic highest-base fallback can be restored")

	DataLoader._load_json_file("res://data/fixtures/batch_g_protections.json", "class")
	var guarded := actor("cxm07_timed_base")
	var feature: Dictionary = DataLoader.get_character_class("fixture:batch_g_protections").features_by_level["1"][0].duplicate(true)
	feature.source_instance_id = "cxm07:protection"
	guarded.features.append(feature)
	var acquired := ResourcePoolRules.acquire(guarded, feature, feature.source_instance_id)
	var activated := ClassFeature.execute(guarded, feature, null, null, feature.source_instance_id)
	var protection_id := ""
	for candidate in guarded.base_ac_candidates():
		if str(candidate.id).contains("protection"): protection_id = candidate.id
	row = ModeControls.row(guarded, ModeControls.BASE_AC_CONTROL)
	var ordinary_choice := ModeControls.apply(guarded, ModeControls.BASE_AC_CONTROL, "base_ac", ordinary, row.token)
	check.call(acquired.get("success", false) and activated.get("success", false) and not protection_id.is_empty() and ordinary_choice.success and guarded.get_ac() == 12 and guarded.ability_scores.get_score("STR") == 18, "CXM-07 choosing a different base keeps the timed protection's other benefits")
	row = ModeControls.row(guarded, ModeControls.BASE_AC_CONTROL)
	check.call(ModeControls.apply(guarded, ModeControls.BASE_AC_CONTROL, "base_ac", protection_id, row.token).success and guarded.get_ac() == 15, "CXM-07 exact timed protection is a selectable AC base")
	guarded.class_id = "familiar"
	guarded.base_ac = 17
	guarded.base_ac_choice = ""
	check.call(guarded.get_ac() == 17, "CXM-07 automatic selection retains template AC against a lower timed base")
	row = ModeControls.row(guarded, ModeControls.BASE_AC_CONTROL)
	var native_id := JSON.stringify(["native"])
	check.call(ModeControls.apply(guarded, ModeControls.BASE_AC_CONTROL, "base_ac", native_id, row.token).success and guarded.get_ac() == 17, "CXM-07 a template creature chooses its real native AC rather than an invented unarmored formula")
	guarded.inventory.equip(Inventory.Slot.SHIELD, "shield", true)
	guarded.inventory.unequip(Inventory.Slot.SHIELD)
	guarded._recalculate_ac()
	check.call(guarded.base_ac == 17 and guarded.get_ac() == 17, "CXM-07 template AC survives equipment changes and recalculation")
	guarded.class_id = CLASS
	guarded.base_ac_choice = protection_id
	ProtectionRules.remove_source(guarded, feature.source_instance_id)
	check.call(guarded.get_ac() == 13, "CXM-07 a removed selected source falls back to a surviving legal base")

	var legacy := actor("cxm07_legacy_shield")
	legacy.armor_proficiencies.append("shields")
	legacy.inventory.equip(Inventory.Slot.SHIELD, "shield", true)
	legacy.armor_proficiencies.clear()
	var legacy_dto := legacy.to_dict()
	legacy_dto.erase("base_ac_choice")
	var recovered := Character.new()
	recovered.from_dict(legacy_dto)
	check.call(int(legacy_dto.base_ac) == 14 and recovered.get_ac() == 12, "CXM-07 legacy equipment recovery removes a stale untrained Shield bonus")

	var item_owner := actor("cxm07_item_choice")
	var bracers := wear(item_owner)
	var upgraded_choice := ""
	for candidate in item_owner.base_ac_candidates():
		if candidate.name == "Unarmored Guard": upgraded_choice = candidate.id
	row = ModeControls.row(item_owner, ModeControls.BASE_AC_CONTROL)
	var picked := ModeControls.apply(item_owner, ModeControls.BASE_AC_CONTROL, "base_ac", upgraded_choice, row.token)
	item_owner.inventory.unequip(Inventory.Slot.HEAD)
	var packed: Dictionary = JSON.parse_string(JSON.stringify(item_owner.to_dict()))
	var reloaded := Character.new()
	reloaded.from_dict(packed)
	var reequipped := reloaded.inventory.equip_instance(Inventory.Slot.HEAD, bracers)
	check.call(picked.success and packed.base_ac_choice == upgraded_choice and reequipped and reloaded.base_ac_choice == upgraded_choice and reloaded.get_ac() == 15, "CXM-07 saving while an owned upgrade copy is unequipped preserves its exact base preference")
