class_name Batch041Checks
extends RefCounted

const CLASS_ID := "fixture:b041_class"
const GUISE := "fixture:b041_guise"
const CHARM := "fixture:b041_charm"
const BLADE := "b041:blade"
const WARD := "b041:ward"

static func load_fixtures() -> void:
	Batch039Checks.load_fixtures()
	Batch040Checks.load_fixtures()
	if not DataLoader.get_spell(GUISE).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_041/classes/bonded.json", "class")
	DataLoader._load_json_file("res://data/fixtures/batch_041/spells/guise.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_041/items/charm.json", "item")

static func bonder(id: String) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 12, "DEX": 14, "CON": 14, "INT": 12, "WIS": 12, "CHA": 16})
	var c := Character.new()
	c.initialize(id, "human", CLASS_ID, scores)
	c.character_id = id
	c.max_hp = 30
	c.current_hp = 30
	return c

static func copy_of(actor: Character, definition: String) -> String:
	for c in actor.inventory.owned_instances():
		if str(c.definition_id) == definition and not BondRules.bonded(actor, BLADE).has(str(c.instance_id)): return str(c.instance_id)
	return ""

static func add_copy(actor: Character, definition: String) -> String:
	var before: Array = actor.inventory.owned_instances().map(func(c): return str(c.instance_id))
	actor.inventory.add_item(definition)
	for c in actor.inventory.owned_instances():
		if str(c.instance_id) not in before: return str(c.instance_id)
	return ""

## Resolve the real self-cast with a chosen equipment policy; concentration is mirrored.
static func guise(actor: Character, policy: String = "") -> Dictionary:
	actor.spell_slots = {"2": 1}
	if not actor.concentrating_on.is_empty(): SpellEffects.end_concentration(actor, [actor])
	var spell := DataLoader.get_spell(GUISE).duplicate(true)
	if not policy.is_empty(): spell["_projection_equipment"] = policy
	var r := SpellResolver.resolve(actor, actor, spell, true, {}, [], 2)
	if r.get("projection", {}).get("projected", false): actor.concentrating_on = {"spell_id": GUISE, "effect_source": str(r.effect_cast.source_id), "targets": [actor]}
	return r

static func wearer(id: String) -> Character:
	var a := Batch031Checks._character(id, 40)
	var charm := add_copy(a, CHARM)
	a.inventory.equip_instance(Inventory.Slot.RING_1, charm)
	var ring := add_copy(a, "ring_of_protection")
	a.inventory.attune_instance(ring, a.character_id)
	a.inventory.equip_instance(Inventory.Slot.RING_2, ring)
	return a

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "041 neutral bond class, equipment projection and charm load: %s" % str(DataLoader.get_load_errors()))
	_bond_validation(check)
	_item_bonds(check)
	_actor_bonds(check)
	_bond_saves(check)
	_equipment_validation(check)
	_equipment(check)
	_equipment_saves(check)

static func _rule(index: int) -> Dictionary:
	return DataLoader.get_character_class(CLASS_ID).features_by_level["1"][index].duplicate(true)

static func _bond_validation(check: Callable) -> void:
	check.call(BondRules.rule_error(_rule(0)).is_empty() and BondRules.rule_error(_rule(1)).is_empty(), "041 S-161 declared item and actor bonds validate")
	var bad := 0
	for mutate in [
		func(r): r["share_with_party"] = true,
		func(r): r.capacity = 0,
		func(r): r.replacement = "steal",
		func(r): r["creature_types"] = ["beast"],
		func(r): r.erase("unique"),
	]:
		var r := _rule(0)
		mutate.call(r)
		if not BondRules.rule_error(r).is_empty(): bad += 1
	check.call(bad == 5, "041 S-161 loader refuses unknown field, zero capacity, illegal replacement, mixed target lists and undeclared uniqueness (%d/5)" % bad)

