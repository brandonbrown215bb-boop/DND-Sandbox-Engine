## Encounter spell expiry, repeat saves and concentration cleanup.
class_name SpellEncounterLifecycle
extends RefCounted


static func _tick_protection_from_energy_duration(cast: SpellCastContext, caster: Character) -> void:
	if caster == null or str(caster.concentrating_on.get("spell_id", "")) != "protection_from_energy":
		return
	if cast.tracker.current_round <= int(caster.concentrating_on.get("duration_started_round", cast.tracker.current_round)):
		return
	var remaining := int(caster.concentrating_on.get("duration_rounds_remaining", 600)) - 1
	caster.concentrating_on["duration_rounds_remaining"] = remaining
	if remaining <= 0:
		SpellEncounterLifecycle._end_concentration(cast, caster)


static func _tick_protection_from_evil_and_good_duration(cast: SpellCastContext, caster: Character) -> void:
	if caster == null or str(caster.concentrating_on.get("spell_id", "")) != "protection_from_evil_and_good":
		return
	if cast.tracker.current_round <= int(caster.concentrating_on.get("duration_started_round", cast.tracker.current_round)):
		return
	var remaining := int(caster.concentrating_on.get("duration_rounds_remaining", 100)) - 1
	caster.concentrating_on["duration_rounds_remaining"] = remaining
	if remaining <= 0:
		SpellEncounterLifecycle._end_concentration(cast, caster)


static func _tick_ray_of_enfeeblement_duration(cast: SpellCastContext, caster: Character) -> void:
	if caster == null or str(caster.concentrating_on.get("spell_id", "")) != "ray_of_enfeeblement":
		return
	if cast.tracker.current_round <= int(caster.concentrating_on.get("duration_started_round", cast.tracker.current_round)):
		return
	var remaining := int(caster.concentrating_on.get("duration_rounds_remaining", 10)) - 1
	caster.concentrating_on["duration_rounds_remaining"] = remaining
	if remaining <= 0:
		SpellEncounterLifecycle._end_concentration(cast, caster)


static func _tick_resilient_sphere_duration(cast: SpellCastContext, caster: Character) -> void:
	if caster == null or str(caster.concentrating_on.get("spell_id", "")) != "resilient_sphere":
		return
	if cast.tracker.current_round <= int(caster.concentrating_on.get("duration_started_round", cast.tracker.current_round)):
		return
	var remaining := int(caster.concentrating_on.get("duration_rounds_remaining", 10)) - 1
	caster.concentrating_on["duration_rounds_remaining"] = remaining
	if remaining <= 0:
		SpellEncounterLifecycle._end_concentration(cast, caster)


static func _tick_hold_monster_duration(cast: SpellCastContext, caster: Character) -> void:
	if caster == null or str(caster.concentrating_on.get("spell_id", "")) != "hold_monster":
		return
	if cast.tracker.current_round <= int(caster.concentrating_on.get("duration_started_round", cast.tracker.current_round)):
		return
	var remaining := int(caster.concentrating_on.get("duration_rounds_remaining", 10)) - 1
	caster.concentrating_on["duration_rounds_remaining"] = remaining
	if remaining <= 0:
		SpellEncounterLifecycle._end_concentration(cast, caster)


static func _apply_regenerate_turn_start(cast: SpellCastContext, target) -> void:
	if target is Character:
		if not target.has_condition("regenerate"):
			return
		var healed: int = target.heal(1)
		if healed > 0:
			cast.hud.add_log("[color=cyan]%s regenerates 1 Hit Point.[/color]" % target.character_name)
	elif target is Dictionary:
		var conditions: Dictionary = target.get("conditions", {})
		if not conditions.has("regenerate") or CombatAction.is_healing_suppressed(target):
			return
		var current_hp := int(target.get("current_hp", 0))
		var healed: int = mini(1, maxi(0, int(target.get("max_hp", current_hp)) - current_hp))
		if healed > 0:
			target["current_hp"] = current_hp + healed
			target["is_alive"] = true
			cast.hud.add_log("[color=cyan]%s regenerates 1 Hit Point.[/color]" % target.get("name", "The creature"))


