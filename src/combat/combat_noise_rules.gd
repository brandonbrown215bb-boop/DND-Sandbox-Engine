## Explicit sound producers in the represented encounter. Distances are authored,
## not an invented hearing radius for every action in the game.
class_name CombatNoiseRules
extends RefCounted

const VERBAL_SOUND := {"volume":"loud", "range_feet":60}


## One effect sound, independent of casting components. Other hosts must refuse
## before payment until they can publish the actual sound.
static func spell_host_error(spell: Dictionary, cast: SpellCastContext) -> String:
	if not spell.has("effect_noise"): return ""
	var reason := error(spell.effect_noise)
	if not reason.is_empty(): return reason
	var origin_kind := str(spell.effect_noise.get("origin", "caster"))
	if not SharedSpell.uses(spell):
		# Native data-declared sounds are limited to ordinary player Magic
		# Actions and ReadySpellRules' verified paid-then-released player host.
		var ordinary_action_host: bool = cast != null and cast.action_id == "magic"
		var ready_spell_host: bool = cast != null and cast.action_id == "ready" and cast.ready_sound_host
		if cast == null or (not ordinary_action_host and not ready_spell_host) or origin_kind != "caster" or not cast.ground_room.is_empty(): return "Native spell effect sound needs an ordinary player combat Action or verified Ready spell."
		if cast.player_index < 0 or cast.player_index >= cast.players.size() or cast.players[cast.player_index].get("character") != cast.caster: return "Native spell effect sound needs an ordinary player combat cast."
	if origin_kind not in ["caster", "target"]: return "Spell effect sound origin must be caster or target."
	if cast == null or cast.grid == null:
		return "Spell effect sound needs a supported represented cast."
	if not cast.ground_room.is_empty():
		if cast.caster == null: return "Spell effect sound needs a represented local-room caster."
		var room_positions: Dictionary = cast.ground_room.get("party_positions", {})
		if not room_positions.has(cast.caster.character_id) or not cast.players.any(func(entry): return entry.get("character") == cast.caster):
			return "Spell effect sound needs a represented local-room caster."
		if origin_kind == "caster":
			return "" if not cast.effect_noise_source_plane.is_empty() else "Spell effect sound needs a represented local-room caster."
		if not cast.effect_noise_source is Character or cast.effect_noise_source == null or not cast.effect_noise_source.is_alive or cast.effect_noise_source not in cast.players.map(func(entry): return entry.get("character")):
			return "Room target-origin sound needs an exact represented living party target."
		var target_position: Variant = room_positions.get(cast.effect_noise_source.character_id, null)
		if target_position == null or cast.effect_noise_source_plane != PhysicalFactsRules.get_plane(cast.effect_noise_source, cast.ground_room):
			return "Room target-origin sound needs an exact represented living party target."
		if LocalRoomRules.coord(target_position) != cast.effect_noise_source_position:
			return "Room target-origin sound source moved before spell completion."
		return ""
	if not cast.publish_combat_event.is_valid():
		return "Spell effect sound needs a supported represented combat cast."
	var monster_source := _monster_cast_source(cast)
	var player_host: bool = false
	if cast.player_index >= 0 and cast.player_index < cast.players.size():
		player_host = cast.players[cast.player_index].get("character") == cast.caster
	if not player_host and monster_source.is_empty(): return "Spell effect sound needs a represented player or monster combat cast."
	# Monster Action casts use this same shared sound owner. A target origin is
	# valid only for one exact creature target selected by the current intent.
	if origin_kind == "target":
		if str(spell.get("target", "single")) not in ["single", "single_ally"] or not cast.command_selection.is_empty() or cast.additional_target_coord != Vector2i(9999, 9999):
			return "Target-origin spell sound needs one selected target."
		# Ready pays at declaration, before release-time target selection. Its
		# declaration is validated here; its exact source is captured at release.
		if cast.effect_noise_source == null and _selected_sound_source(cast).is_empty() and not (cast.action_id == "ready" and not cast.ready_action_paid): return "Target-origin spell sound needs a live selected creature or object."
	return ""


