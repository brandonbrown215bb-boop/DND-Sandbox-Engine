## Conjured spirits and caster-centered emanations.
class_name SpellZoneConjurations
extends RefCounted

static func _create_antilife_shell_zone(zones: CombatSpellZones, active_character: Character, source_id: String) -> void:
	if active_character == null or source_id.is_empty():
		return
	var caster_hex := zones._character_combat_hex(active_character)
	var effect_cast := SpellEffects.begin_cast(active_character, DataLoader.get_spell("antilife_shell"))
	effect_cast["source_id"] = source_id
	SpellEffects.records(active_character)[source_id] = effect_cast
	active_character.concentrating_on["effect_source"] = source_id
	active_character.concentrating_on["antilife_shell_source_id"] = source_id
	active_character.concentrating_on["duration_rounds_remaining"] = 10
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "antilife_shell",
		"caster_id": active_character.character_id,
		"center": caster_hex,
		"radius_hexes": 2,
		"rounds_remaining": 10,
		"concentration": true,
	}
	zones.hud.add_log("A 10-foot Antilife Shell surrounds %s for up to 1 minute." % active_character.character_name)
	zones.refresh_grid.call()
	zones.highlight_reachable.call()

static func _create_conjure_animals_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i, source_id: String, slot_level: int) -> void:
	if active_character == null or source_id.is_empty() or not zones.hex_grid.has_tile(center) or zones._is_occupied_hex(active_character, center):
		return
	var coords := Targeting.get_sphere_targets(center, 2, zones.hex_grid)
	if coords.is_empty():
		return
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "conjure_animals",
		"caster_id": active_character.character_id,
		"center": center,
		"coords": coords,
		"radius_hexes": 2,
		"slot_level": slot_level,
		"save_dc": active_character.get_spell_save_dc(),
		"damage_formula": "%dd10" % (3 + maxi(0, slot_level - 3)),
		"last_trigger_turn_by_target": {},
		"rounds_remaining": 100,
		"concentration": true,
	}
	active_character.concentrating_on["conjure_animals_source_id"] = source_id
	active_character.concentrating_on["duration_rounds_remaining"] = 100
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	active_character.feature_uses.erase("conjure_animals_pack_moved_this_turn")
	active_character.feature_uses.erase("conjure_animals_moved_this_turn")
	zones._refresh_conjure_animals_strength_advantage(active_character)
	zones.hud.add_log("[color=cyan]A spectral animal pack appears for up to 10 minutes. After you move, you can move it up to 30 feet once per turn.[/color]")
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _create_conjure_celestial_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i, source_id: String, slot_level: int, initial_targets: Dictionary) -> void:
	if active_character == null or source_id.is_empty() or not zones.hex_grid.has_tile(center):
		return
	var coords := Targeting.get_sphere_targets(center, 2, zones.hex_grid)
	if coords.is_empty():
		return
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "conjure_celestial",
		"caster_id": active_character.character_id,
		"center": center,
		"coords": coords,
		"radius_hexes": 2,
		"cylinder_height_feet": 40,
		"bright_light": true,
		"slot_level": slot_level,
		"save_dc": active_character.get_spell_save_dc(),
		"last_trigger_turn_by_target": initial_targets.duplicate(true),
		"rounds_remaining": 100,
		"concentration": true,
	}
	active_character.concentrating_on["conjure_celestial_source_id"] = source_id
	active_character.concentrating_on["duration_rounds_remaining"] = 100
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	active_character.feature_uses.erase("conjure_celestial_moved_this_turn")
	active_character.feature_uses.erase("conjure_celestial_pillar_moved_this_turn")
	zones.hud.add_log("[color=cyan]A pillar of light fills a 10-foot-radius, 40-foot-high Cylinder with Bright Light for up to 10 minutes.[/color]")
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _apply_conjure_celestial_healing(zones: CombatSpellZones, target, caster: Character, slot_level: int, ability: String = "") -> int:
	if target == null or caster == null:
		return 0
	var healing_dice := 4 + maxi(0, slot_level - 7)
	var healing_formula := "%dd12" % healing_dice
	var amount := Dice.parse_dice_string(healing_formula, {}, caster)
	amount = SpellEffects.maximize_healing(target, amount, Dice.maximum_dice_string(healing_formula))
	amount += caster.ability_scores.get_ability_modifier(ability if ability in AbilityScores.ABILITIES else caster.get_spellcasting_ability())
	var healing := 0
	if target is Character:
		healing = target.heal(maxi(0, amount))
	else:
		var monster_hp := int(target.get("current_hp", 0))
		if not CombatAction.is_healing_suppressed(target):
			healing = mini(maxi(0, amount), maxi(0, int(target.get("max_hp", monster_hp)) - monster_hp))
			target["current_hp"] = monster_hp + healing
			if healing > 0:
				target["is_alive"] = true
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	zones.hud.add_log("%s regains %d Hit Points from Conjure Celestial's Healing Light." % [target_name, healing])
	return healing


