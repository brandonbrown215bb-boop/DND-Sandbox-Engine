## Production regressions for the Bard base-class pass.
class_name BardChecks
extends RefCounted

static func run(check: Callable) -> void:
	var bard := character(7)
	var ally := character(1, "fighter")
	var uses := int(bard.feature_uses["bard_bardic_inspiration"])
	ally.add_condition("blinded", 2)
	ally.add_condition("deafened", 2)
	check.call(not CombatAction.resolve_bardic_inspiration(bard, ally).get("success", true) and int(bard.feature_uses["bard_bardic_inspiration"]) == uses, "A creature unable to see or hear cannot receive Inspiration or spend a use")
	ally.remove_condition("blinded")
	check.call(CombatAction.resolve_bardic_inspiration(bard, ally).get("success", false), "Seeing the Bard is enough even when the recipient is Deafened")
	check.call(int(ally.feature_uses.get("bardic_inspiration_seconds_remaining", 0)) == 3600, "A granted Inspiration die has a one-hour clock")
	var loaded := Character.new()
	loaded.from_dict(JSON.parse_string(JSON.stringify(ally.to_dict())))
	check.call(loaded.feature_uses.get("bardic_inspiration_die", "") == "1d8" and int(loaded.feature_uses.get("bardic_inspiration_seconds_remaining", 0)) == 3600, "The captured Inspiration die and clock survive JSON reload")
	loaded.feature_uses["bardic_inspiration_seconds_remaining"] = 6
	loaded.tick_conditions()
	check.call(not loaded.feature_uses.has("bardic_inspiration_die"), "The recipient's combat turn advances and expires its Inspiration")
	ally.feature_uses["bardic_inspiration_seconds_remaining"] = 1
	var party_before := PartyManager.characters.duplicate()
	var elapsed_before := GameManager.campaign_elapsed_seconds
	PartyManager.characters[ally.character_id] = ally
	GameManager.advance_campaign_time(1)
	check.call(not ally.feature_uses.has("bardic_inspiration_die"), "Campaign time expires held Inspiration at its saved deadline")
	PartyManager.characters = party_before
	GameManager.campaign_elapsed_seconds = elapsed_before
	var prone := character(1, "fighter")
	prone.add_condition("prone", 2)
	prone.current_hp = 1
	CombatAction.resolve_spell(bard, prone, DataLoader.get_spell("power_word_heal"))
	check.call(prone.current_hp == prone.max_hp and prone.has_condition("prone") and prone.reaction_available, "Power Word Heal preserves Prone and the Reaction until the recipient chooses to stand")
	prone.current_hp = 1
	CombatAction.resolve_spell(bard, prone, DataLoader.get_spell("power_word_heal"), false, {"power_word_heal_stand": true})
	check.call(not prone.has_condition("prone") and not prone.reaction_available, "Choosing to stand after Power Word Heal spends exactly the recipient's Reaction")
	var target := character(1, "fighter")
	bard.add_condition("stunned", 2)
	FighterChecks._seed_die(20, 1)
	var charm := CombatAction.resolve_spell(bard, target, DataLoader.get_spell("charm_person"), false, {"countercharm": true}, [bard])
	check.call(not charm.get("countercharm_used", true) and bard.reaction_available, "An Incapacitated Bard cannot use Countercharm")
	bard.remove_condition("stunned")
	bard.reaction_available = true
	var sorcerer := character(7, "sorcerer")
	ClassProgression.choose_sorcerer_metamagic(sorcerer, ["heightened_spell", "subtle_spell"])
	seed(24)
	Dice.roll(20)
	Dice.roll(20)
	var expected := Dice.roll(20) + target.ability_scores.get_ability_modifier("WIS")
	seed(24)
	charm = CombatAction.resolve_spell(sorcerer, target, DataLoader.get_spell("charm_person"), false, {"countercharm": true, "metamagic:heightened": true}, [bard])
	check.call(charm.get("countercharm_used", false) and int(charm.get("save_total", -1)) == expected, "Countercharm Advantage cancels ongoing Heightened Disadvantage on its reroll")

	var legendary := character(18)
	legendary.spell_slots["1"] = 0
	check.call("healing_word" in legendary.get_spell_option_ids(false), "Spent slots do not erase eligible prepared-spell training choices")
	check.call("guiding_bolt" in legendary.get_spell_option_ids(false) and "fire_bolt" not in legendary.get_spell_option_ids(true), "Magical Secrets expands prepared spells but keeps cantrip choices on the Bard list")
	check.call(int(legendary.spell_slots.get("5", 0)) == 3, "Level-18 Bard receives the third fifth-level spell slot")
	legendary.level_up()
	legendary.level_up()
	check.call(int(legendary.spell_slots.get("5", 0)) == 3 and int(legendary.spell_slots.get("6", 0)) == 2 and int(legendary.spell_slots.get("7", 0)) == 2, "Level-20 Bard preserves the corrected high-level slot table")
	check.call(bard.get_skill_proficiency_bonus("") == 0, "Jack of All Trades does not add proficiency to a check without a skill")
	var novice := character(1)
	novice.feature_uses["bard_bardic_inspiration"] = 0
	var slots := novice.spell_slots.duplicate()
	check.call(not ClassProgression.restore_resource_from_spell_slot(novice, "bard_bardic_inspiration", 1).get("success", true) and novice.spell_slots == slots, "A Bard without Font cannot trade spell slots for Inspiration")
	var dto := ally.to_dict()
	dto["feature_uses"]["bardic_inspiration_die"] = "1d8"
	dto["feature_uses"]["bardic_inspiration_seconds_remaining"] = "forever"
	check.call(not ClassProgression.saved_choices_error(dto).is_empty(), "Save preflight rejects a malformed held-die clock")
	dto["feature_uses"].erase("bardic_inspiration_seconds_remaining")
	loaded.from_dict(JSON.parse_string(JSON.stringify(dto)))
	check.call(int(loaded.feature_uses.get("bardic_inspiration_seconds_remaining", 0)) == 3600, "An older held-die save adopts one bounded hour on load")
	loaded.short_rest()
	check.call(not BardicInspirationRules.has_die(loaded), "A completed Short Rest expires the recipient's one-hour Inspiration")
	ally = character(1, "wizard")
	ally.feature_uses["bardic_inspiration_die"] = "1d8"
	var spell_target := {"name": "Spell Attack Target", "armor_class": 100, "current_hp": 1000, "is_alive": true, "conditions": {}}
	FighterChecks._seed_die(20, 2)
	var spell_attack := CombatAction.resolve_spell(ally, spell_target, DataLoader.get_spell("fire_bolt"), false, {"bardic_inspiration_attack": true})
	check.call(not spell_attack.get("hit", true) and not BardicInspirationRules.has_die(ally), "A failed spell attack can spend a held Inspiration die")
	ally.feature_uses["bardic_inspiration_die"] = "1d8"
	FighterChecks._seed_die(20, 10)
	var normal_total := 10 + ally.ability_scores.get_ability_modifier(ally.get_spellcasting_ability()) + ally.proficiency_bonus
	spell_target["armor_class"] = normal_total + 1
	FighterChecks._seed_die(20, 10)
	spell_attack = CombatAction.resolve_spell(ally, spell_target, DataLoader.get_spell("fire_bolt"), false, {"bardic_inspiration_attack": true})
	check.call(spell_attack.get("hit", false) and not BardicInspirationRules.has_die(ally), "Inspiration can turn a spell attack miss into a hit")
	ally.feature_uses["bardic_inspiration_die"] = "1d8"
	FighterChecks._seed_die(20, 1)
	spell_attack = CombatAction.resolve_spell(ally, spell_target, DataLoader.get_spell("fire_bolt"), false, {"bardic_inspiration_attack": true})
	check.call(not spell_attack.get("hit", true) and BardicInspirationRules.has_die(ally), "A natural-one spell attack preserves an unusable Inspiration die")

	var victim := character(1, "fighter")
	CombatAction.resolve_spell(legendary, victim, DataLoader.get_spell("power_word_kill"))
	check.call(victim.current_hp == 0 and victim.death_save_failures == 3 and not victim.make_death_save().get("rolled", true), "Power Word Kill causes outright death instead of starting death saves")
	var failed_heal := CombatAction.resolve_spell(legendary, victim, DataLoader.get_spell("power_word_heal"))
	check.call(not failed_heal.get("success", true) and victim.current_hp == 0, "Power Word Heal refuses a dead creature instead of resurrecting it")
	var choices := {"skills": ["Performance", "Persuasion", "Stealth"], "tools": ["lute", "flute", "viol"], "instrument": "drum", "equipment": "equipment"}
	var created := Character.new()
	created.initialize("Chosen Bard", "elf", "bard", AbilityScores.new(), "equipment", choices)
	check.call(created.skill_proficiencies.has("Performance") and created.skill_proficiencies.has("Stealth") and created.skill_proficiencies.has("Perception") and created.get_skill_proficiency_bonus("Persuasion") == created.proficiency_bonus, "Bard creation grants chosen skills alongside species proficiencies")
	check.call(created.tool_proficiencies == ["lute", "flute", "viol"] and created.inventory.count_item("drum") == 1 and created.inventory.count_item("entertainers_pack") == 1 and created.inventory.count_item("dagger") == 1 and created.inventory.get_weapon() == "dagger" and created.inventory.gold == 19, "Bard equipment grants a distinct chosen instrument, pack, two daggers and 19 gold")
	var cash := Character.new()
	cash.initialize("Cash Bard", "human", "bard", AbilityScores.new(), "gold", choices)
	check.call(cash.inventory.gold == 90 and cash.inventory.backpack.is_empty() and cash.inventory.equipped.is_empty() and cash.tool_proficiencies.size() == 3, "Choosing Bard gold retains proficiencies without granting class gear")
	var invalid := choices.duplicate(true)
	invalid["tools"] = ["lute", "lute", "viol"]
	var refused := Character.new()
	refused.initialize("Refused", "human", "bard", AbilityScores.new(), "equipment", invalid)
	check.call(refused.character_name.is_empty() and refused.inventory.backpack.is_empty(), "Duplicate creation choices refuse before character or inventory mutation")
	invalid = choices.duplicate(true)
	invalid["skills"] = ["Perception", "Persuasion", "Stealth"]
	check.call(not ClassProgression.creation_choices_error("bard", "elf", invalid).is_empty(), "A Bard must choose new skills rather than duplicate species proficiency")
	var saved := created.to_dict()
	var restored := Character.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check.call(ClassProgression.saved_choices_error(saved).is_empty() and restored.creation_choices == choices and restored.tool_proficiencies == created.tool_proficiencies and restored.inventory.gold == 19, "Bard creation choices and tool proficiencies round-trip without replaying grants")
	saved["creation_choices"]["tools"] = ["lute", "lute", "viol"]
	check.call(not ClassProgression.saved_choices_error(saved).is_empty(), "Saved duplicate instrument choices fail preflight")
	saved = created.to_dict()
	saved.erase("creation_choices")
	saved.erase("tool_proficiencies")
	var old_inventory: Dictionary = saved["inventory"].duplicate(true)
	restored.from_dict(saved)
	check.call(ClassProgression.saved_choices_error(saved).is_empty() and restored.tool_proficiencies.is_empty() and restored.creation_choices.is_empty() and restored.inventory.to_dict() == old_inventory, "Older Bard saves retain their inventory and do not acquire new instruments or cash on reload")

static func character(target_level: int, class_id: String = "bard") -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 10, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 18})
	var c := Character.new()
	c.initialize("Bard Fixture", "human", class_id, scores)
	while c.level < target_level:
		c.level_up()
	return c
