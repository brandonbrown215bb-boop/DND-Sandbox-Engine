## Ordinary JSON spells share one exploration entry point and combat resolution.
class_name LocalRoomSharedSpells
extends RefCounted

static func party_spell(spell: Dictionary) -> bool:
	return SharedSpell.uses(spell) and SpellSupport.is_available(spell) and spell.get("target", "single") in ["single", "self"] and (spell.has("save_exit_placement") or not spell.has("damage") or spell.has("containment_targeting")) and (not spell.has("save") or spell.has("save_exit_placement") or spell.has("containment_targeting"))

static func object_spell(spell: Dictionary) -> bool:
	return SharedSpell.uses(spell) and SpellSupport.is_available(spell) and spell.get("target", "single") == "single" and bool(spell.get("targets_objects", false)) and spell.has("damage")

static func cast(state: Dictionary, caster: Character, spell_id: String, target: Character, party: Array, grid: HexGrid) -> Dictionary:
	var spell := DataLoader.get_spell(spell_id).duplicate(true)
	if not party_spell(spell) or target == null or target not in party:
		return LocalRoomRules.failure("Choose a party-targeted shared spell and a character in this room.")
	return _cast(state, caster, spell, target, target.character_id, party, grid)


static func cast_with_save_exit(state: Dictionary, caster: Character, spell_id: String, target: Character, party: Array, grid: HexGrid, choose_save_exit: Callable) -> Dictionary:
	var spell := DataLoader.get_spell(spell_id).duplicate(true)
	if not party_spell(spell) or not spell.has("save_exit_placement") or target == null or target not in party:
		return LocalRoomRules.failure("Choose a party-targeted spell with a supported required exit.")
	var result := _cast(state, caster, spell, target, target.character_id, party, grid, {}, choose_save_exit)
	if not result.has("save_exit_request"): return result
	var receipt: Dictionary = result.get("_room_exit_receipt", {})
	result.erase("_room_exit_receipt")
	var host: SpellCastContext = receipt.get("host")
	var decisions: Dictionary = receipt.get("decisions", {})
	result = await SpellCastResults._settle_save_exit(host, target, spell, decisions, [], host.slot_level_used, int(receipt.get("distance", 0)), result)
	if result.get("success", false):
		_finish_room_cast(state, caster, spell, target, party, str(receipt.get("component", "")), str(receipt.get("previous_spell", "")), str(receipt.get("previous_source", "")), result)
	return result

## Existing room spell settlement with the combat factory's transient selections.
## The room UI owns placement clicks; shared spell resolution still owns costs,
## source creation and generic actor construction.
static func cast_creation(state: Dictionary, caster: Character, spell: Dictionary, party: Array, grid: HexGrid) -> Dictionary:
	if CreatedActorRules._effect(spell).is_empty() or spell.get("target", "") != "self":
		return LocalRoomRules.failure("Choose a self-targeted shared spell with a supported creature factory.")
	return _cast(state, caster, spell, caster, caster.character_id, party, grid)

static func cast_object(state: Dictionary, caster: Character, spell_id: String, object_id: String, party: Array, grid: HexGrid) -> Dictionary:
	var spell := DataLoader.get_spell(spell_id).duplicate(true)
	var object := LocalRoomRules.get_object(state, object_id)
	var boundary_error := ContainmentRules.target_error(caster, object, spell, state, party)
	if not boundary_error.is_empty(): return LocalRoomRules.failure(boundary_error)
	if not object_spell(spell) or not CombatObjectRules.can_take_spell_damage(object, true):
		return LocalRoomRules.failure("Choose a shared object spell and an eligible object.")
	var target := CombatObjectRules.make_resolution_target(object)
	# Room object transactions own defenses, damage thresholds and broken locks.
	target["damage_immunities"] = []
	target["damage_resistances"] = []
	target["damage_vulnerabilities"] = []
	var result := _cast(state, caster, spell, target, object_id, party, grid, object)
	if result.get("success", false):
		result["damage"] = CombatObjectRules.apply_damage(object, int(result.get("damage", 0)), str(spell["damage_type"]), true)
		if result.get("hit", false) and bool(spell.get("ignites_objects", false)):
			result["ignited"] = CombatObjectRules.ignite(object)
	return result