static func _resolve_conjure_celestial_zone_trigger(zones: CombatSpellZones, target, zone: Dictionary) -> Dictionary:
	var target_id := zones._spell_zone_target_id(target)
	if target_id.is_empty():
		return {}
	var last_trigger_turn_by_target: Dictionary = zone.get("last_trigger_turn_by_target", {})
	var current_turn := zones._current_spell_trigger_turn()
	if str(last_trigger_turn_by_target.get(target_id, "")) == current_turn:
		return {"success": true, "saved": true, "skipped": true, "reason": "already_triggered_this_turn"}
	var caster := zones._spell_zone_caster(zone)
	if caster == null:
		return {}
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	var light_choice := str(zone.get("test_light_choice", ""))
	if light_choice.is_empty():
		light_choice = await zones.hud.request_conjure_celestial_light(target_name)
	if light_choice not in ["healing", "searing"]:
		return {"success": false, "cancelled": true}
	last_trigger_turn_by_target[target_id] = current_turn
	zone["last_trigger_turn_by_target"] = last_trigger_turn_by_target
	if light_choice == "healing":
		var healing := SpellZoneConjurations._apply_conjure_celestial_healing(zones, target, caster, int(zone.get("slot_level", 7)), str(zone.get("spellcasting_ability", "")))
		return {"success": true, "healing": healing, "light": "healing"}
	var spell_data: Dictionary = DataLoader.get_spell("conjure_celestial").duplicate(true)
	spell_data["_ongoing_zone_trigger"] = true
	spell_data["_save_dc_override"] = int(zone.get("save_dc", caster.get_spell_save_dc()))
	spell_data["_skip_counterspell"] = true
	var decisions: Dictionary = await zones.collect_save_decisions.call(target, "Conjure Celestial", spell_data)
	var result := CombatAction.resolve_spell(caster, target, spell_data, false, decisions, [], int(zone.get("slot_level", 7)), 0)
	var damage_taken := int(result.get("damage", 0))
	zones.hud.add_log("%s %s the Conjure Celestial Dexterity save (%d vs DC %d), taking %d Radiant damage." % [target_name, "succeeds on" if bool(result.get("saved", false)) else "fails", int(result.get("save_total", 0)), int(zone.get("save_dc", 0)), int(result.get("damage", 0))])
	if target is Character and damage_taken > 0:
		await zones.check_concentration.call(target, damage_taken)
	elif target is Dictionary and int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		zones.tracker.remove_combatant(str(target.get("id", "")))
		zones.enemy_defeated.call(target, caster)
	if target is Character and not target.is_alive:
		zones.end_concentration.call(target)
	return result


static func _create_conjure_elemental_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i, source_id: String, slot_level: int, element: String, damage_type: String) -> void:
	if active_character == null or source_id.is_empty() or not zones._is_unoccupied_conjure_elemental_space(center):
		return
	var coords := Targeting.get_sphere_targets(center, 1, zones.hex_grid)
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "conjure_elemental",
		"caster_id": active_character.character_id,
		"center": center,
		"coords": coords,
		"size": "Large",
		"intangible": true,
		"element": element,
		"damage_type": damage_type,
		"slot_level": slot_level,
		"save_dc": active_character.get_spell_save_dc(),
		"restrained_targets": [],
		"rounds_remaining": 100,
		"concentration": true,
	}
	active_character.concentrating_on["conjure_elemental_source_id"] = source_id
	active_character.concentrating_on["duration_rounds_remaining"] = 100
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	zones.hud.add_log("[color=cyan]A Large, intangible %s spirit appears.[/color]" % element.capitalize())
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _conjure_elemental_has_restrained_target(zones: CombatSpellZones, zone: Dictionary) -> bool:
	for target in zone.get("restrained_targets", []):
		if target is Character and target.is_alive and zones._has_spell_condition_source(target, str(zone.get("source_id", ""))):
			return true
		if target is Dictionary and bool(target.get("is_alive", true)) and zones._has_spell_condition_source(target, str(zone.get("source_id", ""))):
			return true
	return false


