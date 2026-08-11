## Test Runner (scene-based)
## Runs inside the normal project boot, so autoloads (DataLoader, Dice,
## PlayerManager, GameManager, SaveManager) and class_name globals (Character,
## CombatAction, HexGrid, ...) are all live. Exercises the real combat, grid,
## AI, spell, inventory, event, fog-of-war and persistence code paths.
extends Node

var _passed := 0
var _failed := 0
var _failures: Array[String] = []

func _ready() -> void:
	print("==================================================")
	print(" Rook's In-Engine Test Harness (scene runner)")
	print("==================================================")
	_test_data_loader()
	_test_character_creation()
	_test_dice_parser()
	_test_combat_action()
	_test_player_commands()
	_test_initiative()
	_test_spellcasting()
	_test_ai_controller()
	_test_inventory()
	_test_conditions()
	_test_character_serialization()
	_test_player_manager()
	_test_party_manager()
	_test_campaign_contracts()
	_test_event_system()
	_test_fog_of_war()
	_test_hexutils()
	_test_dungeon_lifecycle()
	_test_save_load()
	_test_widgets()
	_report()
	get_tree().quit(1 if _failed > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failures.append(msg)
		print("[FAIL] %s" % msg)

func _report() -> void:
	print("--------------------------------------------------")
	print(" RESULTS: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		print(" FAILURES:")
		for f in _failures:
			print("   - %s" % f)
		print("TESTS FAILED")
	else:
		print("ALL TESTS PASSED")

# ---- helpers ----
func _fresh_char(name: String, race: String, klass: String, scores_dict: Dictionary) -> Character:
	var s: AbilityScores = AbilityScores.new()
	s.from_dict(scores_dict)
	var c: Character = Character.new()
	c.initialize(name, race, klass, s)
	return c

func _build_grid(radius: int) -> HexGrid:
	var grid: HexGrid = HexGrid.new()
	var cells: Array[Vector2i] = HexUtils.get_hexes_in_range(Vector2i.ZERO, radius)
	for cell in cells:
		var t: HexTile = HexTile.new()
		t.coord = cell
		t.terrain = HexTile.TerrainType.PLAINS
		t.is_revealed = true
		t.is_visible = true
		grid.add_tile(t)
	return grid

func _monster_inst(id: String) -> Dictionary:
	var m: Dictionary = DataLoader.get_monster(id)
	return {
		"name": m.get("name", id), "monster_id": id,
		"max_hp": int(m.get("hit_points", 7)), "current_hp": int(m.get("hit_points", 7)),
		"armor_class": int(m.get("armor_class", 15)), "speed": int(m.get("speed", 6)),
		"ability_scores": m.get("ability_scores", {}), "attacks": m.get("attacks", []),
		"spells": m.get("spells", []).duplicate(true), "spell_slots": m.get("spell_slots", {}).duplicate(true),
		"damage_immunities": m.get("damage_immunities", []).duplicate(true), "condition_immunities": m.get("condition_immunities", []).duplicate(true),
		"saving_throw_bonuses": m.get("saving_throw_bonuses", {}).duplicate(true), "special_abilities": m.get("special_abilities", []).duplicate(true),
		"loot_table": m.get("loot_table", []).duplicate(true), "is_boss": bool(m.get("is_boss", false)), "creature_type": str(m.get("creature_type", "")),
		"ai_behavior": m.get("ai_behavior", "aggressive"),
		"hex_position": Vector2i(3, 0), "is_alive": true, "conditions": {}
	}

# ---- groups ----
func _test_data_loader() -> void:
	print("\n[Group] DataLoader")
	_assert(not DataLoader.monsters.is_empty(), "monsters registry populated")
	_assert(not DataLoader.spells.is_empty(), "spells registry populated")
	_assert(DataLoader.classes.size() >= 1, "at least one class loaded")
	_assert(DataLoader.races.size() >= 1, "at least one race loaded")
	var goblin: Dictionary = DataLoader.get_monster("goblin")
	_assert(not goblin.is_empty(), "lookup 'goblin' returns data")
	_assert(goblin.has("hit_points"), "goblin has hit_points field")
	_assert(goblin.has("attacks"), "goblin has attacks field")
	_assert(DataLoader.get_monster("skeleton").get("creature_type", "") == "undead", "Crown monster registry carries curated creature type metadata")
	# real spell + event tables exist
	var fb: Dictionary = DataLoader.get_spell("fireball")
	_assert(not fb.is_empty() and fb.has("damage"), "fireball spell loaded with damage")
	_assert(DataLoader.get_event_table("dungeon_events").size() > 0, "dungeon_events table loaded")
	var camp: Dictionary = DataLoader.get_campaign("")
	# at least one campaign present
	_assert(DataLoader.campaigns.size() >= 1, "at least one campaign loaded")
	_assert(DataLoader.get_load_errors().is_empty(), "content load has no unapproved collisions or schema errors")
	_assert(DataLoader.get_registry_hash() == DataLoader.get_registry_hash(), "registry hash is stable within a load")
	_assert(DataLoader.get_content_layers() == ["core_imported", "core_curated", "mods"], "content layers follow the manifest order")
	_assert(DataLoader.get_content_pack_ids() == ["core", "crown"], "core and Crown content packs expose identity metadata")
	_assert(str(fb.get("casting_time", "")) in DataLoader.VALID_SPELL_CASTING_TIMES, "production spell passes casting-time enum validation")
	_assert(str(fb.get("target", "")) in DataLoader.VALID_SPELL_TARGETS, "production spell passes target enum validation")
	var bless: Dictionary = DataLoader.get_spell("bless")
	var shield: Dictionary = DataLoader.get_spell("shield")
	var hunters_mark: Dictionary = DataLoader.get_spell("hunters_mark")
	_assert(not bless.get("effects", []).is_empty(), "curated bless effects survive imported collision")
	_assert(not shield.get("effects", []).is_empty(), "curated shield effects survive imported collision")
	_assert(hunters_mark.get("casting_time", "") == "bonus_action" and hunters_mark.get("concentration", false), "Hunter's Mark is a curated concentration bonus-action spell")
	_assert(hunters_mark.get("effects", [])[0].get("type", "") == "hunters_mark", "Hunter's Mark has a production mark effect")
	for crown_monster_id in ["goblin", "goblin_chief", "skeleton", "zombie", "wolf", "bandit", "giant_spider", "ooze", "wight", "lich_king"]:
		var crown_monster: Dictionary = DataLoader.get_monster(crown_monster_id)
		_assert(not crown_monster.is_empty() and not crown_monster.get("attacks", []).is_empty() and not str(crown_monster.get("ai_behavior", "")).is_empty(), "Crown monster %s has validated combat actions and AI metadata" % crown_monster_id)
	for consumable_id in ["potion_healing", "potion_greater_healing", "antidote", "torch"]:
		var consumable: Dictionary = DataLoader.get_item(consumable_id)
		_assert(consumable.get("type", "") == "consumable" and not consumable.get("effects", []).is_empty(), "Production consumable %s has an executable effect" % consumable_id)
	var wizard: Dictionary = DataLoader.get_character_class("wizard")
	_assert(wizard.get("spells_known_by_level", {}).get("1", []).has("magic_missile"), "wizard has a production level-1 spell")
	_assert(not wizard.get("features_by_level", {}).get("1", []).any(func(feature): return str(feature.get("id", "")) == "wizard_spellcasting"), "unsupported descriptive class features are quarantined from player state")
	var mystic_exposed := false
	var mystic_record: Dictionary = DataLoader.get_character_class("mystic")
	for mystic_level in mystic_record.get("features_by_level", {}):
		for mystic_feature in mystic_record.get("features_by_level", {}).get(mystic_level, []):
			if str(mystic_feature.get("id", "")) in ["mystic_psionics", "mystic_mystical_recovery"]:
				mystic_exposed = true
	_assert(not mystic_exposed, "Mystic psionics remains quarantined until a psi-resource and discipline contract exists")
	var exposed_feature_contract_valid := true
	for class_id in DataLoader.classes:
		var class_record: Dictionary = DataLoader.classes[class_id]
		for level_key in class_record.get("features_by_level", {}):
			for feature in class_record["features_by_level"][level_key]:
				if feature.get("effects", []).is_empty() and str(feature.get("resolver", "")).is_empty():
					exposed_feature_contract_valid = false
		_assert(exposed_feature_contract_valid, "every player-facing class feature has an executable effect or resolver")
	var artificer: Character = _fresh_char("Artificer", "human", "artificer",
		{"STR": 10, "DEX": 14, "CON": 14, "INT": 16, "WIS": 10, "CHA": 8})
	var tinkers_magic: Dictionary = artificer.get_feature("artificer_tinker's_magic")
	_assert(tinkers_magic.get("type", "") == "active" and tinkers_magic.get("action_cost", "") == "action" and tinkers_magic.get("uses_per", "") == "combat", "Artificer Tinker's Magic is a curated combat action")
	_assert(artificer.inventory.has_item("tinkers_tools"), "Artificer starts with Tinker's Tools for the production feature prerequisite")
	var bearings_before := artificer.inventory.count_item("ball_bearings")
	var tinkers_result := ClassFeature.execute(artificer, tinkers_magic)
	_assert(tinkers_result.get("success", false) and artificer.inventory.count_item("ball_bearings") == bearings_before + 1, "Tinker's Magic creates Ball Bearings through the shared feature resolver")
	_assert(not artificer.use_feature("artificer_tinker's_magic"), "Tinker's Magic cannot be used twice before its combat reset")
	var caster: Character = _fresh_char("Caster", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	_assert("magic_missile" in caster.known_spells and caster.spell_slots.get("1", 0) > 0, "new caster reaches combat with known spell and slot")
	_assert(not caster.has_feature("wizard_spellcasting") and caster.has_feature("wizard_arcane_recovery"), "character feature inventory exposes only curated mechanics-backed features")
	var fighter: Character = _fresh_char("Fighter", "human", "fighter",
		{"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
	_assert(fighter.has_feature("fighter_second_wind"), "fighter receives curated Second Wind")
	_assert(not fighter.get_feature("fighter_second_wind").get("effects", []).is_empty(), "Second Wind has an executable healing effect")
	_assert(not fighter.use_feature("not_a_real_feature"), "unknown class feature cannot consume an action or resource")
	_assert(fighter.use_feature("fighter_second_wind"), "Second Wind can be consumed once")
	_assert(not fighter.use_feature("fighter_second_wind"), "Second Wind cannot be consumed twice before reset")
	fighter.reset_rest_features()
	_assert(fighter.use_feature("fighter_second_wind"), "rest cadence restores Second Wind")
	fighter.level_up()
	_assert(fighter.has_feature("fighter_action_surge"), "fighter receives curated Action Surge at level 2")
	fighter.level_up()
	fighter.level_up()
	fighter.level_up()
	_assert(fighter.has_feature("fighter_extra_attack") and fighter.extra_attacks == 1, "fighter receives executable Extra Attack at level 5")
	for class_id in ["barbarian", "monk", "paladin", "ranger"]:
		var martial: Character = _fresh_char("%s leveler" % class_id, "human", class_id,
			{"STR": 16, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
		for level_step in 4:
			martial.level_up()
		_assert(martial.extra_attacks == 1, "%s receives executable level-5 Extra Attack" % class_id)
	for class_id in DataLoader.classes.keys():
		var broad_class: Character = _fresh_char("%s representative" % class_id, "human", str(class_id),
			{"STR": 12, "DEX": 12, "CON": 12, "INT": 12, "WIS": 12, "CHA": 12})
		var representative_weapon := DataLoader.get_item(broad_class.inventory.get_weapon())
		if representative_weapon.is_empty():
			representative_weapon = {"ability": "STR", "damage": "1d4", "damage_type": "bludgeoning", "range": 1}
		var representative_target := _monster_inst("goblin")
		representative_target["current_hp"] = 100
		representative_target["max_hp"] = 100
		representative_target["armor_class"] = -100
		var representative_attack: Dictionary = {}
		var representative_action_resolved := false
		for _attempt in 20:
			representative_attack = CombatAction.resolve_weapon_attack(broad_class, representative_target, representative_weapon)
			if representative_attack.get("hit", false):
				representative_action_resolved = true
				break
		_assert(not broad_class.class_id.is_empty() and representative_action_resolved and representative_attack.get("damage", 0) >= 0,
			"%s creates and resolves a production weapon action" % class_id)
		var restored_class: Character = Character.new()
		restored_class.from_dict(broad_class.to_dict())
		_assert(restored_class.class_id == broad_class.class_id and restored_class.level == broad_class.level and
			restored_class.current_hp == broad_class.current_hp and restored_class.known_spells == broad_class.known_spells and
			restored_class.inventory.to_dict() == broad_class.inventory.to_dict(),
			"%s representative character survives DTO persistence round-trip" % class_id)
		print("[class-matrix] %s action=%s damage=%d persisted=%s" % [class_id, representative_attack.get("message", "resolved"), int(representative_attack.get("damage", 0)), str(restored_class.class_id == broad_class.class_id)])
	var barbarian: Character = _fresh_char("Rage Tester", "human", "barbarian",
		{"STR": 16, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	var rage_feature: Dictionary = barbarian.get_feature("barbarian_rage")
	_assert(not rage_feature.is_empty() and rage_feature.get("action_cost", "") == "bonus_action", "barbarian Rage is a curated bonus-action feature")
	_assert(rage_feature.get("uses_per", "") == "rest" and rage_feature.get("effects", []).size() == 2, "barbarian Rage has a rest resource and executable effects")
	var barbarian_defense: Dictionary = barbarian.get_feature("barbarian_unarmored_defense")
	_assert(barbarian_defense.get("effects", [])[0].get("type", "") == "unarmored_defense" and barbarian_defense.get("effects", [])[0].get("allows_shield", false), "barbarian Unarmored Defense has a curated shield-compatible AC contract")
	var armored_barbarian_ac := barbarian.get_ac()
	barbarian.inventory.unequip(Inventory.Slot.BODY)
	barbarian._recalculate_ac()
	_assert(barbarian.get_ac() == 10 + barbarian.ability_scores.get_ability_modifier("DEX") + barbarian.ability_scores.get_ability_modifier("CON") + 2, "barbarian Unarmored Defense uses Dexterity, Constitution, and the equipped shield")
	barbarian.inventory.equip(Inventory.Slot.BODY, "chain_mail", true)
	barbarian._recalculate_ac()
	_assert(barbarian.get_ac() == armored_barbarian_ac, "barbarian AC returns to the equipped armor calculation")
	var reckless: Character = _fresh_char("Reckless Barbarian", "human", "barbarian",
		{"STR": 16, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
	reckless.level_up()
	var reckless_feature: Dictionary = reckless.get_feature("barbarian_reckless_attack")
	_assert(reckless_feature.get("effects", [])[0].get("type", "") == "reckless_attack", "barbarian Reckless Attack has a production advantage effect")
	var reckless_activation := CombatAction.activate_reckless_attack(reckless)
	_assert(reckless_activation.get("success", false) and reckless.has_condition("reckless_attack"), "Reckless Attack marks the barbarian as vulnerable through the shared combat boundary")
	_assert(not CombatAction.activate_reckless_attack(reckless).get("success", true), "Reckless Attack cannot be chosen twice in one turn")
	var monk: Character = _fresh_char("Monk", "human", "monk",
		{"STR": 12, "DEX": 16, "CON": 12, "INT": 10, "WIS": 16, "CHA": 10})
	monk.level_up()
	var unarmored_defense: Dictionary = monk.get_feature("monk_unarmored_defense")
	_assert(unarmored_defense.get("effects", [])[0].get("type", "") == "unarmored_defense", "monk Unarmored Defense is exposed as a curated passive contract")
	var armored_monk_ac := monk.get_ac()
	_assert(armored_monk_ac == 16, "Monk starts with the production leather-and-shield AC")
	monk.inventory.unequip(Inventory.Slot.BODY)
	monk.inventory.unequip(Inventory.Slot.SHIELD)
	monk._recalculate_ac()
	_assert(monk.get_ac() == 16, "Monk Unarmored Defense uses Dexterity plus Wisdom when armor and shield are removed")
	monk.inventory.equip(Inventory.Slot.BODY, "leather_armor")
	monk.inventory.equip(Inventory.Slot.SHIELD, "shield")
	monk._recalculate_ac()
	_assert(monk.get_ac() == armored_monk_ac, "Monk AC returns to the equipped armor and shield calculation")
	var patient_defense: Dictionary = monk.get_feature("monk_patient_defense")
	_assert(not patient_defense.is_empty() and patient_defense.get("action_cost", "") == "bonus_action", "monk receives a curated Patient Defense bonus action")
	_assert(patient_defense.get("uses_per", "") == "turn" and patient_defense.get("effects", []).size() == 1, "Patient Defense grants a per-turn Dodging effect")
	var step_of_wind: Dictionary = monk.get_feature("monk_step_of_the_wind")
	_assert(not step_of_wind.is_empty() and step_of_wind.get("action_cost", "") == "bonus_action", "monk receives a curated Step of the Wind bonus action")
	_assert(step_of_wind.get("uses_per", "") == "turn" and step_of_wind.get("effects", []).size() == 1, "Step of the Wind has a per-turn executable effect")
	var martial_arts: Dictionary = monk.get_feature("monk_martial_arts")
	var bonus_unarmed: Dictionary = monk.get_feature("monk_bonus_unarmed_strike")
	var flurry: Dictionary = monk.get_feature("monk_flurry_of_blows")
	_assert(martial_arts.get("effects", [])[0].get("type", "") == "unarmed_attack" and bonus_unarmed.get("effects", [])[0].get("type", "") == "unarmed_attack", "monk Martial Arts and Bonus Unarmed Strike use the production unarmed-attack effect")
	_assert(martial_arts.get("uses_per", "") == "turn" and bonus_unarmed.get("action_cost", "") == "bonus_action", "monk unarmed features are per-turn bonus actions")
	_assert(flurry.get("effects", [])[0].get("type", "") == "unarmed_attack" and flurry.get("effects", [])[0].get("count", 0) == 2, "Monk Flurry of Blows is a two-strike unarmed contract")
	_assert(flurry.get("uses_per", "") == "turn" and flurry.get("action_cost", "") == "bonus_action", "Flurry of Blows restores per turn and spends a bonus action")
	var paladin: Character = _fresh_char("Smiter", "human", "paladin",
		{"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	paladin.level_up()
	var divine_smite: Dictionary = paladin.get_feature("paladin_divine_smite")
	_assert(not divine_smite.is_empty() and divine_smite.get("type", "") == "passive", "paladin receives a curated Divine Smite passive")
	_assert(divine_smite.get("effects", []).size() == 1 and divine_smite.get("effects", [])[0].get("type", "") == "divine_smite", "Divine Smite has a production radiant damage effect")
	var fighting_style: Dictionary = paladin.get_feature("paladin_fighting_style")
	_assert(fighting_style.get("effects", [])[0].get("type", "") == "defense_style" and fighting_style.get("effects", [])[0].get("ac_bonus", 0) == 1, "Paladin Defense Fighting Style has a curated armored AC contract")
	var armored_paladin_ac := paladin.get_ac()
	_assert(armored_paladin_ac == paladin.base_ac + 1, "Paladin Defense Fighting Style adds one AC while chain mail is worn")
	paladin.inventory.unequip(Inventory.Slot.BODY)
	paladin.inventory.unequip(Inventory.Slot.SHIELD)
	paladin._recalculate_ac()
	_assert(paladin.get_ac() == paladin.base_ac and paladin.get_ac() < armored_paladin_ac, "Paladin Defense Fighting Style does not apply without armor")
	paladin.inventory.equip(Inventory.Slot.BODY, "chain_mail", true)
	paladin.inventory.equip(Inventory.Slot.SHIELD, "shield", true)
	paladin._recalculate_ac()
	_assert(paladin.get_ac() == armored_paladin_ac, "Paladin Defense Fighting Style returns after armor and shield re-equip")
	var restored_paladin: Character = Character.new()
	restored_paladin.from_dict(paladin.to_dict())
	_assert(restored_paladin.has_feature("paladin_fighting_style") and restored_paladin.get_ac() == armored_paladin_ac, "Paladin Defense Fighting Style survives character persistence")
	var lay_on_hands: Dictionary = paladin.get_feature("paladin_lay_on_hands")
	_assert(not lay_on_hands.is_empty() and lay_on_hands.get("uses_per", "") == "rest" and lay_on_hands.get("resource_formula", "") == "level*5", "paladin receives a level-scaled rest-recharged Lay on Hands pool")
	_assert(paladin.feature_uses.get("paladin_lay_on_hands", 0) == 10, "level-2 Lay on Hands starts with ten healing points")
	var divine_sense: Dictionary = paladin.get_feature("paladin_divine_sense")
	_assert(divine_sense.get("effects", [])[0].get("type", "") == "divine_sense", "paladin Divine Sense has a production detection effect")
	var bard: Character = _fresh_char("Bard", "human", "bard",
		{"STR": 10, "DEX": 14, "CON": 12, "INT": 12, "WIS": 10, "CHA": 16})
	var bardic_inspiration: Dictionary = bard.get_feature("bard_bardic_inspiration")
	_assert(bardic_inspiration.get("effects", [])[0].get("type", "") == "bardic_inspiration", "bard Bardic Inspiration has a production die effect")
	var ranger: Character = _fresh_char("Ranger", "human", "ranger",
		{"STR": 12, "DEX": 16, "CON": 12, "INT": 10, "WIS": 14, "CHA": 10})
	var favored_foe: Dictionary = ranger.get_feature("ranger_favored_foe")
	_assert(favored_foe.get("effects", [])[0].get("type", "") == "favored_foe", "ranger Favored Foe has a production mark effect")
	ranger.level_up()
	var ranger_style: Dictionary = ranger.get_feature("ranger_fighting_style")
	_assert(ranger_style.get("effects", [])[0].get("type", "") == "archery" and ranger_style.get("effects", [])[0].get("attack_bonus", 0) == 2, "ranger Archery has a curated ranged attack contract")
	var longbow: Dictionary = DataLoader.get_item("longbow")
	var longsword: Dictionary = DataLoader.get_item("longsword")
	_assert(ranger.get_attack_style_bonus(longbow) == 2 and ranger.get_attack_style_bonus(longsword) == 0, "ranger Archery applies only to ranged weapons")
	var ranger_attack_roll := ranger.make_attack_roll("DEX", false, false, longbow)
	_assert(ranger_attack_roll.get("feature_bonus", 0) == 2 and ranger_attack_roll.get("modifier", 0) == ranger.ability_scores.get_ability_modifier("DEX") + ranger.proficiency_bonus + 2, "ranger Archery adds two to a ranged attack roll")
	var rogue: Character = _fresh_char("Rogue", "human", "rogue",
		{"STR": 10, "DEX": 16, "CON": 12, "INT": 12, "WIS": 10, "CHA": 12})
	_assert(rogue.has_feature("rogue_sneak_attack"), "rogue receives curated Sneak Attack")
	rogue.level_up()
	var cunning_action: Dictionary = rogue.get_feature("rogue_cunning_action")
	_assert(not cunning_action.is_empty() and cunning_action.get("action_cost", "") == "bonus_action", "rogue receives a curated Cunning Action bonus action")
	_assert(cunning_action.get("uses_per", "") == "turn" and not cunning_action.get("effects", []).is_empty(), "Cunning Action has a per-turn executable effect")

func _test_character_creation() -> void:
	print("\n[Group] Character creation")
	var c: Character = _fresh_char("Tester", "human", "fighter",
		{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8})
	_assert(c.max_hp > 0, "initialized character has positive max_hp")
	_assert(c.current_hp == c.max_hp, "current_hp starts at max")
	_assert(c.is_alive, "character starts alive")
	_assert(c.ability_scores.get_ability_modifier("STR") == 3, "STR 15 + human +1 = 16 -> +3 modifier")
	_assert(c.has_feature("fighting_style") or c.features.size() > 0, "level 1 features unlocked")
	var before := c.current_hp
	var dealt := c.take_damage(3)
	_assert(dealt == 3 and c.current_hp == before - 3, "take_damage reduces hp by dealt amount")
	var healed := c.heal(9999)
	_assert(c.current_hp == c.max_hp and healed <= 9999, "heal clamps to max_hp")
	# temp hp absorbs first
	c.temp_hp = 5
	var d2 := c.take_damage(3)
	_assert(d2 == 0 and c.temp_hp == 2, "temp hp absorbs damage before hp")
	c.take_damage(c.max_hp + 50)
	_assert(not c.is_alive, "lethal damage flips is_alive false")

func _test_dice_parser() -> void:
	print("\n[Group] Dice parser")
	var total: int = Dice.parse_dice_string("2D6+3")
	_assert(total >= 5 and total <= 15, "2d6+3 in [5,15] (got %d)" % total)
	var modded: int = Dice.parse_dice_string("1D20+STR", {"STR": 3})
	_assert(modded >= 4 and modded <= 23, "1d20+STR(3) in [4,23] (got %d)" % modded)
	var neg: int = Dice.parse_dice_string("1D20-2")
	_assert(neg >= -1 and neg <= 18, "1d20-2 in [-1,18] (got %d)" % neg)
	var adv: int = Dice.roll_with_advantage(20)
	_assert(adv >= 1 and adv <= 20, "advantage roll in [1,20] (got %d)" % adv)

func _test_combat_action() -> void:
	print("\n[Group] CombatAction")
	var attack_command := CombatCommand.from_hud("attack", {})
	_assert(attack_command != null and attack_command.is_valid(), "combat command accepts a valid attack request")
	var move_command := CombatCommand.movement(Vector2i(2, -1))
	_assert(move_command.is_valid() and move_command.target_hex() == Vector2i(2, -1), "movement command carries a typed target")
	_assert(CombatCommand.from_hud("cast_spell", {}) == null, "combat command rejects an incomplete spell request")
	_assert(CombatCommand.from_hud("unknown_action", {}) == null, "combat command rejects an unknown action")
	var command_caster: Character = _fresh_char("Command Caster", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	_assert(CombatCommand.from_hud_for_character("cast_spell", {"spell": DataLoader.get_spell("magic_missile")}, command_caster) != null, "combat command accepts a spell the active character knows")
	_assert(CombatCommand.from_hud_for_character("cast_spell", {"spell": {"id": "not_a_spell"}}, command_caster) == null, "combat command rejects an inaccessible spell before targeting")
	_assert(CombatCommand.from_hud_for_character("use_feature", {"feature": {"id": "not_a_feature"}}, command_caster) == null, "combat command rejects an unowned feature before mutation")
	command_caster.inventory.add_item("potion_healing")
	_assert(CombatCommand.from_hud_for_character("use_item", {"item": DataLoader.get_item("potion_healing")}, command_caster) != null, "combat command accepts an owned consumable")
	_assert(CombatCommand.from_hud_for_character("use_item", {"item": DataLoader.get_item("potion_greater_healing")}, command_caster) == null, "combat command rejects an unowned consumable")
	var economy := CombatState.new()
	_assert(economy.turn_budget.can_spend("action") and economy.turn_budget.can_spend("bonus_action"), "new combat turn has action and bonus-action budgets")
	_assert(economy.turn_budget.spend("bonus_action") and economy.turn_budget.bonus_action_available == false and economy.turn_budget.action_available, "bonus action spends independently of the main action")
	_assert(economy._spend_action_cost("action") and not economy._can_spend_action_cost("action"), "main action budget is consumed independently")
	economy.turn_budget.action_available = true
	_assert(economy._spend_action_cost("action") and economy.turn_budget.action_available == false, "action budget can be consumed before an extra-action effect")
	economy._reset_turn_action_economy()
	_assert(not economy.turn_budget.has_acted_this_turn and economy.turn_budget.action_available and economy.turn_budget.bonus_action_available and economy._can_spend_action_cost("action"), "a fresh turn restores both action budgets")
	economy.turn_budget.action_available = true
	_assert(economy.turn_budget.action_available and economy._can_spend_action_cost("action"), "extra-action effects can restore the action budget")
	economy.free()
	var movement_entity := {"hex_position": Vector2i.ZERO, "is_alive": true}
	var movement_result := CombatAction.resolve_movement_step(movement_entity, Vector2i.ZERO, Vector2i(1, 0))
	_assert(movement_result.get("success", false) and movement_entity["hex_position"] == Vector2i(1, 0), "player and AI movement share a typed position-step resolver")
	var stale_movement := CombatAction.resolve_movement_step(movement_entity, Vector2i.ZERO, Vector2i(2, 0))
	_assert(not stale_movement.get("success", true) and movement_entity["hex_position"] == Vector2i(1, 0), "stale movement paths reject before position mutation")
	var atk: Character = _fresh_char("Attacker", "human", "fighter",
		{"STR": 16, "DEX": 14, "CON": 14, "INT": 10, "WIS": 12, "CHA": 8})
	var weapon: Dictionary = DataLoader.get_item("longsword")
	if weapon.is_empty():
		weapon = {"name": "Test Sword", "ability": "STR", "damage": "1d8", "damage_type": "slashing"}
	else:
		if not weapon.has("ability"): weapon["ability"] = "STR"
		if not weapon.has("damage"): weapon["damage"] = "1d8"
	var mi: Dictionary = _monster_inst("goblin")
	var saw_hit := false
	var saw_miss := false
	for i in 50:
		var res: Dictionary = CombatAction.resolve_weapon_attack(atk, mi, weapon)
		_assert(typeof(res) == TYPE_DICTIONARY, "attack returns a dictionary")
		_assert(res.has("hit") and res.has("message"), "attack result has hit + message keys")
		_assert(not res.get("hit", false) or int(res.get("damage", -1)) >= 0,
			"hit deals non-negative damage when present")
		if res.get("hit", false):
			saw_hit = true
		else:
			saw_miss = true
	_assert(saw_hit, "observed at least one hit across 50 attacks")
	_assert(saw_miss, "observed at least one miss across 50 attacks (RNG variance)")
	_assert(int(mi.get("current_hp", -99)) <= 7, "monster hp tracked during attacks")
	# advantage improves hit chance meaningfully over many rolls
	var hits_adv := 0
	for i in 200:
		var r: Dictionary = CombatAction.resolve_weapon_attack(atk, mi, weapon, true, false)
		if r.get("hit", false): hits_adv += 1
	_assert(hits_adv > 100, "advantage yields >50%% hits over 200 rolls (got %d)" % hits_adv)
	var rogue5: Character = _fresh_char("Rogue Five", "human", "rogue",
		{"STR": 10, "DEX": 16, "CON": 12, "INT": 12, "WIS": 10, "CHA": 12})
	for level_step in 4:
		rogue5.level_up()
	_assert(rogue5.has_feature("rogue_uncanny_dodge"), "rogue reaches the production Uncanny Dodge feature at level 5")
	var reaction_target: Character = rogue5
	reaction_target.max_hp = 100
	reaction_target.current_hp = 100
	reaction_target.reaction_available = true
	var reaction_seen := false
	for attempt in 50:
		if not reaction_target.reaction_available:
			break
		var reaction_result := CombatAction.resolve_weapon_attack(atk, reaction_target, weapon)
		if reaction_result.get("hit", false):
			reaction_seen = true
	_assert(reaction_seen and not reaction_target.reaction_available, "Uncanny Dodge consumes the owning character reaction on a hit")
	# An owner-facing decision map must be authoritative: declining preserves the
	# reaction, while accepting spends it only on a hit.
	reaction_target.reaction_available = true
	var declined_hit := false
	for attempt in 50:
		var declined_result := CombatAction.resolve_weapon_attack(atk, reaction_target, weapon, false, false, {"uncanny_dodge": false})
		if declined_result.get("hit", false):
			declined_hit = true
			break
	_assert(declined_hit and reaction_target.reaction_available, "declining Uncanny Dodge preserves the reaction")
	reaction_target.reaction_available = true
	var accepted_hit := false
	for attempt in 50:
		var accepted_result := CombatAction.resolve_weapon_attack(atk, reaction_target, weapon, false, false, {"uncanny_dodge": true})
		if accepted_result.get("hit", false):
			accepted_hit = true
			break
	_assert(accepted_hit and not reaction_target.reaction_available, "accepting Uncanny Dodge spends the reaction on a hit")
	var rage_attacker: Character = _fresh_char("Rage Attacker", "human", "barbarian",
		{"STR": 16, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	var rage_feature_for_test: Dictionary = rage_attacker.get_feature("barbarian_rage")
	var rage_target: Character = _fresh_char("Rage Target", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	rage_target.base_ac = 0
	rage_target.max_hp = 100
	rage_target.current_hp = 100
	var rage_effect_results := EventResolver.apply_effects(rage_attacker, rage_feature_for_test.get("effects", []))
	_assert(rage_effect_results.size() == 2 and rage_attacker.has_condition("raging") and rage_attacker.get_modifier("stat", "damage:physical") == 2, "Rage effects apply a timed condition and physical damage bonus")
	var monk_for_test: Character = _fresh_char("Patient Defense", "human", "monk",
		{"STR": 12, "DEX": 16, "CON": 12, "INT": 10, "WIS": 16, "CHA": 10})
	monk_for_test.level_up()
	var patient_defense_effects: Array = monk_for_test.get_feature("monk_patient_defense").get("effects", [])
	var patient_defense_results := EventResolver.apply_effects(monk_for_test, patient_defense_effects)
	_assert(patient_defense_results.size() == 1 and monk_for_test.has_condition("dodging"), "Patient Defense applies the shared Dodging condition")
	var smiter_for_test: Character = _fresh_char("Smite Test", "human", "paladin",
		{"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	smiter_for_test.level_up()
	smiter_for_test.spell_slots["1"] = 1
	var smite_target: Character = _fresh_char("Smite Target", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	smite_target.base_ac = 0
	smite_target.max_hp = 100
	smite_target.current_hp = 100
	var smite_seen := false
	for attempt in 50:
		var smite_attack := CombatAction.resolve_weapon_attack(smiter_for_test, smite_target, {"ability": "STR", "damage": "0", "damage_type": "slashing"})
		if smite_attack.get("hit", false):
			var smite_result := CombatAction.resolve_divine_smite(smiter_for_test, smite_target, 1)
			_assert(smite_result.get("success", false) and smite_result.get("damage", 0) >= 2, "Divine Smite deals radiant damage after a melee hit")
			_assert(smiter_for_test.spell_slots.get("1", 0) == 0, "Divine Smite consumes the selected spell slot")
			smite_seen = true
			break
	_assert(smite_seen, "Divine Smite fixture reached a melee hit")
	var monster_rider_target: Character = _fresh_char("Monster Rider Target", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 8, "INT": 10, "WIS": 10, "CHA": 10})
	monster_rider_target.max_hp = 100
	monster_rider_target.current_hp = 100
	var spider_rider := CombatAction.resolve_monster_attack_effects(_monster_inst("giant_spider"), monster_rider_target,
		{"extra_effects": [{"type": "poison_save", "save": "CON", "dc": 99, "damage": "1d4"}]}, {"hit": true, "damage": 1})
	_assert(not spider_rider.is_empty() and monster_rider_target.has_condition("poisoned") and monster_rider_target.current_hp < 100, "Crown monster poison riders use the shared save and condition boundary")
	var corrode_rider := CombatAction.resolve_monster_attack_effects(_monster_inst("ooze"), monster_rider_target,
		{"extra_effects": [{"type": "corrode_armor"}]}, {"hit": true, "damage": 1})
	_assert(not corrode_rider.is_empty() and monster_rider_target.get_modifier("stat", "AC") == -1, "Crown monster armor riders persist as timed AC modifiers")
	var monk_attack: Character = _fresh_char("Unarmed Monk", "human", "monk",
		{"STR": 10, "DEX": 16, "CON": 12, "INT": 10, "WIS": 16, "CHA": 10})
	var unarmed_target: Character = _fresh_char("Unarmed Target", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	unarmed_target.base_ac = 0
	unarmed_target.max_hp = 100
	unarmed_target.current_hp = 100
	var unarmed_seen := false
	for attempt in 50:
		var unarmed_result := CombatAction.resolve_unarmed_attack(monk_attack, unarmed_target)
		if unarmed_result.get("hit", false):
			_assert(unarmed_result.get("damage", 0) >= 1 and unarmed_result.get("damage_type", "") == "bludgeoning", "Monk Bonus Unarmed Strike resolves through weapon damage")
			unarmed_seen = true
			break
	_assert(unarmed_seen, "Monk unarmed strike fixture reached a melee hit")
	var flurry_target: Character = _fresh_char("Flurry Target", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	flurry_target.base_ac = 0
	flurry_target.max_hp = 100
	flurry_target.current_hp = 100
	var flurry_attacks := CombatAction.resolve_flurry_of_blows(monk_attack, flurry_target)
	_assert(flurry_attacks.size() == 2, "Flurry of Blows resolves two unarmed strikes through the shared boundary")
	var ranger_for_test: Character = _fresh_char("Favored Ranger", "human", "ranger",
		{"STR": 12, "DEX": 16, "CON": 12, "INT": 10, "WIS": 14, "CHA": 10})
	var favored_target := _monster_inst("goblin")
	favored_target["id"] = "favored_target"
	favored_target["current_hp"] = 100
	favored_target["max_hp"] = 100
	var favored_mark := CombatAction.resolve_favored_foe_mark(ranger_for_test, favored_target)
	_assert(favored_mark.get("success", false) and favored_target.get("conditions", {}).has("favored_foe"), "Favored Foe marks a stable monster target")
	var favored_damage := CombatAction.resolve_favored_foe_damage(ranger_for_test, favored_target)
	_assert(favored_damage.get("success", false) and favored_damage.get("damage", 0) >= 1, "Favored Foe adds once-per-turn damage to the marked target")
	var favored_repeat := CombatAction.resolve_favored_foe_damage(ranger_for_test, favored_target)
	_assert(not favored_repeat.get("success", true), "Favored Foe does not add damage twice in one turn")
	var mark_target := _monster_inst("goblin")
	mark_target["id"] = "hunters_mark_target"
	mark_target["current_hp"] = 100
	mark_target["max_hp"] = 100
	var hunters_mark_result := CombatAction.resolve_spell(ranger_for_test, mark_target, DataLoader.get_spell("hunters_mark"))
	_assert(hunters_mark_result.get("success", false) and mark_target.get("conditions", {}).has("hunters_mark"), "Hunter's Mark resolves as a target mark instead of a spell attack")
	var mark_damage := CombatAction.resolve_hunters_mark_damage(ranger_for_test, mark_target)
	_assert(mark_damage.get("success", false) and mark_damage.get("damage", 0) >= 1 and mark_target.get("current_hp", 100) < 100, "Hunter's Mark adds 1d6 damage to a weapon-hit follow-up")
	var sense_paladin: Character = _fresh_char("Sense Paladin", "human", "paladin",
		{"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	var sense_undead := _monster_inst("skeleton")
	sense_undead["id"] = "sense_undead"
	sense_undead["creature_type"] = "undead"
	sense_undead["hex_position"] = Vector2i(3, 0)
	var sense_humanoid := _monster_inst("goblin")
	sense_humanoid["id"] = "sense_humanoid"
	sense_humanoid["creature_type"] = "humanoid"
	sense_humanoid["hex_position"] = Vector2i(3, 1)
	var sense_result := CombatAction.resolve_divine_sense(sense_paladin, [sense_undead, sense_humanoid], Vector2i.ZERO)
	_assert(sense_result.get("success", false) and sense_result.get("target_ids", []).has("sense_undead") and not sense_result.get("target_ids", []).has("sense_humanoid"), "Divine Sense detects typed undead without name-based false positives")
	var bard_for_test: Character = _fresh_char("Bardic Test Bard", "human", "bard",
		{"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	var inspired_ally: Character = _fresh_char("Inspired Ally", "human", "fighter",
		{"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
	var inspiration_uses_before := int(bard_for_test.feature_uses.get("bard_bardic_inspiration", 0))
	var inspiration_result := CombatAction.resolve_bardic_inspiration(bard_for_test, inspired_ally)
	_assert(inspiration_result.get("success", false) and inspired_ally.feature_uses.get("bardic_inspiration_die", "") == "1d6", "Bardic Inspiration grants an ally a level-scaled die")
	_assert(int(bard_for_test.feature_uses.get("bard_bardic_inspiration", 0)) == inspiration_uses_before - 1, "Bardic Inspiration spends one shared feature use after a valid grant")
	var second_inspired_ally: Character = _fresh_char("Second Inspired Ally", "human", "fighter",
		{"STR": 12, "DEX": 12, "CON": 12, "INT": 10, "WIS": 10, "CHA": 8})
	var exhausted_inspiration := CombatAction.resolve_bardic_inspiration(bard_for_test, second_inspired_ally)
	_assert(not exhausted_inspiration.get("success", false) and second_inspired_ally.feature_uses.get("bardic_inspiration_die", "") == "", "Bardic Inspiration rejects a second grant after its resource is spent")
	var warlock_class: Dictionary = DataLoader.get_character_class("warlock")
	var pact_feature: Character = _fresh_char("Pact Feature Warlock", "human", "warlock",
		{"STR": 8, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	_assert(pact_feature.get_feature("warlock_pact_magic").get("effects", [])[0].get("type", "") == "pact_magic", "Warlock Pact Magic has a production executable feature effect")
	_assert(warlock_class.get("pact_magic_by_level", {}).get("1", {}).get("slot_level", 0) == 1 and pact_feature.spell_slots.get("1", 0) == 1, "Warlock level 1 receives one level-1 pact slot")
	var inspiration_attack_target: Character = _fresh_char("Inspiration Target", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	inspiration_attack_target.base_ac = 0
	inspiration_attack_target.max_hp = 100
	inspiration_attack_target.current_hp = 100
	# Keep the production attack path, but make its natural d20 deterministic so
	# a natural 1 cannot bypass the optional Bardic Inspiration reaction.
	seed(424242)
	var inspiration_attack := CombatAction.resolve_weapon_attack(inspired_ally, inspiration_attack_target, {"ability": "STR", "damage": "0", "damage_type": "slashing"}, false, false, {"bardic_inspiration": true})
	_assert(inspiration_attack.get("hit", false) and inspiration_attack.get("bardic_bonus", 0) >= 1 and not inspired_ally.feature_uses.has("bardic_inspiration_die"), "Bardic Inspiration can be consumed on the ally's next attack")
	var lay_target: Character = _fresh_char("Lay Target", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	lay_target.max_hp = 20
	lay_target.current_hp = 2
	var lay_result := CombatAction.resolve_lay_on_hands(smiter_for_test, lay_target, 5)
	_assert(lay_result.get("success", false) and lay_result.get("healing", 0) == 5 and lay_target.current_hp == 7, "Lay on Hands restores the requested healing amount")
	_assert(smiter_for_test.feature_uses.get("paladin_lay_on_hands", 0) == 5, "Lay on Hands spends healing points rather than a single button use")
	smiter_for_test.level_up()
	_assert(smiter_for_test.get_feature_max_uses("paladin_lay_on_hands") == 15 and smiter_for_test.feature_uses.get("paladin_lay_on_hands", 0) == 10, "Lay on Hands pool grows by five on paladin level-up while preserving spent points")
	smiter_for_test.long_rest()
	_assert(smiter_for_test.feature_uses.get("paladin_lay_on_hands", 0) == 15, "Lay on Hands fully restores on a long rest")
	var fixed_weapon := {"ability": "STR", "damage": "0", "damage_type": "slashing"}
	var rage_damage_seen := false
	for attempt in 50:
		var rage_result := CombatAction.resolve_weapon_attack(rage_attacker, rage_target, fixed_weapon)
		if rage_result.get("hit", false):
			rage_damage_seen = true
			_assert(rage_result.get("damage", 0) == 2, "Rage adds its physical damage bonus to a weapon hit")
			break
	_assert(rage_damage_seen, "Rage damage fixture reached a weapon hit")
	var resistant_target: Character = _fresh_char("Raging Defender", "human", "barbarian",
		{"STR": 10, "DEX": 10, "CON": 16, "INT": 10, "WIS": 10, "CHA": 10})
	resistant_target.base_ac = 0
	resistant_target.max_hp = 100
	resistant_target.current_hp = 100
	resistant_target.add_condition("raging", 10)
	var resistance_seen := false
	for attempt in 50:
		var resistance_result := CombatAction.resolve_weapon_attack(atk, resistant_target, {"ability": "STR", "damage": "10", "damage_type": "slashing"})
		if resistance_result.get("hit", false):
			resistance_seen = true
			var expected_resisted_damage := 10 if resistance_result.get("crit", false) else 5
			_assert(resistance_result.get("damage", 0) == expected_resisted_damage, "Rage halves incoming physical weapon damage")
			break
	_assert(resistance_seen, "Rage resistance fixture reached a weapon hit")


func _test_initiative() -> void:
	print("\n[Group] Initiative")
	var tracker := InitiativeTracker.new()
	tracker.add_combatant("player_a", "A", true, null, 12, 2)
	tracker.add_combatant("player_b", "B", true, null, 12, 2)
	tracker.add_combatant("monster_a", "M", false, null, 12, 2)
	tracker.sort_initiative()
	var first_order: Array[String] = []
	for combatant in tracker.combatants:
		first_order.append(str(combatant.get("id", "")))
	tracker.sort_initiative()
	var second_order: Array[String] = []
	for combatant in tracker.combatants:
		second_order.append(str(combatant.get("id", "")))
	_assert(first_order == second_order, "initiative tie ordering is stable across repeated sorts")
	_assert(first_order == ["monster_a", "player_a", "player_b"], "initiative tie ordering uses stable IDs")

func _test_player_commands() -> void:
	print("\n[Group] Player commands")
	var move_command := PlayerCommand.move(Vector2i(3, -2))
	_assert(move_command != null and move_command.is_valid() and move_command.target_hex() == Vector2i(3, -2), "player move command carries a typed target")
	_assert(PlayerCommand.from_ui("event_choice", {}) == null, "event command rejects an empty choice")
	var choice_command := PlayerCommand.event_choice({"text": "Leave", "effects": []})
	_assert(choice_command != null and choice_command.is_valid(), "event choice command accepts a complete option")
	_assert(PlayerCommand.inventory_buy(-1, "longsword") == null, "inventory command rejects an invalid seat")
	var buy_command := PlayerCommand.inventory_buy(0, "longsword")
	_assert(buy_command != null and buy_command.is_valid(), "inventory command carries a validated item intent")
	_assert(PlayerCommand.from_ui("unknown_intent", {}) == null, "shared player command rejects unknown intent types")


func _test_spellcasting() -> void:
	print("\n[Group] Spellcasting")
	var sphere_selection := EventResolver.resolve_area_selection({"type": "area_selection", "shape": "sphere", "radius": 2})
	_assert(sphere_selection.get("success", false) and sphere_selection.get("type", "") == "area_selection" and not sphere_selection.get("persistent", true), "area selection returns a transient validated sphere result")
	var invalid_selection := EventResolver.resolve_area_selection({"type": "area_selection", "shape": "sphere", "radius": 0})
	_assert(not invalid_selection.get("success", true), "area selection rejects an invalid radius before state mutation")
	var fireball_effects: Array = DataLoader.get_spell("fireball").get("effects", [])
	var fireball_area_effect := fireball_effects.any(func(effect): return str(effect.get("type", "")) == "area_selection" and int(effect.get("radius", 0)) == 3)
	_assert(fireball_area_effect, "production Fireball carries the shared area-selection contract")
	var mid_spell_ids := ["misty_step", "scorching_ray", "fireball", "counterspell"]
	for spell_id in mid_spell_ids:
		var mid_spell: Dictionary = DataLoader.get_spell(spell_id)
		var mid_resolution_payload: bool = not mid_spell.get("effects", []).is_empty() or mid_spell.has("damage") or mid_spell.has("damage_per_dart") or mid_spell.has("damage_per_ray") or mid_spell.has("save") or str(mid_spell.get("attack_type", "none")) != "none"
		_assert(not mid_spell.is_empty(), "%s is present in the curated level-2/3 spell cohort" % spell_id)
		_assert(int(mid_spell.get("level", -1)) in [2, 3], "%s remains a level-2/3 spell" % spell_id)
		_assert(str(mid_spell.get("casting_time", "")) in DataLoader.VALID_SPELL_CASTING_TIMES and int(mid_spell.get("range", -1)) >= 0, "%s has a valid casting time and range" % spell_id)
		_assert(str(mid_spell.get("target", "")) in DataLoader.VALID_SPELL_TARGETS, "%s has a valid target contract" % spell_id)
		_assert(mid_resolution_payload, "%s has a production resolution payload" % spell_id)
	var mid_caster: Character = _fresh_char("Mid-level Mage", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	mid_caster.spell_slots = {"2": 1}
	var misty_step: Dictionary = DataLoader.get_spell("misty_step")
	var misty_cast := CombatAction.resolve_spell(mid_caster, mid_caster, misty_step, true)
	_assert(misty_cast.get("success", false) and mid_caster.spell_slots.get("2", 0) == 0, "Misty Step accepts only its caster and spends its level-2 slot")
	var early_spell_ids := ["fire_bolt", "ray_of_frost", "light", "magic_missile", "shield", "mage_armor", "sleep", "bless", "cure_wounds", "thunderwave", "hunters_mark"]
	for spell_id in early_spell_ids:
		var early_spell: Dictionary = DataLoader.get_spell(spell_id)
		var has_resolution_payload: bool = not early_spell.get("effects", []).is_empty() or early_spell.has("damage") or early_spell.has("damage_per_dart") or early_spell.has("damage_per_ray") or early_spell.has("save") or str(early_spell.get("attack_type", "none")) != "none"
		_assert(not early_spell.is_empty(), "%s is present in the curated early-spell cohort" % spell_id)
		_assert(str(early_spell.get("casting_time", "")) in DataLoader.VALID_SPELL_CASTING_TIMES and int(early_spell.get("range", -1)) >= 0, "%s has a valid casting time and range" % spell_id)
		_assert(str(early_spell.get("target", "")) in DataLoader.VALID_SPELL_TARGETS, "%s has a valid target contract" % spell_id)
		_assert(has_resolution_payload, "%s has a production resolution payload" % spell_id)
	# Fireball: level 3 save-based AoE. Caster is a wizard with INT.
	var caster: Character = _fresh_char("Mage", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	caster.spell_slots = {"3": 1}
	var fb: Dictionary = DataLoader.get_spell("fireball")
	var target: Dictionary = _monster_inst("goblin")
	# deduct slot true -> slot should decrement
	var res: Dictionary = CombatAction.resolve_spell(caster, target, fb, true)
	_assert(res.get("success", false), "fireball resolves with success")
	_assert(caster.spell_slots.get("3", 1) == 0, "spell slot deducted when deduct_slot=true")
	_assert(int(res.get("damage", -1)) >= 0, "fireball deals non-negative damage")
	_assert(int(res.get("damage", -1)) <= 48, "fireball damage <= 8d6 max (got %d)" % int(res.get("damage", -1)))
	# No slots left -> resolve fails cleanly
	var res2: Dictionary = CombatAction.resolve_spell(caster, target, fb, true)
	_assert(not res2.get("success", true), "fireball fails when no slots remain")
	# Curated multi-roll spell boundary: Magic Missile auto-hits and resolves all darts.
	var mm: Dictionary = DataLoader.get_spell("magic_missile")
	var caster2: Character = _fresh_char("Mage2", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	var t2: Dictionary = _monster_inst("goblin")
	t2["current_hp"] = 100
	var res3: Dictionary = CombatAction.resolve_spell(caster2, t2, mm, false)
	_assert(res3.get("success", false), "magic_missile spell resolves")
	_assert(res3.get("hit", false) and int(res3.get("dart_count", 0)) == 3 and int(res3.get("damage", 0)) > 0, "Magic Missile resolves three automatic force darts")
	var ray: Dictionary = DataLoader.get_spell("scorching_ray")
	var ray_target: Dictionary = _monster_inst("goblin")
	ray_target["armor_class"] = 0
	ray_target["current_hp"] = 100
	var ray_cast := CombatAction.resolve_spell(caster2, ray_target, ray, false)
	_assert(ray_cast.get("success", false) and int(ray_cast.get("ray_count", 0)) == 3 and int(ray_cast.get("rays_hit", 0)) > 0 and int(ray_cast.get("damage", 0)) > 0, "Scorching Ray resolves one spell attack and damage roll per ray")
	var effect_only: Dictionary = CombatAction.resolve_spell(caster2, caster2, DataLoader.get_spell("mage_armor"), false)
	_assert(effect_only.get("success", false) and effect_only.get("hit", false) and int(effect_only.get("damage", -1)) == 0, "Effect-only Mage Armor resolves without an invalid attack roll")
	var invalid_mage_armor: Dictionary = CombatAction.resolve_spell(caster2, t2, DataLoader.get_spell("mage_armor"), true)
	_assert(not invalid_mage_armor.get("success", true), "Mage Armor rejects a monster target before spending a slot")
	var invalid_light: Dictionary = CombatAction.resolve_spell(caster2, t2, DataLoader.get_spell("light"), false)
	_assert(not invalid_light.get("success", true), "Light rejects a non-caster target")
	var invalid_shield: Dictionary = CombatAction.resolve_spell(caster2, caster2, DataLoader.get_spell("shield"), false)
	_assert(not invalid_shield.get("success", true), "Shield remains reaction-only at the shared spell boundary")
	var wounded: Character = _fresh_char("Wounded", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	wounded.current_hp = 1
	var cure: Dictionary = DataLoader.get_spell("cure_wounds")
	var cure_cast := CombatAction.resolve_spell(caster2, wounded, cure, false)
	var cure_results := EventResolver.apply_effects(wounded, cure.get("effects", []))
	_assert(cure_cast.get("success", false) and not cure_results.is_empty() and wounded.current_hp > 1, "Cure Wounds uses the production effect-only path to heal an ally")
	var ray_effects := EventResolver.apply_effects(wounded, DataLoader.get_spell("ray_of_frost").get("effects", []))
	_assert(not ray_effects.is_empty() and wounded.get_modifier("stat", "speed") < 0, "Ray of Frost production effect applies a timed speed reduction")
	var pact_warlock: Character = _fresh_char("Pact Caster", "human", "warlock",
		{"STR": 8, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	var pact_target: Dictionary = _monster_inst("goblin")
	var pact_cast := CombatAction.resolve_spell(pact_warlock, pact_target, mm, true)
	_assert(pact_cast.get("success", false) and pact_warlock.spell_slots.get("1", 0) == 0, "Warlock Pact Magic spends the available pact slot on a leveled spell")
	pact_warlock.short_rest()
	_assert(pact_warlock.spell_slots.get("1", 0) == 1, "Warlock Pact Magic restores its slot on a short rest")
	pact_warlock.level_up()
	_assert(pact_warlock.spell_slots.get("2", 0) == 2, "Warlock pact slots scale to two level-2 slots at class level 2")
	var pact_level_two_cast := CombatAction.resolve_spell(pact_warlock, pact_target, mm, true)
	_assert(pact_level_two_cast.get("success", false) and pact_warlock.spell_slots.get("2", 0) == 1 and int(pact_level_two_cast.get("dart_count", 0)) == 4, "Warlock can cast a lower-level spell using a higher-level pact slot and gains its extra dart")
	var magical_cunning: Dictionary = pact_warlock.get_feature("warlock_magical_cunning")
	_assert(magical_cunning.get("type", "") == "active" and magical_cunning.get("action_cost", "") == "action" and magical_cunning.get("uses_per", "") == "rest", "Warlock Magical Cunning is a once-per-rest action contract")
	_assert(pact_warlock.use_feature("warlock_magical_cunning"), "Warlock Magical Cunning spends its available use")
	var cunning_results := EventResolver.apply_effects(pact_warlock, magical_cunning.get("effects", []))
	_assert(cunning_results.size() == 1 and pact_warlock.spell_slots.get("2", 0) == 2, "Warlock Magical Cunning restores up to half of the maximum pact slots")
	_assert(not pact_warlock.use_feature("warlock_magical_cunning"), "Warlock Magical Cunning cannot be used twice before its rest reset")
	pact_warlock.long_rest()
	_assert(pact_warlock.feature_uses.get("warlock_magical_cunning", 0) == 1, "Warlock Magical Cunning returns after a long rest")
	var upcast_ray_caster: Character = _fresh_char("Upcast Ray", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	upcast_ray_caster.spell_slots = {"3": 1}
	var upcast_ray_target: Dictionary = _monster_inst("goblin")
	upcast_ray_target["armor_class"] = 0
	var upcast_ray_cast := CombatAction.resolve_spell(upcast_ray_caster, upcast_ray_target, ray, true)
	_assert(upcast_ray_cast.get("success", false) and int(upcast_ray_cast.get("ray_count", 0)) == 4, "Scorching Ray gains an extra ray when cast with a higher-level slot")
	var sorcerer_for_test: Character = _fresh_char("Metamagic Sorcerer", "human", "sorcerer",
		{"STR": 8, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	var innate_sorcery: Dictionary = sorcerer_for_test.get_feature("sorcerer_innate_sorcery")
	_assert(innate_sorcery.get("type", "") == "active" and innate_sorcery.get("action_cost", "") == "bonus_action" and innate_sorcery.get("uses_per", "") == "combat", "Sorcerer Innate Sorcery is a curated combat bonus-action feature")
	var normal_sorcerer_dc := sorcerer_for_test.get_spell_save_dc()
	_assert(sorcerer_for_test.use_feature("sorcerer_innate_sorcery"), "Sorcerer Innate Sorcery spends its combat use")
	var innate_results := EventResolver.apply_effects(sorcerer_for_test, innate_sorcery.get("effects", []))
	_assert(innate_results.size() == 1 and sorcerer_for_test.has_condition("innate_sorcery") and sorcerer_for_test.get_spell_save_dc() == normal_sorcerer_dc + 1, "Innate Sorcery raises the Sorcerer's spell save DC while active")
	var innate_attack := sorcerer_for_test.make_attack_roll("CHA", sorcerer_for_test.has_condition("innate_sorcery"))
	_assert(innate_attack.get("advantage", false), "Innate Sorcery routes spell attacks through the shared advantage roll")
	sorcerer_for_test.level_up()
	var metamagic_target: Dictionary = _monster_inst("goblin")
	metamagic_target["armor_class"] = 0
	var empowered_cast := CombatAction.resolve_spell(sorcerer_for_test, metamagic_target, mm, false, {"metamagic:empowered": true})
	_assert(sorcerer_for_test.get_feature("sorcerer_metamagic").get("effects", [])[0].get("type", "") == "metamagic" and sorcerer_for_test.get_sorcery_points() == 1, "Sorcerer receives production Metamagic and spends one Sorcery Point")
	_assert(empowered_cast.get("success", false) and empowered_cast.get("metamagic_used", false), "Empowered Spell modifies a resolved spell through the shared spell boundary")
	sorcerer_for_test.long_rest()
	_assert(sorcerer_for_test.get_sorcery_points() == sorcerer_for_test.get_max_sorcery_points(), "Sorcery Points fully restore on a long rest")
	var short_rest_feature := {"id": "fixture_short_rest", "uses": 1, "uses_per": "short_rest"}
	caster2.features.append(short_rest_feature)
	caster2.feature_uses["fixture_short_rest"] = 0
	caster2.spell_slots = {"1": 0}
	caster2.short_rest()
	_assert(caster2.feature_uses["fixture_short_rest"] == 1, "short rest restores short-rest feature uses")
	_assert(caster2.spell_slots["1"] == 0, "short rest does not restore spell slots")
	caster2.current_hp = 1
	caster2.long_rest()
	_assert(caster2.current_hp == caster2.max_hp and caster2.spell_slots["1"] > 0, "long rest restores HP and spell slots")
	# Counterspell reaction: target with counterspell known interrupts
	var victim: Character = _fresh_char("Victim", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	victim.known_spells.append("counterspell")
	victim.spell_slots = {"3": 1}
	victim.reaction_available = true
	var caster3: Character = _fresh_char("Mage3", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	var res4: Dictionary = CombatAction.resolve_spell(caster3, victim, fb, false)
	_assert(not res4.get("success", true), "counterspell interrupts incoming spell")
	_assert("Counterspell" in res4.get("message", ""), "counterspell message present")
	victim.reaction_available = true
	victim.spell_slots["3"] = 1
	var declined_counterspell := CombatAction.resolve_spell(caster3, target, fb, false, {"counterspell:%s" % victim.character_name: false}, [victim])
	_assert(declined_counterspell.get("success", false) and victim.reaction_available and victim.spell_slots["3"] == 1, "declining an observer Counterspell preserves reaction and slot")
	victim.reaction_available = true
	victim.spell_slots["3"] = 1
	var accepted_counterspell := CombatAction.resolve_spell(caster3, target, fb, false, {"counterspell:%s" % victim.character_name: true}, [victim])
	_assert(not accepted_counterspell.get("success", true) and not victim.reaction_available and victim.spell_slots["3"] == 0, "an eligible observer can accept Counterspell against a monster target")

func _test_ai_controller() -> void:
	print("\n[Group] AIController")
	var grid: HexGrid = _build_grid(4)
	# aggressive: player far -> move towards / move_attack
	var mon_aggr := _monster_inst("goblin")
	mon_aggr["ai_behavior"] = "aggressive"
	mon_aggr["hex_position"] = Vector2i(3, 0)
	var pchar1: Character = _fresh_char("Hero", "human", "wizard", {"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	var players1 := [{"character": pchar1, "hex_position": Vector2i(-3, 0), "is_alive": true}]
	var d1: Dictionary = AIController.get_monster_action(mon_aggr, mon_aggr["hex_position"], grid, players1)
	_assert(d1["action"] in ["attack", "move", "move_attack", "none"], "aggressive action known (got '%s')" % d1.get("action",""))
	var c1 := AICommand.from_decision(d1, mon_aggr, players1, grid)
	_assert(c1 != null and c1.is_valid(mon_aggr, players1, grid), "AI decision crosses a validated combat command boundary")
	var bad_target := AICommand.from_decision({"action": "attack", "target_id": "NotAPlayer", "attack_idx": 0}, mon_aggr, players1, grid)
	_assert(bad_target == null, "AI command rejects a target outside the live party")
	var bad_attack := AICommand.from_decision({"action": "attack", "target_id": "Hero", "attack_idx": 99}, mon_aggr, players1, grid)
	_assert(bad_attack == null, "AI command rejects an unavailable monster attack")
	var bad_move := AICommand.from_decision({"action": "move", "move_to": Vector2i(-3, 0)}, mon_aggr, players1, grid)
	_assert(bad_move == null, "AI command rejects a non-adjacent movement shortcut")
	var lich := _monster_inst("lich_king")
	lich["hex_position"] = Vector2i(0, 0)
	var lich_players := [{"character": pchar1, "hex_position": Vector2i(3, 0), "is_alive": true}]
	var lich_decision := AIController.get_monster_action(lich, lich["hex_position"], grid, lich_players)
	_assert(lich_decision.get("action", "") == "cast_spell" and not str(lich_decision.get("spell_id", "")).is_empty(), "production Lich King AI chooses an available offensive spell")
	var lich_command := AICommand.from_decision(lich_decision, lich, lich_players, grid)
	_assert(lich_command != null and lich_command.spell_id() == lich_decision.get("spell_id", ""), "monster spell decision crosses the validated AI command boundary")
	var bad_spell := AICommand.from_decision({"action": "cast_spell", "target_id": "Hero", "spell_id": "not_a_spell"}, lich, lich_players, grid)
	_assert(bad_spell == null, "AI command rejects an unavailable monster spell")
	var spell_state := CombatState.new()
	var lich_caster: Character = spell_state._make_monster_spellcaster(lich)
	var spell_target: Character = _fresh_char("Lich Target", "human", "fighter", {"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	spell_target.base_ac = 0
	spell_target.max_hp = 100
	spell_target.current_hp = 100
	var monster_spell_result := CombatAction.resolve_spell(lich_caster, spell_target, DataLoader.get_spell(lich_command.spell_id()), true)
	_assert(monster_spell_result.get("success", false) and int(monster_spell_result.get("damage", 0)) > 0, "production Lich spell resolves through the shared CombatAction spell boundary")
	spell_state.free()
	if d1.has("move_to"):
		_assert(grid.has_tile(d1["move_to"]), "aggressive move_to is on grid")
	# defensive: player adjacent -> should move_attack away or attack
	var mon_def := _monster_inst("goblin")
	mon_def["ai_behavior"] = "defensive"
	mon_def["hex_position"] = Vector2i(0, 0)
	var pchar2: Character = _fresh_char("Hero2", "human", "wizard", {"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	var players2 := [{"character": pchar2, "hex_position": Vector2i(1, 0), "is_alive": true}]
	var d2: Dictionary = AIController.get_monster_action(mon_def, mon_def["hex_position"], grid, players2)
	_assert(d2["action"] in ["attack", "move", "move_attack", "none"], "defensive action known (got '%s')" % d2.get("action",""))
	if d2["action"] == "move_attack":
		_assert(grid.has_tile(d2["move_to"]), "defensive move_attack move_to is on grid")
	# support: currently implemented as aggressive fallback
	var mon_sup := _monster_inst("goblin")
	mon_sup["ai_behavior"] = "support"
	mon_sup["hex_position"] = Vector2i(3, 0)
	var d3: Dictionary = AIController.get_monster_action(mon_sup, mon_sup["hex_position"], grid, players1)
	_assert(d3["action"] in ["attack", "move", "move_attack", "none"], "support action known (got '%s')" % d3.get("action",""))
	# no players alive -> none
	var d4: Dictionary = AIController.get_monster_action(mon_aggr, mon_aggr["hex_position"], grid, [])
	_assert(d4["action"] == "none", "no alive players -> action 'none'")
	grid.free()

func _test_inventory() -> void:
	print("\n[Group] Inventory")
	var inv: Inventory = Inventory.new()
	_assert(inv.add_item("gold_100"), "add_item succeeds when not full")
	_assert(inv.has_item("gold_100"), "has_item true after add")
	_assert(inv.count_item("gold_100") == 1, "count_item returns 1")
	_assert(inv.remove_item("gold_100"), "remove_item succeeds")
	_assert(not inv.has_item("gold_100"), "has_item false after remove")
	# equip a real weapon
	var wpn: Dictionary = DataLoader.get_item("longsword")
	if not wpn.is_empty():
		inv.add_item("longsword")
		var prev: String = inv.equip(Inventory.Slot.WEAPON, "longsword")
		_assert(inv.get_weapon() == "longsword", "get_weapon returns equipped weapon")
		_assert(prev == "", "equip returns empty previous when slot was empty")
		_assert(not inv.can_equip(Inventory.Slot.WEAPON, "potion_healing"), "cannot equip a consumable as a weapon")
		_assert(inv.equip(Inventory.Slot.WEAPON, "potion_healing") == "" and inv.get_weapon() == "longsword", "invalid equip leaves equipment unchanged")
		inv.unequip(Inventory.Slot.WEAPON)
		_assert(inv.get_weapon() == "", "unequip clears weapon slot")
		var full_equip: Inventory = Inventory.new()
		full_equip.add_item("longsword")
		full_equip.equip(Inventory.Slot.WEAPON, "longsword")
		for i in Inventory.MAX_BACKPACK_SIZE:
			full_equip.add_item("gold_100")
		_assert(full_equip.unequip(Inventory.Slot.WEAPON) == "" and full_equip.get_weapon() == "longsword", "full backpack blocks unequip without dropping equipment")
	# backpack cap
	var inv2: Inventory = Inventory.new()
	for i in 20:
		inv2.add_item("gold_100")
	_assert(inv2.backpack.size() == 20, "backpack reaches max 20")
	_assert(not inv2.add_item("gold_100"), "add_item fails when backpack full")
	var consumer: Character = _fresh_char("Consumer", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 12, "INT": 10, "WIS": 10, "CHA": 10})
	consumer.take_damage(3)
	consumer.inventory.add_item("potion_healing")
	var hp_before_potion := consumer.current_hp
	var potion_result := consumer.inventory.consume("potion_healing", consumer)
	_assert(potion_result.get("success", false), "mechanics-backed healing potion can be consumed")
	_assert(consumer.current_hp > hp_before_potion and not consumer.inventory.has_item("potion_healing"), "consuming a potion heals and removes one inventory item")
	# ac bonus from equipped armor item with ac_bonus
	var bonus := 0
	var armor_inventory: Inventory = Inventory.new()
	for item_id in DataLoader.items.keys():
		var d: Dictionary = DataLoader.get_item(item_id)
		if d.get("type", "") == "armor" and int(d.get("ac_bonus", 0)) > 0:
			armor_inventory.add_item(item_id)
			armor_inventory.equip(Inventory.Slot.BODY, item_id)
			bonus = armor_inventory.calculate_ac_bonus()
			break
	_assert(typeof(bonus) == TYPE_INT and bonus >= 0, "calculate_ac_bonus returns int >= 0 (got %d)" % bonus)
	# round-trip
	var snap: Dictionary = inv2.to_dict()
	var inv3: Inventory = Inventory.new()
	inv3.from_dict(snap)
	_assert(inv3.gold == inv2.gold, "inventory gold survives round-trip")
	var equipment_inventory: Inventory = Inventory.new()
	for equipment_id in ["longsword", "chain_mail", "shield"]:
		_assert(equipment_inventory.add_item(equipment_id), "production equipment %s can enter the backpack" % equipment_id)
	equipment_inventory.equip(Inventory.Slot.WEAPON, "longsword")
	equipment_inventory.equip(Inventory.Slot.BODY, "chain_mail")
	equipment_inventory.equip(Inventory.Slot.SHIELD, "shield")
	var equipment_snapshot := equipment_inventory.to_dict()
	var equipment_restored: Inventory = Inventory.new()
	equipment_restored.from_dict(equipment_snapshot)
	_assert(equipment_restored.get_weapon() == "longsword" and equipment_restored.get_armor() == "chain_mail" and equipment_restored.get_equipped(Inventory.Slot.SHIELD) == "shield", "equipped weapon, armor, and shield survive inventory round-trip")
	var quest_inventory: Inventory = Inventory.new()
	_assert(quest_inventory.add_item("crown_fragment"), "Crown quest item enters the backpack")
	var quest_restored: Inventory = Inventory.new()
	quest_restored.from_dict(quest_inventory.to_dict())
	_assert(quest_restored.count_item("crown_fragment") == 1 and not quest_restored.can_equip(Inventory.Slot.WEAPON, "crown_fragment"), "Crown quest item persists without becoming equippable")

func _test_conditions() -> void:
	print("\n[Group] Conditions")
	var c: Character = _fresh_char("Cond", "human", "fighter",
		{"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	c.add_condition("poisoned", 3)
	_assert(c.has_condition("poisoned"), "condition active after add")
	c.tick_conditions()
	_assert(c.has_condition("poisoned"), "condition persists after one tick")
	c.tick_conditions()
	c.tick_conditions()
	_assert(not c.has_condition("poisoned"), "condition expires after duration elapses")
	c.add_condition("blessed", 1)
	c.tick_conditions()
	_assert(not c.has_condition("blessed"), "single-turn condition expires")
	c.add_condition("restrained", 4)
	c.add_condition("restrained", 1)
	_assert(int(c.conditions.get("restrained", 0)) == 4, "reapplying a condition cannot shorten its remaining duration")
	c.add_condition("restrained", 6)
	_assert(int(c.conditions.get("restrained", 0)) == 6, "reapplying a condition can refresh it to a longer duration")
	# blinded grants disadvantage path inside make_attack_roll (smoke)
	c.add_condition("blinded", 5)
	var roll: Dictionary = c.make_attack_roll("STR")
	_assert(roll.has("total"), "attack roll still produced while blinded")
	var temp_result := EventResolver.apply_effects(c, [{"type": "temporary_hp", "value": "5"}])
	_assert(c.temp_hp == 5 and temp_result[0].get("type", "") == "temporary_hp", "temporary HP effect is typed and applied")
	c.feature_uses["fighter_second_wind"] = 1
	var spend_result := EventResolver.apply_effects(c, [{"type": "spend_resource", "resource_id": "fighter_second_wind"}])
	_assert(c.feature_uses["fighter_second_wind"] == 0 and spend_result[0].get("success", false), "resource spend effect consumes a named feature use")
	var restore_result := EventResolver.apply_effects(c, [{"type": "restore_resource", "resource_id": "fighter_second_wind"}])
	_assert(c.feature_uses["fighter_second_wind"] == 1 and restore_result[0].get("success", false), "resource restore effect respects the feature maximum")
	var concentration_result := EventResolver.apply_effects(c, [{"type": "set_concentration", "spell_id": "bless", "targets": []}])
	_assert(not c.concentrating_on.is_empty() and concentration_result[0].get("type", "") == "concentration", "concentration effect records an owned spell link")
	var modifier_results := EventResolver.apply_effects(c, [
		{"type": "ac_bonus", "value": 2, "duration": 2},
		{"type": "roll_modifier", "key": "attack", "amount": 3, "duration": 1},
		{"type": "movement", "value": 2, "duration": 1},
	])
	_assert(modifier_results.size() == 3 and c.get_ac() == c.base_ac + 2, "typed AC, roll, and movement modifiers apply through one effect vocabulary")
	_assert(c.get_modifier("roll", "attack") == 3 and c.get_modifier("stat", "speed") == 2, "numeric modifiers are queryable by domain key")
	c.tick_conditions()
	_assert(c.get_modifier("roll", "attack") == 0 and c.get_modifier("stat", "speed") == 0 and c.get_modifier("stat", "AC") == 2, "numeric modifiers expire on their declared turn")
	var slowed_monster := _monster_inst("goblin")
	slowed_monster["speed"] = 4
	slowed_monster["speed_before_spell_slow"] = 6
	slowed_monster["conditions"] = {"speed_reduced": 1}
	CombatState.tick_monster_condition_durations(slowed_monster)
	_assert(not slowed_monster["conditions"].has("speed_reduced") and int(slowed_monster["speed"]) == 6 and not slowed_monster.has("speed_before_spell_slow"), "monster spell slow expires on its turn and restores the prior speed")

func _test_character_serialization() -> void:
	print("\n[Group] Character serialization")
	var c: Character = _fresh_char("Hero", "human", "wizard",
		{"STR":8,"DEX":14,"CON":14,"INT":16,"WIS":12,"CHA":10})
	c.current_hp = 5
	c.inventory.add_item("gold_100")
	var d: Dictionary = c.to_dict()
	var c2: Character = Character.new()
	c2.from_dict(d)
	_assert(c2.character_name == "Hero", "name survives round-trip")
	_assert(c2.race_id == "human", "race survives round-trip")
	_assert(c2.class_id == "wizard", "class survives round-trip")
	_assert(c2.max_hp == c.max_hp, "max_hp survives round-trip")
	_assert(c2.current_hp == 5, "current_hp survives round-trip")
	_assert(c2.level == 1, "level survives round-trip")
	_assert(c2.inventory.has_item("gold_100"), "inventory item survives round-trip")
	_assert(c2.ability_scores.get_ability_modifier("INT") == c.ability_scores.get_ability_modifier("INT"), "ability mod survives round-trip")

func _test_player_manager() -> void:
	print("\n[Group] PlayerManager")
	PlayerManager.reset()
	var i0 := PlayerManager.add_player("A")
	var i1 := PlayerManager.add_player("B")
	_assert(i0 == 0 and i1 == 1, "add_player returns sequential indices")
	_assert(PlayerManager.get_player_count() == 2, "player count is 2")
	PlayerManager.start_game()
	_assert(PlayerManager.active_player_index == 0, "start_game sets active to 0")
	PlayerManager.next_turn()  # -> 1
	_assert(PlayerManager.active_player_index == 1, "next_turn advances to player 1")
	var nr := PlayerManager.next_turn()  # -> 0, new round
	_assert(PlayerManager.active_player_index == 0, "next_turn wraps to player 0")
	_assert(nr, "wrapping to first player starts a new round")
	_assert(PlayerManager.current_round == 2, "round incremented on wrap")
	var reconnect_session := str(PlayerManager.get_player(1).get("session_id", ""))
	var reconnect_position := PlayerManager.get_player_position(1)
	_assert(PlayerManager.disconnect_player(reconnect_session), "disconnect marks a known seat unavailable")
	_assert(not PlayerManager.is_player_connected(1), "disconnected seat is not treated as connected")
	_assert(PlayerManager.next_turn() == false or PlayerManager.active_player_index != 1, "turn rotation skips a disconnected seat")
	_assert(PlayerManager.reconnect_player(reconnect_session) == 1, "reconnect restores the stable seat index")
	_assert(PlayerManager.is_player_connected(1) and PlayerManager.get_player_position(1) == reconnect_position, "reconnect preserves seat state")
	_assert(PlayerManager.bind_device_to_session(reconnect_session, 7), "controller binds to an existing stable seat")
	_assert(PlayerManager.get_player_index_for_device(7) == 1, "physical device resolves to its stable seat")
	_assert(not PlayerManager.bind_device_to_session(str(PlayerManager.get_player(0).get("session_id", "")), 7), "one controller cannot silently steal another seat")
	PlayerManager._on_joy_connection_changed(7, false)
	_assert(not PlayerManager.is_player_connected(1) and PlayerManager.get_player(1).get("device_id") == PlayerManager.UNBOUND_DEVICE_ID, "physical disconnect keeps the seat but clears its transient device")
	_assert(PlayerManager.get_input_status(1) == "Press Start to rebind", "disconnected controller seat exposes a rebind prompt")
	PlayerManager._on_joy_connection_changed(7, true)
	_assert(PlayerManager.is_player_connected(1) and PlayerManager.get_player_index_for_device(7) == 1, "same-session reconnect reclaims the original seat")
	# serialize / deserialize with real characters
	PlayerManager.reset()
	PlayerManager.add_player("Alice")
	PlayerManager.add_player("Bob")
	var ca: Character = _fresh_char("Alice", "human", "fighter", {"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var cb: Character = _fresh_char("Bob", "elf", "wizard", {"STR":8,"DEX":14,"CON":14,"INT":16,"WIS":12,"CHA":10})
	PlayerManager.set_player_character(0, ca)
	PlayerManager.set_player_character(1, cb)
	PlayerManager.set_player_position(0, Vector2i(2, 0))
	var bob_session := str(PlayerManager.get_player(1).get("session_id", ""))
	_assert(PlayerManager.bind_device_to_session(bob_session, 7), "controller-mode seat can be prepared for save/load proof")
	var snap: Array = PlayerManager.serialize()
	var snap_text := JSON.stringify(snap)
	_assert(not snap_text.contains("device_id"), "player save DTO excludes physical device IDs")
	PlayerManager.reset()
	PlayerManager.deserialize(snap)
	_assert(PlayerManager.get_player_count() == 2, "player count survives serialize")
	_assert(PlayerManager.get_player(0)["name"] == "Alice", "player name survives serialize")
	_assert(PlayerManager.get_player(0)["character"].character_name == "Alice", "character survives serialize")
	_assert(PlayerManager.get_player_position(0) == Vector2i(2, 0), "player position survives serialize")
	_assert(PlayerManager.is_player_connected(0), "shared-control seat remains available after load")
	_assert(not PlayerManager.is_player_connected(1) and PlayerManager.get_player(1).get("device_id") == PlayerManager.UNBOUND_DEVICE_ID, "controller seat requires a fresh physical binding after load")
	_assert(PlayerManager.get_player(1).get("character").character_name == "Bob", "post-load rebind boundary preserves seat character ownership")
	_assert(PlayerManager.request_device_join(9, bob_session) == 1, "post-load Start join rebinds the requested stable seat")
	_assert(PlayerManager.get_player_index_for_device(9) == 1 and PlayerManager.is_player_connected(1), "post-load device binding restores the exact seat")
	# party wiped detection
	PlayerManager.reset()
	_assert(not PlayerManager.is_party_wiped(), "empty roster is not a wipe")
	PlayerManager.add_player("Dead")
	var dead: Character = _fresh_char("Dead", "human", "fighter", {"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	dead.current_hp = 0
	dead.is_alive = false
	PlayerManager.set_player_character(0, dead)
	_assert(PlayerManager.is_party_wiped(), "all-dead party reports wiped")


func _test_party_manager() -> void:
	print("\n[Group] PartyManager")
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Solo")
	PlayerManager.add_player("Co-op")
	var hero: Character = _fresh_char("Solo Hero", "human", "fighter", {"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	PlayerManager.set_player_character(0, hero)
	_assert(PartyManager.register_player_character(0, hero), "player character registers into stable party slot")
	_assert(PartyManager.get_active_characters().size() == 1, "active party starts with one character")
	_assert(PartyManager.has_valid_formation(1, PartyManager.get_formation_positions(1)), "single-member formation is valid")
	var campaign: Dictionary = DataLoader.get_campaign("the_lost_crown")
	PartyManager.initialize_campaign_companions(campaign.get("companions", {}))
	_assert(PartyManager.get_available_companions().size() == 3, "campaign exposes three available companions")
	_assert(PartyManager.recruit_companion("aldric"), "companion fills an empty party slot")
	_assert(PartyManager.get_active_characters().size() == 2, "recruited companion is active")
	_assert(PartyManager.assign_slot_to_seat("slot_1", 1), "companion ownership can move to another local seat")
	_assert(PlayerManager.get_player_for_party_slot("slot_1") == 1, "reassigned companion reports the new owner seat")
	_assert(not PartyManager.assign_slot_to_seat("slot_0", 1), "player character ownership cannot be reassigned as a companion")
	_assert(PartyManager.has_valid_formation(4, PartyManager.get_formation_positions(4)), "full party formation has distinct spawn positions")
	_assert(PartyManager.set_leader("slot_0"), "occupied party slot can lead exploration")
	PartyManager.move_exploration_party(Vector2i(2, 1))
	_assert(PlayerManager.get_player_position(0) == Vector2i(2, 1), "leader movement updates the exploration party")
	var party_snapshot: Dictionary = PartyManager.serialize()
	var snapshot_text := JSON.stringify(party_snapshot)
	_assert(not snapshot_text.contains("<RefCounted") and not snapshot_text.contains("Object"), "party snapshot contains DTOs only")
	PartyManager.reset()
	PlayerManager.reset()


func _test_campaign_contracts() -> void:
	print("\n[Group] Campaign contracts")
	var campaign: Dictionary = DataLoader.get_campaign("the_lost_crown")
	GameManager.active_campaign = campaign
	GameManager.game_in_progress = true
	for player_count in range(1, PlayerManager.MAX_PLAYERS + 1):
		PlayerManager.reset()
		PartyManager.reset()
		for index in player_count:
			PlayerManager.add_player("Seat %d" % (index + 1))
			var character := _fresh_char("Hero %d" % (index + 1), "human", "fighter", {"STR":15,"DEX":14,"CON":13,"INT":10,"WIS":10,"CHA":8})
			PlayerManager.set_player_character(index, character)
			_assert(PartyManager.register_player_character(index, character), "player %d registers for %d-player campaign" % [index + 1, player_count])
		PartyManager.initialize_campaign_companions(campaign.get("companions", {}))
		for companion_id in PartyManager.get_available_companions():
			if PartyManager.get_active_characters().size() >= PartyManager.MAX_PARTY_SIZE:
				break
			_assert(PartyManager.recruit_companion(companion_id), "companion fills open slot for %d-player campaign" % player_count)
		_assert(PartyManager.get_active_characters().size() == PartyManager.MAX_PARTY_SIZE, "%d-player campaign reaches a full active party" % player_count)
		for slot in PartyManager.party_slots:
			if bool(slot.get("occupied", false)):
				_assert(PlayerManager.get_player_for_party_slot(slot.get("slot_id", "")) >= 0, "occupied slot has a local owner")
	# The objective API counts party-wide quest items and defeated bosses.
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Solo")
	var hero := _fresh_char("Crown Bearer", "human", "fighter", {"STR":15,"DEX":14,"CON":13,"INT":10,"WIS":10,"CHA":8})
	PlayerManager.set_player_character(0, hero)
	PartyManager.register_player_character(0, hero)
	var objective_lines := GameManager.get_campaign_objectives()
	_assert(objective_lines.size() >= 2 and objective_lines[0].contains("Crown"), "campaign objective exposes quest progress")
	for index in 3:
		hero.inventory.add_item("crown_fragment")
	GameManager.defeated_monsters.assign(["lich_king"])
	_assert(GameManager.are_win_conditions_met(), "campaign goals complete from party inventory and defeat ledger")
	GameManager.game_in_progress = false
	GameManager.active_campaign = {}
	PartyManager.reset()
	PlayerManager.reset()

func _test_event_system() -> void:
	print("\n[Group] EventSystem")
	var known_ids := ["trapped_chest", "undead_ambush", "mysterious_fountain", "cave_in", "ghostly_warning", "treasure_room", "ooze_encounter"]
	var all_known := true
	for i in 200:
		var ev: Dictionary = EventSystem.roll_event("dungeon_events")
		if ev.is_empty() or ev.get("id", "") not in known_ids:
			all_known = false
			break
	_assert(all_known, "roll_event always returns a valid dungeon event over 200 rolls")
	var one: Dictionary = EventSystem.roll_event("dungeon_events")
	_assert(one.has("id") and one.has("weight"), "event has id + weight fields")
	# missing table -> empty dict
	_assert(EventSystem.roll_event("does_not_exist").is_empty(), "unknown table returns empty dict")
	# trigger via tile with explicit event_table_id
	var tile: HexTile = HexTile.new()
	tile.coord = Vector2i.ZERO
	tile.event_table_id = "dungeon_events"
	var tev: Dictionary = EventSystem.trigger_event_for_tile(tile)
	_assert(not tev.is_empty(), "trigger_event_for_tile returns an event")
	# terrain lookup requires an active campaign set
	var camp: Dictionary = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	var tile2: HexTile = HexTile.new()
	tile2.coord = Vector2i.ZERO
	tile2.terrain = HexTile.TerrainType.DUNGEON_ENTRANCE
	var tid := EventSystem.get_table_for_terrain("dungeon")
	# not asserting specific value (campaign-dependent) but that it returns a string
	_assert(typeof(tid) == TYPE_STRING, "get_table_for_terrain returns a string")

func _test_fog_of_war() -> void:
	print("\n[Group] FogOfWar")
	PlayerManager.reset()
	PlayerManager.add_player("Scout")
	var scout: Character = _fresh_char("Scout", "human", "ranger",
		{"STR":12,"DEX":16,"CON":14,"INT":10,"WIS":14,"CHA":10})
	PlayerManager.set_player_character(0, scout)
	PlayerManager.set_player_position(0, Vector2i.ZERO)
	var grid: HexGrid = _build_grid(2)
	FogOfWar.update_visibility(grid)
	var center: HexTile = grid.get_tile(Vector2i.ZERO)
	_assert(center != null and center.is_visible, "tile under player is visible")
	# tile within default vision radius (2) is revealed
	var near: HexTile = grid.get_tile(Vector2i(0, 1))
	_assert(near != null and near.is_revealed, "tile within radius 2 is revealed")
	# tile at radius 3 does not exist in this grid; build bigger to test exclusion
	var grid2: HexGrid = _build_grid(3)
	FogOfWar.update_visibility(grid2)
	var far: HexTile = grid2.get_tile(Vector2i(3, 0))
	_assert(far != null, "far tile exists in radius-3 grid")
	# visibility resets each call; a tile outside vision should not be visible
	var far_visible := far.is_visible
	# radius 2 vision from origin cannot reach (3,0) (distance 3)
	_assert(not far_visible, "tile beyond vision radius is not visible")
	grid.free()
	grid2.free()

func _test_hexutils() -> void:
	print("\n[Group] HexUtils")
	_assert(HexUtils.get_distance(Vector2i.ZERO, Vector2i(3, 0)) == 3, "distance (0,0)->(3,0) == 3")
	_assert(HexUtils.get_distance(Vector2i.ZERO, Vector2i.ZERO) == 0, "distance to self == 0")
	var nb: Array[Vector2i] = HexUtils.get_neighbors(Vector2i.ZERO)
	_assert(nb.size() == 6, "a hex has 6 neighbors")
	var ring: Array[Vector2i] = HexUtils.get_hex_ring(Vector2i.ZERO, 2)
	_assert(ring.size() == 12, "hex ring radius 2 has 12 tiles (got %d)" % ring.size())
	var inrange: Array[Vector2i] = HexUtils.get_hexes_in_range(Vector2i.ZERO, 1)
	_assert(inrange.size() == 7, "hexes within radius 1 == 7 (center + 6)")
	# pixel round-trip
	var pix: Vector2 = HexUtils.hex_to_pixel(Vector2i(4, -2))
	var back: Vector2i = HexUtils.pixel_to_hex(pix)
	_assert(back == Vector2i(4, -2), "hex->pixel->hex round trips")
	# line of sight: straight line, no blockers -> true
	var los := HexUtils.has_line_of_sight(Vector2i.ZERO, Vector2i(3, 0), func(h: Vector2i) -> bool: return false)
	_assert(los, "clear line of sight returns true")
	var los_blocked := HexUtils.has_line_of_sight(Vector2i.ZERO, Vector2i(3, 0), func(h: Vector2i) -> bool: return h == Vector2i(1, 0))
	_assert(not los_blocked, "blocked intermediate hex breaks line of sight")
	# static A* pathfinding
	var path: Array[Vector2i] = HexUtils.find_path(Vector2i.ZERO, Vector2i(3, 0),
		func(h: Vector2i) -> bool: return true, func(h: Vector2i) -> float: return 1.0, 100)
	_assert(path.size() >= 2 and path[0] == Vector2i.ZERO and path[-1] == Vector2i(3, 0), "static find_path endpoints correct")

func _test_save_load() -> void:
	print("\n[Group] Save/Load")
	# Set up minimal game-in-progress state
	var camp: Dictionary = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	PlayerManager.reset()
	PlayerManager.add_player("Sava")
	var sc: Character = _fresh_char("Sava", "human", "fighter", {"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	PlayerManager.set_player_character(0, sc)
	PartyManager.sync_from_player_manager()
	var slot := "rook_test_slot"
	# clean any prior
	SaveManager.delete_save(slot)
	var saved := SaveManager.save_game(slot)
	_assert(saved, "save_game returns true when game in progress")
	var saved_file := FileAccess.open("user://saves/%s.sav" % slot, FileAccess.READ)
	var saved_json := JSON.new()
	var saved_parse := saved_json.parse(saved_file.get_as_text()) if saved_file != null else ERR_FILE_NOT_FOUND
	if saved_file != null: saved_file.close()
	var saved_dto: Dictionary = saved_json.data if saved_parse == OK and saved_json.data is Dictionary else {}
	_assert(SaveManager._validate_save_data(saved_dto).is_empty(), "saved party DTO passes structural validation")
	var backup_text := FileAccess.get_file_as_string("user://saves/%s.sav" % slot)
	var backup_file := FileAccess.open("user://saves/%s.sav.bak" % slot, FileAccess.WRITE)
	if backup_file != null:
		backup_file.store_string(backup_text)
		backup_file.close()
	var interrupted_file := FileAccess.open("user://saves/%s.sav" % slot, FileAccess.WRITE)
	if interrupted_file != null:
		interrupted_file.store_string("{\"schema_version\":")
		interrupted_file.close()
	GameManager.test_mode = true
	_assert(SaveManager.load_game(slot), "interrupted primary save falls back to the last committed backup")
	_assert(GameManager.current_state == GameManager.GameState.OVERWORLD, "backup recovery restores a resumable state")
	_assert(slot in SaveManager.get_available_saves(), "backup-only recovery keeps the save slot discoverable")
	var fixture_file := FileAccess.open("res://data/fixtures/save_v1_compat.json", FileAccess.READ)
	var fixture_json := JSON.new()
	var fixture_parse := fixture_json.parse(fixture_file.get_as_text()) if fixture_file != null else ERR_FILE_NOT_FOUND
	if fixture_file != null: fixture_file.close()
	var fixture_dto: Dictionary = fixture_json.data if fixture_parse == OK and fixture_json.data is Dictionary else {}
	_assert(SaveManager._validate_save_data(fixture_dto).is_empty(), "repository save v1 compatibility fixture passes validation")
	var invalid_party := saved_dto.duplicate(true)
	invalid_party["party"]["party_slots"][0]["character_id"] = "missing_character"
	_assert(not SaveManager._validate_save_data(invalid_party).is_empty(), "save validation rejects a missing party character reference")
	var invalid_slot := "rook_invalid_fixture"
	var invalid_file := FileAccess.open("user://saves/%s.sav" % invalid_slot, FileAccess.WRITE)
	if invalid_file != null:
		invalid_file.store_string(JSON.stringify({"schema_version": 999, "campaign_id": "the_lost_crown"}))
		invalid_file.close()
	var state_before_invalid := GameManager.current_state
	_assert(not SaveManager.load_game(invalid_slot), "corrupt or unsupported save is rejected")
	_assert(GameManager.current_state == state_before_invalid and GameManager.active_campaign.get("id", "") == camp.get("id", ""), "rejected save leaves active session unchanged")
	SaveManager.delete_save(invalid_slot)
	var saves: Array[String] = SaveManager.get_available_saves()
	_assert(slot in saves, "saved slot appears in available saves")
	GameManager.current_state = GameManager.GameState.COMBAT
	_assert(not SaveManager.save_game(slot), "combat save is rejected by the safe-save policy")
	GameManager.current_state = GameManager.GameState.DUNGEON
	var room := Room.new()
	room.id = 0
	room.coord = Vector2i.ZERO
	room.type = Room.RoomType.ENTRANCE
	room.is_visited = true
	GameManager.active_dungeon_state = {
		"dungeon_id": "ruins_of_ashvale",
		"rooms": {Vector2i.ZERO: room},
		"party_position": Vector2i.ZERO,
		"save_checkpoint": true,
	}
	GameManager.completed_milestones.assign(["enter_dungeon_1"])
	GameManager.cleared_dungeons.assign(["ruins_of_ashvale"])
	_assert(SaveManager.save_game(slot), "dungeon-entry checkpoint save is accepted")
	var save_file := FileAccess.open("user://saves/%s.sav" % slot, FileAccess.READ)
	var save_text := save_file.get_as_text() if save_file != null else ""
	if save_file != null: save_file.close()
	_assert(not save_text.contains("<RefCounted") and not save_text.contains("Vector2i"), "save contains plain DTO data only")
	GameManager.test_mode = true
	_assert(SaveManager.load_game(slot), "versioned save loads transactionally in test mode")
	_assert("enter_dungeon_1" in GameManager.completed_milestones and "ruins_of_ashvale" in GameManager.cleared_dungeons, "campaign ledgers survive round-trip")
	GameManager.claimed_rewards.assign(["ruins_of_ashvale_fragment"])
	_assert(SaveManager.save_game(slot), "second save accepts progressed checkpoint state")
	GameManager.claimed_rewards.clear()
	_assert(SaveManager.load_game(slot), "second load accepts progressed checkpoint state")
	_assert("ruins_of_ashvale_fragment" in GameManager.claimed_rewards, "progressed reward ledger survives a second round-trip")
	GameManager.test_mode = false
	var deleted := SaveManager.delete_save(slot)
	_assert(deleted, "delete_save returns true for existing slot")
	var saves2: Array[String] = SaveManager.get_available_saves()
	_assert(slot not in saves2, "slot gone after delete")
	GameManager.game_in_progress = false


func _test_dungeon_lifecycle() -> void:
	print("\n[Group] Dungeon lifecycle")
	var dungeon := DungeonState.new()
	dungeon.dungeon_id = "ruins_of_ashvale"
	var boss := Room.new()
	boss.id = 4
	boss.coord = Vector2i(0, 4)
	boss.type = Room.RoomType.BOSS
	boss.monster_ids = ["goblin_chief"]
	dungeon.rooms = {boss.coord: boss}
	dungeon._begin_room_combat(boss)
	_assert(dungeon.pending_combat_room_id == boss.id, "dungeon records the pending combat room")
	_assert(not boss.is_cleared and not dungeon.boss_defeated, "entering a boss room does not pre-clear it")
	_assert(int(GameManager.active_dungeon_state.get("pending_combat_room_id", -1)) == boss.id, "pending combat room is included in active dungeon state")
	var interrupted_state := SaveManager._serialize_dungeon_state(GameManager.active_dungeon_state)
	_assert(int(interrupted_state.get("pending_combat_room_id", -1)) == boss.id, "pending combat room survives save DTO serialization")
	var failed_result := dungeon.pending_combat_room_id
	_assert(failed_result == boss.id and not boss.is_cleared, "defeat leaves the unresolved room replayable")
	var completed := dungeon._complete_pending_combat()
	_assert(completed == boss and boss.is_cleared, "combat victory clears the resolved room")
	_assert(dungeon.boss_defeated and dungeon.pending_combat_room_id == -1, "boss victory advances dungeon completion state")
	_assert(int(GameManager.active_dungeon_state.get("pending_combat_room_id", -1)) == -1, "completed combat clears the pending room from active state")
	dungeon.free()

func _test_widgets() -> void:
	print("\n[Group] UI Widgets")
	# LogPanel: severity-aware RichTextLabel wrapper, backwards-compatible with
	# the BaseHUD log_text contract (.text still holds the rendered log).
	var lp: LogPanel = LogPanel.new()
	add_child(lp)
	_assert(lp is RichTextLabel, "LogPanel is a RichTextLabel (HUD log_text contract survives)")
	lp.clear_logs()
	lp.log_info("scout moved")
	lp.log_danger("trap! 3 dmg")
	lp.add_log("legacy call still works")
	_assert(lp.text.contains("scout moved"), "LogPanel log_info appends text")
	_assert(lp.text.contains("trap! 3 dmg"), "LogPanel log_danger appends text")
	_assert(lp.text.contains("legacy call still works"), "LogPanel add_log shim works")
	lp.clear_logs()
	_assert(lp.text == "", "LogPanel clear_logs empties the log")
	lp.free()
	# ActionBar: consistent icon+label action row (icon optional).
	var bar: ActionBar = ActionBar.new()
	add_child(bar)
	_assert(bar is HBoxContainer, "ActionBar is an HBoxContainer")
	var rest_btn: Button = bar.add_action("rest", "Rest", null, func(): pass)
	_assert(rest_btn != null and rest_btn.text == "Rest", "ActionBar.add_action creates a labeled button")
	_assert(rest_btn.name == "Action_rest", "ActionBar button named Action_<id>")
	bar.push_right()
	var sheet_btn: Button = bar.add_action("sheet", "Sheet")
	_assert(sheet_btn != null, "ActionBar.add_action works icon-less (no art required)")
	var fired_state := {"id": ""}
	bar.action_pressed.connect(func(id: String): fired_state.id = id)
	bar.trigger("sheet")
	_assert(fired_state.id == "sheet", "ActionBar.trigger emits action_pressed with the action id")
	bar.clear_actions()
	_assert(bar.get_child_count() == 0, "ActionBar.clear_actions removes buttons")
	bar.free()
