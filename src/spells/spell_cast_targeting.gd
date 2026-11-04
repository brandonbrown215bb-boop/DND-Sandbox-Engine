## Shared target queries and cast target collection.
class_name SpellCastTargeting
extends RefCounted

static func can_target_downed(character: Character, spell: Dictionary) -> bool:
	if character == null or not character.is_downed(): return false
	if SharedSpell.uses(spell):
		return not character.is_dead()
	if str(spell.get("target", "")) in ["area", "cone"] and spell.has("damage"): return true
	return str(spell.get("id", "")) in ["cure_wounds", "healing_word", "heal", "regenerate", "power_word_heal", "spare_the_dying", "mass_cure_wounds", "mass_healing_word", "conjure_celestial", "beacon_of_hope"]

static func collect_targets(cast: SpellCastContext) -> void:
	if cast.target_type == "area" or cast.spell.get("target") == "cone":
		var radius := int(cast.area_selection.get("radius", 2))
		var cone_size := int(cast.area_selection.get("size", 3))
		var origin: Vector2i = cast.players[cast.player_index]["hex_position"]
		var area_centers: Array[Vector2i] = [cast.target_coord]
		if int(cast.spell.get("area_point_count", 1)) > 1:
			for center in cast.command_selection:
				if center not in area_centers:
					area_centers.append(center)

		if int(cast.spell.get("area_point_count", 1)) > 1 and str(cast.area_selection.get("shape", "sphere")) == "sphere":
			cast.targets = union_sphere_targets(area_centers, radius, cast.grid)
		else:
			match str(cast.area_selection.get("shape", "sphere")):
				"line" when str(cast.area_selection.get("origin", "")) == "self":
					cast.targets = Targeting.get_self_line_targets(origin, cast.target_coord, int(cast.area_selection.get("size", 1)), cast.grid)
				"line":
					cast.targets = HexUtils.hex_line(area_centers[0], area_centers[1]) if area_centers.size() == 2 and HexUtils.get_distance(area_centers[0], area_centers[1]) <= int(cast.area_selection.get("size", 12)) else []
				"point":
					cast.targets = [cast.target_coord]
				"cone":
					cast.targets = Targeting.get_cone_targets(origin, cast.target_coord, cone_size, cast.grid)
				"cube":
					cast.targets = Targeting.get_cube_targets(origin, cast.target_coord, cone_size, cast.grid)
				"square":
					cast.targets = Targeting.get_square_targets(cast.target_coord, int(cast.area_selection.get("size_feet", 10)), cast.grid)
				_:
					cast.targets = Targeting.get_sphere_targets(cast.target_coord, radius, cast.grid)
	else:
		cast.targets = [cast.target_coord]
		if SpellProjectileResolver.is_projectile(cast.spell) and not cast.command_selection.is_empty():
			var projectile_target_counts: Dictionary = {}
			var unique_projectile_targets: Array[Vector2i] = []
			for projectile_target in cast.command_selection:
				var key := "%d,%d" % [projectile_target.x, projectile_target.y]
				projectile_target_counts[key] = int(projectile_target_counts.get(key, 0)) + 1
				if projectile_target not in unique_projectile_targets:
					unique_projectile_targets.append(projectile_target)
			cast.spell["_projectile_target_counts"] = projectile_target_counts
			cast.targets = unique_projectile_targets
		elif not cast.command_selection.is_empty():
			cast.targets = cast.command_selection.duplicate()
		elif cast.additional_target_coord != Vector2i(9999, 9999) and SpellCastTargeting._valid_additional_spell_target(cast, cast.target_coord, cast.additional_target_coord, cast.spell):
			cast.targets.append(cast.additional_target_coord)

	if cast.target_type in ["area", "cone"] or str(cast.spell.get("target", "")) == "cone":
		cast.targets = cast.targets.filter(func(cell): return not CoverRules.blocks_target(CoverRules.effect_origin(cast, cell), cell, cast.grid))

	if str(cast.spell.get("id", "")) == "beacon_of_hope":
		var beacon_candidates: Array[Dictionary] = []
		var beacon_origin: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
		var beacon_range := int(cast.spell.get("range", 6))
		for player_entity in cast.players:
			var candidate: Character = player_entity.get("character")
			if candidate == null or (not candidate.is_alive and (candidate.current_hp != 0 or candidate.death_save_failures >= 3 or candidate.disintegrated)):
				continue
			if HexUtils.get_distance(beacon_origin, player_entity.get("hex_position", Vector2i.ZERO)) <= beacon_range:
				beacon_candidates.append({"id": cast.areas._spell_zone_target_id(candidate), "name": candidate.character_name})
		for monster_entity in cast.monsters:
			if not bool(monster_entity.get("is_alive", false)):
				continue
			if HexUtils.get_distance(beacon_origin, monster_entity.get("hex_position", Vector2i.ZERO)) <= beacon_range:
				beacon_candidates.append({"id": cast.areas._spell_zone_target_id(monster_entity), "name": str(monster_entity.get("name", "Creature"))})
		var beacon_target_ids: Array[String] = await cast.hud.request_beacon_of_hope_targets(beacon_candidates, cast.spell.get("_test_beacon_target_ids", []))
		cast.spell["_beacon_target_ids"] = beacon_target_ids
		cast.targets.clear()
		for beacon_target in beacon_candidates:
			if str(beacon_target.get("id", "")) not in beacon_target_ids:
				continue
			for player_entity in cast.players:
				if cast.areas._spell_zone_target_id(player_entity.get("character")) == str(beacon_target.get("id", "")):
					var target_hex: Vector2i = player_entity.get("hex_position", Vector2i.ZERO)
					if target_hex not in cast.targets:
						cast.targets.append(target_hex)
					break
			for monster_entity in cast.monsters:
				if cast.areas._spell_zone_target_id(monster_entity) == str(beacon_target.get("id", "")):
					var target_hex: Vector2i = monster_entity.get("hex_position", Vector2i.ZERO)
					if target_hex not in cast.targets:
						cast.targets.append(target_hex)
					break

	# Sleet Storm does not make an appearance save. Creatures save on their first
	# entry on a turn or when they start a turn inside the Cylinder.
	if str(cast.spell.get("id", "")) == "sleet_storm":
		cast.targets.clear()
	if str(cast.spell.get("id", "")) == "conjure_animals":
		# The pack's appearance is not a damaging movement trigger.
		cast.targets.clear()

	# "Each creature in the area who can see it": the creature at each cell must
	# be able to see the area's anchor point (light, Blinded, obscurement, cover).
	if bool(cast.spell.get("area_save_requires_sight", false)):
		var sighted_cells: Array[Vector2i] = []
		for target_hex in cast.targets:
			var viewer = _creature_entity_at(cast, target_hex)
			if viewer == null or CombatPerception.can_see_target(viewer, null, target_hex, cast.target_coord, cast.grid):
				sighted_cells.append(target_hex)
			else:
				cast.hud.add_log("%s can't see %s and is unaffected." % [_creature_name(viewer), str(cast.spell.get("name", "the spell"))])
		cast.targets = sighted_cells

	# "Each creature of your choice in the area": ask per creature.
	if bool(cast.spell.get("area_creature_choice", false)):
		var chosen_targets: Array[Vector2i] = []
		var spell_name := str(cast.spell.get("name", "Spell"))
		for target_hex in cast.targets:
			var area_creature = _creature_entity_at(cast, target_hex)
			if area_creature == null:
				continue
			var creature_name := _creature_name(area_creature)
			cast.set_resolving.call(true)
			var include_target := await cast.hud.request_reaction(cast.owner_label, "area_creature_choice:%s:%s" % [str(cast.spell.get("id", "")), creature_name], "Include %s in %s's targets?" % [creature_name, spell_name], "Only creatures you choose in the area are affected.", "Include", "%s Targets" % spell_name)
			cast.set_resolving.call(false)
			if include_target:
				chosen_targets.append(target_hex)
		cast.targets = chosen_targets

	# choice_per_target: "choose for each creature" once the area's creatures are known.
	var per_target_options: Array = SharedSpell.per_target_condition_choices(cast.spell) if SharedSpell.uses(cast.spell) else []
	if not per_target_options.is_empty():
		var picks: Dictionary = cast.spell.get("_chosen_conditions", {}).duplicate(true)
		var committed_choices := bool(cast.spell.get("_condition_choices_ready", false))
		var spell_label := str(cast.spell.get("name", "Spell"))
		var any_scoped := false
		for target_hex in cast.targets:
			if not SpellCastTargeting._has_spell_creature_at(cast, target_hex, cast.spell):
				continue
			var picked_creature = _creature_entity_at(cast, target_hex)
			if picked_creature == null:
				continue
			var picked_id := SpellEffects.caster_id(picked_creature) if picked_creature is Character else str(picked_creature.get("id", ""))
			if picks.has(picked_id):
				if CombatAction.condition_rule(str(picks[picked_id]), "attitude_indifferent"): any_scoped = true
				continue
			cast.set_resolving.call(true)
			var pick := await cast.hud.request_damage_type_choice(per_target_options, "%s: %s" % [spell_label, _creature_name(picked_creature)])
			# A reaction can move another eligible creature into an already-paid
			# area. It still needs an explicit effect choice; dismissing that late
			# menu cannot silently exclude it or choose an effect on the player's behalf.
			while pick not in per_target_options and committed_choices:
				pick = await cast.hud.request_damage_type_choice(per_target_options, "%s: choose an effect for %s" % [spell_label, _creature_name(picked_creature)])
			cast.set_resolving.call(false)
			if pick not in per_target_options:
				cast.spell["_condition_choice_cancelled"] = true
				cast.targets.clear()
				return
			picks[picked_id] = pick
			if CombatAction.condition_rule(pick, "attitude_indifferent"): any_scoped = true
		cast.spell["_chosen_conditions"] = picks
		if any_scoped and not bool(cast.spell.get("_attitude_choices_ready", false)):
			var scope_ids: Array = []
			var scope_candidates: Array = []
			for player_entity in cast.players:
				var scoped: Character = player_entity.get("character")
				if scoped == null: continue
				scope_candidates.append({"id": SpellEffects.caster_id(scoped), "name": scoped.character_name})
			for monster in cast.monsters:
				if bool(monster.get("is_alive", false)):
					scope_candidates.append({"id": str(monster.get("id", "")), "name": str(monster.get("name", "Creature"))})
			for scoped in scope_candidates:
				cast.set_resolving.call(true)
				var include := await cast.hud.request_reaction(cast.owner_label, "attitude_scope:%s:%s" % [str(cast.spell.get("id", "")), str(scoped.id)], "Make the affected creatures Indifferent toward %s?" % str(scoped.name), "Only creatures you choose are covered.", "Include", "%s Indifference" % spell_label)
				cast.set_resolving.call(false)
				if include and not str(scoped.id).is_empty() and scoped.id not in scope_ids: scope_ids.append(scoped.id)
			cast.spell["_attitude_scope_ids"] = scope_ids
			cast.spell["_attitude_choices_ready"] = true
		cast.spell["_condition_choices_ready"] = true

	if str(cast.spell.get("id", "")) == "mass_cure_wounds":
		var selected_heal_targets: Array[Vector2i] = []
		var included_count := 0
		for target_hex in cast.targets:
			if not SpellCastTargeting._has_spell_creature_at(cast, target_hex, cast.spell):
				continue
			var target_name := "Creature"
			for player_entity in cast.players:
				var candidate: Character = player_entity.get("character")
				if player_entity.get("hex_position", Vector2i.ZERO) == target_hex and candidate != null:
					target_name = candidate.character_name
					break
			if target_name == "Creature":
				for monster_entity in cast.monsters:
					if monster_entity.get("hex_position", Vector2i.ZERO) == target_hex:
						target_name = str(monster_entity.get("name", "Creature"))
						break
			if included_count >= 6:
				cast.hud.add_log("%s is outside Mass Cure Wounds' six-creature limit." % target_name)
				continue
			cast.set_resolving.call(true)
			var include_target := await cast.hud.request_reaction(cast.owner_label, "mass_cure_wounds:%s" % target_name, "Include %s in Mass Cure Wounds?" % target_name, "Choose up to six creatures in the Sphere.", "Include", "Mass Cure Wounds Targets")
			cast.set_resolving.call(false)
			if include_target:
				selected_heal_targets.append(target_hex)
				included_count += 1
		cast.targets = selected_heal_targets

	# Spike Growth has no casting-time save or damage. Its damage belongs only to
	# later movement through the persistent zone.
	if str(cast.spell.get("id", "")) == "spike_growth":
		cast.targets.clear()