static func _item_bonds(check: Callable) -> void:
	var a := bonder("b041_blade_owner")
	check.call(BondRules.rules(a).size() == 2, "041 S-161 the owner's class features carry both bonds")
	var first := add_copy(a, "dagger")
	var r := BondRules.bond(a, BLADE, first)
	check.call(r.bonded and BondRules.is_bonded(a, BLADE, first) and r.released == "", "041 S-161 an exact held weapon copy bonds to its owner")
	var ring := add_copy(a, CHARM)
	var not_weapon := BondRules.bond(a, BLADE, ring)
	var not_held := BondRules.bond(a, BLADE, "inv:elsewhere:1")
	var again := BondRules.bond(a, BLADE, first)
	check.call(not not_weapon.bonded and not not_held.bonded and not again.bonded and BondRules.bonded(a, BLADE) == [first], "041 S-161 ineligible, unheld and repeated bonds are refused and change nothing")
	var second := add_copy(a, "dagger")
	r = BondRules.bond(a, BLADE, second)
	check.call(r.bonded and r.released == first and BondRules.bonded(a, BLADE) == [second], "041 S-161 legal replacement releases only the previous bond")
	var b := bonder("b041_blade_heir")
	check.call(a.inventory.transfer_instance(second, b.inventory) and BondRules.bonded(a, BLADE).is_empty(), "041 S-161 giving the exact copy away ends that bond")
	r = BondRules.bond(b, BLADE, second, [a])
	check.call(r.bonded and BondRules.is_bonded(b, BLADE, second) and not BondRules.is_bonded(a, BLADE, second), "041 S-161 the new holder may bond the same copy; uniqueness holds")
	var stray := bonder("b041_no_bond")
	stray.features = stray.features.filter(func(f): return str(f.get("type", "")) != "exclusive_bond")
	check.call(not BondRules.bond(stray, BLADE, add_copy(stray, "dagger")).bonded, "041 S-161 an owner without the declared feature cannot bond")

static func _actor_bonds(check: Callable) -> void:
	var a := bonder("b041_ward_owner")
	Batch039Checks.conjure(a, 3)
	var wardens := CreatedActorRules.actors(a)
	var r := BondRules.bond(a, WARD, wardens[0])
	check.call(wardens.size() == 2 and r.bonded and BondRules.is_bonded(a, WARD, wardens[0].character_id), "041 S-161 an owned created actor bonds to its owner")
	var dagger := add_copy(a, "dagger")
	BondRules.bond(a, BLADE, dagger)
	var ac_before := a.get_ac()
	var full := BondRules.bond(a, WARD, wardens[1])
	check.call(not full.bonded and full.reason == "The bond is at capacity." and BondRules.bonded(a, WARD) == [wardens[0].character_id] and BondRules.bonded(a, BLADE) == [dagger] and a.get_ac() == ac_before, "041 S-161 refusal at capacity preserves the previous bond and every other source")
	var other := bonder("b041_ward_other")
	Batch039Checks.conjure(other, 2)
	var foreign := BondRules.bond(a, WARD, CreatedActorRules.actors(other)[0])
	check.call(not foreign.bonded and BondRules.bonded(a, WARD).size() == 1, "041 S-161 another owner's actor cannot be bonded")
	SpellEffects.end_concentration(a, [a])
	check.call(BondRules.bonded(a, WARD).is_empty() and BondRules.bonded(a, BLADE) == [dagger], "041 S-161 the actor bond ends with its actor; the item bond is untouched")

