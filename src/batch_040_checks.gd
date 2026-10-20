class_name Batch040Checks
extends RefCounted

const REAP := "fixture:b040_reap"
const SHIFT := "fixture:b040_shift"
const MANTLE := "fixture:b040_mantle"

static func load_fixtures() -> void:
	if not DataLoader.get_spell(REAP).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_040/spells/reap.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_040/spells/form.json", "spell")

static func policy() -> Dictionary:
	return DataLoader.get_spell(REAP).zero_hp_aftermath.duplicate(true)

static func caster(id: String) -> Character:
	var a := Batch031Checks._character(id, 40)
	a.spell_slots = {"1": 4, "2": 3, "3": 2}
	return a

static func reap(source: Character, target) -> Dictionary:
	source.spell_slots = {"1": 1}
	return SpellResolver.resolve(source, target, DataLoader.get_spell(REAP), true, {}, [], 1)

## Resolve the real self-cast; the combat pipeline's concentration bookkeeping is mirrored.
static func shift(actor: Character, slot: int, form_id: String = "", spell_id: String = SHIFT) -> Dictionary:
	actor.spell_slots = {str(slot): 1}
	if not actor.concentrating_on.is_empty(): SpellEffects.end_concentration(actor, [actor])
	var spell := DataLoader.get_spell(spell_id).duplicate(true)
	if not form_id.is_empty(): spell["_projection_form_id"] = form_id
	var r := SpellResolver.resolve(actor, actor, spell, true, {}, [], slot)
	var source := str(r.get("effect_cast", {}).get("source_id", ""))
	if r.get("projection", {}).get("projected", false): actor.concentrating_on = {"spell_id": spell_id, "effect_source": source, "targets": [actor]}
	return r

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "040 neutral successor and projection spells load: %s" % str(DataLoader.get_load_errors()))
	_successor_validation(check)
	_successor(check)
	_successor_saves(check)
	_projection_validation(check)
	_projection(check)
	_projection_saves(check)
	review_stress(check)

static func _successor_validation(check: Callable) -> void:
	check.call(ZeroHpAftermathRules.validate_policy(policy()).is_empty(), "040 S-120 declared successor policy validates")
	var bad: Array = []
	for mutate in [
		func(p): p.successor.template.creature_type = "robot",
		func(p): p.successor["follows_killer"] = true,
		func(p): p.successor.side = "anyone",
		func(p): p.successor.erase("attack_bonus"),
		func(p): p.successor = "husk",
	]:
		var p := policy()
		mutate.call(p)
		if not ZeroHpAftermathRules.validate_policy(p).is_empty(): bad.append(p)
	check.call(bad.size() == 5, "040 S-120 loader refuses a bad template, unknown field, side, missing attack bonus and non-object successor (%d/5)" % bad.size())