## Called after the effect stages and Action settlement, including an empty area
## or a missed attack. Recipient success is not the spell's completion boundary.
static func publish_spell_effect(cast: SpellCastContext) -> void:
	if cast.action_id == "ready" and (cast.ready_release_token.is_empty() or not cast.ready_action_paid): return
	if cast.effect_noise_published or cast.interrupted or not cast.spell.has("effect_noise") or not spell_host_error(cast.spell, cast).is_empty(): return
	# Mark before opening any Reaction continuation. Multi-recipient/step spells
	# produce one sound; holding a Ready spell produces none until release.
	cast.effect_noise_published = true
	var monster_source := _monster_cast_source(cast)
	var source = monster_source if not monster_source.is_empty() else cast.caster
	var actor = monster_source if not monster_source.is_empty() else cast.caster
	var origin: Vector2i = monster_source.get("hex_position", Vector2i.ZERO) if not monster_source.is_empty() else cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
	var target_origin := str(cast.spell.effect_noise.get("origin", "caster")) == "target"
	if target_origin:
		source = cast.effect_noise_source
		origin = cast.effect_noise_source_position
	var source_kind := cast.effect_noise_source_kind if target_origin else "creature"
	var source_plane := cast.effect_noise_source_plane if target_origin else PhysicalFactsRules.get_plane(source, LocalRoomCombat.room())
	await cast.publish_combat_event.call({"type":"sound", "actor":actor, "source":source, "source_kind":source_kind, "source_plane":source_plane, "position":origin, "noise":cast.spell.effect_noise.duplicate(true)})


## Local-room casts use the same represented grid routes and hearing rules, with
## receipts returned to the ordinary room result. No room sound history is kept.
static func publish_room_spell_effect(room: Dictionary, caster: Character, party: Array, grid: HexGrid, spell: Dictionary, cast: SpellCastContext, result: Dictionary) -> void:
	if cast == null or cast.effect_noise_published or cast.interrupted or not spell.has("effect_noise") or spell_host_error(spell, cast) != "": return
	cast.effect_noise_published = true
	var target_origin := str(spell.effect_noise.get("origin", "caster")) == "target"
	var source = cast.effect_noise_source if target_origin else caster
	var source_kind := cast.effect_noise_source_kind if target_origin else "creature"
	if CombatPerception._has_condition(source, "silenced"): return
	for position in grid.tiles:
		grid.get_tile(position).custom_properties["blocks_sound"] = LocalRoomRules.blocks_sound(room, position)
	var origin := cast.effect_noise_source_position if target_origin else cast.spell_origin
	var plane := cast.effect_noise_source_plane if target_origin else PhysicalFactsRules.get_plane(caster, room)
	var heard: Array[String] = []
	for observer in party:
		if not observer is Character or not observer.is_alive or not room.party_positions.has(observer.character_id): continue
		if not ContainmentRules.relation(room, "character", observer.character_id).is_empty(): continue
		var destination := LocalRoomRules.coord(room.party_positions[observer.character_id])
		if can_hear(observer, destination, origin, grid, spell.effect_noise, source, room, plane, source_kind == "object"): heard.append(observer.character_id)
	if str(spell.effect_noise.get("volume", "")) == "loud" and source is Character: OrdinaryActionRules.remove_hidden(source)
	result["noise"] = spell.effect_noise.duplicate(true)
	result["heard_by"] = heard
	var names: Array[String] = []
	for observer in party:
		if observer is Character and observer.character_id in heard: names.append(observer.character_name)
	result["message"] = str(result.get("message", "")) + " %s sound; heard by %s." % [str(spell.effect_noise.volume).capitalize(), ", ".join(names) if not names.is_empty() else "no party members"]


static func _monster_cast_source(cast: SpellCastContext) -> Dictionary:
	if cast == null or cast.caster == null or not bool(cast.caster.feature_uses.get("is_monster_actor", false)): return {}
	var source: Variant = cast.caster.feature_uses.get("monster_source")
	if not source is Dictionary: return {}
	var exact_host := false
	for monster in cast.monsters:
		if is_same(source, monster): exact_host = true; break
	if not exact_host: return {}
	return source


