## Spell selection and pre-target metamagic choices, before resources are spent.
class_name SpellCastSelection
extends RefCounted

static func choose_quickened(cast: SpellCastContext, candidate_spell: Dictionary) -> Dictionary:
	var apotheosis_free := cast.caster.has_feature("sorcerer_arcane_apotheosis") and cast.caster.has_condition("innate_sorcery") and not bool(cast.caster.feature_uses.get("sorcerer_arcane_apotheosis_used_this_turn", false))
	var used_levelled_spell := bool(cast.caster.feature_uses.get("sorcerer_levelled_spell_cast_this_turn", false))
	if SorcererRules.can_quicken_spell(cast.caster, candidate_spell, used_levelled_spell, cast.turn_budget, apotheosis_free):
		var free_cost := apotheosis_free
		var quickened_prompt := "Use Arcane Apotheosis to make Quickened Spell free?" if free_cost else "Spend 2 Sorcery Points to cast this action spell as a Bonus Action?"
		if await cast.hud.request_reaction(cast.owner_label, "metamagic:quickened", quickened_prompt, "Use Quickened Spell?", "Cast as Bonus Action", "Quickened Spell — %s" % cast.owner_label):
			return SorcererRules.apply_quickened_spell(candidate_spell, free_cost)
	return {}


