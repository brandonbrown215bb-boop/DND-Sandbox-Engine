## Eligibility, target/component checks and geometry before spell resources.
class_name SpellCastValidation
extends RefCounted

static func validate_actor(cast: SpellCastContext) -> bool:
	if not str(cast.spell.get("trigger", "")).is_empty():
		cast.hud.add_log("%s is offered immediately after a qualifying hit." % cast.spell.get("name", "This spell"))
		return false
	if str(cast.spell.get("id", "")) == "find_familiar":
		cast.hud.add_log("Find Familiar requires its hour-long exploration cast.")
		return false
	var support := SpellSupport.availability(cast.spell)
	if not support["available"]:
		cast.hud.add_log("[color=orange]%s[/color]" % support["reason"])
		cast.clear_pending(SpellCastContext.CLEAR_ACTION)
		cast.clear_pending(SpellCastContext.CLEAR_SPELL)
		cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
		cast.clear_pending(SpellCastContext.CLEAR_WISH)
		cast.highlight_reachable.call()
		return false
	var spell_origin_for_barrier: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
	if cast.caster.has_condition("resilient_sphere") and cast.target_coord != spell_origin_for_barrier:
		cast.hud.add_log("Resilient Sphere prevents spells from passing through its barrier.")
		cast.clear_pending(SpellCastContext.CLEAR_ACTION)
		cast.clear_pending(SpellCastContext.CLEAR_SPELL)
		cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
		cast.clear_pending(SpellCastContext.CLEAR_WISH)
		cast.highlight_reachable.call()
		return false
	var sphere_target := SpellCastTargeting._creature_at_coord_has_condition(cast, cast.target_coord, "resilient_sphere")
	if sphere_target and cast.target_coord != spell_origin_for_barrier and str(cast.spell.get("id", "")) != "disintegrate":
		cast.hud.add_log("Resilient Sphere blocks the spell's effect across its barrier.")
		cast.clear_pending(SpellCastContext.CLEAR_ACTION)
		cast.clear_pending(SpellCastContext.CLEAR_SPELL)
		cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
		cast.clear_pending(SpellCastContext.CLEAR_WISH)
		cast.highlight_reachable.call()
		return false
	if str(cast.spell.get("id", "")) == "protection_from_energy":
		var is_party_target := false
		for party_entity in cast.players:
			if party_entity.get("hex_position", Vector2i.ZERO) == cast.target_coord and party_entity.get("character") != null and party_entity["character"].is_alive:
				is_party_target = true
				break
		if not is_party_target:
			cast.hud.add_log("Protection from Energy requires a willing living party member; monsters cannot be selected as willing targets.")
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
			cast.clear_pending(SpellCastContext.CLEAR_WISH)
			cast.highlight_reachable.call()
			return false
	if str(cast.spell.get("id", "")) == "protection_from_evil_and_good":
		var is_party_target := false
		for party_entity in cast.players:
			if party_entity.get("hex_position", Vector2i.ZERO) == cast.target_coord and party_entity.get("character") != null and party_entity["character"].is_alive:
				is_party_target = true
				break
		if not is_party_target:
			cast.hud.add_log("Protection from Evil and Good requires a willing living party member.")
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
			cast.clear_pending(SpellCastContext.CLEAR_WISH)
			cast.highlight_reachable.call()
			return false
	if str(cast.spell.get("id", "")) == "mage_armor":
		var eligible_armor_target: Character = null
		for party_entity in cast.players:
			var candidate: Character = party_entity.get("character")
			if candidate != null and candidate.is_alive and party_entity.get("hex_position", Vector2i.ZERO) == cast.target_coord:
				eligible_armor_target = candidate
				break
		if eligible_armor_target == null or not eligible_armor_target.inventory.get_armor().is_empty():
			cast.hud.add_log("Mage Armor needs a willing living party member who isn't wearing armor.")
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.highlight_reachable.call()
			return false
	if str(cast.spell.get("id", "")) == "magic_weapon":
		var weapon_target: Character = null
		for party_entity in cast.players:
			var candidate: Character = party_entity.get("character")
			if candidate != null and candidate.is_alive and party_entity.get("hex_position", Vector2i.ZERO) == cast.target_coord:
				weapon_target = candidate
				break
		if weapon_target == null:
			cast.hud.add_log("Magic Weapon needs a willing living party member holding the target weapon.")
			cast.highlight_reachable.call()
			return false
		var weapon_id := weapon_target.inventory.get_weapon()
		var weapon_record := DataLoader.get_item(weapon_id)
		if weapon_id.is_empty() or weapon_record.is_empty() or str(weapon_record.get("type", "")) != "weapon" or bool(weapon_record.get("magical", false)) or weapon_record.has("rarity"):
			cast.hud.add_log("Magic Weapon needs the target party member's equipped nonmagical weapon.")
			cast.highlight_reachable.call()
			return false
		cast.spell["_magic_weapon_id"] = weapon_id
	if not DruidRules.can_cast_spells(cast.caster):
		cast.hud.add_log("You cannot cast spells while using Wild Shape.")
		cast.clear_pending(SpellCastContext.CLEAR_ACTION)
		cast.clear_pending(SpellCastContext.CLEAR_SPELL)
		cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
		cast.clear_pending(SpellCastContext.CLEAR_WISH)
		cast.highlight_reachable.call()
		return false
	if not DruidRules.can_cast_spell(cast.caster, cast.spell):
		cast.hud.add_log("This spell has a costly or consumed Material component and cannot be cast in Beast form.")
		cast.clear_pending(SpellCastContext.CLEAR_ACTION)
		cast.clear_pending(SpellCastContext.CLEAR_SPELL)
		cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
		cast.clear_pending(SpellCastContext.CLEAR_WISH)
		cast.highlight_reachable.call()
		return false
	if DruidRules.ignores_free_material_components(cast.caster, cast.spell) and "M" in cast.spell.get("components", []):
		cast.spell["_ignore_material_components"] = true
	var required_budget := "bonus_action" if cast.spell.get("casting_time", "action") == "bonus_action" else "magic_action"
	if not cast.can_spend.call(required_budget):
		cast.hud.add_log("Action Surge cannot grant a Magic action.")
		return false
	cast.spell_origin = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
	if not FamiliarSpellDelivery.validate(cast):
		cast.highlight_reachable.call()
		return false
	cast.target_type = str(cast.spell.get("target", "single"))
	return true