## Capture the exact entity/object before ordinary spell payment or Ready
## Reaction payment. A repeated validation must resolve to that same source.
static func capture_target_origin(cast: SpellCastContext) -> String:
	if str(cast.spell.get("effect_noise", {}).get("origin", "caster")) != "target": return ""
	var selected := _selected_sound_source(cast)
	if selected.is_empty() and cast.action_id == "ready" and not cast.ready_action_paid: return ""
	if selected.is_empty(): return "The selected sound source is no longer a valid target."
	var source_id := str(selected.get("id", ""))
	var source_kind := str(selected.get("kind", ""))
	var position: Vector2i = selected.get("position", Vector2i.ZERO)
	var plane := PhysicalFactsRules.get_plane(selected.get("source"), LocalRoomCombat.room())
	if not cast.effect_noise_source_id.is_empty() and (cast.effect_noise_source_id != source_id or cast.effect_noise_source_kind != source_kind or cast.effect_noise_source_position != position or cast.effect_noise_source_plane != plane or not is_same(cast.effect_noise_source, selected.get("source"))):
		return "The selected sound source changed before the spell could be paid."
	cast.effect_noise_source_id = source_id
	cast.effect_noise_source_kind = source_kind
	cast.effect_noise_source_position = position
	cast.effect_noise_source_plane = plane
	cast.effect_noise_source = selected.source
	return ""


static func _selected_sound_source(cast: SpellCastContext) -> Dictionary:
	var position: Vector2i = cast.target_coord
	for player in cast.players:
		var character: Character = player.get("character")
		if character != null and player.get("hex_position", Vector2i.ZERO) == position and character.is_alive:
			return {"id": character.character_id, "kind":"creature", "position":position, "source":character}
	for monster in cast.monsters:
		if bool(monster.get("is_alive", false)) and monster.get("hex_position", Vector2i.ZERO) == position:
			return {"id":str(monster.get("id", "")), "kind":"creature", "position":position, "source":monster}
	if bool(cast.spell.get("targets_objects", false)):
		var object := CombatObjectRules.at(cast.grid, position, cast.caster)
		if CombatObjectRules.can_take_spell_damage(object):
			return {"id":CombatObjectRules.target_key(object), "kind":"object", "position":position, "source":object}
	return {}


static func error(noise: Variant) -> String:
	if not noise is Dictionary or noise.is_empty(): return "Sound needs a volume and hearing range."
	for field in noise:
		if field not in ["volume", "range_feet", "origin"]: return "Unsupported sound field."
	if noise.get("volume") not in ["whisper", "loud"]: return "Sound volume must be whisper or loud."
	if not ResourcePoolRules._integer(noise.get("range_feet"), 1, 5280): return "Sound needs a hearing range of 1-5280 feet."
	if noise.has("origin") and noise.origin not in ["caster", "target"]: return "Spell effect sound origin must be caster or target."
	return ""


static func can_hear(observer, origin: Vector2i, destination: Vector2i, grid: HexGrid, noise: Dictionary, source = null, spatial_context: Dictionary = {}, source_plane: String = "", allow_blocked_origin: bool = false) -> bool:
	if observer == null or not error(noise).is_empty() or grid == null or not grid.has_tile(origin) or not grid.has_tile(destination): return false
	if CombatPerception._has_condition(observer, "deafened") or CombatPerception._has_condition(observer, "silenced") or CombatPerception._has_condition(source, "silenced"): return false
	if source != null and PhysicalFactsRules.get_plane(observer, spatial_context) != (source_plane if not source_plane.is_empty() else PhysicalFactsRules.get_plane(source, spatial_context)): return false
	var max_steps := floori(float(noise.range_feet) / 5.0)
	# Sound follows the shortest open route across represented hexes. Missing
	# cells and sound-blocking walls/doors stop propagation; sight and fog do not
	# determine whether a route is audible.
	if _blocks_sound(grid, origin) and not allow_blocked_origin: return false
	var queue: Array[Vector2i] = [origin]
	var distance := {origin: 0}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var steps := int(distance[current])
		if current == destination: return true
		if steps >= max_steps: continue
		for neighbor in HexUtils.get_neighbors(current):
			if distance.has(neighbor) or not grid.has_tile(neighbor) or _blocks_sound(grid, neighbor): continue
			distance[neighbor] = steps + 1
			queue.append(neighbor)
	return false