static func _tick_spell_effect_boundary(cast: SpellCastContext, caster: Character, phase: String) -> void:
	var key := "%s:%s" % [SpellEffects.caster_id(caster), phase]
	if int(cast.effect_boundary_rounds.get(key, -1)) == cast.tracker.current_round:
		return
	cast.effect_boundary_rounds[key] = cast.tracker.current_round
	var identify_record: Dictionary = {}
	for source in caster.spell_effects.keys():
		var record: Dictionary = caster.spell_effects[source]
		if str(record.get("spell_id", "")) == "identify" and record.has("identify_target"):
			identify_record = record.duplicate(true)
			break
	if not identify_record.is_empty() and phase == "start" and not SpellEncounterPerception._identify_target_remains_touchable(cast, caster, identify_record.get("identify_target", {})):
		SpellEncounterLifecycle._end_concentration(cast, caster)
		cast.hud.add_log("[color=orange]Identify ends because contact with its target was broken before the casting finished.[/color]")
		SpellEncounterPerception._refresh_detect_evil_and_good_senses(cast)
		SpellEncounterPerception._refresh_detect_poison_and_disease_senses(cast)
		return
	SpellEffects.tick_boundary(cast.areas._spell_effect_targets(), SpellEffects.caster_id(caster), phase)
	if not identify_record.is_empty():
		var identify_source := str(identify_record.get("source_id", ""))
		if not caster.spell_effects.has(identify_source):
			SpellEncounterPerception._complete_identify(cast, caster, identify_record)
	SpellEncounterPerception._refresh_detect_evil_and_good_senses(cast)
	SpellEncounterPerception._refresh_detect_poison_and_disease_senses(cast)


static func _resolve_condition_spell_repeat_saves(cast: SpellCastContext, target) -> void:
	for source in SpellEffects.records(target).keys():
		var result := CombatAction.resolve_condition_spell_repeat_save(target, str(source))
		if result.get("success", false):
			var target_name: String = target.character_name if target is Character else str(target.get("name", "The target"))
			if str(result["spell_id"]) == "sleep" and str(result.get("condition", "")) == "unconscious":
				cast.hud.add_log("%s fails the second Wisdom save against Sleep (%d vs DC %d) and becomes Unconscious." % [target_name, int(result["total"]), int(result["save_dc"])])
			else:
				cast.hud.add_log("%s %s the repeat save against %s (%d vs DC %d)." % [target_name, "succeeds on" if result["saved"] else "fails", str(result["spell_id"]), int(result["total"]), int(result["save_dc"])])
	SpellEffects.reconcile(cast.players.map(func(player): return player.get("character")).filter(func(caster): return caster != null), cast.areas._spell_effect_targets())


