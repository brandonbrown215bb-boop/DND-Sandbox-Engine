## Area-spell creation after target resolution.
class_name SpellCastAreas
extends RefCounted

static func _create_spell_cast_areas(cast: SpellCastContext) -> void:
	var prior_zones: Array = cast.areas.active_spell_zones.keys()
	if str(cast.spell.get("id", "")) == "sunburst":
		# The burst still resolves if its sphere contains no creatures; it can
		# independently dispel overlapping magical Darkness.
		cast.successful = not cast.interrupted
		if cast.successful:
			var dispelled := SpellZoneTerrain.dispel_darkness_in_area(cast.areas, cast.targets)
			if dispelled > 0:
				cast.hud.add_log("Sunburst dispels %d magical Darkness area%s." % [dispelled, "" if dispelled == 1 else "s"])
	if str(cast.spell.get("id", "")) in ["grease", "spike_growth", "moonbeam", "plant_growth", "black_tentacles", "sleet_storm", "wall_of_fire", "cloud_of_daggers", "cloudkill", "fog_cloud", "darkness", "conjure_animals", "conjure_celestial", "conjure_woodland_beings", "spirit_guardians", "aura_of_life", "antilife_shell", "beacon_of_hope"] and cast.targets.is_empty():
		# A zone remains a valid cast even when no creature starts in it.
		cast.successful = true
	if str(cast.spell.get("id", "")) == "entangle":
		cast.successful = true
	if str(cast.spell.get("id", "")) == "black_tentacles" and not cast.interrupted:
		cast.successful = true
	SpellEffects.reconcile(cast.players.map(func(player): return player.get("character")).filter(func(caster): return caster != null), cast.areas._spell_effect_targets())
	if str(cast.spell.get("id", "")) == "grease" and cast.successful:
		SpellZoneTerrain._create_grease_zone(cast.areas, cast.caster, cast.target_coord)
	if str(cast.spell.get("id", "")) == "spike_growth" and cast.successful:
		SpellZoneTerrain._create_spike_growth_zone(cast.areas, cast.caster, cast.target_coord, cast.slot_level_used)
	if str(cast.spell.get("id", "")) == "entangle" and cast.successful:
		SpellZoneTerrain._create_entangle_zone(cast.areas, cast.caster, cast.target_coord, cast.area_source_id, cast.restrained_targets)
	if str(cast.spell.get("id", "")) == "black_tentacles" and cast.successful:
		SpellZoneTerrain._create_black_tentacles_zone(cast.areas, cast.caster, cast.spell, cast.target_coord, cast.area_source_id, cast.restrained_targets, cast.targets, cast.slot_level_used)
	if str(cast.spell.get("id", "")) == "sleet_storm" and cast.successful:
		SpellZoneTerrain._create_sleet_storm_zone(cast.areas, cast.caster, cast.target_coord, cast.area_source_id, bool(cast.spell.get("_metamagic_extended", false)))
	if str(cast.spell.get("id", "")) == "wall_of_fire" and cast.successful and cast.command_selection.size() == 1:
		SpellZoneTerrain._create_wall_of_fire_zone(cast.areas, cast.caster, cast.target_coord, cast.command_selection[0], cast.area_source_id, cast.slot_level_used, bool(cast.spell.get("_metamagic_extended", false)))
	if str(cast.spell.get("id", "")) in ["cloud_of_daggers", "cloudkill"] and not cast.interrupted:
		cast.successful = true
	if str(cast.spell.get("id", "")) == "cloud_of_daggers" and cast.successful:
		SpellZoneTerrain._create_cloud_of_daggers_zone(cast.areas, cast.caster, cast.target_coord, cast.slot_level_used, bool(cast.spell.get("_metamagic_extended", false)))
	if str(cast.spell.get("id", "")) == "cloudkill" and cast.successful:
		SpellZoneTerrain._create_cloudkill_zone(cast.areas, cast.caster, cast.target_coord, cast.area_source_id, cast.slot_level_used, bool(cast.spell.get("_metamagic_extended", false)))
	if str(cast.spell.get("id", "")) == "fog_cloud" and not cast.interrupted:
		cast.successful = true
	if str(cast.spell.get("id", "")) == "fog_cloud" and cast.successful:
		SpellZoneTerrain._create_fog_cloud_zone(cast.areas, cast.caster, cast.target_coord, cast.slot_level_used, bool(cast.spell.get("_metamagic_extended", false)))
	if str(cast.spell.get("id", "")) == "darkness" and not cast.interrupted:
		cast.successful = true
	if str(cast.spell.get("id", "")) == "darkness" and cast.successful:
		SpellZoneTerrain._create_darkness_zone(cast.areas, cast.caster, cast.target_coord, bool(cast.spell.get("_metamagic_extended", false)))
	if str(cast.spell.get("id", "")) == "conjure_animals" and not cast.interrupted:
		cast.successful = true
		SpellZoneConjurations._create_conjure_animals_zone(cast.areas, cast.caster, cast.target_coord, cast.area_source_id, cast.slot_level_used)
	if str(cast.spell.get("id", "")) == "conjure_celestial" and not cast.interrupted:
		cast.successful = true
		SpellZoneConjurations._create_conjure_celestial_zone(cast.areas, cast.caster, cast.target_coord, cast.area_source_id, cast.slot_level_used, cast.initial_targets)
	if str(cast.spell.get("id", "")) == "conjure_elemental" and not cast.interrupted:
		cast.successful = true
		SpellZoneConjurations._create_conjure_elemental_zone(cast.areas, cast.caster, cast.target_coord, cast.area_source_id, cast.slot_level_used, str(cast.spell.get("_conjure_elemental_choice", "air")), str(cast.spell.get("damage_type", "lightning")))
	if str(cast.spell.get("id", "")) == "conjure_minor_elementals" and not cast.interrupted:
		cast.successful = true
		SpellZoneConjurations._create_conjure_minor_elementals_zone(cast.areas, cast.caster, cast.area_source_id, cast.slot_level_used)
	if str(cast.spell.get("id", "")) == "conjure_woodland_beings" and not cast.interrupted:
		cast.successful = true
		SpellZoneConjurations._create_conjure_woodland_beings_zone(cast.areas, cast.caster, cast.area_source_id, cast.slot_level_used)
	if str(cast.spell.get("id", "")) == "spirit_guardians" and not cast.interrupted:
		cast.successful = true
		SpellZoneConjurations._create_spirit_guardians_zone(cast.areas, cast.caster, cast.spell, cast.area_source_id, cast.slot_level_used)
	if str(cast.spell.get("id", "")) == "aura_of_life" and not cast.interrupted:
		cast.successful = true
		SpellZoneConjurations._create_aura_of_life_zone(cast.areas, cast.caster, cast.area_source_id)
	if str(cast.spell.get("id", "")) == "antilife_shell" and not cast.interrupted:
		cast.successful = true
		SpellZoneConjurations._create_antilife_shell_zone(cast.areas, cast.caster, cast.area_source_id)
	if str(cast.spell.get("id", "")) == "conjure_fey" and not cast.interrupted:
		cast.successful = true
		var fey_source_id := SpellZoneConjurations._create_conjure_fey_zone(cast.areas, cast.caster, cast.target_coord, cast.area_source_id, cast.slot_level_used)
		var fey_zone: Dictionary = cast.areas.active_spell_zones.get(fey_source_id, {})
		if not fey_zone.is_empty():
			fey_zone["spellcasting_ability"] = SpellPermissionRules.selected_ability(cast.spell, cast.caster.get_spellcasting_ability())
			var initial_fey_targets := cast.areas._conjure_fey_targets_within(cast.target_coord)
			var initial_target_id := str(cast.spell.get("_test_conjure_fey_target_id", ""))
			if not initial_fey_targets.is_empty():
				if initial_target_id.is_empty():
					initial_target_id = await cast.hud.request_conjure_fey_attack_target(initial_fey_targets)
				var initial_target = cast.areas._conjure_fey_target_by_id(initial_target_id)
				if initial_target != null:
					await SpellZoneConjurations._resolve_conjure_fey_attack(cast.areas, fey_zone, initial_target)
	if str(cast.spell.get("id", "")) == "moonbeam" and cast.successful:
		SpellZoneTerrain._create_moonbeam_zone(cast.areas, cast.caster, cast.target_coord, cast.slot_level_used, cast.targets, cast.area_source_id, cast.shape_locked_targets)
	if str(cast.spell.get("id", "")) == "plant_growth" and cast.successful:
		SpellZoneTerrain._create_plant_growth_zone(cast.areas, cast.caster, cast.target_coord)
	if str(cast.spell.get("id", "")) == "ice_knife" and cast.successful:
		SpellCastResults._resolve_ice_knife_splash(cast, cast.target_coord, cast.spell, cast.slot_level_used, cast.counterspell_decisions)
	for id in cast.areas.active_spell_zones:
		if id in prior_zones: continue
		var zone: Dictionary = cast.areas.active_spell_zones[id]
		if zone.has("save_dc"): zone["save_dc"] = SpellPermissionRules.save_dc(cast.caster, cast.spell)
		if zone.get("spell_id", "") in ["conjure_fey", "conjure_celestial"]:
			zone["spellcasting_ability"] = SpellPermissionRules.selected_ability(cast.spell, cast.caster.get_spellcasting_ability())



	if cast.caster.concentrating_on.get("spell_id", "") == cast.spell.get("id", "") and cast.caster.concentrating_on.has("save_dc"):
		cast.caster.concentrating_on["save_dc"] = SpellPermissionRules.save_dc(cast.caster, cast.spell)
