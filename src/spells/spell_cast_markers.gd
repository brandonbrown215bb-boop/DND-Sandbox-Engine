## Marker and message spell cast completion.
class_name SpellCastMarkers
extends RefCounted

static func _resolve_spell_cast_markers(cast: SpellCastContext) -> bool:
	if str(cast.spell.get("id", "")) == "prestidigitation":
		return await _cast_prestidigitation(cast)
	if str(cast.spell.get("id", "")) == "produce_flame" and bool(cast.spell.get("_produce_flame_create", false)):
		return await _cast_produce_flame(cast)
	if str(cast.spell.get("id", "")) == "minor_illusion":
		return await _cast_minor_illusion(cast)
	if str(cast.spell.get("id", "")) == "message":
		return await _cast_message(cast)
	if str(cast.spell.get("id", "")) == "mage_hand":
		return await _cast_mage_hand(cast)
	if str(cast.spell.get("id", "")) == "light":
		return await _cast_light(cast)
	if str(cast.spell.get("id", "")) == "dancing_lights":
		return await _cast_dancing_lights(cast)
	return false


static func _cast_prestidigitation(cast: SpellCastContext) -> bool:
	var prestidigitation_cast := CombatAction.resolve_spell(cast.caster, cast.caster, cast.spell, false, cast.counterspell_decisions, cast.counterspell_observers, cast.slot_level_used, 0)
	if prestidigitation_cast.get("success", false):
		var effect_type := str(cast.spell.get("_prestidigitation_effect_type", ""))
		var effect := PrestidigitationRules.create_effect(cast.target_coord, cast.caster.character_id, cast.caster.character_name, effect_type, str(cast.spell.get("_prestidigitation_description", "")), cast.tracker.current_round)
		if effect.is_empty():
			cast.hud.add_log("[color=orange]Choose one supported Prestidigitation effect and describe it.[/color]")
		elif PrestidigitationRules.is_instantaneous(effect_type):
			cast.hud.add_log("[color=cyan]Prestidigitation creates a harmless sensory flourish: %s[/color]" % effect["description"])
		else:
			var effects: Array = cast.prestidigitation_effects.get(cast.caster.character_id, [])
			effects.append(effect)
			cast.prestidigitation_effects[cast.caster.character_id] = effects
			cast.hud.add_log("[color=cyan]Prestidigitation creates %s: %s[/color]" % [effect_type.replace("_", " "), effect["description"]])
	else:
		cast.hud.add_log(str(prestidigitation_cast.get("message", "Prestidigitation fails to resolve.")))
	cast.spend_action_cost.call("bonus_action" if bool(cast.spell.get("_metamagic_quickened", false)) else "magic_action")
	cast.clear_pending(SpellCastContext.CLEAR_ACTION)
	cast.clear_pending(SpellCastContext.CLEAR_SPELL)
	cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
	cast.clear_pending(SpellCastContext.CLEAR_WISH)
	cast.hud.update_hud(cast.caster, cast.tracker)
	cast.redraw_entities.call()
	cast.highlight_reachable.call()
	return true


static func _cast_produce_flame(cast: SpellCastContext) -> bool:
	var flame_cast := CombatAction.resolve_spell(cast.caster, cast.caster, cast.spell, false, cast.counterspell_decisions, cast.counterspell_observers, cast.slot_level_used, 0)
	if flame_cast.get("success", false):
		var flame_origin: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
		cast.produce_flame_markers[cast.caster.character_id] = ProduceFlameRules.create_flame(cast.caster.character_id, cast.caster.character_name, flame_origin, cast.tracker.current_round)
		cast.hud.add_log("[color=orange]%s holds a harmless flame that sheds light.[/color]" % cast.caster.character_name)
	else:
		cast.hud.add_log(str(flame_cast.get("message", "Produce Flame fails to resolve.")))
	cast.spend_action_cost.call(cast.action_cost_for_command.call("cast_spell", {"spell": cast.spell}))
	cast.clear_pending(SpellCastContext.CLEAR_ACTION)
	cast.clear_pending(SpellCastContext.CLEAR_SPELL)
	cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
	cast.clear_pending(SpellCastContext.CLEAR_WISH)
	cast.hud.update_hud(cast.caster, cast.tracker)
	cast.redraw_entities.call()
	cast.highlight_reachable.call()
	return true


