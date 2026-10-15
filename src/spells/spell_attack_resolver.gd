## Single spell attacks, attack reactions and settled damage.
class_name SpellAttackResolver
extends RefCounted

static func resolve(cast: SpellResolutionContext) -> Dictionary:
	# Standard spell attack roll
	var tracks_resolution_windows := SharedSpell.uses(cast.spell)
	if tracks_resolution_windows:
		SpellDamageRolls.begin_resolution_occurrence(cast, "spell_attack")
		SpellDamageRolls.record_resolution_window(cast, "before_roll")
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
	if tracks_resolution_windows:
		SpellDamageRolls.record_resolution_window(cast, "after_natural", {
			"roll_natural": int(attack_result.get("natural", 0)),
			"roll_modifier": int(attack_result.get("modifier", 0)),
			"roll_total": int(attack_result.get("total", 0)),
		})
		SpellDamageRolls.record_resolution_window(cast, "provisional_outcome", {
			"roll_natural": int(attack_result.get("natural", 0)),
			"roll_modifier": int(attack_result.get("modifier", 0)),
			"roll_total": int(attack_result.get("total", 0)),
			"target_ac": target_ac,
			"provisional_hit": is_hit,
			"provisional_critical": is_crit,
		})

	# Shared attacks may wait here for the owner's exact source choice. Native
	# rerolls and bonuses above are already settled and are captured once.
	if SharedSpell.uses(cast.spell) and SpellDamageRolls.has_attack_bonus_choice_host(cast.decisions):
		var allow_numeric_bonus := not is_hit and not bool(attack_result.get("is_miss", false)) and not is_crit and int(attack_result.get("natural", 0)) != 1
		var allow_hit_adjustments := is_hit and not is_crit and not bool(attack_result.get("is_miss", false))
		var bonus_options := SpellDamageRolls.attack_choice_options(cast.caster, "shared_spell_attack", is_hit, allow_numeric_bonus, allow_hit_adjustments)
		if not bonus_options.is_empty():
			var captured := {
				"attack_result": attack_result.duplicate(true), "original_target_ac": target_ac,
				"original_attack_result": attack_result.duplicate(true),
				"provisional_hit": is_hit,
				"spell_attack_advantage": spell_attack_advantage,
				"spell_attack_disadvantage": spell_attack_disadvantage,
				"reaction_msg": reaction_msg, "seeking_spell_used": seeking_spell_used,
				"stroke_of_luck_used": stroke_of_luck_used, "spell_cast": cast,
			}
			var pending_choice := SpellDamageRolls.create_weapon_attack_bonus_request(cast.caster, cast.target, captured, bonus_options, cast.decisions, "shared_spell_attack")
			SpellDamageRolls.publish_resolution_windows(cast, pending_choice)
			return pending_choice
	return _finish_attack(cast, attack_result, target_ac, spell_attack_advantage, spell_attack_disadvantage, reaction_msg, seeking_spell_used, stroke_of_luck_used, {})


static func resume_numeric_bonus(record: Dictionary, selected: Dictionary) -> Dictionary:
	var captured: Dictionary = record.get("context", {})
	var cast: SpellResolutionContext = captured.get("spell_cast")
	if cast == null:
		return {"success": false, "refused": true, "message": "The captured spell attack is no longer available."}
	var attack_result: Dictionary = captured.get("attack_result", {}).duplicate(true)
	if not selected.is_empty() and str(selected.get("resolution", "")) not in ["outcome_override", "attack_total_adjustment", "defending_ac_adjustment"]:
		var bonus := int(selected.get("bonus_amount", selected.get("amount", 0)))
		attack_result["total"] = int(attack_result.get("total", 0)) + bonus
		attack_result["post_roll_bonus"] = bonus
		attack_result["post_roll_bonus_source"] = str(selected.get("source_instance_id", ""))
		if str(selected.get("bonus_kind", "numeric")) == "die":
			var bonus_roll: Dictionary = selected.get("bonus_roll", {})
			var bonus_terms: Array = attack_result.get("bonus_dice_terms", [])
			bonus_terms.append({
				"count": 1, "sides": int(selected.get("die_size", 0)),
				"results": bonus_roll.get("rolls", []).duplicate(true),
				"kept": bonus_roll.get("kept", []).duplicate(true),
				"label": str(selected.get("label", "Spell Attack Bonus")), "subtotal": bonus,
			})
			attack_result["bonus_dice_terms"] = bonus_terms
			attack_result["post_roll_bonus_die"] = bonus_roll.duplicate(true)
	return _finish_attack(cast, attack_result, int(captured.get("original_target_ac", 10)), bool(captured.get("spell_attack_advantage", false)), bool(captured.get("spell_attack_disadvantage", false)), str(captured.get("reaction_msg", "")), bool(captured.get("seeking_spell_used", false)), bool(captured.get("stroke_of_luck_used", false)), selected)


