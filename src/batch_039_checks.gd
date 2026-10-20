class_name Batch039Checks
extends RefCounted

const CONJURE := "fixture:b039_conjure"

static func load_fixtures() -> void:
	if not DataLoader.get_spell(CONJURE).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_039/spells/conjure.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_039/monsters/withering.json", "monster")

static func template() -> Dictionary:
	return DataLoader.get_spell(CONJURE).effects[0].template.duplicate(true)

static func wither_rule() -> Dictionary:
	return DataLoader.get_monster("fixture:b039_witherer").attacks[0].extra_effects[0].rule.duplicate(true)

static func caster(id: String) -> Character:
	var a := Batch031Checks._character(id, 40)
	a.spell_slots = {"1": 4, "2": 3, "3": 2, "4": 1}
	return a

## Resolve the real cast; the combat pipeline's concentration bookkeeping is mirrored.
static func conjure(owner: Character, slot: int) -> Dictionary:
	owner.spell_slots = {str(slot): 1}
	if not owner.concentrating_on.is_empty(): SpellEffects.end_concentration(owner, [owner])
	var r := SpellResolver.resolve(owner, owner, DataLoader.get_spell(CONJURE), true, {}, [], slot)
	var source := str(r.get("effect_cast", {}).get("source_id", ""))
	if r.get("success", false): owner.concentrating_on = {"spell_id": CONJURE, "effect_source": source, "targets": [owner]}
	return r

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "039 neutral created-actor spell and zero-limit creature load: %s" % str(DataLoader.get_load_errors()))
	_validation(check)
	_create(check)
	_lifetime(check)
	_created_saves(check)
	_zero_limit(check)
	_zero_saves(check)
	review_stress(check)

static func _validation(check: Callable) -> void:
	check.call(CreatedActorRules.template_error(template()).is_empty(), "039 S-154 declared template validates")
	var bad: Array = []
	for mutate in [
		func(t): t.creature_type = "robot",
		func(t): t.ability_scores.erase("CHA"),
		func(t): t.ac = {"base": 40},
		func(t): t.max_hp = {"base": 10, "per_level": 99},
		func(t): t.count = {"base": 2, "max": 1},
		func(t): t.attack.damage = "2d7",
		func(t): t["owner_level_hp"] = true,
	]:
		var t := template()
		mutate.call(t)
		if not CreatedActorRules.template_error(t).is_empty(): bad.append(t)
	check.call(bad.size() == 7, "039 S-154 loader refuses unknown type, missing score, out-of-range AC/HP, inverted count, illegal die and unknown field (%d/7)" % bad.size())
	var spell := DataLoader.get_spell(CONJURE).duplicate(true)
	spell.target = "single"
	check.call(not SharedSpell.content_error(spell).is_empty(), "039 S-154 created actors require a flat self-cast owner")

static func _create(check: Callable) -> void:
	var owner := caster("b039_owner")
	var r := conjure(owner, 2)
	var made: Dictionary = r.get("created_actors", {})
	var actors := CreatedActorRules.actors(owner)
	check.call(r.get("success", false) and made.get("count", 0) == 1 and actors.size() == 1 and int(owner.spell_slots["2"]) == 0, "039 S-154 real cast at base level creates one actor and pays its slot once")
	var w: Character = actors[0]
	check.call(w.base_ac == 13 and w.max_hp == 20 and w.current_hp == 20 and w.creature_type == "construct" and CreatedActorRules.owner_of(w) == owner.character_id, "039 S-154 base-level template values and retained owner identity")
	var ids: Array = w.features.map(func(f): return f.id)
	check.call(ids == ["b039_sturdy"] and made.excluded_features == ["b039_no_spawn", "b039_no_casting"], "039 S-154 forbidden creation/casting features are excluded and reported")
	var up := caster("b039_upcaster")
	r = conjure(up, 4)
	var many := CreatedActorRules.actors(up)
	check.call(r.created_actors.count == 3 and many.size() == 3 and many.all(func(a): return a.base_ac == 15 and a.max_hp == 40), "039 S-154 paid level above base scales AC, HP and capped count")
	var profile := CreatedActorRules.attack_profile(up, many[0])
	var dc := SpellPermissionRules.save_dc(up, DataLoader.get_spell(CONJURE))
	check.call(int(profile.attack_bonus_override) == dc - 8 and int(profile.save_dc) == dc and profile.damage == "1d8" and profile.damage_type == "force", "039 S-154 attack bonus and DC are owner-linked")
	up.ability_scores.from_dict({"STR": 16, "DEX": 14, "CON": 14, "INT": 20, "WIS": 12, "CHA": 10})
	check.call(int(CreatedActorRules.attack_profile(up, many[0]).save_dc) == SpellPermissionRules.save_dc(up, DataLoader.get_spell(CONJURE)), "039 S-154 owner-linked DC follows the live owner")
	check.call(JSON.stringify(DataLoader.get_spell(CONJURE).effects[0].template) == JSON.stringify(template()) and many[0].features.size() == 1, "039 S-154 catalog template is not mutated")
	many[1].current_hp = 7
	check.call(many[0].current_hp == 40 and many[1].max_hp == 40, "039 S-154 each actor's current HP is separate from its maximum and its siblings")