static func _end_concentration(cast: SpellCastContext, caster: Character) -> void:
	if caster.concentrating_on.is_empty(): return
	# Room-owned area records and encounter markers use the concentration
	# metadata too; clean them before SpellEffects clears that source record.
	var spell_id := str(caster.concentrating_on.get("spell_id", ""))
	cast.areas.end_area_concentration(caster)
	if spell_id == "dancing_lights":
		cast.dancing_light_sets.erase(caster.character_id)
	if SpellEffects.end_concentration(caster, cast.areas._spell_effect_targets()):
		cast.hud.add_log("[color=yellow]%s's concentration ends.[/color]" % caster.character_name)
		return

	var targets: Array = caster.concentrating_on["targets"]
	var concentration_name: String = str(DataLoader.get_spell(spell_id).get("name", spell_id))
	if spell_id == "ranger_favored_foe":
		concentration_name = "Favored Foe"
	cast.hud.add_log("[color=yellow]%s's concentration on %s ends.[/color]" % [caster.character_name, concentration_name])
	if spell_id == "ranger_favored_foe":
		var marked_id := str(caster.feature_uses.get("ranger_favored_foe_target_id", ""))
		for monster in cast.monsters:
			if str(monster.get("id", "")) == marked_id:
				monster.get("conditions", {}).erase("favored_foe")
		caster.feature_uses.erase("ranger_favored_foe_target_id")
	if spell_id == "hunters_mark":
		var marked_id := str(caster.feature_uses.get("hunters_mark_target_id", ""))
		for monster in cast.monsters:
			if str(monster.get("id", "")) == marked_id:
				monster.get("conditions", {}).erase("hunters_mark")
		caster.feature_uses.erase("hunters_mark_target_id")
	if spell_id == "protection_from_energy":
		for target in targets:
			if target is Character:
				target.protection_from_energy_type = ""
			elif target is Dictionary:
				target.erase("protection_from_energy_type")
	if spell_id == "protection_from_evil_and_good":
		for target in targets:
			if target is Character:
				target.protection_from_evil_and_good_sources.erase(caster.character_id)
			elif target is Dictionary:
				target.get("protection_from_evil_and_good_sources", {}).erase(caster.character_id)
	
	# Remove conditions applied by this spell
	var effects: Array = caster.concentrating_on.get("effects", [])
	for target in targets:
		for effect in effects:
			if effect.get("type", "") == "grant_condition":
				var cond = effect.get("condition", "")
				if target is Character:
					target.remove_condition(cond)
					if spell_id == "guidance":
						target.guidance_skill = ""
					if spell_id == "resistance":
						target.resistance_damage_type = ""
						target.resistance_last_turn_serial = -1
				elif target is Dictionary:
					target.get("conditions", {}).erase(cond)
					if spell_id == "resistance":
						target.erase("resistance_damage_type")
						target.erase("resistance_last_turn_serial")
					
	caster.concentrating_on.clear()
	cast.redraw_entities.call()


static func _end_resilient_sphere_for_target(cast: SpellCastContext, target) -> void:
	for player in cast.players:
		var caster: Character = player.get("character")
		if caster == null or str(caster.concentrating_on.get("spell_id", "")) != "resilient_sphere":
			continue
		if target in caster.concentrating_on.get("targets", []):
			SpellEncounterLifecycle._end_concentration(cast, caster)
			return


static func _check_concentration_save(cast: SpellCastContext, character: Character, damage_taken: int) -> void:
	if damage_taken <= 0 or character.concentrating_on.is_empty(): return
	var concentration_spell_id := str(character.concentrating_on.get("spell_id", ""))
	for feature in character.features:
		for effect in character._feature_effects(feature):
			if effect.get("type", "") == "concentration_protection" and concentration_spell_id in effect.get("spells", []):
				cast.hud.add_log("%s maintains concentration on %s through Relentless Hunter." % [character.character_name, DataLoader.get_spell(concentration_spell_id).get("name", concentration_spell_id)])
				return
	
	var dc: int = max(10, int(floor(float(damage_taken) / 2.0)))
	var save_test := character.saving_throw_test_to_dc("CON", dc, bool(character.concentrating_on.get("extended_spell", false)))
	var roll := int(save_test.get("total", 0))
	var success: bool = roll >= dc
	var inspiration_message := ""
	if not success and character.has_feature("rogue_stroke_of_luck") and int(character.feature_uses.get("rogue_stroke_of_luck", 0)) > 0:
		var owner_label: String = cast.owner_label_for_character.call(character)
		var accepted := await cast.hud.request_reaction(owner_label, "stroke_of_luck", "If this concentration save fails, turn its d20 into a 20?", "Use Stroke of Luck on this save?", "Turn the d20 into 20", "Stroke of Luck — %s" % owner_label)
		var stroke := RogueRules.apply_stroke_of_luck(character, save_test, accepted)
		if stroke.get("used", false):
			save_test = stroke.get("result", save_test)
			roll = int(save_test.get("total", roll))
			success = bool(save_test.get("success", roll >= dc))
			inspiration_message += " Stroke of Luck turns the saving throw into a 20."
	if not success and character.feature_uses.has("bardic_inspiration_die"):
		var die := str(character.feature_uses.get("bardic_inspiration_die", "1d6"))
		var owner_label: String = cast.owner_label_for_character.call(character)
		var accepted := await cast.hud.request_reaction(owner_label, "bardic_inspiration", "If your concentration save still fails, add %s to the roll?" % die, "Save Bardic Inspiration for this save?", "Use Inspiration", "Bardic Inspiration — %s" % owner_label)
		var inspiration := BardicInspirationRules.apply_to_test(character, roll, dc, accepted)
		if inspiration.get("used", false):
			roll = int(inspiration["total"])
			success = bool(inspiration["success"])
			inspiration_message += " Bardic Inspiration adds %d." % int(inspiration["bonus"])
	
	cast.hud.add_log("%s makes a CON save to maintain concentration: %d vs DC %d.%s %s" % [character.character_name, roll, dc, inspiration_message, character.last_save_note])
	if success:
		cast.hud.add_log("[color=green]%s maintained concentration![/color]" % character.character_name)
	else:
		cast.hud.add_log("[color=red]%s failed CON save! Concentration lost.[/color]" % character.character_name)
		SpellEncounterLifecycle._end_concentration(cast, character)


