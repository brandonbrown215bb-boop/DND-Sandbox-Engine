## Cast-wide reaction choices, Metamagic and effect preparation.
class_name SpellCastReactions
extends RefCounted

static func _collect_spell_cast_reactions(cast: SpellCastContext) -> void:
	cast.reaction_decisions = {}
	if bool(cast.spell.get("_metamagic_twinned", false)):
		cast.reaction_decisions["metamagic:twinned"] = true
		if bool(cast.spell.get("_metamagic_twinned_free", false)):
			cast.reaction_decisions["metamagic:arcane_apotheosis"] = true
	if bool(cast.spell.get("_metamagic_distant", false)):
		cast.reaction_decisions["metamagic:distant"] = true
		if bool(cast.spell.get("_metamagic_distant_free", false)):
			cast.reaction_decisions["metamagic:arcane_apotheosis"] = true
	if bool(cast.spell.get("_metamagic_transmuted", false)):
		cast.reaction_decisions["metamagic:transmuted"] = true
		if bool(cast.spell.get("_metamagic_transmuted_free", false)):
			cast.reaction_decisions["metamagic:arcane_apotheosis"] = true
	if bool(cast.spell.get("_metamagic_seeking", false)):
		cast.reaction_decisions["metamagic:seeking"] = true
		if bool(cast.spell.get("_metamagic_seeking_free", false)):
			cast.reaction_decisions["metamagic:arcane_apotheosis"] = true
	var apotheosis_already_assigned := bool(cast.spell.get("_metamagic_distant_free", false)) or bool(cast.spell.get("_metamagic_transmuted_free", false)) or bool(cast.spell.get("_metamagic_seeking_free", false)) or bool(cast.spell.get("_metamagic_quickened_free", false)) or bool(cast.spell.get("_metamagic_twinned_free", false))
	cast.apotheosis_available = cast.caster.has_feature("sorcerer_arcane_apotheosis") and cast.caster.has_condition("innate_sorcery") and not bool(cast.caster.feature_uses.get("sorcerer_arcane_apotheosis_used_this_turn", false)) and not apotheosis_already_assigned
	cast.apotheosis_assigned = apotheosis_already_assigned
	cast.quickened_selected = bool(cast.spell.get("_metamagic_quickened", false))
	cast.twinned_selected = bool(cast.spell.get("_metamagic_twinned", false))
	var already_selected_metamagic := int(cast.quickened_selected) + int(cast.twinned_selected) + int(bool(cast.reaction_decisions.get("metamagic:distant", false))) + int(bool(cast.reaction_decisions.get("metamagic:transmuted", false))) + int(bool(cast.reaction_decisions.get("metamagic:seeking", false)))
	var quickened_combo_allowed_at_innate := (not cast.quickened_selected or cast.caster.has_condition("innate_sorcery")) and (not cast.twinned_selected or cast.caster.has_condition("innate_sorcery"))
	if not bool(cast.spell.get("_produce_flame_hurl", false)) and cast.caster.has_feature("sorcerer_metamagic") and "empowered_spell" in cast.caster.sorcerer_metamagic_choices and already_selected_metamagic < 2 and quickened_combo_allowed_at_innate and (cast.caster.get_sorcery_points() > 0 or cast.apotheosis_available) and _spell_has_damage_payload(cast.spell):
		var empowered_free := cast.apotheosis_available
		var empowered_prompt := "Use Arcane Apotheosis to make this Metamagic free?" if empowered_free else "Spend 1 Sorcery Point to reroll selected damage dice (up to your Charisma modifier, minimum one). New rolls must stand."
		if await cast.hud.request_reaction(cast.owner_label, "metamagic:empowered", empowered_prompt, "Use Empowered Spell?", "Empower Spell", "Empowered Spell — %s" % cast.owner_label):
			cast.reaction_decisions["metamagic:empowered"] = true
			if empowered_free:
				cast.reaction_decisions["metamagic:arcane_apotheosis"] = true
				cast.apotheosis_assigned = true
	var prior_metamagic_count := int(cast.quickened_selected) + int(cast.twinned_selected) + int(bool(cast.reaction_decisions.get("metamagic:distant", false))) + int(bool(cast.reaction_decisions.get("metamagic:transmuted", false))) + int(bool(cast.reaction_decisions.get("metamagic:seeking", false))) + int(bool(cast.reaction_decisions.get("metamagic:empowered", false)))
	var heightened_combo_allowed := (prior_metamagic_count == 0 or (cast.caster.has_condition("innate_sorcery") and prior_metamagic_count < 2) or (prior_metamagic_count == 1 and bool(cast.reaction_decisions.get("metamagic:empowered", false)))) and quickened_combo_allowed_at_innate
	if cast.caster.has_feature("sorcerer_metamagic") and "heightened_spell" in cast.caster.sorcerer_metamagic_choices and heightened_combo_allowed and (cast.caster.get_sorcery_points() >= 2 or (cast.apotheosis_available and not cast.apotheosis_assigned)) and CombatAction.spell_requires_saving_throw(cast.spell) and cast.spell.get("target", "") == "single":
		var heightened_free := cast.apotheosis_available and not cast.apotheosis_assigned
		var heightened_prompt := "Use Arcane Apotheosis to make this Metamagic free?" if heightened_free else "Spend 2 Sorcery Points to give one target Disadvantage on its saving throw."
		if await cast.hud.request_reaction(cast.owner_label, "metamagic:heightened", heightened_prompt, "Use Heightened Spell?", "Heighten Spell", "Heightened Spell — %s" % cast.owner_label):
			cast.reaction_decisions["metamagic:heightened"] = true
			if heightened_free:
				cast.reaction_decisions["metamagic:arcane_apotheosis"] = true
	cast.spell_attack_available = _spell_has_attack(cast.spell)
	if cast.caster.has_feature("rogue_stroke_of_luck") and int(cast.caster.feature_uses.get("rogue_stroke_of_luck", 0)) > 0 and cast.spell_attack_available:
		if await cast.hud.request_reaction(cast.owner_label, "stroke_of_luck", "If this spell attack misses, turn the first missed d20 into a 20? The use is spent only if it misses.", "Use Stroke of Luck?", "Turn a Miss into 20", "Stroke of Luck — %s" % cast.owner_label):
			cast.reaction_decisions["stroke_of_luck"] = true

	cast.targets = []
	var active_position: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
	var counterspell_context: Dictionary = {"decisions": {}, "observers": []} if bool(cast.spell.get("_skip_counterspell", false)) else await cast.collect_counterspell_decisions.call(cast.caster, cast.spell, active_position, cast.caster)
	cast.counterspell_observers = counterspell_context.get("observers", [])
	cast.counterspell_decisions = counterspell_context.get("decisions", {})
	for decision_key in cast.reaction_decisions:
		cast.counterspell_decisions[decision_key] = cast.reaction_decisions[decision_key]
	if cast.spell_attack_available:
		cast.counterspell_decisions.merge(await cast.collect_attack_inspiration_decision.call(cast.caster), true)
	cast.counterspell_pending = true


