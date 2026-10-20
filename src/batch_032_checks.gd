class_name Batch032Checks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_032/spells/responses.json", "spell")

static func grant(target, owner: Character, suffix: String) -> String:
	var spell := DataLoader.get_spell("fixture:b032_" + suffix)
	var cast := SpellEffects.begin_cast(owner, spell)
	SharedSpell.apply_custom_effects(owner, target, spell.get("effects", []), {"effect_cast": cast}, 1)
	return str(cast.get("source_id", ""))

static func clear(target) -> void:
	for source in SpellEffects.records(target).keys(): SpellEffects.remove(target, source, "fixture_reset")

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "032 loaded neutral/renamed policies and mixed/ordered inputs pass production validation: %s" % str(DataLoader.get_load_errors()))
	var a := Batch031Checks._character("b032_a", 100)
	var b := Batch031Checks._character("b032_b", 100)
	PartyManager.characters[a.character_id] = a
	PartyManager.characters[b.character_id] = b
	var monster := {"id": "b032_monster", "current_hp": 50, "max_hp": 100, "is_alive": true, "damage_immunities": ["fire"]}
	var monster_source := grant(monster, b, "absorb")
	var monster_result := CombatAction.resolve_damage(monster, 7, "fire", {}, false, false, b)
	check.call(SpellEffects.records(monster).has(monster_source) and monster.current_hp == 57 and monster_result.replacement_receipts[0].healed == 7, "032 first grant creates a monster's owned effect dictionary and replaces immune damage")
	a.current_hp = 50
	a.feature_uses["damage_immunities"] = ["fire"]
	var source := grant(a, b, "absorb")
	var r := CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	check.call(r.raw == 7 and r.prevented == 7 and r.absorbed == 7 and r.resolved == 0 and r.hp_loss == 0 and a.current_hp == 57, "032 incoming replacement heals seven despite immunity and distinguishes all damage measures")
	check.call(r.replacement_receipts[0].reacting_source_instance_id == source and r.replacement_receipts[0].measured == 7 and r.replacement_receipts[0].healed == 7, "032 replacement retains exact source and captured healing")
	a.current_hp = 99
	r = CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	check.call(a.current_hp == 100 and r.replacement_receipts[0].healed == 1 and r.replacement_receipts[0].requested_healing == 7, "032 actual healing clamps to missing HP without inventing Temporary HP")
	SpellEffects.remove(a, source)
	source = grant(a, b, "renamed_partial")
	a.current_hp = 50
	r = CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	check.call(a.current_hp == 50 and r.replacement_receipts.is_empty(), "032 resolved replacement cannot heal an immune target's zero resolved damage")
	a.feature_uses.erase("damage_immunities")
	a.feature_uses["damage_resistances"] = ["fire"]
	r = CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	check.call(r.resolved == 1 and r.hp_loss == 1 and r.replacement_receipts[0].measured == 3 and r.replacement_receipts[0].replaced == 2 and r.replacement_receipts[0].healed == 1 and a.current_hp == 50, "032 renamed policy reads resisted three, replaces two, caps healing at one, then loses one HP")
	clear(a)
	a.feature_uses.clear()
	a.current_hp = 50
	a.temp_hp = 10
	grant(a, b, "mirror")
	b.current_hp = 100
	r = CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	check.call(a.current_hp == 50 and a.temp_hp == 3 and r.hp_loss == 0 and r.resolved == 7 and b.current_hp == 93, "032 settled resolved counter includes Temporary HP damage with zero HP loss")
	var cr: Dictionary = r.countereffect_receipts[0]
	check.call(cr.measured == 7 and cr.original_cause_actor_id == b.character_id and cr.root_occurrence_id == r.root_occurrence_id and cr.parent_consequence_id == 0 and cr.damage_receipt.damage_occurrence_id != r.damage_occurrence_id, "032 derived consequence retains root/original cause and distinct occurrence")
	clear(a)
	grant(a, b, "renamed_mirror")
	a.temp_hp = 10
	r = CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	check.call(r.countereffect_receipts.is_empty() and b.current_hp == 93, "032 HP-loss counter does not treat Temporary HP as HP loss")
	a.temp_hp = 0
	r = CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	check.call(r.countereffect_receipts[0].amount == 4 and b.current_hp == 89, "032 changed HP-loss counter rounds half of seven up to four")
	clear(a)
	clear(b)
	a.current_hp = 100
	b.current_hp = 100
	grant(a, b, "mirror")
	grant(b, a, "mirror")
	r = CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	var first: Dictionary = r.countereffect_receipts[0]
	var second: Dictionary = first.damage_receipt.countereffect_receipts[0]
	var stop: Dictionary = second.damage_receipt.countereffect_receipts[0]
	check.call(a.current_hp == 86 and b.current_hp == 93 and bool(stop.get("limited", false)) and second.parent_consequence_id == first.consequence_id, "032 reciprocal exact sources fire once each then terminate with a linked limit receipt")
	r = CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	check.call(a.current_hp == 72 and b.current_hp == 86 and not r.countereffect_receipts[0].get("limited", false), "032 later unrelated occurrence starts a fresh feedback chain")
	clear(a)
	clear(b)
	grant(a, b, "depth_one")
	grant(b, a, "depth_one")
	a.current_hp = 100
	b.current_hp = 100
	r = CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	check.call(a.current_hp == 93 and b.current_hp == 93 and r.countereffect_receipts[0].damage_receipt.countereffect_receipts[0].limited, "032 authored depth-one limit prevents even a different source at depth two")
	clear(a)
	clear(b)
	a.current_hp = 40
	a.feature_uses["damage_resistances"] = ["fire"]
	grant(a, b, "prevented_heal")
	r = CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	check.call(r.prevented == 4 and r.hp_loss == 3 and r.countereffect_receipts[0].healed == 4 and a.current_hp == 41, "032 prevented-based healing reads the settled prevention receipt")
	clear(a)
	a.feature_uses.clear()
	a.current_hp = 40
	a.temp_hp = 7
	grant(a, b, "absorbed_heal")
	r = CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	check.call(r.absorbed == 7 and r.hp_loss == 0 and r.countereffect_receipts[0].healed == 7 and a.current_hp == 47, "032 absorbed-based healing reads Temporary HP absorption after settlement")
	clear(a)
	var p: Dictionary = DataLoader.get_spell("fixture:b032_mirror").effects[0].policy.duplicate(true)
	for defect in ["max_depth", "measure", "feedback", "denominator", "unexpected"]:
		var bad := p.duplicate(true)
		bad[defect] = 0 if defect in ["max_depth", "denominator"] else "unknown"
		check.call(not DamageResponseRules.policy_error(bad).is_empty(), "032 rejects malformed policy field %s" % defect)
	var too_large := p.duplicate(true)
	too_large["numerator"] = 21
	check.call(not DamageResponseRules.policy_error(too_large).is_empty(), "032 refuses ratios outside the production multiplier range")
	grant(a, b, "prevented_heal")
	a.current_hp = 40
	a.add_condition("resilient_sphere", 10)
	r = CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	check.call(r.prevented == 7 and r.resolved == 0 and a.current_hp == 47 and r.countereffect_receipts[0].measured == 7, "032 completely prevented weapon input still supplies a settled prevented-heal measure")
	a.remove_condition("resilient_sphere")
	clear(a)
	a.current_hp = 3
	a.concentrating_on = {"spell_id": "shield_of_faith", "targets": [a]}
	grant(a, b, "hp_loss_heal")
	var healed_zero := CombatAction.resolve_spell(b, a, DataLoader.get_spell("fixture:b032_ordered"), false, {}, [], 1, 5)
	check.call(a.current_hp == 3 and healed_zero.get("step_results", []).size() == 2 and a.concentrating_on.is_empty(), "032 ordered settled healing preserves the already-reached zero-HP concentration outcome through later damage")
	clear(a)
	_pending(check, a, b)
	clear(a)
	clear(b)
	a.current_hp = 50
	a.temp_hp = 100
	grant(a, b, "raw_heal")
	Batch031Controls._seed_hit()
	var weapon := {"damage": "7", "damage_type": "fire", "attack_bonus_override": 100, "ability": "STR"}
	var hit := CombatAction.resolve_weapon_attack(b, a, weapon, false, false, {}, {"formula": "30", "type": "cold"})
	var recipients := DamageLinkRules.recipient_settlements(a, hit)
	check.call(hit.hit and hit.resolved == 37 and hit.damage_components.size() == 2 and recipients.size() == 1 and recipients[0].resolved == 37 and a.temp_hp == 63, "032 response aftermath includes unrelated additional typed damage fully absorbed by Temporary HP")
	clear(a)
	PartyManager.characters.erase(a.character_id)
	PartyManager.characters.erase(b.character_id)

