## Direct healing, stabilization and Power Word Heal results.
## Batch 081: Power Word Kill moved to data (settle_death with a declared fallback).
class_name SpellHealingResolver
extends RefCounted

static func _resolve_words_power_spell(caster: Character, target_entity, spell_data: Dictionary, reaction_decisions: Dictionary = {}) -> Dictionary:
	var spell_id := str(spell_data.get("id", ""))
	if spell_id == "power_word_heal":
		var healed := 0
		var target_name := "Target"
		if target_entity is Character:
			if not CombatAction.can_receive_power_word_heal(target_entity):
				return {"success": false, "message": "Power Word Heal cannot revive a dead creature."}
			target_name = target_entity.character_name
			healed = target_entity.heal(target_entity.max_hp)
			for condition in ["charmed", "frightened", "paralyzed", "poisoned", "stunned"]:
				target_entity.remove_condition(condition)
			if bool(reaction_decisions.get("power_word_heal_stand", false)):
				CombatAction.stand_after_power_word_heal(target_entity)
		elif target_entity is Dictionary:
			target_name = str(target_entity.get("name", "Target"))
			var old_hp := int(target_entity.get("current_hp", 0))
			target_entity["current_hp"] = int(target_entity.get("max_hp", old_hp))
			healed = maxi(0, int(target_entity["current_hp"]) - old_hp)
			var conditions: Dictionary = target_entity.get("conditions", {})
			for condition in ["charmed", "frightened", "paralyzed", "poisoned", "stunned"]:
				conditions.erase(condition)
			target_entity["conditions"] = conditions
		return {"success": true, "hit": true, "damage": 0, "healing": healed, "message": "%s regains all Hit Points from Power Word Heal." % target_name}
	return {"success": false, "message": "Power Word has no valid creature target."}


static func spare_the_dying(cast: SpellResolutionContext) -> Dictionary:
	if not cast.target is Character or cast.target.current_hp != 0 or cast.target.is_dead():
		return {"success": false, "message": "Spare the Dying requires a living, not-dead creature at 0 Hit Points."}
	cast.target.stabilize()
	return {"success": true, "hit": true, "stable": true, "damage": 0, "message": "%s is Stable and no longer makes Death Saving Throws." % cast.target.character_name}


static func regenerate(cast: SpellResolutionContext) -> Dictionary:
	var healing_formula := str(cast.spell.get("effects", [{}])[0].get("value", "4d8+15"))
	var healing_rolled := Dice.parse_dice_string(healing_formula, {}, cast.caster)
	healing_rolled = SpellEffects.maximize_healing(cast.target, healing_rolled, Dice.maximum_dice_string(healing_formula))
	var healing_applied := 0
	if cast.target is Character:
		healing_applied = cast.target.heal(healing_rolled)
		cast.target.add_condition("regenerate", int(cast.spell.get("healing_duration_turns", 600)))
	elif cast.target is Dictionary:
		if not CombatAction.is_healing_suppressed(cast.target):
			var monster_hp := int(cast.target.get("current_hp", 0))
			healing_applied = mini(healing_rolled, maxi(0, int(cast.target.get("max_hp", monster_hp)) - monster_hp))
			cast.target["current_hp"] = monster_hp + healing_applied
			if healing_applied > 0:
				cast.target["is_alive"] = true
		var conditions: Dictionary = cast.target.get("conditions", {})
		conditions["regenerate"] = int(cast.spell.get("healing_duration_turns", 600))
		cast.target["conditions"] = conditions
	var target_name: String = cast.target.character_name if cast.target is Character else str(cast.target.get("name", "Target"))
	return {"success": true, "hit": true, "healing": healing_applied, "healing_rolled": healing_rolled, "regeneration_turns": int(cast.spell.get("healing_duration_turns", 600)), "message": "%s regains %d Hit Points and regenerates 1 Hit Point at the start of each of its turns for 1 hour." % [target_name, healing_applied]}


