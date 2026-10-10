## Metamagic and spell resources, spent at their existing cast boundaries.
class_name SpellCastResources
extends RefCounted

static func commit_metamagic(cast: SpellCastContext) -> bool:
	var metamagic_cost_to_commit := 0
	metamagic_cost_to_commit += SorcererRules.QUICKENED_SPELL_COST if bool(cast.spell.get("_metamagic_quickened", false)) else 0
	metamagic_cost_to_commit += 1 if bool(cast.spell.get("_metamagic_distant", false)) else 0
	metamagic_cost_to_commit += 1 if bool(cast.spell.get("_metamagic_transmuted", false)) else 0
	metamagic_cost_to_commit += 1 if bool(cast.spell.get("_metamagic_subtle", false)) else 0
	metamagic_cost_to_commit += SorcererRules.TWINNED_SPELL_COST if bool(cast.spell.get("_metamagic_twinned", false)) else 0
	var metamagic_free_costs := int(bool(cast.spell.get("_metamagic_quickened_free", false))) + int(bool(cast.spell.get("_metamagic_distant_free", false))) + int(bool(cast.spell.get("_metamagic_transmuted_free", false))) + int(bool(cast.spell.get("_metamagic_subtle_free", false)))
	metamagic_free_costs += int(bool(cast.spell.get("_metamagic_twinned_free", false)))
	if cast.caster.class_id == "sorcerer" and cast.caster.get_sorcery_points() < maxi(0, metamagic_cost_to_commit - metamagic_free_costs):
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
	if cast.spell_level > 0 and not cast.divine_intervention and not magic_item_activation:
		var spell_id := str(cast.spell.get("id", ""))
		if cast.caster.has_free_spell_cast(spell_id) and not bool(cast.spell.get("_force_spell_slot", false)):
			if not cast.caster.spend_free_spell_cast(spell_id):
				cast.hud.add_log("[color=orange]No free cast remains for %s.[/color]" % cast.spell.get("name", "this spell"))
				cast.clear_pending(SpellCastContext.CLEAR_ACTION)
				cast.highlight_reachable.call()
				return false
			cast.hud.add_log("%s used its free Long Rest cast of %s." % [cast.caster.character_name, cast.spell.get("name", "this spell")])
		elif WarlockRules.arcanum_cast_level(cast.caster, spell_id) > 0:
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
	FamiliarSpellDelivery.commit(cast)
	return true