static func _resolve_conjure_elemental_save(zones: CombatSpellZones, target, zone: Dictionary, repeat_save: bool = false) -> Dictionary:
	var target_id := zones._spell_zone_target_id(target)
	var source_id := str(zone.get("source_id", ""))
	if target_id.is_empty() or source_id.is_empty():
		return {}
	var is_restrained_by_spirit := zones._has_spell_condition_source(target, source_id)
	if repeat_save and not is_restrained_by_spirit:
		return {"success": false, "skipped": true, "reason": "not_restrained_by_this_spirit"}
	if not repeat_save and SpellZoneConjurations._conjure_elemental_has_restrained_target(zones, zone):
		return {"success": true, "saved": true, "skipped": true, "reason": "spirit_already_restraining"}
	var caster := zones._spell_zone_caster(zone)
	if caster == null:
		return {}
	var spell_data: Dictionary = DataLoader.get_spell("conjure_elemental").duplicate(true)
	spell_data["damage"] = "4d8" if repeat_save else "8d8"
	spell_data["damage_type"] = str(zone.get("damage_type", "lightning"))
	spell_data["half_on_save"] = false
	spell_data["_save_dc_override"] = int(zone.get("save_dc", caster.get_spell_save_dc()))
	spell_data["_skip_counterspell"] = true
	var slot_level := int(zone.get("slot_level", 5))
	var decisions: Dictionary = await zones.collect_save_decisions.call(target, "Conjure Elemental", spell_data)
	var result := CombatAction.resolve_spell(caster, target, spell_data, false, decisions, [], slot_level, 0)
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	if bool(result.get("saved", false)):
		if repeat_save:
			CombatAction.remove_condition_source(target, source_id, ["restrained"])
			var targets: Array = zone.get("restrained_targets", [])
			targets.erase(target)
			zone["restrained_targets"] = targets
		zones.hud.add_log("%s succeeds on the Conjure Elemental Dexterity save; %s." % [target_name, "it is no longer Restrained by the spirit" if repeat_save else "it avoids the spirit"])
	else:
		if not repeat_save:
			CombatAction.apply_condition(target, "restrained", 1000, source_id)
			var targets: Array = zone.get("restrained_targets", [])
			if zones._has_spell_condition_source(target, source_id) and target not in targets:
				targets.append(target)
			zone["restrained_targets"] = targets
		zones.hud.add_log("%s fails the Conjure Elemental Dexterity save and takes %d %s damage%s." % [target_name, int(result.get("damage", 0)), str(zone.get("damage_type", "elemental")).capitalize(), " again while Restrained" if repeat_save else " and is Restrained"])
	var damage_taken := int(result.get("damage", 0))
	if target is Character and damage_taken > 0:
		await zones.check_concentration.call(target, damage_taken)
	elif target is Dictionary and int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		zones.tracker.remove_combatant(str(target.get("id", "")))
		zones.enemy_defeated.call(target, caster)
	if target is Character and not target.is_alive:
		zones.end_concentration.call(target)
	return result


static func _create_conjure_fey_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i, source_id: String, slot_level: int) -> String:
	if active_character == null or source_id.is_empty() or not zones._is_unoccupied_conjure_fey_space(center):
		return ""
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "conjure_fey",
		"caster_id": active_character.character_id,
		"center": center,
		"size": "Medium",
		"slot_level": slot_level,
		"frightened_targets": [],
		"cast_turn": zones._current_spell_trigger_turn(),
		"rounds_remaining": 100,
		"concentration": true,
	}
	active_character.concentrating_on["conjure_fey_source_id"] = source_id
	active_character.concentrating_on["conjure_fey_cast_turn"] = zones._current_spell_trigger_turn()
	active_character.concentrating_on["duration_rounds_remaining"] = 100
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	zones.hud.add_log("[color=cyan]A Medium Conjure Fey spirit appears.[/color]")
	zones.refresh_grid.call()
	zones.highlight_reachable.call()
	return source_id