static func _bond_saves(check: Callable) -> void:
	var a := bonder("b041_bond_save")
	var dagger := add_copy(a, "dagger")
	BondRules.bond(a, BLADE, dagger)
	Batch039Checks.conjure(a, 2)
	BondRules.bond(a, WARD, CreatedActorRules.actors(a)[0])
	var dto := a.to_dict()
	check.call(BondRules.saved_error(dto).is_empty() and dto.exclusive_bonds.size() == 2, "041 S-161 live bonds validate (%s)" % BondRules.saved_error(dto))
	var back := Character.new()
	back.from_dict(dto)
	check.call(BondRules.is_bonded(back, BLADE, dagger) and BondRules.bonded(back, WARD).size() == 1 and BondRules.bonded(back, WARD)[0] == CreatedActorRules.actors(back)[0].character_id, "041 S-161 reload keeps the same exact bonds")
	var defects := {
		"undeclared": func(d): d.exclusive_bonds["b041:other"] = {"serial": 1, "targets": []},
		"over capacity": func(d): d.exclusive_bonds[BLADE].targets.append({"target_id": "x", "serial": 9}),
		"unheld copy": func(d): d.exclusive_bonds[BLADE].targets[0].target_id = "inv:else:1",
		"unowned actor": func(d): d.exclusive_bonds[WARD].targets[0].target_id = "spell:else:1:actor:1",
		"future serial": func(d): d.exclusive_bonds[BLADE].targets[0].serial = 99,
	}
	var refused := 0
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		if not BondRules.saved_error(bad).is_empty(): refused += 1
	check.call(refused == 5, "041 S-161 saved bonds refuse undeclared, over-capacity, unheld, unowned and out-of-order records (%d/5)" % refused)
	var legacy := dto.duplicate(true)
	legacy.erase("exclusive_bonds")
	check.call(BondRules.saved_error(legacy).is_empty(), "041 legacy saves without bonds still validate")

static func _effect() -> Dictionary:
	return DataLoader.get_spell(GUISE).effects[0].duplicate(true)

static func _equipment_validation(check: Callable) -> void:
	check.call(ActorProjectionRules.effect_error(_effect()).is_empty(), "041 S-164 declared equipment policies validate")
	var bad := 0
	for mutate in [func(e): e.equipment = ["stowed"], func(e): e.equipment = ["worn", "worn"], func(e): e.equipment = []]:
		var e := _effect()
		mutate.call(e)
		if not ActorProjectionRules.effect_error(e).is_empty(): bad += 1
	check.call(bad == 3, "041 S-164 loader refuses unknown, duplicate and empty equipment policies (%d/3)" % bad)