static func _pending(check: Callable, a: Character, b: Character) -> void:
	a.current_hp = 100
	b.current_hp = 100
	a.temp_hp = 0
	var source := grant(a, b, "concentration_mirror")
	b.concentrating_on = {"spell_id": "fixture:b032_concentration_mirror", "effect_source": source, "targets": [a]}
	b.add_modifier("roll", "save:CON", -100, 999)
	b.features.append({"id": "rogue_stroke_of_luck"})
	b.feature_uses["rogue_stroke_of_luck"] = 1
	var spell := DataLoader.get_spell("fixture:b032_ordered")
	var r := CombatAction.resolve_spell(b, a, spell, false, {}, [], 1, 5)
	check.call(r.has("concentration_request") and a.current_hp == 93 and b.current_hp == 93, "032 counter recipient's pending concentration pauses before ordered continuation")
	var stale := r.duplicate(true)
	r = CombatAction.finish_pending_concentration_choice(b, b, r, {"accepted": false})
	check.call(not r.has("concentration_request") and a.current_hp == 90 and b.current_hp == 93 and not SpellEffects.records(a).has(source), "032 declined failed save removes exact reacting source before later ordered damage without replay")
	var refused := CombatAction.finish_pending_concentration_choice(b, b, stale, {"accepted": true})
	check.call(refused.get("refused", false) and a.current_hp == 90 and b.current_hp == 93 and b.feature_uses.rogue_stroke_of_luck == 1, "032 stale callback cannot heal, counter, reacquire or consume a use")