static func _creature_entity_at(cast: SpellCastContext, coord: Vector2i):
	for player_entity in cast.players:
		var candidate: Character = player_entity.get("character")
		if player_entity.get("hex_position", Vector2i.ZERO) == coord and candidate != null and candidate.is_alive:
			return candidate
	for monster_entity in cast.monsters:
		if monster_entity.get("hex_position", Vector2i.ZERO) == coord and monster_entity.get("is_alive", false):
			return monster_entity
	return null


static func _creature_name(entity) -> String:
	return entity.character_name if entity is Character else str(entity.get("name", "Creature"))


static func _spell_target_range(cast: SpellCastContext, spell_data: Dictionary) -> int:
	if not SharedSpell.weapon_attack_effect(spell_data).is_empty() and cast.caster != null:
		var equipped_weapon := DataLoader.get_item(cast.caster.inventory.get_weapon())
		if not equipped_weapon.is_empty():
			return maxi(1, CombatAction.weapon_range_hexes(equipped_weapon))
	var max_range := CombatAction.spell_range_in_hexes(spell_data, cast.caster.level if cast.caster != null else 1)
	if max_range == 0:
		for effect in spell_data.get("effects", []):
			if str(effect.get("type", "")) == "area_selection" and str(effect.get("shape", "")) in ["cone", "cube"]:
				return 1 # Select one adjacent hex to indicate direction; range metamagic does not expand a self-originating area.
			if str(effect.get("type", "")) == "area_selection" and str(effect.get("shape", "")) == "line" and str(effect.get("origin", "")) == "self":
				return maxi(1, int(effect.get("size", 1))) # Any hex along the intended line sets its direction.
	if bool(spell_data.get("_metamagic_distant", false)):
		max_range = SorcererRules.distant_spell_range(max_range)
	if cast.caster != null:
		max_range += int(CombatAction.spell_range_bonus_feet(cast.caster, spell_data) / 5)
	for effect in spell_data.get("effects", []):
		if str(effect.get("type", "")) == "teleport":
			max_range = maxi(max_range, int(effect.get("distance", 0)))
	return max_range


