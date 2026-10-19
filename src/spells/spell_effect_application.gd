## Applies resolved spell effects and movement; shared rolls stay in SpellResolver.
class_name SpellEffectApplication
extends RefCounted

static func apply(cast: SpellCastContext, p_target: Character = null, m_target: Dictionary = {}, spell_data: Dictionary = {}, origin: Vector2i = Vector2i.ZERO, target_coord: Vector2i = Vector2i.ZERO, resolution: Dictionary = {}) -> void:
	if bool(resolution.get("recipient_negated", false)): return
	if SharedSpell.uses(spell_data):
		SharedSpell.apply(cast.caster, p_target if p_target != null else m_target, spell_data, resolution)
		await _apply_repelling_blast(cast, m_target, spell_data, origin, resolution)
		return
	_apply_spell_specific(cast, p_target, m_target, spell_data, origin, resolution)
	_apply_hit_and_save_effects(cast, p_target, m_target, spell_data, resolution)
	await _apply_push(cast, p_target, m_target, spell_data, origin, target_coord, resolution)
	_apply_payloads(cast, p_target, m_target, spell_data, resolution)
	await _apply_repelling_blast(cast, m_target, spell_data, origin, resolution)


static func _apply_spell_specific(cast: SpellCastContext, p_target: Character = null, m_target: Dictionary = {}, spell_data: Dictionary = {}, origin: Vector2i = Vector2i.ZERO, resolution: Dictionary = {}) -> void:
	if str(spell_data.get("id", "")) in ["heal", "lesser_restoration"] and bool(resolution.get("success", false)) and p_target != null and cure_sight_rot(p_target):
		cast.hud.add_log("[color=cyan]%s's Sight Rot contagion ends.[/color]" % p_target.character_name)
	if str(spell_data.get("id", "")) in ["fly", "spider_climb", "freedom_of_movement", "water_walk"] and bool(resolution.get("success", false)) and p_target != null:
		var movement_spell := str(spell_data["id"])
		SpellEffects.grant(p_target, resolution.get("effect_cast", spell_data.get("_effect_cast", {})), movement_spell)
		var movement_benefit := "a 60-foot flying speed" if movement_spell == "fly" else "a climbing speed equal to its walking speed" if movement_spell == "spider_climb" else "a swimming speed equal to its walking speed" if movement_spell == "freedom_of_movement" else "the ability to move across liquid surfaces"
		cast.hud.add_log("[color=cyan]%s gains %s while the spell lasts.[/color]" % [p_target.character_name, movement_benefit])
	if str(spell_data.get("id", "")) == "goodberry" and bool(resolution.get("success", false)):
		var berry_cast: Dictionary = resolution.get("effect_cast", spell_data.get("_effect_cast", {}))
		if SpellEffects.grant_goodberries(cast.caster, berry_cast, int(spell_data.get("berry_count", 10))):
			cast.hud.add_log("[color=green]Ten Goodberries appear in %s's hand. They last 24 hours; eating one is a Bonus Action and restores 1 Hit Point.[/color]" % cast.caster.character_name)
	if str(spell_data.get("id", "")) == "identify" and bool(resolution.get("success", false)):
		var identify_cast: Dictionary = resolution.get("effect_cast", spell_data.get("_effect_cast", {}))
		var identify_source := str(identify_cast.get("source_id", ""))
		if not identify_source.is_empty() and spell_data.get("_identify_target", {}) is Dictionary:
			identify_cast["concentration"] = true
			identify_cast["identify_target"] = spell_data["_identify_target"].duplicate(true)
			cast.caster.spell_effects[identify_source] = identify_cast
			cast.hud.add_log("[color=cyan]%s begins Identify; keep concentration and remain in contact for 1 minute.[/color]" % cast.caster.character_name)
	if str(spell_data.get("id", "")) == "detect_poison_and_disease" and bool(resolution.get("success", false)):
		var detector: Character = p_target if p_target != null else cast.caster
		var detect_cast: Dictionary = resolution.get("effect_cast", spell_data.get("_effect_cast", {}))
		if detector != null and not detect_cast.is_empty():
			SpellEffects.grant(detector, detect_cast, "detect_poison_and_disease")
			cast.refresh_poison_senses.call()
	if str(spell_data.get("id", "")) == "detect_evil_and_good" and bool(resolution.get("success", false)):
		var detector: Character = p_target if p_target != null else cast.caster
		var detect_cast: Dictionary = resolution.get("effect_cast", spell_data.get("_effect_cast", {}))
		if detector != null and not detect_cast.is_empty():
			SpellEffects.grant(detector, detect_cast, "detect_evil_and_good")
			cast.refresh_creature_senses.call()
	if str(spell_data.get("id", "")) == "blur" and bool(resolution.get("success", false)):
		var blurred_target = p_target if p_target != null else m_target
		if blurred_target != null:
			SpellEffects.grant(blurred_target, resolution.get("effect_cast", spell_data.get("_effect_cast", {})), "blurred")
	if str(spell_data.get("id", "")) == "detect_magic" and bool(resolution.get("success", false)):
		var detector: Character = p_target if p_target != null else cast.caster
		var detect_cast: Dictionary = resolution.get("effect_cast", spell_data.get("_effect_cast", {}))
		if detector != null and not detect_cast.is_empty():
			var detect_duration := 1200 if bool(spell_data.get("_metamagic_extended", false)) else 600
			SpellEffects.grant(detector, detect_cast, "detect_magic", "start", detect_duration)
			var found := DetectMagicRules.auras_within(origin, cast.players, cast.monsters, cast.areas.active_spell_zones)
			cast.hud.add_log("[color=cyan]Detect Magic senses %d represented magical effect%s within 30 feet for up to 10 minutes.[/color]" % [found.size(), "" if found.size() == 1 else "s"])
	if str(spell_data.get("id", "")) == "barkskin" and bool(resolution.get("success", false)):
		var barkskin_target = p_target if p_target != null else m_target
		if not m_target.is_empty() or p_target != null:
			if SpellEffects.grant_barkskin(barkskin_target, resolution.get("effect_cast", {}), 17):
				cast.hud.add_log("[color=cyan]%s's AC can't be lower than 17 for 1 hour.[/color]" % (p_target.character_name if p_target != null else str(m_target.get("name", "The target"))))
	if str(spell_data.get("id", "")) == "resilient_sphere":
		if bool(resolution.get("saved", false)):
			cast.end_concentration.call(cast.caster)
		else:
			cast.hud.add_log("[color=cyan]%s is enclosed by Resilient Sphere and protected by its barrier.[/color]" % (p_target.character_name if p_target != null else m_target.get("name", "The target")))
	if str(spell_data.get("id", "")) == "disintegrate" and bool(resolution.get("sphere_destroyed", false)):
		cast.end_resilient_sphere.call(p_target if p_target != null else m_target)
	if str(spell_data.get("id", "")) == "remove_curse" and resolution.get("success", false):
		if p_target != null and p_target.has_condition("cursed"):
			p_target.remove_condition("cursed")
			cast.hud.add_log("[color=cyan]%s's curse ends.[/color]" % p_target.character_name)
		if p_target != null:
			var broken_item_attunements := p_target.inventory.break_cursed_item_attunements(p_target.character_id)
			if broken_item_attunements > 0:
				cast.hud.add_log("[color=cyan]Remove Curse breaks %s cursed item attunement%s.[/color]" % [broken_item_attunements, "" if broken_item_attunements == 1 else "s"])
		elif not m_target.is_empty() and m_target.get("conditions", {}).has("cursed"):
			m_target.get("conditions", {}).erase("cursed")
			cast.hud.add_log("[color=cyan]%s's curse ends.[/color]" % m_target.get("name", "The target"))
	if str(spell_data.get("id", "")) == "ray_of_enfeeblement" and resolution.get("success", false) and resolution.get("saved", false):
		cast.end_concentration.call(cast.caster)
		var saved_ray_cast: Dictionary = resolution.get("effect_cast", {}).duplicate(true)
		saved_ray_cast["concentration"] = false
		SpellEffects.grant(p_target if p_target != null else m_target, saved_ray_cast, "vicious_mockery_disadvantage", "start", 6)
	if str(spell_data.get("id", "")) == "protection_from_poison" and resolution.get("success", false):
		if p_target != null:
			if p_target.has_condition("poisoned"):
				p_target.remove_condition("poisoned")
			p_target.add_condition("protection_from_poison", 600)
			cast.hud.add_log("[color=cyan]%s's poison is neutralized; the target gains Poison resistance and Advantage against being Poisoned for 1 hour.[/color]" % p_target.character_name)
		elif not m_target.is_empty():
			var monster_conditions: Dictionary = m_target.get("conditions", {})
			monster_conditions.erase("poisoned")
			monster_conditions["protection_from_poison"] = maxi(600, int(monster_conditions.get("protection_from_poison", 0)))
			m_target["conditions"] = monster_conditions
			cast.hud.add_log("[color=cyan]%s's poison is neutralized and it gains Poison resistance for 1 hour.[/color]" % m_target.get("name", "Target"))
	if str(spell_data.get("id", "")) == "protection_from_evil_and_good" and resolution.get("success", false):
		var protected_types: Array = spell_data.get("protected_creature_types", []).duplicate()
		var source_id := cast.caster.character_id
		if p_target != null:
			p_target.protection_from_evil_and_good_sources[source_id] = protected_types
			cast.hud.add_log("[color=cyan]%s is protected from Aberrations, Celestials, Elementals, Fey, Fiends, and Undead while %s concentrates.[/color]" % [p_target.character_name, cast.caster.character_name])
		elif not m_target.is_empty():
			var sources: Dictionary = m_target.get("protection_from_evil_and_good_sources", {})
			sources[source_id] = protected_types
			m_target["protection_from_evil_and_good_sources"] = sources
			cast.hud.add_log("[color=cyan]%s is protected from those creature types while %s concentrates.[/color]" % [m_target.get("name", "Target"), cast.caster.character_name])


