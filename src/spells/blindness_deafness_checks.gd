## Focused checks for the repeat-save Blindness/Deafness gameplay slice.
class_name BlindnessDeafnessChecks
extends RefCounted

static func _caster(id: String) -> Character:
	var character := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"INT": 16, "CON": 14, "WIS": 12})
	character.initialize(id, "human", "wizard", scores)
	character.character_id = id
	return character

static func _monster(id: String, save_bonus: int, immunities: Array = []) -> Dictionary:
	return {
		"id": id,
		"name": id,
		"is_alive": true,
		"current_hp": 40,
		"max_hp": 40,
		"armor_class": 10,
		"creature_type": "humanoid",
		"conditions": {},
		"condition_sources": {},
		"spell_effects": {},
		"condition_immunities": immunities,
		"saving_throw_bonuses": {"CON": save_bonus},
	}

static func run(check: Callable) -> void:
	var spell: Dictionary = DataLoader.get_spell("blindness/deafness")
	check.call(SpellSupport.is_available(spell) and SpellEffects.manages(spell) and str(spell.get("school", "")) == "transmutation" and int(spell.get("range", 0)) == 24 and spell.get("classes", []) == ["bard", "cleric", "sorcerer", "wizard"], "Blindness/Deafness loads the curated SRD level-2 record and is available to its four classes")
	check.call(spell.get("condition_options", []) == ["blinded", "deafened"] and str(spell.get("repeat_save_ability", "")) == "CON" and int(spell.get("duration_seconds", 0)) == 60 and not bool(spell.get("concentration", true)), "Blindness/Deafness records both condition choices, minute duration, and non-concentration repeat saves")

	var caster := _caster("blindness-caster")
	var target := _monster("blindness-target", -1000)
	var blinded_spell := spell.duplicate(true)
	blinded_spell["condition_on_failed_save"] = "blinded"
	var first_cast := CombatAction.resolve_spell(caster, target, blinded_spell, false, {}, [], 2, 30)
	var source := str(first_cast.get("effect_cast", {}).get("source_id", ""))
	var first_record: Dictionary = SpellEffects.records(target).get(source, {})
	check.call(not bool(first_cast.get("saved", true)) and CombatAction.has_condition(target, "blinded") and str(first_record.get("spell_id", "")) == "blindness/deafness" and int(first_record.get("save_dc", 0)) == caster.get_spell_save_dc(), "A failed Constitution save applies source-owned Blinded with the casting save DC")
	check.call(int(first_record.get("remaining_seconds", 0)) == 60 and not bool(first_record.get("concentration", true)), "Blinded remains source-owned for one minute without concentration")

	target["saving_throw_bonuses"]["CON"] = 1000
	var repeated := CombatAction.resolve_condition_spell_repeat_save(target, source)
	check.call(bool(repeated.get("success", false)) and bool(repeated.get("saved", false)) and not CombatAction.has_condition(target, "blinded") and not SpellEffects.records(target).has(source), "A successful end-of-turn Constitution save ends only this Blindness/Deafness effect")

	var deaf_target := _monster("deafness-target", -1000)
	var deafened_spell := spell.duplicate(true)
	deafened_spell["condition_on_failed_save"] = "deafened"
	var deaf_cast := CombatAction.resolve_spell(caster, deaf_target, deafened_spell, false, {}, [], 2, 30)
	check.call(not bool(deaf_cast.get("saved", true)) and CombatAction.has_condition(deaf_target, "deafened") and not CombatAction.has_condition(deaf_target, "blinded"), "The alternate spell choice applies Deafened rather than Blinded")

	var immune_target := _monster("immune-target", -1000, ["blinded"])
	var immune_cast := CombatAction.resolve_spell(caster, immune_target, blinded_spell, false, {}, [], 2, 30)
	check.call(not bool(immune_cast.get("saved", true)) and not CombatAction.has_condition(immune_target, "blinded") and SpellEffects.records(immune_target).is_empty(), "A monster immune to the selected condition receives no effect record")
	print("BLINDNESS_DEAFNESS_REPEAT_SAVE_CHECKS_COMPLETE")