static func _cast(state: Dictionary, caster: Character, spell: Dictionary, target, target_id: String, party: Array, grid: HexGrid, object: Dictionary = {}, choose_save_exit: Callable = Callable()) -> Dictionary:
	var boundary_error := ContainmentRules.target_error(caster, target, spell, state, party)
	if not boundary_error.is_empty(): return LocalRoomRules.failure(boundary_error)
	var caster_inside := not ContainmentRules.relation(state, "character", caster.character_id).is_empty()
	var target_kind := "character" if target is Character else "object"
	var target_inside := not ContainmentRules.relation(state, target_kind, target_id).is_empty()
	if (caster_inside or target_inside or ContainmentRules.involved(state, target_kind, target_id)) and (spell.has("save_exit_placement") or spell.get("effects", []).any(func(e): return e.get("type") in ["create_actor", "actor_projection", "grant_source_benefits", "teleport", "transform"])): return LocalRoomRules.failure("That spell needs containment release or placement support.")
	var error := LocalRoomRules._room_spell_caster_error(caster, spell)
	if not error.is_empty(): return LocalRoomRules.failure(error)
	if caster.has_condition("raging") or not DruidRules.can_cast_spell(caster, spell):
		return LocalRoomRules.failure("That character cannot cast a spell in its current state.")
	var positions: Dictionary = state.get("party_positions", {})
	if not positions.has(caster.character_id) or (object.is_empty() and not positions.has(target_id)):
		return LocalRoomRules.failure("The caster and target must be present in this room.")
	var from := ContainmentRules.external_location(state, "character", caster.character_id, party)
	var to := ContainmentRules.external_location(state, target_kind, target_id, party)
	if from.get("kind") != "external" or to.get("kind") != "external" or from.plane != to.plane: return LocalRoomRules.failure("Choose represented locations on the same plane.")
	var origin := LocalRoomRules.coord(from.position)
	var destination := LocalRoomRules.coord(to.position)
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
	var host := SpellCastContext.new()
	host.caster = caster
	host.spell = spell
	host.ground_room = state
	host.grid = grid
	host.choose_save_exit = choose_save_exit
	for member: Character in party:
		if not ContainmentRules.relation(state, "character", member.character_id).is_empty(): continue
		var member_position: Variant = positions.get(member.character_id, null)
		if member_position is Array and member_position.size() >= 2:
			host.players.append({"character": member, "hex_position": LocalRoomRules.coord(member_position), "is_alive": member.is_alive})
	var decisions := {"cast_context": host, "grid": grid, "players": host.players, "monsters": host.monsters}
	var result := CombatAction.resolve_spell(caster, target, spell, true, decisions, [], 0, distance, host)
	if result.has("save_exit_request"):
		result["_room_exit_receipt"] = {"host": host, "decisions": decisions, "distance": distance, "component": component, "previous_spell": previous_spell, "previous_source": previous_source}
		return result
	if not result.get("success", false): return result
	_finish_room_cast(state, caster, spell, target, party, component, previous_spell, previous_source, result)
	return result


static func _finish_room_cast(state: Dictionary, caster: Character, spell: Dictionary, target, party: Array, component: String, previous_spell: String, previous_source: String, result: Dictionary) -> void:
	if bool(spell.get("material_component_consumed", false)) and not component.is_empty(): caster.inventory.take_instance(component, "destruction")
	if bool(spell.get("concentration", false)):
		LocalRoomAreas.remove_concentration(state, caster.character_id, previous_spell, previous_source)
		SpellEffects.end_concentration(caster, party)
		caster.concentrating_on = {"spell_id": spell["id"], "effect_source": result["effect_cast"]["source_id"], "targets": [target]}
	SpellEffects.reconcile(party, party)
	result["seconds"] = 6