static func _lifetime(check: Callable) -> void:
	var owner := caster("b039_life")
	conjure(owner, 2)
	var source := str(owner.concentrating_on.get("effect_source", ""))
	check.call(not source.is_empty() and CreatedActorRules.actors(owner).size() == 1, "039 S-154 the actor is owned by the concentrating cast")
	SpellEffects.end_concentration(owner, [owner])
	check.call(CreatedActorRules.actors(owner).is_empty(), "039 S-154 ending the exact source ends its actor")
	conjure(owner, 2)
	var other := caster("b039_other")
	conjure(other, 2)
	SpellEffects.advance_time([owner, other], 60)
	check.call(CreatedActorRules.actors(owner).is_empty() and CreatedActorRules.actors(other).is_empty(), "039 S-154 expiry ends created actors without reviving or rebuilding")
	var a := caster("b039_two_a")
	var b := caster("b039_two_b")
	conjure(a, 2)
	conjure(b, 2)
	SpellEffects.end_concentration(a, [a])
	check.call(CreatedActorRules.actors(a).is_empty() and CreatedActorRules.actors(b).size() == 1, "039 S-154 one owner's source ending leaves another owner's equivalent actor")

static func _created_saves(check: Callable) -> void:
	var owner := caster("b039_save")
	conjure(owner, 3)
	var live := CreatedActorRules.actors(owner)
	live[0].current_hp = 11
	var dto := owner.to_dict()
	check.call(SpellEffectPersistence.saved_state_error(dto).is_empty(), "039 S-154 live created-actor record validates")
	var back := Character.new()
	back.from_dict(dto)
	CreatedActorRules._live.clear()
	var restored := CreatedActorRules.actors(back)
	check.call(restored.size() == 2 and restored[0].current_hp == 11 and restored[0].max_hp == 30 and restored[1].current_hp == 30 and restored[0].base_ac == 14, "039 S-154 reload rebuilds the same actors with saved current and derived maximum HP")
	var source := str(back.concentrating_on.get("effect_source", ""))
	var defects := {
		"overhealed": func(d): d.spell_effects[source].created_actors.actors[0].current_hp = 999,
		"extra actor": func(d): d.spell_effects[source].created_actors.actors.append({"actor_id": "%s:actor:3" % source, "current_hp": 5}),
		"renamed actor": func(d): d.spell_effects[source].created_actors.actors[0].actor_id = "elsewhere",
		"foreign caster": func(d): d.spell_effects[source].caster_id = "someone",
		"level": func(d): d.spell_effects[source].created_actors.level = 12,
	}
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		check.call(not SpellEffectPersistence.saved_state_error(bad).is_empty(), "039 S-154 saved created actors refuse %s" % label)