static func cure_sight_rot(target: Character) -> bool:
	if target == null or not target.condition_sources.get("blinded", {}).has("disease:sight_rot"):
		return false
	CombatAction.remove_condition_source(target, "disease:sight_rot", ["blinded"])
	return true


static func _apply_hit_and_save_effects(cast: SpellCastContext, p_target: Character = null, m_target: Dictionary = {}, spell_data: Dictionary = {}, resolution: Dictionary = {}) -> void:
	var spell_target = p_target if p_target != null else m_target
	var delayed_damage := CombatAction.spell_delayed_damage_for_resolution(cast.caster, spell_data, resolution)
	if not delayed_damage.is_empty():
		if p_target != null:
			p_target.delayed_spell_damage.append(delayed_damage)
		elif not m_target.is_empty():
			var delayed_effects: Array = m_target.get("delayed_spell_damage", [])
			delayed_effects.append(delayed_damage)
			m_target["delayed_spell_damage"] = delayed_effects
		cast.hud.add_log("[color=cyan]%s is set to take %s %s damage at the end of its next turn.[/color]" % [p_target.character_name if p_target != null else m_target.get("name", "Target"), delayed_damage.get("formula", "0"), delayed_damage.get("damage_type", "acid")])
	var spell_source_id := str(cast.caster.get_instance_id()) if cast.caster != null else ""
	for applied in CombatAction.apply_spell_hit_effects(spell_target, spell_data, resolution, spell_source_id):
		var target_name := p_target.character_name if p_target != null else str(m_target.get("name", "Target"))
		match str(applied.get("condition", "")):
			"starry_wisp":
				cast.hud.add_log("[color=cyan]%s is marked by starlight and cannot benefit from Invisible until the end of its next turn.[/color]" % target_name)
			"guiding_bolt":
				cast.hud.add_log("[color=cyan]%s glows with dim light; the next attack against it has Advantage.[/color]" % target_name)
			"shocking_grasp":
				cast.hud.add_log("[color=cyan]%s cannot make Opportunity Attacks until the start of its next turn.[/color]" % target_name)
		if str(applied.get("type", "")) == "prevent_healing":
			cast.hud.add_log("[color=cyan]%s can't regain Hit Points until the end of %s's next turn.[/color]" % [target_name, cast.caster.character_name if cast.caster != null else "the caster"])
	for applied in CombatAction.apply_spell_failed_save_effects(spell_target, spell_data, resolution):
		var failed_save_target_name := p_target.character_name if p_target != null else str(m_target.get("name", "Target"))
		if str(applied.get("type", "")) == "command":
			var command_state := {"action": str(spell_data.get("_command_choice", "halt")), "caster_id": str(cast.caster.character_id if cast.caster != null else ""), "spell_id": "command"}
			if p_target != null:
				p_target.combat_command = command_state
			else:
				m_target["combat_command"] = command_state
			cast.hud.add_log("[color=cyan]%s must %s on its next turn.[/color]" % [failed_save_target_name, str(command_state["action"]).capitalize()])
			continue
		match str(applied.get("condition", "")):
			"resilient_sphere":
				cast.hud.add_log("[color=cyan]%s is enclosed by Resilient Sphere and protected by its barrier.[/color]" % failed_save_target_name)
			"paralyzed":
				cast.hud.add_log("[color=purple]%s is Paralyzed by %s.[/color]" % [failed_save_target_name, str(spell_data.get("name", "the spell"))])
			"vicious_mockery_disadvantage":
				cast.hud.add_log("[color=cyan]%s has Disadvantage on its next attack roll.[/color]" % failed_save_target_name)
			"blinded":
				cast.hud.add_log("[color=cyan]%s is Blinded until the end of its next turn.[/color]" % failed_save_target_name)


