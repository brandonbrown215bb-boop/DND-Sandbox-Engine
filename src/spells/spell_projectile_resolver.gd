## Missile and ray allocation, rolls and settled damage.
class_name SpellProjectileResolver
extends RefCounted

const DELIVERIES := ["automatic", "spell_attack"]
## Fields a projectiles block owns; a replaced native record must not backfill them.
const OWNED_FIELDS := ["damage", "scaling", "upcast", "save", "steps"]

## Shared data authors one generic `projectiles` block; native records keep their
## legacy per-dart/per-ray keys. Both resolve through the same allocation code.
static func is_projectile(spell_data: Dictionary) -> bool:
	return spell_data.get("projectiles") is Dictionary or spell_data.has("damage_per_dart") or spell_data.has("damage_per_ray")


static func view(spell_data: Dictionary) -> Dictionary:
	var block: Variant = spell_data.get("projectiles")
	if not block is Dictionary:
		return spell_data if is_projectile(spell_data) else {}
	var out := spell_data.duplicate(true)
	out.erase("projectiles")
	out["_projectile_noun"] = str(block.get("noun", ""))
	out["_shield_negates"] = bool(block.get("shield_negates", false))
	var extra := int(block.get("extra_per_slot_level", 0))
	if str(block.get("delivery", "")) == "automatic":
		out["damage_per_dart"] = str(block.get("damage", "1"))
		out["dart_count"] = int(block.get("count", 1))
		out["upcast"] = {"extra_darts_per_level": extra}
	else:
		out["damage_per_ray"] = str(block.get("damage", "1"))
		out["ray_count"] = int(block.get("count", 1))
		out["upcast"] = {"extra_rays_per_level": extra}
		if block.has("count_by_character_level"):
			out["beam_count_by_level"] = block["count_by_character_level"].duplicate(true)
	return out


static func noun(spell_data: Dictionary) -> String:
	var block: Variant = spell_data.get("projectiles")
	if block is Dictionary and not str(block.get("noun", "")).is_empty():
		return str(block["noun"])
	return "dart" if spell_data.has("damage_per_dart") else "ray"


static func shield_negates(spell_data: Dictionary) -> bool:
	var block: Variant = spell_data.get("projectiles")
	return block is Dictionary and bool(block.get("shield_negates", false))


static func block_error(block: Variant, level: int) -> String:
	if not block is Dictionary: return "Shared projectiles must be an object."
	for key in block:
		if str(key) not in ["noun", "delivery", "damage", "count", "count_by_character_level", "extra_per_slot_level", "shield_negates"]:
			return "Unsupported projectile field '%s'." % key
	if str(block.get("delivery", "")) not in DELIVERIES: return "Projectile delivery must be automatic or spell_attack."
	if str(block.get("noun", "")).is_empty(): return "Projectiles need a noun."
	var damage := str(block.get("damage", ""))
	if not SharedSpell._formula(damage.replace(" ", "")): return "Projectiles need a damage formula."
	if not block.get("count") is int and not (block.get("count") is float and float(block["count"]) == floorf(float(block["count"]))): return "Projectile count must be an integer."
	if int(block["count"]) < 1 or int(block["count"]) > 20: return "Projectile count must be 1-20."
	if int(block.get("extra_per_slot_level", 0)) < 0: return "extra_per_slot_level cannot be negative."
	if block.has("shield_negates") and not block["shield_negates"] is bool: return "shield_negates must be Boolean."
	if block.has("count_by_character_level"):
		if level != 0 or str(block["delivery"]) != "spell_attack": return "Character-level projectile counts are for attack cantrips."
		if not block["count_by_character_level"] is Dictionary or block["count_by_character_level"].is_empty(): return "count_by_character_level must be a nonempty object."
		for threshold in block["count_by_character_level"]:
			if not str(threshold).is_valid_int() or int(block["count_by_character_level"][threshold]) < 1: return "Projectile level bands need integer levels and counts."
	if level == 0 and int(block.get("extra_per_slot_level", 0)) != 0: return "Cantrip projectiles cannot add per slot level."
	return ""

