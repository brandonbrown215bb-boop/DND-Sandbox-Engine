class_name Batch071Checks
extends RefCounted
## Batch 071 (S-130/S-131): maximum-HP sources on monster combatant records —
## overlapping sources, removal order, clamps and zero-maximum consequences.

const WITHER := "fixture:b071_wither"
const SAP := "fixture:b071_sap"
const VIGOR := "fixture:b071_vigor"

static func load_fixtures() -> void:
	if not DataLoader.get_spell(WITHER).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_071/spells/max_hp.json", "spell")

static func monster(id: String, hp: int) -> Dictionary:
	return {"id": id, "name": "Husk %s" % id, "monster_id": "fixture:b071_husk", "creature_type": "humanoid", "hex_position": Vector2i(1, 0), "is_alive": true, "current_hp": hp, "max_hp": hp, "temp_hp": 0, "armor_class": 10, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_immunities": [], "damage_resistances": [], "saving_throw_bonuses": {}, "spell_slots": {}}

static func caster(id: String) -> Character:
	var a := Batch031Checks._character(id, 40)
	a.spell_slots = {"1": 4}
	return a

## The real resolver; concentration bookkeeping mirrors the combat pipeline.
static func cast(owner: Character, target, spell_id: String) -> Dictionary:
	if not owner.concentrating_on.is_empty(): SpellEffects.end_concentration(owner, [target])
	var spell := DataLoader.get_spell(spell_id)
	var r := SpellResolver.resolve(owner, target, spell, true, {}, [], 1)
	var source := str(r.get("effect_cast", {}).get("source_id", ""))
	if r.get("success", false) and bool(spell.get("concentration", false)): owner.concentrating_on = {"spell_id": spell_id, "effect_source": source, "targets": [target]}
	r["_source"] = source
	return r

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "071 neutral maximum-HP spell fixtures load: %s" % str(DataLoader.get_load_errors()))
	_validation(check)
	_overlap(check)
	_zero(check)
	_character_saves(check)
	_legacy(check)
	_review_stress(check)

static func _validation(check: Callable) -> void:
	var good: Dictionary = DataLoader.get_spell(WITHER).duplicate(true)
	check.call(SharedSpell.content_error(good).is_empty(), "071 the max_hp_source shared effect validates")
	var bad: Array = []
	for mutate in [
		func(s): s.effects[0].rule.combine = "stack",
		func(s): s.effects[0].rule.amount = "damage_dealt",
		func(s): s.effects[0]["extra"] = 1,
		func(s): s.effects[0].erase("rule"),
		func(s): s.effects[0].rule["surprise"] = true,
	]:
		var s := good.duplicate(true)
		mutate.call(s)
		if not SharedSpell.content_error(s).is_empty(): bad.append(s)
	check.call(bad.size() == 5, "071 loader refuses unknown combine, damage_dealt on a spell, extra effect fields, a missing rule and unknown rule fields (%d/5)" % bad.size())

static func _overlap(check: Callable) -> void:
	var m := monster("b071_m1", 20)
	var a := caster("b071_a")
	var b := caster("b071_b")
	var c := caster("b071_c")
	var ra := cast(a, m, WITHER)
	check.call(ra.get("success", false) and int(m.max_hp) == 14 and int(m.current_hp) == 14 and int(a.spell_slots["1"]) == 3, "071 real cast on a monster record: max 20 -> 14, current clamped to 14, slot paid once")
	var rb := cast(b, m, WITHER)
	check.call(rb.get("success", false) and int(m.max_hp) == 14 and MaxHpSourceRules.sources(m).size() == 2, "071 a second caster's same-named spell does not combine: max stays 14 with two owned sources")
	var rc := cast(c, m, SAP)
	check.call(rc.get("success", false) and int(m.max_hp) == 10 and int(m.current_hp) == 10, "071 a differently named spell adds: max 10")
	m.current_hp = 9
	SpellEffects.end_concentration(a, [m])
	check.call(int(m.max_hp) == 10 and int(m.current_hp) == 9 and not MaxHpSourceRules.sources(m).has(ra._source), "071 ending the first caster's source leaves the equivalent source in force (max 10)")
	SpellEffects.end_concentration(c, [m])
	check.call(int(m.max_hp) == 14 and int(m.current_hp) == 9, "071 removing the differently named source restores only its 4; current HP is not raised")
	SpellEffects.end_concentration(b, [m])
	check.call(int(m.max_hp) == 20 and int(m.current_hp) == 9 and MaxHpSourceRules.sources(m).is_empty() and SpellEffects.records(m).is_empty(), "071 last removal restores the natural maximum 20; no records remain")
	# Opposite removal order reaches the same values.
	var m2 := monster("b071_m2", 20)
	cast(a, m2, WITHER); cast(b, m2, WITHER); cast(c, m2, SAP)
	SpellEffects.end_concentration(c, [m2])
	var mid := int(m2.max_hp)
	SpellEffects.end_concentration(b, [m2])
	var mid2 := int(m2.max_hp)
	SpellEffects.end_concentration(a, [m2])
	check.call(mid == 14 and mid2 == 14 and int(m2.max_hp) == 20, "071 reverse removal order: 14, 14, 20 (%d/%d/%d)" % [mid, mid2, int(m2.max_hp)])
	# A real encounter record may carry no spell_effects key yet.
	var bare := monster("b071_bare", 20)
	bare.erase("spell_effects")
	var rbare := cast(c, bare, SAP)
	var linked: bool = SpellEffects.records(bare).get(rbare._source, {}).get("max_hp_source", "") == "b071:sap"
	SpellEffects.end_concentration(c, [bare])
	check.call(linked and int(bare.max_hp) == 20, "071 a record with no spell_effects key still gets the link, and concentration end restores it")
	# Encounter end removes every monster source.
	var m3 := monster("b071_m3", 20)
	cast(a, m3, SAP)
	SpellEffects.finish_encounter([a], [m3])
	check.call(int(m3.max_hp) == 20 and MaxHpSourceRules.sources(m3).is_empty(), "071 encounter end removes the monster's cast-owned source")
	# Aura-protected record refuses a reduction without changing anything.
	var m4 := monster("b071_m4", 20)
	m4["aura_of_life_sources"] = ["aura"]
	var r4 := MaxHpSourceRules.apply(m4, DataLoader.get_spell(SAP).effects[0].rule, "x")
	check.call(not r4.applied and r4.reason == "maximum_protected" and int(m4.max_hp) == 20, "071 a protected record refuses the reduction")

