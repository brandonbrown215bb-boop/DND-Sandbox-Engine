## Missile and ray allocation, rolls and settled damage.
class_name SpellProjectileResolver
extends RefCounted

static func _resolve_magic_missile(caster: Character, target_entity, spell_data: Dictionary, reaction_decisions: Dictionary = {}, slot_level: int = 0) -> Dictionary:
	var dart_count := SpellProjectileResolver.magic_missile_dart_count(spell_data, slot_level)
	if target_entity is Character:
		if target_entity.has_condition("shield"):
			return {"success": true, "hit": true, "damage": 0, "dart_count": dart_count, "shield_blocked": true, "message": "%s takes no damage from Magic Missile because Shield blocks it." % target_entity.character_name}
		var shield_payment := SpellPermissionRules.spend_reaction(target_entity, "shield", reaction_decisions) if target_entity.reaction_available and CombatAction._reaction_accepted("shield", reaction_decisions) else {}
		if not shield_payment.is_empty():
			target_entity.add_condition("shield", 1)
			var ward_events: Array = shield_payment.get("ward_events", [])
			var shield_msg := "%s casts Shield as a Reaction and takes no damage from Magic Missile." % target_entity.character_name
			for ward_ev in ward_events:
				if not str(ward_ev.get("message", "")).is_empty():
					shield_msg += " " + str(ward_ev["message"])
			return {"success": true, "hit": true, "damage": 0, "dart_count": dart_count, "shield_blocked": true, "shield_used": true, "message": shield_msg}
	var damage_per_dart := str(spell_data.get("damage_per_dart", "1d4+1")).replace(" ", "")
	var details := SpellDamageRolls._roll_spell_damage(caster, damage_per_dart, dart_count, reaction_decisions)
	return SpellDamageRolls._finish_spell_damage(caster, target_entity, details, 0, 1.0, str(spell_data.get("damage_type", "force")), reaction_decisions, {
		"success": true, "hit": true, "dart_count": dart_count,
		"message": "%s hits automatically with %d darts for {damage} %s damage." % [spell_data.get("name", "Magic Missile"), dart_count, spell_data.get("damage_type", "force")]
	})


static func magic_missile_dart_count(spell_data: Dictionary, slot_level: int = 0) -> int:
	var dart_count := int(spell_data.get("dart_count", 3))
	var base_level := int(spell_data.get("level", 1))
	var upcast: Dictionary = spell_data.get("upcast", {})
	dart_count += maxi(0, slot_level - base_level) * int(upcast.get("extra_darts_per_level", 0))
	return clampi(int(spell_data.get("_magic_missile_darts_for_target", dart_count)), 1, dart_count)


