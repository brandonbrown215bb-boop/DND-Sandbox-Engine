## Ordered shared spell boundary: validation, resources, interruption and dispatch.
class_name SpellResolver
extends RefCounted

static func resolve(caster: Character, target_entity, spell_data: Dictionary, deduct_slot: bool = false, reaction_decisions: Dictionary = {}, reaction_observers: Array = [], slot_level_override: int = 0, distance_feet: int = -1) -> Dictionary:
	var cast := SpellResolutionContext.new()
	cast.caster = caster
	cast.target = target_entity
	cast.spell = spell_data
	cast.decisions = reaction_decisions
	cast.observers = reaction_observers
	cast.distance_feet = distance_feet
	var support := SpellSupport.availability(cast.spell)
	if not support["available"]:
		return {"success": false, "unavailable": true, "message": support["reason"]}
	var ongoing_zone_trigger := bool(cast.spell.get("_ongoing_zone_trigger", false))
	if cast.caster.has_condition("raging") and not ongoing_zone_trigger:
		return {"success": false, "message": "You cannot cast spells while raging."}
	if not ongoing_zone_trigger and not DruidRules.can_cast_spell(cast.caster, cast.spell):
		return {"success": false, "message": "You cannot cast this spell while using Wild Shape."}
	if not ongoing_zone_trigger:
		var target_validation := CombatAction.validate_spell_target(cast.caster, cast.target, cast.spell, cast.distance_feet)
		if not target_validation.get("success", false):
			return target_validation
	if str(cast.spell.get("id", "")) == "spare_the_dying":
		return SpellHealingResolver.spare_the_dying(cast)
	var spell_level: int = int(cast.spell.get("level", 0))
	cast.slot_level = maxi(spell_level, slot_level_override)
	cast.incoming_slot_spent = false
	cast.incoming_slot_key = ""

	# Deduct spell slot if leveled spell
	if deduct_slot and spell_level > 0:
		var slot_result := CombatAction.spend_spell_slot(cast.caster, cast.spell)
		if not slot_result.get("success", false):
			return slot_result
		cast.slot_level = int(slot_result.get("slot_level", spell_level))
		cast.incoming_slot_spent = not bool(slot_result.get("slot_recalled", false))
		cast.incoming_slot_key = str(cast.slot_level)
	if not ongoing_zone_trigger:
		SpellEffects.consume_spell(cast.caster, "sanctuary")
		if str(cast.spell.get("id", "")) != "invisibility":
			SpellEffects.consume_spell(cast.caster, "invisibility")
	cast.effect_cast = cast.spell.get("_effect_cast", {})
	if SpellEffects.manages(cast.spell) and cast.effect_cast.is_empty():
		cast.effect_cast = SpellEffects.begin_cast(cast.caster, cast.spell)

	var interruption := _resolve_counterspell(cast)
	if not interruption.is_empty():
		return interruption

	if str(cast.spell.get("id", "")) == "disintegrate":
		var special := SpellControlResolver.disintegrate(cast)
		if not special.is_empty():
			return special
	if str(cast.spell.get("id", "")) == "power_word_stun":
		return SpellControlResolver.power_word_stun(cast)
	if str(cast.spell.get("id", "")) == "sleep":
		return SpellControlResolver.sleep(cast)
	if str(cast.spell.get("id", "")) == "revivify":
		return CorpseRules.revive(cast.target, int(GameManager.campaign_elapsed_seconds))
	if str(cast.spell.get("id", "")) == "gentle_repose":
		CorpseRules.preserve(cast.target, int(GameManager.campaign_elapsed_seconds))
		return {"success": true, "hit": true, "message": "%s’s remains are preserved for 10 days." % cast.target.character_name}
	if str(cast.spell.get("id", "")) == "regenerate":
		return SpellHealingResolver.regenerate(cast)
	if str(cast.spell.get("id", "")) == "animal_messenger":
		var special := SpellControlResolver.animal_messenger(cast)
		if not special.is_empty():
			return special
	if str(cast.spell.get("id", "")) == "hunters_mark":
		return SpellWardResolver.hunters_mark(cast)
	if str(cast.spell.get("id", "")) == "false_life":
		return SpellWardResolver.false_life(cast)
	if str(cast.spell.get("id", "")) == "divine_favor":
		return SpellWardResolver.divine_favor(cast)
	if str(cast.spell.get("id", "")) == "death_ward":
		return SpellWardResolver.death_ward(cast)
	if str(cast.spell.get("id", "")) == "sanctuary":
		return SpellWardResolver.sanctuary(cast)
	if str(cast.spell.get("id", "")) == "heroism":
		return SpellWardResolver.heroism(cast)
	if str(cast.spell.get("id", "")) == "magic_weapon":
		return SpellWardResolver.magic_weapon(cast)
	if str(cast.spell.get("id", "")) == "invisibility":
		return SpellWardResolver.invisibility(cast)
	if CombatAction._spell_directly_damages_target(cast.spell) and not CombatAction._spell_is_area_effect(cast.spell) and SpellEffects.has_spell(cast.target, "sanctuary"):
		var sanctuary_dc := CombatAction._spell_effect_save_dc(cast.target, "sanctuary", cast.caster.get_spell_save_dc())
		var sanctuary_save := int(cast.caster.saving_throw_test_to_dc("WIS", sanctuary_dc).get("total", 0))
		if sanctuary_save < sanctuary_dc:
			return {"success": true, "hit": false, "damage": 0, "sanctuary_blocked": true, "saved": true, "sanctuary_save_total": sanctuary_save, "sanctuary_save_dc": sanctuary_dc, "slot_level": cast.slot_level, "effect_cast": cast.effect_cast, "message": "%s fails the Wisdom save against Sanctuary; the spell has no effect on that creature." % cast.caster.character_name}
	if SharedSpell.uses(cast.spell):
		return SharedSpell.resolve(cast)
	if str(cast.spell.get("id", "")) in ["power_word_heal", "power_word_kill"]:
		return SpellHealingResolver._resolve_words_power_spell(cast.caster, cast.target, cast.spell, cast.decisions)

	if cast.spell.has("damage_per_dart"):
		return SpellProjectileResolver._resolve_magic_missile(cast.caster, cast.target, cast.spell, cast.decisions, cast.slot_level)
	if cast.spell.has("damage_per_ray"):
		return SpellProjectileResolver._resolve_scorching_ray(cast.caster, cast.target, cast.spell, cast.decisions, cast.slot_level, cast.distance_feet)
	cast.has_damage_payload = cast.spell.has("damage") or cast.spell.has("damage_per_dart") or cast.spell.has("damage_per_ray") or not cast.spell.get("damage_components", []).is_empty()
	if not cast.has_damage_payload and not CombatAction.spell_requires_saving_throw(cast.spell) and str(cast.spell.get("attack_type", "none")) == "none":
		return {"success": true, "hit": true, "damage": 0, "slot_level": cast.slot_level, "effect_cast": cast.effect_cast, "message": "%s resolves without a damage roll." % cast.spell.get("name", "Spell")}

	if CombatAction.spell_requires_saving_throw(cast.spell):
		return SpellSaveResolver.resolve(cast)
	return SpellAttackResolver.resolve(cast)