static func _create_conjure_minor_elementals_zone(zones: CombatSpellZones, active_character: Character, source_id: String, slot_level: int) -> String:
	if active_character == null or source_id.is_empty():
		return ""
	var formula := "%dd8" % (2 + maxi(0, slot_level - 4))
	var center := zones._character_combat_hex(active_character)
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "conjure_minor_elementals",
		"caster_id": active_character.character_id,
		"center": center,
		"radius_hexes": int(DataLoader.get_spell("conjure_minor_elementals").get("emanation_radius_hexes", 3)),
		"slot_level": slot_level,
		"attack_damage_formula": formula,
		"damage_type_choices": ["acid", "cold", "fire", "lightning"],
		"enemy_difficult_terrain": true,
		"rounds_remaining": 100,
		"concentration": true,
	}
	active_character.concentrating_on["conjure_minor_elementals_source_id"] = source_id
	active_character.concentrating_on["duration_rounds_remaining"] = 100
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	zones.hud.add_log("[color=cyan]Elemental spirits swirl in a 15-foot Emanation around %s; enemy movement there is Difficult Terrain.[/color]" % active_character.character_name)
	zones.refresh_grid.call()
	zones.highlight_reachable.call()
	return source_id


static func _create_conjure_woodland_beings_zone(zones: CombatSpellZones, active_character: Character, source_id: String, slot_level: int) -> String:
	if active_character == null or source_id.is_empty():
		return ""
	var spell: Dictionary = DataLoader.get_spell("conjure_woodland_beings")
	var radius := int(spell.get("emanation_radius_hexes", 2))
	var formula := CombatAction.spell_damage_formula(active_character, spell, slot_level)
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "conjure_woodland_beings",
		"caster_id": active_character.character_id,
		"center": zones._character_combat_hex(active_character),
		"radius_hexes": radius,
		"slot_level": slot_level,
		"save_dc": active_character.get_spell_save_dc(),
		"damage_formula": formula,
		"last_trigger_turn_by_target": {},
		"rounds_remaining": 100,
		"concentration": true,
	}
	active_character.concentrating_on["conjure_woodland_beings_source_id"] = source_id
	active_character.concentrating_on["duration_rounds_remaining"] = 100
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	active_character.feature_uses["conjure_woodland_beings_disengage_source_id"] = source_id
	zones.hud.add_log("[color=cyan]Nature spirits swirl in a 10-foot Emanation around %s for up to 10 minutes.[/color]" % active_character.character_name)
	zones.refresh_grid.call()
	zones.highlight_reachable.call()
	return source_id


static func _create_aura_of_life_zone(zones: CombatSpellZones, active_character: Character, source_id: String) -> String:
	if active_character == null or source_id.is_empty():
		return ""
	var spell: Dictionary = DataLoader.get_spell("aura_of_life")
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "aura_of_life",
		"caster_id": active_character.character_id,
		"radius_hexes": int(spell.get("emanation_radius_hexes", 6)),
		"rounds_remaining": 100,
		"concentration": true,
		"last_revive_turn_by_target": {},
	}
	active_character.concentrating_on["aura_of_life_source_id"] = source_id
	active_character.concentrating_on["duration_rounds_remaining"] = 100
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	zones.hud.add_log("[color=cyan]A life-protecting 30-foot Emanation surrounds %s.[/color]" % active_character.character_name)
	zones.refresh_grid.call()
	zones.highlight_reachable.call()
	return source_id