static func _successor(check: Callable) -> void:
	var src := caster("b040_reaper")
	var a := Batch031Checks._character("b040_fallen", 20)
	var r := reap(src, a)
	var made: Dictionary = a.corpse_state.get("successor", {})
	var husks := AftermathSuccessorRules.actors(a)
	check.call(r.get("success", false) and a.is_dead() and a.corpse_state.remains == "bones" and husks.size() == 1 and made.get("owner_id", "") == src.character_id and made.get("carrier", "") == "spell:" + REAP, "040 S-120 actual final death creates one declared successor for the source (corpse=%s)" % str(a.corpse_state))
	var h: Character = husks[0]
	check.call(h.base_ac == 11 and h.max_hp == 15 and h.current_hp == 15 and h.get_creature_type() == "undead" and h.character_id == "%s:successor:1" % a.corpse_state.corpse_id, "040 S-120 successor takes the template values and an identity tied to this death")
	var receipt: Dictionary = CombatAction.resolve_damage(Batch031Checks._character("b040_receipt", 20), 30, "necrotic", {"zero_hp_aftermath": policy(), "zero_hp_aftermath_carrier": "spell:" + REAP}).get("zero_hp_aftermath", {}).get("successor", {})
	check.call(h.features.map(func(f): return f.id) == ["b040_grave_sense"] and receipt.get("created", false) and receipt.get("excluded_features", []) == ["b040_no_spawn"] and a.character_id == "b040_fallen", "040 S-120 forbidden creation features are excluded; the dead creature keeps its identity")
	var again := AftermathSuccessorRules.settle(a, policy(), {"zero_hp_aftermath_carrier": "spell:" + REAP}, src.character_id)
	reap(src, a)
	check.call(not again.get("created", true) and AftermathSuccessorRules.actors(a).size() == 1, "040 S-120 the successor is created once per death")
	var b := Batch031Checks._character("b040_uncarried", 20)
	var plain := CombatAction.resolve_damage(b, 30, "necrotic", {"zero_hp_aftermath": policy()})
	check.call(b.is_dead() and not plain.zero_hp_aftermath.successor.created and AftermathSuccessorRules.actors(b).is_empty(), "040 S-120 a policy without a stable carrier is refused, not improvised")
	var c := Batch031Checks._character("b040_construct", 20)
	c.creature_type = "construct"
	reap(src, c)
	var d := Batch031Checks._character("b040_survivor", 50)
	reap(src, d)
	check.call(AftermathSuccessorRules.actors(c).is_empty() and AftermathSuccessorRules.actors(d).is_empty() and d.current_hp == 20 and c.corpse_state.get("successor", {}).is_empty(), "040 S-120 excluded types and non-final damage create no successor")
	var now := int(GameManager.campaign_elapsed_seconds)
	check.call(CorpseRules.target_error(a, "revivify", now) == "These remains have risen as a successor.", "040 S-120 revival is refused while the successor stands")
	h.current_hp = 0
	h.is_alive = false
	check.call(CorpseRules.target_error(a, "revivify", now) != "These remains have risen as a successor." and AftermathSuccessorRules.actors(a).size() == 1 and int(a.corpse_state.successor.actors[0].current_hp) == 0, "040 S-120 a destroyed successor is recorded, not rebuilt or replaced")
	var monster := {"id": "b040_beast", "name": "Beast", "current_hp": 10, "max_hp": 10, "is_alive": true, "creature_type": "beast"}
	reap(src, monster)
	check.call(not monster.is_alive and AftermathSuccessorRules.actors(monster).size() == 1 and monster.zero_hp_aftermath.successor.corpse_id == "creature:b040_beast", "040 S-120 a creature record's final death also creates its successor once")
	var profile := AftermathSuccessorRules.attack_profile(AftermathSuccessorRules.actors(monster)[0])
	check.call(int(profile.attack_bonus_override) == 3 and profile.damage == "1d6" and profile.damage_type == "slashing", "040 S-120 successor attack reads the declared policy")

static func _successor_saves(check: Callable) -> void:
	var src := caster("b040_save_src")
	var a := Batch031Checks._character("b040_save_dead", 20)
	reap(src, a)
	AftermathSuccessorRules.actors(a)[0].current_hp = 6
	var dto := a.to_dict()
	check.call(CorpseRules.saved_error(dto).is_empty(), "040 S-120 dead creature with its successor validates")
	var back := Character.new()
	back.from_dict(dto)
	var restored := AftermathSuccessorRules.actors(back)
	check.call(restored.size() == 1 and restored[0].current_hp == 6 and restored[0].max_hp == 15 and restored[0].character_id == AftermathSuccessorRules.actors(a)[0].character_id, "040 S-120 reload rebuilds the same successor with its current HP")
	var defects := {
		"extra successor": func(d): d.corpse_state.successor.actors.append({"actor_id": "x", "current_hp": 1}),
		"overhealed": func(d): d.corpse_state.successor.actors[0].current_hp = 99,
		"foreign carrier": func(d): d.corpse_state.successor.carrier = "spell:fixture:b034_dust",
		"other death": func(d): d.corpse_state.successor.corpse_id = "corpse:else:1",
		"self owner": func(d): d.corpse_state.successor.owner_id = d.character_id,
	}
	var refused := 0
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		if not CorpseRules.saved_error(bad).is_empty(): refused += 1
	check.call(refused == 5, "040 S-120 saved successor refuses extra, overhealed, foreign-carrier, other-death and self-owned records (%d/5)" % refused)
	var legacy := dto.duplicate(true)
	legacy.corpse_state.erase("successor")
	check.call(CorpseRules.saved_error(legacy).is_empty(), "040 legacy corpses without a successor still validate")

