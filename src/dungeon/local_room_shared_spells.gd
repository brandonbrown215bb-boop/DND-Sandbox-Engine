## Ordinary JSON spells share one exploration entry point and combat resolution.
class_name LocalRoomSharedSpells
extends RefCounted

static func party_spell(spell: Dictionary) -> bool:
	return SharedSpell.uses(spell) and SpellSupport.is_available(spell) and spell.get("target", "single") in ["single", "self"] and not spell.has("damage") and not spell.has("save")

static func object_spell(spell: Dictionary) -> bool:
	return SharedSpell.uses(spell) and SpellSupport.is_available(spell) and spell.get("target", "single") == "single" and bool(spell.get("targets_objects", false)) and spell.has("damage")

static func cast(state: Dictionary, caster: Character, spell_id: String, target: Character, party: Array, grid: HexGrid) -> Dictionary:
	var spell := DataLoader.get_spell(spell_id).duplicate(true)
	if not party_spell(spell) or target == null or target not in party:
		return LocalRoomRules.failure("Choose a party-targeted shared spell and a character in this room.")
	return _cast(state, caster, spell, target, target.character_id, party, grid)

static func cast_object(state: Dictionary, caster: Character, spell_id: String, object_id: String, party: Array, grid: HexGrid) -> Dictionary:
	var spell := DataLoader.get_spell(spell_id).duplicate(true)
	var object := LocalRoomRules.get_object(state, object_id)
	if not object_spell(spell) or not CombatObjectRules.can_take_spell_damage(object):
		return LocalRoomRules.failure("Choose a shared object spell and an eligible object.")
	var target := CombatObjectRules.make_resolution_target(object)
	# Room object transactions own defenses, damage thresholds and broken locks.
	target["damage_immunities"] = []
	target["damage_resistances"] = []
	target["damage_vulnerabilities"] = []
	var result := _cast(state, caster, spell, target, object_id, party, grid, object)
	if result.get("success", false):
		result["damage"] = CombatObjectRules.apply_damage(object, int(result.get("damage", 0)), str(spell["damage_type"]))
		if result.get("hit", false) and bool(spell.get("ignites_objects", false)):
			result["ignited"] = CombatObjectRules.ignite(object)
	return result

static func _cast(state: Dictionary, caster: Character, spell: Dictionary, target, target_id: String, party: Array, grid: HexGrid, object: Dictionary = {}) -> Dictionary:
	var error := LocalRoomRules._room_spell_caster_error(caster, spell)
	if not error.is_empty(): return LocalRoomRules.failure(error)
	if caster.has_condition("raging") or not DruidRules.can_cast_spell(caster, spell):
		return LocalRoomRules.failure("That character cannot cast a spell in its current state.")
	var positions: Dictionary = state.get("party_positions", {})
	if not positions.has(caster.character_id) or (object.is_empty() and not positions.has(target_id)):
		return LocalRoomRules.failure("The caster and target must be present in this room.")
	var origin := LocalRoomRules.coord(positions[caster.character_id])
	var destination := LocalRoomRules.coord(object["position"] if not object.is_empty() else positions[target_id])
	if not Targeting.is_in_range(origin, destination, CombatAction.spell_range_in_hexes(spell, caster.level)):
		return LocalRoomRules.failure("Choose a target within the spell's range.")
	var distance := HexUtils.get_distance(origin, destination) * 5
	var validation := CombatAction.validate_spell_target(caster, target, spell, distance)
	if not validation.get("success", false): return LocalRoomRules.failure(str(validation["message"]))
	if not Targeting.has_line_of_sight(origin, destination, grid):
		return LocalRoomRules.failure("Choose a target with an unobstructed path.")
	var slot := str(CombatAction.get_spell_slot_level(caster, spell))
	if int(spell["level"]) > 0 and int(caster.spell_slots.get(slot, 0)) <= 0 and not caster.has_free_spell_cast(str(spell["id"])):
		return LocalRoomRules.failure("No spell slot or free cast remains.")
	var component := caster.inventory.required_spell_component_instance(spell)
	var previous_spell := str(caster.concentrating_on.get("spell_id", ""))
	var previous_source := str(caster.concentrating_on.get("effect_source", caster.concentrating_on.get("%s_source_id" % previous_spell, "")))
	var result := CombatAction.resolve_spell(caster, target, spell, true, {}, [], 0, distance)
	if not result.get("success", false): return result
	if bool(spell.get("material_component_consumed", false)) and not component.is_empty(): caster.inventory.take_instance(component)
	if bool(spell.get("concentration", false)):
		LocalRoomAreas.remove_concentration(state, caster.character_id, previous_spell, previous_source)
		SpellEffects.end_concentration(caster, party)
		caster.concentrating_on = {"spell_id": spell["id"], "effect_source": result["effect_cast"]["source_id"], "targets": [target]}
	SpellEffects.reconcile(party, party)
	result["seconds"] = 6
	return result