static func _cast_minor_illusion(cast: SpellCastContext) -> bool:
	var illusion_cast := CombatAction.resolve_spell(cast.caster, cast.caster, cast.spell, false, cast.counterspell_decisions, cast.counterspell_observers, cast.slot_level_used, 0)
	if illusion_cast.get("success", false):
		var illusion := MinorIllusionRules.create_illusion(
			cast.target_coord,
			cast.caster.character_id,
			cast.caster.character_name,
			str(cast.spell.get("_minor_illusion_form", "")),
			str(cast.spell.get("_minor_illusion_description", "")),
			cast.tracker.current_round
		)
		if not illusion.is_empty():
			cast.minor_illusion_markers[cast.caster.character_id] = illusion
			cast.hud.add_log("[color=violet]Minor Illusion creates a %s: %s[/color]" % [illusion["form"], illusion["description"]])
		else:
			cast.hud.add_log("[color=orange]Minor Illusion needs a sound or image description.[/color]")
	else:
		cast.hud.add_log(str(illusion_cast.get("message", "Minor Illusion fails to resolve.")))
	cast.spend_action_cost.call("bonus_action" if bool(cast.spell.get("_metamagic_quickened", false)) else "magic_action")
	cast.clear_pending(SpellCastContext.CLEAR_ACTION)
	cast.clear_pending(SpellCastContext.CLEAR_SPELL)
	cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
	cast.clear_pending(SpellCastContext.CLEAR_WISH)
	cast.hud.update_hud(cast.caster, cast.tracker)
	cast.redraw_entities.call()
	cast.highlight_reachable.call()
	return true


static func _cast_message(cast: SpellCastContext) -> bool:
	var message_target: Character = null
	for player in cast.players:
		var candidate: Character = player.get("character")
		if candidate != null and candidate.character_id == str(cast.spell.get("_message_target_id", "")) and candidate.is_alive:
			message_target = candidate
			break
	if message_target == null:
		cast.hud.add_log("[color=orange]The Message target is no longer available.")
	else:
		var cast_result := CombatAction.resolve_spell(cast.caster, message_target, cast.spell, false, cast.counterspell_decisions, cast.counterspell_observers, cast.slot_level_used, HexUtils.get_distance(cast.spell_origin, cast.target_coord) * 5)
		if cast_result.get("success", false):
			var exchange: Dictionary = await cast.hud.request_message_exchange(
				cast.caster.character_name,
				message_target.character_name,
				int(cast.spell.get("_message_target_owner", -1))
			)
			if exchange.get("success", false):
				cast.hud.add_log(MessageRules.activity_summary(cast.caster.character_name, message_target.character_name))
			else:
				cast.hud.add_log("[color=orange]The whisper exchange was cancelled.[/color]")
		else:
			cast.hud.add_log(str(cast_result.get("message", "Message could not be delivered.")))
	cast.spend_action_cost.call("bonus_action" if bool(cast.spell.get("_metamagic_quickened", false)) else "magic_action")
	cast.clear_pending(SpellCastContext.CLEAR_ACTION)
	cast.clear_pending(SpellCastContext.CLEAR_SPELL)
	cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
	cast.clear_pending(SpellCastContext.CLEAR_WISH)
	cast.hud.update_hud(cast.caster, cast.tracker)
	cast.highlight_reachable.call()
	return true