static func _effect(spell_id: String = SHIFT) -> Dictionary:
	return DataLoader.get_spell(spell_id).effects[0].duplicate(true)

static func _projection_validation(check: Callable) -> void:
	check.call(ActorProjectionRules.effect_error(_effect()).is_empty() and ActorProjectionRules.effect_error(_effect(MANTLE)).is_empty(), "040 S-163 declared projections validate")
	var bad := 0
	for mutate in [
		func(e): e.retain.erase("hp"),
		func(e): e.retain.append("everything"),
		func(e): e.forms[1].id = e.forms[0].id,
		func(e): e.forms[0].attack.erase("bonus"),
		func(e): e.forms[0]["hp"] = 50,
		func(e): e.forms = [],
	]:
		var e := _effect()
		mutate.call(e)
		if not ActorProjectionRules.effect_error(e).is_empty(): bad += 1
	check.call(bad == 6, "040 S-163 loader refuses dropped HP retention, unknown retention, duplicate forms, attack without bonus, a replacement HP pool and no forms (%d/6)" % bad)
	var spell := DataLoader.get_spell(SHIFT).duplicate(true)
	spell.target = "single"
	check.call(not SharedSpell.content_error(spell).is_empty(), "040 S-163 projections require a flat self-cast actor")

static func _projection(check: Callable) -> void:
	var a := caster("b040_shifter")
	a.current_hp = 33
	var features_before := a.features.size()
	var uses_before := a.feature_uses.duplicate(true)
	var speed_before := a.speed
	var before := a.ability_scores.to_dict()
	var r := shift(a, 2, "b040_hound")
	var p: Dictionary = r.get("projection", {})
	check.call(p.get("projected", false) and a.ability_scores.get_score("STR") == 16 and a.ability_scores.get_score("DEX") == 15 and a.ability_scores.get_score("INT") == int(before.INT) and a.ability_scores.get_score("CHA") == int(before.CHA) and a.speed == 8 and int(a.spell_slots["2"]) == 0, "040 S-163 actual cast sets the form's physical scores and speed and keeps the declared mental scores (p=%s msg=%s scores=%s speed=%d slots=%s)" % [str(p), str(r.get("message", "")), str(a.ability_scores.to_dict()), a.speed, str(a.spell_slots)])
	check.call(a.get_ac() == 13 and a.temp_hp == 10 and a.current_hp == 33 and a.max_hp == 40 and a.get_creature_type() == "humanoid" and a.get_creature_size() == "medium", "040 S-163 form AC and Temporary HP apply; own HP and retained type stay")
	check.call(features_before > 0 and a.features.is_empty() and not ActorProjectionRules.can_cast_spells(a), "040 S-163 unretained features and spellcasting are suppressed")
	var at := ActorProjectionRules.attack_profile(a)
	check.call(int(at.attack_bonus_override) == 5 and at.damage == "2d4", "040 S-163 the form's attack profile is exposed")
	var again := ActorProjectionRules.apply(a, SpellEffects.begin_cast(a, DataLoader.get_spell(MANTLE)), _effect(MANTLE), 3, DataLoader.get_spell(MANTLE), "")
	check.call(not again.projected and ActorProjectionRules.active(a).form.id == "b040_hound", "040 S-163 a second projection is refused while one is active")
	a.take_damage(14)
	check.call(a.temp_hp == 0 and a.current_hp == 29, "040 S-163 damage spends form Temporary HP before the actor's own HP")
	SpellEffects.end_concentration(a, [a])
	check.call(not ActorProjectionRules.is_projected(a) and a.ability_scores.to_dict() == before and a.speed == speed_before and a.features.size() == features_before, "040 S-163 concentration end reverts scores, speed and features")
	check.call(a.current_hp == 29 and a.max_hp == 40 and a.feature_uses == uses_before and a.features.map(func(f): return f.id).size() == _unique_ids(a.features), "040 S-163 reversion keeps the same HP and resources without refilling or duplicating features")
	var up := caster("b040_up")
	shift(up, 3, "b040_hound")
	check.call(up.get_ac() == 14 and up.temp_hp == 15, "040 S-163 paid level above base scales the form's AC and Temporary HP")
	var big := caster("b040_big")
	shift(big, 2, "b040_bulwark")
	var none := caster("b040_none")
	var refused := shift(none, 2)
	check.call(big.get_creature_size() == "large" and big.get_ac() == 17 and not refused.get("success", true) and int(none.spell_slots.get("2", 0)) == 1 and not ActorProjectionRules.is_projected(none), "040 S-163 the selected form applies; no selection among several forms is refused")
	var m := caster("b040_mantled")
	var mf := m.features.size()
	var m_int := m.ability_scores.get_score("INT")
	shift(m, 3, "", MANTLE)
	check.call(m.get_creature_type() == "fey" and m.ability_scores.get_score("INT") == 9 and m.features.size() == mf and ActorProjectionRules.can_cast_spells(m) and m.get_creature_size() == "small", "040 S-163 a form that does not retain type and mind replaces them while retained features and casting stay")
	SpellEffects.advance_time([m], 600)
	check.call(not ActorProjectionRules.is_projected(m) and m.get_creature_type() == "humanoid" and m.ability_scores.get_score("INT") == m_int, "040 S-163 expiry reverts the projection")