static func _create_spirit_guardians_zone(zones: CombatSpellZones, active_character: Character, pending_spell_data: Dictionary, source_id: String, slot_level: int) -> String:
	if active_character == null or source_id.is_empty():
		return ""
	var spell: Dictionary = DataLoader.get_spell("spirit_guardians")
	var radius := int(spell.get("emanation_radius_hexes", 3))
	var formula := CombatAction.spell_damage_formula(active_character, spell, slot_level)
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "spirit_guardians",
		"caster_id": active_character.character_id,
		"center": zones._character_combat_hex(active_character),
		"radius_hexes": radius,
		"slot_level": slot_level,
		"save_dc": active_character.get_spell_save_dc(),
		"damage_formula": formula,
		"damage_type": str(pending_spell_data.get("_spirit_guardians_damage_type", "radiant")),
		"exempt_target_ids": pending_spell_data.get("_spirit_guardians_exempt_target_ids", []).duplicate(),
		"last_trigger_turn_by_target": {},
		"rounds_remaining": 100,
		"concentration": true,
	}
	active_character.concentrating_on["spirit_guardians_source_id"] = source_id
	active_character.concentrating_on["duration_rounds_remaining"] = 100
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	zones.hud.add_log("[color=cyan]Protective spirits surround %s in a 15-foot Emanation (%s damage).[/color]" % [active_character.character_name, str(zones.active_spell_zones[source_id]["damage_type"]).capitalize()])
	zones.refresh_grid.call()
	zones.highlight_reachable.call()
	return source_id


static func _spirit_guardians_zone_affects_target(zones: CombatSpellZones, zone: Dictionary, target_id: String) -> bool:
	return target_id not in zone.get("exempt_target_ids", [])


static func _resolve_spirit_guardians_zone_save(zones: CombatSpellZones, target, zone: Dictionary) -> Dictionary:
	var target_id := zones._spell_zone_target_id(target)
	if target_id.is_empty() or not SpellZoneConjurations._spirit_guardians_zone_affects_target(zones, zone, target_id):
		return {"success": true, "skipped": true, "reason": "designated_unaffected"}
	var last_trigger_turn_by_target: Dictionary = zone.get("last_trigger_turn_by_target", {})
	var current_turn := zones._current_spell_trigger_turn()
	if str(last_trigger_turn_by_target.get(target_id, "")) == current_turn:
		return {"success": true, "saved": true, "skipped": true, "reason": "already_triggered_this_turn"}
	last_trigger_turn_by_target[target_id] = current_turn
	zone["last_trigger_turn_by_target"] = last_trigger_turn_by_target
	var caster := zones._spell_zone_caster(zone)
	if caster == null:
		return {}
	var spell_data: Dictionary = DataLoader.get_spell("spirit_guardians").duplicate(true)
	spell_data["damage"] = str(zone.get("damage_formula", "3d8"))
	spell_data["damage_type"] = str(zone.get("damage_type", "radiant"))
	spell_data["_ongoing_zone_trigger"] = true
	spell_data["_save_dc_override"] = int(zone.get("save_dc", caster.get_spell_save_dc()))
	spell_data["_skip_counterspell"] = true
	var decisions: Dictionary = await zones.collect_save_decisions.call(target, "Spirit Guardians", spell_data)
	var result := CombatAction.resolve_spell(caster, target, spell_data, false, decisions, [], int(zone.get("slot_level", 3)), 0)
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	var damage_text := " and takes %d %s damage" % [int(result.get("damage", 0)), str(zone.get("damage_type", "radiant")).capitalize()] if int(result.get("damage", 0)) > 0 else ""
	zones.hud.add_log("%s %s the Spirit Guardians Wisdom save (%d vs DC %d)%s." % [target_name, "succeeds on" if bool(result.get("saved", false)) else "fails", int(result.get("save_total", 0)), int(zone.get("save_dc", 0)), damage_text])
	var damage_taken := int(result.get("damage", 0))
	if target is Character and damage_taken > 0:
		await zones.check_concentration.call(target, damage_taken)
	elif target is Dictionary and int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		zones.tracker.remove_combatant(str(target.get("id", "")))
		zones.enemy_defeated.call(target, caster)
	if target is Character and not target.is_alive:
		zones.end_concentration.call(target)
	return result


