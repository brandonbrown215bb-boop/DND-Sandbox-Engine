## SC-07 support 09/10: Bestow Curse option 4. The curse's extra Necrotic damage
## is a typed packet inside the caster's attack-roll hit or spell damage
## occurrence: doubled on a critical hit, mitigated like any packet, included in
## returned totals (concentration/aftermath/logs), rolled once, and skipped when
## the occurrence dealt no damage. Plain resolve_damage never adds it.
class_name CrownSc07Support09Flow
extends RefCounted

const P := "SC-07 s9: "

static func _cursed(caster: Character, id: String, hex: Vector2i, hp: int = 200) -> Dictionary:
	var m := CrownSc07Support08Flow._target(id, hex)
	m["armor_class"] = 1
	m["current_hp"] = hp
	m["max_hp"] = hp
	var s := DataLoader.get_spell("bestow_curse").duplicate(true)
	s["_chosen_condition"] = "cursed_necrotic"
	CombatAction.resolve_spell(caster, m, s, false, {}, [], 3, 5)
	return m

static func _curse_components(result: Dictionary) -> Array:
	return result.get("damage_components", []).filter(func(c): return str(c.get("type", "")) == "necrotic")

static func _weapon_hit(caster: Character, target: Dictionary, want_crit: bool) -> Dictionary:
	for _i in 200:
		if want_crit: FighterChecks._seed_die(20, 20)
		var hp := int(target.current_hp)
		var r := CombatAction.resolve_weapon_attack(caster, target, {"id": "fixture:club", "type": "weapon", "damage": "1", "damage_type": "bludgeoning", "ability": "STR", "range": 1, "attack_bonus": 50})
		if bool(r.get("hit", false)) and bool(r.get("crit", false)) == want_crit:
			r["_hp_lost"] = hp - int(target.current_hp)
			return r
	return {}