static func _unique_ids(features: Array) -> int:
	var seen := {}
	for f in features: seen[str(f.get("id", ""))] = true
	return seen.size()

static func _projection_saves(check: Callable) -> void:
	var a := caster("b040_proj_save")
	var features_before := a.features.size()
	var before := a.ability_scores.to_dict()
	shift(a, 2, "b040_hound")
	var dto := a.to_dict()
	check.call(SpellEffectPersistence.saved_state_error(dto).is_empty(), "040 S-163 live projection record validates")
	var back := Character.new()
	back.from_dict(dto)
	check.call(ActorProjectionRules.is_projected(back) and back.features.is_empty() and back.ability_scores.get_score("STR") == 16 and back.get_ac() == 13 and back.speed == 8, "040 S-163 reload keeps the projection and re-suppresses rebuilt features")
	var src := str(dto.spell_concentration.effect_source)
	SpellEffects.remove(back, src)
	check.call(not ActorProjectionRules.is_projected(back) and back.features.size() == features_before and back.ability_scores.to_dict() == before and back.speed == int(dto.spell_effects[src].projection.original.speed), "040 S-163 reverting after reload restores the same actor without duplicate features")
	var defects := {
		"undeclared form": func(d): d.spell_effects[src].projection.form_id = "dragon",
		"level": func(d): d.spell_effects[src].projection.level = 5,
		"scores": func(d): d.ability_scores.STR = 30,
		"suppressed under retention": func(d): d.spell_effects[src].spell_id = MANTLE,
		"foreign caster": func(d): d.spell_effects[src].caster_id = "someone",
	}
	var refused := 0
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		if not SpellEffectPersistence.saved_state_error(bad).is_empty(): refused += 1
	check.call(refused == 5, "040 S-163 saved projection refuses an undeclared form, tampered level, contradicted scores, wrong carrier and foreign caster (%d/5)" % refused)
	var two := dto.duplicate(true)
	var dup: Dictionary = two.spell_effects[src].duplicate(true)
	dup.source_id = src + "0"
	two.spell_effects[src + "0"] = dup
	check.call(not ActorProjectionRules.saved_state_error(two).is_empty(), "040 S-163 a saved actor cannot hold two projections")