static func _zero_limit(check: Callable) -> void:
	var rule := wither_rule()
	check.call(MaxHpSourceRules.validate_rule(rule).is_empty(), "039 S-131 zero-limit rule validates")
	var bad_floor := rule.duplicate(true); bad_floor["floor"] = 1
	var bad_kind := rule.duplicate(true); bad_kind.kind = "increase"
	var bad_remains := rule.duplicate(true); bad_remains.zero_limit.remains = "destroyed"
	check.call([bad_floor, bad_kind, bad_remains].all(func(r): return not MaxHpSourceRules.validate_rule(r).is_empty()), "039 S-131 zero limit refuses floors, increases and undeclared remains")
	var a := Batch031Checks._character("b039_wither", 20)
	MaxHpSourceRules.apply(a, rule, "shade:b039:wither", 12)
	check.call(a.max_hp == 8 and a.current_hp == 8 and a.is_alive, "039 S-131 partial zero-limit reduction is ordinary")
	var r := MaxHpSourceRules.apply(a, rule, "shade:b039:wither", 8)
	check.call(r.zero_limit_death and a.max_hp == 0 and not a.is_alive and a.corpse_state.remains == "dust" and a.corpse_state.cause == "withered" and a.corpse_state.cause_source.source_instance_id == "shade:b039:wither", "039 S-131 reaching zero maximum is death with the source's remains and cause")
	check.call(not a.is_downed() and a.death_save_successes == 0 and a.heal(10) == 0 and a.current_hp == 0, "039 S-131 zero-maximum death is not current-HP zero: no downed state and no healing")
	check.call(not CorpseRules.target_error(a, "revivify", int(GameManager.campaign_elapsed_seconds)).is_empty(), "039 S-131 revival is refused while the maximum is 0")
	var b := Batch031Checks._character("b039_floor", 20)
	var floored := Batch035Checks.drain_rule()
	MaxHpSourceRules.apply(b, floored, "drainer:b035:hollow", 50)
	check.call(b.max_hp == 1 and b.is_alive, "039 S-131 ordinary reductions still stop at the floor")
	MaxHpSourceRules.apply(b, rule, "shade:b039:wither", 5)
	check.call(b.max_hp == 0 and not b.is_alive, "039 S-131 a zero-limit source can take the last point another source left")
	MaxHpSourceRules.remove(b, "shade:b039:wither")
	check.call(b.max_hp == 1 and not b.is_alive and b.current_hp == 0, "039 S-131 removing the source restores the maximum but does not revive")
	var c := Batch031Checks._character("b039_c", 10)
	c.current_hp = 0
	c.death_save_failures = 0
	MaxHpSourceRules.apply(c, wither_rule(), "shade:b039:wither", 3)
	check.call(c.max_hp == 7 and c.corpse_state.is_empty() and c.death_save_failures == 0, "039 S-131 a downed creature whose maximum stays above zero is not killed by the rule")

static func _zero_saves(check: Callable) -> void:
	var a := Batch031Checks._character("b039_zs", 10)
	MaxHpSourceRules.apply(a, wither_rule(), "shade:b039:wither", 10)
	var dto := a.to_dict()
	check.call(MaxHpSourceRules.saved_error(dto).is_empty() and CorpseRules.saved_error(dto).is_empty(), "039 S-131 zero-maximum death saves validly")
	var back := Character.new()
	back.from_dict(dto)
	check.call(back.max_hp == 0 and not back.is_alive and back.corpse_state.remains == "dust" and back.max_hp_sources.has("shade:b039:wither"), "039 S-131 reload keeps the zero maximum, death and source")
	var alive := dto.duplicate(true); alive.is_alive = true; alive.corpse_state = {}
	var sourceless := dto.duplicate(true); sourceless.max_hp_sources = {}
	var floored := dto.duplicate(true); floored.max_hp_sources["shade:b039:wither"].floor = 1
	check.call([alive, sourceless, floored].all(func(d): return not MaxHpSourceRules.saved_error(d).is_empty()), "039 S-131 saved zero maximum refuses a living, sourceless or floored record")
	var legacy := Batch031Checks._character("b039_legacy", 20)
	MaxHpSourceRules.apply(legacy, Batch035Checks.drain_rule(), "x:b035:hollow", 4)
	var ldto := legacy.to_dict()
	check.call(MaxHpSourceRules.saved_error(ldto).is_empty() and not ldto.max_hp_sources["x:b035:hollow"].has("zero_limit"), "039 legacy max-HP sources without zero_limit still validate")