static func run(h) -> void:
	h._enter_test("crown_sc_07_support_09_flow")
	h._setup_world()
	var caster := ConversionBatch002Checks.actor("crown-sc07s9-caster", "cleric", 5)
	var other := ConversionBatch002Checks.actor("crown-sc07s9-other", "fighter", 5)
	var t := _cursed(caster, "crown-sc07s9-t", Vector2i(1, 0))
	h._assert(t.conditions.has("cursed_necrotic"), P + "option 4 curse lands")
	# Plain settlements (hazards, falls, items, features) never add the packet.
	var hp := int(t.current_hp)
	var hazard := CombatAction.resolve_damage(t, 4, "fire", {}, false, false, caster)
	var fall := CombatAction.resolve_damage(t, 4, "bludgeoning", {"damage_source_instance_id": "fall"}, false, false, caster)
	h._assert(not hazard.has("marker_rider_receipts") and not fall.has("marker_rider_receipts") and hp - int(t.current_hp) == 8, P + "hazard and fall damage dealt by the caster add no Necrotic")
	var area_hp := int(t.current_hp)
	var plane := PhysicalFactsRules.get_plane(t, {"plane": ""})
	var area_res := LocalRoomAreas.resolve_aftermath_entry({"id": "crown-sc07s9-trap", "spell_id": "trap", "hazard_kind": "entry_damage", "plane": plane, "amount": 3, "damage_type": "fire", "caster_id": caster.character_id}, t)
	h._assert(int(area_res.get("resolved", -1)) == 3 and area_hp - int(t.current_hp) == 3, P + "a room hazard placed by the caster deals only its own damage (%s)" % str(area_res))
	# Weapon hits: one Curse packet, in the returned total, doubled dice on a crit.
	var hit := _weapon_hit(caster, t, false)
	var curse: Array = _curse_components(hit)
	h._assert(curse.size() == 1 and int(curse[0].value) >= 1 and int(curse[0].value) <= 8 and int(hit.damage) == int(hit._hp_lost) and int(hit.damage) == 1 + int(curse[0].value), P + "non-critical weapon hit: 1 + one 1d8 Necrotic packet, and the returned damage equals HP lost (%s)" % str(hit.get("damage_components", [])))
	var crit := _weapon_hit(caster, t, true)
	curse = _curse_components(crit)
	var curse_terms: Array = crit.get("activity_damage", {}).get("dice_terms", []).filter(func(term): return str(term.get("label", "")).begins_with("Curse"))
	h._assert(curse.size() == 1 and curse_terms.size() == 2 and int(curse[0].value) >= 2 and int(curse[0].value) <= 16 and int(crit.damage) == int(crit._hp_lost), P + "critical weapon hit doubles the Curse dice (2d8) inside the same hit total (%s)" % str(curse_terms))
	var theirs := _weapon_hit(other, t, false)
	h._assert(_curse_components(theirs).is_empty() and int(theirs._hp_lost) == 1, P + "another creature's hit adds nothing")
	# A hit that deals no damage deals no curse damage.
	t["damage_immunities"] = ["bludgeoning"]
	var blocked := _weapon_hit(caster, t, false)
	h._assert(_curse_components(blocked).is_empty() and int(blocked._hp_lost) == 0, P + "a hit the target is immune to deals no Curse damage (%s)" % str(blocked.get("damage_components", [])))
	t.erase("damage_immunities")
	# The Curse packet is mitigated like any other packet.
	t["damage_immunities"] = ["necrotic"]
	var immune := _weapon_hit(caster, t, false)
	curse = _curse_components(immune)
	h._assert(curse.size() == 1 and int(curse[0].value) == 0 and int(immune._hp_lost) == 1, P + "Necrotic immunity stops the Curse packet but not the hit")
	t.erase("damage_immunities")
	# Spell damage (shared settlement): save spells keep the full rider on a halved spell.
	var half := SpellDamageRolls._finish_spell_damage(caster, t, {"final_total": 10, "dice_terms": []}, 0, 0.5, "fire", {}, {"success": true, "hit": true, "message": "{damage}"})
	var half_curse: Array = half.get("additional_damage_components", []).filter(func(c): return str(c.get("label", "")) == "Curse")
	h._assert(half_curse.size() == 1 and int(half_curse[0].value) >= 1 and int(half_curse[0].value) <= 8 and int(half.damage) == 5 + int(half_curse[0].value) and int(half.resolved) == int(half.damage) and half_curse[0].roll.get("dice_terms", []).size() == 1, P + "half-damage save spell: 5 fire + an unhalved 1d8 Curse packet in one returned total")
	var spell_crit := SpellDamageRolls._finish_spell_damage(caster, t, {"final_total": 4, "dice_terms": []}, 0, 1.0, "fire", {"damage_is_critical": true}, {"success": true, "hit": true, "message": "{damage}"})
	var crit_curse: Array = spell_crit.get("additional_damage_components", []).filter(func(c): return str(c.get("label", "")) == "Curse")
	h._assert(crit_curse.size() == 1 and crit_curse[0].roll.get("dice_terms", []).size() == 2 and int(spell_crit.damage) == 4 + int(crit_curse[0].value), P + "critical spell attack doubles the Curse dice in the same occurrence")
	var none := SpellDamageRolls._finish_spell_damage(caster, t, {"final_total": 10, "dice_terms": []}, 0, 0.0, "fire", {}, {"success": true, "hit": true, "message": "{damage}"})
	h._assert(none.get("additional_damage_components", []).is_empty() and int(none.damage) == 0, P + "a spell that deals no damage deals no Curse damage")
	# Real spell routes: a spell attack (Guiding Bolt) and a save spell (Sacred Flame).
	t["saving_throw_bonuses"] = {"WIS": -1000, "DEX": -1000}
	for spell_id in ["guiding_bolt", "sacred_flame"]:
		var spell := DataLoader.get_spell(spell_id).duplicate(true)
		var r := {}
		var lost := 0
		for _i in 40:
			var before := int(t.current_hp)
			r = CombatAction.resolve_spell(caster, t, spell.duplicate(true), false, {}, [], int(spell.get("level", 0)), 5)
			lost = before - int(t.current_hp)
			if lost > 0: break
		var parts: Array = r.get("additional_damage_components", []).filter(func(c): return str(c.get("label", "")) == "Curse")
		h._assert(parts.size() == 1 and int(r.get("damage", 0)) == lost, P + "%s: one Curse packet and the returned damage equals HP lost (%d vs %d)" % [spell_id, int(r.get("damage", 0)), lost])
	# Zero HP: the packet settles in the occurrence that downs the target and is reported with it.
	var low := _cursed(caster, "crown-sc07s9-low", Vector2i(0, 1), 3)
	var down := SpellDamageRolls._finish_spell_damage(caster, low, {"final_total": 3, "dice_terms": []}, 0, 1.0, "fire", {}, {"success": true, "hit": true, "message": "{damage}"})
	h._assert(int(down.get("hp_after", 1)) <= 0 and int(down.resolved) >= 4 and down.get("additional_damage_components", []).size() == 1, P + "the downing occurrence includes its Curse packet once (%s)" % str(down.get("additional_damage_components", [])))
	# Zone ticks use the same occurrence helper.
	var zone := CombatAction.resolve_spell_damage_occurrence(t, 3, "slashing", caster)
	var zone_other := CombatAction.resolve_spell_damage_occurrence(t, 3, "slashing", other)
	h._assert(zone.get("marker_rider_receipts", []).size() == 1 and int(zone.damage) >= 4 and int(zone.damage) <= 11 and not zone_other.has("marker_rider_receipts") and int(zone_other.damage) == 3, P + "a spell zone tick from the caster carries one Curse packet in its total; another caster's does not")
	print("CROWN_SC_07_SUPPORT_09_PASSED")
	h._exit_test()