## Runtime Reviewer stress (RY1-RY8).
static func review_stress(check: Callable) -> void:
	# RY1: refusal before cost - several forms and no selection keep the slot.
	var a := caster("b040_ry1")
	a.spell_slots = {"2": 1}
	var r := SpellResolver.resolve(a, a, DataLoader.get_spell(SHIFT), true, {}, [], 2)
	check.call(not ActorProjectionRules.is_projected(a) and int(a.spell_slots.get("2", 0)) == 1 and not r.get("success", true), "040 RY1 no form selection is refused before the slot is spent (slots=%s success=%s)" % [str(a.spell_slots), str(r.get("success", null))])
	# RY2: an active projection refuses a second projection before cost and keeps the first.
	var b := caster("b040_ry2")
	shift(b, 2, "b040_hound")
	b.spell_slots = {"3": 1}
	var r2 := SpellResolver.resolve(b, b, DataLoader.get_spell(MANTLE), true, {}, [], 3)
	check.call(ActorProjectionRules.active(b).get("form", {}).get("id", "") == "b040_hound" and int(b.spell_slots.get("3", 0)) == 1 and not r2.get("success", true), "040 RY2 a second projection is refused before the slot is spent (slots=%s)" % str(b.spell_slots))
	# RY3: Wild Shape active refuses before cost (documented limit: no combined forms).
	var c := caster("b040_ry3")
	c.wild_shape_state = {"form_id": "wolf"}
	c.spell_slots = {"3": 1}
	var r3 := SpellResolver.resolve(c, c, DataLoader.get_spell(MANTLE), true, {}, [], 3)
	check.call(not ActorProjectionRules.is_projected(c) and int(c.spell_slots.get("3", 0)) == 1 and not r3.get("success", true), "040 RY3 Wild Shape refuses a projection before the slot is spent (slots=%s)" % str(c.spell_slots))
	c.wild_shape_state = {}
	# RY4: creature records reuse ids every encounter (monster_0); a new death gets a fresh successor.
	var src := caster("b040_ry4")
	var m1 := {"id": "monster_0", "name": "G", "current_hp": 10, "max_hp": 10, "is_alive": true, "creature_type": "humanoid"}
	reap(src, m1)
	var h1: Character = AftermathSuccessorRules.actors(m1)[0]
	h1.take_damage(999)
	var m2 := {"id": "monster_0", "name": "G", "current_hp": 10, "max_hp": 10, "is_alive": true, "creature_type": "humanoid"}
	reap(src, m2)
	var h2: Array = AftermathSuccessorRules.actors(m2)
	check.call(h2.size() == 1 and h2[0] != h1 and h2[0].is_alive and h2[0].current_hp == h2[0].max_hp, "040 RY4 a later encounter's same-id creature death raises a fresh successor, not the earlier destroyed one (hp=%s)" % str(h2.map(func(x): return x.current_hp)))
	# RY5: a reloaded Character host rebuilds its successor from the saved record.
	var d := Batch031Checks._character("b040_ry5", 20)
	reap(src, d)
	var hs: Character = AftermathSuccessorRules.actors(d)[0]
	hs.current_hp = 9
	var dto := d.to_dict()
	hs.take_damage(999)
	var nd := Character.new()
	nd.from_dict(dto)
	var back: Array = AftermathSuccessorRules.actors(nd)
	check.call(back.size() == 1 and back[0] != hs and back[0].current_hp == 9 and back[0].is_alive, "040 RY5 reload rebuilds the successor at its saved HP, not the post-save cache")
	# RY6: created-actor R1 still holds after the restack (039 RX1 mirror).
	var o := Batch039Checks.caster("b040_ry6")
	Batch039Checks.conjure(o, 2)
	var w: Character = CreatedActorRules.actors(o)[0]
	w.take_damage(5)
	var odto := o.to_dict()
	w.take_damage(7)
	var no := Character.new()
	no.from_dict(odto)
	check.call(CreatedActorRules.actors(no)[0].current_hp == w.max_hp - 5, "040 RY6 039 R1 owner-instance rebuild survives the shared instance() refactor")
	# RY7: revert through SpellEffects.remove (not concentration) restores the exact actor once.
	var e := caster("b040_ry7")
	var feats := e.features.size()
	var scores := e.ability_scores.to_dict()
	shift(e, 2, "b040_hound")
	var src_id := str(ActorProjectionRules.active(e).source)
	SpellEffects.remove(e, src_id)
	SpellEffects.remove(e, src_id)
	check.call(not ActorProjectionRules.is_projected(e) and e.features.size() == feats and e.ability_scores.to_dict() == scores and e.temp_hp == 0, "040 RY7 removal reverts once; a repeated removal changes nothing")
	# RY8: a refused cast leaves no orphan source record.
	check.call(not a.spell_effects.values().any(func(rec): return rec is Dictionary and str(rec.get("spell_id", "")) == SHIFT), "040 RY8 a refused projection leaves no source record")