static func choose(cast: SpellCastContext, spell_info: Dictionary) -> bool:
	if str(spell_info.get("id", "")) == "find_familiar":
		cast.hud.add_log("Find Familiar takes an hour. Cast it while exploring a room; combat does not support that casting time.")
		return false
	if str(spell_info.get("casting_time", "action")) == "reaction":
		cast.hud.add_log("That spell is reaction-only and is offered when its trigger occurs.")
		return false
	if bool(spell_info.get("_magic_item_activation", false)):
		cast.begin_targeting.call()
		cast.replace_spell(spell_info.duplicate(true))
		cast.hud.add_log("Activating %s. Select target hex." % str(spell_info.get("name", "Magic item")))
		return true
	var spell_lvl: int = int(spell_info.get("level", 0))
	var selected_pool := str(spell_info.get("_spell_slot_pool_id", SpellSlotRules.default_pool_id(cast.caster)))
	if spell_lvl > 0 and cast.caster != null:
		var slot_key := str(CombatAction.get_spell_slot_level(cast.caster, spell_info))
		var has_required_slot := SpellSlotRules.available(cast.caster, spell_lvl, selected_pool)
		if str(spell_info.get("id", "")) == "animal_messenger":
			has_required_slot = SpellSlotRules.available(cast.caster, spell_lvl, selected_pool)
		var selected_payment := str(spell_info.get("_spell_payment_kind", ""))
		var selected_payment_source := str(spell_info.get("_spell_payment_source_id", ""))
		var selected_free := selected_payment == "free_cast" and not cast.caster.free_spell_cast_feature(str(spell_info.get("id", "")), selected_payment_source).is_empty()
		if selected_payment == "free_cast" and bool(spell_info.get("_arcanum_payment", false)):
			selected_free = WarlockRules.arcanum_cast_level(cast.caster, str(spell_info.get("id", ""))) > 0
		if selected_payment == "slot":
			has_required_slot = has_required_slot
		elif selected_payment == "free_cast":
			has_required_slot = selected_free
		if selected_payment == "points":
			var selected_permission := {}
			for permission in SpellPermissionRules.for_spell(cast.caster, spell_info):
				if str(permission.get("id", "")) == str(spell_info.get("_source_permission_id", "")):
					selected_permission = permission
					break
			has_required_slot = SpellPermissionRules.can_pay_points(cast.caster, selected_permission, spell_lvl)
		if selected_payment == "item_charges":
			has_required_slot = SpellPermissionRules.selection_valid(cast.caster, spell_info)
		var payment_available := has_required_slot or selected_free
		if selected_payment.is_empty():
			payment_available = payment_available or cast.caster.has_free_spell_cast(str(spell_info.get("id", "")))
		if not payment_available:
			cast.hud.add_log("[color=orange]No level %s spell slots remaining for %s.[/color]" % [slot_key, spell_info.get("name", "this spell")])
			return false
	cast.begin_targeting.call()
	# S-140 (Batch 085): cast-local range/components/school/timing for this invocation only.
	cast.replace_spell(AttackProfileRules.apply_cast(cast.caster, spell_info))
	if cast.spell.has(AttackProfileRules.CAST_PROFILE_KEY):
		cast.hud.add_log("%s is changed for this casting by %s." % [str(cast.spell.get("name", "Spell")), ", ".join(cast.spell[AttackProfileRules.CAST_PROFILE_KEY].sources)])
	if str(cast.spell.get("id", "")) == "produce_flame":
		var flame_choice := await cast.hud.request_produce_flame_choice(cast.produce_flame_markers.has(cast.caster.character_id))
		if flame_choice.is_empty():
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			return false
		var flame_action_cost := ProduceFlameRules.action_cost_for_mode(flame_choice)
		if not cast.can_spend.call(flame_action_cost):
			cast.hud.add_log("You have no %s available for Produce Flame." % flame_action_cost.replace("_", " "))
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			return false
		if flame_choice == "hurl":
			if not cast.produce_flame_markers.has(cast.caster.character_id):
				cast.hud.add_log("You need an active flame to hurl it.")
				cast.clear_pending(SpellCastContext.CLEAR_ACTION)
				cast.clear_pending(SpellCastContext.CLEAR_SPELL)
				return false
			cast.spell["_produce_flame_hurl"] = true
			cast.spell["_skip_counterspell"] = true
			cast.spell["casting_time"] = "action"
			cast.spell["range"] = ProduceFlameRules.RANGE_HEXES
			cast.spell["target"] = "single"
			cast.spell["attack_type"] = "ranged_spell"
			cast.spell["damage"] = "1d8"
			cast.spell["damage_type"] = "fire"
			cast.spell["scaling"] = {"5": "2d8", "11": "3d8", "17": "4d8"}
		else:
			cast.spell["_produce_flame_create"] = true
	if bool(cast.spell.get("_force_spell_slot", false)) or str(cast.spell.get("id", "")) in ["command", "animal_messenger"]:
		var requested_slot_level := await cast.hud.request_spell_slot(cast.caster, spell_lvl, selected_pool)
		if requested_slot_level <= 0:
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.highlight_reachable.call()
			return false
		cast.spell["_selected_spell_slot_level"] = requested_slot_level
	elif int(cast.spell.get("upcast", {}).get("additional_targets_per_level", 0)) > 0:
		var has_higher_target_slot := false
		for slot_row in SpellSlotRules.pool_rows(cast.caster):
			if str(slot_row.pool_id) == selected_pool and int(slot_row.level) > spell_lvl and int(slot_row.remaining) > 0:
				has_higher_target_slot = true
				break
		if has_higher_target_slot:
			var requested_target_slot := await cast.hud.request_spell_slot(cast.caster, spell_lvl, selected_pool)
			if requested_target_slot <= 0:
				cast.clear_pending(SpellCastContext.CLEAR_ACTION)
				cast.clear_pending(SpellCastContext.CLEAR_SPELL)
				return false
			cast.spell["_selected_spell_slot_level"] = requested_target_slot
	var twinned_slot_level := CombatAction.get_spell_slot_level(cast.caster, cast.spell)
	var twinned_prior_count := int(bool(cast.spell.get("_metamagic_quickened", false)))
	var twinned_combo_allowed := twinned_prior_count == 0 or (cast.caster.has_condition("innate_sorcery") and twinned_prior_count < 2)
	var twinned_free_available := cast.caster.has_feature("sorcerer_arcane_apotheosis") and cast.caster.has_condition("innate_sorcery") and not bool(cast.caster.feature_uses.get("sorcerer_arcane_apotheosis_used_this_turn", false))
	if not bool(cast.spell.get("_produce_flame_hurl", false)) and cast.caster.class_id == "sorcerer" and twinned_combo_allowed and SorcererRules.can_twinned_spell(cast.caster, cast.spell, twinned_slot_level, twinned_free_available):
		var twinned_prompt := "Use Arcane Apotheosis to make Twinned Spell free? It adds one effective spell level and one target." if twinned_free_available else "Spend 1 Sorcery Point to add one effective spell level and one target."
		if await cast.hud.request_reaction(cast.owner_label, "metamagic:twinned", twinned_prompt, "Use Twinned Spell?", "Add One Target", "Twinned Spell — %s" % cast.owner_label):
			cast.replace_spell(SorcererRules.apply_twinned_spell(cast.spell))
			cast.spell["_metamagic_twinned_free"] = twinned_free_available
			cast.spell["_metamagic_twinned_extra_targets"] = SorcererRules.twinned_extra_target_count(cast.spell, twinned_slot_level + 1)
	var quickened_combo_allowed := (not bool(cast.spell.get("_metamagic_quickened", false)) and (not bool(cast.spell.get("_metamagic_twinned", false)) or cast.caster.has_condition("innate_sorcery"))) or cast.caster.has_condition("innate_sorcery")
	if not bool(cast.spell.get("_produce_flame_hurl", false)) and cast.caster.class_id == "sorcerer" and cast.caster.has_feature("sorcerer_metamagic") and "distant_spell" in cast.caster.sorcerer_metamagic_choices and int(cast.spell.get("range", 0)) >= 1 and quickened_combo_allowed:
		var distant_free_available := cast.caster.has_feature("sorcerer_arcane_apotheosis") and cast.caster.has_condition("innate_sorcery") and not bool(cast.caster.feature_uses.get("sorcerer_arcane_apotheosis_used_this_turn", false)) and not bool(cast.spell.get("_metamagic_quickened_free", false)) and not bool(cast.spell.get("_metamagic_twinned_free", false))
		if SorcererRules.remaining_metamagic_points(cast.caster, cast.spell) >= 1 or distant_free_available:
			var distant_prompt := "Use Distant Spell for free with Arcane Apotheosis?" if distant_free_available else "Spend 1 Sorcery Point to extend this spell's range with Distant Spell?"
			if await cast.hud.request_reaction(cast.owner_label, "metamagic:distant", distant_prompt, "Use Distant Spell?", "Extend Range", "Distant Spell — %s" % cast.owner_label):
				cast.spell["_metamagic_distant"] = true
				cast.spell["_metamagic_distant_free"] = distant_free_available
	var original_damage_type := str(cast.spell.get("damage_type", ""))
	var transmuted_options := SorcererRules.transmuted_damage_options(original_damage_type)
	var has_spell_damage := cast.spell.has("damage") or cast.spell.has("damage_per_dart") or cast.spell.has("damage_per_ray")
	var transmute_combo_allowed := (not bool(cast.spell.get("_metamagic_distant", false)) or cast.caster.has_condition("innate_sorcery")) and quickened_combo_allowed and (not bool(cast.spell.get("_metamagic_twinned", false)) or cast.caster.has_condition("innate_sorcery"))
	var transmuted_free_available := cast.caster.has_feature("sorcerer_arcane_apotheosis") and cast.caster.has_condition("innate_sorcery") and not bool(cast.caster.feature_uses.get("sorcerer_arcane_apotheosis_used_this_turn", false)) and not bool(cast.spell.get("_metamagic_distant_free", false)) and not bool(cast.spell.get("_metamagic_quickened_free", false)) and not bool(cast.spell.get("_metamagic_twinned_free", false))
	if not bool(cast.spell.get("_produce_flame_hurl", false)) and cast.caster.class_id == "sorcerer" and cast.caster.has_feature("sorcerer_metamagic") and "transmuted_spell" in cast.caster.sorcerer_metamagic_choices and not transmuted_options.is_empty() and has_spell_damage and transmute_combo_allowed and (SorcererRules.remaining_metamagic_points(cast.caster, cast.spell) >= 1 or transmuted_free_available):
		var transmuted_prompt := "Use Transmuted Spell free with Arcane Apotheosis?" if transmuted_free_available else "Spend 1 Sorcery Point to change this spell's damage type?"
		if await cast.hud.request_reaction(cast.owner_label, "metamagic:transmuted", transmuted_prompt, "Use Transmuted Spell?", "Change Damage Type", "Transmuted Spell — %s" % cast.owner_label):
			var selected_damage_type := await cast.hud.request_damage_type_choice(transmuted_options, "Transmuted Spell")
			if SorcererRules.apply_transmuted_damage_type(cast.spell, selected_damage_type):
				cast.spell["_metamagic_transmuted"] = true
				cast.spell["_metamagic_transmuted_free"] = transmuted_free_available
				cast.spell["_metamagic_original_damage_type"] = original_damage_type
	var seeking_prior_count := int(bool(cast.spell.get("_metamagic_distant", false))) + int(bool(cast.spell.get("_metamagic_transmuted", false))) + int(bool(cast.spell.get("_metamagic_twinned", false)))
	var seeking_free_available := cast.caster.has_feature("sorcerer_arcane_apotheosis") and cast.caster.has_condition("innate_sorcery") and not bool(cast.caster.feature_uses.get("sorcerer_arcane_apotheosis_used_this_turn", false)) and not bool(cast.spell.get("_metamagic_distant_free", false)) and not bool(cast.spell.get("_metamagic_transmuted_free", false)) and not bool(cast.spell.get("_metamagic_quickened_free", false)) and not bool(cast.spell.get("_metamagic_twinned_free", false))
	var seeking_is_spell_attack := str(cast.spell.get("attack_type", "none")) in ["ranged_spell", "melee_spell"] and not cast.spell.has("damage_per_dart") and not cast.spell.has("damage_per_ray")
	if not bool(cast.spell.get("_produce_flame_hurl", false)) and cast.caster.class_id == "sorcerer" and cast.caster.has_feature("sorcerer_metamagic") and "seeking_spell" in cast.caster.sorcerer_metamagic_choices and seeking_is_spell_attack and seeking_prior_count < 2 and (not bool(cast.spell.get("_metamagic_twinned", false)) or cast.caster.has_condition("innate_sorcery")) and (SorcererRules.remaining_metamagic_points(cast.caster, cast.spell) >= 1 or seeking_free_available):
		var seeking_prompt := "Use Arcane Apotheosis if this spell attack misses?" if seeking_free_available else "Spend 1 Sorcery Point only if this spell attack misses?"
		if await cast.hud.request_reaction(cast.owner_label, "metamagic:seeking", seeking_prompt, "Use Seeking Spell?", "Reroll a Miss", "Seeking Spell — %s" % cast.owner_label):
			cast.spell["_metamagic_seeking"] = true
			cast.spell["_metamagic_seeking_free"] = seeking_free_available
	var subtle_prior_count := int(bool(cast.spell.get("_metamagic_quickened", false))) + int(bool(cast.spell.get("_metamagic_distant", false))) + int(bool(cast.spell.get("_metamagic_transmuted", false))) + int(bool(cast.spell.get("_metamagic_seeking", false))) + int(bool(cast.spell.get("_metamagic_twinned", false)))
	var subtle_combo_allowed := subtle_prior_count == 0 or (cast.caster.has_condition("innate_sorcery") and subtle_prior_count < 2)
	var subtle_free_available := cast.caster.has_feature("sorcerer_arcane_apotheosis") and cast.caster.has_condition("innate_sorcery") and not bool(cast.caster.feature_uses.get("sorcerer_arcane_apotheosis_used_this_turn", false)) and not bool(cast.spell.get("_metamagic_quickened_free", false)) and not bool(cast.spell.get("_metamagic_distant_free", false)) and not bool(cast.spell.get("_metamagic_transmuted_free", false)) and not bool(cast.spell.get("_metamagic_seeking_free", false)) and not bool(cast.spell.get("_metamagic_twinned_free", false))
	if not bool(cast.spell.get("_produce_flame_hurl", false)) and SorcererRules.can_subtle_spell(cast.caster, cast.spell) and subtle_combo_allowed and (SorcererRules.remaining_metamagic_points(cast.caster, cast.spell) >= 1 or subtle_free_available):
		var subtle_prompt := "Use Subtle Spell free with Arcane Apotheosis?" if subtle_free_available else "Spend 1 Sorcery Point to remove this spell's components? Costly or consumed Materials will remain."
		if await cast.hud.request_reaction(cast.owner_label, "metamagic:subtle", subtle_prompt, "Use Subtle Spell?", "Remove Components", "Subtle Spell — %s" % cast.owner_label):
			var subtle_spell := SorcererRules.apply_subtle_spell(cast.spell)
			if bool(subtle_spell.get("_metamagic_subtle", false)):
				cast.replace_spell(subtle_spell)
				cast.spell["_metamagic_subtle_free"] = subtle_free_available
	if str(cast.spell.get("id", "")) == "find_steed":
		var steed_choice := await cast.hud.request_find_steed_choice(cast.spell)
		if steed_choice.is_empty():
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			return false
		cast.spell["_find_steed_choice"] = steed_choice
	var spell_name: String = cast.spell.get("name", "Spell")
	if FamiliarSpellDelivery.eligible(cast.spell) and not FamiliarSpellDelivery.creature(cast.caster, cast.players).is_empty():
		cast.spell["_familiar_delivery"] = await cast.hud.request_reaction(cast.owner_label, "familiar:touch_delivery", "Your familiar can deliver this Touch spell within 5 feet of itself, using its Reaction. You spend the spell's normal action and resources.", "Deliver through familiar?", "Use familiar", "Touch delivery")
	cast.hud.add_log("Casting %s. Select target hex." % spell_name)
	var count := SpellCastTargeting._spell_projectile_total(cast, cast.spell)
	if str(cast.spell.get("id", "")) in ["magic_missile", "scorching_ray", "eldritch_blast"]:
		cast.hud.show_hint("%s: %d projectiles remaining. Click a creature for each; you may choose the same creature again. Esc/Cancel to back out." % [spell_name, count])
	else:
		cast.hud.show_hint("%s: click a highlighted target. Esc/Cancel to back out." % spell_name)
	return true
