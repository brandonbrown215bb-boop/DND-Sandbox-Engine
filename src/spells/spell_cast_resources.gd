## Metamagic and spell resources, spent at their existing cast boundaries.
class_name SpellCastResources
extends RefCounted

static func revalidate_selection(cast: SpellCastContext) -> bool:
	if cast.commit_guard.is_valid() and not cast.commit_guard.call():
		cast.hud.add_log("The parent action or its remaining units are no longer available.")
		cast.clear_pending(SpellCastContext.CLEAR_ACTION | SpellCastContext.CLEAR_SPELL)
		return false
	# Special legacy casts retain their existing authority; ordinary commands carry an ID.
	if not cast.spell.has("_source_permission_id"): return true
	if SpellPermissionRules.selection_valid(cast.caster, cast.spell): return true
	cast.hud.add_log("The selected spell source or payment is no longer available.")
	cast.clear_pending(SpellCastContext.CLEAR_ACTION | SpellCastContext.CLEAR_SPELL)
	if cast.highlight_reachable.is_valid(): cast.highlight_reachable.call()
	return false

static func commit_metamagic(cast: SpellCastContext) -> bool:
	if not revalidate_selection(cast): return false
	var metamagic_cost_to_commit := 0
	var free_selections := 0
	for kind in ["quickened", "distant", "transmuted", "subtle", "twinned"]:
		if bool(cast.spell.get("_metamagic_" + kind, false)) and bool(cast.spell.get("_metamagic_" + kind + "_free", false)): free_selections += 1
	if free_selections > 0 and (free_selections > 1 or not cast.caster.has_feature("sorcerer_arcane_apotheosis") or not cast.caster.has_condition("innate_sorcery") or bool(cast.caster.feature_uses.get("sorcerer_arcane_apotheosis_used_this_turn", false))):
		cast.hud.add_log("The selected free Metamagic use is no longer available.")
		cast.clear_pending(SpellCastContext.CLEAR_ACTION | SpellCastContext.CLEAR_SPELL)
		if cast.highlight_reachable.is_valid(): cast.highlight_reachable.call()
		return false
	metamagic_cost_to_commit += SorcererRules.QUICKENED_SPELL_COST if bool(cast.spell.get("_metamagic_quickened", false)) else 0
	metamagic_cost_to_commit += 1 if bool(cast.spell.get("_metamagic_distant", false)) else 0
	metamagic_cost_to_commit += 1 if bool(cast.spell.get("_metamagic_transmuted", false)) else 0
	metamagic_cost_to_commit += 1 if bool(cast.spell.get("_metamagic_subtle", false)) else 0
	metamagic_cost_to_commit += SorcererRules.TWINNED_SPELL_COST if bool(cast.spell.get("_metamagic_twinned", false)) else 0
	var metamagic_free_costs := SorcererRules.QUICKENED_SPELL_COST * int(bool(cast.spell.get("_metamagic_quickened_free", false))) + int(bool(cast.spell.get("_metamagic_distant_free", false))) + int(bool(cast.spell.get("_metamagic_transmuted_free", false))) + int(bool(cast.spell.get("_metamagic_subtle_free", false)))
	metamagic_free_costs += int(bool(cast.spell.get("_metamagic_twinned_free", false)))
	var spell_points_to_commit := 0
	if cast.spell.get("_spell_payment_kind", "") == "points":
		var permission := SpellPermissionRules.selected_permission(cast.caster, cast.spell)
		if permission.get("point_payment", {}).get("resource_id", "") == "sorcery_points":
			spell_points_to_commit = SpellPermissionRules.point_payment_cost(permission, int(cast.spell.get("level", 0)))
	if cast.caster.class_id == "sorcerer" and cast.caster.get_sorcery_points() < spell_points_to_commit + maxi(0, metamagic_cost_to_commit - metamagic_free_costs):
		cast.hud.add_log("You do not have enough Sorcery Points for the selected Metamagic options.")
		cast.clear_pending(SpellCastContext.CLEAR_ACTION)
		cast.clear_pending(SpellCastContext.CLEAR_SPELL)
		cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
		cast.clear_pending(SpellCastContext.CLEAR_WISH)
		cast.highlight_reachable.call()
		return false
	if bool(cast.spell.get("_metamagic_quickened", false)):
		var quickened_cost_decisions := {"metamagic:arcane_apotheosis": bool(cast.spell.get("_metamagic_quickened_free", false))}
		if not SorcererRules.spend_metamagic_cost(cast.caster, SorcererRules.QUICKENED_SPELL_COST, quickened_cost_decisions):
			cast.hud.add_log("Quickened Spell needs 2 Sorcery Points or an unused Arcane Apotheosis use.")
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
			cast.clear_pending(SpellCastContext.CLEAR_WISH)
			cast.highlight_reachable.call()
			return false
		cast.hud.add_log("Quickened Spell casts this spell as a Bonus Action.")
	if bool(cast.spell.get("_metamagic_distant", false)):
		var distant_cost_decisions := {"metamagic:arcane_apotheosis": bool(cast.spell.get("_metamagic_distant_free", false))}
		if not SorcererRules.spend_metamagic_cost(cast.caster, 1, distant_cost_decisions):
			cast.hud.add_log("Distant Spell needs 1 Sorcery Point or an unused Arcane Apotheosis use.")
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
			cast.clear_pending(SpellCastContext.CLEAR_WISH)
			cast.highlight_reachable.call()
			return false
	if bool(cast.spell.get("_metamagic_transmuted", false)):
		var transmuted_cost_decisions := {"metamagic:arcane_apotheosis": bool(cast.spell.get("_metamagic_transmuted_free", false))}
		if not SorcererRules.spend_metamagic_cost(cast.caster, 1, transmuted_cost_decisions):
			cast.hud.add_log("Transmuted Spell needs 1 Sorcery Point or an unused Arcane Apotheosis use.")
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
			cast.clear_pending(SpellCastContext.CLEAR_WISH)
			cast.highlight_reachable.call()
			return false
		cast.hud.add_log("Transmuted Spell changes %s damage to %s." % [str(cast.spell.get("_metamagic_original_damage_type", "elemental")), str(cast.spell.get("damage_type", "elemental"))])
	if bool(cast.spell.get("_metamagic_subtle", false)):
		var subtle_cost_decisions := {"metamagic:arcane_apotheosis": bool(cast.spell.get("_metamagic_subtle_free", false))}
		if not SorcererRules.spend_metamagic_cost(cast.caster, 1, subtle_cost_decisions):
			cast.hud.add_log("Subtle Spell needs 1 Sorcery Point or an unused Arcane Apotheosis use.")
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
			cast.clear_pending(SpellCastContext.CLEAR_WISH)
			cast.highlight_reachable.call()
			return false
		cast.hud.add_log("Subtle Spell removes %s from the casting." % ", ".join(cast.spell.get("_metamagic_subtle_removed_components", [])))
	if bool(cast.spell.get("_metamagic_twinned", false)):
		var twinned_cost_decisions := {"metamagic:arcane_apotheosis": bool(cast.spell.get("_metamagic_twinned_free", false))}
		if not SorcererRules.spend_metamagic_cost(cast.caster, SorcererRules.TWINNED_SPELL_COST, twinned_cost_decisions):
			cast.hud.add_log("Twinned Spell needs 1 Sorcery Point or an unused Arcane Apotheosis use.")
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
			cast.clear_pending(SpellCastContext.CLEAR_WISH)
			cast.highlight_reachable.call()
			return false
		cast.hud.add_log("Twinned Spell raises the effective level by one and adds a target.")
	return true