static func _spell_grants_additional_target(cast: SpellCastContext, character: Character, spell_data: Dictionary) -> bool:
	if character == null:
		return false
	if SpellCastTargeting._spell_upcast_maximum_targets(cast, spell_data) > 1:
		return true
	if int(spell_data.get("_metamagic_twinned_extra_targets", 0)) > 0:
		return true
	var spell_id := str(spell_data.get("id", ""))
	for feature in character.features:
		for effect in feature.get("effects", []) + feature.get("passive_effects", []):
			if effect.get("type", "") == "additional_spell_target" and spell_id in effect.get("spells", []):
				return true
	return false


static func _spell_upcast_maximum_targets(cast: SpellCastContext, spell_data: Dictionary) -> int:
	var upcast: Dictionary = spell_data.get("upcast", {})
	var extra_per_level := int(upcast.get("additional_targets_per_level", 0))
	var base_level := int(spell_data.get("level", 1))
	var slot_level := int(spell_data.get("_selected_spell_slot_level", base_level))
	return TetherRules.maximum_targets(spell_data, maxi(1, int(spell_data.get("base_targets", 1))) + maxi(0, slot_level - base_level) * maxi(0, extra_per_level))


static func _magic_missile_dart_total(cast: SpellCastContext, spell_data: Dictionary) -> int:
	var base_level := int(spell_data.get("level", 1))
	var slot_level := int(spell_data.get("_selected_spell_slot_level", base_level))
	var upcast: Dictionary = spell_data.get("upcast", {})
	return maxi(1, int(spell_data.get("dart_count", 3)) + maxi(0, slot_level - base_level) * int(upcast.get("extra_darts_per_level", 1)))