static func _resolve_conjure_fey_attack(zones: CombatSpellZones, zone: Dictionary, target) -> Dictionary:
	var caster := zones._spell_zone_caster(zone)
	if caster == null or target == null or not zones.active_spell_zones.has(str(zone.get("source_id", ""))):
		return {}
	var target_hex := zones._spell_zone_target_hex(target)
	var center: Vector2i = zone.get("center", Vector2i.ZERO)
	if HexUtils.get_distance(center, target_hex) > 1:
		return {"success": false, "reason": "target_out_of_reach"}
	var spell_data: Dictionary = DataLoader.get_spell("conjure_fey").duplicate(true)
	spell_data["_spellcasting_ability"] = str(zone.get("spellcasting_ability", caster.get_spellcasting_ability()))
	spell_data["_spell_damage_bonus_override"] = caster.ability_scores.get_ability_modifier(spell_data["_spellcasting_ability"])
	var decisions: Dictionary = await zones.collect_attack_decision.call(caster)
	if target is Character:
		decisions.merge(await zones.collect_shield_decision.call(target, spell_data, decisions), true)
	var distance_feet := HexUtils.get_distance(center, target_hex) * 5
	var result := CombatAction.resolve_spell(caster, target, spell_data, false, decisions, [], int(zone.get("slot_level", 6)), distance_feet)
	if bool(result.get("hit", false)):
		CombatAction.apply_condition(target, "frightened", 1000, str(zone.get("source_id", "")))
		var frightened_targets: Array = zone.get("frightened_targets", [])
		if target not in frightened_targets and zones._has_spell_condition_source(target, str(zone.get("source_id", "")), "frightened"):
			frightened_targets.append(target)
		zone["frightened_targets"] = frightened_targets
		var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
		result["message"] = str(result.get("message", "Conjure Fey hits.")) + " %s is Frightened until the start of your next turn." % target_name
	zones.hud.add_log(str(result.get("message", "The Conjure Fey attack resolves.")))
	var damage_taken := int(result.get("damage", 0))
	if target is Character and damage_taken > 0:
		await zones.check_concentration.call(target, damage_taken)
	elif target is Dictionary and int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		zones.tracker.remove_combatant(str(target.get("id", "")))
		zones.enemy_defeated.call(target, caster)
	if target is Character and not target.is_alive:
		zones.end_concentration.call(target)
	return result


static func _resolve_conjure_animals_zone_save(zones: CombatSpellZones, target, zone: Dictionary) -> Dictionary:
	var target_id := zones._spell_zone_target_id(target)
	if target_id.is_empty():
		return {}
	var last_trigger_turn_by_target: Dictionary = zone.get("last_trigger_turn_by_target", {})
	var current_turn := zones._current_spell_trigger_turn()
	if str(last_trigger_turn_by_target.get(target_id, "")) == current_turn:
		return {"success": true, "saved": true, "skipped": true, "reason": "already_triggered_this_turn"}
	last_trigger_turn_by_target[target_id] = current_turn
	zone["last_trigger_turn_by_target"] = last_trigger_turn_by_target
	var caster := zones._spell_zone_caster(zone)
	if caster == null:
		return {}
	var spell_data: Dictionary = DataLoader.get_spell("conjure_animals").duplicate(true)
	spell_data["damage"] = "3d10"
	spell_data["_ongoing_zone_trigger"] = true
	spell_data["_save_dc_override"] = int(zone.get("save_dc", caster.get_spell_save_dc()))
	spell_data["_skip_counterspell"] = true
	var decisions: Dictionary = await zones.collect_save_decisions.call(target, "Conjure Animals", spell_data)
	var result := CombatAction.resolve_spell(caster, target, spell_data, false, decisions, [], int(zone.get("slot_level", 3)), 0)
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	var damage_text := " and takes %d Slashing damage" % int(result.get("damage", 0)) if not bool(result.get("saved", true)) else ""
	zones.hud.add_log("%s %s the Conjure Animals Dexterity save (%d vs DC %d)%s." % [target_name, "succeeds on" if bool(result.get("saved", false)) else "fails", int(result.get("save_total", 0)), int(zone.get("save_dc", 0)), damage_text])
	var damage_taken := int(result.get("damage", 0))
	if target is Character and damage_taken > 0:
		await zones.check_concentration.call(target, damage_taken)
	elif target is Dictionary and int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		zones.tracker.remove_combatant(str(target.get("id", "")))
		zones.enemy_defeated.call(target, caster)
	if target is Character and not target.is_alive:
		zones.end_concentration.call(target)
	return result


