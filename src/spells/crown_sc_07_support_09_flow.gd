## SC-07 support 09: Bestow Curse option 4 restricted to attack-roll hits and
## spell damage. Generic damage_origin tag (CombatAction.with_damage_origin):
## weapon-attack hits and the primary settlement of spell damage (spell damage
## rolls, spell zones, Hunter's Mark, Divine Smite) are tagged; hazards, falls,
## items, features, riders and packets stay untagged and never fire riders.
class_name CrownSc07Support09Flow
extends RefCounted

const P := "SC-07 s9: "

static func _cursed(caster: Character, id: String, hex: Vector2i) -> Dictionary:
	var m := CrownSc07Support08Flow._target(id, hex)
	m["armor_class"] = 1
	var s := DataLoader.get_spell("bestow_curse").duplicate(true)
	s["_chosen_condition"] = "cursed_necrotic"
	CombatAction.resolve_spell(caster, m, s, false, {}, [], 3, 5)
	return m

static func _riders(receipt: Dictionary) -> int:
	return receipt.get("marker_rider_receipts", []).size()

static func run(h) -> void:
	h._enter_test("crown_sc_07_support_09_flow")
	h._setup_world()
	var caster := ConversionBatch002Checks.actor("crown-sc07s9-caster", "cleric", 5)
	var other := ConversionBatch002Checks.actor("crown-sc07s9-other", "fighter", 5)
	var t := _cursed(caster, "crown-sc07s9-t", Vector2i(1, 0))
	h._assert(t.conditions.has("cursed_necrotic"), P + "option 4 curse lands")
	# Non-attack, non-spell damage from the caster: the untagged paths hazards, falls, items and features use.
	var hp := int(t.current_hp)
	var hazard := CombatAction.resolve_damage(t, 4, "fire", {}, false, false, caster)
	var fall := CombatAction.resolve_damage(t, 4, "bludgeoning", {"damage_source_instance_id": "fall"}, false, false, caster)
	var item := CombatAction.resolve_damage(t, 4, "acid", {"damage_source_instance_id": "item:alchemists_fire"}, false, false, caster)
	h._assert(_riders(hazard) + _riders(fall) + _riders(item) == 0 and hp - int(t.current_hp) == 12, P + "hazard, fall and item damage dealt by the caster add no Necrotic")
	# The real room-hazard code path (LocalRoomAreas) carries the caster's id but no origin tag.
	var area_hp := int(t.current_hp)
	var plane := PhysicalFactsRules.get_plane(t, {"plane": ""})
	var area_res := LocalRoomAreas.resolve_aftermath_entry({"id": "crown-sc07s9-trap", "spell_id": "trap", "hazard_kind": "entry_damage", "plane": plane, "amount": 3, "damage_type": "fire", "caster_id": caster.character_id}, t)
	h._assert(int(area_res.get("resolved", -1)) == 3 and area_hp - int(t.current_hp) == 3, P + "a room hazard placed by the caster deals only its own damage (%s)" % str(area_res))
	var before := int(t.current_hp)
	var hit2 := {}
	for _i in 40:
		before = int(t.current_hp)
		hit2 = CombatAction.resolve_weapon_attack(caster, t, {"damage": "1", "damage_type": "bludgeoning", "attack_bonus": 50})
		if bool(hit2.get("hit", false)): break
	var lost := before - int(t.current_hp)
	h._assert(bool(hit2.get("hit", false)) and lost >= 2 and lost <= 9, P + "the caster's weapon attack-roll hit adds 1d8 Necrotic (lost %d)" % lost)
	before = int(t.current_hp)
	for _i in 40:
		before = int(t.current_hp)
		var o := CombatAction.resolve_weapon_attack(other, t, {"damage": "1", "damage_type": "bludgeoning", "attack_bonus": 50})
		if bool(o.get("hit", false)): break
	h._assert(before - int(t.current_hp) == 1, P + "another creature's hit adds nothing")
	# Spell damage from the caster through CombatAction.resolve_spell triggers.
	var flame := DataLoader.get_spell("sacred_flame").duplicate(true)
	t["saving_throw_bonuses"] = {"WIS": -1000, "DEX": -1000}
	before = int(t.current_hp)
	var r := CombatAction.resolve_spell(caster, t, flame, false, {}, [], 0, 5)
	var dealt := before - int(t.current_hp)
	h._assert(dealt > int(r.get("damage", 0)) and dealt - int(r.get("damage", 0)) <= 8, P + "the caster's spell damage adds 1d8 Necrotic (spell %d, total %d)" % [int(r.get("damage", 0)), dealt])
	print("CROWN_SC_07_SUPPORT_09_PASSED")
	h._exit_test()