static func _equipment(check: Callable) -> void:
	var a := wearer("b041_unchosen")
	var normal_ac := a.get_ac()
	var r := guise(a)
	check.call(not r.get("projection", {}).get("projected", true) and not ActorProjectionRules.is_projected(a) and a.get_ac() == normal_ac and SourceBenefitRules.total(a, "AC") == 2, "041 S-164 several legal policies require a choice; refusal changes nothing")
	var w := wearer("b041_worn")
	guise(w, "worn")
	check.call(w.get_ac() == 12 + 2 + 1 and SourceBenefitRules.total(w, "AC") == 2, "041 S-164 worn equipment keeps its copy effects in the form (ac=%d)" % w.get_ac())
	var m := wearer("b041_merged")
	var m_ac := m.get_ac()
	var charm := m.inventory.equipped_instance_id(Inventory.Slot.RING_1)
	var ring := m.inventory.equipped_instance_id(Inventory.Slot.RING_2)
	r = guise(m, "merged")
	check.call(charm in r.projection.equipment.merged and ring in r.projection.equipment.merged and m.get_ac() == 12 and SourceBenefitRules.total(m, "AC") == 0 and not m.inventory.has_equipped_attuned_item("ring_of_protection", m.character_id) and m.inventory.equipped_instance_id(Inventory.Slot.RING_1) == charm, "041 S-164 merged copies stay in their slots with only their effects suppressed (ac=%d)" % m.get_ac())
	var spare := add_copy(m, CHARM)
	m.inventory.unequip(Inventory.Slot.HANDS)
	check.call(not m.inventory.equip_instance(Inventory.Slot.HANDS, spare) and spare in m.inventory.backpack_instances().map(func(c): return str(c.instance_id)), "041 S-164 a merged form cannot don another copy")
	var other := wearer("b041_bystander")
	check.call(SourceBenefitRules.total(other, "AC") == 2, "041 S-164 suppression is limited to the merged actor's exact copies")
	m.inventory.destroy_instance(ring)
	var ended := SpellEffects.remove(m, str(m.concentrating_on.effect_source), "concentration_ended")
	m.concentrating_on.clear()
	check.call(charm in ended.projection.merged_restored and ring not in ended.projection.merged_restored and ended.projection.merged_lost == [ring] and SourceBenefitRules.total(m, "AC") == 2 and m.get_ac() == m_ac - 1, "041 S-164 reversion restores only the remaining merged copy (ac=%d before=%d)" % [m.get_ac(), m_ac])
	var d := wearer("b041_dropped")
	var d_charm := d.inventory.equipped_instance_id(Inventory.Slot.RING_1)
	r = guise(d, "dropped")
	check.call(d_charm in r.projection.equipment.dropped and d.inventory.copies.equipped.is_empty() and d.inventory.equipped_instance_id(Inventory.Slot.RING_1) == "" and d_charm in d.inventory.backpack_instances().map(func(c): return str(c.instance_id)) and d.get_ac() == 12, "041 S-164 dropped copies leave their slots and stay owned")
	SpellEffects.end_concentration(d, [d])
	check.call(d.inventory.equipped_instance_id(Inventory.Slot.RING_1) == "" and SourceBenefitRules.total(d, "AC") == 0 and d_charm in d.inventory.owned_instances().map(func(c): return str(c.instance_id)), "041 S-164 reversion does not re-equip dropped copies")
	var legacy := Batch040Checks.caster("b041_legacy_form")
	var lr := Batch040Checks.shift(legacy, 2, "b040_hound")
	var bad_spell := DataLoader.get_spell(Batch040Checks.SHIFT).duplicate(true)
	var refused := ActorProjectionRules.apply(Batch040Checks.caster("b041_legacy_pick"), SpellEffects.begin_cast(legacy, bad_spell), bad_spell.effects[0], 2, bad_spell, "b040_hound", "merged")
	check.call(lr.projection.projected and lr.projection.get("equipment", {}).is_empty() and not legacy.spell_effects[str(lr.effect_cast.source_id)].projection.has("equipment") and not refused.projected, "041 S-164 projections without equipment policies keep 040 behavior and refuse a policy")

static func _equipment_saves(check: Callable) -> void:
	var a := wearer("b041_eq_save")
	var normal := a.get_ac()
	guise(a, "merged")
	var dto := a.to_dict()
	check.call(SpellEffectPersistence.saved_state_error(dto).is_empty(), "041 S-164 merged projection record validates")
	var back := Character.new()
	back.from_dict(dto)
	check.call(back.get_ac() == 12 and SourceBenefitRules.total(back, "AC") == 0, "041 S-164 reload keeps merged suppression (ac=%d)" % back.get_ac())
	SpellEffects.end_concentration(back, [back])
	SpellEffects.remove(back, str(dto.spell_concentration.effect_source))
	check.call(back.get_ac() == normal and SourceBenefitRules.total(back, "AC") == 2, "041 S-164 reverting after reload restores the merged effects")
	var src := str(dto.spell_concentration.effect_source)
	var defects := {
		"illegal policy": func(d): d.spell_effects[src].projection.equipment.policy = "stowed",
		"merged under worn": func(d): d.spell_effects[src].projection.equipment.policy = "worn",
		"missing record": func(d): d.spell_effects[src].projection.erase("equipment"),
		"dropped still worn": func(d):
			d.spell_effects[src].projection.equipment.policy = "dropped"
			d.spell_effects[src].projection.equipment.dropped = d.spell_effects[src].projection.equipment.merged.duplicate()
			d.spell_effects[src].projection.equipment.merged = [],
	}
	var refused := 0
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		if not SpellEffectPersistence.saved_state_error(bad).is_empty(): refused += 1
	check.call(refused == 4, "041 S-164 saved equipment refuses an illegal policy, contradicted merge, missing record and dropped copies still worn (%d/4)" % refused)
