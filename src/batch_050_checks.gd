class_name Batch050Checks
extends RefCounted
## Batch 050: Brandon's 047-049 playtest fixes, one regression each, plus the
## remembered-option, dawn-recovery and explicit-suppression decisions.

const BLADE := "fixture:b050_blade"

static func load_fixtures() -> void:
	Batch049Checks.load_fixtures()
	if not DataLoader.get_item(BLADE).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_050/items/blade.json", "item")

static func ward(id: String) -> String:
	return "ward@" + id

static func actor(id: String) -> Character:
	var a := Batch031Checks._character(id, 40)
	a.inventory.unequip(Inventory.Slot.SHIELD)
	return a

## Equip a fresh blade in the main hand (or off hand). Returns the copy id.
static func wield(a: Character, slot: Inventory.Slot = Inventory.Slot.WEAPON) -> String:
	var id := Batch041Checks.add_copy(a, BLADE)
	a.inventory.equip_instance(slot, id)
	return id

static func mute(a: Character, source: String) -> Dictionary:
	return MagicPropertyRules.apply(a, {"source_id": source, "caster_id": a.character_id, "spell_id": "fixture:b050_quell"}, {"type": "suppress_item_magic", "properties": ["features"]})

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_item(BLADE).is_empty(), "050 dawn-recharging magic blade fixture loads: %s" % str(DataLoader.get_load_errors()))
	_bug1_drop(check)
	_bug2_suppressed_end(check)
	_bug3_identical(check)
	_bug4_missing_feat(check)
	_dawn(check)
	_suppression_scope(check)
	_dawn_anywhere(check)

## Bug 1: dropping an equipped copy must not recharge it for the next holder.
static func _bug1_drop(check: Callable) -> void:
	var a := actor("b050_dropper")
	var id := wield(a)
	var chose := RuleUpgradeRules.choose_alternative(a, ward(id), "edge", "deep@" + id)
	var on := FeatureModeRules.activate(a, ward(id), "protect")
	FeatureModeRules.end(a, ward(id), "dismissed")
	var record := a.inventory.drop_equipped_instance(Inventory.Slot.WEAPON)
	check.call(chose and on.success and int(record.get("state", {}).get("feature_uses", {}).get(ward(id), -1)) == 1 and record.state.get("rule_alternatives", {}).get(ward(id) + "|edge", "") == "deep@" + id and InventoryCopies.record_state_error(record).is_empty(), "050 bug 1: the dropped copy carries its 1 remaining use and its Deep option on record.state, which passes record_state_error")
	var b := actor("b050_finder")
	b.inventory.receive_instance(record)
	b.inventory.equip_instance(Inventory.Slot.WEAPON, id)
	check.call(int(b.feature_uses.get(ward(id), -1)) == 1 and b.get_feature_max_uses(ward(id)) == 3 and b.rule_alternatives.get(ward(id) + "|edge", "") == "deep@" + id, "050 bug 1: the new holder sees the same 1 use and the copy's remembered option, not a recharge")
	var back := Character.new()
	b.inventory.unequip(Inventory.Slot.WEAPON)
	back.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
	back.inventory.equip_instance(Inventory.Slot.WEAPON, id)
	check.call(int(back.feature_uses.get(ward(id), -1)) == 1 and back.rule_alternatives.get(ward(id) + "|edge", "") == "deep@" + id, "050 decision: an unequipped copy keeps its uses and chosen option on the record across save/load")
	var forged: Dictionary = record.duplicate(true)
	forged.state["rule_alternatives"] = {ward(id) + "|edge": "deep@inv_other"}
	check.call(not InventoryCopies.record_state_error(forged).is_empty(), "050 a stamped option that names another copy's upgrade is refused")

## Bug 2: a suppressed power still ends on its declared end condition.
static func _bug2_suppressed_end(check: Callable) -> void:
	var a := actor("b050_ward")
	var id := wield(a)
	var on := FeatureModeRules.activate(a, ward(id), "protect")
	var muted := mute(a, "b050_mute")
	a.add_condition("incapacitated", 6)
	a.remove_condition("incapacitated")
	a.spell_effects.erase("b050_mute")
	check.call(on.success and muted.get("applied", false) and not bool(a.feature_modes[ward(id)].active) and SourceBenefitRules.total(a, "AC") == 0, "050 bug 2: protection ended by incapacitation while suppressed does not return when suppression ends")
	var u := actor("b050_ward_uncon")
	var uid := wield(u)
	FeatureModeRules.activate(u, ward(uid), "protect")
	u.add_condition("unconscious", 6)
	check.call(not bool(u.feature_modes[ward(uid)].active), "050 an Unconscious wielder is Incapacitated too, so the declared end fires")