static func _apply_push(cast: SpellCastContext, p_target: Character = null, m_target: Dictionary = {}, spell_data: Dictionary = {}, origin: Vector2i = Vector2i.ZERO, target_coord: Vector2i = Vector2i.ZERO, resolution: Dictionary = {}) -> void:
	if bool(resolution.get("success", false)):
		for effect in spell_data.get("effects", []):
			if str(effect.get("type", "")) != "push" or (bool(effect.get("on_failed_save", false)) and bool(resolution.get("saved", false))):
				continue
			var push_distance := maxi(0, int(effect.get("distance", 1)))
			var push_target_name := p_target.character_name if p_target != null else str(m_target.get("name", "Target"))
			if p_target == null and m_target.is_empty(): continue
			var pushed_target = p_target if p_target != null else m_target
			var feet_moved: int = await cast.push_combat_target.call(pushed_target, origin, push_distance, false)
			if feet_moved > 0:
				cast.hud.add_log("[color=cyan]%s is pushed %d feet away.[/color]" % [push_target_name, feet_moved])


static func _apply_payloads(cast: SpellCastContext, p_target: Character = null, m_target: Dictionary = {}, spell_data: Dictionary = {}, resolution: Dictionary = {}) -> void:
	var spell_target = p_target if p_target != null else m_target
	var effects: Array = CombatAction.spell_effects_for_slot_level(spell_data, int(resolution.get("slot_level", spell_data.get("level", 0))))
	for effect in effects:
		var type: String = effect.get("type", "")
		if bool(effect.get("on_spell_hit", false)) or bool(effect.get("on_failed_save", false)):
			continue
		match type:
			"alter_self_natural_weapons":
				if p_target != null and p_target == cast.caster:
					var damage_type := str(spell_data.get("_alter_self_natural_damage_type", ""))
					if damage_type in ["slashing", "piercing", "bludgeoning"]:
						SpellEffects.grant(p_target, resolution.get("effect_cast", spell_data.get("_effect_cast", {})), "alter_self_natural_%s" % damage_type)
						cast.hud.add_log("[color=cyan]%s grows natural weapons that deal %s damage and use its spellcasting ability for Unarmed Strikes.[/color]" % [p_target.character_name, damage_type.capitalize()])
			"aid_hp_bonus":
				if p_target != null:
					var applied := SpellEffects.grant_aid(p_target, resolution.get("effect_cast", spell_data.get("_effect_cast", {})), int(effect.get("value", 5)))
					if applied:
						cast.hud.add_log("[color=cyan]%s gains %d to its current and maximum Hit Points for 8 hours.[/color]" % [p_target.character_name, int(effect.get("value", 5))])
					else:
						cast.hud.add_log("[color=gray]%s already benefits from Aid or can't receive its benefit.[/color]" % p_target.character_name)
			"damage_resistance":
				var damage_type := str(spell_data.get("_protection_from_energy_type", ""))
				if damage_type not in effect.get("damage_types", []):
					continue
				if p_target != null:
					p_target.protection_from_energy_type = damage_type
					cast.hud.add_log("[color=cyan]%s gains resistance to %s damage while %s concentrates.[/color]" % [p_target.character_name, damage_type, cast.caster.character_name])
				elif not m_target.is_empty():
					m_target["protection_from_energy_type"] = damage_type
					cast.hud.add_log("[color=cyan]%s gains resistance to %s damage while %s concentrates.[/color]" % [m_target.get("name", "Target"), damage_type, cast.caster.character_name])
			"disintegrate_on_zero":
				if p_target != null and p_target.current_hp <= 0 and not p_target.disintegrated:
					p_target.disintegrated = true
					CorpseRules.mark_dead(p_target, "disintegrate", "dust")
					cast.hud.add_log("[color=red]%s is disintegrated into gray dust and can return only through True Resurrection or Wish.[/color]" % p_target.character_name)
				elif not m_target.is_empty() and int(m_target.get("current_hp", 0)) <= 0:
					m_target["disintegrated"] = true
					cast.hud.add_log("[color=red]%s is disintegrated into gray dust.[/color]" % m_target.get("name", "Target"))
			"heal", "heal_self", "temporary_hp", "reduce_speed", "vision_bonus":
				if p_target != null:
					for result in EventResolver.apply_effects(p_target, [effect], cast.caster, SpellPermissionRules.selected_ability(cast.spell, cast.caster.get_spellcasting_ability())):
						cast.hud.add_log(result.get("message", ""))
				elif not m_target.is_empty() and type == "heal":
					var healing_formula := str(effect.get("value", "0"))
					var healing_request := Dice.parse_dice_string(healing_formula, {}, cast.caster)
					healing_request = SpellEffects.maximize_healing(m_target, healing_request, Dice.maximum_dice_string(healing_formula))
					if bool(effect.get("ability_bonus_from_caster", false)):
						healing_request += cast.caster.ability_scores.get_ability_modifier(SpellPermissionRules.selected_ability(cast.spell, cast.caster.get_spellcasting_ability()))
					var healing := 0
					if not CombatAction.is_healing_suppressed(m_target):
						healing = mini(maxi(0, healing_request), maxi(0, int(m_target.get("max_hp", 0)) - int(m_target.get("current_hp", 0))))
						m_target["current_hp"] = int(m_target.get("current_hp", 0)) + healing
						if healing > 0:
							m_target["is_alive"] = true
					cast.hud.add_log("%s regains %d Hit Points." % [str(m_target.get("name", "The target")), healing])
				elif not m_target.is_empty() and type == "reduce_speed":
					var reduction := maxi(0, int(effect.get("value", 2)))
					var duration := maxi(1, int(effect.get("duration", 1)))
					var conditions: Dictionary = m_target.get("conditions", {})
					if not conditions.has("speed_reduced"):
						m_target["speed_before_spell_slow"] = int(m_target.get("speed", 6))
						m_target["speed"] = maxi(0, int(m_target.get("speed", 6)) - reduction)
					conditions["speed_reduced"] = duration
					m_target["conditions"] = conditions
					cast.hud.add_log("[color=cyan]%s's movement is reduced by %d for %d turns.[/color]" % [m_target.get("name", "Target"), reduction, duration])
			"remove_condition", "remove_all_conditions":
				if p_target != null:
					for result in EventResolver.apply_effects(p_target, [effect], cast.caster):
						cast.hud.add_log(result.get("message", ""))
			"grant_condition":
				var cond = effect.get("condition", "")
				var dur = int(effect.get("duration", 3))
				if SpellEffects.manages(spell_data):
					SpellEffects.grant(spell_target, resolution.get("effect_cast", spell_data.get("_effect_cast", {})), str(cond))
					continue
				if p_target != null:
					p_target.add_condition(cond, dur)
					if str(spell_data.get("id", "")) == "guidance":
						p_target.guidance_skill = str(spell_data.get("_guidance_skill", ""))
					if str(spell_data.get("id", "")) == "resistance":
						p_target.resistance_damage_type = str(spell_data.get("_resistance_damage_type", ""))
						p_target.resistance_last_turn_serial = -1
					if str(spell_data.get("id", "")) == "shillelagh":
						p_target.shillelagh_weapon_id = p_target.inventory.get_weapon()
					cast.hud.add_log("[color=green]%s is now %s for %d turns![/color]" % [p_target.character_name, cond, dur])
				elif not m_target.is_empty():
					var immunities: Array = m_target.get("condition_immunities", [])
					if cond in immunities:
						cast.hud.add_log("[color=gray]%s is immune to %s.[/color]" % [m_target.get("name", "Target"), cond])
						continue
					var already_had_condition := int(m_target.get("conditions", {}).get(cond, 0)) > 0
					CombatAction.apply_condition(m_target, cond, dur)
					if str(spell_data.get("id", "")) == "longstrider" and not already_had_condition:
						m_target["speed"] = int(m_target.get("speed", 6)) + 2
					if str(spell_data.get("id", "")) == "resistance":
						m_target["resistance_damage_type"] = str(spell_data.get("_resistance_damage_type", ""))
						m_target["resistance_last_turn_serial"] = -1
					cast.hud.add_log("[color=green]%s is now %s for %d turns![/color]" % [m_target.get("name", "Target"), cond, dur])
			"ac_bonus":
				var val = int(effect.get("value", 5))
				var dur = int(effect.get("duration", 1))
				if p_target != null:
					p_target.add_condition("shield", dur)
					cast.hud.add_log("[color=green]%s is protected by a magical barrier (+5 AC)![/color]" % p_target.character_name)
			"set_base_ac":
				if p_target != null:
					SpellEffects.grant(p_target, resolution.get("effect_cast", {}), "mage_armor", "start")
					if SpellEffects.has_spell(p_target, "mage_armor"):
						cast.hud.add_log("[color=green]%s's base AC is 13 + Dexterity for up to 8 hours.[/color]" % p_target.character_name)


static func _apply_repelling_blast(cast: SpellCastContext, m_target: Dictionary = {}, spell_data: Dictionary = {}, origin: Vector2i = Vector2i.ZERO, resolution: Dictionary = {}) -> void:
	# Repelling Blast: Warlock cantrip hit pushes target 10 ft (2 hexes) away
	if not m_target.is_empty() and bool(resolution.get("hit", false)) and int(spell_data.get("level", -1)) == 0 and int(m_target.get("current_hp", 0)) > 0:
		if WarlockRules.has_repelling_blast(cast.caster, str(spell_data.get("id", ""))):
			var feet: int = await cast.push_combat_target.call(m_target, origin, 2)
			cast.hud.add_log("[color=cyan]Repelling Blast pushes %s %d feet away.[/color]" % [m_target.get("name", "Target"), feet])
