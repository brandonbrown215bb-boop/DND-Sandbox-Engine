## Saving-throw spell resolution and its existing decisions.
class_name SpellSaveResolver
extends RefCounted

static func resolve(cast: SpellResolutionContext) -> Dictionary:
	var save_ability: String = cast.spell.get("save", "DEX")
	var save_dc := 15 if str(cast.spell.get("id", "")) == "contact_other_plane" else int(cast.spell.get("_save_dc_override", cast.caster.get_spell_save_dc()))
	var contact_patron_saved := str(cast.spell.get("id", "")) == "contact_other_plane" and cast.caster.has_feature("warlock_contact_patron")
	var willing_target_no_save := bool(cast.spell.get("willing_target_skips_save", false)) and cast.target is Character
	var careful_saved := not willing_target_no_save and SorcererRules.is_careful_spell_target(cast.caster, cast.spell, cast.target, cast.decisions.get("metamagic:careful_targets", []))
	var save_test: Dictionary = {}
	# Roll save for target
	var save_roll := 0
	var poison_save_advantage := false
	if cast.target is Character:
		poison_save_advantage = cast.target.has_condition("protection_from_poison") and CombatAction.spell_grants_condition(cast.spell, "poisoned")
	elif cast.target is Dictionary:
		poison_save_advantage = cast.target.get("conditions", {}).has("protection_from_poison") and CombatAction.spell_grants_condition(cast.spell, "poisoned")
	var target_save_advantage := poison_save_advantage or (cast.target is Dictionary and bool(cast.spell.get("save_advantage_if_fighting_target", false)))
	var auto_fail_creature_types: Array = cast.spell.get("auto_fail_save_creature_types", [])
	var target_creature_type := ""
	if cast.target is Character:
		target_creature_type = cast.target.get_creature_type()
	elif cast.target is Dictionary:
		target_creature_type = str(cast.target.get("creature_type", ""))
	var target_save_disadvantage: bool = target_creature_type in cast.spell.get("save_disadvantage_creature_types", [])
	target_save_disadvantage = target_save_disadvantage or (save_ability == "DEX" and CombatAction.has_condition(cast.target, "restrained"))
	var paralyzed_save_auto_fail := CombatAction.is_paralyzed(cast.target) and save_ability in ["STR", "DEX"]
	var object_without_ability_scores: bool = cast.target is Dictionary and bool(cast.target.get("is_object", false)) and not cast.target.has("ability_scores")
	var automatically_fails: bool = not contact_patron_saved and (target_creature_type in auto_fail_creature_types or paralyzed_save_auto_fail or (save_ability in ["STR", "DEX"] and object_without_ability_scores))
	var heightened := bool(cast.decisions.get("metamagic:heightened", false)) and not automatically_fails and not careful_saved and not contact_patron_saved and cast.caster.class_id == "sorcerer" and "heightened_spell" in cast.caster.sorcerer_metamagic_choices and str(cast.spell.get("target", "")) == "single"
	if heightened and not SorcererRules.spend_metamagic_cost(cast.caster, 2, cast.decisions):
		heightened = false
	if contact_patron_saved:
		save_test = {"total": save_dc, "success": true}
		save_roll = save_dc
	elif automatically_fails:
		save_test = {"total": -1000, "success": false}
		save_roll = -1000
	elif willing_target_no_save:
		save_test = {"total": 0, "success": false}
		save_roll = 0
	elif cast.target is Character:
		save_test = cast.target.saving_throw_test_to_dc(save_ability, save_dc, target_save_advantage, heightened or target_save_disadvantage)
		save_roll = int(save_test.get("total", 0))
	elif cast.target is Dictionary:
		# Monster stats
		save_roll = BarbarianRules.roll_monster_save(cast.target, save_ability)
		var save_has_advantage: bool = target_save_advantage and not target_save_disadvantage and not heightened
		var save_has_disadvantage: bool = (target_save_disadvantage or heightened) and not target_save_advantage
		if save_has_disadvantage:
			save_roll = mini(save_roll, BarbarianRules.roll_monster_save(cast.target, save_ability))
		elif save_has_advantage:
			save_roll = maxi(save_roll, BarbarianRules.roll_monster_save(cast.target, save_ability))
		if save_ability in ["STR", "DEX"] and cast.target.get("conditions", {}).has("stunned"):
			save_roll = -1000

	var saved := contact_patron_saved or careful_saved or (not willing_target_no_save and save_roll >= save_dc)
	var target_name: String = cast.target.character_name if cast.target is Character else str(cast.target.get("name", "Target"))
	var countercharm_used := false
	var inflicted_condition := str(cast.spell.get("condition_on_failed_save", ""))
	if SharedSpell.uses(cast.spell) and CombatAction.spell_grants_condition(cast.spell, "frightened"):
		# SharedSpell applies the grant; this name only enables Countercharm.
		inflicted_condition = "frightened"
	if not saved and not automatically_fails and cast.target is Character and inflicted_condition in ["charmed", "frightened"]:
		for observer in cast.observers:
			if not observer is Character or not observer.is_alive or CombatAction.is_incapacitated(observer) or not observer.has_feature("bard_countercharm") or not observer.reaction_available:
				continue
			var observer_key := "countercharm:%s" % observer.character_id
			if not bool(cast.decisions.get(observer_key, cast.decisions.get("countercharm:%s" % observer.character_name, cast.decisions.get("countercharm", false)))):
				continue
			observer.reaction_available = false
			save_test = cast.target.make_saving_throw_result(save_ability, true, heightened)
			save_test["dc"] = save_dc
			save_roll = int(save_test.get("total", 0))
			saved = save_roll >= save_dc
			countercharm_used = true
			break
	var stroke_of_luck_used := false
	if not saved and not automatically_fails and not willing_target_no_save and cast.target is Character:
		var stroke_key := "stroke_of_luck:%s" % cast.target.character_id
		var stroke_result := RogueRules.apply_stroke_of_luck(cast.target, save_test, bool(cast.decisions.get(stroke_key, cast.decisions.get("stroke_of_luck_save", false))))
		if stroke_result.get("used", false):
			save_test = stroke_result.get("result", save_test)
			save_roll = int(save_test.get("total", save_roll))
			saved = bool(save_test.get("success", save_roll >= save_dc))
			stroke_of_luck_used = true
	var bardic_inspiration_used := false
	if not saved and not automatically_fails and not willing_target_no_save and cast.target is Character:
		var inspiration_test := BardicInspirationRules.apply_to_test(cast.target, save_roll, save_dc, bool(cast.decisions.get("bardic_inspiration", false)))
		if inspiration_test.get("used", false):
			save_roll = int(inspiration_test["total"])
			saved = bool(inspiration_test["success"])
			bardic_inspiration_used = true
	
	# Roll damage
	var damage_components: Array = cast.spell.get("damage_components", [])
	var primary_component: Dictionary = damage_components[0] if not damage_components.is_empty() else {}
	var primary_damage_spell := cast.spell
	if not primary_component.is_empty():
		primary_damage_spell = {"damage": str(primary_component.get("damage", "0")), "level": int(cast.spell.get("level", 0)), "upcast": primary_component.get("upcast", cast.spell.get("upcast", {}))}
	var damage_str := SpellDamageRolls.spell_damage_formula(cast.caster, primary_damage_spell, cast.slot_level)
	var damage_type: String = primary_component.get("damage_type", cast.spell.get("damage_type", "fire"))
	var damage_details := SpellDamageRolls._roll_spell_damage(cast.caster, damage_str, 1, cast.decisions) if cast.has_damage_payload else {"dice_terms": [], "final_total": 0}
	var additional_damage_packets: Array[Dictionary] = []
	for component_index in range(1, damage_components.size()):
		var component: Dictionary = damage_components[component_index]
		var component_spell := {"damage": str(component.get("damage", "0")), "level": int(cast.spell.get("level", 0)), "upcast": component.get("upcast", cast.spell.get("upcast", {}))}
		var component_formula := SpellDamageRolls.spell_damage_formula(cast.caster, component_spell, cast.slot_level)
		var component_decisions := cast.decisions.duplicate()
		component_decisions.erase("spell_damage_context")
		var component_details := SpellDamageRolls._roll_spell_damage(cast.caster, component_formula, 1, component_decisions)
		additional_damage_packets.append({
			"details": component_details,
			"type": str(component.get("damage_type", "fire")),
			"label": str(component.get("label", "%s damage" % str(component.get("damage_type", "fire")).capitalize())),
			"formula": component_formula,
		})
	var damage_scale := 1.0
	
	var has_evasion := false
	if cast.target is Character and cast.target.has_feature_effect("evasion") and save_ability == "DEX" and bool(cast.spell.get("half_on_save", false)) and not CombatAction.is_incapacitated(cast.target):
		has_evasion = true

	if saved:
		if has_evasion:
			damage_scale = 0.0
		elif cast.spell.get("half_on_save", false):
			damage_scale = 0.0 if careful_saved else 0.5
		else:
			damage_scale = 0.0
	else:
		if has_evasion and cast.spell.get("half_on_save", false):
			damage_scale = 0.5
	var msg := ""
	if willing_target_no_save:
		msg = "%s willingly enters Resilient Sphere without a saving throw." % target_name
	elif contact_patron_saved:
		msg = "%s automatically succeeds on the Contact Other Plane saving throw through Contact Patron." % target_name
	elif saved:
		msg = "%s succeeded on %s save (DC %d) taking {damage} %s damage." % [target_name, save_ability, save_dc, damage_type]
	else:
		msg = "%s failed %s save (DC %d) taking {damage} %s damage." % [target_name, save_ability, save_dc, damage_type]
	if automatically_fails:
		if cast.target is Dictionary and bool(cast.target.get("is_object", false)):
			msg = "%s automatically fails the %s save, taking {damage} %s damage." % [target_name, save_ability, damage_type]
		else:
			msg = "%s automatically fails the %s save as a %s, taking {damage} %s damage." % [target_name, save_ability, target_creature_type.capitalize(), damage_type]
	if not cast.has_damage_payload and not contact_patron_saved and not willing_target_no_save:
		if saved:
			msg = "%s succeeded on %s save (DC %d)." % [target_name, save_ability, save_dc]
		else:
			msg = "%s failed %s save (DC %d)." % [target_name, save_ability, save_dc]
	if countercharm_used:
		msg += " Countercharm rerolled the save with Advantage."
	if bardic_inspiration_used:
		msg += " Bardic Inspiration adds to the saving throw."
	if careful_saved:
		msg += " Careful Spell causes the creature to succeed and take no damage."
	if not saved and not inflicted_condition.is_empty():
		msg += " %s is %s." % [target_name, inflicted_condition]
	
	if cast.target is Character and not cast.target.last_save_note.is_empty():
		msg += " " + cast.target.last_save_note
	if stroke_of_luck_used:
		msg += " Stroke of Luck turns the failed saving throw into a 20."
	var effective_save_disadvantage: bool = (target_save_disadvantage or heightened) and not target_save_advantage
	return SpellDamageRolls._finish_spell_damage(cast.caster, cast.target, damage_details, CombatAction.spell_damage_bonus(cast.caster, cast.spell) if cast.has_damage_payload else 0, damage_scale, damage_type, cast.decisions, {"success": true, "saved": saved, "save_total": save_roll, "save_dc": save_dc, "save_disadvantage": effective_save_disadvantage, "effect_cast": cast.effect_cast, "condition": inflicted_condition if not saved and not SharedSpell.uses(cast.spell) else "", "condition_source": "animal_friendship:%s" % cast.caster.character_id if str(cast.spell.get("id", "")) == "animal_friendship" else "", "caster_creature_type": cast.caster.creature_type, "countercharm_used": countercharm_used, "bardic_inspiration_used": bardic_inspiration_used, "stroke_of_luck_used": stroke_of_luck_used, "metamagic_used": careful_saved, "message": msg}, maxi(1, int(cast.spell.get("condition_duration", 1))), additional_damage_packets)