static func _finish_attack(cast: SpellResolutionContext, attack_result: Dictionary, original_target_ac: int, spell_attack_advantage: bool, spell_attack_disadvantage: bool, reaction_msg: String, seeking_spell_used: bool, stroke_of_luck_used: bool, selected_bonus: Dictionary) -> Dictionary:
	var tracks_resolution_windows := SharedSpell.uses(cast.spell)
	var original_attack_result: Dictionary = attack_result.duplicate(true)
	var target_ac := original_target_ac
	if str(selected_bonus.get("resolution", "")) == "outcome_override":
		attack_result["outcome_override"] = str(selected_bonus.get("outcome", ""))
		attack_result["outcome_override_source"] = str(selected_bonus.get("source_instance_id", ""))
		attack_result["outcome_override_domain"] = str(selected_bonus.get("domain", "shared_spell_attack"))
		attack_result["outcome_override_stage"] = str(selected_bonus.get("stage", "provisional_outcome"))
	var is_crit := bool(attack_result.get("is_crit", false))
	var override_outcome := str(attack_result.get("outcome_override", ""))
	# Settle native reactions from the numeric roll before applying the explicit
	# outcome. In particular, a forced miss must not consume Peerless Aim.
	var is_hit: bool = is_crit or (not bool(attack_result.get("is_miss", false)) and int(attack_result.get("total", 0)) >= target_ac)
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
	if override_outcome in ["hit", "miss"]:
		is_hit = override_outcome == "hit"
		if not is_hit:
			is_crit = false
			attack_result["is_crit"] = false
		elif (CombatAction.is_unconscious(cast.target) or CombatAction.is_paralyzed(cast.target)) and int(cast.spell.get("range", 6)) <= 1:
			is_crit = true
			attack_result["is_crit"] = true
	var adjustment_operation := str(selected_bonus.get("resolution", ""))
	if adjustment_operation in ["attack_total_adjustment", "defending_ac_adjustment"]:
		var adjusted := SpellDamageRolls.apply_attack_result_adjustment(attack_result, target_ac, selected_bonus)
		attack_result = adjusted.get("attack_result", attack_result)
		target_ac = int(adjusted.get("target_ac", target_ac))
		is_hit = is_crit or (not bool(attack_result.get("is_miss", false)) and int(attack_result.get("total", 0)) >= target_ac)
	var adjustment_cost_paid := false
	if not selected_bonus.is_empty():
		var payment_policy := "pay_on_choice" if str(selected_bonus.get("resolution", "")) == "outcome_override" else str(selected_bonus.get("payment_policy", "pay_on_choice"))
		if payment_policy not in SpellDamageRolls.FAILED_SAVE_BONUS_PAYMENT_POLICIES:
			return {"success": false, "refused": true, "message": "The selected attack bonus policy is unsupported."}
		if payment_policy == "pay_on_choice" or is_hit:
			var payment := ResourcePoolRules.spend(cast.caster, str(selected_bonus.get("source_instance_id", "")), int(selected_bonus.get("cost", 0)))
			if not bool(payment.get("success", false)):
				return {"success": false, "refused": true, "message": str(payment.get("message", "The selected attack source cannot pay."))}
			adjustment_cost_paid = true
	var adjustment_receipt := SpellDamageRolls.attack_adjustment_receipt(selected_bonus, original_attack_result, original_target_ac, attack_result, target_ac, is_hit, is_crit, adjustment_cost_paid, {"domain": "shared_spell_attack", "ability": cast.caster.get_spellcasting_ability(), "spell_id": str(cast.spell.get("id", "")), "advantage": spell_attack_advantage, "disadvantage": spell_attack_disadvantage})
	var token_replaced := bool(attack_result.get("roll_token_replaced", false))
	var token_id := str(attack_result.get("roll_token_id", ""))
	var token_value := int(attack_result.get("roll_token_value", 0))
	var numeric_margin_fields := {}
	if attack_result.has("natural") and attack_result.has("total"):
		# S-092 outcome overrides and S-095 numeric adjustments change final hit
		# independently. Keep the adjusted numeric margin beside the final outcome.
		numeric_margin_fields = {
			"numeric_margin": int(attack_result["total"]) - target_ac,
			"attack_target_ac": target_ac,
		}
	if not is_hit:
		FighterRules.record_miss(cast.caster, cast.target)
		if (cast.spell.has("miss_damage_scale") or cast.spell.has("damage_scale_by_outcome")) and cast.spell.has("damage"):
			if tracks_resolution_windows:
				var miss_window_fields := {
					"roll_natural": int(attack_result.get("natural", 0)),
					"roll_modifier": int(attack_result.get("modifier", 0)),
					"roll_total": int(attack_result.get("total", 0)),
					"target_ac": target_ac,
					"final_hit": false,
					"critical": false,
				}
				if not adjustment_receipt.is_empty(): miss_window_fields["attack_adjustment"] = adjustment_receipt.duplicate(true)
				var miss_override_receipt := _outcome_override_receipt(selected_bonus, override_outcome)
				if not miss_override_receipt.is_empty(): miss_window_fields["roll_outcome_override"] = miss_override_receipt
				SpellDamageRolls.record_resolution_window(cast, "pre_damage", miss_window_fields)
			var miss_damage_str := SpellDamageRolls.spell_damage_formula(cast.caster, cast.spell, cast.slot_level)
			var miss_damage_details := SpellDamageRolls._roll_spell_damage(cast.caster, miss_damage_str, 1, cast.decisions)
			var miss_base := {
				"success": true, "hit": false, "slot_level": cast.slot_level,
				"attack_roll": int(attack_result.get("total", 0)),
				"attack_advantage": spell_attack_advantage,
				"attack_disadvantage": spell_attack_disadvantage,
				"metamagic_used": seeking_spell_used, "stroke_of_luck_used": stroke_of_luck_used,
				"roll_token_replaced": token_replaced,
				"message": reaction_msg + "Spell misses for half damage: {damage} %s damage." % cast.spell.get("damage_type", "fire")
			}
			for field in numeric_margin_fields: miss_base[field] = numeric_margin_fields[field]
			if not selected_bonus.is_empty():
				if not adjustment_receipt.is_empty():
					miss_base["attack_adjustment_receipt"] = adjustment_receipt.duplicate(true)
					miss_base["original_attack_result"] = original_attack_result.duplicate(true)
					miss_base["original_target_ac"] = original_target_ac
				elif override_outcome in ["hit", "miss"]:
					_apply_outcome_override_metadata(miss_base, selected_bonus)
				else:
					_apply_post_roll_bonus_metadata(miss_base, selected_bonus)
					miss_base["post_roll_bonus_paid"] = str(selected_bonus.get("payment_policy", "pay_on_choice")) == "pay_on_choice"
			if token_replaced:
				miss_base["roll_token_id"] = token_id
				miss_base["roll_token_value"] = token_value
			if tracks_resolution_windows:
				miss_base["_resolution_context"] = cast
			var miss_scale := SharedSpell.authored_damage_scale(cast.spell, "miss", float(cast.spell.get("miss_damage_scale", 0.0)))
			SharedSpell.record_damage_scale(miss_base, cast.spell, "miss", miss_scale)
			return SpellDamageRolls._finish_spell_damage(cast.caster, cast.target, miss_damage_details, CombatAction.spell_damage_bonus(cast.caster, cast.spell), miss_scale, str(cast.spell.get("damage_type", "fire")), cast.decisions, miss_base)
		var miss_out := {"success": true, "hit": false, "slot_level": cast.slot_level, "attack_roll": attack_result["total"], "attack_advantage": spell_attack_advantage, "attack_disadvantage": spell_attack_disadvantage, "metamagic_used": seeking_spell_used, "stroke_of_luck_used": stroke_of_luck_used, "roll_token_replaced": token_replaced, "message": reaction_msg + "Spell missed! Ranged spell attack %d vs AC %d" % [attack_result["total"], target_ac]}
		for field in numeric_margin_fields: miss_out[field] = numeric_margin_fields[field]
		if not selected_bonus.is_empty():
			if not adjustment_receipt.is_empty():
				miss_out["attack_adjustment_receipt"] = adjustment_receipt.duplicate(true)
				miss_out["original_attack_result"] = original_attack_result.duplicate(true)
				miss_out["original_target_ac"] = original_target_ac
			elif override_outcome in ["hit", "miss"]:
				_apply_outcome_override_metadata(miss_out, selected_bonus)
			else:
				_apply_post_roll_bonus_metadata(miss_out, selected_bonus)
				miss_out["post_roll_bonus_paid"] = str(selected_bonus.get("payment_policy", "pay_on_choice")) == "pay_on_choice"
		if tracks_resolution_windows and not adjustment_receipt.is_empty():
			# This branch has no damage roll, so it never reaches _finish_spell_damage,
			# which normally publishes the settled pre-damage receipt. Keep the
			# selected adjustment inspectable in the same ordered result windows.
			SpellDamageRolls.record_resolution_window(cast, "pre_damage", {
				"roll_natural": int(attack_result.get("natural", 0)),
				"roll_modifier": int(attack_result.get("modifier", 0)),
				"roll_total": int(attack_result.get("total", 0)),
				"target_ac": target_ac,
				"final_hit": false,
				"critical": false,
				"attack_adjustment": adjustment_receipt.duplicate(true),
			})
		if token_replaced:
			miss_out["roll_token_id"] = token_id
			miss_out["roll_token_value"] = token_value
		SpellDamageRolls.publish_resolution_windows(cast, miss_out)
		return miss_out

	if tracks_resolution_windows:
		var hit_window_fields := {
			"roll_natural": int(attack_result.get("natural", 0)),
			"roll_modifier": int(attack_result.get("modifier", 0)),
			"roll_total": int(attack_result.get("total", 0)),
			"target_ac": target_ac,
			"final_hit": true,
			"critical": bool(attack_result.get("is_crit", false)),
		}
		if not adjustment_receipt.is_empty(): hit_window_fields["attack_adjustment"] = adjustment_receipt.duplicate(true)
		var hit_override_receipt := _outcome_override_receipt(selected_bonus, override_outcome)
		if not hit_override_receipt.is_empty(): hit_window_fields["roll_outcome_override"] = hit_override_receipt
		SpellDamageRolls.record_resolution_window(cast, "pre_damage", hit_window_fields)
	var damage_str := SpellDamageRolls.spell_damage_formula(cast.caster, cast.spell, cast.slot_level)
	var damage_type: String = cast.spell.get("damage_type", "fire")
	var is_sorcerous_burst := str(cast.spell.get("id", "")) == "sorcerous_burst"
	var rolled_damage_formula := "%s + %s" % [damage_str, damage_str] if bool(attack_result["is_crit"]) else damage_str
	var damage_details := SpellDamageRolls._roll_sorcerous_burst_damage(cast.caster, rolled_damage_formula, int(cast.spell.get("explode_on_max", 8)), str(cast.spell.get("maximum_bonus_dice_ability", "CHA"))) if is_sorcerous_burst else SpellDamageRolls._roll_spell_damage(cast.caster, damage_str, 2 if attack_result["is_crit"] else 1, cast.decisions)
	var authored_scale := SharedSpell.authored_damage_scale(cast.spell, "hit", 1.0)
	var damage_scale := authored_scale

	# Uncanny Dodge halves the settled roll, including any selected rerolls.
	if cast.target is Character and cast.target.reaction_available and (cast.target.has_feature("uncanny_dodge") or cast.target.has_feature("rogue_uncanny_dodge")) and CombatAction._reaction_accepted("uncanny_dodge", cast.decisions):
		cast.target.reaction_available = false
		damage_scale *= 0.5
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
	SharedSpell.record_damage_scale(hit_base, cast.spell, "hit", authored_scale)
	for field in numeric_margin_fields: hit_base[field] = numeric_margin_fields[field]
	if tracks_resolution_windows:
		hit_base["_resolution_context"] = cast
	if not selected_bonus.is_empty():
		if not adjustment_receipt.is_empty():
			hit_base["attack_adjustment_receipt"] = adjustment_receipt.duplicate(true)
			hit_base["original_attack_result"] = original_attack_result.duplicate(true)
			hit_base["original_target_ac"] = original_target_ac
		elif override_outcome in ["hit", "miss"]:
			_apply_outcome_override_metadata(hit_base, selected_bonus)
		else:
			_apply_post_roll_bonus_metadata(hit_base, selected_bonus)
			hit_base["post_roll_bonus_paid"] = true
	if token_replaced:
		hit_base["roll_token_id"] = token_id
		hit_base["roll_token_value"] = token_value
	var res := SpellDamageRolls._finish_spell_damage(cast.caster, cast.target, damage_details, CombatAction.spell_damage_bonus(cast.caster, cast.spell), damage_scale, damage_type, cast.decisions, hit_base, 1, attack_damage_packets)
	cast.decisions.erase("damage_is_critical")
	cast.decisions.erase("critical")
	return res


