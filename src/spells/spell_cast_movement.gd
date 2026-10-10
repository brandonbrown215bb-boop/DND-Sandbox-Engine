## Find Steed and teleport cast completion.
class_name SpellCastMovement
extends RefCounted

static func _resolve_spell_cast_movement(cast: SpellCastContext) -> bool:
	if str(cast.spell.get("id", "")) == "find_steed":
		var choice: Dictionary = cast.spell.get("_find_steed_choice", {})
		var steed_result := PaladinRules.create_find_steed_state(cast.caster, cast.spell, cast.slot_level_used, str(choice.get("creature_type", "")), str(choice.get("form", "")))
		if not steed_result.get("success", false):
			cast.hud.add_log("[color=orange]%s[/color]" % steed_result.get("message", "Find Steed failed."))
			return true
		var summon_result: Dictionary = cast.add_find_steed_entity.call(cast.players[cast.player_index], cast.target_coord, true)
		if not summon_result.get("success", false):
			PaladinRules.dismiss_find_steed(cast.caster)
			cast.hud.add_log("[color=orange]%s[/color]" % summon_result.get("message", "Find Steed could not place the steed."))
			return true
		cast.hud.add_log("[color=cyan]%s[/color]" % steed_result.get("message", "Find Steed appears."))
		cast.spend_action_cost.call(cast.action_cost_for_command.call("cast_spell", {"spell": cast.spell}))
		cast.clear_pending(SpellCastContext.CLEAR_ACTION)
		cast.clear_pending(SpellCastContext.CLEAR_SPELL)
		cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
		cast.clear_pending(SpellCastContext.CLEAR_WISH)
		cast.hud.update_hud(cast.caster, cast.tracker)
		cast.highlight_reachable.call()
		cast.redraw_entities.call()
		return true
	# Self-targeted teleport spells resolve movement at the combat-state boundary;
	# there is no creature at the destination to pass through CombatAction.
	for effect in cast.spell.get("effects", []):
		if str(effect.get("type", "")) != "teleport":
			continue
		var origin: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
		if not cast.grid.has_tile(cast.target_coord) or not cast.grid.is_hex_passable(cast.target_coord) or cast.areas._is_occupied_hex(cast.caster, cast.target_coord):
			cast.hud.add_log("[color=orange]That teleport destination is not available.[/color]")
			cast.highlight_reachable.call()
			return true
		cast.players[cast.player_index]["hex_position"] = cast.target_coord
		await cast.areas._resolve_spell_zone_entries(cast.caster, origin, cast.target_coord)
		cast.hud.add_log("[color=cyan]%s teleports from %s to %s.[/color]" % [cast.caster.character_name, origin, cast.target_coord])
		var teleport_cost := str(cast.spell.get("casting_time", "action"))
		cast.spend_action_cost.call("bonus_action" if teleport_cost == "bonus_action" else "magic_action")
		cast.clear_pending(SpellCastContext.CLEAR_ACTION)
		cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
		cast.clear_pending(SpellCastContext.CLEAR_WISH)
		cast.check_battle_end_conditions.call()
		cast.highlight_reachable.call()
		cast.redraw_entities.call()
		return true
	return false