static func _spell_projectile_total(cast: SpellCastContext, spell_data: Dictionary) -> int:
	spell_data = SpellProjectileResolver.view(spell_data) if spell_data.get("projectiles") is Dictionary else spell_data
	if spell_data.has("damage_per_ray"):
		return CombatAction.scorching_ray_count(cast.caster, spell_data, int(spell_data.get("_selected_spell_slot_level", spell_data.get("level", 2))))
	return SpellCastTargeting._magic_missile_dart_total(cast, spell_data)


static func _valid_additional_spell_target(cast: SpellCastContext, first_target: Vector2i, candidate: Vector2i, spell_data: Dictionary, prior_targets: Array[Vector2i] = []) -> bool:
	var is_chain_lightning := str(spell_data.get("id", "")) == "chain_lightning"
	var valid_target := SpellCastTargeting._has_spell_target_at(cast, candidate, spell_data) if is_chain_lightning else SpellCastTargeting._has_spell_creature_at(cast, candidate, spell_data)
	if candidate == first_target or not valid_target:
		return false
	if not is_chain_lightning and not SpellCastTargeting._creature_at_coord_matches_types(cast, candidate, spell_data.get("target_creature_types", [])):
		return false
	if not is_chain_lightning and not spell_data.get("target_creature_type_exclusions", []).is_empty() and SpellCastTargeting._creature_at_coord_matches_types(cast, candidate, spell_data.get("target_creature_type_exclusions", [])):
		return false
	if is_chain_lightning:
		var primary_target := prior_targets[0] if not prior_targets.is_empty() else first_target
		return Targeting.is_in_range(primary_target, candidate, 6)
	if int(spell_data.get("base_targets", 1)) > 1 or int(spell_data.get("upcast", {}).get("additional_targets_per_level", 0)) > 0:
		var origin := FamiliarSpellDelivery.origin(cast.caster, cast.players, spell_data, cast.players[cast.player_index].get("hex_position", Vector2i.ZERO))
		return Targeting.is_in_range(origin, candidate, SpellCastTargeting._spell_target_range(cast, spell_data))
	if int(spell_data.get("_metamagic_twinned_extra_targets", 0)) > 0:
		var origin := FamiliarSpellDelivery.origin(cast.caster, cast.players, spell_data, cast.players[cast.player_index].get("hex_position", Vector2i.ZERO))
		return Targeting.is_in_range(origin, candidate, SpellCastTargeting._spell_target_range(cast, spell_data))
	return SpellCastTargeting._spell_grants_additional_target(cast, cast.caster, spell_data) and Targeting.is_in_range(first_target, candidate, 2)