static func _tick_spell_healing_suppression(cast: SpellCastContext, caster: Character) -> void:
	var source_id := str(caster.get_instance_id())
	for player_entity in cast.players:
		var target: Character = player_entity.get("character")
		if target != null:
			CombatAction.tick_healing_suppression_for_source(target, source_id)
	for monster in cast.monsters:
		CombatAction.tick_healing_suppression_for_source(monster, source_id)


static func _resolve_delayed_spell_damage(cast: SpellCastContext, target) -> void:
	var delayed_effects: Array = []
	if target is Character:
		delayed_effects = target.delayed_spell_damage.duplicate(true)
		target.delayed_spell_damage.clear()
	elif target is Dictionary:
		delayed_effects = target.get("delayed_spell_damage", []).duplicate(true)
		target["delayed_spell_damage"] = []
	for delayed in delayed_effects:
		if str(delayed.get("trigger", "")) != "end_of_target_next_turn":
			continue
		var target_was_alive: bool = target.is_alive if target is Character else bool(target.get("is_alive", false))
		var amount := Dice.parse_dice_string(str(delayed.get("formula", "0")))
		var damage_type := str(delayed.get("damage_type", "acid"))
		var result := CombatAction.resolve_damage(target, amount, damage_type)
		var damage_taken := int(result.get("resolved", 0))
		var target_name: String = target.character_name if target is Character else str(target.get("name", "Target"))
		cast.hud.add_log("[color=red]%s takes %d delayed %s damage from %s." % [target_name, int(result.get("damage", 0)), damage_type, DataLoader.get_spell(str(delayed.get("spell_id", ""))).get("name", "a spell")])
		if target is Character:
			if damage_taken > 0:
				await SpellEncounterLifecycle._check_concentration_save(cast, target, damage_taken)
		elif target_was_alive and not bool(target.get("is_alive", true)):
			cast.hud.add_log("[color=green]%s was defeated![/color]" % target_name)
			cast.tracker.remove_combatant(str(target.get("id", "")))
			cast.trigger_enemy_defeat_features.call(target, null)




static func _clear_delayed_spell_damage(cast: SpellCastContext) -> void:
	for player in cast.players:
		var member: Character = player.get("character")
		if member != null:
			member.delayed_spell_damage.clear()
	for monster in cast.monsters:
		monster["delayed_spell_damage"] = []