static func _resolve_magic_missile(caster: Character, target_entity, spell_data: Dictionary, reaction_decisions: Dictionary = {}, slot_level: int = 0) -> Dictionary:
	var dart_count := SpellProjectileResolver.magic_missile_dart_count(spell_data, slot_level)
	var spell_name := str(spell_data.get("name", "Magic Missile"))
	# Legacy native dart records keep their historical Shield rule; shared records opt in by data.
	if target_entity is Character and bool(spell_data.get("_shield_negates", true)):
		if target_entity.has_condition("shield"):
			return {"success": true, "hit": true, "damage": 0, "dart_count": dart_count, "shield_blocked": true, "message": "%s takes no damage from %s because Shield blocks it." % [target_entity.character_name, spell_name]}
		var shield_payment := SpellPermissionRules.spend_reaction(target_entity, "shield", reaction_decisions) if target_entity.reaction_available and CombatAction._reaction_accepted("shield", reaction_decisions) else {}
		if not shield_payment.is_empty():
			target_entity.add_condition("shield", 1)
			var ward_events: Array = shield_payment.get("ward_events", [])
			var shield_msg := "%s casts Shield as a Reaction and takes no damage from %s." % [target_entity.character_name, spell_name]
			for ward_ev in ward_events:
				if not str(ward_ev.get("message", "")).is_empty():
					shield_msg += " " + str(ward_ev["message"])
			return {"success": true, "hit": true, "damage": 0, "dart_count": dart_count, "shield_blocked": true, "shield_used": true, "message": shield_msg}
	var damage_per_dart := str(spell_data.get("damage_per_dart", "1d4+1")).replace(" ", "")
	var details := SpellDamageRolls._roll_spell_damage(caster, damage_per_dart, dart_count, reaction_decisions)
	return SpellDamageRolls._finish_spell_damage(caster, target_entity, details, 0, 1.0, str(spell_data.get("damage_type", "force")), reaction_decisions, {
		"success": true, "hit": true, "dart_count": dart_count,
		"message": "%s hits automatically with %d %ss for {damage} %s damage." % [spell_data.get("name", "Magic Missile"), dart_count, str(spell_data.get("_projectile_noun", "dart")), spell_data.get("damage_type", "force")]
	})


static func magic_missile_dart_count(spell_data: Dictionary, slot_level: int = 0) -> int:
	spell_data = view(spell_data) if spell_data.get("projectiles") is Dictionary else spell_data
	var dart_count := int(spell_data.get("dart_count", 3))
	var base_level := int(spell_data.get("level", 1))
	var upcast: Dictionary = spell_data.get("upcast", {})
	dart_count += maxi(0, slot_level - base_level) * int(upcast.get("extra_darts_per_level", 0))
	return clampi(int(spell_data.get("_projectile_count_for_target", spell_data.get("_magic_missile_darts_for_target", dart_count))), 1, dart_count)


