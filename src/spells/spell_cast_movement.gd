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
		cast.successful = true
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
		if cast.teleport_settled: # Batch 066: never move or charge twice.
			return true
		var origin: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
		# Batch 066: rechecked before commit_spell_resource; this guard never pays twice.
		if SpellCastMovement.refuse_teleport_destination(cast):
			return true
		cast.players[cast.player_index]["hex_position"] = cast.target_coord
		cast.successful = true
		SpellEffects.publish_event(cast.caster, {"type": "movement", "actor_id": SpellEffects.caster_id(cast.caster), "from": [origin.x, origin.y], "to": [cast.target_coord.x, cast.target_coord.y], "distance_feet": HexUtils.get_distance(origin, cast.target_coord) * 5})
		if cast.publish_source_range_events.is_valid(): cast.publish_source_range_events.call()
		await cast.areas._resolve_spell_zone_entries(cast.caster, origin, cast.target_coord)
		cast.hud.add_log("[color=cyan]%s teleports from %s to %s.[/color]" % [cast.caster.character_name, origin, cast.target_coord])
		var teleport_cost := str(cast.spell.get("casting_time", "action"))
		cast.spend_action_cost.call("bonus_action" if teleport_cost == "bonus_action" else "magic_action")
		cast.teleport_settled = true # Batch 066: one arrival per cast invocation.
		cast.clear_pending(SpellCastContext.CLEAR_ACTION)
		cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
		cast.clear_pending(SpellCastContext.CLEAR_WISH)
		cast.check_battle_end_conditions.call()
		cast.highlight_reachable.call()
		cast.redraw_entities.call()
		return true
	return false



## Batch 066 (S-121/S-122): refuse an illegal teleport arrival, logging the reason.
## Called before any payment (validation and the pre-commit recheck).
## Batch 086 (S-121/S-122): the summoned arrival host. Refuses (and logs) when
## the chosen space cannot hold the declared body's whole footprint within the
## invocation's range. Called at target validation and again just before
## payment, so a selection gone stale after option popups spends nothing.
static func refuse_arrival_destination(cast: SpellCastContext) -> bool:
	var why := arrival_destination_reason(cast)
	if why.is_empty(): return false
	if cast.hud != null: cast.hud.add_log("[color=orange]%s cannot arrive there: %s[/color]" % [str(cast.spell.get("name", "The creature")), why])
	if cast.highlight_reachable.is_valid(): cast.highlight_reachable.call()
	return true

static func arrival_destination_reason(cast: SpellCastContext) -> String:
	if SummonArrivalRules.spec(cast.spell).is_empty(): return ""
	var origin: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
	var range_hexes := SpellCastTargeting._spell_target_range(cast, cast.spell)
	return SummonArrivalRules.destination_error(cast, cast.players, cast.caster, origin, cast.target_coord, cast.spell, range_hexes)

static func refuse_teleport_destination(cast: SpellCastContext) -> bool:
	var why := refuse_teleport_destination_reason(cast)
	if why.is_empty(): return false
	if cast.hud != null: cast.hud.add_log("[color=orange]%s[/color]" % why)
	if cast.highlight_reachable.is_valid(): cast.highlight_reachable.call()
	return true

static func refuse_teleport_destination_reason(cast: SpellCastContext) -> String:
	if TravelPlacementRules.teleport_effects(cast.spell).is_empty(): return ""
	var origin: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
	return TravelPlacementRules.destination_error(cast, cast.caster, origin, cast.target_coord, cast.spell, cast.grid)