static func _zero(check: Callable) -> void:
	var a := caster("b071_za")
	var c := caster("b071_zc")
	var m := monster("b071_z1", 8)
	cast(c, m, SAP)
	check.call(int(m.max_hp) == 4 and bool(m.is_alive), "071 floor-1 reduction first: max 8 -> 4")
	var r := cast(a, m, WITHER)
	var receipt: Dictionary = r.get("max_hp_source", {})
	check.call(bool(receipt.get("zero_limit_death", false)) and int(m.max_hp) == 0 and int(m.current_hp) == 0 and not bool(m.is_alive), "071 the zero-limit source takes the remaining maximum to 0: the monster dies")
	var after: Dictionary = m.get("zero_hp_aftermath", {})
	check.call(after.get("outcome", "") == "death" and after.get("remains", "") == "dust" and after.get("cause", "") == "withered" and after.get("cause_source", {}).get("source_instance_id", "") == r._source, "071 zero-maximum death records the source's declared remains and cause once")
	var snapshot := JSON.stringify(after)
	var again := MaxHpSourceRules.apply(m, DataLoader.get_spell(WITHER).effects[0].rule, "another", 6)
	check.call(not again.applied and again.reason == "target_dead" and JSON.stringify(m.zero_hp_aftermath) == snapshot, "071 a dead record refuses another source: no duplicate death or remains")
	SpellEffects.end_concentration(c, [m])
	SpellEffects.finish_encounter([a, c], [m])
	check.call(not bool(m.is_alive) and int(m.current_hp) == 0 and JSON.stringify(m.zero_hp_aftermath) == snapshot, "071 ending the other sources never revives the zero-maximum body")
	# Already at 0 HP from damage: refused, no second aftermath.
	var dead := monster("b071_z2", 10)
	dead.current_hp = 0
	dead.is_alive = false
	var slots := int(a.spell_slots["1"])
	var rd := cast(a, dead, WITHER)
	check.call(rd.get("refused", false) and int(a.spell_slots["1"]) == slots and not dead.has("zero_hp_aftermath") and int(dead.max_hp) == 10, "071 a cast at an already-dead monster is refused before paying: no slot, source or remains (slots %d->%d)" % [slots, int(a.spell_slots["1"])])
	# Direct single source to zero.
	var m5 := monster("b071_z3", 6)
	var r5 := cast(a, m5, WITHER)
	check.call(bool(r5.get("max_hp_source", {}).get("zero_limit_death", false)) and not bool(m5.is_alive) and int(m5.max_hp) == 0, "071 a 6-HP-maximum monster dies from a 6-point zero-limit source")