static func _blocks_sound(grid: HexGrid, position: Vector2i) -> bool:
	var properties: Dictionary = grid.get_tile(position).custom_properties
	return bool(properties.get("blocks_sound", properties.get("blocks_sight", false)))


static func emit(state: CombatState, event: Dictionary) -> void:
	event["heard_by"] = {}
	var actor = event.get("actor")
	var source = event.get("source", actor)
	var noise: Dictionary = event.get("noise", {})
	if actor == null or source == null or not event.get("position") is Vector2i or not error(noise).is_empty(): return
	if CombatPerception._has_condition(source, "silenced"): return
	var represented_creature: bool = source is Character or (source is Dictionary and source.has("is_alive") and source.has("id"))
	if noise.volume == "loud" and represented_creature: OrdinaryActionRules.remove_hidden(source)
	for participant in state.player_entities + state.monster_entities:
		var observer = participant.get("character", participant)
		if not OrdinaryActionRules._alive(observer): continue
		if can_hear(observer, participant.hex_position, event.position, state.hex_grid, noise, source, LocalRoomCombat.room(), str(event.get("source_plane", "")), str(event.get("source_kind", "")) == "object"):
			event.heard_by[CombatAction.actor_id(observer)] = participant.hex_position
			if noise.volume == "loud" and represented_creature and CombatAction.actor_id(observer) != CombatAction.actor_id(source): CombatPerception.reveal_location(observer, source, event.position, state.hex_grid)


## Room operations use the same declared sound and actual-attempt boundary.
static func room_interact(room: Dictionary, actor: Character, party: Array, grid: HexGrid, id: String, action: String, instance_id: String = "") -> Dictionary:
	var object := LocalRoomRules.get_object(room, id, actor)
	if object.is_empty(): return LocalRoomRules.failure("That object is no longer known here.")
	var declarations: Variant = object.get("interaction_noise", {})
	if not declarations is Dictionary: return LocalRoomRules.failure("Object interaction_noise must map operations to sounds.")
	var noise: Variant = declarations.get(action, {})
	if declarations.has(action) and not error(noise).is_empty(): return LocalRoomRules.failure(error(noise))
	if actor == null or actor not in party or not room.get("party_positions", {}).has(actor.character_id): return LocalRoomRules.failure("Choose a character in this room.")
	if PhysicalFactsRules.get_plane(actor, room) != PhysicalFactsRules.get_plane(object, room): return LocalRoomRules.failure("The object is on another plane.")
	var object_altitude := int(object.get("altitude_feet", LocalRoomRules.elevation_feet(room, LocalRoomRules.coord(object.position))))
	if abs(LocalRoomRules.altitude_feet(room, actor.character_id) - object_altitude) > 5: return LocalRoomRules.failure("Move within 5 feet of the object first.")
	var result := LocalRoomRules.interact(room, id, action, actor, instance_id, LocalRoomSearchRules.check_context(room, actor, grid, party))
	if int(result.get("seconds", 0)) <= 0 or not declarations.has(action) or CombatPerception._has_condition(actor, "silenced"): return result
	# Resolve the operation first, so an opened door no longer blocks its sound.
	for position in grid.tiles: grid.get_tile(position).custom_properties["blocks_sound"] = LocalRoomRules.blocks_sound(room, position)
	var origin := LocalRoomRules.coord(room.party_positions[actor.character_id])
	var heard: Array[String] = []
	for observer in party:
		if not observer.is_alive or not room.party_positions.has(observer.character_id) or not ContainmentRules.relation(room, "character", observer.character_id).is_empty(): continue
		if can_hear(observer, LocalRoomRules.coord(room.party_positions[observer.character_id]), origin, grid, noise, actor, room): heard.append(observer.character_id)
	if noise.volume == "loud": OrdinaryActionRules.remove_hidden(actor)
	result["noise"] = noise.duplicate(true)
	result["heard_by"] = heard
	result["message"] = str(result.get("message", "")) + " %s sound; heard by %d party member(s)." % [str(noise.volume).capitalize(), heard.size()]
	return result