static func _cast_mage_hand(cast: SpellCastContext) -> bool:
	if not Targeting.is_in_range(cast.spell_origin, cast.target_coord, MageHandRules.RANGE_HEXES) or not cast.grid.has_tile(cast.target_coord):
		cast.hud.add_log("[color=orange]Choose a point within 30 feet for Mage Hand.[/color]")
		cast.highlight_reachable.call()
		return true
	var cast_result := CombatAction.resolve_spell(cast.caster, cast.caster, cast.spell, false, cast.counterspell_decisions, cast.counterspell_observers, cast.slot_level_used, 0)
	cast.hud.add_log(str(cast_result.get("message", "Mage Hand fails to resolve.")))
	if cast_result.get("success", false):
		cast.mage_hand_markers[cast.caster.character_id] = MageHandRules.create_hand(cast.target_coord, cast.caster.character_id, cast.caster.character_name, cast.tracker.current_round)
		cast.hud.add_log("[color=violet]A spectral hand appears.[/color]")
	cast.spend_action_cost.call("magic_action")
	cast.clear_pending(SpellCastContext.CLEAR_ACTION)
	cast.clear_pending(SpellCastContext.CLEAR_SPELL)
	cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
	cast.clear_pending(SpellCastContext.CLEAR_WISH)
	cast.hud.update_hud(cast.caster, cast.tracker)
	cast.redraw_entities.call()
	cast.highlight_reachable.call()
	return true


static func _cast_light(cast: SpellCastContext) -> bool:
	var cast_result := CombatAction.resolve_spell(cast.caster, cast.caster, cast.spell, false, cast.counterspell_decisions, cast.counterspell_observers, cast.slot_level_used, 0)
	cast.hud.add_log(str(cast_result.get("message", "Light fails to resolve.")))
	if cast_result.get("success", false):
		if SpellZoneTerrain.light_is_dispersed_by_darkness(cast.areas.active_spell_zones, cast.target_coord, LightRules.DIM_RADIUS_HEXES):
			cast.light_spell_markers.erase(cast.caster.character_id)
			cast.hud.add_log("[color=sky_blue]Magical Darkness immediately dispels the overlapping Light.[/color]")
		else:
			cast.light_spell_markers[cast.caster.character_id] = LightRules.create_marker(cast.target_coord, cast.caster.character_id, cast.caster.character_name)
			cast.hud.add_log("[color=yellow]The touched object sheds Bright Light for 20 feet and Dim Light for 20 more feet.[/color]")
	cast.spend_action_cost.call("magic_action")
	cast.clear_pending(SpellCastContext.CLEAR_ACTION)
	cast.clear_pending(SpellCastContext.CLEAR_SPELL)
	cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
	cast.clear_pending(SpellCastContext.CLEAR_WISH)
	cast.hud.update_hud(cast.caster, cast.tracker)
	cast.redraw_entities.call()
	cast.highlight_reachable.call()
	return true


static func _cast_dancing_lights(cast: SpellCastContext) -> bool:
	var cast_result := CombatAction.resolve_spell(cast.caster, cast.caster, cast.spell, false, cast.counterspell_decisions, cast.counterspell_observers, cast.slot_level_used, 0)
	cast.hud.add_log(str(cast_result.get("message", "Dancing Lights fails to resolve.")))
	if cast_result.get("success", false):
		if not cast.caster.concentrating_on.is_empty():
			cast.end_concentration.call(cast.caster)
		var light_result := DancingLightsRules.create_light_set(
			cast.caster.character_id,
			cast.caster.character_name,
			cast.spell_origin,
			cast.target_coord,
			bool(cast.spell.get("_dancing_lights_humanoid_form", false)),
			int(cast.spell.get("_dancing_lights_count", 4))
		)
		if light_result.get("success", false):
			cast.dancing_light_sets[cast.caster.character_id] = light_result["lights"]
			cast.caster.concentrating_on = {
				"spell_id": "dancing_lights",
				"effects": [],
				"targets": [],
				"dancing_lights_cast_round": cast.tracker.current_round,
				"dancing_lights_rounds_remaining": 10,
			}
			cast.hud.add_log("[color=cyan]Four torch-size lights appear and shed Dim Light in a 10-foot radius.[/color]" if not bool(cast.spell.get("_dancing_lights_humanoid_form", false)) else "[color=cyan]A glowing Medium, vaguely humanlike form appears and sheds Dim Light in a 10-foot radius.[/color]")
		else:
			cast.hud.add_log("[color=orange]%s[/color]" % light_result.get("message", "Dancing Lights could not appear."))
	cast.spend_action_cost.call("magic_action")
	cast.clear_pending(SpellCastContext.CLEAR_ACTION)
	cast.clear_pending(SpellCastContext.CLEAR_SPELL)
	cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
	cast.clear_pending(SpellCastContext.CLEAR_WISH)
	cast.hud.update_hud(cast.caster, cast.tracker)
	cast.redraw_entities.call()
	cast.highlight_reachable.call()
	return true