## Runtime Reviewer stress (RX1-RX7).
static func review_stress(check: Callable) -> void:
	# RX1: a reload is a new owner object with the same id; the saved record, not a stale cache, decides HP.
	var a := caster("b039_rx1")
	conjure(a, 2)
	var w: Character = CreatedActorRules.actors(a)[0]
	w.take_damage(5)
	var dto := a.to_dict()
	var saved_hp := w.current_hp
	w.take_damage(7)
	var back := Character.new()
	back.from_dict(dto)
	var bw: Array = CreatedActorRules.actors(back)
	check.call(bw.size() == 1 and bw[0] != w and bw[0].current_hp == saved_hp, "039 RX1 reload rebuilds the created actor from the saved record, not the pre-load cache (saved=%d got=%s)" % [saved_hp, str(bw.map(func(x): return x.current_hp))])
	# RX2: a created actor killed after the save comes back alive on reload.
	w.take_damage(999)
	var back2 := Character.new()
	back2.from_dict(dto)
	var bw2: Array = CreatedActorRules.actors(back2)
	check.call(bw2.size() == 1 and bw2[0].is_alive and bw2[0].current_hp == saved_hp, "039 RX2 reload restores a created actor that died after the save")
	# RX3: the reloaded owner owns the rebuilt actor; the old owner object no longer drives it.
	check.call(not bw2.is_empty() and CreatedActorRules.owner_of(bw2[0]) == a.character_id, "039 RX3 rebuilt actor stays linked to the owner id")
	# RX4: the same owner object keeps its live actor (party dismiss/recruit keeps the object).
	var c := caster("b039_rx4")
	conjure(c, 2)
	var cw: Character = CreatedActorRules.actors(c)[0]
	cw.take_damage(3)
	check.call(CreatedActorRules.actors(c)[0] == cw and cw.current_hp == cw.max_hp - 3, "039 RX4 same owner object keeps its live actor and HP")
	# RX5: ending concentration through the real end path removes record and actors; a recast is fresh.
	SpellEffects.end_concentration(c, [c])
	check.call(CreatedActorRules.actors(c).is_empty() and c.concentrating_on.is_empty() and not c.spell_effects.values().any(func(r): return r.has("created_actors")), "039 RX5 real concentration end removes the record and its actors")
	conjure(c, 3)
	var fresh: Array = CreatedActorRules.actors(c)
	check.call(fresh.size() == 2 and fresh.all(func(x): return x.current_hp == x.max_hp and x.max_hp == 30), "039 RX5 recast at a higher slot creates fresh full-HP actors (count 2, max 30)")
	# RX6: S-131 on a created actor (a Character): zero maximum is death, not downed.
	var z: Character = fresh[0]
	var r := MaxHpSourceRules.apply(z, wither_rule(), "shade:b039:rx6", 30)
	check.call(r.zero_limit_death and z.max_hp == 0 and not z.is_alive and not z.is_downed(), "039 RX6 zero-limit on a created actor kills it")
	# RX7: S-131 with S-130 fixed re-derivation: increase + zero-limit, removed in either order, no drift.
	for order in [0, 1]:
		var d := Batch031Checks._character("b039_rx7_%d" % order, 20)
		var inc := {"id": "b035:bolster", "kind": "increase", "amount": 5, "raise_current": true}
		MaxHpSourceRules.apply(d, inc, "x:inc")
		MaxHpSourceRules.apply(d, wither_rule(), "shade:b039:rx7", 10)
		var mid := d.max_hp
		var first := "x:inc" if order == 0 else "shade:b039:rx7"
		var second := "shade:b039:rx7" if order == 0 else "x:inc"
		MaxHpSourceRules.remove(d, first)
		var after_first := d.max_hp
		MaxHpSourceRules.remove(d, second)
		check.call(mid == 15 and after_first == (10 if order == 0 else 25) and d.max_hp == 20 and d.is_alive, "039 RX7 increase plus zero-limit removal order %d returns to 20 without drift (mid=%d first=%d end=%d)" % [order, mid, after_first, d.max_hp])
	# RX7b: floor-clamped ordinary drain then zero-limit; removing the drain lets the zero-limit apply in full.
	var f := Batch031Checks._character("b039_rx7b", 20)
	MaxHpSourceRules.apply(f, Batch035Checks.drain_rule(), "x:b035:hollow", 50)
	MaxHpSourceRules.apply(f, wither_rule(), "shade:b039:rx7b", 4)
	check.call(f.max_hp == 0 and not f.is_alive, "039 RX7b zero-limit after a floor-clamped drain reaches 0")
	MaxHpSourceRules.remove(f, "x:b035:hollow")
	check.call(f.max_hp == 16 and not f.is_alive, "039 RX7b removing the clamped drain re-derives to 20-4 and does not revive (max=%d)" % f.max_hp)