## Bug 3: identical equipped copies each exist with their own uses.
static func _bug3_identical(check: Callable) -> void:
	var a := actor("b050_pair")
	var main := wield(a)
	var off := wield(a, Inventory.Slot.OFFHAND)
	check.call(a.has_feature(ward(main)) and a.has_feature(ward(off)) and int(a.feature_uses[ward(main)]) == 2 and int(a.feature_uses[ward(off)]) == 2, "050 bug 3: both identical blades own their Ward with separate pools")
	FeatureModeRules.activate(a, ward(main), "protect")
	var second := FeatureModeRules.activate(a, ward(off), "protect")
	check.call(second.success and int(a.feature_uses[ward(main)]) == 1 and int(a.feature_uses[ward(off)]) == 1 and SourceBenefitRules.total(a, "AC") == 1, "050 bug 3: each copy spends its own use; the same item's power grants its bonus once")
	var back := Character.new()
	back.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	check.call(back.feature_modes.has(ward(main)) and back.feature_modes.has(ward(off)) and int(back.feature_uses[ward(off)]) == 1 and SourceBenefitRules.total(back, "AC") == 1, "050 bug 3: both copies' states survive reload, still granting once")

## Bug 4: a missing feat id fails loading with a useful message.
static func _bug4_missing_feat(check: Callable) -> void:
	var before := DataLoader._load_errors.size()
	DataLoader._load_json_file("res://data/fixtures/batch_050/races/typo.json", "race")
	var errors: Array = DataLoader._load_errors.slice(before)
	DataLoader._load_errors.resize(before)
	var text := " ".join(errors)
	check.call(errors.size() == 1 and "fixture:b050_typo_kin" in text and "typo.json" in text and "fixture:b049_faet" in text and DataLoader.get_race("fixture:b050_typo_kin").is_empty(), "050 bug 4: a species naming a missing feat fails loading, naming the species, its file and the missing id: %s" % text)
	var race := {"id": "x", "name": "X", "feats": ["nope"]}
	check.call("nope" in DataLoader.missing_feat_error(race, "probe.json") and DataLoader.missing_feat_error(DataLoader.get_race(Batch049Checks.KIN), "k").is_empty(), "050 bug 4: the full-load pass uses the same check (unknown id reported, known feat clean)")

## SRD 5.2.1 p.206: item recharge at dawn, worn or not.
static func _dawn(check: Callable) -> void:
	var a := actor("b050_dawn")
	var id := wield(a)
	FeatureModeRules.activate(a, ward(id), "protect")
	FeatureModeRules.end(a, ward(id), "dismissed")
	var carried := wield(a, Inventory.Slot.OFFHAND)
	FeatureModeRules.activate(a, ward(carried), "protect")
	FeatureModeRules.end(a, ward(carried), "dismissed")
	a.inventory.unequip(Inventory.Slot.OFFHAND)
	a.long_rest()
	check.call(int(a.feature_uses[ward(id)]) == 1 and int(a.inventory.get_instance(carried).state.feature_uses[ward(carried)]) == 1, "050 a long rest does not recharge a dawn item (source rule, not wearer rule)")
	OwnedFeatureSources.recover_dawn(a)
	a.inventory.equip_instance(Inventory.Slot.OFFHAND, carried)
	check.call(int(a.feature_uses[ward(id)]) == 2 and int(a.feature_uses[ward(carried)]) == 2, "050 dawn recharges both the wielded copy and the carried-but-unworn copy")
	var bad := DataLoader.get_item(Batch049Checks.KIN) # empty: species cannot recover at dawn
	var kin := DataLoader.get_feat(Batch049Checks.FEAT).duplicate(true)
	for key in ["_source", "_source_record"]: kin.erase(key)
	kin.features[0]["uses_per"] = "dawn"
	check.call(bad.is_empty() and not Batch049Checks._loads(kin, "feat"), "050 dawn recovery is accepted only on item powers")