static func are_legal_chain_targets(targets: Array[Vector2i], origin: Vector2i, first_range: int, link_range: int, maximum_targets: int, grid: HexGrid) -> bool:
	if grid == null or targets.is_empty() or targets.size() > maximum_targets:
		return false
	var seen: Array[Vector2i] = []
	for index in targets.size():
		var target := targets[index]
		if target in seen or not grid.has_tile(target):
			return false
		if index == 0:
			if not Targeting.is_in_range(origin, target, first_range):
				return false
		elif not Targeting.is_in_range(targets[0], target, link_range):
			return false
		seen.append(target)
	return true


static func _creature_at_coord_matches_types(cast: SpellCastContext, coord: Vector2i, required_types: Array) -> bool:
	if required_types.is_empty():
		return true
	for player in cast.players:
		var character: Character = player.get("character")
		if player.get("hex_position", Vector2i.ZERO) == coord and character != null and (character.is_alive or character.is_downed()):
			var creature_type := character.get_creature_type()
			return creature_type in required_types
	for monster in cast.monsters:
		if monster.get("hex_position", Vector2i.ZERO) == coord and monster.get("is_alive", false):
			return str(monster.get("creature_type", "")) in required_types
	return false


static func _spell_target_visible_to_active_character(cast: SpellCastContext, coord: Vector2i, spell_data: Dictionary) -> bool:
	var origin: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
	var delivery_origin := FamiliarSpellDelivery.origin(cast.caster, cast.players, spell_data, origin)
	if not Targeting.has_line_of_effect(delivery_origin, coord, cast.grid):
		return false
	var requires_sight := bool(spell_data.get("requires_target_sight", false))
	if str(spell_data.get("target", "single")) not in ["single", "single_ally", "multi"]:
		return not requires_sight or CombatPerception.can_see_target(cast.caster, null, origin, coord, cast.grid)
	for player in cast.players:
		var character: Character = player.get("character")
		if player.get("hex_position", Vector2i.ZERO) == coord and character != null and (character.is_alive or can_target_downed(character, spell_data)):
			return CombatPerception.can_see_target(cast.caster, character, origin, coord, cast.grid) if requires_sight else CombatPerception.can_locate_target(cast.caster, character, origin, coord, cast.grid)
	for monster in cast.monsters:
		if monster.get("hex_position", Vector2i.ZERO) == coord and monster.get("is_alive", false):
			return CombatPerception.can_see_target(cast.caster, monster, origin, coord, cast.grid) if requires_sight else CombatPerception.can_locate_target(cast.caster, monster, origin, coord, cast.grid)
	return not requires_sight or CombatPerception.can_see_target(cast.caster, null, origin, coord, cast.grid)


