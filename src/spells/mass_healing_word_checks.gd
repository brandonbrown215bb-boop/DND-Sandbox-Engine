## Focused checks for the current six-target Mass Healing Word slice.
class_name MassHealingWordChecks
extends RefCounted

static func _character(name: String, klass: String, spellcasting_score: int) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 10, "DEX": 12, "CON": 12, "INT": 10, "WIS": 10, "CHA": spellcasting_score})
	var character := Character.new()
	character.initialize(name, "human", klass, scores)
	return character

static func run(check: Callable) -> void:
	var spell := DataLoader.get_spell("mass_healing_word")
	var effect: Dictionary = spell.get("effects", []).filter(func(item): return str(item.get("type", "")) == "heal")[0]
	check.call(SharedSpell.uses(spell) and SpellSupport.is_available(spell) and spell.get("rules_source", "") == "dnd-2024-srd-5.2.1" and spell.get("school", "") == "abjuration" and spell.get("casting_time", "") == "bonus_action" and spell.get("components", []) == ["V"], "Mass Healing Word loads the shared SRD record and bonus-action cost")
	check.call(int(spell.get("base_targets", 0)) == 6 and int(spell.get("range", 0)) == 12 and effect.get("value", "") == "2d4" and bool(effect.get("ability_bonus_from_caster", false)) and CombatAction.spell_effects_for_slot_level(spell, 5)[0].get("value", "") == "2d4 + 2d4", "Mass Healing Word can heal six visible creatures within 60 feet and adds 1d4 per upcast slot")
	var bard := _character("Healing Bard", "bard", 18)
	var downed := _character("Downed Ally", "fighter", 10)
	downed.current_hp = 0
	downed.is_alive = false
	var applied := EventResolver.apply_effects(downed, [effect], bard)
	check.call(applied.size() == 1 and int(applied[0].get("amount", 0)) > 0 and downed.current_hp > 0 and downed.is_alive, "Mass Healing Word can restore a downed ally and applies the Bard's spellcasting modifier")
