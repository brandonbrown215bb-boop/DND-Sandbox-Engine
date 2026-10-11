## Single spell attacks, attack reactions and settled damage.
class_name SpellAttackResolver
extends RefCounted

static func resolve(cast: SpellResolutionContext) -> Dictionary:
	# Standard spell attack roll
	var spell_stat := cast.caster.get_spellcasting_ability()
	var spell_attack_distance := maxi(0, cast.distance_feet)
	var fog_obscures_attack := CombatAction.has_condition(cast.caster, "fog_cloud_obscured") or CombatAction.has_condition(cast.target, "fog_cloud_obscured") or CombatAction.has_condition(cast.caster, "darkness_obscured") or CombatAction.has_condition(cast.target, "darkness_obscured")
	var spell_attack_advantage := FighterRules.attack_advantage(cast.caster, cast.target) or CombatAction.has_condition(cast.target, "restrained") or SpellEffects.has_spell(cast.target, "faerie_fire") or fog_obscures_attack or cast.caster.has_condition("innate_sorcery") or CombatAction.is_unconscious(cast.target) or CombatAction.is_paralyzed(cast.target)
	spell_attack_advantage = spell_attack_advantage or CombatAction.has_condition(cast.target, "reckless_attack")
	spell_attack_advantage = spell_attack_advantage or (CombatAction.is_invisible(cast.caster) and not CombatAction.can_perceive_invisible(cast.target, spell_attack_distance))
	var spell_attack_disadvantage := (CombatAction.is_invisible(cast.target) and not CombatAction.can_perceive_invisible(cast.caster, spell_attack_distance)) or (SpellEffects.has_spell(cast.target, "blur") and not CombatAction.can_perceive_blur(cast.caster, spell_attack_distance)) or fog_obscures_attack or cast.caster.has_condition("restrained")
	var visibility: Dictionary = cast.decisions.get("spell_visibility", {})
	var grid: HexGrid = visibility.get("grid")
	if grid != null:
		var origin: Vector2i = visibility["caster_position"]
		var target_position: Vector2i = visibility["target_position"]
		spell_attack_disadvantage = spell_attack_disadvantage or not CombatPerception.can_see_target(cast.caster, cast.target, origin, target_position, grid)
		if not (cast.target is Dictionary and bool(cast.target.get("is_object", false))):
			spell_attack_advantage = spell_attack_advantage or not CombatPerception.can_see_target(cast.target, cast.caster, target_position, origin, grid)
	if cast.caster.get_creature_type() in CombatAction.protected_creature_types_for_target(cast.target):
		spell_attack_disadvantage = true
	if (cast.target is Character and cast.target.has_condition("guiding_bolt")) or (cast.target is Dictionary and cast.target.get("conditions", {}).has("guiding_bolt")):
		spell_attack_advantage = true
		CombatAction.consume_guiding_bolt_advantage(cast.target)
	var helped_attack := CombatAction.consume_attack_help(cast.target)
	spell_attack_advantage = spell_attack_advantage or helped_attack
	var attack_result := cast.caster.make_attack_roll(spell_stat, spell_attack_advantage, spell_attack_disadvantage, {}, cast.decisions)
	
	var target_ac := 10
	if cast.target is Character:
		target_ac = cast.target.get_ac()
	elif cast.target is Dictionary:
		target_ac = SpellEffects.effective_ac(cast.target, int(cast.target.get("armor_class", 10)) + (2 if CombatAction.has_condition(cast.target, "shield_of_faith") else 0))
	CombatAction.apply_blade_ward_attack_penalty(cast.target, cast.caster, attack_result)

	var is_crit := bool(attack_result["is_crit"])
	var is_hit: bool = is_crit or (not attack_result["is_miss"] and attack_result["total"] >= target_ac)
	var reaction_msg := ""
	var seeking_spell_used := false
	if not is_hit and bool(cast.decisions.get("metamagic:seeking", false)) and cast.caster.class_id == "sorcerer" and "seeking_spell" in cast.caster.sorcerer_metamagic_choices:
		var seeking_cost_decisions := {"metamagic:arcane_apotheosis": bool(cast.decisions.get("metamagic:arcane_apotheosis", false))}
		if SorcererRules.spend_metamagic_cost(cast.caster, 1, seeking_cost_decisions):
			seeking_spell_used = true
			attack_result = cast.caster.make_attack_roll(spell_stat, spell_attack_advantage, spell_attack_disadvantage)
			CombatAction.apply_blade_ward_attack_penalty(cast.target, cast.caster, attack_result)
			is_crit = bool(attack_result["is_crit"])
			is_hit = is_crit or (not attack_result["is_miss"] and attack_result["total"] >= target_ac)
			reaction_msg += "[color=magenta]Seeking Spell rerolls the missed spell attack; the new roll stands.[/color]\n"
	var stroke_of_luck_used := false
	if not is_hit and bool(cast.decisions.get("stroke_of_luck", false)) and cast.caster.has_feature("rogue_stroke_of_luck"):
		var stroke_result := RogueRules.apply_stroke_of_luck_to_attack(cast.caster, attack_result, true)
		if bool(stroke_result.get("used", false)):
			stroke_of_luck_used = true
			attack_result = stroke_result.get("result", attack_result)
			is_crit = bool(attack_result.get("is_crit", false))
			is_hit = is_crit or (not bool(attack_result.get("is_miss", false)) and int(attack_result.get("total", 0)) >= target_ac)
			reaction_msg += "[color=gold]Stroke of Luck turns the failed spell attack into a 20.[/color]\n"
	var attack_inspiration := BardicInspirationRules.apply_to_attack_result(cast.caster, attack_result, target_ac, bool(cast.decisions.get("bardic_inspiration_attack", cast.decisions.get("bardic_inspiration", false))))
	if attack_inspiration.get("used", false):
		is_hit = bool(attack_inspiration["success"])
		reaction_msg += str(attack_inspiration.get("message", "")) + "\n"
	if is_hit and (CombatAction.is_unconscious(cast.target) or CombatAction.is_paralyzed(cast.target)) and int(cast.spell.get("range", 6)) <= 1:
		is_crit = true
		attack_result["is_crit"] = true

	# Shield can be cast even when the triggering attack is a critical hit;
	# the Reaction still raises AC against any later attacks this turn.
	if is_hit and cast.target is Character:
		if cast.target.reaction_available and "shield" in cast.target.known_spells and cast.target.spell_slots.get("1", 0) > 0 and CombatAction._reaction_accepted("shield", cast.decisions):
			cast.target.reaction_available = false
			cast.target.spell_slots["1"] -= 1
			cast.target.add_condition("shield", 1)
			var ward_events := WardRules.on_slot_spell_cast(cast.target, DataLoader.get_spell("shield"), 1)
			target_ac = cast.target.get_ac()
			is_hit = is_crit or attack_result["total"] >= target_ac
			reaction_msg = "[color=cyan]%s casts Shield as a reaction! AC increases to %d.[/color]\n" % [cast.target.character_name, target_ac]
			for ward_ev in ward_events:
				if not str(ward_ev.get("message", "")).is_empty():
					reaction_msg += "[color=cyan]%s[/color]\n" % str(ward_ev["message"])

	is_hit = FighterRules.peerless_aim(cast.caster, is_hit)
	var token_replaced := bool(attack_result.get("roll_token_replaced", false))
	var token_id := str(attack_result.get("roll_token_id", ""))
	var token_value := int(attack_result.get("roll_token_value", 0))
	if not is_hit:
		FighterRules.record_miss(cast.caster, cast.target)
		if cast.spell.has("miss_damage_scale") and cast.spell.has("damage"):
			var miss_damage_str := SpellDamageRolls.spell_damage_formula(cast.caster, cast.spell, cast.slot_level)
			var miss_damage_details := SpellDamageRolls._roll_spell_damage(cast.caster, miss_damage_str, 1, cast.decisions)
			var miss_base := {
				"success": true, "hit": false, "slot_level": cast.slot_level,
				"metamagic_used": seeking_spell_used, "stroke_of_luck_used": stroke_of_luck_used,
				"roll_token_replaced": token_replaced,
				"message": reaction_msg + "Spell misses for half damage: {damage} %s damage." % cast.spell.get("damage_type", "fire")
			}
			if token_replaced:
				miss_base["roll_token_id"] = token_id
				miss_base["roll_token_value"] = token_value
			return SpellDamageRolls._finish_spell_damage(cast.caster, cast.target, miss_damage_details, CombatAction.spell_damage_bonus(cast.caster, cast.spell), float(cast.spell.get("miss_damage_scale", 0.0)), str(cast.spell.get("damage_type", "fire")), cast.decisions, miss_base)
		var miss_out := {"success": true, "hit": false, "slot_level": cast.slot_level, "attack_roll": attack_result["total"], "attack_advantage": spell_attack_advantage, "attack_disadvantage": spell_attack_disadvantage, "metamagic_used": seeking_spell_used, "stroke_of_luck_used": stroke_of_luck_used, "roll_token_replaced": token_replaced, "message": reaction_msg + "Spell missed! Ranged spell attack %d vs AC %d" % [attack_result["total"], target_ac]}
		if token_replaced:
			miss_out["roll_token_id"] = token_id
			miss_out["roll_token_value"] = token_value
		return miss_out

	var damage_str := SpellDamageRolls.spell_damage_formula(cast.caster, cast.spell, cast.slot_level)
	var damage_type: String = cast.spell.get("damage_type", "fire")
	var is_sorcerous_burst := str(cast.spell.get("id", "")) == "sorcerous_burst"
	var rolled_damage_formula := "%s + %s" % [damage_str, damage_str] if bool(attack_result["is_crit"]) else damage_str
	var damage_details := SpellDamageRolls._roll_sorcerous_burst_damage(cast.caster, rolled_damage_formula, int(cast.spell.get("explode_on_max", 8)), str(cast.spell.get("maximum_bonus_dice_ability", "CHA"))) if is_sorcerous_burst else SpellDamageRolls._roll_spell_damage(cast.caster, damage_str, 2 if attack_result["is_crit"] else 1, cast.decisions)
	var damage_scale := 1.0

	# Uncanny Dodge halves the settled roll, including any selected rerolls.
	if cast.target is Character and cast.target.reaction_available and (cast.target.has_feature("uncanny_dodge") or cast.target.has_feature("rogue_uncanny_dodge")) and CombatAction._reaction_accepted("uncanny_dodge", cast.decisions):
		cast.target.reaction_available = false
		damage_scale = 0.5
		reaction_msg += "[color=cyan]%s uses Uncanny Dodge as a reaction to halve incoming damage![/color]\n" % cast.target.character_name
	var attack_critical := bool(attack_result["is_crit"]) or ((CombatAction.is_unconscious(cast.target) or CombatAction.is_paralyzed(cast.target)) and int(cast.spell.get("range", 6)) <= 1)
	var attack_damage_packets := CombatAction._roll_attack_damage_packets(cast.caster, cast.spell.get("_conjure_minor_elementals_bonus_packets", []), [attack_critical])
	cast.decisions["damage_is_critical"] = attack_critical
	cast.decisions["critical"] = attack_critical
	var hit_base := {
		"success": true, "hit": true, "slot_level": cast.slot_level, "attack_roll": attack_result["total"], "attack_advantage": spell_attack_advantage, "attack_disadvantage": spell_attack_disadvantage, "metamagic_used": seeking_spell_used,
		"crit": attack_critical,
		"critical": attack_critical,
		"stroke_of_luck_used": stroke_of_luck_used,
		"roll_token_replaced": token_replaced,
		"effect_cast": cast.effect_cast,
		"message": reaction_msg + "Spell Hit! Dealing {damage} %s damage." % damage_type
	}
	if token_replaced:
		hit_base["roll_token_id"] = token_id
		hit_base["roll_token_value"] = token_value
	var res := SpellDamageRolls._finish_spell_damage(cast.caster, cast.target, damage_details, CombatAction.spell_damage_bonus(cast.caster, cast.spell), damage_scale, damage_type, cast.decisions, hit_base, 1, attack_damage_packets)
	cast.decisions.erase("damage_is_critical")
	cast.decisions.erase("critical")
	return res