static func _resolve_scorching_ray(caster: Character, target_entity, spell_data: Dictionary, reaction_decisions: Dictionary, slot_level: int = 0, distance_feet: int = -1) -> Dictionary:
	var ray_count := SpellProjectileResolver.scorching_ray_count(caster, spell_data, slot_level)
	var damage_dice := str(spell_data.get("damage_per_ray", "2d6")).replace(" ", "")
	var target_ac := 10
	if target_entity is Character:
		target_ac = target_entity.get_ac()
	elif target_entity is Dictionary:
		target_ac = SpellEffects.effective_ac(target_entity, int(target_entity.get("armor_class", 10)) + (2 if CombatAction.has_condition(target_entity, "shield_of_faith") else 0))
	var hits := 0
	var bonus_packets: Array[Dictionary] = []
	var bonus_choices: Array = spell_data.get("_conjure_minor_elementals_bonus_packets", [])
	var details := {"formula": damage_dice, "dice_terms": [], "modifiers": [], "final_total": 0}
	var stroke_of_luck_used := false
	var shield_used := false
	var visibility: Dictionary = reaction_decisions.get("spell_visibility", {})
	var grid: HexGrid = visibility.get("grid")
	var unseen_target := CombatAction.is_invisible(target_entity) and not CombatAction.can_perceive_invisible(caster, maxi(0, distance_feet))
	var unseen_caster := CombatAction.is_invisible(caster) and not CombatAction.can_perceive_invisible(target_entity, maxi(0, distance_feet))
	if grid != null:
		var origin: Vector2i = visibility["caster_position"]
		var target_position: Vector2i = visibility["target_position"]
		unseen_target = not CombatPerception.can_see_target(caster, target_entity, origin, target_position, grid)
		unseen_caster = not CombatPerception.can_see_target(target_entity, caster, target_position, origin, grid)
	for ray_index in ray_count:
		var ray_fog_obscures_attack := CombatAction.has_condition(caster, "fog_cloud_obscured") or CombatAction.has_condition(target_entity, "fog_cloud_obscured") or CombatAction.has_condition(caster, "darkness_obscured") or CombatAction.has_condition(target_entity, "darkness_obscured")
		var spell_attack_advantage := FighterRules.attack_advantage(caster, target_entity) or SpellEffects.has_spell(target_entity, "faerie_fire") or ray_fog_obscures_attack or caster.has_condition("innate_sorcery") or CombatAction.is_unconscious(target_entity) or CombatAction.is_paralyzed(target_entity) or unseen_caster
		var spell_attack_disadvantage := (caster.get_creature_type() in CombatAction.protected_creature_types_for_target(target_entity)) or (SpellEffects.has_spell(target_entity, "blur") and not CombatAction.can_perceive_blur(caster, maxi(0, distance_feet))) or ray_fog_obscures_attack or unseen_target
		var helped_attack := CombatAction.consume_attack_help(target_entity)
		spell_attack_advantage = spell_attack_advantage or helped_attack
		var attack_result := caster.make_attack_roll(SpellPermissionRules.selected_ability(spell_data, caster.get_spellcasting_ability()), spell_attack_advantage, spell_attack_disadvantage)
		var hit: bool = bool(attack_result.get("is_crit", false)) or (not attack_result.get("is_miss", false) and int(attack_result.get("total", 0)) >= target_ac)
		if not hit and not stroke_of_luck_used and bool(reaction_decisions.get("stroke_of_luck", false)) and caster.has_feature("rogue_stroke_of_luck"):
			var stroke_result := RogueRules.apply_stroke_of_luck_to_attack(caster, attack_result, true)
			if bool(stroke_result.get("used", false)):
				stroke_of_luck_used = true
				attack_result = stroke_result.get("result", attack_result)
				hit = bool(attack_result.get("is_crit", false)) or (not bool(attack_result.get("is_miss", false)) and int(attack_result.get("total", 0)) >= target_ac)
		var ray_inspiration := BardicInspirationRules.apply_to_attack_result(caster, attack_result, target_ac, bool(reaction_decisions.get("bardic_inspiration_attack", reaction_decisions.get("bardic_inspiration", false))))
		if ray_inspiration.get("used", false):
			hit = bool(ray_inspiration["success"])
		hit = FighterRules.peerless_aim(caster, hit)
		var shield_payment := SpellPermissionRules.spend_reaction(target_entity, "shield", reaction_decisions) if hit and not shield_used and target_entity is Character and target_entity.reaction_available and CombatAction._reaction_accepted("shield", reaction_decisions) else {}
		if not shield_payment.is_empty():
			target_entity.add_condition("shield", 1)
			target_ac = target_entity.get_ac()
			shield_used = true
			hit = bool(attack_result.get("is_crit", false)) or int(attack_result.get("total", 0)) >= target_ac
		if not hit:
			FighterRules.record_miss(caster, target_entity)
		if hit:
			var ray_is_crit := bool(attack_result.get("is_crit", false)) or (CombatAction.is_unconscious(target_entity) or CombatAction.is_paralyzed(target_entity)) and int(spell_data.get("range", 6)) <= 1
			hits += 1
			var ray_damage := SpellDamageRolls._roll_spell_damage(caster, damage_dice, 2 if ray_is_crit else 1, {})
			details["dice_terms"].append_array(ray_damage["dice_terms"])
			details["final_total"] = int(details["final_total"]) + int(ray_damage["final_total"])
			if ray_index < bonus_choices.size() and bonus_choices[ray_index] is Dictionary:
				var choice: Dictionary = bonus_choices[ray_index]
				var bonus_formula := str(choice.get("formula", ""))
				if not bonus_formula.is_empty():
					bonus_packets.append({"details": SpellDamageRolls._roll_spell_damage(caster, bonus_formula, 2 if ray_is_crit else 1, {}), "type": str(choice.get("type", "acid")), "label": str(choice.get("label", "Conjure Minor Elementals")), "formula": bonus_formula})
	if hits == 0:
		return {"success": true, "hit": false, "damage": 0, "ray_count": ray_count, "shield_used": shield_used, "message": "%s misses all %d rays.%s" % [spell_data.get("name", "Scorching Ray"), ray_count, " Shield raises the target's AC for subsequent attacks." if shield_used else ""]}
	var beam_bonus := CombatAction.spell_damage_bonus(caster, spell_data) if not spell_data.get("beam_count_by_level", {}).is_empty() else 0
	if beam_bonus > 0 and hits > 1:
		details["final_total"] = int(details["final_total"]) + beam_bonus * (hits - 1)
		details["modifiers"].append({"source": "per-hit cantrip bonus", "value": beam_bonus * (hits - 1)})
	return SpellDamageRolls._finish_spell_damage(caster, target_entity, details, beam_bonus, 1.0, str(spell_data.get("damage_type", "fire")), reaction_decisions, {
		"success": true, "hit": true, "ray_count": ray_count, "rays_hit": hits,
		"stroke_of_luck_used": stroke_of_luck_used, "shield_used": shield_used,
		"message": "%s hits with %d of %d rays for {damage} %s damage.%s%s" % [spell_data.get("name", "Scorching Ray"), hits, ray_count, spell_data.get("damage_type", "fire"), " Stroke of Luck turns the first missed ray's attack into a 20." if stroke_of_luck_used else "", " Shield raises the target's AC for subsequent attacks." if shield_used else ""]
	}, 1, bonus_packets)


static func scorching_ray_count(caster: Character, spell_data: Dictionary, slot_level: int = 0) -> int:
	var beam_levels: Dictionary = spell_data.get("beam_count_by_level", {})
	if not beam_levels.is_empty():
		var beams := 1
		for threshold in beam_levels:
			if str(threshold).is_valid_int() and caster != null and caster.level >= int(threshold):
				beams = maxi(beams, int(beam_levels[threshold]))
		return clampi(int(spell_data.get("_scorching_ray_count_for_target", beams)), 1, beams)
	var ray_count := int(spell_data.get("ray_count", 3))
	var base_level := int(spell_data.get("level", 2))
	var upcast: Dictionary = spell_data.get("upcast", {})
	ray_count += maxi(0, slot_level - base_level) * int(upcast.get("extra_rays_per_level", 0))
	return clampi(int(spell_data.get("_scorching_ray_count_for_target", ray_count)), 1, ray_count)