static func _resolve_scorching_ray(caster: Character, target_entity, spell_data: Dictionary, reaction_decisions: Dictionary, slot_level: int = 0, distance_feet: int = -1) -> Dictionary:
	var ray_count := SpellProjectileResolver.scorching_ray_count(caster, spell_data, slot_level)
	var damage_dice := str(spell_data.get("damage_per_ray", "2d6")).replace(" ", "")
	var target_ac := 10
	if target_entity is Character:
		target_ac = target_entity.get_ac()
	elif target_entity is Dictionary:
		target_ac = SpellEffects.effective_ac(target_entity, int(target_entity.get("armor_class", 10)) + (2 if CombatAction.has_condition(target_entity, "shield_of_faith") else 0))
	target_ac += CoverRules.bonus(reaction_decisions, spell_data)
	var hits := 0
	var bonus_packets: Array[Dictionary] = []
	var bonus_choices: Array = spell_data.get("_conjure_minor_elementals_bonus_packets", [])
	var details := {"formula": damage_dice, "dice_terms": [], "modifiers": [], "final_total": 0}
	var stroke_of_luck_used := false
	var shield_used := false
	reaction_decisions = reaction_decisions.duplicate()
	reaction_decisions["perception_handles_blindness"] = true
	for ray_index in ray_count:
		var perception := CombatPerception.attack_visibility(caster, target_entity, maxi(0, distance_feet), reaction_decisions)
		var spell_attack_advantage := FighterRules.attack_advantage(caster, target_entity) or SpellEffects.has_spell(target_entity, "faerie_fire") or caster.has_condition("innate_sorcery") or CombatAction.attack_target_grants_advantage(target_entity, maxi(0, distance_feet) / 5, true) or bool(perception.advantage)
		var spell_attack_disadvantage := CombatAction.attack_target_imposes_disadvantage(target_entity, maxi(0, distance_feet) / 5, bool(perception.target_sees_attacker)) or (caster.get_creature_type() in CombatAction.protected_creature_types_for_target(target_entity)) or (SpellEffects.has_spell(target_entity, "blur") and not CombatAction.can_perceive_blur(caster, maxi(0, distance_feet))) or bool(perception.disadvantage) or CombatAction.attacker_has_condition_disadvantage(caster, SpellPermissionRules.selected_ability(spell_data, caster.get_spellcasting_ability()), reaction_decisions)
		var helped_attack := CombatAction.consume_attack_help(target_entity, caster)
		spell_attack_advantage = spell_attack_advantage or helped_attack
		var attack_result := caster.make_attack_roll(SpellPermissionRules.selected_ability(spell_data, caster.get_spellcasting_ability()), spell_attack_advantage, spell_attack_disadvantage, {}, reaction_decisions)
		CombatAction.reveal_hidden_attacker(caster)
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
			target_ac = target_entity.get_ac() + CoverRules.bonus(reaction_decisions, spell_data)
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
		return {"success": true, "hit": false, "damage": 0, "ray_count": ray_count, "shield_used": shield_used, "message": "%s misses all %d %ss.%s" % [spell_data.get("name", "Scorching Ray"), ray_count, str(spell_data.get("_projectile_noun", "ray")), " Shield raises the target's AC for subsequent attacks." if shield_used else ""]}
	var beam_bonus := CombatAction.spell_damage_bonus(caster, spell_data) if not spell_data.get("beam_count_by_level", {}).is_empty() else 0
	if beam_bonus > 0 and hits > 1:
		details["final_total"] = int(details["final_total"]) + beam_bonus * (hits - 1)
		details["modifiers"].append({"source": "per-hit cantrip bonus", "value": beam_bonus * (hits - 1)})
	return SpellDamageRolls._finish_spell_damage(caster, target_entity, details, beam_bonus, 1.0, str(spell_data.get("damage_type", "fire")), reaction_decisions, {
		"success": true, "hit": true, "ray_count": ray_count, "rays_hit": hits,
		"stroke_of_luck_used": stroke_of_luck_used, "shield_used": shield_used,
		"message": "%s hits with %d of %d %ss for {damage} %s damage.%s%s" % [spell_data.get("name", "Scorching Ray"), hits, ray_count, str(spell_data.get("_projectile_noun", "ray")), spell_data.get("damage_type", "fire"), " Stroke of Luck turns the first missed ray's attack into a 20." if stroke_of_luck_used else "", " Shield raises the target's AC for subsequent attacks." if shield_used else ""]
	}, 1, bonus_packets)


static func scorching_ray_count(caster: Character, spell_data: Dictionary, slot_level: int = 0) -> int:
	spell_data = view(spell_data) if spell_data.get("projectiles") is Dictionary else spell_data
	var beam_levels: Dictionary = spell_data.get("beam_count_by_level", {})
	if not beam_levels.is_empty():
		var beams := 1
		for threshold in beam_levels:
			if str(threshold).is_valid_int() and caster != null and caster.level >= int(threshold):
				beams = maxi(beams, int(beam_levels[threshold]))
		return clampi(int(spell_data.get("_projectile_count_for_target", spell_data.get("_scorching_ray_count_for_target", beams))), 1, beams)
	var ray_count := int(spell_data.get("ray_count", 3))
	var base_level := int(spell_data.get("level", 2))
	var upcast: Dictionary = spell_data.get("upcast", {})
	ray_count += maxi(0, slot_level - base_level) * int(upcast.get("extra_rays_per_level", 0))
	return clampi(int(spell_data.get("_projectile_count_for_target", spell_data.get("_scorching_ray_count_for_target", ray_count))), 1, ray_count)