static func _resolve_conjure_woodland_beings_zone_save(zones: CombatSpellZones, target, zone: Dictionary) -> Dictionary:
	var target_id := zones._spell_zone_target_id(target)
	if target_id.is_empty():
		return {}
	var last_trigger_turn_by_target: Dictionary = zone.get("last_trigger_turn_by_target", {})
	var current_turn := zones._current_spell_trigger_turn()
	if str(last_trigger_turn_by_target.get(target_id, "")) == current_turn:
		return {"success": true, "saved": true, "skipped": true, "reason": "already_triggered_this_turn"}
	last_trigger_turn_by_target[target_id] = current_turn
	zone["last_trigger_turn_by_target"] = last_trigger_turn_by_target
	var caster := zones._spell_zone_caster(zone)
	if caster == null:
		return {}
	var spell_data: Dictionary = DataLoader.get_spell("conjure_woodland_beings").duplicate(true)
	spell_data["damage"] = str(zone.get("damage_formula", "5d8"))
	spell_data["_ongoing_zone_trigger"] = true
	spell_data["_save_dc_override"] = int(zone.get("save_dc", caster.get_spell_save_dc()))
	spell_data["_skip_counterspell"] = true
	var decisions: Dictionary = await zones.collect_save_decisions.call(target, "Conjure Woodland Beings", spell_data)
	var result := CombatAction.resolve_spell(caster, target, spell_data, false, decisions, [], int(zone.get("slot_level", 4)), 0)
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	var damage_text := " and takes %d Force damage" % int(result.get("damage", 0)) if int(result.get("damage", 0)) > 0 else ""
	zones.hud.add_log("%s %s the Conjure Woodland Beings Wisdom save (%d vs DC %d)%s." % [target_name, "succeeds on" if bool(result.get("saved", false)) else "fails", int(result.get("save_total", 0)), int(zone.get("save_dc", 0)), damage_text])
	var damage_taken := int(result.get("damage", 0))
	if target is Character and damage_taken > 0:
		await zones.check_concentration.call(target, damage_taken)
	elif target is Dictionary and int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		zones.tracker.remove_combatant(str(target.get("id", "")))
		zones.enemy_defeated.call(target, caster)
	if target is Character and not target.is_alive:
		zones.end_concentration.call(target)
	return result




static func _conjure_minor_elementals_damage_choice(zones: CombatSpellZones, caster: Character, target) -> Dictionary:
	if not zones._conjure_minor_elementals_applies_to_target(caster, target):
		return {}
	var source_id := zones._conjure_minor_elementals_zone_source_for_caster(caster)
	var zone: Dictionary = zones.active_spell_zones.get(source_id, {})
	var damage_type := str(zone.get("_test_damage_type", ""))
	if damage_type.is_empty():
		damage_type = await zones.hud.request_damage_type_choice(zone.get("damage_type_choices", ["acid", "cold", "fire", "lightning"]), "Conjure Minor Elementals")
	if damage_type.is_empty() or damage_type not in zone.get("damage_type_choices", []):
		return {}
	return {"formula": str(zone.get("attack_damage_formula", "2d8")), "type": damage_type, "label": "Conjure Minor Elementals"}


static func _conjure_minor_elementals_spell_attack_choices(zones: CombatSpellZones, caster: Character, target, spell_data: Dictionary) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if not zones._conjure_minor_elementals_applies_to_target(caster, target):
		return choices
	var count := int(spell_data.get("_scorching_ray_count_for_target", 1)) if spell_data.has("damage_per_ray") else 1
	var source_id := zones._conjure_minor_elementals_zone_source_for_caster(caster)
	var zone: Dictionary = zones.active_spell_zones.get(source_id, {})
	for _attack in maxi(1, count):
		var damage_type := str(zone.get("_test_damage_type", ""))
		if damage_type.is_empty():
			damage_type = await zones.hud.request_damage_type_choice(zone.get("damage_type_choices", ["acid", "cold", "fire", "lightning"]), "Conjure Minor Elementals")
		if damage_type.is_empty() or damage_type not in zone.get("damage_type_choices", []):
			return []
		choices.append({"formula": str(zone.get("attack_damage_formula", "2d8")), "type": damage_type, "label": "Conjure Minor Elementals"})
	return choices