static func _apply_post_roll_bonus_metadata(result: Dictionary, selected_bonus: Dictionary) -> void:
	result["post_roll_bonus"] = int(selected_bonus.get("bonus_amount", selected_bonus.get("amount", 0)))
	result["post_roll_bonus_source"] = str(selected_bonus.get("source_instance_id", ""))
	if selected_bonus.get("bonus_roll", {}) is Dictionary and not selected_bonus.get("bonus_roll", {}).is_empty():
		result["post_roll_bonus_die"] = selected_bonus["bonus_roll"].duplicate(true)


static func _apply_outcome_override_metadata(result: Dictionary, selected: Dictionary) -> void:
	result["attack_outcome_override"] = str(selected.get("outcome", ""))
	result["attack_outcome_override_source"] = str(selected.get("source_instance_id", ""))
	result["attack_outcome_override_feature_id"] = str(selected.get("feature_id", ""))
	result["attack_outcome_override_pool_definition_id"] = str(selected.get("pool_definition_id", ""))
	result["attack_outcome_override_owner_id"] = str(selected.get("source_owner_id", ""))
	result["attack_outcome_override_domain"] = str(selected.get("domain", "shared_spell_attack"))
	result["attack_outcome_override_stage"] = str(selected.get("stage", "provisional_outcome"))
	result["attack_outcome_override_cost_paid"] = true


static func _outcome_override_receipt(selected: Dictionary, outcome: String) -> Dictionary:
	if str(selected.get("resolution", "")) != "outcome_override" or outcome not in ["hit", "miss"]:
		return {}
	return {
		"outcome": outcome,
		"source_instance_id": str(selected.get("source_instance_id", "")),
		"feature_id": str(selected.get("feature_id", "")),
		"pool_definition_id": str(selected.get("pool_definition_id", "")),
		"owner_id": str(selected.get("source_owner_id", "")),
		"domain": str(selected.get("domain", "shared_spell_attack")),
		"stage": str(selected.get("stage", "provisional_outcome")),
		"cost_paid": true,
	}