## Decision: suppression explicitly covers item modes and upgrades; others leave them alone.
static func _suppression_scope(check: Callable) -> void:
	var a := actor("b050_scope")
	var id := wield(a)
	RuleUpgradeRules.choose_alternative(a, ward(id), "edge", "deep@" + id)
	var before := a.get_feature_max_uses(ward(id))
	mute(a, "b050_scope_mute")
	var muted_upgrades := RuleUpgradeRules.upgrades_for(a, ward(id)).size()
	var refused := FeatureModeRules.activate(a, ward(id), "protect")
	a.spell_effects.erase("b050_scope_mute")
	var other := MagicPropertyRules.apply(a, {"source_id": "b050_benefits_only", "caster_id": a.character_id, "spell_id": "x"}, {"type": "suppress_item_magic", "properties": ["source_benefits"]})
	var still := FeatureModeRules.activate(a, ward(id), "protect")
	check.call(before == 3 and muted_upgrades == 0 and not refused.success and int(a.feature_uses[ward(id)]) == 1 and not other.get("applied", false) and still.success, "050 checklist: a 'features' suppression mutes the copy's modes and upgrades and refuses before cost; a suppression not naming 'features' leaves them alone")

static func _spent(a: Character, definition: String) -> String:
	var id := Batch041Checks.add_copy(a, definition)
	a.inventory.equip_instance(Inventory.Slot.WEAPON, id)
	if DataLoader.get_item(definition).get("requires_attunement", false): a.inventory.attune_instance(id, a.character_id)
	FeatureModeRules.activate(a, ward(id), "protect")
	FeatureModeRules.end(a, ward(id), "dismissed")
	a.inventory.unequip(Inventory.Slot.WEAPON)
	return id

## Brandon: identical copies keep separate pools; "regains at dawn" applies held,
## stowed or lying in a room, unless the item's JSON requires being worn/attuned.
static func _dawn_anywhere(check: Callable) -> void:
	var a := actor("b050_dawn_any")
	var pack := Batch048Checks.add(a, "backpack")
	var stowed := _spent(a, BLADE)
	var put := ContainerRules.stow(a.inventory, stowed)
	var lying := _spent(a, BLADE)
	var floor_record := a.inventory.take_instance(lying)
	var room := {"objects": [{"id": "loose:1", "kind": "loose", "contents": [floor_record]}]}
	var bound := _spent(a, "fixture:b050_bound_blade")
	a.inventory.unattune_instance(bound, a.character_id)
	var bound_record := a.inventory.take_instance(bound)
	var bound_room := {"objects": [{"id": "loose:2", "kind": "loose", "contents": [bound_record]}]}
	var nested: Dictionary = ContainerRules.contents(a.inventory, pack)[0]
	check.call(put.get("success", false) and int(nested.state.feature_uses[ward(stowed)]) == 1 and int(floor_record.state.feature_uses[ward(lying)]) == 1, "050 fix: spent copies are stowed in a backpack and lying in a room with 1 use each")
	OwnedFeatureSources.recover_dawn(a)
	OwnedFeatureSources.recover_dawn_rooms([room, bound_room])
	nested = ContainerRules.contents(a.inventory, pack)[0]
	check.call(int(nested.state.feature_uses[ward(stowed)]) == 2 and int(room.objects[0].contents[0].state.feature_uses[ward(lying)]) == 2, "050 fix: dawn recharges a copy inside a container and a copy lying in a room")
	check.call(int(bound_room.objects[0].contents[0].state.feature_uses[ward(bound)]) == 1, "050 fix: a copy whose JSON says recharge_while attuned does not recharge unattuned")
	var b := actor("b050_dawn_finder")
	b.inventory.receive_instance(room.objects[0].contents[0])
	b.inventory.equip_instance(Inventory.Slot.WEAPON, lying)
	check.call(int(b.feature_uses[ward(lying)]) == 2 and InventoryCopies.record_state_error(nested).is_empty(), "050 fix: the room copy picked up after dawn starts recharged; the stowed record passes record_state_error")
	var held := actor("b050_dawn_bound_held")
	var hb := _spent(held, "fixture:b050_bound_blade")
	OwnedFeatureSources.recover_dawn(held)
	check.call(int(held.inventory.get_instance(hb).state.feature_uses[ward(hb)]) == 2, "050 fix: the attuned bound copy recharges at dawn even unworn")
	var item := DataLoader.get_item(BLADE).duplicate(true)
	for key in ["_source", "_source_record"]: item.erase(key)
	item.features[0]["recharge_while"] = "sleeping"
	check.call(not Batch048Checks._loads(item), "050 fix: an unknown recharge_while requirement is refused at load")
