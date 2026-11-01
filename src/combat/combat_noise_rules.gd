## Explicit sound producers in the represented encounter. Distances are authored,
## not an invented hearing radius for every action in the game.
class_name CombatNoiseRules
extends RefCounted

const VERBAL_SOUND := {"volume":"loud", "range_feet":60}


static func error(noise: Variant) -> String:
	if not noise is Dictionary or noise.is_empty(): return "Sound needs a volume and hearing range."
	for field in noise:
		if field not in ["volume", "range_feet"]: return "Unsupported sound field."
	if noise.get("volume") not in ["whisper", "loud"]: return "Sound volume must be whisper or loud."
	if not ResourcePoolRules._integer(noise.get("range_feet"), 1, 5280): return "Sound needs a hearing range of 1-5280 feet."
	return ""


static func can_hear(observer, origin: Vector2i, destination: Vector2i, grid: HexGrid, noise: Dictionary, source = null, spatial_context: Dictionary = {}) -> bool:
	if observer == null or not error(noise).is_empty() or grid == null or not grid.has_tile(origin) or not grid.has_tile(destination): return false
	if CombatPerception._has_condition(observer, "deafened") or CombatPerception._has_condition(observer, "silenced") or CombatPerception._has_condition(source, "silenced"): return false
	if source != null and PhysicalFactsRules.get_plane(observer, spatial_context) != PhysicalFactsRules.get_plane(source, spatial_context): return false
	if HexUtils.get_distance(origin, destination) * 5 > int(noise.range_feet): return false
	# Fog and darkness do not stop sound. Represented solid walls (including
	# glass) and closed doors do; propagation around corners is outside this host.
	for position in Targeting.line_cells(origin, destination):
		if not grid.has_tile(position): return false
		var properties: Dictionary = grid.get_tile(position).custom_properties
		if bool(properties.get("blocks_sound", properties.get("blocks_sight", false))): return false
	return true


static func emit(state: CombatState, event: Dictionary) -> void:
	event["heard_by"] = {}
	var actor = event.get("actor")
	var noise: Dictionary = event.get("noise", {})
	if actor == null or not event.get("position") is Vector2i or not error(noise).is_empty(): return
	if CombatPerception._has_condition(actor, "silenced"): return
	if noise.volume == "loud": OrdinaryActionRules.remove_hidden(actor)
	for participant in state.player_entities + state.monster_entities:
		var observer = participant.get("character", participant)
		if not OrdinaryActionRules._alive(observer): continue
		if can_hear(observer, participant.hex_position, event.position, state.hex_grid, noise, actor, LocalRoomCombat.room()):
			event.heard_by[CombatAction.actor_id(observer)] = participant.hex_position
			if noise.volume == "loud" and not is_same(observer, actor): CombatPerception.reveal_location(observer, actor, event.position, state.hex_grid)