static func commit_spell_resource(cast: SpellCastContext) -> bool:
	if not revalidate_selection(cast): return false
	var payment_permission := SpellPermissionRules.selected_permission(cast.caster, cast.spell)
	if cast.divine_intervention:
		if not cast.turn_budget.can_spend("magic_action") or not cast.caster.use_feature("cleric_divine_intervention"):
			cast.hud.add_log("Divine Intervention is unavailable or you have no Magic action.")
			cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.highlight_reachable.call()
			return false
		var recovery_rests := ClericRules.apply_greater_intervention_cooldown(cast.caster, "wish" if cast.divine_intervention_wish else str(cast.spell.get("id", "")))
		if recovery_rests > 0:
			cast.hud.add_log("Wish locks Divine Intervention for %d Long Rests." % recovery_rests)
	# Deduct spell slot if leveled spell
	cast.spell_level = int(cast.spell.get("level", 0))
	cast.slot_level_used = cast.spell_level
	cast.incoming_slot_spent = false
	var magic_item_activation := bool(cast.spell.get("_magic_item_activation", false))
	if magic_item_activation:
		var instance_id := str(cast.spell.get("_magic_item_instance_id", ""))
		var charges := int(cast.spell.get("_magic_item_charges", 0))
		var wand_record := cast.caster.inventory.get_instance(instance_id)
		var charges_before := int(wand_record.get("state", {}).get("charges", 0))
		if str(wand_record.get("definition_id", "")) != "wand_of_magic_missiles" or cast.caster.inventory.equipped_instance_id(Inventory.Slot.HANDS) != instance_id or charges < 1 or charges > 3 or int(cast.spell.get("_selected_spell_slot_level", 0)) != charges or not cast.caster.inventory.spend_instance_charges(instance_id, charges):
			cast.hud.add_log("The Wand of Magic Missiles no longer has the selected charges available.")
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.highlight_reachable.call()
			return false
		cast.slot_level_used = charges
		if charges_before == charges:
			var destruction_roll := int(cast.spell.get("_test_magic_item_destruction_roll", randi_range(1, 20)))
			if destruction_roll == 1:
				cast.caster.inventory.destroy_instance(instance_id)
				cast.hud.add_log("The Wand of Magic Missiles expends its last charge, crumbles into ashes, and is destroyed.")
			else:
				cast.hud.add_log("The Wand of Magic Missiles expended its last charge. It survives the destruction roll (%d)." % destruction_roll)
		else:
			cast.hud.add_log("The Wand of Magic Missiles expended %d charge%s." % [charges, "" if charges == 1 else "s"])
	var selected_item_payment := str(cast.spell.get("_spell_payment_kind", "")) == "item_charges"
	if selected_item_payment:
		var permission := SpellPermissionRules.selected_permission(cast.caster, cast.spell)
		var copy_id := str(permission.source_id)
		var copy := cast.caster.inventory.get_instance(copy_id)
		copy.state["charges"] = int(copy.state.charges) - int(permission.charge_cost)
		cast.caster.inventory.copies.records[copy_id] = copy
	if cast.spell_level > 0 and not selected_item_payment and not cast.divine_intervention and not magic_item_activation:
		var spell_id := str(cast.spell.get("id", ""))
		var selected_payment := str(cast.spell.get("_spell_payment_kind", ""))
		var selected_payment_source := str(cast.spell.get("_spell_payment_source_id", ""))
		if selected_payment == "points":
			var selected_permission := {}
			for permission in SpellPermissionRules.for_spell(cast.caster, cast.spell):
				if str(permission.get("id", "")) == str(cast.spell.get("_source_permission_id", "")):
					selected_permission = permission
					break
			if not SpellPermissionRules.spend_points(cast.caster, selected_permission, cast.spell_level):
				cast.hud.add_log("The selected spell-point payment is no longer available.")
				cast.clear_pending(SpellCastContext.CLEAR_ACTION)
				cast.highlight_reachable.call()
				return false
			var point_cost := SpellPermissionRules.point_payment_cost(selected_permission, cast.spell_level)
			var point_resource := str(selected_permission.get("point_payment", {}).get("resource_id", "points"))
			cast.hud.add_log("%s spent %d %s to cast %s." % [cast.caster.character_name, point_cost, point_resource, cast.spell.get("name", spell_id)])
			selected_payment = "points_paid"
		var use_free_cast := (selected_payment == "free_cast" or (selected_payment.is_empty() and cast.caster.has_free_spell_cast(spell_id))) and not bool(cast.spell.get("_force_spell_slot", false))
		if selected_payment == "points_paid":
			cast.slot_level_used = cast.spell_level
		elif selected_payment == "free_cast" and bool(cast.spell.get("_arcanum_payment", false)):
			use_free_cast = true
			cast.slot_level_used = WarlockRules.arcanum_cast_level(cast.caster, spell_id)
			if cast.slot_level_used <= 0 or not WarlockRules.spend_arcanum_cast(cast.caster, spell_id):
				use_free_cast = false
				cast.hud.add_log("That Mystic Arcanum payment is no longer available.")
				cast.clear_pending(SpellCastContext.CLEAR_ACTION)
				cast.highlight_reachable.call()
				return false
		elif use_free_cast:
			if not cast.caster.spend_free_spell_cast(spell_id, selected_payment_source):
				cast.hud.add_log("[color=orange]No free cast remains for %s.[/color]" % cast.spell.get("name", "this spell"))
				cast.clear_pending(SpellCastContext.CLEAR_ACTION)
				cast.highlight_reachable.call()
				return false
			cast.hud.add_log("%s used its free Long Rest cast of %s." % [cast.caster.character_name, cast.spell.get("name", "this spell")])
		elif selected_payment.is_empty() and WarlockRules.arcanum_cast_level(cast.caster, spell_id) > 0:
			cast.slot_level_used = WarlockRules.arcanum_cast_level(cast.caster, spell_id)
			if not WarlockRules.spend_arcanum_cast(cast.caster, spell_id):
				cast.hud.add_log("[color=orange]That Mystic Arcanum cast has already been used.[/color]")
				cast.clear_pending(SpellCastContext.CLEAR_ACTION)
				cast.highlight_reachable.call()
				return false
			cast.hud.add_log("%s used the level %d Mystic Arcanum for %s." % [cast.caster.character_name, cast.slot_level_used, cast.spell.get("name", "this spell")])
		elif cast.caster.class_id == "warlock" and cast.spell_level > 5:
			cast.hud.add_log("[color=orange]This spell needs an available Mystic Arcanum.[/color]")
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.highlight_reachable.call()
			return false
		else:
			var slot_result := CombatAction.spend_spell_slot(cast.caster, cast.spell, int(cast.spell.get("_selected_spell_slot_level", 0)))
			if not slot_result.get("success", false):
				cast.hud.add_log("[color=orange]%s[/color]" % slot_result.get("message", "No spell slots remaining!"))
				cast.clear_pending(SpellCastContext.CLEAR_ACTION)
				cast.highlight_reachable.call()
				return false
			cast.slot_level_used = int(slot_result.get("slot_level", cast.spell_level))
			cast.incoming_slot_spent = not bool(slot_result.get("slot_recalled", false))
			cast.incoming_slot_pool_id = str(slot_result.get("slot_pool_id", "ordinary"))
			if slot_result.get("slot_recalled", false):
				cast.hud.add_log("[color=cyan]%s's Boon of Spell Recall preserves the level %d slot.[/color]" % [cast.caster.character_name, int(slot_result.get("slot_level", cast.spell_level))])
			else:
				cast.hud.add_log("%s expended a level %d spell slot." % [cast.caster.character_name, int(slot_result.get("slot_level", cast.spell_level))])
	if str(cast.spell.get("id", "")) == "black_tentacles":
		var black_tentacles_duration_rounds := 10
		if cast.slot_level_used >= 5:
			cast.spell["concentration"] = false
			black_tentacles_duration_rounds = 4800 if cast.slot_level_used <= 6 else 14400 if cast.slot_level_used <= 8 else -1
		if bool(cast.spell.get("_metamagic_extended", false)) and black_tentacles_duration_rounds > 0:
			black_tentacles_duration_rounds = mini(black_tentacles_duration_rounds * 2, 14400)
		cast.spell["_black_tentacles_duration_rounds"] = black_tentacles_duration_rounds
	if cast.spell_level > 0:
		SorcererRules.mark_spell_cast_this_turn(cast.caster, cast.spell)
	if bool(cast.spell.get("_metamagic_quickened", false)):
		cast.caster.feature_uses["sorcerer_quickened_spell_cast_this_turn"] = true
	cast.payment_receipt = CastInterruptionRules.payment_receipt(cast.caster, cast.spell, {"slot_level":cast.slot_level_used,"slot_pool_id":cast.incoming_slot_pool_id,"slot_recalled":not cast.incoming_slot_spent} if cast.incoming_slot_spent or cast.spell.get("_spell_payment_kind", "") == "slot" else {}, payment_permission)
	FamiliarSpellDelivery.commit(cast)
	return true