static func _prepare_spell_cast_effects(cast: SpellCastContext) -> void:
	if bool(cast.reaction_decisions.get("metamagic:empowered", false)):
		cast.counterspell_decisions["defer_empowered"] = true
	if cast.target_type in ["area", "cone"]:
		cast.counterspell_decisions["spell_damage_context"] = {}
	var chosen_metamagic_count := int(cast.quickened_selected) + int(cast.twinned_selected) + int(bool(cast.reaction_decisions.get("metamagic:distant", false))) + int(bool(cast.reaction_decisions.get("metamagic:transmuted", false))) + int(bool(cast.reaction_decisions.get("metamagic:seeking", false))) + int(bool(cast.reaction_decisions.get("metamagic:empowered", false))) + int(bool(cast.reaction_decisions.get("metamagic:heightened", false)))
	var careful_combo_allowed := chosen_metamagic_count == 0 or (cast.caster.has_condition("innate_sorcery") and chosen_metamagic_count < 2)
	if cast.caster.has_feature("sorcerer_metamagic") and "careful_spell" in cast.caster.sorcerer_metamagic_choices and CombatAction.spell_requires_saving_throw(cast.spell) and careful_combo_allowed and (cast.caster.get_sorcery_points() > 0 or (cast.apotheosis_available and not cast.apotheosis_assigned)):
		var careful_candidates: Array[Dictionary] = []
		for target_hex in cast.targets:
			for player_entity in cast.players:
				var player_character: Character = player_entity["character"]
				if player_entity["hex_position"] == target_hex and player_character.is_alive:
					var player_id := SorcererRules.careful_spell_target_id(player_character)
					if not player_id.is_empty():
						careful_candidates.append({"id": player_id, "name": player_character.character_name})
					break
			for monster_entity in cast.monsters:
				if monster_entity["hex_position"] == target_hex and monster_entity["is_alive"]:
					var monster_id := SorcererRules.careful_spell_target_id(monster_entity)
					if not monster_id.is_empty():
						careful_candidates.append({"id": monster_id, "name": str(monster_entity.get("name", "Creature"))})
					break
		if not careful_candidates.is_empty():
			var careful_free := cast.apotheosis_available and not cast.apotheosis_assigned
			var careful_prompt := "Use Arcane Apotheosis to make this Metamagic free?" if careful_free else "Spend 1 Sorcery Point to choose creatures that automatically succeed on this spell's save."
			if await cast.hud.request_reaction(cast.owner_label, "metamagic:careful", careful_prompt, "Use Careful Spell?", "Careful Spell", "Careful Spell — %s" % cast.owner_label):
				var careful_ids := await cast.hud.request_sorcerer_careful_spell_targets(cast.caster, careful_candidates)
				if not careful_ids.is_empty():
					var careful_cost_decisions := {"metamagic:arcane_apotheosis": careful_free}
					if SorcererRules.spend_metamagic_cost(cast.caster, 1, careful_cost_decisions):
						cast.reaction_decisions["metamagic:careful"] = true
						cast.reaction_decisions["metamagic:careful_targets"] = careful_ids
						cast.counterspell_decisions["metamagic:careful"] = true
						cast.counterspell_decisions["metamagic:careful_targets"] = careful_ids
						if careful_free:
							cast.reaction_decisions["metamagic:arcane_apotheosis"] = true
							cast.counterspell_decisions["metamagic:arcane_apotheosis"] = true
							cast.apotheosis_assigned = true
					else:
						cast.hud.add_log("[color=orange]Careful Spell could not spend a Sorcery Point.[/color]")

	var extended_combo_count := chosen_metamagic_count + int(bool(cast.reaction_decisions.get("metamagic:careful", false)))
	var extended_combo_allowed := extended_combo_count == 0 or (cast.caster.has_condition("innate_sorcery") and extended_combo_count < 2)
	if SorcererRules.can_extend_spell(cast.caster, cast.spell) and extended_combo_allowed and (cast.caster.get_sorcery_points() > 0 or (cast.apotheosis_available and not cast.apotheosis_assigned)):
		var extended_free := cast.apotheosis_available and not cast.apotheosis_assigned
		var extended_prompt := "Use Arcane Apotheosis to make this Metamagic free?" if extended_free else "Spend 1 Sorcery Point to double this spell's duration (up to 24 hours) and gain Advantage on Concentration saves for it."
		if await cast.hud.request_reaction(cast.owner_label, "metamagic:extended", extended_prompt, "Use Extended Spell?", "Extend Spell", "Extended Spell — %s" % cast.owner_label):
			var extended_cost_decisions := {"metamagic:arcane_apotheosis": extended_free}
			if SorcererRules.spend_metamagic_cost(cast.caster, 1, extended_cost_decisions):
				cast.replace_spell(SorcererRules.apply_extended_spell(cast.spell))
				cast.reaction_decisions["metamagic:extended"] = true
				cast.counterspell_decisions["metamagic:extended"] = true
				if extended_free:
					cast.reaction_decisions["metamagic:arcane_apotheosis"] = true
					cast.counterspell_decisions["metamagic:arcane_apotheosis"] = true
					cast.apotheosis_assigned = true
			else:
				cast.hud.add_log("[color=orange]Extended Spell could not spend a Sorcery Point.[/color]")

	if not bool(cast.spell.get("_ignore_material_components", false)) and bool(cast.spell.get("material_component_consumed", false)) and not cast.component_item_id.is_empty():
		if not cast.component_instance_id.is_empty():
			cast.caster.inventory.take_instance(cast.component_instance_id)
		else:
			cast.caster.inventory.remove_item(cast.component_item_id)
		cast.hud.add_log("%s consumes %s." % [cast.spell.get("name", "The spell"), DataLoader.get_item(cast.component_item_id).get("name", cast.component_item_id)])

	# If spell requires concentration, handle existing concentration
	if SpellEffects.manages(cast.spell):
		cast.spell["_effect_cast"] = SpellEffects.begin_cast(cast.caster, cast.spell)
	var identify_casting := str(cast.spell.get("id", "")) == "identify"
	if identify_casting:
		cast.spell["_effect_cast"]["concentration"] = true
	if cast.spell.get("concentration", false) or identify_casting:
		cast.end_concentration.call(cast.caster)
		cast.caster.concentrating_on = {
			"spell_id": cast.spell["id"],
			"effects": cast.spell.get("effects", []),
			"targets": [],
			"extended_spell": bool(cast.spell.get("_metamagic_extended", false))
		}
		if SpellEffects.manages(cast.spell):
			cast.caster.concentrating_on["effect_source"] = cast.spell["_effect_cast"]["source_id"]
			cast.caster.concentrating_on["save_dc"] = cast.spell["_effect_cast"]["save_dc"]
		if str(cast.spell.get("id", "")) == "protection_from_energy":
			cast.caster.concentrating_on["duration_rounds_remaining"] = 1200 if bool(cast.spell.get("_metamagic_extended", false)) else 600
			cast.caster.concentrating_on["duration_started_round"] = cast.tracker.current_round
		elif str(cast.spell.get("id", "")) == "protection_from_evil_and_good":
			cast.caster.concentrating_on["duration_rounds_remaining"] = 200 if bool(cast.spell.get("_metamagic_extended", false)) else 100
			cast.caster.concentrating_on["duration_started_round"] = cast.tracker.current_round
		elif str(cast.spell.get("id", "")) == "ray_of_enfeeblement":
			cast.caster.concentrating_on["duration_rounds_remaining"] = 10
			cast.caster.concentrating_on["duration_started_round"] = cast.tracker.current_round
			cast.caster.concentrating_on["save_dc"] = cast.caster.get_spell_save_dc()
		elif str(cast.spell.get("id", "")) == "resilient_sphere":
			cast.caster.concentrating_on["duration_rounds_remaining"] = 20 if bool(cast.spell.get("_metamagic_extended", false)) else 10
			cast.caster.concentrating_on["duration_started_round"] = cast.tracker.current_round
		elif str(cast.spell.get("id", "")) == "hold_monster":
			cast.caster.concentrating_on["duration_rounds_remaining"] = 20 if bool(cast.spell.get("_metamagic_extended", false)) else 10
			cast.caster.concentrating_on["duration_started_round"] = cast.tracker.current_round
			cast.caster.concentrating_on["save_dc"] = cast.caster.get_spell_save_dc()


static func _spell_has_damage_payload(spell_data: Dictionary) -> bool:
	if spell_data.has("damage") or spell_data.has("damage_per_dart") or spell_data.has("damage_per_ray"):
		return true
	for step in spell_data.get("steps", []):
		if step is Dictionary and step.has("damage"):
			return true
	return false


static func _spell_has_attack(spell_data: Dictionary) -> bool:
	if str(spell_data.get("attack_type", "none")) in ["ranged_spell", "melee_spell"] or spell_data.has("damage_per_ray"):
		return true
	for step in spell_data.get("steps", []):
		if step is Dictionary and (step.get("type", "") == "attack" or str(step.get("attack_type", "none")) in ["ranged_spell", "melee_spell"]):
			return true
	return false