static func _tick_dancing_lights_duration(cast: SpellCastContext, caster: Character) -> void:
	if caster == null or str(caster.concentrating_on.get("spell_id", "")) != "dancing_lights":
		return
	if cast.tracker.current_round <= int(caster.concentrating_on.get("dancing_lights_cast_round", cast.tracker.current_round)):
		return
	var remaining := int(caster.concentrating_on.get("dancing_lights_rounds_remaining", 10)) - 1
	caster.concentrating_on["dancing_lights_rounds_remaining"] = remaining
	if remaining <= 0:
		SpellEncounterLifecycle._end_concentration(cast, caster)
		cast.redraw_entities.call()


static func _tick_light_spell_duration(cast: SpellCastContext, caster: Character) -> void:
	if caster == null or not cast.light_spell_markers.has(caster.character_id):
		return
	var light_spell_marker: Dictionary = cast.light_spell_markers[caster.character_id]
	var result := LightRules.tick(light_spell_marker)
	if bool(result.get("active", false)):
		cast.light_spell_markers[caster.character_id] = result.get("marker", {})
	else:
		cast.light_spell_markers.erase(caster.character_id)
		cast.redraw_entities.call()


static func _tick_mage_hand_duration(cast: SpellCastContext, caster: Character) -> void:
	if caster == null or not cast.mage_hand_markers.has(caster.character_id):
		return
	var mage_hand_marker: Dictionary = cast.mage_hand_markers[caster.character_id]
	if cast.tracker.current_round <= int(mage_hand_marker.get("cast_round", cast.tracker.current_round)):
		return
	var result := MageHandRules.tick(mage_hand_marker)
	if bool(result.get("active", false)):
		cast.mage_hand_markers[caster.character_id] = result.get("hand", {})
	else:
		cast.mage_hand_markers.erase(caster.character_id)
		cast.redraw_entities.call()


static func _tick_minor_illusion_duration(cast: SpellCastContext, caster: Character) -> void:
	if caster == null or not cast.minor_illusion_markers.has(caster.character_id):
		return
	var illusion: Dictionary = cast.minor_illusion_markers[caster.character_id]
	if cast.tracker.current_round <= int(illusion.get("cast_round", cast.tracker.current_round)):
		return
	var result := MinorIllusionRules.tick(illusion)
	if result.get("active", false):
		cast.minor_illusion_markers[caster.character_id] = result.get("illusion", {})
	else:
		cast.minor_illusion_markers.erase(caster.character_id)
		cast.redraw_entities.call()


static func _tick_prestidigitation_effects(cast: SpellCastContext, caster: Character) -> void:
	if caster == null or not cast.prestidigitation_effects.has(caster.character_id):
		return
	var effects: Array[Dictionary] = []
	for effect_value in cast.prestidigitation_effects[caster.character_id]:
		effects.append(effect_value)
	var active_effects := PrestidigitationRules.tick(effects)
	if active_effects.is_empty():
		cast.prestidigitation_effects.erase(caster.character_id)
	else:
		cast.prestidigitation_effects[caster.character_id] = active_effects
	if active_effects.size() != effects.size():
		cast.redraw_entities.call()


static func _tick_produce_flame_duration(cast: SpellCastContext, caster: Character) -> void:
	if caster == null or not cast.produce_flame_markers.has(caster.character_id):
		return
	var flame: Dictionary = cast.produce_flame_markers[caster.character_id]
	if cast.tracker.current_round <= int(flame.get("round_created", cast.tracker.current_round)):
		return
	var active_flame := ProduceFlameRules.tick(flame)
	if active_flame.is_empty():
		cast.produce_flame_markers.erase(caster.character_id)
	else:
		cast.produce_flame_markers[caster.character_id] = active_flame
	cast.redraw_entities.call()