static func _has_spell_creature_at(cast: SpellCastContext, coord: Vector2i, spell: Dictionary) -> bool:
	if str(spell.get("id", "")) in ["revivify", "gentle_repose"]:
		for player in cast.players:
			var body_target: Character = player.get("character")
			if player.get("hex_position", Vector2i.ZERO) == coord and body_target != null and body_target.is_dead(): return true
		return false
	for player in cast.players:
		var target: Character = player.get("character")
		if player.get("hex_position", Vector2i.ZERO) == coord and can_target_downed(target, spell):
			return true
	return cast.areas._has_creature_at(coord)


static func _has_spell_target_at(cast: SpellCastContext, coord: Vector2i, spell: Dictionary) -> bool:
	var object_target_available := false
	if str(spell.get("id", "")) == "chain_lightning":
		object_target_available = not SpellCastTargeting.chain_target_options(cast, coord).is_empty()
	elif bool(spell.get("targets_objects", false)) or str(spell.get("id", "")) == "fire_bolt":
		for object in CombatObjectRules.all_at(cast.grid, coord, cast.caster):
			if CombatObjectRules.can_take_spell_damage(object):
				object_target_available = true
				break
	return SpellCastTargeting._has_spell_creature_at(cast, coord, spell) or object_target_available


static func chain_target_options(cast: SpellCastContext, coord: Vector2i) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for player in cast.players:
		var character: Character = player.get("character")
		if character == null or not character.is_alive or player.get("hex_position", Vector2i.ZERO) != coord:
			continue
		var character_id := character.character_id if not character.character_id.is_empty() else "runtime_%d" % character.get_instance_id()
		options.append({"id": "player:%s" % character_id, "label": character.character_name, "kind": "creature"})
	for monster in cast.monsters:
		if not monster.get("is_alive", false) or monster.get("hex_position", Vector2i.ZERO) != coord:
			continue
		options.append({"id": "monster:%s" % str(monster.get("id", "")), "label": str(monster.get("name", "Creature")), "kind": "creature"})
	for object in CombatObjectRules.all_at(cast.grid, coord, cast.caster):
		if CombatObjectRules.can_target(object):
			options.append({"id": "object:%s" % CombatObjectRules.target_key(object), "label": str(object.get("name", "Object")), "kind": "object"})
	for player in cast.players:
		if player.get("hex_position", Vector2i.ZERO) != coord:
			continue
		var character: Character = player.get("character")
		if character == null:
			continue
		var copy_ordinals: Dictionary = {}
		for record in character.inventory.owned_instances():
			var instance_id := str(record.get("instance_id", ""))
			var definition_id := str(record.get("definition_id", ""))
			copy_ordinals[definition_id] = int(copy_ordinals.get(definition_id, 0)) + 1
			var worn := false
			var location := "carried"
			for slot in character.inventory.copies.equipped:
				if str(character.inventory.copies.equipped[slot]) == instance_id:
					worn = true
					location = Inventory.Slot.keys()[int(slot)].to_lower().replace("_", " ").capitalize()
					break
			var carried_object := CombatObjectRules.make_owned_item(record, character.character_id, worn, coord)
			if CombatObjectRules.can_target(carried_object):
				options.append({"id": "object:%s" % instance_id, "label": "%s · %d (%s)" % [str(carried_object.get("name", "Item")), int(copy_ordinals[definition_id]), location], "kind": "worn item" if worn else "carried item"})
	return options


