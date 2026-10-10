## Direct spell wards, enhancements and caster benefits.
class_name SpellWardResolver
extends RefCounted

static func hunters_mark(cast: SpellResolutionContext) -> Dictionary:
	return CombatAction.resolve_hunters_mark(cast.caster, cast.target)


static func false_life(cast: SpellResolutionContext) -> Dictionary:
	if str(cast.spell.get("id", "")) == "false_life" and WarlockRules.has_invocation(cast.caster, "fiendish_vigor"):
		cast.caster.temp_hp = maxi(cast.caster.temp_hp, 12)
		return {"success": true, "hit": true, "damage": 0, "temporary_hp": cast.caster.temp_hp, "message": "%s gains %d temporary Hit Points from Fiendish Vigor." % [cast.caster.character_name, cast.caster.temp_hp]}
	var temporary_hit_points := Dice.parse_dice_string(str(cast.spell.get("damage", "1d4+4")))
	cast.caster.temp_hp = maxi(cast.caster.temp_hp, temporary_hit_points)
	return {"success": true, "hit": true, "damage": 0, "temporary_hp": cast.caster.temp_hp, "message": "%s gains %d temporary Hit Points from False Life." % [cast.caster.character_name, cast.caster.temp_hp]}


static func divine_favor(cast: SpellResolutionContext) -> Dictionary:
	SpellEffects.grant_divine_favor(cast.caster, cast.effect_cast)
	return {"success": true, "hit": true, "damage": 0, "effect_cast": cast.effect_cast, "message": "%s's weapon attacks deal an extra 1d4 Radiant damage on a hit for 1 minute." % cast.caster.character_name}


static func death_ward(cast: SpellResolutionContext) -> Dictionary:
	SpellEffects.grant_death_ward(cast.target, cast.effect_cast)
	var target_name: String = cast.target.character_name if cast.target is Character else str(cast.target.get("name", "The creature"))
	return {"success": true, "hit": true, "damage": 0, "effect_cast": cast.effect_cast, "message": "%s is protected by Death Ward for 8 hours." % target_name}


static func sanctuary(cast: SpellResolutionContext) -> Dictionary:
	SpellEffects.grant_sanctuary(cast.target, cast.effect_cast)
	var sanctuary_target_name: String = cast.target.character_name if cast.target is Character else str(cast.target.get("name", "The creature"))
	return {"success": true, "hit": true, "damage": 0, "effect_cast": cast.effect_cast, "message": "%s is warded by Sanctuary for 1 minute." % sanctuary_target_name}


static func heroism(cast: SpellResolutionContext) -> Dictionary:
	if cast.target is not Character:
		return {"success": false, "message": "Heroism requires a willing living party character."}
	var heroism_target_name: String = cast.target.character_name
	var temporary_hp_per_turn := maxi(0, AbilityScores.get_modifier(cast.caster.ability_scores.get_score(cast.caster.get_spellcasting_ability())))
	SpellEffects.grant_heroism(cast.target, cast.effect_cast, temporary_hp_per_turn)
	return {"success": true, "hit": true, "damage": 0, "effect_cast": cast.effect_cast, "temporary_hp_per_turn": temporary_hp_per_turn, "message": "%s is immune to Frightened and gains %d Temporary Hit Points at the start of each turn while %s concentrates." % [heroism_target_name, temporary_hp_per_turn, cast.caster.character_name]}


static func magic_weapon(cast: SpellResolutionContext) -> Dictionary:
	if cast.target is not Character:
		return {"success": false, "message": "Magic Weapon needs a willing party character holding the target weapon."}
	var magic_weapon_id := str(cast.spell.get("_magic_weapon_id", ""))
	if magic_weapon_id.is_empty():
		return {"success": false, "message": "Magic Weapon needs a selected nonmagical equipped weapon."}
	var magic_weapon_bonus := mini(3, 1 + floori(float(cast.slot_level - 2) / 2.0))
	SpellEffects.grant_magic_weapon(cast.target, cast.effect_cast, magic_weapon_id, magic_weapon_bonus)
	return {"success": true, "hit": true, "damage": 0, "effect_cast": cast.effect_cast, "weapon_id": magic_weapon_id, "weapon_bonus": magic_weapon_bonus, "message": "%s's %s becomes magical with a +%d bonus to attack and damage rolls while %s concentrates." % [cast.target.character_name, DataLoader.get_item(magic_weapon_id).get("name", magic_weapon_id), magic_weapon_bonus, cast.caster.character_name]}


static func invisibility(cast: SpellResolutionContext) -> Dictionary:
	var target_is_alive := false
	if cast.target is Character:
		target_is_alive = cast.target.is_alive
	elif cast.target is Dictionary:
		target_is_alive = bool(cast.target.get("is_alive", false))
	if not target_is_alive:
		return {"success": false, "message": "Invisibility requires a living creature target."}
	SpellEffects.grant(cast.target, cast.effect_cast, "invisible")
	if not SpellEffects.has_spell(cast.target, "invisibility"):
		return {"success": false, "message": "The creature cannot be affected by Invisibility."}
	var invisible_target_name: String = cast.target.character_name if cast.target is Character else str(cast.target.get("name", "The creature"))
	return {"success": true, "hit": true, "damage": 0, "effect_cast": cast.effect_cast, "message": "%s becomes Invisible while %s concentrates. The effect ends for that creature after it makes an attack roll, deals damage, or casts a spell." % [invisible_target_name, cast.caster.character_name]}