static func validate_weapon_and_steed(cast: SpellCastContext) -> bool:
	if str(cast.spell.get("id", "")) == "shillelagh" and cast.caster.inventory.get_weapon() not in ["club", "quarterstaff"]:
		cast.hud.add_log("[color=orange]Shillelagh needs a Club or Quarterstaff equipped in your weapon hand.[/color]")
		cast.highlight_reachable.call()
		return false
	if str(cast.spell.get("id", "")) == "true_strike":
		var true_strike_weapon_id := cast.caster.inventory.get_weapon()
		var true_strike_weapon := DataLoader.get_item(true_strike_weapon_id)
		if true_strike_weapon.is_empty() or str(true_strike_weapon.get("type", "")) != "weapon" or not cast.caster.is_proficient_with_weapon(true_strike_weapon) or int(true_strike_weapon.get("value", 0)) <= 0:
			cast.hud.add_log("[color=orange]True Strike requires an equipped weapon you are proficient with, worth at least 1 CP.[/color]")
			cast.highlight_reachable.call()
			return false
		if not SpellCastTargeting._creature_at_coord_matches_types(cast, cast.target_coord, ["humanoid", "beast", "aberration", "celestial", "construct", "dragon", "elemental", "fey", "fiend", "giant", "monstrosity", "ooze", "plant", "undead"]):
			cast.hud.add_log("[color=orange]True Strike needs a living creature as the weapon attack target.[/color]")
			cast.highlight_reachable.call()
			return false
		cast.spell["_true_strike_weapon_id"] = true_strike_weapon_id
	if str(cast.spell.get("casting_time", "action")) == "reaction":
		cast.hud.add_log("[color=orange]%s resolves only through its reaction boundary.[/color]" % cast.spell.get("name", "This spell"))
		cast.clear_pending(SpellCastContext.CLEAR_ACTION)
		cast.highlight_reachable.call()
		return false
	if str(cast.spell.get("id", "")) == "find_steed":
		var steed_range := SpellCastTargeting._spell_target_range(cast, cast.spell)
		if cast.target_coord == cast.spell_origin or not Targeting.is_in_range(cast.spell_origin, cast.target_coord, steed_range) or not cast.grid.has_tile(cast.target_coord) or not cast.grid.is_hex_passable(cast.target_coord) or cast.areas._is_occupied_hex(cast.caster, cast.target_coord):
			cast.hud.add_log("[color=orange]Choose an unoccupied space within range for Find Steed.[/color]")
			cast.highlight_reachable.call()
			return false
	return true