static func is_chain_target_selected(cast: SpellCastContext, coord: Vector2i, target_id: String) -> bool:
	if target_id.begins_with("player:"):
		for player in cast.players:
			var character: Character = player.get("character")
			if character == null:
				continue
			var character_id := character.character_id if not character.character_id.is_empty() else "runtime_%d" % character.get_instance_id()
			if character_id == target_id.trim_prefix("player:") and character.is_alive and player.get("hex_position", Vector2i.ZERO) == coord:
				return true
		return false
	if target_id.begins_with("monster:"):
		for monster in cast.monsters:
			if str(monster.get("id", "")) == target_id.trim_prefix("monster:") and bool(monster.get("is_alive", false)) and monster.get("hex_position", Vector2i.ZERO) == coord:
				return true
		return false
	if target_id.begins_with("object:"):
		var object_key := target_id.trim_prefix("object:")
		if CombatObjectRules.can_target(CombatObjectRules.by_key(cast.grid, coord, object_key, cast.caster)):
			return true
		var owned := CombatObjectRules.owned_item_record_at(cast.players, coord, object_key)
		if not owned.is_empty():
			return CombatObjectRules.can_target(CombatObjectRules.make_owned_item(owned["record"], owned["character"].character_id, object_key in owned["character"].inventory.copies.equipped.values(), coord))
	return false


## Return the union of multiple spherical footprints. A hex in overlapping
## areas appears once, so an occupant is resolved only once.
static func union_sphere_targets(centers: Array[Vector2i], radius: int, grid: HexGrid) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	if grid == null:
		return targets
	for center in centers:
		for target in Targeting.get_sphere_targets(center, radius, grid):
			if target not in targets:
				targets.append(target)
	return targets


static func are_legal_area_centers(centers: Array[Vector2i], required_count: int, origin: Vector2i, range_hexes: int, grid: HexGrid) -> bool:
	if grid == null or required_count < 1 or centers.size() != required_count:
		return false
	var seen: Array[Vector2i] = []
	for center in centers:
		if center in seen or not grid.has_tile(center) or not Targeting.is_in_range(origin, center, range_hexes):
			return false
		seen.append(center)
	return true


static func _identify_creature_id_at(cast: SpellCastContext, coord: Vector2i) -> String:
	for entry in cast.players:
		var character: Character = entry.get("character")
		if character != null and character.is_alive and entry.get("hex_position", Vector2i.ZERO) == coord:
			return cast.areas._spell_zone_target_id(character)
	for monster in cast.monsters:
		if bool(monster.get("is_alive", false)) and monster.get("hex_position", Vector2i.ZERO) == coord:
			return cast.areas._spell_zone_target_id(monster)
	return ""


static func _area_selection_for_spell(cast: SpellCastContext, spell_data: Dictionary) -> Dictionary:
	var target_type := str(spell_data.get("target", "single"))
	if target_type not in ["area", "cone"]:
		return {"success": true, "type": "single_target", "persistent": false}

	var selection_effect: Dictionary = {}
	for effect in spell_data.get("effects", []):
		if str(effect.get("type", "")) == "area_selection":
			selection_effect = effect.duplicate(true)
			break
	if selection_effect.is_empty():
		selection_effect = {
			"type": "area_selection",
			"shape": "cone" if target_type == "cone" else "sphere",
			"size": int(spell_data.get("cone_size", 3)),
			"radius": int(spell_data.get("area_radius", 2)),
		}
	return EventResolver.resolve_area_selection(selection_effect)


static func _creature_at_coord_matches_sizes(cast: SpellCastContext, coord: Vector2i, required_sizes: Array) -> bool:
	if required_sizes.is_empty():
		return true
	for player in cast.players:
		var character: Character = player.get("character")
		if character != null and character.is_alive and player.get("hex_position", Vector2i.ZERO) == coord:
			var character_size := character.get_creature_size()
			return character_size in required_sizes.map(func(size): return str(size).to_lower())
	for monster in cast.monsters:
		if monster.get("hex_position", Vector2i.ZERO) == coord and monster.get("is_alive", false):
			return str(monster.get("size", "")).to_lower() in required_sizes.map(func(size): return str(size).to_lower())
	return false


static func _creature_at_coord_has_condition(cast: SpellCastContext, coord: Vector2i, condition: String) -> bool:
	for player in cast.players:
		var character: Character = player.get("character")
		if character != null and character.is_alive and player.get("hex_position", Vector2i.ZERO) == coord and character.has_condition(condition):
			return true
	for monster in cast.monsters:
		if monster.get("hex_position", Vector2i.ZERO) == coord and monster.get("is_alive", false) and CombatAction.has_condition(monster, condition):
			return true
	return false


