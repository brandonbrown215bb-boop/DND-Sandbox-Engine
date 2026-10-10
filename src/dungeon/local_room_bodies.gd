## The first recovery path carries a party member's remains with that party slot.
class_name LocalRoomBodies
extends RefCounted

static func cast(state: Dictionary, caster: Character, target: Character, party: Array, spell_id: String, ritual: bool = false) -> Dictionary:
	if GameManager.current_state == GameManager.GameState.COMBAT: return LocalRoomRules.failure("Use the combat spell controls during an encounter.")
	if target not in party or caster not in party: return LocalRoomRules.failure("Choose a current party member.")
	if spell_id not in ["revivify", "gentle_repose"]: return LocalRoomRules.failure("This recovery spell is unsupported.")
	var spell := DataLoader.get_spell(spell_id)
	var error := LocalRoomRules._room_spell_caster_error(caster, spell)
	if not error.is_empty(): return LocalRoomRules.failure(error)
	if ritual and not bool(spell.get("ritual", false)): return LocalRoomRules.failure("This spell cannot be cast as a ritual.")
	var origin := LocalRoomRules.coord(state.get("party_positions", {}).get(caster.character_id, [9999, 9999]))
	var position := LocalRoomRules.coord(state.get("party_positions", {}).get(target.character_id, [9999, 9999]))
	if origin == FamiliarRules.ABSENT or position == FamiliarRules.ABSENT or HexUtils.get_distance(origin, position) > 1 or not _clear_path(state, origin, position): return LocalRoomRules.failure("Move within 5 feet of the party member's remains.")
	var now := int(GameManager.campaign_elapsed_seconds)
	error = CorpseRules.target_error(target, spell_id, now)
	if not error.is_empty(): return LocalRoomRules.failure(error)
	var component := caster.inventory.required_spell_component_instance(spell)
	if component.is_empty(): return LocalRoomRules.failure("The consumed Material component is missing.")
	if not ritual:
		var spent := CombatAction.spend_spell_slot(caster, spell)
		if not spent.get("success", false): return LocalRoomRules.failure(str(spent.get("message", "No spell slot remains.")))
	caster.inventory.destroy_instance(component)
	# Exploration casts resolve at completion, after their actual casting time.
	var duration := 606 if ritual else 6
	if spell_id == "gentle_repose":
		CorpseRules.preserve(target, now + duration)
		return {"success": true, "seconds": duration, "message": "%s's remains are protected from decay and becoming Undead for 10 days%s." % [target.character_name, " after the ritual" if ritual else ""]}
	var result := CorpseRules.revive(target, now)
	result["seconds"] = duration
	return result

static func _clear_path(state: Dictionary, origin: Vector2i, position: Vector2i) -> bool:
	for cell in HexUtils.hex_line(origin, position):
		if cell != origin and cell != position and LocalRoomRules.blocks_sight(state, cell): return false
	return true