static func _try_shake_sleeping_creature(cast: SpellCastContext, coord: Vector2i, player_pos: Vector2i) -> bool:
	if not cast.can_spend.call("action") or not Targeting.is_in_range(player_pos, coord, 1):
		return false
	var target = null
	for player_entity in cast.players:
		var candidate: Character = player_entity.get("character")
		if candidate != null and candidate.is_alive and player_entity.get("hex_position", Vector2i.ZERO) == coord:
			target = candidate
			break
	if target == null:
		for monster_entity in cast.monsters:
			if monster_entity.get("is_alive", false) and monster_entity.get("hex_position", Vector2i.ZERO) == coord:
				target = monster_entity
				break
	if target == null:
		return false
	var sleep_source := ""
	for source in SpellEffects.records(target):
		var record: Dictionary = SpellEffects.records(target)[source]
		if str(record.get("spell_id", "")) == "sleep" and ("incapacitated" in record.get("conditions", []) or "unconscious" in record.get("conditions", [])):
			sleep_source = str(source)
			break
	if sleep_source.is_empty():
		return false
	SpellEffects.remove(target, sleep_source)
	SpellEffects.reconcile(cast.players.map(func(player): return player.get("character")).filter(func(caster): return caster != null), cast.areas._spell_effect_targets())
	cast.spend_action_cost.call("action")
	cast.hud.add_log("%s uses an action to shake %s awake, ending Sleep." % [cast.caster.character_name, target.character_name if target is Character else str(target.get("name", "the creature"))])
	cast.hud.update_hud(cast.caster, cast.tracker)
	cast.redraw_entities.call()
	cast.highlight_reachable.call()
	return true


static func _resolve_ray_of_enfeeblement_repeat_save(cast: SpellCastContext, target) -> void:
	if SpellEffects.has_spell(target, "ray_of_enfeeblement"):
		SpellEncounterLifecycle._resolve_condition_spell_repeat_saves(cast, target)
		return
	if target is Character and not target.has_condition("ray_of_enfeeblement"):
		return
	if target is Dictionary and not target.get("conditions", {}).has("ray_of_enfeeblement"):
		return
	for party_entity in cast.players:
		var caster: Character = party_entity.get("character")
		if caster == null or str(caster.concentrating_on.get("spell_id", "")) != "ray_of_enfeeblement" or target not in caster.concentrating_on.get("targets", []):
			continue
		var dc := int(caster.concentrating_on.get("save_dc", caster.get_spell_save_dc()))
		var saved := false
		if target is Character:
			saved = bool(target.saving_throw_test_to_dc("CON", dc).get("success", false))
		elif target is Dictionary:
			saved = BarbarianRules.roll_monster_save(target, "CON") >= dc
		if not saved:
			continue
		if target is Character:
			target.remove_condition("ray_of_enfeeblement")
		else:
			target.get("conditions", {}).erase("ray_of_enfeeblement")
		cast.hud.add_log("[color=green]%s succeeds on its Constitution save and ends Ray of Enfeeblement.[/color]" % (target.character_name if target is Character else target.get("name", "The target")))


static func _resolve_hold_monster_repeat_save(cast: SpellCastContext, target) -> void:
	if SpellEffects.has_spell(target, "hold_monster") or SpellEffects.has_spell(target, "hold_person"):
		SpellEncounterLifecycle._resolve_condition_spell_repeat_saves(cast, target)
		return
	for player_entity in cast.players:
		var caster: Character = player_entity.get("character")
		if caster == null or str(caster.concentrating_on.get("spell_id", "")) != "hold_monster" or target not in caster.concentrating_on.get("targets", []):
			continue
		var repeat_save := CombatAction.resolve_hold_monster_repeat_save(target, int(caster.concentrating_on.get("save_dc", caster.get_spell_save_dc())))
		var target_name: String = target.character_name if target is Character else str(target.get("name", "The target"))
		if bool(repeat_save.get("saved", false)):
			var held_targets: Array = caster.concentrating_on.get("targets", []).duplicate()
			held_targets.erase(target)
			caster.concentrating_on["targets"] = held_targets
			cast.hud.add_log("[color=green]%s succeeds on its Wisdom save and ends Hold Monster (%d vs DC %d).[/color]" % [target_name, int(repeat_save.get("total", 0)), int(repeat_save.get("save_dc", 0))])
			if held_targets.is_empty():
				SpellEncounterLifecycle._end_concentration(cast, caster)
		else:
			cast.hud.add_log("[color=purple]%s fails its Wisdom save and remains Paralyzed by Hold Monster (%d vs DC %d).[/color]" % [target_name, int(repeat_save.get("total", 0)), int(repeat_save.get("save_dc", 0))])