static func validate_self_target(cast: SpellCastContext) -> bool:
	var spell_is_teleport: bool = cast.spell.get("effects", []).any(func(effect): return str(effect.get("type", "")) == "teleport")
	if cast.target_type == "self" and cast.target_coord != cast.spell_origin and not spell_is_teleport:
		cast.hud.add_log("[color=orange]%s can only target its caster.[/color]" % cast.spell.get("name", "This spell"))
		cast.highlight_reachable.call()
		return false
	return true


static func validate_creatures_and_components(cast: SpellCastContext) -> bool:
	var recovery_spell_id := str(cast.spell.get("id", ""))
	if recovery_spell_id in ["revivify", "gentle_repose"]:
		var body_target: Character = null
		for player in cast.players:
			var candidate: Character = player.get("character")
			if player.get("hex_position", Vector2i.ZERO) != cast.target_coord or candidate == null or not candidate.is_dead() or candidate.class_id in ["familiar", "steed"]: continue
			if body_target != null:
				cast.hud.add_log("Choose a space containing exactly one party member's remains.")
				return false
			body_target = candidate
		var recovery_error := CorpseRules.target_error(body_target, recovery_spell_id, int(GameManager.campaign_elapsed_seconds))
		if not recovery_error.is_empty():
			cast.hud.add_log(recovery_error)
			return false
		cast.spell["_recovery_target_id"] = body_target.character_id
	if cast.target_type == "single_ally":
		var ally_at_target := false
		for player in cast.players:
			if player.get("hex_position", Vector2i.ZERO) == cast.target_coord and player.get("character") != null and (player["character"].is_alive or SpellCastTargeting.can_target_downed(player["character"], cast.spell)):
				ally_at_target = true
				break
		if not ally_at_target:
			cast.hud.add_log("[color=orange]%s needs a living ally target.[/color]" % cast.spell.get("name", "This spell"))
			cast.highlight_reachable.call()
			return false
	cast.command_selection = []
	if str(cast.spell.get("id", "")) in ["command", "longstrider", "magic_missile", "scorching_ray", "eldritch_blast"] or int(cast.spell.get("area_point_count", 1)) > 1 or SpellCastTargeting._spell_upcast_maximum_targets(cast, cast.spell) > 1:
		cast.command_selection.append_array(cast.extra_target_coords)
	if str(cast.spell.get("id", "")) == "chain_lightning":
		var chain_targets: Array[Vector2i] = cast.command_selection.duplicate()
		if cast.target_coord not in chain_targets:
			chain_targets.push_front(cast.target_coord)
		if not SpellCastTargeting.are_legal_chain_targets(chain_targets, cast.spell_origin, SpellCastTargeting._spell_target_range(cast, cast.spell), 6, SpellCastTargeting._spell_upcast_maximum_targets(cast, cast.spell), cast.grid):
			cast.hud.add_log("Choose one legal first target and distinct creatures or objects within 30 feet of that first target.")
			cast.highlight_reachable.call()
			return false
		if not cast.chain_target_ids.is_empty() and cast.chain_target_ids.size() != chain_targets.size():
			cast.hud.add_log("Choose one creature or object identity for each Chain Lightning target.")
			cast.highlight_reachable.call()
			return false
		for target_index in chain_targets.size():
			var chain_target := chain_targets[target_index]
			var has_target := SpellCastTargeting._has_spell_target_at(cast, chain_target, cast.spell)
			if not cast.chain_target_ids.is_empty():
				has_target = SpellCastTargeting.is_chain_target_selected(cast, chain_target, cast.chain_target_ids[target_index])
			if not has_target:
				cast.hud.add_log("Chain Lightning target identity is no longer present at the selected hex.")
				cast.highlight_reachable.call()
				return false
	var required_creature_types: Array = cast.spell.get("target_creature_types", [])
	if SpellEffects.manages(cast.spell):
		var selected: Array[Vector2i] = cast.command_selection.duplicate()
		if cast.target_coord not in selected:
			selected.append(cast.target_coord)
		if cast.additional_target_coord != Vector2i(9999, 9999):
			if cast.additional_target_coord in selected:
				cast.hud.add_log("Select each creature only once.")
				return false
			selected.append(cast.additional_target_coord)
		var seen: Array[Vector2i] = []
		for coord in selected:
			if coord in seen or not Targeting.is_in_range(cast.spell_origin, coord, SpellCastTargeting._spell_target_range(cast, cast.spell)) or not SpellCastTargeting._creature_at_coord_matches_types(cast, coord, ["humanoid", "beast", "aberration", "celestial", "construct", "dragon", "elemental", "fey", "fiend", "giant", "monstrosity", "ooze", "plant", "undead"]):
				cast.hud.add_log("Choose distinct living creatures within this spell's range.")
				return false
			if cast.target_type == "single_ally":
				var party_target := false
				for party_entity in cast.players:
					if party_entity.get("hex_position", Vector2i.ZERO) == coord and party_entity.get("character") != null and party_entity["character"].is_alive:
						party_target = true
						break
				if not party_target:
					cast.hud.add_log("%s can target only willing living party members." % str(cast.spell.get("name", "This spell")))
					return false
			seen.append(coord)
		if selected.size() > SpellCastTargeting._spell_upcast_maximum_targets(cast, cast.spell):
			cast.hud.add_log("Too many targets for this spell slot.")
			return false
	if not required_creature_types.is_empty():
		var spell_target_coords: Array[Vector2i] = [cast.target_coord]
		spell_target_coords.append_array(cast.command_selection)
		if cast.additional_target_coord != Vector2i(9999, 9999):
			spell_target_coords.append(cast.additional_target_coord)
		for spell_target_coord in spell_target_coords:
			if not SpellCastTargeting._creature_at_coord_matches_types(cast, spell_target_coord, required_creature_types):
				cast.hud.add_log("[color=orange]%s can only target %s.[/color]" % [cast.spell.get("name", "This spell"), ", ".join(required_creature_types)])
				cast.highlight_reachable.call()
				return false
	var required_target_sizes: Array = cast.spell.get("target_sizes", [])
	if not required_target_sizes.is_empty() and not SpellCastTargeting._creature_at_coord_matches_sizes(cast, cast.target_coord, required_target_sizes):
		cast.hud.add_log("[color=orange]%s needs a %s target.[/color]" % [cast.spell.get("name", "This spell"), " or ".join(required_target_sizes)])
		cast.highlight_reachable.call()
		return false
	cast.component_item_id = str(cast.spell.get("material_component_item_id", cast.spell.get("consumed_material_item_id", "")))
	cast.component_instance_id = cast.caster.inventory.required_spell_component_instance(cast.spell)
	var component_cost := int(cast.spell.get("material_component_cost", 0))
	if not bool(cast.spell.get("_magic_item_activation", false)) and not cast.caster.inventory.has_required_spell_component(cast.spell, cast.caster.class_id):
		var component_message := "an available hand and a compatible focus or component pouch" if "M" in cast.spell.get("components", []) and component_cost <= 0 and not bool(cast.spell.get("material_component_consumed", false)) else "its Material component%s (%d GP or more)" % [" (consumed)" if bool(cast.spell.get("material_component_consumed", false)) else "", component_cost]
		if cast.caster.inventory.available_spellcasting_hands() < 1 and ("S" in cast.spell.get("components", []) or "M" in cast.spell.get("components", [])):
			component_message = "a free hand for spell components"
		cast.hud.add_log("%s requires %s." % [cast.spell.get("name", "This spell"), component_message])
		cast.clear_pending(SpellCastContext.CLEAR_ACTION)
		cast.clear_pending(SpellCastContext.CLEAR_SPELL)
		cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
		cast.clear_pending(SpellCastContext.CLEAR_WISH)
		cast.highlight_reachable.call()
		return false
	var excluded_creature_types: Array = cast.spell.get("target_creature_type_exclusions", [])
	if not excluded_creature_types.is_empty():
		var excluded_target_coords: Array[Vector2i] = [cast.target_coord]
		excluded_target_coords.append_array(cast.command_selection)
		if cast.additional_target_coord != Vector2i(9999, 9999):
			excluded_target_coords.append(cast.additional_target_coord)
		for excluded_target_coord in excluded_target_coords:
			if SpellCastTargeting._creature_at_coord_matches_types(cast, excluded_target_coord, excluded_creature_types):
				cast.hud.add_log("[color=orange]%s has no effect on that creature type.[/color]" % cast.spell.get("name", "This spell"))
				cast.highlight_reachable.call()
				return false
	var sight_required_targets: Array[Vector2i] = [cast.target_coord]
	sight_required_targets.append_array(cast.command_selection)
	if cast.additional_target_coord != Vector2i(9999, 9999):
		sight_required_targets.append(cast.additional_target_coord)
	for sight_target_coord in sight_required_targets:
		if not SpellCastTargeting._spell_target_visible_to_active_character(cast, sight_target_coord, cast.spell):
			cast.hud.add_log("[color=orange]%s requires a target you can see.[/color]" % cast.spell.get("name", "This spell"))
			cast.highlight_reachable.call()
			return false
	return true