static func _character_saves(check: Callable) -> void:
	var a := caster("b071_sa")
	var b := caster("b071_sb")
	var ally := caster("b071_ally")
	var base := ally.max_hp
	var r1 := cast(a, ally, VIGOR)
	var r2 := cast(b, ally, VIGOR)
	check.call(r1.get("success", false) and r2.get("success", false) and ally.max_hp == base + 5 and ally.current_hp == base + 5 and ally.max_hp_sources.size() == 2, "071 two same-named increases on a character apply once (+5), current raised once")
	var dto := ally.to_dict()
	check.call(MaxHpSourceRules.saved_error(dto).is_empty() and SpellEffectPersistence.saved_state_error(dto).is_empty(), "071 saved character with linked sources validates")
	var back := Character.new()
	back.from_dict(dto)
	check.call(back.max_hp == base + 5 and back.max_hp_sources.size() == 2 and SpellEffects.records(back).has(r1._source), "071 reload keeps the sources and their spell links")
	SpellEffects.remove(back, r1._source, "expired")
	check.call(back.max_hp == base + 5, "071 after reload, ending one cast leaves the other +5")
	SpellEffects.remove(back, r2._source, "expired")
	check.call(back.max_hp == base and back.current_hp == base, "071 after reload, ending both restores the base maximum and clamps current")
	var forged := dto.duplicate(true)
	forged.spell_effects[r1._source].max_hp_source = "b071:other"
	var orphan := dto.duplicate(true)
	orphan.max_hp_sources.erase(r1._source)
	orphan.max_hp = int(orphan.max_hp)
	var combine := dto.duplicate(true)
	combine.max_hp_sources[r1._source].combine = "stack"
	check.call(not SpellEffectPersistence.saved_state_error(forged).is_empty() and not SpellEffectPersistence.saved_state_error(orphan).is_empty() and not MaxHpSourceRules.saved_error(combine).is_empty(), "071 saved links refuse a forged rule, an orphan link and an unknown combine")

static func _legacy(check: Callable) -> void:
	var c := Batch031Checks._character("b071_legacy", 20)
	var rule := {"id": "legacy", "kind": "reduction", "amount": 3}
	MaxHpSourceRules.apply(c, rule, "one")
	MaxHpSourceRules.apply(c, rule, "two")
	check.call(c.max_hp == 14 and MaxHpSourceRules.saved_error(c.to_dict()).is_empty(), "071 legacy rules without combine still sum (20 -> 14) and save")

## Review 071 stress: highest-wins order, weaker resumes, ties, zero-max death once, legacy sum.
static func _review_stress(check: Callable) -> void:
	var m := monster("rs", 20)
	m.temp_hp = 5
	var weak := {"id": "rv:sap", "kind": "reduction", "amount": 4, "combine": "highest"}
	var strong := {"id": "rv:sap", "kind": "reduction", "amount": 9, "combine": "highest"}
	MaxHpSourceRules.apply(m, weak, "a")
	MaxHpSourceRules.apply(m, strong, "b")
	check.call(m.max_hp == 11, "R071 weaker-then-stronger same-name: strongest applies (%d)" % m.max_hp)
	MaxHpSourceRules.remove(m, "b")
	check.call(m.max_hp == 16 and m.current_hp == 11, "R071 stronger ends: weaker resumes, HP not raised (%d/%d)" % [m.current_hp, m.max_hp])
	MaxHpSourceRules.remove(m, "a")
	check.call(m.max_hp == 20 and m.current_hp == 11 and MaxHpSourceRules.saved_error(m).is_empty(), "R071 all end: natural max, current unchanged")
	var t := monster("rt", 10)
	MaxHpSourceRules.apply(t, {"id": "rv:h", "kind": "reduction", "amount": 5, "combine": "highest"}, "1")
	MaxHpSourceRules.apply(t, {"id": "rv:h", "kind": "reduction", "amount": 5, "combine": "highest"}, "2")
	check.call(t.max_hp == 5, "R071 tie does not stack (%d)" % t.max_hp)
	MaxHpSourceRules.remove(t, "1")
	check.call(t.max_hp == 5 and MaxHpSourceRules.saved_error(t).is_empty(), "R071 tie: first removed, second takes over (%d)" % t.max_hp)
	var n := monster("rn", 10)
	MaxHpSourceRules.apply(n, {"id": "rv:sum", "kind": "reduction", "amount": 3}, "1")
	MaxHpSourceRules.apply(n, {"id": "rv:sum", "kind": "reduction", "amount": 3}, "2")
	check.call(n.max_hp == 4, "R071 absent combine stays legacy sum (%d)" % n.max_hp)
	var z := {"id": "rv:w", "kind": "reduction", "amount": 30, "combine": "highest", "zero_limit": {"cause": "withered", "remains": "dust"}}
	var d := monster("rz", 20)
	d.temp_hp = 7
	var r1 := MaxHpSourceRules.apply(d, z, "c")
	var r2 := MaxHpSourceRules.apply(d, z, "d")
	check.call(bool(r1.zero_limit_death) and d.max_hp == 0 and not d.is_alive and d.temp_hp == 0 and d.zero_hp_aftermath.remains == "dust" and str(r2.get("reason", "")) == "target_dead", "R071 zero max with temp HP kills once, dust, second refused")