static func _resolve_counterspell(cast: SpellResolutionContext) -> Dictionary:
	# CombatState supplies only observers that can see the cast within range.
	var counterspell_candidates: Array = []
	for observer in cast.observers:
		if observer is Character and observer not in counterspell_candidates:
			counterspell_candidates.append(observer)
	var spell_components: Array = cast.spell.get("components", [])
	if spell_components.is_empty() or not spell_components.any(func(component): return str(component) in ["V", "S", "M"]):
		counterspell_candidates.clear()
	if not bool(cast.spell.get("_skip_counterspell", false)):
		for observer in counterspell_candidates:
			if not SpellSupport.is_available(DataLoader.get_spell("counterspell")):
				continue
			var counterspell_free: bool = observer.has_free_spell_cast("counterspell")
			var has_counterspell_slot := false
			for counterspell_slot_level in observer.spell_slots:
				if int(counterspell_slot_level) >= 3 and int(observer.spell_slots[counterspell_slot_level]) > 0:
					has_counterspell_slot = true
					break
			if not observer.reaction_available or "counterspell" not in observer.known_spells or (not has_counterspell_slot and not counterspell_free):
				continue
			var observer_key := "counterspell:%s" % observer.character_name
			var accepted := bool(cast.decisions.get(observer_key, cast.decisions.get("counterspell", false)))
			if not accepted:
				continue
			if counterspell_free:
				if not observer.spend_free_spell_cast("counterspell"):
					continue
			else:
				var counterspell_cost := CombatAction.spend_spell_slot(observer, DataLoader.get_spell("counterspell"))
				if not counterspell_cost.get("success", false):
					continue
			observer.reaction_available = false
			var counterspell_dc: int = observer.get_spell_save_dc()
			var save_total := int(cast.caster.saving_throw_test_to_dc("CON", counterspell_dc).get("total", 0))
			var saved_counterspell: bool = save_total >= counterspell_dc
			if not saved_counterspell:
				if cast.incoming_slot_spent and cast.caster.spell_slots.has(cast.incoming_slot_key):
					cast.caster.spell_slots[cast.incoming_slot_key] = int(cast.caster.spell_slots[cast.incoming_slot_key]) + 1
				return {
					"success": false,
					"countered": true,
					"counterspell_save_total": save_total,
					"counterspell_save_dc": counterspell_dc,
					"incoming_spell_slot_refunded": cast.incoming_slot_spent,
					"message": "[color=cyan]%s casts Counterspell; %s fails its Constitution save and the spell dissipates.[/color]" % [observer.character_name, cast.caster.character_name]
				}
			cast.decisions["counterspell_saved_by"] = observer.character_name
			cast.decisions["counterspell_save_total"] = save_total
			cast.decisions["counterspell_save_dc"] = counterspell_dc
	return {}