static func validate_area(cast: SpellCastContext) -> bool:
	cast.area_selection = SpellCastTargeting._area_selection_for_spell(cast, cast.spell)
	if cast.target_type in ["area", "cone"] and not cast.area_selection.get("success", false):
		cast.hud.add_log("[color=orange]%s[/color]" % cast.area_selection.get("message", "Invalid area selection."))
		cast.highlight_reachable.call()
		return false
	var area_point_count := int(cast.spell.get("area_point_count", 1))
	if area_point_count > 1:
		var centers: Array[Vector2i] = [cast.target_coord]
		for selected_center in cast.command_selection:
			if selected_center not in centers:
				centers.append(selected_center)
		if centers.size() != area_point_count:
			cast.hud.add_log("Choose %d distinct centers for %s." % [area_point_count, str(cast.spell.get("name", "this spell"))])
			cast.highlight_reachable.call()
			return false
		var point_range := SpellCastTargeting._spell_target_range(cast, cast.spell)
		var line_selection := str(cast.area_selection.get("shape", "")) == "line" and area_point_count == 2
		var line_valid := line_selection and centers.size() == 2 and cast.grid.has_tile(centers[0]) and cast.grid.has_tile(centers[1]) and Targeting.is_in_range(cast.spell_origin, centers[0], point_range) and Targeting.is_in_range(cast.spell_origin, centers[1], point_range) and HexUtils.get_distance(centers[0], centers[1]) <= int(cast.area_selection.get("size", 12))
		if (line_selection and not line_valid) or (not line_selection and not SpellCastTargeting.are_legal_area_centers(centers, area_point_count, cast.spell_origin, point_range, cast.grid)):
			cast.hud.add_log("Choose %d distinct legal centers within %d feet." % [area_point_count, point_range * 5])
			cast.highlight_reachable.call()
			return false
	if str(cast.area_selection.get("shape", "")) in ["cone", "cube"]:
		if not cast.grid.has_tile(cast.target_coord) or not Targeting.is_in_range(cast.spell_origin, cast.target_coord, 1) or cast.target_coord == cast.spell_origin:
			cast.hud.add_log("Choose an adjacent hex to set the direction of %s." % str(cast.spell.get("name", "this spell")))
			cast.highlight_reachable.call()
			return false
	if str(cast.spell.get("id", "")) == "conjure_animals" and (not cast.grid.has_tile(cast.target_coord) or cast.areas._is_occupied_hex(cast.caster, cast.target_coord)):
		cast.hud.add_log("Choose an unoccupied space for the Conjure Animals pack.")
		cast.highlight_reachable.call()
		return false
	if str(cast.spell.get("id", "")) == "conjure_elemental" and not cast.areas._is_unoccupied_conjure_elemental_space(cast.target_coord):
		cast.hud.add_log("Choose an unoccupied Large space for the Conjure Elemental spirit.")
		cast.highlight_reachable.call()
		return false
	if str(cast.spell.get("id", "")) == "conjure_fey" and not cast.areas._is_unoccupied_conjure_fey_space(cast.target_coord):
		cast.hud.add_log("Choose an unoccupied space for the Conjure Fey spirit.")
		cast.highlight_reachable.call()
		return false
	# Validate self-targeted teleport destinations before spending a spell slot.
	for effect in cast.spell.get("effects", []):
		if str(effect.get("type", "")) == "teleport" and (not cast.grid.has_tile(cast.target_coord) or not cast.grid.is_hex_passable(cast.target_coord) or cast.areas._is_occupied_hex(cast.caster, cast.target_coord)):
			cast.hud.add_log("[color=orange]That teleport destination is not available.[/color]")
			cast.highlight_reachable.call()
			return false
	return true


