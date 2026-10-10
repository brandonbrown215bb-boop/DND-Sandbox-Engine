## Focused resolver checks for the Mass Cure Wounds gameplay slice.
class_name MassCureWoundsChecks
extends RefCounted

static func _character(name: String, klass: String, scores: Dictionary) -> Character:
	var ability_scores := AbilityScores.new()
	ability_scores.from_dict(scores)
	var character := Character.new()
	character.initialize(name, "human", klass, ability_scores)
	return character

static func run(check: Callable) -> void:
	var spell := DataLoader.get_spell("mass_cure_wounds")
	var area: Dictionary = spell.get("effects", []).filter(func(effect): return str(effect.get("type", "")) == "area_selection")[0]
	var healing: Dictionary = spell.get("effects", []).filter(func(effect): return str(effect.get("type", "")) == "heal")[0]
	check.call(SpellSupport.is_available(spell) and spell.get("rules_source", "") == "SRD5.2.1" and spell.get("target", "") == "area", "Mass Cure Wounds loads its castable SRD 5.2.1 area-healing record")
	check.call(str(area.get("shape", "")) == "sphere" and int(area.get("radius", 0)) == 6 and int(area.get("maximum_targets", 0)) == 6, "Mass Cure Wounds targets up to six creatures inside a 30-foot-radius Sphere")
	check.call(str(healing.get("value", "")) == "5d8" and bool(healing.get("ability_bonus_from_caster", false)) and CombatAction.spell_effects_for_slot_level(spell, 7)[1].get("value", "") == "5d8 + 2d8", "Mass Cure Wounds adds the spellcasting modifier and one healing d8 per slot level above five")
	var caster := _character("Healing Druid", "druid", {"STR": 10, "DEX": 12, "CON": 12, "INT": 10, "WIS": 18, "CHA": 10})
	var target := _character("Downed Ally", "fighter", {"STR": 14, "DEX": 10, "CON": 12, "INT": 10, "WIS": 10, "CHA": 10})
	target.current_hp = 0
	target.is_alive = false
	var result := EventResolver.apply_effects(target, [healing], caster)
	check.call(result.size() == 1 and int(result[0].get("amount", 0)) > 0 and target.current_hp > 0 and target.is_alive, "Mass Cure Wounds restores a downed creature using the caster's Wisdom modifier")
