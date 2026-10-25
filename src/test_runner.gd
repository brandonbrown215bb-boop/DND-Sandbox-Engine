## Test Runner (scene-based)
## Runs inside the normal project boot, so autoloads (DataLoader, Dice,
## PlayerManager, GameManager, SaveManager) and class_name globals (Character,
## CombatAction, HexGrid, ...) are all live. Exercises the real combat, grid,
## AI, spell, inventory, event, fog-of-war and persistence code paths.
extends Node

var _passed := 0
var _failed := 0
var _failures: Array[String] = []
var _logic_groups: Array[String] = []
var _script_errors := ScriptErrorCounter.new()

func _ready() -> void:
	print("==================================================")
	print(" Rook's In-Engine Test Harness (scene runner)")
	print("==================================================")
	OS.add_logger(_script_errors) # Review cafa R1.
	for argument in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if argument.begins_with("--logic-groups="):
			for group in argument.trim_prefix("--logic-groups=").split(",", false):
				_logic_groups.append(group)
			if _logic_groups.is_empty():
				_assert(false, "logic group selection cannot be empty")
	var valid_groups := ["all", "data", "spells", "effects", "barbarian", "bard", "cleric", "combat", "conditions", "classes", "persistence", "world", "ui", "check_context"]
	for group in _logic_groups:
		if group not in valid_groups:
			_assert(false, "unknown logic group: %s" % group)
	if _failed > 0:
		_report()
		get_tree().quit(1)
		return
	print("LOGIC GROUPS: %s" % (", ".join(_logic_groups) if not _logic_groups.is_empty() else "all"))
	# Card cafa: a registered check file that fails to load or parse turns the run red.
	var registered_scripts := CheckScriptGate.load_registered("res://src/test_runner.gd")
	for failure in CheckScriptGate.failures(registered_scripts):
		_assert(false, failure)
	print("CHECK SCRIPT GATE: %d registered check scripts, %d failed" % [registered_scripts.size(), CheckScriptGate.failures(registered_scripts).size()])
	_test_check_script_gate()
	_run_group("data", _test_data_loader)
	_run_group("classes", _test_character_creation)
	_run_group("classes", _test_paladin_divine_sense_2024)
	_run_group("classes", _test_paladin_abjure_foes_2024)
	_run_group("classes", _test_monk_2024)
	_run_group("classes", _test_fighter_second_wind_2024)
	_run_group("classes", func(): FighterChecks.run(_assert))
	_run_group("combat", _test_dice_parser)
	_run_group("combat", _test_combat_action)
	_run_group("combat", func(): PlaytestFixChecks.weapon_damage(_assert))
	_run_group("combat", func(): PlaytestFixChecks.phase_one_wiring(_assert))
	_run_group("combat", func(): Batch031Checks.run(_assert))
	_run_group("combat", func(): Batch032Checks.run(_assert))
	_run_group("combat", func(): Batch033Checks.run(_assert))
	_run_group("combat", func(): Batch034Checks.run(_assert))
	_run_group("combat", func(): Batch035Checks.run(_assert))
	_run_group("combat", func(): Batch036Checks.run(_assert))
	_run_group("effects", func(): LocatedSourceEndChecks.run(_assert))
	_run_group("combat", func(): Batch037Checks.run(_assert))
	_run_group("combat", func(): Batch038Checks.run(_assert))
	_run_group("combat", func(): Batch039Checks.run(_assert))
	_run_group("combat", func(): Batch040Checks.run(_assert))
	_run_group("combat", func(): Batch041Checks.run(_assert))
	_run_group("combat", func(): FormEquipmentGroundChecks.run(_assert))
	_run_group("combat", func(): Batch042Checks.run(_assert))
	_run_group("combat", func(): ItemFormReturnChecks.run(_assert))
	_run_group("combat", func(): Batch043Checks.run(_assert))
	_run_group("combat", func(): Batch044Checks.run(_assert))
	_run_group("combat", func(): Batch045Checks.run(_assert))
	_run_group("combat", func(): Batch046Checks.run(_assert))
	_run_group("combat", func(): TetherGroupChecks.run(_assert))
	_run_group("combat", func(): Batch047Checks.run(_assert))
	_run_group("combat", func(): Batch048Checks.run(_assert))
	_run_group("combat", func(): Batch049Checks.run(_assert))
	_run_group("combat", func(): Batch050Checks.run(_assert))
	_run_group("combat", func(): Batch051Checks.run(_assert))
	_run_group("combat", func(): Batch052Checks.run(_assert))
	_run_group("combat", func(): Batch053Checks.run(_assert))
	_run_group("combat", func(): Batch054Checks.run(_assert))
	_run_group("combat", func(): Batch058Checks.run(_assert))
	_run_group("combat", func(): Batch059Checks.run(_assert))
	_run_group("combat", func(): Batch060Checks.run(_assert))
	_run_group("combat", func(): Batch061Checks.run(_assert))
	_run_group("combat", func(): Batch062Checks.run(_assert))
	_run_group("combat", func(): Batch063Checks.run(_assert))
	_run_group("combat", func(): Batch064Checks.run(_assert))
	_run_group("combat", func(): Batch065Checks.run(_assert))
	_run_group("combat", func(): Batch066TravelChecks.run(_assert))
	_run_group("combat", func(): Batch067Checks.run(_assert))
	_run_group("combat", func(): Batch068Checks.run(_assert))
	_run_group("combat", func(): Batch069Checks.run(_assert))
	_run_group("combat", func(): Batch055Checks.run(_assert))
	_run_group("combat", func(): Batch056Checks.run(_assert))
	_run_group("combat", func(): CreatedActorSchedulingChecks.run(_assert))
	_run_group("combat", func(): SharedInitiativeChecks.run(_assert))
	_run_group("combat", func(): Batch057Checks.run(_assert))
	_run_group("combat", func(): Review053065Checks.run(_assert))
	_run_group("combat", func(): Review052Checks.run(_assert))
	_run_group("combat", func(): Review051Checks.run(_assert))
	_run_group("combat", func(): Review050Checks.run(_assert))
	_run_group("combat", func(): Review050FChecks.run(_assert))
	_run_group("combat", func(): StackRepairChecks.run(_assert))
	_run_group("combat", _test_player_commands)
	_run_group("combat", _test_initiative)
	_run_group("spells", _test_spellcasting)
	_run_group("spells", func(): SpellPermissionChecks.run(_assert))
	_run_group("spells", func(): SpellSlotChecks.run(_assert))
	_run_group("spells", func(): SharedSpellChecks.run(_assert))
	_run_group("spells", func(): TrueStrikeChecks.run(_assert))
	_run_group("spells", func(): MassCureWoundsChecks.run(_assert))
	_run_group("spells", func(): MassHealingWordChecks.run(_assert))
	_run_group("spells", func(): ConversionBatch001Checks.run(_assert))
	_run_group("spells", func(): ConversionBatch002Checks.run(_assert))
	_run_group("spells", func(): BlindnessDeafnessChecks.run(_assert))
	_run_group("spells", _test_grease_spell)
	_run_group("spells", _test_spike_growth_spell)
	_run_group("spells", _test_entangle_spell)
	_run_group("spells", _test_black_tentacles_spell)
	_run_group("spells", _test_sleet_storm_spell)
	_run_group("spells", _test_cloud_of_daggers_spell)
	_run_group("spells", _test_cloudkill_spell)
	_run_group("spells", _test_conjure_animals_spell)
	_run_group("spells", _test_conjure_celestial_spell)
	_run_group("spells", _test_conjure_elemental_spell)
	_run_group("spells", _test_conjure_fey_spell)
	_run_group("spells", _test_conjure_minor_elementals_spell)
	_run_group("spells", _test_conjure_woodland_beings_spell)
	_run_group("spells", _test_spirit_guardians_spell)
	_run_group("spells", _test_aura_of_life_spell)
	_run_group("spells", _test_moonbeam_spell)
	_run_group("spells", _test_plant_growth_spell)
	_run_group("spells", _test_barkskin_spell)
	_run_group("spells", _test_mage_armor_spell)
	_run_group("effects", func(): SpellEffectChecks.run(_assert))
	_run_group("effects", func(): Batch026Checks.run(_assert))
	_run_group("effects", func(): SpellZoneChecks.run(_assert))
	_run_group("barbarian", func(): BarbarianChecks.run(_assert))
	_run_group("bard", func(): BardChecks.run(_assert))
	_run_group("cleric", func(): ClericChecks.run(_assert))
	_run_group("combat", _test_ai_controller)
	_run_group("persistence", _test_inventory)
	_run_group("conditions", _test_conditions)
	_run_group("conditions", func(): Batch020Checks.run(_assert))
	_run_group("classes", func(): Batch027Checks.run(_assert))
	_run_group("classes", func(): Batch028Checks.run(_assert))
	_run_group("classes", func(): Batch029Checks.run(_assert))
	_run_group("classes", func(): Batch030Checks.run(_assert))
	_run_group("persistence", _test_character_serialization)
	_run_group("world", _test_player_manager)
	_run_group("world", _test_party_manager)
	_run_group("world", _test_campaign_contracts)
	_run_group("world", _test_event_system)
	if _logic_groups.is_empty() or "all" in _logic_groups or "check_context" in _logic_groups:
		await CheckContextChecks.run(_assert)
	_run_group("world", _test_fog_of_war)
	_run_group("world", _test_hexutils)
	_run_group("world", _test_dungeon_lifecycle)
	_run_group("world", func(): LocalRoomChecks.run(_assert))
	_run_group("persistence", _test_activity_history)
	_run_group("persistence", _test_save_load)
	_run_group("persistence", func(): PlaytestFixChecks.saved_coordinates(_assert))
	_run_group("ui", _test_widgets)
	_run_group("classes", func(): ClassFeatureChecks.run(_assert))
	# Release the real per-turn attack cache before the scene harness exits.
	CombatAction.reset_bounded_owner_turn_rider_locks()
	SpellDamageRolls.clear_pending_requests()
	_report()
	get_tree().quit(1 if _failed > 0 else 0)


## Card cafa regression: simulated load and compile failures are reported
## (no broken file is committed; an uncompiled GDScript stands in for a parse failure).
func _test_check_script_gate() -> void:
	var names := CheckScriptGate.registered("_run_group(\"x\", func(): Batch050Checks.run(_assert))\nFooChecks.load_fixtures()\nBatch050Checks.x()")
	_assert(names == ["Batch050Checks", "FooChecks"], "cafa: the gate finds each registered check class once (%s)" % str(names))
	var uncompiled := GDScript.new()
	uncompiled.source_code = "extends RefCounted\nfunc run(:"
	var fails := CheckScriptGate.failures({"MissingChecks": null, "BrokenChecks": uncompiled, "Batch050Checks": load("res://src/batch_050_checks.gd")})
	_assert(fails.size() == 2 and "MissingChecks failed to load" in fails[0] + fails[1] and "BrokenChecks failed to parse" in fails[0] + fails[1], "cafa: a missing script and an uncompiled (unparseable) script both fail the gate; a good one passes: %s" % str(fails))
	_assert(CheckScriptGate.load_registered("res://src/test_runner.gd").size() >= 20, "cafa: the live runner registers its check classes through the gate")
	var probe := ScriptErrorCounter.new()
	probe._log_error("f", "res://x.gd", 1, "", "engine noise", false, Logger.ERROR_TYPE_ERROR, [])
	probe._log_error("run", "res://y.gd", 7, "", "Invalid call", false, Logger.ERROR_TYPE_SCRIPT, [])
	_assert(probe.count == 1 and "res://y.gd:7" in probe.first, "Review cafa R1: the runner's logger counts script errors only (%d, %s)" % [probe.count, probe.first])

func _run_group(group: String, check: Callable) -> void:
	if _logic_groups.is_empty() or "all" in _logic_groups or group in _logic_groups:
		check.call()

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failures.append(msg)
		print("[FAIL] %s" % msg)

func _report() -> void:
	# Review cafa R1: a check that died on a SCRIPT ERROR skipped its remaining asserts.
	if _script_errors.count > 0:
		_assert(false, "%d SCRIPT ERROR(s) during the logic run aborted check code; first: %s" % [_script_errors.count, _script_errors.first])
	print("--------------------------------------------------")
	print(" RESULTS: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		print(" FAILURES:")
		for f in _failures:
			print("   - %s" % f)
		print("TESTS FAILED")
	else:
		print("ALL TESTS PASSED" if _logic_groups.is_empty() or "all" in _logic_groups else "SELECTED LOGIC TESTS PASSED")

# ---- helpers ----
func _fresh_char(name: String, race: String, klass: String, scores_dict: Dictionary) -> Character:
	var s: AbilityScores = AbilityScores.new()
	s.from_dict(scores_dict)
	var c: Character = Character.new()
	c.initialize(name, race, klass, s)
	return c

func _test_paladin_divine_sense_2024() -> void:
	var poison_paladin := _fresh_char("Poison Cleanser", "human", "paladin", {"STR": 12, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 14})
	var poison_ally := _fresh_char("Poisoned Ally", "human", "fighter", {"STR": 14, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 10})
	poison_ally.add_condition("poisoned", 3)
	var poison_result := CombatAction.resolve_lay_on_hands(poison_paladin, poison_ally, 0, ["poisoned"])
	_assert(poison_result.get("success", false) and poison_result.get("conditions_removed", []).has("poisoned") and poison_paladin.feature_uses.get("paladin_lay_on_hands", -1) == 0, "Level-1 Lay on Hands spends five pool points to remove Poisoned without requiring Restoring Touch")
	var paladin := _fresh_char("Divine Sense", "human", "paladin", {"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	paladin.level_up()
	paladin.level_up()
	var feature := paladin.get_feature("paladin_channel_divinity_divine_sense")
	_assert(not feature.is_empty() and feature.get("action_cost", "") == "bonus_action" and feature.get("resource_id", "") == "paladin_channel_divinity", "Divine Sense is a Bonus Action using the shared Paladin Channel Divinity pool")
	_assert(paladin.feature_uses.get("paladin_channel_divinity", 0) == 2, "Level-3 Divine Sense is available from the Paladin's shared two-use Channel Divinity pool")
	var fiend := _monster_inst("goblin")
	fiend["id"] = "sense-fiend"
	fiend["name"] = "Near Fiend"
	fiend["creature_type"] = "fiend"
	fiend["hex_position"] = Vector2i(12, 0)
	var undead := _monster_inst("goblin")
	undead["id"] = "sense-undead"
	undead["name"] = "Near Undead"
	undead["creature_type"] = "undead"
	undead["hex_position"] = Vector2i(0, 13)
	var ordinary := _monster_inst("goblin")
	ordinary["id"] = "sense-ordinary"
	ordinary["creature_type"] = "humanoid"
	ordinary["hex_position"] = Vector2i(1, 0)
	_assert(paladin.use_feature("paladin_channel_divinity_divine_sense"), "Divine Sense spends one use from the shared Channel Divinity pool")
	var result := CombatAction.resolve_divine_sense(paladin, [fiend, undead, ordinary], Vector2i.ZERO, 12, 4)
	_assert(result.get("success", false) and result.get("target_ids", []) == ["sense-fiend"], "Divine Sense detects eligible creatures within 60 feet and ignores other types or creatures beyond range")
	_assert(paladin.feature_uses.get("paladin_divine_sense_expires_round", 0) == 104 and str(result.get("message", "")).contains("fiend") and str(result.get("message", "")).contains("(12, 0)"), "Divine Sense reports creature type and position and records its 10-minute duration")
	fiend["hex_position"] = Vector2i(2, 0)
	var refreshed := CombatAction.resolve_divine_sense(paladin, [fiend], Vector2i.ZERO, 12, 5, true)
	_assert(refreshed.get("target_ids", []) == ["sense-fiend"] and paladin.feature_uses.get("paladin_divine_sense_expires_round", 0) == 104, "Divine Sense refreshes changing creature positions without extending the original duration")

func _test_paladin_abjure_foes_2024() -> void:
	var paladin := _fresh_char("Abjure Foes", "human", "paladin", {"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	for _level in range(8):
		paladin.level_up()
	var feature := paladin.get_feature("paladin_abjure_foes")
	_assert(not feature.is_empty() and feature.get("action_cost", "") == "magic_action" and feature.get("resource_id", "") == "paladin_channel_divinity", "Abjure Foes uses a Magic action and the shared Paladin Channel Divinity pool")
	var first := _monster_inst("goblin")
	first["id"] = "abjure-first"
	first["name"] = "First Foe"
	first["ability_scores"] = {"WIS": 10}
	first["saving_throw_bonuses"] = {"WIS": -30}
	first["hex_position"] = Vector2i(1, 0)
	var second := _monster_inst("goblin")
	second["id"] = "abjure-second"
	second["name"] = "Second Foe"
	second["ability_scores"] = {"WIS": 10}
	second["saving_throw_bonuses"] = {"WIS": -30}
	second["hex_position"] = Vector2i(2, 0)
	var immune := _monster_inst("goblin")
	immune["id"] = "abjure-immune"
	immune["condition_immunities"] = ["frightened"]
	immune["hex_position"] = Vector2i(3, 0)
	var distant := _monster_inst("goblin")
	distant["id"] = "abjure-distant"
	distant["ability_scores"] = {"WIS": 10}
	distant["saving_throw_bonuses"] = {"WIS": -30}
	distant["hex_position"] = Vector2i(13, 0)
	var third := _monster_inst("goblin")
	third["id"] = "abjure-third"
	third["ability_scores"] = {"WIS": 10}
	third["saving_throw_bonuses"] = {"WIS": -30}
	third["hex_position"] = Vector2i(4, 0)
	var results := PaladinRules.resolve_abjure_foes(paladin, [first, second, distant, immune, third], Vector2i.ZERO)
	_assert(results.size() == 3 and results[0].get("saved", true) == false and first.get("conditions", {}).get("frightened", 0) == 10 and first.get(PaladinRules.ABJURE_FOES_MARKER, false), "Abjure Foes makes Wisdom saves and frightens no more foes than the Charisma modifier")
	var abjure_party: Array[Dictionary] = [{"character": paladin, "hex_position": Vector2i.ZERO}]
	_assert(PaladinRules.abjure_foes_forbids_movement_closer(first, Vector2i.ZERO, abjure_party) and not PaladinRules.abjure_foes_forbids_movement_closer(first, Vector2i(2, 0), abjure_party), "Abjure Foes prevents willing movement closer to the living caster while allowing movement away")
	abjure_party[0]["hex_position"] = Vector2i(3, 0)
	_assert(PaladinRules.abjure_foes_source_position(first, abjure_party) == Vector2i(3, 0), "Abjure Foes tracks its caster's current position for fear visibility and movement")
	_assert(results[2].get("immune", false) and not distant.get("conditions", {}).has("frightened") and not third.get("conditions", {}).has("frightened"), "Abjure Foes respects Frightened immunity, its 60-foot range, and its target cap")
	ClericRules.clear_turning_after_damage(first)
	_assert(not first.get("conditions", {}).has("frightened") and not first.has(PaladinRules.ABJURE_FOES_MARKER), "Any damage clears Abjure Foes' source-marked Frightened condition")
	for round_tick in 10:
		CombatState.tick_monster_condition_durations(second)
	_assert(not second.get("conditions", {}).has("frightened") and not second.has(PaladinRules.ABJURE_FOES_MARKER), "Abjure Foes clears its source marker when the one-minute condition duration expires")

func _test_fighter_second_wind_2024() -> void:
	var fighter := _fresh_char("Second Wind", "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
	for expected_level in range(1, 6):
		var maximum := 2 if expected_level < 4 else 3
		_assert(fighter.level == expected_level and fighter.get_feature_max_uses("fighter_second_wind") == maximum, "Second Wind maximum follows 2024 progression at level %d" % expected_level)
		fighter.long_rest()
		for use_index in maximum:
			_assert(fighter.use_feature("fighter_second_wind"), "Second Wind legal use %d at level %d" % [use_index + 1, expected_level])
		_assert(not fighter.use_feature("fighter_second_wind"), "Second Wind rejects exhaustion at level %d" % expected_level)
		fighter.reset_combat_features()
		_assert(fighter.feature_uses["fighter_second_wind"] == 0, "entering combat does not restore Second Wind")
		fighter.short_rest()
		_assert(fighter.feature_uses["fighter_second_wind"] == 1, "Short Rest restores exactly one Second Wind")
		var restored := Character.new()
		restored.from_dict(fighter.to_dict())
		_assert(restored.get_feature_max_uses("fighter_second_wind") == maximum and restored.feature_uses["fighter_second_wind"] == 1, "Second Wind maximum and remaining uses survive serialization")
		fighter.long_rest()
		_assert(fighter.feature_uses["fighter_second_wind"] == maximum, "Long Rest restores all Second Wind uses")
		fighter.short_rest()
		_assert(fighter.feature_uses["fighter_second_wind"] == maximum, "Short Rest cannot overfill Second Wind")
		fighter.current_hp = 1
		fighter.max_hp = 100
		var healing := EventResolver.apply_effects(fighter, fighter.get_feature("fighter_second_wind")["effects"])
		_assert(int(healing[0].get("amount", 0)) >= 1 + expected_level and int(healing[0].get("amount", 0)) <= 10 + expected_level and fighter.current_hp == 1 + int(healing[0].get("amount", 0)), "production Second Wind healing uses 1d10 plus Fighter level")
		if expected_level < 5:
			fighter.feature_uses["fighter_second_wind"] = 0
			fighter.level_up()
			_assert(fighter.feature_uses["fighter_second_wind"] == (1 if expected_level == 3 else 0), "level-up grants only newly gained Second Wind capacity")
	fighter.current_hp = fighter.max_hp - 1
	EventResolver.apply_effects(fighter, fighter.get_feature("fighter_second_wind")["effects"])
	_assert(fighter.current_hp == fighter.max_hp, "Second Wind healing cannot exceed maximum HP")
	var invalid_remaining := fighter.to_dict()
	invalid_remaining["feature_uses"]["fighter_second_wind"] = 999
	var bounded := Character.new()
	bounded.from_dict(invalid_remaining)
	_assert(bounded.feature_uses["fighter_second_wind"] == 3, "loaded Second Wind cannot exceed the level maximum")
	_assert(fighter.get_feature("fighter_second_wind").get("rules_status", "") == "2024-supported" and DataLoader.get_character_class("fighter").get("rules_status", "") == "2024-supported", "Fighter production data identifies its implemented 2024 features")


func _test_monk_2024() -> void:
	print("\n[Group] 2024 Monk")
	var monk := _fresh_char("Focus Fixture", "human", "monk", {"STR": 10, "DEX": 16, "CON": 12, "INT": 10, "WIS": 16, "CHA": 8})
	_assert(DataLoader.get_all_classes().size() == 12, "new creation offers the twelve core classes, not Artificer/Mystic")
	_assert(monk.armor_proficiencies.is_empty() and monk.is_unarmored(), "Monk has no armor training or starting armor")
	_assert(monk.inventory.get_weapon() == "spear" and monk.inventory.count_item("dagger") == 5 and monk.inventory.gold == 11, "Monk receives the supported 2024 starting weapons and gold")
	_assert(monk.get_martial_arts_die() == "1d6" and monk.get_max_focus_points() == 0, "level 1 has d6 Martial Arts and no Focus")
	_assert(monk.is_monk_weapon(DataLoader.get_item("shortsword")) and monk.is_monk_weapon(DataLoader.get_item("scimitar")), "Light Martial melee weapons qualify for Martial Arts")
	_assert(not monk.is_monk_weapon(DataLoader.get_item("longsword")) and not monk.is_monk_weapon(DataLoader.get_item("shortbow")), "non-Light Martial and Ranged weapons do not qualify")
	monk.level_up()
	_assert(monk.get_focus_points() == 2 and monk.get_speed() == monk.speed + 2, "level 2 unlocks shared Focus and ten feet of unarmored movement")
	_assert(monk.spend_focus_points(1) and monk.spend_focus_points(1) and not monk.spend_focus_points(1), "Focus is shared and cannot overspend")
	_assert(not monk.spend_focus_points(-1) and monk.get_focus_points() == 0, "negative spending cannot manufacture Focus")
	monk.short_rest()
	_assert(monk.get_focus_points() == 2, "Short Rest restores Focus")
	monk.spend_focus_points(1)
	var restored := Character.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(monk.to_dict())))
	_assert(restored.get_focus_points() == 1, "actual Character JSON round trip preserves remaining Focus")
	monk.inventory.add_item("shield")
	monk.inventory.equip(Inventory.Slot.SHIELD, "shield")
	_assert(not monk.can_use_martial_arts() and monk.get_speed() == monk.speed, "shield disables Martial Arts and Unarmored Movement")
	monk.inventory.unequip(Inventory.Slot.SHIELD)
	monk.inventory.add_item("leather_armor")
	monk.inventory.equip(Inventory.Slot.BODY, "leather_armor")
	_assert(not monk.can_use_martial_arts(), "armor disables Martial Arts")
	monk.inventory.unequip(Inventory.Slot.BODY)
	monk.level_up()
	monk.current_hp = 1
	monk.spend_focus_points(monk.get_focus_points())
	_assert(monk.use_uncanny_metabolism().get("success", false) and monk.get_focus_points() == 3 and monk.current_hp > 1, "Uncanny Metabolism restores Focus and heals")
	_assert(not monk.use_uncanny_metabolism().get("success", false), "Uncanny Metabolism cannot repeat before a Long Rest")
	monk.long_rest()
	_assert(not monk.feature_uses.has("uncanny_metabolism_used") and monk.get_focus_points() == 3, "Long Rest resets metabolism and Focus")
	monk.level_up()
	monk.level_up()
	_assert(monk.get_martial_arts_die() == "1d8" and monk.get_max_focus_points() == 5 and monk.extra_attacks == 1, "level 5 unlocks d8 Martial Arts, five Focus and Extra Attack")
	var level_five_copy := Character.new()
	level_five_copy.from_dict(monk.to_dict())
	_assert(level_five_copy.extra_attacks == 1, "level-5 reload rebuilds Extra Attack exactly once")
	var foe := _monster_inst("goblin")
	foe["current_hp"] = 100
	foe["armor_class"] = -100
	foe["ability_scores"] = {"CON": 1, "DEX": 1}
	foe["saving_throw_bonuses"] = {"CON": -100, "DEX": -100}
	var stun := CombatAction.resolve_stunning_strike(monk, foe)
	_assert(stun.get("stunned", false) and monk.get_focus_points() == 4, "failed CON save produces a source-bound Stunned target and spends one Focus")
	_assert(not CombatAction.resolve_stunning_strike(monk, foe).get("success", true) and monk.get_focus_points() == 4, "Stunning Strike cannot spend twice in a turn")
	monk.feature_uses.erase("stunning_strike_used")
	foe.erase("stunning_strike_stunned")
	foe["saving_throw_bonuses"]["CON"] = 100
	var resisted := CombatAction.resolve_stunning_strike(monk, foe)
	_assert(resisted.get("success", false) and foe.get("speed", 0) == 3 and foe.get("stunning_strike_advantage", false), "successful CON save still halves speed and grants next-attack Advantage")
	var hit := CombatAction.resolve_unarmed_attack(monk, foe)
	_assert(hit.get("activity_roll", {}).get("formula", "").begins_with("2d20kh1") and not foe.has("stunning_strike_advantage"), "Stunning Strike Advantage is consumed by the next actual attack")
	var dice_seen := false
	for attempt in 30:
		var strike := CombatAction.resolve_unarmed_attack(monk, foe)
		if strike.get("hit", false):
			dice_seen = int(strike.get("activity_damage", {}).get("dice_terms", [{}])[0].get("sides", 0)) == 8
			break
	_assert(dice_seen, "the level-5 production unarmed resolver actually rolls d8, not merely a matching description")
	var redirect := CombatAction.resolve_deflect_redirect(monk, foe, "piercing")
	_assert(redirect.get("success", false) and redirect.get("damage", 0) >= 5 and monk.get_focus_points() == 2, "Deflect redirect uses two Martial Arts dice plus DEX and shared Focus")
	var enemy := _fresh_char("Incoming", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	monk.base_ac = -100
	var deflect_seen := false
	for attempt in 30:
		monk.reaction_available = true
		var attack := CombatAction.resolve_weapon_attack(enemy, monk, {"damage": "1", "damage_type": "piercing"}, false, false, {"deflect_attacks": true})
		if attack.get("hit", false):
			deflect_seen = attack.get("deflected", false) and not monk.reaction_available and attack.get("damage", -1) == 0
			break
	_assert(deflect_seen, "confirmed physical hit spends Reaction and can reduce damage to zero")
	var forged := monk.get_feature("monk_flurry_of_blows").duplicate(true)
	forged["focus_cost"] = 0
	var command := CombatCommand.from_hud_for_character("use_feature", {"feature": forged}, monk)
	_assert(command != null and command.payload["feature"].get("focus_cost", 0) == 1, "HUD cannot forge a cheaper Flurry cost")
	_assert(CombatCommand.from_hud_for_character("use_feature", {"feature": monk.get_feature("monk_martial_arts")}, monk) == null, "passive features cannot be submitted as active commands")

	# --- Monk Levels 6 to 20 Verification ---
	# Level 6: Empowered Strikes, Wholeness of Body, Unarmored Movement +15 ft
	monk.level_up()
	_assert(monk.level == 6 and monk.has_feature("monk_empowered_strikes"), "level 6 unlocks Empowered Strikes")
	_assert(monk.get_speed() == monk.speed + 3, "level 6 unarmored movement is +15 ft (3 tiles)")
	var empowered_atk := CombatAction.resolve_unarmed_attack(monk, foe)
	_assert(empowered_atk.get("damage_type", "") == "force", "Empowered Strikes deals Force damage with Unarmed Strikes")
	monk.current_hp = 5
	var whole_res := MonkRules.use_wholeness_of_body(monk)
	_assert(whole_res.get("success", false) and monk.current_hp > 5, "Wholeness of Body heals successfully")

	# Level 7: Evasion
	monk.level_up()
	_assert(monk.level == 7 and monk.has_feature("monk_evasion"), "level 7 unlocks Evasion")
	# Level 8: ASI
	monk.level_up()
	_assert(monk.level == 8 and monk.has_feature("monk_ability_score_improvement_8"), "level 8 unlocks ASI")
	# Level 9: Acrobatic Movement
	monk.level_up()
	_assert(monk.level == 9 and not monk.has_feature("monk_acrobatic_movement"), "terrain-dependent Acrobatic Movement remains unavailable")

	# Level 10: Heightened Focus, Self-Restoration, Unarmored Movement +20 ft
	monk.level_up()
	_assert(monk.level == 10 and monk.has_feature("monk_heightened_focus") and monk.has_feature("monk_self_restoration"), "level 10 unlocks Heightened Focus and Self-Restoration")
	_assert(monk.get_speed() == monk.speed + 4, "level 10 unarmored movement is +20 ft (4 tiles)")
	var flurry_3 := CombatAction.resolve_flurry_of_blows(monk, foe)
	_assert(flurry_3.size() == 3, "Heightened Focus grants 3 unarmed strikes with Flurry of Blows")
	monk.add_condition("poisoned", 5)
	monk.tick_conditions()
	_assert(not monk.has_condition("poisoned"), "Self-Restoration removes poisoned condition at end of turn")

	# Level 11: Fleet Step, Martial Arts die upgrades to 1d10
	monk.level_up()
	_assert(monk.level == 11 and monk.get_martial_arts_die() == "1d10", "level 11 upgrades Martial Arts die to 1d10")
	_assert(monk.has_feature("monk_fleet_step"), "level 11 unlocks Fleet Step")
	# Level 12: ASI
	monk.level_up()
	_assert(monk.level == 12 and monk.has_feature("monk_ability_score_improvement_12"), "level 12 unlocks ASI")

	# Level 13: Deflect Energy
	monk.level_up()
	_assert(monk.level == 13 and monk.has_feature("monk_deflect_energy"), "level 13 unlocks Deflect Energy")
	monk.reaction_available = true
	var fire_atk := CombatAction.resolve_weapon_attack(enemy, monk, {"damage": "1", "damage_type": "fire", "attack_bonus": 50}, true, false, {"deflect_attacks": true})
	_assert(fire_atk.get("deflected", false) and fire_atk.get("damage", -1) == 0, "Deflect Energy deflects non-physical damage")

	# Level 14: Disciplined Survivor, Unarmored Movement +25 ft
	monk.level_up()
	_assert(monk.level == 14 and monk.has_feature("monk_disciplined_survivor"), "level 14 unlocks Disciplined Survivor")
	_assert(monk.get_speed() == monk.speed + 5, "level 14 unarmored movement is +25 ft (5 tiles)")
	_assert(monk.is_proficient_in_save("STR") and monk.is_proficient_in_save("DEX") and monk.is_proficient_in_save("CON") and monk.is_proficient_in_save("INT") and monk.is_proficient_in_save("WIS") and monk.is_proficient_in_save("CHA"), "Disciplined Survivor grants proficiency in all 6 saving throws")
	var focus_before_save := monk.get_focus_points()
	monk.saving_throw_to_dc("INT", 50)
	_assert(monk.get_focus_points() == focus_before_save - 1, "Disciplined Survivor spends 1 Focus to reroll failed saving throw")

	# Level 15: Perfect Focus
	monk.level_up()
	_assert(monk.level == 15 and monk.has_feature("monk_perfect_focus"), "level 15 unlocks Perfect Focus")
	monk.spend_focus_points(monk.get_focus_points())
	_assert(MonkRules.apply_perfect_focus(monk) and monk.get_focus_points() == 4, "Perfect Focus restores Focus to 4 when rolling initiative with <= 3 Focus")

	# Level 16: ASI
	monk.level_up()
	_assert(monk.level == 16 and monk.has_feature("monk_ability_score_improvement_16"), "level 16 unlocks ASI")

	# Level 17: Quivering Palm, Martial Arts die upgrades to 1d12
	monk.level_up()
	_assert(monk.level == 17 and monk.get_martial_arts_die() == "1d12", "level 17 upgrades Martial Arts die to 1d12")
	_assert(not monk.has_feature("monk_quivering_palm"), "unwired Quivering Palm is not a player action")
	monk.short_rest()
	var focus_before_quiv := monk.get_focus_points()
	var quiv := MonkRules.resolve_quivering_palm(monk, foe)
	_assert(not quiv.get("success", false) and monk.get_focus_points() == focus_before_quiv, "unavailable Quivering Palm cannot spend Focus through its helper")

	# Level 18: Superior Defense, Unarmored Movement +30 ft
	monk.level_up()
	_assert(monk.level == 18 and monk.has_feature("monk_superior_defense"), "level 18 unlocks Superior Defense")
	_assert(monk.get_speed() == monk.speed + 6, "level 18 unarmored movement is +30 ft (6 tiles)")
	var sup_res := MonkRules.activate_superior_defense(monk, true)
	_assert(sup_res.get("success", false) and monk.has_condition("superior_defense"), "Superior Defense grants superior_defense condition")
	var incoming_slash := CombatAction.resolve_weapon_attack(enemy, monk, {"damage": "10", "damage_type": "slashing"}, false, false)
	var max_expected: int = 10 if incoming_slash.get("crit", false) else 5
	_assert(incoming_slash.get("damage", 0) <= max_expected, "Superior Defense halves incoming damage")

	# Level 19: Epic Boon
	monk.level_up()
	_assert(monk.level == 19 and not monk.has_feature("monk_epic_boon"), "unsupported Monk Epic Boon catalog remains unavailable")

	# Level 20: Body and Mind
	var dex_before := monk.ability_scores.get_score("DEX")
	var wis_before := monk.ability_scores.get_score("WIS")
	monk.level_up()
	_assert(monk.level == 20 and monk.has_feature("monk_body_and_mind"), "level 20 unlocks Body and Mind")
	_assert(monk.ability_scores.get_score("DEX") == dex_before + 4 and monk.ability_scores.get_score("WIS") == wis_before + 4, "Body and Mind increases DEX and WIS by 4 at level 20")
	_assert(monk.get_max_focus_points() == 20, "level 20 Monk has 20 Focus points")

	# Subclass Open Hand Technique test
	foe["current_hp"] = 100
	foe["is_alive"] = true
	foe["saving_throw_bonuses"] = {"DEX": -10}
	var open_hand_addle := MonkRules.resolve_open_hand_technique(monk, foe, "addle")
	_assert(not open_hand_addle.get("success", false), "unwired Open Hand Technique remains unavailable")
	var open_hand_topple := MonkRules.resolve_open_hand_technique(monk, foe, "topple")
	_assert(not open_hand_topple.get("success", false), "unavailable Open Hand helper cannot apply Topple")

	# Serialization round trip at Level 20
	var monk_dict := monk.to_dict()
	var loaded_monk := Character.new()
	loaded_monk.from_dict(monk_dict)
	_assert(loaded_monk.ability_scores.to_dict() == monk.ability_scores.to_dict(), "Body and Mind is not applied again when rebuilding saved features")
	_assert(loaded_monk.level == 20 and loaded_monk.get_martial_arts_die() == "1d12" and loaded_monk.get_max_focus_points() == 20, "Level 20 Monk survives full Character serialization round-trip")


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


func _activity_attack_draft(title: String = "Longsword") -> Dictionary:
	return {
		"category": "roll",
		"kind": "attack",
		"actor": {"id": "pc-elowen", "name": "Elowen"},
		"targets": [{"id": "goblin-3", "name": "Goblin"}],
		"title": title,
		"summary": "17 vs AC 14 - Hit",
		"outcome": {"code": "hit", "label": "Hit"},
		"visibility": "public",
		"payload": {
			"formula": "1d20 + 3 + 2",
			"dice_terms": [{
				"count": 1,
				"sides": 20,
				"results": [12],
				"kept": [true],
				"label": "d20",
				"subtotal": 12,
			}],
			"modifiers": [
				{"label": "Strength", "value": 3},
				{"label": "Proficiency", "value": 2},
			],
			"natural_total": 12,
			"final_total": 17,
			"comparison": {
				"kind": "armor_class",
				"target": 14,
				"margin": 3,
				"result": "hit",
			},
		},
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
	for consumable_id in ["potion_healing", "potion_greater_healing", "antidote"]:
		var consumable: Dictionary = DataLoader.get_item(consumable_id)
		_assert(consumable.get("type", "") == "consumable" and not consumable.get("effects", []).is_empty(), "Production consumable %s has an executable effect" % consumable_id)
	var torch_item: Dictionary = DataLoader.get_item("torch")
	_assert(torch_item.get("light_source", {}).get("bright_radius_feet", 0) == 20 and torch_item.get("light_source", {}).get("dim_radius_feet", 0) == 40 and torch_item.get("light_source", {}).get("duration_seconds", 0) == 3600, "Torch records the 2024 Basic Rules light radii and one-hour burn time")
	var wizard: Dictionary = DataLoader.get_character_class("wizard")
	_assert(wizard.get("spells_known_by_level", {}).get("1", []).has("magic_missile"), "wizard has a production level-1 spell")
	var wizard_spell_options := DataLoader.get_spell_list_options(["wizard"])
	var wizard_leveled_spell_count := 0
	for spell_option in wizard_spell_options:
		if int(spell_option.get("level", 0)) > 0:
			wizard_leveled_spell_count += 1
	_assert(wizard_leveled_spell_count >= 29 and DataLoader.get_spell("cone_of_cold").get("level", 0) == 5 and DataLoader.get_spell("power_word_kill").get("level", 0) == 9, "Wizard spellbook choices include supported level-1 through level-9 spells")
	_assert(wizard.get("features_by_level", {}).get("1", []).any(func(feature): return str(feature.get("id", "")) == "wizard_spellcasting"), "Wizard Spellcasting is exposed through the shared prepared-spell feature")

	# Complete SRD 5.2.1 spell catalog assertions
	var expected_class_spell_counts: Dictionary = {
		# SRD list plus the existing curated PHB2024 Cloud of Daggers integration.
		"wizard": 219,
		"sorcerer": 139,
		"druid": 125,
		"cleric": 110,
		"bard": 136,
		"warlock": 75,
		"ranger": 49,
		"paladin": 46
	}
	for class_name_key in expected_class_spell_counts:
		var list_options := DataLoader.get_spell_list_options([class_name_key])
		_assert(list_options.size() == expected_class_spell_counts[class_name_key], "Class %s retains its approved 2024 spell list inventory (%d spells)" % [class_name_key, expected_class_spell_counts[class_name_key]])

	for sample_spell_id in ["chain_lightning", "meteor_swarm", "time_stop", "mass_heal", "prismatic_spray", "sunburst", "heal", "wish"]:
		var sample_spell: Dictionary = DataLoader.get_spell(sample_spell_id)
		_assert(not sample_spell.is_empty() and sample_spell.has("level") and sample_spell.has("school") and sample_spell.has("casting_time"), "Iconic SRD spell '%s' is present with full attributes" % sample_spell_id)

	var eldritch_blast: Dictionary = DataLoader.get_spell("eldritch_blast")
	_assert(eldritch_blast.get("rules_source", "") == "SRD5.2.1" and eldritch_blast.get("beam_count_by_level", {}).get("17", 0) == 4 and eldritch_blast.get("damage_per_ray", "") == "1d10" and SpellSupport.is_available(eldritch_blast), "Eldritch Blast records its per-beam damage and is available with per-beam targeting")
	var spare_the_dying: Dictionary = DataLoader.get_spell("spare_the_dying")
	_assert(spare_the_dying.get("rules_source", "") == "SRD 5.2.1" and int(spare_the_dying.get("range", 0)) == 3 and spare_the_dying.get("range_by_character_level_feet", {}).get("17", 0) == 120 and SpellSupport.is_available(spare_the_dying), "Spare the Dying records its 2024 range and cantrip upgrades and is available")
	_assert([CombatAction.spell_range_in_hexes(spare_the_dying, 1), CombatAction.spell_range_in_hexes(spare_the_dying, 5), CombatAction.spell_range_in_hexes(spare_the_dying, 11), CombatAction.spell_range_in_hexes(spare_the_dying, 17)] == [3, 6, 12, 24], "Spare the Dying range doubles at character levels 5, 11, and 17")

	var archmage: Character = _fresh_char("Archmage", "human", "wizard", {"STR": 10, "DEX": 14, "CON": 14, "INT": 20, "WIS": 12, "CHA": 10})
	while archmage.level < 20:
		archmage.level_up()
	var test_dummy: Character = _fresh_char("Test Dummy", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	test_dummy.max_hp = 500
	test_dummy.current_hp = 500

	var chain_lightning_spell: Dictionary = DataLoader.get_spell("chain_lightning")
	_assert(chain_lightning_spell.get("rules_status", "") == "2024-gameplay-partial" and chain_lightning_spell.get("base_targets", 0) == 4 and chain_lightning_spell.get("upcast", {}).get("additional_targets_per_level", 0) == 1 and not chain_lightning_spell.get("upcast", {}).has("damage_per_level"), "Chain Lightning records the 2024 chained targets and upcast bolts")
	_assert(chain_lightning_spell.get("requires_target_sight", false) and SpellSupport.is_available(chain_lightning_spell), "Chain Lightning remains sight-targeted and is enabled for its accepted creature/object target paths")
	var contact_other_plane: Dictionary = DataLoader.get_spell("contact_other_plane")
	_assert(contact_other_plane.get("rules_source", "") == "SRD5.2.1" and contact_other_plane.get("question_limit", 0) == 5 and not SpellSupport.is_available(contact_other_plane), "Contact Other Plane records its five-question purpose and remains gated until it can return answers")
	var finger_of_death: Dictionary = DataLoader.get_spell("finger_of_death")
	_assert(finger_of_death.get("rules_source", "") == "SRD5.2.1" and finger_of_death.get("zombie_on_humanoid_kill", false) and not SpellSupport.is_available(finger_of_death), "Finger of Death records its Humanoid-to-Zombie effect and stays gated until created-creature behavior exists")
	var power_word_stun: Dictionary = DataLoader.get_spell("power_word_stun")
	_assert(power_word_stun.get("rules_source", "") == "SRD5.2.1" and power_word_stun.get("hp_threshold", 0) == 150 and power_word_stun.get("repeat_save_ability", "") == "CON" and power_word_stun.get("requires_target_sight", false) and SpellSupport.is_available(power_word_stun), "Power Word Stun records its sight, HP threshold and repeat save and is available")
	var circle_of_death: Dictionary = DataLoader.get_spell("circle_of_death")
	_assert(circle_of_death.get("area_radius", 0) == 12 and circle_of_death.get("material_component_cost", 0) == 500 and circle_of_death.get("material_component_item_id", "") == "black_pearl_powder_500gp" and not circle_of_death.get("material_component_consumed", false) and SpellSupport.is_available(circle_of_death), "Circle of Death requires its 500 GP black-pearl component without consuming it")
	var thunderwave_spell: Dictionary = DataLoader.get_spell("thunderwave")
	_assert(thunderwave_spell.get("rules_source", "") == "SRD5.2.1" and thunderwave_spell.get("effects", [])[0].get("shape", "") == "cube" and thunderwave_spell.get("effects", [])[0].get("size", 0) == 3 and SpellSupport.is_available(thunderwave_spell), "Thunderwave records its 15-foot Cube and is available with directional cube targeting")
	_assert(thunderwave_spell.get("upcast", {}).get("damage_per_level", "") == "1d8" and thunderwave_spell.get("effects", [])[1].get("on_failed_save", false) and CombatAction.spell_damage_formula(archmage, thunderwave_spell, 2) == "2d8 + 1d8", "Thunderwave upcasts by 1d8 and marks its 10-foot push for failed saves only")
	print("THUNDERWAVE_CUBE_PUSH_CHECKS_COMPLETE")

	var sunburst_spell: Dictionary = DataLoader.get_spell("sunburst")
	_assert(sunburst_spell.get("rules_status", "") == "2024-gameplay-partial" and sunburst_spell.get("area_selection", {}).get("radius", 0) == 12 and sunburst_spell.get("condition_on_failed_save", "") == "blinded", "Sunburst records its 60-foot Sphere and failed-save Blinded effect")
	_assert(SpellSupport.is_available(sunburst_spell) and sunburst_spell.get("duration_seconds", 0) == 60 and sunburst_spell.get("repeat_save_ability", "") == "CON", "Sunburst exposes its playable area, failed-save Blinded effect, one-minute duration, and Constitution repeat save")

	var meteor_spell: Dictionary = DataLoader.get_spell("meteor_swarm")
	_assert(meteor_spell.get("rules_status", "") == "2024-gameplay-partial" and meteor_spell.get("area_point_count", 0) == 4 and meteor_spell.get("area_radius", 0) == 8 and meteor_spell.get("damage_components", []).size() == 2 and meteor_spell.get("damage_components", [])[1].get("damage_type", "") == "bludgeoning", "Meteor Swarm records four 40-foot spheres and split Fire/Bludgeoning damage")
	_assert(SpellSupport.is_available(meteor_spell), "Meteor Swarm is available after its creature and unattended-object area paths pass")
	var disintegrate_cast := CombatAction.resolve_spell(archmage, test_dummy, DataLoader.get_spell("disintegrate"))
	_assert(disintegrate_cast.get("success", false) and int(disintegrate_cast.get("damage", 0)) > 0, "Disintegrate resolves DEX save and force damage")
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
				if feature.get("effects", []).is_empty() and feature.get("passive_effects", []).is_empty() and str(feature.get("resolver", "")).is_empty() and str(feature.get("executor", "")).is_empty() and feature.get("type", "") != "resource":
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
	var caster_book: Array[String] = ["magic_missile", "shield", "mage_armor", "sleep", "ice_knife", "burning_hands"]
	_assert(ClassProgression.choose_wizard_spellbook(caster, caster_book), "new Wizard records the required starting spellbook choices")
	var caster_spell_choices: Array[String] = ["fire_bolt", "ray_of_frost", "light", "magic_missile", "shield", "mage_armor", "sleep"]
	_assert(ClassProgression.choose_spell_selection(caster, caster_spell_choices), "new Wizard prepares leveled spells from the saved spellbook")
	_assert("magic_missile" in caster.known_spells and caster.spell_slots.get("1", 0) > 0, "new caster reaches combat with known spell and slot")
	_assert(caster.has_feature("wizard_spellcasting") and caster.has_feature("wizard_arcane_recovery") and caster.get_spellcasting_capacity("cantrips") == 3 and caster.get_spellcasting_capacity("prepared_spells") == 4, "Wizard shares spellcasting capacity and retains Arcane Recovery")
	var high_wizard: Character = _fresh_char("High Wizard", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 12, "CHA": 10})
	while high_wizard.level < 20:
		high_wizard.level_up()
	_assert(high_wizard.get_spellcasting_capacity("cantrips") == 5 and high_wizard.get_spellcasting_capacity("prepared_spells") == 25 and high_wizard.spell_slots.get("9", 0) == 1 and high_wizard.has_feature("wizard_spell_mastery") and high_wizard.has_feature("wizard_signature_spells"), "Wizard reaches level-20 capacities, slot progression, Spell Mastery, and Signature Spells")
	_assert(CombatAction.spell_damage_formula(high_wizard, DataLoader.get_spell("fire_bolt")) == "4d10" and CombatAction.spell_damage_formula(high_wizard, DataLoader.get_spell("ray_of_frost")) == "4d8", "Fire Bolt and Ray of Frost scale through all four official cantrip tiers")
	high_wizard.wizard_spellbook_pending = 1
	_assert(ClassProgression.choose_wizard_spellbook(high_wizard, ["cone_of_cold"]), "level-20 Wizard can learn a level-5 spell from its class catalog")
	var cone_target: Character = _fresh_char("Cone Target", "human", "fighter", {"STR": 10, "DEX": 8, "CON": 8, "INT": 10, "WIS": 10, "CHA": 10})
	var cone_spell: Dictionary = DataLoader.get_spell("cone_of_cold")
	_assert(cone_spell.get("cone_size", 0) == 12 and cone_spell.get("effects", [])[0].get("size", 0) == 12 and cone_spell.get("rules_source", "") == "SRD5.2.1", "Cone of Cold records the SRD's 60-foot cone as 12 five-foot hexes")
	_assert(EventResolver.resolve_area_selection(cone_spell.get("effects", [])[0]).get("success", false), "Area selection accepts a valid 12-hex Cone of Cold")
	var cone_cast := CombatAction.resolve_spell(high_wizard, cone_target, cone_spell)
	_assert(cone_cast.get("success", false) and int(cone_cast.get("damage", 0)) > 0, "Cone of Cold resolves its Constitution save and cold damage through the production spell resolver")
	high_wizard.wizard_spellbook.assign(["magic_missile", "scorching_ray", "fireball", "counterspell"])
	high_wizard.wizard_spellbook_pending = 40
	_assert(ClassProgression.choose_wizard_spell_mastery(high_wizard, 1, "magic_missile") and ClassProgression.choose_wizard_spell_mastery(high_wizard, 2, "scorching_ray"), "Wizard Spell Mastery accepts one eligible level-1 and one level-2 book spell")
	_assert(not ClassProgression.choose_wizard_spell_mastery(high_wizard, 1, "scorching_ray") and "magic_missile" in high_wizard.known_spells and "scorching_ray" in high_wizard.known_spells, "Spell Mastery rejects mismatched spell levels and automatically prepares both choices")
	_assert(high_wizard.has_free_spell_cast("magic_missile") and high_wizard.spend_free_spell_cast("magic_missile") and high_wizard.has_free_spell_cast("magic_missile"), "Spell Mastery casts at will without spending a limited free-cast use")
	var mastery_upcast_slots_before := int(high_wizard.spell_slots.get("2", 0))
	var mastery_upcast := CombatAction.spend_spell_slot(high_wizard, DataLoader.get_spell("magic_missile"), 2)
	_assert(mastery_upcast.get("success", false) and int(mastery_upcast.get("slot_level", 0)) == 2 and int(high_wizard.spell_slots.get("2", 0)) == mastery_upcast_slots_before - 1 and high_wizard.has_free_spell_cast("magic_missile"), "Wizard can choose a level-2 slot to upcast a Spell Mastery spell without losing its at-will cast")
	_assert(ClassProgression.choose_wizard_signature_spells(high_wizard, ["fireball", "counterspell"]) and "fireball" in high_wizard.known_spells and "counterspell" in high_wizard.known_spells, "Signature Spells accepts two level-3 book spells, including a reaction spell, and prepares them")
	_assert(high_wizard.has_free_spell_cast("fireball") and high_wizard.spend_free_spell_cast("fireball") and not high_wizard.has_free_spell_cast("fireball"), "Signature Spell consumes its individual free cast")
	high_wizard.short_rest()
	_assert(high_wizard.has_free_spell_cast("fireball"), "Signature Spell use returns after a Short Rest")
	high_wizard.spend_free_spell_cast("fireball")
	high_wizard.long_rest()
	_assert(high_wizard.has_free_spell_cast("fireball"), "Signature Spell use also returns after a Long Rest")
	var mastery_roundtrip := Character.new()
	mastery_roundtrip.from_dict(high_wizard.to_dict())
	_assert(mastery_roundtrip.wizard_spell_mastery == high_wizard.wizard_spell_mastery and mastery_roundtrip.wizard_signature_spells == high_wizard.wizard_signature_spells and mastery_roundtrip.has_free_spell_cast("fireball"), "Wizard mastery choices and remaining Signature Spell uses survive character save/load")
	var counterspell_target := _monster_inst("goblin")
	var failed_counterspell_caster: Character = _fresh_char("Counterspell Save Failure", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 8, "INT": 16, "WIS": 12, "CHA": 10})
	failed_counterspell_caster.spell_slots = {"1": 1}
	failed_counterspell_caster.add_modifier("roll", "save:CON", -1000, 4)
	var counterspell_slot_before := int(mastery_roundtrip.spell_slots.get("3", 0))
	var signature_payment: Dictionary = SpellPermissionRules.payment_choices(mastery_roundtrip, "counterspell").filter(func(row): return row.get("_spell_payment_kind") == "free_cast" and row.get("_spell_payment_source_id") == "wizard_signature_spells")[0]
	var signature_decisions := {"counterspell:%s" % mastery_roundtrip.character_name:true, SpellPermissionRules.reaction_key(mastery_roundtrip, "counterspell"):signature_payment}
	var counterspell_result := CombatAction.resolve_spell(failed_counterspell_caster, counterspell_target, DataLoader.get_spell("magic_missile"), true, signature_decisions, [mastery_roundtrip])
	_assert(not counterspell_result.get("success", true) and counterspell_result.get("countered", false) and counterspell_result.get("incoming_spell_slot_refunded", false) and int(failed_counterspell_caster.spell_slots.get("1", 0)) == 1 and not mastery_roundtrip.has_free_spell_cast("counterspell") and not mastery_roundtrip.reaction_available and int(mastery_roundtrip.spell_slots.get("3", 0)) == counterspell_slot_before, "Failed Counterspell Constitution save interrupts the cast, refunds its spell slot, and spends Signature Spell plus the Reaction")
	var saved_counterspell_caster: Character = _fresh_char("Counterspell Save Success", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	saved_counterspell_caster.add_modifier("roll", "save:CON", 1000, 4)
	var slot_only_counterspeller: Character = _fresh_char("Slot Counterspeller", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 12, "INT": 16, "WIS": 12, "CHA": 10})
	SpellPermissionChecks.grant_slot_permission(slot_only_counterspeller, ["counterspell"])
	slot_only_counterspeller.spell_slots = {"4": 1}
	var saved_counterspell_decisions := {"counterspell:%s" % slot_only_counterspeller.character_name: true}
	var counterspell_save_result := CombatAction.resolve_spell(saved_counterspell_caster, counterspell_target, DataLoader.get_spell("magic_missile"), false, saved_counterspell_decisions, [slot_only_counterspeller])
	_assert(counterspell_save_result.get("success", false) and saved_counterspell_decisions.get("counterspell_saved_by", "") == slot_only_counterspeller.character_name and not slot_only_counterspeller.reaction_available and int(slot_only_counterspeller.spell_slots.get("4", 0)) == 0, "A successful Counterspell save lets the incoming spell continue after spending a higher-level slot and Reaction")
	_assert(SpellSupport.is_available(DataLoader.get_spell("counterspell")), "Counterspell is available through its Constitution-save reaction resolver")
	print("COUNTERSPELL_SAVE_AND_REFUND_CHECKS_COMPLETE")
	var fighter: Character = _fresh_char("Fighter", "human", "fighter",
		{"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
	_assert(fighter.has_feature("fighter_second_wind"), "fighter receives curated Second Wind")
	_assert(not fighter.get_feature("fighter_second_wind").get("effects", []).is_empty(), "Second Wind has an executable healing effect")
	_assert(not fighter.use_feature("not_a_real_feature"), "unknown class feature cannot consume an action or resource")
	_assert(fighter.use_feature("fighter_second_wind"), "Second Wind can be consumed once")
	_assert(fighter.use_feature("fighter_second_wind"), "2024 Second Wind has a second use")
	_assert(not fighter.use_feature("fighter_second_wind"), "Second Wind cannot be consumed when exhausted")
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
	_assert(rage_feature.get("uses_per", "") == "long_rest" and int(rage_feature.get("short_rest_recovery", 0)) == 1 and rage_feature.get("effects", []).size() == 3 and rage_feature.get("passive_effects", []).size() == 2, "barbarian Rage has SRD uses, shared ongoing checks and executable effects")
	var barbarian_defense: Dictionary = barbarian.get_feature("barbarian_unarmored_defense")
	_assert(barbarian_defense.get("effects", [])[0].get("type", "") == "unarmored_defense" and barbarian_defense.get("effects", [])[0].get("allows_shield", false), "barbarian Unarmored Defense has a curated shield-compatible AC contract")
	# Supply armor and a shield explicitly; neither is Barbarian starting gear.
	barbarian.inventory.unequip(Inventory.Slot.WEAPON)
	barbarian.inventory.add_item("chain_mail")
	barbarian.inventory.add_item("shield")
	barbarian.inventory.equip(Inventory.Slot.BODY, "chain_mail", true)
	barbarian.inventory.equip(Inventory.Slot.SHIELD, "shield", true)
	barbarian._recalculate_ac()
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
	_assert(armored_monk_ac == 16 and monk.is_unarmored(), "2024 Monk starts without armor or shield")
	monk.inventory.unequip(Inventory.Slot.BODY)
	monk.inventory.unequip(Inventory.Slot.SHIELD)
	monk._recalculate_ac()
	_assert(monk.get_ac() == 16, "Monk Unarmored Defense uses Dexterity plus Wisdom when armor and shield are removed")
	monk.inventory.add_item("leather_armor")
	monk.inventory.add_item("shield")
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
	_assert(martial_arts.get("effects", [])[0].get("type", "") == "martial_arts" and bonus_unarmed.get("effects", [])[0].get("type", "") == "unarmed_attack", "Martial Arts is passive; the separate bonus strike resolves attacks")
	_assert(martial_arts.get("type", "") == "passive" and bonus_unarmed.get("action_cost", "") == "bonus_action", "Martial Arts is not exposed as a duplicate bonus action")
	_assert(flurry.get("effects", [])[0].get("type", "") == "unarmed_attack" and flurry.get("effects", [])[0].get("count", 0) == 2, "Monk Flurry of Blows is a two-strike unarmed contract")
	_assert(flurry.get("uses_per", "") == "turn" and flurry.get("action_cost", "") == "bonus_action", "Flurry of Blows restores per turn and spends a bonus action")
	var paladin: Character = _fresh_char("Smiter", "human", "paladin",
		{"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	paladin.level_up()
	var lay_on_hands: Dictionary = paladin.get_feature("paladin_lay_on_hands")
	_assert(not lay_on_hands.is_empty() and lay_on_hands.get("uses_per", "") == "long_rest" and lay_on_hands.get("action_cost", "") == "bonus_action", "Paladin Lay on Hands uses its 2024 Bonus Action and Long Rest cadence")
	_assert(paladin.feature_uses.get("paladin_lay_on_hands", 0) == 10, "level-2 Lay on Hands starts with ten healing points")
	var paladin_casting: Dictionary = paladin.get_feature("paladin_spellcasting")
	_assert(not paladin_casting.is_empty() and paladin_casting.get("effects", [])[0].get("type", "") == "spellcasting", "Paladin spellcasting uses the shared prepared-spell path")
	var mastery: Dictionary = paladin.get_feature("paladin_weapon_mastery")
	_assert(mastery.get("effects", [])[0].get("type", "") == "weapon_mastery", "Paladin weapon mastery uses the shared saved-choice path")
	var defense_paladin: Character = _fresh_char("Defense Paladin", "human", "paladin",
		{"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	defense_paladin.level_up()
	var chose_defense := ClassProgression.choose_feature_option(defense_paladin, "paladin_fighting_style", "defense")
	_assert(chose_defense and defense_paladin.get_ac() == defense_paladin.base_ac + 1, "Paladin Defense style uses the shared saved choice and Fighter armor rule")
	var archery_paladin: Character = _fresh_char("Archery Paladin", "human", "paladin",
		{"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	archery_paladin.level_up()
	ClassProgression.choose_feature_option(archery_paladin, "paladin_fighting_style", "archery")
	_assert(archery_paladin.get_attack_style_bonus({"properties": ["ranged"]}) == 2, "Paladin Archery style uses the shared ranged attack bonus")
	var weapon_style_paladin: Character = _fresh_char("Weapon Style Paladin", "human", "paladin",
		{"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	weapon_style_paladin.level_up()
	ClassProgression.choose_feature_option(weapon_style_paladin, "paladin_fighting_style", "great_weapon_fighting")
	weapon_style_paladin.inventory.unequip(Inventory.Slot.SHIELD)
	var style_damage_detail := {"dice_terms": [{"results": [1, 2, 4], "kept": [true, true, true], "subtotal": 7}]}
	var style_damage_gain := FighterRules.weapon_damage(weapon_style_paladin, {"id": "greatsword", "properties": ["two_handed"]}, style_damage_detail)
	_assert(style_damage_gain == 3 and style_damage_detail["dice_terms"][0]["results"] == [3, 3, 4], "Paladin Great Weapon Fighting reuses the shared damage-die rule")
	var two_weapon_paladin: Character = _fresh_char("Two Weapon Paladin", "human", "paladin",
		{"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	two_weapon_paladin.level_up()
	var chose_two_weapon := ClassProgression.choose_feature_option(two_weapon_paladin, "paladin_fighting_style", "two_weapon_fighting")
	_assert(chose_two_weapon and FighterRules.has_style(two_weapon_paladin, "two_weapon_fighting"), "Paladin Two-Weapon Fighting persists in the shared style choice")
	var blessed_paladin: Character = _fresh_char("Blessed Paladin", "human", "paladin",
		{"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	blessed_paladin.level_up()
	var chose_blessed := ClassProgression.choose_feature_option(blessed_paladin, "paladin_fighting_style", "blessed_warrior")
	var blessed_cantrips: Array[String] = ["guidance", "sacred_flame", "bless", "cure_wounds", "command"]
	var blessed_spells_chosen := ClassProgression.choose_spell_selection(blessed_paladin, blessed_cantrips)
	var restored_blessed_paladin := Character.new()
	restored_blessed_paladin.from_dict(blessed_paladin.to_dict())
	_assert(chose_blessed and blessed_spells_chosen and blessed_paladin.get_spellcasting_capacity("cantrips") == 2 and "cleric" in blessed_paladin.get_spell_list_ids(), "Blessed Warrior adds two Cleric cantrips through shared spell-list and capacity choices")
	_assert("guidance" in restored_blessed_paladin.known_spells and ClassProgression.saved_choices_error(blessed_paladin.to_dict()).is_empty(), "Blessed Warrior spell choices remain valid after save reconstruction")
	var aura_paladin: Character = _fresh_char("Aura Paladin", "human", "paladin", {"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	for _level in range(5):
		aura_paladin.level_up()
	var aura_ally: Character = _fresh_char("Aura Ally", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	var aura_outsider: Character = _fresh_char("Aura Outsider", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	var aura_party: Array[Dictionary] = [
		{"character": aura_paladin, "hex_position": Vector2i.ZERO},
		{"character": aura_ally, "hex_position": Vector2i(2, 0)},
		{"character": aura_outsider, "hex_position": Vector2i(3, 0)},
	]
	AuraRules.refresh_party_context(aura_party)
	_assert(AuraRules.saving_throw_bonus(aura_paladin) == 3 and AuraRules.saving_throw_bonus(aura_ally) == 3 and AuraRules.saving_throw_bonus(aura_outsider) == 0, "Aura of Protection reaches the Paladin and allies through 10 feet")
	seed(317)
	var aura_save_with_bonus := aura_ally.make_saving_throw("DEX")
	aura_party[0]["hex_position"] = Vector2i(10, 0)
	AuraRules.refresh_party_context(aura_party)
	seed(317)
	var aura_save_without_bonus := aura_ally.make_saving_throw("DEX")
	_assert(aura_save_with_bonus - aura_save_without_bonus == 3, "Aura of Protection adds its bonus through the shared saving-throw path")
	aura_party[0]["hex_position"] = Vector2i.ZERO
	AuraRules.refresh_party_context(aura_party)
	aura_ally.add_condition("frightened", 2)
	_assert(aura_ally.has_condition("frightened"), "Aura of Courage is not present before Paladin level 10")
	for _level in range(4):
		aura_paladin.level_up()
	AuraRules.refresh_party_context(aura_party)
	_assert(not aura_ally.has_condition("frightened"), "Aura of Courage suppresses Frightened for an ally in Aura of Protection")
	aura_paladin.add_condition("incapacitated", 1)
	_assert(AuraRules.saving_throw_bonus(aura_ally) == 0 and aura_ally.has_condition("frightened"), "Paladin auras end while their source is Incapacitated")
	aura_paladin.remove_condition("incapacitated")
	for _level in range(8):
		aura_paladin.level_up()
	aura_party[1]["hex_position"] = Vector2i(6, 0)
	aura_party[2]["hex_position"] = Vector2i(7, 0)
	AuraRules.refresh_party_context(aura_party)
	_assert(AuraRules.saving_throw_bonus(aura_ally) == 3 and AuraRules.saving_throw_bonus(aura_outsider) == 0 and not aura_ally.has_condition("frightened"), "Level 18 Aura Expansion extends protection and courage to 30 feet")
	aura_party[1]["hex_position"] = Vector2i(7, 0)
	AuraRules.refresh_party_context(aura_party)
	_assert(aura_ally.has_condition("frightened"), "Aura of Courage ends when an ally leaves the expanded aura")
	var steed_paladin: Character = _fresh_char("Steed Paladin", "human", "paladin", {"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	for _level in range(4):
		steed_paladin.level_up()
	_assert(steed_paladin.has_free_spell_cast("find_steed") and steed_paladin.spend_free_spell_cast("find_steed") and not steed_paladin.has_free_spell_cast("find_steed"), "Faithful Steed provides one saved free Find Steed cast per Long Rest")
	steed_paladin.long_rest()
	_assert(steed_paladin.has_free_spell_cast("find_steed"), "Faithful Steed restores its free cast on a Long Rest")
	var find_steed_spell := DataLoader.get_spell("find_steed")
	_assert(find_steed_spell.get("casting_time", "") == "action" and find_steed_spell.get("range", 0) == 6 and find_steed_spell.get("summoned_creature", {}).get("kind", "") == "otherworldly_steed", "Find Steed's curated spell record replaces the legacy imported version")
	var fey_steed := PaladinRules.create_find_steed_state(steed_paladin, find_steed_spell, 2, "fey", "dire wolf")
	var fey_steed_state: Dictionary = fey_steed.get("state", {})
	_assert(fey_steed.get("success", false) and fey_steed_state.get("armor_class", 0) == 12 and fey_steed_state.get("max_hp", 0) == 25 and fey_steed_state.get("fly_speed_feet", -1) == 0, "Find Steed level 2 creates the correct non-flying base stat block")
	PaladinRules.update_find_steed_hit_points(steed_paladin, 9)
	var steed_save_copy := Character.new()
	steed_save_copy.from_dict(steed_paladin.to_dict())
	_assert(PaladinRules.find_steed_state(steed_save_copy).get("current_hp", 0) == 9, "The persistent steed and its remaining Hit Points survive owner save reconstruction")
	_assert(PaladinRules.set_find_steed_mounted(steed_paladin, true) and PaladinRules.find_steed_is_mounted(steed_paladin), "A living bonded steed records mounted state on its Paladin owner")
	var mounted_steed_save := Character.new()
	mounted_steed_save.from_dict(steed_paladin.to_dict())
	_assert(PaladinRules.find_steed_is_mounted(mounted_steed_save) and PaladinRules.set_find_steed_mounted(mounted_steed_save, false) and not PaladinRules.find_steed_is_mounted(mounted_steed_save), "Mounted transport survives owner save reconstruction and can be cleared on dismount")
	var upgraded_steed := PaladinRules.create_find_steed_state(steed_paladin, find_steed_spell, 4, "celestial", "horse")
	var upgraded_steed_state: Dictionary = upgraded_steed.get("state", {})
	_assert(upgraded_steed.get("success", false) and upgraded_steed_state.get("armor_class", 0) == 14 and upgraded_steed_state.get("max_hp", 0) == 45 and upgraded_steed_state.get("fly_speed_feet", 0) == 60, "Find Steed replaces the prior spirit and gains the level 4 AC, Hit Points, and Fly Speed")
	var steed_features := PaladinRules.find_steed_features(fey_steed_state)
	_assert(steed_features.size() == 2 and steed_features[0].get("id", "") == "otherworldly_steed_slam" and steed_features[1].get("id", "") == "otherworldly_steed_fey_step" and steed_features[1].get("action_cost", "") == "bonus_action", "Otherworldly Steed exposes its shared Action Slam and type-specific Bonus Action")
	var steed_attacker: Character = _fresh_char("Fey Steed", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	var slam_target := _monster_inst("goblin")
	slam_target["armor_class"] = -100
	var slam_result := PaladinRules.resolve_steed_slam(steed_paladin, steed_attacker, slam_target, "fey", 2)
	_assert(slam_result.get("hit", false) and int(slam_result.get("damage", 0)) >= 3 and int(slam_result.get("damage", 0)) <= 20 and slam_result.get("damage_type", "") == "psychic", "Otherworldly Slam uses the owner's spell attack bonus, shared damage roll, and Fey damage type")
	steed_attacker.current_hp -= 5
	var bonded_healing := PaladinRules.apply_life_bond(steed_paladin, steed_attacker, 3)
	_assert(bonded_healing == 3 and steed_attacker.current_hp == steed_attacker.max_hp - 2, "Life Bond copies actual Paladin spell healing to the steed and respects its Hit Point maximum")
	_assert(PaladinRules.mark_find_steed_ability_used(steed_paladin) and not PaladinRules.mark_find_steed_ability_used(steed_paladin), "The steed's type-specific Bonus Action can be used once per Long Rest")
	var steed_owner_save := Character.new()
	steed_owner_save.from_dict(steed_paladin.to_dict())
	steed_owner_save.long_rest()
	_assert(not PaladinRules.find_steed_state(steed_owner_save).get("long_rest_ability_used", true), "A Long Rest restores the bonded steed's Bonus Action across owner save data")
	paladin.level_up()
	_assert(paladin.get_feature_max_uses("paladin_channel_divinity") == 2, "Paladin Channel Divinity begins with two uses at level 3")
	paladin.feature_uses["paladin_channel_divinity"] = 0
	paladin.short_rest()
	_assert(paladin.feature_uses["paladin_channel_divinity"] == 1, "Paladin Channel Divinity restores one use on a Short Rest")
	paladin.long_rest()
	_assert(paladin.feature_uses["paladin_channel_divinity"] == 2, "Paladin Channel Divinity fully restores on a Long Rest")
	_assert(paladin.get_feature("paladin_divine_sense").is_empty(), "2014 Divine Sense is not granted as a separate 2024 class feature")
	var radiant_paladin: Character = _fresh_char("Radiant Paladin", "human", "paladin",
		{"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	for _level in range(10):
		radiant_paladin.level_up()
	_assert(radiant_paladin.get_feature_max_uses("paladin_channel_divinity") == 3, "Paladin Channel Divinity grows to three uses at level 11")
	var melee_target := _monster_inst("goblin")
	var first_rider := CombatAction.resolve_weapon_damage_riders(radiant_paladin, melee_target, {}, {"range": 1})
	var second_target := _monster_inst("goblin")
	var second_rider := CombatAction.resolve_weapon_damage_riders(radiant_paladin, second_target, {}, {"range": 1})
	var ranged_target := _monster_inst("goblin")
	var ranged_rider := CombatAction.resolve_weapon_damage_riders(radiant_paladin, ranged_target, {}, {"range": 6})
	_assert(first_rider.size() == 1 and second_rider.size() == 1 and first_rider[0].get("damage_type", "") == "radiant", "Paladin Radiant Strikes adds radiant damage to each melee hit through the shared rider path")
	_assert(ranged_rider.is_empty(), "Paladin Radiant Strikes does not add damage to ranged weapon hits")
	var bard: Character = _fresh_char("Bard", "human", "bard",
		{"STR": 10, "DEX": 14, "CON": 12, "INT": 12, "WIS": 10, "CHA": 16})
	var bardic_inspiration: Dictionary = bard.get_feature("bard_bardic_inspiration")
	_assert(bardic_inspiration.get("effects", [])[0].get("type", "") == "bardic_inspiration", "bard Bardic Inspiration has a production die effect")
	var ranger: Character = _fresh_char("Ranger", "human", "ranger",
		{"STR": 12, "DEX": 16, "CON": 12, "INT": 10, "WIS": 14, "CHA": 10})
	var favored_enemy: Dictionary = ranger.get_feature("ranger_favored_enemy")
	_assert(favored_enemy.get("effects", [])[1].get("type", "") == "spell_free_cast" and ranger.has_free_spell_cast("hunters_mark"), "Ranger Favored Enemy provides free Hunter's Mark casts")
	ranger.level_up()
	var ranger_style: Dictionary = ranger.get_feature("ranger_fighting_style")
	_assert(ranger_style.get("effects", [])[0].get("type", "") == "feature_choice", "Ranger Fighting Style uses the shared saved style choice")
	var longbow: Dictionary = DataLoader.get_item("longbow")
	var longsword: Dictionary = DataLoader.get_item("longsword")
	_assert(not ranger_style.is_empty() and not longbow.is_empty() and not longsword.is_empty(), "Ranger receives its shared Fighting Style progression and valid weapon records")
	var rogue: Character = _fresh_char("Rogue", "human", "rogue",
		{"STR": 10, "DEX": 16, "CON": 12, "INT": 12, "WIS": 10, "CHA": 12})
	_assert(rogue.has_feature("rogue_sneak_attack"), "rogue receives curated Sneak Attack")
	_assert(rogue.get_feature("rogue_expertise").get("effects", [])[0].get("count", 0) == 2 and rogue.get_feature("rogue_weapon_mastery").get("effects", [])[0].get("capacity_by_level", {}).get("1", 0) == 2, "Rogue gains two shared Expertise choices and two Weapon Masteries at level 1")
	for skill in ["Stealth", "Acrobatics"]:
		rogue.skill_proficiencies.append(skill)
	_assert(ClassProgression.choose_skill_expertise(rogue, "rogue_expertise", ["Stealth", "Acrobatics"]), "Rogue selects level-1 Expertise through the shared saved-choice path")
	_assert(rogue.get_feature("rogue_sneak_attack").get("effects", [])[0].get("dice_by_level", {}).get("19", "") == "10d6", "Sneak Attack progression reaches 10d6 at level 19")
	rogue.level_up()
	var cunning_action: Dictionary = rogue.get_feature("rogue_cunning_action")
	_assert(not cunning_action.is_empty() and cunning_action.get("action_cost", "") == "bonus_action", "rogue receives a curated Cunning Action bonus action")
	_assert(cunning_action.get("uses_per", "") == "turn" and not cunning_action.get("effects", []).is_empty(), "Cunning Action has a per-turn executable effect")
	var reliable_rogue: Character = _fresh_char("Reliable Talent Rogue", "human", "rogue", {"STR": 10, "DEX": 16, "CON": 12, "INT": 12, "WIS": 10, "CHA": 12})
	for _level in range(6):
		reliable_rogue.level_up()
	reliable_rogue.skill_proficiencies.append("Stealth")
	_assert(reliable_rogue.apply_skill_check_roll_floor(4, "Stealth") == 10 and reliable_rogue.apply_skill_check_roll_floor(4, "History") == 4, "Reliable Talent floor applies only to proficient skills")
	var slippery_rogue: Character = _fresh_char("Slippery Mind Rogue", "human", "rogue", {"STR": 10, "DEX": 16, "CON": 12, "INT": 12, "WIS": 10, "CHA": 12})
	for _level in range(14):
		slippery_rogue.level_up()
	_assert(slippery_rogue.is_proficient_in_save("WIS") and slippery_rogue.is_proficient_in_save("CHA"), "Slippery Mind grants Wisdom and Charisma saving throw proficiency at level 15")

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
	var command_book: Array[String] = ["magic_missile", "shield", "mage_armor", "sleep", "ice_knife", "burning_hands"]
	var command_spells: Array[String] = ["fire_bolt", "ray_of_frost", "light", "magic_missile", "shield", "mage_armor", "sleep"]
	_assert(ClassProgression.choose_wizard_spellbook(command_caster, command_book), "command fixture learns its Wizard spellbook before combat")
	_assert(ClassProgression.choose_spell_selection(command_caster, command_spells), "command fixture prepares the spell it will cast")
	var command_spell := DataLoader.get_spell("magic_missile").duplicate(true)
	command_spell["_source_permission_id"] = "class:" + command_caster.get_spellcasting_feature_id()
	command_spell["_spell_payment_kind"] = "slot"
	_assert(CombatCommand.from_hud_for_character("cast_spell", {"spell": command_spell}, command_caster) != null, "combat command accepts an owned prepared spell with an explicit allowed payment")
	_assert(CombatCommand.from_hud_for_character("cast_spell", {"spell": {"id": "not_a_spell"}}, command_caster) == null, "combat command rejects an inaccessible spell before targeting")
	_assert(CombatCommand.from_hud_for_character("use_feature", {"feature": {"id": "not_a_feature"}}, command_caster) == null, "combat command rejects an unowned feature before mutation")
	command_caster.inventory.add_item("potion_healing")
	_assert(CombatCommand.from_hud_for_character("use_item", {"item": DataLoader.get_item("potion_healing")}, command_caster) != null, "combat command accepts an owned consumable")
	_assert(CombatCommand.from_hud_for_character("use_item", {"item": DataLoader.get_item("potion_greater_healing")}, command_caster) == null, "combat command rejects an unowned consumable")
	command_caster.inventory.add_item("wand_of_magic_missiles")
	command_caster.inventory.add_item("wand_of_magic_missiles")
	var wand_copy_ids: Array[String] = []
	for wand_copy in command_caster.inventory.backpack_instances():
		if str(wand_copy.get("definition_id", "")) == "wand_of_magic_missiles":
			wand_copy_ids.append(str(wand_copy["instance_id"]))
	_assert(command_caster.inventory.equip_instance(Inventory.Slot.HANDS, wand_copy_ids[0]), "the wand fixture equips one exact copy in hand")
	var wand_command := CombatCommand.from_hud_for_character("activate_magic_item", {"instance_id": wand_copy_ids[0], "charges": 3}, command_caster)
	_assert(wand_command != null and int(wand_command.payload.get("spell", {}).get("_selected_spell_slot_level", 0)) == 3, "wand activation validates held-copy identity and maps charges to Magic Missile's upcast level")
	_assert(CombatCommand.from_hud_for_character("activate_magic_item", {"instance_id": wand_copy_ids[1], "charges": 1}, command_caster) == null and CombatCommand.from_hud_for_character("activate_magic_item", {"instance_id": wand_copy_ids[0], "charges": 8}, command_caster) == null, "wand activation rejects a carried-but-not-held copy and an invalid charge count")
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
	_assert(rage_effect_results.size() == 3 and rage_attacker.has_condition("raging") and rage_attacker.get_modifier("stat", "damage:rage") == 2, "Rage effects apply a timed condition, clear concentration and add a shared damage modifier")
	var rage_spell_attempt := CombatAction.resolve_spell(rage_attacker, {}, DataLoader.get_spell("magic_missile"))
	_assert(not rage_spell_attempt.get("success", true) and str(rage_spell_attempt.get("message", "")).contains("cannot cast spells"), "A raging Barbarian cannot cast a spell")
	var monk_for_test: Character = _fresh_char("Patient Defense", "human", "monk",
		{"STR": 12, "DEX": 16, "CON": 12, "INT": 10, "WIS": 16, "CHA": 10})
	monk_for_test.level_up()
	var patient_defense_effects: Array = monk_for_test.get_feature("monk_patient_defense").get("effects", [])
	_assert(patient_defense_effects[0].get("type", "") == "monk_bonus_action", "Patient Defense routes free/paid choices through CombatState, not a free Dodge effect")
	var smiter_for_test: Character = _fresh_char("Smite Test", "human", "paladin",
		{"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	smiter_for_test.level_up()
	smiter_for_test.spell_slots["1"] = 1
	var smite_target: Character = _fresh_char("Smite Target", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	smite_target.base_ac = 0
	smite_target.max_hp = 100
	smite_target.current_hp = 100
	var free_smite := CombatAction.resolve_divine_smite(smiter_for_test, smite_target, 1, true)
	_assert(smiter_for_test.has_feature("paladin_paladins_smite") and "divine_smite" in smiter_for_test.known_spells and DataLoader.get_spell("divine_smite").get("trigger", "") == "after_melee_weapon_or_unarmed_hit", "Paladin's Smite prepares the registered after-hit Divine Smite spell")
	_assert(free_smite.get("success", false) and free_smite.get("damage_formula", "") == "2d8" and smiter_for_test.spell_slots.get("1", 0) == 1 and not smiter_for_test.has_free_spell_cast("divine_smite"), "Paladin's Smite grants one free Divine Smite without spending a spell slot")
	var spent_smite_copy := Character.new()
	spent_smite_copy.from_dict(smiter_for_test.to_dict())
	_assert(not spent_smite_copy.has_free_spell_cast("divine_smite"), "The spent free Divine Smite cast survives save reconstruction")
	smiter_for_test.long_rest()
	_assert(smiter_for_test.has_free_spell_cast("divine_smite"), "Paladin's free Divine Smite cast returns after a Long Rest")
	smiter_for_test.spell_slots["1"] = 1
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
	var upcast_smite_caster: Character = _fresh_char("Upcast Smite", "human", "paladin",
		{"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	upcast_smite_caster.level_up()
	upcast_smite_caster.spell_slots = {"1": 0, "2": 1}
	var fiend_smite_target: Dictionary = _monster_inst("goblin")
	fiend_smite_target["creature_type"] = "fiend"
	fiend_smite_target["current_hp"] = 100
	var upcast_smite := CombatAction.resolve_divine_smite(upcast_smite_caster, fiend_smite_target)
	_assert(upcast_smite.get("success", false) and upcast_smite.get("slot_level", 0) == 2 and upcast_smite.get("damage_formula", "") == "4d8" and upcast_smite_caster.spell_slots.get("2", 0) == 0, "Divine Smite uses the lowest eligible shared spell slot, upcasts, and adds a die against Fiends")
	var undead_smite_target: Dictionary = _monster_inst("goblin")
	undead_smite_target["creature_type"] = "undead"
	undead_smite_target["current_hp"] = 100
	var undead_smite := CombatAction.resolve_divine_smite(upcast_smite_caster, undead_smite_target, 1, true)
	_assert(undead_smite.get("success", false) and undead_smite.get("damage_formula", "") == "3d8", "Divine Smite adds one damage die against Undead")
	var radiant_resistant_target: Character = _fresh_char("Radiant Resistant", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	radiant_resistant_target.max_hp = 100
	radiant_resistant_target.current_hp = 100
	radiant_resistant_target.add_condition("superior_defense", 2)
	upcast_smite_caster.spell_slots = {"1": 1}
	var resistant_smite := CombatAction.resolve_divine_smite(upcast_smite_caster, radiant_resistant_target)
	_assert(resistant_smite.get("success", false) and int(resistant_smite.get("damage", -1)) <= 8, "Divine Smite applies the target's radiant damage resistance")
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
	var ranger_for_test: Character = _fresh_char("Favored Enemy Ranger", "human", "ranger",
		{"STR": 12, "DEX": 16, "CON": 12, "INT": 10, "WIS": 14, "CHA": 10})
	_assert(ranger_for_test.known_spells.has("hunters_mark") and ranger_for_test.has_free_spell_cast("hunters_mark"), "Favored Enemy makes Hunter's Mark always prepared and free-castable")
	for _level in range(4):
		ranger_for_test.level_up()
	_assert(int(ranger_for_test.feature_uses.get("free_spell_cast:ranger_favored_enemy", 0)) == 3, "Favored Enemy free-cast capacity grows at Ranger level 5")
	var mark_target := _monster_inst("goblin")
	mark_target["id"] = "hunters_mark_target"
	mark_target["current_hp"] = 100
	mark_target["max_hp"] = 100
	var hunters_mark_spell: Dictionary = DataLoader.get_spell("hunters_mark")
	ranger_for_test.spell_slots["1"] = 1
	var hunters_mark_blocked_cast := CombatAction.resolve_spell(ranger_for_test, mark_target, hunters_mark_spell, true, {}, [], 1, 90)
	_assert(not SpellSupport.is_available(hunters_mark_spell) and hunters_mark_blocked_cast.get("unavailable", false) and ranger_for_test.spell_slots["1"] == 1 and not mark_target.get("conditions", {}).has("hunters_mark"), "Hunter's Mark refuses unsupported clauses before consuming its slot or marking a target")
	var hunters_mark_result := CombatAction.resolve_hunters_mark(ranger_for_test, mark_target)
	_assert(hunters_mark_result.get("success", false) and mark_target.get("conditions", {}).has("hunters_mark"), "The shared Hunter's Mark condition helper tracks the selected target")
	_assert(hunters_mark_spell.get("rules_source", "") == "SRD 5.2.1" and hunters_mark_spell.get("duration_seconds", 0) == 3600 and hunters_mark_spell.get("upcast", {}).get("concentration_seconds_by_slot_level", {}).get("5+", 0) == 86400, "Hunter's Mark records 2024 force damage, duration, and upcast metadata")
	var mark_damage := CombatAction.resolve_hunters_mark_damage(ranger_for_test, mark_target)
	_assert(mark_damage.get("success", false) and mark_damage.get("damage", 0) >= 1 and mark_damage.get("dice", "") == "1d6" and mark_damage.get("damage_type", "") == "force" and mark_target.get("current_hp", 100) < 100, "Hunter's Mark adds 1d6 force damage to a weapon-hit follow-up")
	for _level in range(15):
		ranger_for_test.level_up()
	_assert(ranger_for_test.has_feature("ranger_foe_slayer"), "Ranger gains Foe Slayer at level 20")
	var epic_mark_target := _monster_inst("goblin")
	epic_mark_target["id"] = "epic_hunters_mark_target"
	epic_mark_target["current_hp"] = 100
	epic_mark_target["max_hp"] = 100
	CombatAction.resolve_hunters_mark(ranger_for_test, epic_mark_target)
	var epic_mark_damage := CombatAction.resolve_hunters_mark_damage(ranger_for_test, epic_mark_target)
	_assert(epic_mark_damage.get("dice", "") == "1d10", "Foe Slayer increases Hunter's Mark damage to 1d10")
	var cleric_spellcasting: Character = _fresh_char("Cleric Spellcasting", "human", "cleric",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 10})
	_assert(ClassProgression.pending_feature_choices(cleric_spellcasting) == ["cleric_divine_order"] and not ClassProgression.choose_feature_option(cleric_spellcasting, "cleric_divine_order", "invalid"), "Cleric Divine Order creates one saved choice and rejects unknown options")
	var protector_cleric: Character = _fresh_char("Protector Cleric", "human", "cleric",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 10})
	_assert(ClassProgression.choose_feature_option(protector_cleric, "cleric_divine_order", "protector") and "martial" in protector_cleric.weapon_proficiencies and "heavy" in protector_cleric.armor_proficiencies, "Protector grants Martial weapons and Heavy Armor through the shared choice operation")
	var protector_save := protector_cleric.to_dict()
	var restored_protector := Character.new()
	restored_protector.from_dict(protector_save)
	var invalid_protector_save := protector_save.duplicate(true)
	invalid_protector_save["feature_choices"]["cleric_divine_order"] = ["invented_option"]
	_assert(ClassProgression.saved_choices_error(protector_save).is_empty() and not ClassProgression.saved_choices_error(invalid_protector_save).is_empty() and restored_protector.feature_choices["cleric_divine_order"] == ["protector"] and "heavy" in restored_protector.armor_proficiencies, "Protector selection survives reconstruction and invalid saved options fail preflight")
	var thaumaturge_cleric: Character = _fresh_char("Thaumaturge Cleric", "human", "cleric",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 10})
	var chose_thaumaturge := ClassProgression.choose_feature_option(thaumaturge_cleric, "cleric_divine_order", "thaumaturge")
	var thaumaturge_check := EventResolver.resolve_skill_check(thaumaturge_cleric, {"skill": "Arcana", "ability": "INT", "dc": 1})
	_assert(chose_thaumaturge and thaumaturge_cleric.get_spellcasting_capacity("cantrips") == 4 and thaumaturge_cleric.get_ability_check_bonus("Arcana") == 3 and thaumaturge_cleric.get_ability_check_bonus("Religion") == 3 and int(thaumaturge_check.get("modifier", 0)) == 3, "Thaumaturge grants an extra cantrip and Wisdom bonuses on Arcana and Religion checks")
	var thaumaturge_spells: Array[String] = ["guidance", "sacred_flame", "resistance", "light", "bless", "cure_wounds", "guiding_bolt", "shield_of_faith"]
	_assert(ClassProgression.choose_spell_selection(thaumaturge_cleric, thaumaturge_spells) and thaumaturge_cleric.known_spells.size() == 8, "Thaumaturge can select its extra cantrip through the shared Cleric spell picker")
	var low_wisdom_cleric: Character = _fresh_char("Low Wisdom Cleric", "human", "cleric",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 8, "CHA": 10})
	ClassProgression.choose_feature_option(low_wisdom_cleric, "cleric_divine_order", "thaumaturge")
	_assert(low_wisdom_cleric.get_ability_check_bonus("Arcana") == 1 and low_wisdom_cleric.get_ability_check_bonus("Athletics") == 0, "Thaumaturge's Arcana and Religion bonus has a +1 minimum and affects no other skills")
	_assert(cleric_spellcasting.get_spellcasting_capacity("cantrips") == 3 and cleric_spellcasting.get_spellcasting_capacity("prepared_spells") == 4 and cleric_spellcasting.known_spells.size() == 6 and not cleric_spellcasting.known_spells.has("thaumaturgy"), "Cleric starts with working recommendations and leaves unavailable cantrip choices pending")
	var cleric_progression_milestones := [
		{"level": 4, "cantrips": 4, "prepared": 7},
		{"level": 10, "cantrips": 5, "prepared": 15},
		{"level": 20, "cantrips": 5, "prepared": 22},
	]
	for milestone in cleric_progression_milestones:
		while cleric_spellcasting.level < int(milestone["level"]):
			cleric_spellcasting.level_up()
		_assert(cleric_spellcasting.get_spellcasting_capacity("prepared_spells") == int(milestone["prepared"]) and cleric_spellcasting.get_spellcasting_capacity("cantrips") == int(milestone["cantrips"]), "Cleric spell-choice capacity scales at level %d" % int(milestone["level"]))
	_assert(cleric_spellcasting.spell_slots.get("5", 0) == 3 and cleric_spellcasting.spell_slots.get("6", 0) == 2 and cleric_spellcasting.spell_slots.get("7", 0) == 2 and cleric_spellcasting.spell_slots.get("8", 0) == 1 and cleric_spellcasting.spell_slots.get("9", 0) == 1, "Cleric levels 19–20 receive the correct 2024 high-level spell slots")
	var cleric_channel: Character = _fresh_char("Cleric Channel Divinity", "human", "cleric",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 10})
	while cleric_channel.level < 2:
		cleric_channel.level_up()
	_assert(cleric_channel.get_feature_max_uses("cleric_channel_divinity") == 2, "Cleric Channel Divinity has two uses at level 2")
	while cleric_channel.level < 6:
		cleric_channel.level_up()
	_assert(cleric_channel.get_feature_max_uses("cleric_channel_divinity") == 3, "Cleric Channel Divinity gains a third use at level 6")
	while cleric_channel.level < 18:
		cleric_channel.level_up()
	_assert(cleric_channel.get_feature_max_uses("cleric_channel_divinity") == 4, "Cleric Channel Divinity gains a fourth use at level 18")
	cleric_channel.feature_uses["cleric_channel_divinity"] = 0
	cleric_channel.short_rest()
	_assert(cleric_channel.feature_uses["cleric_channel_divinity"] == 1, "Cleric recovers one Channel Divinity use on a Short Rest")
	cleric_channel.long_rest()
	_assert(cleric_channel.feature_uses["cleric_channel_divinity"] == 4, "Cleric restores all Channel Divinity uses on a Long Rest")
	var bard_for_test: Character = _fresh_char("Bardic Test Bard", "human", "bard",
		{"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	_assert(bard_for_test.get_spellcasting_capacity("prepared_spells") == 4 and bard_for_test.get_spellcasting_capacity("cantrips") == 2, "Bard Spellcasting exposes its level-1 prepared spell and cantrip limits")
	var spell_choice_bard: Character = _fresh_char("Spell Choice Bard", "human", "bard",
		{"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	_assert(spell_choice_bard.spell_choices_pending and spell_choice_bard.known_spells.size() == 5 and spell_choice_bard.get_spell_option_ids(true).has("mage_hand"), "Bard starts with editable recommended spells and choices from its curated spell list")
	var selected_bard_spells: Array[String] = ["mage_hand", "vicious_mockery", "charm_person", "healing_word", "sleep", "cure_wounds"]
	_assert(ClassProgression.choose_spell_selection(spell_choice_bard, selected_bard_spells) and not spell_choice_bard.spell_choices_pending and spell_choice_bard.known_spells.size() == 6 and ClassProgression.saved_choices_error(spell_choice_bard.to_dict()).is_empty(), "Bard chooses its exact starting spell capacity and saves those choices")
	spell_choice_bard.level_up()
	var next_level_bard_spells: Array[String] = selected_bard_spells.duplicate()
	next_level_bard_spells.append("longstrider")
	_assert(spell_choice_bard.spell_choices_pending and ClassProgression.choose_spell_selection(spell_choice_bard, next_level_bard_spells), "Bard adds the new prepared spell at level 2 while retaining its current selections")
	var restored_spell_bard := Character.new()
	restored_spell_bard.from_dict(spell_choice_bard.to_dict())
	_assert(restored_spell_bard.known_spells.size() == 7 and "longstrider" in restored_spell_bard.known_spells and ClassProgression.saved_choices_error(restored_spell_bard.to_dict()).is_empty(), "Bard spell selections survive save reconstruction")
	var bard_spellcasting_progression: Character = _fresh_char("Spellcasting Progression Bard", "human", "bard",
		{"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	for milestone in [{"level": 4, "prepared": 7, "cantrips": 3}, {"level": 5, "prepared": 9, "cantrips": 3}, {"level": 10, "prepared": 15, "cantrips": 4}, {"level": 18, "prepared": 20, "cantrips": 4}, {"level": 20, "prepared": 22, "cantrips": 4}]:
		while bard_spellcasting_progression.level < int(milestone["level"]):
			bard_spellcasting_progression.level_up()
		_assert(bard_spellcasting_progression.get_spellcasting_capacity("prepared_spells") == int(milestone["prepared"]) and bard_spellcasting_progression.get_spellcasting_capacity("cantrips") == int(milestone["cantrips"]), "Bard Spellcasting capacity scales at level %d" % int(milestone["level"]))
	_assert(bard_spellcasting_progression.has_feature("bard_words_of_creation") and "power_word_heal" in bard_spellcasting_progression.known_spells and "power_word_kill" in bard_spellcasting_progression.known_spells, "Bard level 20 gains Words of Creation and keeps both Power Words prepared outside its normal spell capacity")
	_assert("cleric" in bard_spellcasting_progression.get_spell_list_ids() and bard_spellcasting_progression.get_spell_option_ids(false).has("guiding_bolt"), "Magical Secrets expands Bard spell choices to the Cleric, Druid, and Wizard lists")
	_assert(ClassProgression.pending_epic_boon_choices(bard_spellcasting_progression).has("bard_epic_boon") and not ClassProgression.choose_epic_boon(bard_spellcasting_progression, "bard_epic_boon", "spell_recall", "STR") and ClassProgression.choose_epic_boon(bard_spellcasting_progression, "bard_epic_boon", "spell_recall", "INT"), "Bard Epic Boon can select Spell Recall and enforces its Intelligence, Wisdom, or Charisma increase")
	var spell_recall_seen := false
	for rng_seed in range(1, 40):
		bard_spellcasting_progression.spell_slots["1"] = 1
		seed(rng_seed)
		var recalled_slot := CombatAction.spend_spell_slot(bard_spellcasting_progression, {"level": 1})
		if recalled_slot.get("slot_recalled", false) and bard_spellcasting_progression.spell_slots["1"] == 1:
			spell_recall_seen = true
			break
	_assert(spell_recall_seen, "Boon of Spell Recall preserves a matching level-1 spell slot")
	var words_target: Character = _fresh_char("Words of Creation Target", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	words_target.current_hp = 1
	words_target.add_condition("frightened", 2)
	var power_word_heal := CombatAction.resolve_spell(bard_spellcasting_progression, words_target, DataLoader.get_spell("power_word_heal"))
	_assert(power_word_heal.get("success", false) and words_target.current_hp == words_target.max_hp and not words_target.has_condition("frightened"), "Power Word Heal restores all Hit Points and ends supported conditions")
	var power_word_victim: Character = _fresh_char("Words of Creation Victim", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	power_word_victim.current_hp = 100
	var power_word_kill := CombatAction.resolve_spell(bard_spellcasting_progression, power_word_victim, DataLoader.get_spell("power_word_kill"))
	_assert(power_word_kill.get("killed", false) and not power_word_victim.is_alive, "Power Word Kill defeats a creature with 100 Hit Points or fewer")
	var bard_progression: Character = _fresh_char("Expertise Test Bard", "human", "bard",
		{"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	while bard_progression.level < 9:
		bard_progression.level_up()
	bard_progression.skill_proficiencies.append_array(["Performance", "Persuasion", "History"])
	_assert(ClassProgression.choose_skill_expertise(bard_progression, "bard_expertise_2", ["Performance", "Persuasion"]) and ClassProgression.choose_skill_expertise(bard_progression, "bard_expertise_9", ["History", "Arcana"]), "Bard selects Expertise at levels 2 and 9 from proficient skills")
	_assert(bard_progression.get_skill_proficiency_bonus("Performance") == bard_progression.proficiency_bonus * 2 and bard_progression.get_skill_proficiency_bonus("Stealth") == int(floor(float(bard_progression.proficiency_bonus) / 2.0)), "Expertise and Jack of All Trades use shared skill bonus calculations")
	var bard_choice_save := bard_progression.to_dict()
	var restored_bard := Character.new()
	restored_bard.from_dict(bard_choice_save)
	_assert(ClassProgression.saved_choices_error(bard_choice_save).is_empty() and restored_bard.get_skill_proficiency_bonus("History") == restored_bard.proficiency_bonus * 2, "Bard Expertise choices survive save reconstruction")
	var bard_short_rest: Character = _fresh_char("Font Bard", "human", "bard",
		{"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	while bard_short_rest.level < 5:
		bard_short_rest.level_up()
	bard_short_rest.feature_uses["bard_bardic_inspiration"] = 0
	bard_short_rest.short_rest()
	_assert(bard_short_rest.feature_uses["bard_bardic_inspiration"] == bard_short_rest.get_feature_max_uses("bard_bardic_inspiration"), "Font of Inspiration restores Bardic Inspiration on a Short Rest")
	bard_short_rest.feature_uses["bard_bardic_inspiration"] = 0
	bard_short_rest.spell_slots["1"] = 2
	var font_recovery := ClassProgression.restore_resource_from_spell_slot(bard_short_rest, "bard_bardic_inspiration", 1)
	_assert(font_recovery.get("success", false) and bard_short_rest.feature_uses["bard_bardic_inspiration"] == 1 and bard_short_rest.spell_slots["1"] == 1, "Font of Inspiration trades one spell slot for one Bardic Inspiration use without spending an action")
	var font_command := CombatCommand.from_hud_for_character("use_feature", {"feature": {"id": "bard_font_of_inspiration", "selected_spell_slot_level": 1}}, bard_short_rest)
	_assert(font_command != null and int(font_command.payload.get("feature", {}).get("selected_spell_slot_level", 0)) == 1, "The free Font of Inspiration command retains the chosen slot level after ownership validation")
	bard_short_rest.feature_uses["bard_bardic_inspiration"] = bard_short_rest.get_feature_max_uses("bard_bardic_inspiration")
	var font_full_slot_count := int(bard_short_rest.spell_slots["1"])
	var font_full_recovery := ClassProgression.restore_resource_from_spell_slot(bard_short_rest, "bard_bardic_inspiration", 1)
	_assert(not font_full_recovery.get("success", false) and int(bard_short_rest.spell_slots["1"]) == font_full_slot_count, "Font of Inspiration cannot spend a spell slot when Bardic Inspiration is already full")
	var bard_superior: Character = _fresh_char("Superior Inspiration Bard", "human", "bard",
		{"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	while bard_superior.level < 18:
		bard_superior.level_up()
	bard_superior.feature_uses["bard_bardic_inspiration"] = 0
	var superior_recovery := ClassProgression.apply_initiative_resource_recovery(bard_superior)
	_assert(superior_recovery.get("bard_bardic_inspiration", 0) == 2 and bard_superior.feature_uses["bard_bardic_inspiration"] == 2, "Superior Inspiration restores Bardic Inspiration to two uses at Initiative")
	var countercharm_bard: Character = _fresh_char("Countercharm Bard", "human", "bard",
		{"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 20})
	while countercharm_bard.level < 20:
		countercharm_bard.level_up()
	var charmed_target: Character = _fresh_char("Charm Target", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 1, "CHA": 10})
	var charm_save_result := CombatAction.resolve_spell(countercharm_bard, charmed_target, DataLoader.get_spell("charm_person"), false, {"countercharm:%s" % countercharm_bard.character_name: true}, [countercharm_bard])
	_assert(charm_save_result.get("countercharm_used", false) and charm_save_result.get("condition", "") == "charmed" and charmed_target.has_condition("charmed") and not countercharm_bard.reaction_available, "Countercharm rerolls a failed Charm Person save with Advantage and spends the Bard's Reaction")
	_assert(charm_save_result.get("damage", -1) == 0, "A non-damaging charm spell does not invent damage dice")
	var inspired_ally: Character = _fresh_char("Inspired Ally", "human", "fighter",
		{"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
	bard_for_test.feature_uses["bard_bardic_inspiration"] = 1
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
	_assert(inspiration_attack.get("hit", false) and inspired_ally.feature_uses.has("bardic_inspiration_die"), "Bardic Inspiration is preserved when the D20 Test succeeds")
	var inspiration_miss_target: Character = _fresh_char("Inspiration Miss Target", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	inspiration_miss_target.base_ac = 99
	inspiration_miss_target.max_hp = 100
	inspiration_miss_target.current_hp = 100
	seed(424242)
	var inspiration_after_miss := CombatAction.resolve_weapon_attack(inspired_ally, inspiration_miss_target, {"ability": "STR", "damage": "0", "damage_type": "slashing"}, false, false, {"bardic_inspiration": true})
	_assert(not inspiration_after_miss.get("hit", true) and int(inspiration_after_miss.get("attack_roll", 0)) > 7 and not inspired_ally.feature_uses.has("bardic_inspiration_die"), "Bardic Inspiration is added to a failed attack test and spent after use")
	var inspiration_check_target: Character = _fresh_char("Inspiration Check Target", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	inspiration_check_target.feature_uses["bardic_inspiration_die"] = "1d6"
	var inspiration_check := BardicInspirationRules.apply_to_test(inspiration_check_target, 14, 15, true)
	_assert(inspiration_check.get("used", false) and inspiration_check.get("success", false) and inspiration_check.get("total", 0) >= 15 and not inspiration_check_target.feature_uses.has("bardic_inspiration_die"), "Bardic Inspiration uses the shared D20 Test helper to turn a failed check into a success")
	inspiration_check_target.feature_uses["bardic_inspiration_die"] = "1d6"
	var declined_inspiration_check := BardicInspirationRules.apply_to_test(inspiration_check_target, 14, 15, false)
	_assert(not declined_inspiration_check.get("used", true) and inspiration_check_target.feature_uses.has("bardic_inspiration_die"), "Declining Bardic Inspiration preserves the die after a failed check")
	var dying_inspiration_target: Character = _fresh_char("Inspiration Death Save Target", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	var death_save_inspiration_seen := false
	for rng_seed in range(1, 80):
		dying_inspiration_target.current_hp = 0
		dying_inspiration_target.is_alive = false
		dying_inspiration_target.death_save_successes = 0
		dying_inspiration_target.death_save_failures = 0
		dying_inspiration_target.feature_uses["bardic_inspiration_die"] = "1d12"
		seed(rng_seed)
		var inspired_death_save := dying_inspiration_target.make_death_save(true)
		if inspired_death_save.get("bardic_inspiration_used", false):
			death_save_inspiration_seen = not dying_inspiration_target.feature_uses.has("bardic_inspiration_die")
			break
	_assert(death_save_inspiration_seen, "Bardic Inspiration can improve a failed death save through the shared D20 Test helper")
	var natural_one_inspiration_seen := false
	for rng_seed in range(1, 80):
		dying_inspiration_target.current_hp = 0
		dying_inspiration_target.is_alive = false
		dying_inspiration_target.death_save_successes = 0
		dying_inspiration_target.death_save_failures = 0
		dying_inspiration_target.feature_uses["bardic_inspiration_die"] = "1d12"
		seed(rng_seed)
		var natural_one_death_save := dying_inspiration_target.make_death_save(true)
		if int(natural_one_death_save.get("natural", 0)) == 1:
			natural_one_inspiration_seen = natural_one_death_save.get("failures", 0) == 2 and dying_inspiration_target.feature_uses.has("bardic_inspiration_die")
			break
	_assert(natural_one_inspiration_seen, "A natural 1 remains two death save failures and preserves Bardic Inspiration")
	var inspiration_save_target: Character = _fresh_char("Inspiration Save Target", "human", "fighter",
		{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 1, "CHA": 10})
	inspiration_save_target.feature_uses["bardic_inspiration_die"] = "1d6"
	var inspiration_save := CombatAction.resolve_spell(countercharm_bard, inspiration_save_target, DataLoader.get_spell("charm_person"), false, {"bardic_inspiration": true})
	_assert(inspiration_save.get("bardic_inspiration_used", false) and not inspiration_save_target.feature_uses.has("bardic_inspiration_die"), "Bardic Inspiration is applied through the shared helper to a failed spell saving throw")
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
	var restorer: Character = _fresh_char("Restorer", "human", "paladin", {"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	for _level in range(13):
		restorer.level_up()
	var restoration_target: Character = _fresh_char("Restoration Target", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	restoration_target.max_hp = 20
	restoration_target.current_hp = 5
	restoration_target.add_condition("blinded", 3)
	restoration_target.add_condition("frightened", 2)
	var touch_result := CombatAction.resolve_lay_on_hands(restorer, restoration_target, 10, ["blinded", "frightened"])
	_assert(restorer.has_feature("paladin_restoring_touch") and touch_result.get("success", false) and touch_result.get("healing", 0) == 10 and touch_result.get("conditions_removed", []).size() == 2, "Restoring Touch removes multiple eligible conditions and heals from the shared Lay on Hands pool")
	_assert(not restoration_target.conditions.has("blinded") and not restoration_target.conditions.has("frightened") and restoration_target.current_hp == 15 and restorer.feature_uses.get("paladin_lay_on_hands", 0) == 50, "Restoring Touch spends five pool points per condition plus the Hit Points restored")
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
	var spare_the_dying: Dictionary = DataLoader.get_spell("spare_the_dying")
	var spare_caster: Character = _fresh_char("Spare the Dying Caster", "human", "cleric", {"STR": 10, "DEX": 10, "CON": 12, "INT": 10, "WIS": 16, "CHA": 10})
	var downed_ally: Character = _fresh_char("Downed Ally", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	downed_ally.current_hp = 0
	downed_ally.is_alive = false
	var spare_result := CombatAction.resolve_spell(spare_caster, downed_ally, spare_the_dying)
	_assert(spare_result.get("success", false) and spare_result.get("stable", false) and downed_ally.is_stable and not downed_ally.make_death_save().get("rolled", true), "Spare the Dying stabilizes a downed ally and prevents further Death Saving Throws")
	var stable_copy: Character = _fresh_char("Stable Save Copy", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	stable_copy.from_dict(downed_ally.to_dict())
	_assert(stable_copy.is_stable, "Stable state persists through Character save data")
	downed_ally.take_damage(1)
	_assert(not downed_ally.is_stable and downed_ally.death_save_successes == 0 and downed_ally.death_save_failures == 1, "Damage to a Stable creature resumes Death Saving Throws with one failure")
	downed_ally.heal(1)
	_assert(downed_ally.current_hp == 1 and not downed_ally.is_stable and downed_ally.death_save_failures == 0, "Healing restores a Stable creature and clears its death-save state")
	print("SPARE_THE_DYING_STABILIZATION_CHECKS_COMPLETE")
	var eldritch_blast: Dictionary = DataLoader.get_spell("eldritch_blast")
	var eldritch_caster: Character = _fresh_char("Eldritch Blast Caster", "human", "warlock", {"STR": 10, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 18})
	var eldritch_beam_target := _monster_inst("goblin")
	eldritch_beam_target["armor_class"] = 1
	eldritch_beam_target["current_hp"] = 500
	eldritch_beam_target["max_hp"] = 500
	for beam_level in [1, 5, 11, 17]:
		eldritch_caster.level = beam_level
		eldritch_caster.warlock_invocations.assign(["agonizing_blast:eldritch_blast"] if beam_level >= 5 else [])
		var beams := CombatAction.resolve_spell(eldritch_caster, eldritch_beam_target, eldritch_blast)
		var expected_beams := 1 if beam_level < 5 else 2 if beam_level < 11 else 3 if beam_level < 17 else 4
		var beams_hit := int(beams.get("rays_hit", 0))
		var damage_per_hit_max := 20 if beam_level == 1 else 24
		_assert(beams.get("success", false) and int(beams.get("ray_count", 0)) == expected_beams and int(beams.get("damage", 0)) >= beams_hit * (1 if beam_level == 1 else 5) and int(beams.get("damage", 0)) <= beams_hit * damage_per_hit_max, "Eldritch Blast resolves %d separately rolled beam(s) with per-hit invocation damage at character level %d" % [expected_beams, beam_level])
		if beam_level >= 5:
			_assert(CombatAction.spell_damage_bonus(eldritch_caster, eldritch_blast) == 4, "Agonizing Blast adds Charisma damage to each matching Eldritch Blast beam")
	print("ELDRITCH_BLAST_BEAM_GAMEPLAY_CHECKS_COMPLETE")
	var sight_caster: Character = _fresh_char("Sight Ranger", "human", "ranger",
		{"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 16, "CHA": 10})
	var unseen_target := {"id": "unseen", "name": "Invisible Target", "creature_type": "humanoid", "conditions": {"invisible": 2}, "current_hp": 20, "max_hp": 20, "is_alive": true}
	var sight_spell: Dictionary = DataLoader.get_spell("charm_person")
	_assert(sight_spell.get("requires_target_sight", false) and not CombatAction.validate_spell_target(sight_caster, unseen_target, sight_spell, 10).get("success", true), "sight-required spell rejects an invisible target without Blindsight")
	for ranger_level in 17:
		sight_caster.level_up()
	_assert(sight_caster.has_feature("ranger_feral_senses") and CombatAction.can_perceive_invisible(sight_caster, 30), "Ranger Feral Senses grants production Blindsight within 30 feet")
	_assert(CombatAction.validate_spell_target(sight_caster, unseen_target, sight_spell, 30).get("success", false), "Ranger Blindsight allows a sight-required spell on an invisible target in range")
	_assert(not CombatAction.validate_spell_target(sight_caster, unseen_target, sight_spell, 35).get("success", true), "Ranger Blindsight does not reveal an invisible target beyond 30 feet")
	_assert(CombatAction.can_perceive_invisible({"senses": {"blindsight": 20}}, 20) and not CombatAction.can_perceive_invisible({"senses": {"blindsight": 20}}, 25), "monster Blindsight uses its listed range")
	var sphere_selection := EventResolver.resolve_area_selection({"type": "area_selection", "shape": "sphere", "radius": 2})
	_assert(sphere_selection.get("success", false) and sphere_selection.get("type", "") == "area_selection" and not sphere_selection.get("persistent", true), "area selection returns a transient validated sphere result")
	var cube_selection := EventResolver.resolve_area_selection({"type": "area_selection", "shape": "cube", "size": 3})
	_assert(cube_selection.get("success", false) and cube_selection.get("shape", "") == "cube" and cube_selection.get("message", "").begins_with("Selected a Cube"), "area selection validates and identifies a directional cube")
	var invalid_selection := EventResolver.resolve_area_selection({"type": "area_selection", "shape": "sphere", "radius": 0})
	_assert(not invalid_selection.get("success", true), "area selection rejects an invalid radius before state mutation")
	var area_grid := HexGrid.new()
	for area_cell in HexUtils.get_hexes_in_range(Vector2i.ZERO, 4):
		var area_tile := HexTile.new()
		area_tile.coord = area_cell
		area_grid.add_tile(area_tile)
	var wall_selection := EventResolver.resolve_area_selection({"type": "area_selection", "shape": "line", "size": 12})
	var invalid_wall_selection := EventResolver.resolve_area_selection({"type": "area_selection", "shape": "line", "size": 13})
	var wall_spell: Dictionary = DataLoader.get_spell("wall_of_fire")
	var wall_cast := SpellCastContext.new()
	wall_cast.spell = wall_spell
	wall_cast.area_selection = SpellCastTargeting._area_selection_for_spell(wall_cast, wall_spell)
	wall_cast.target_type = "area"
	wall_cast.players = [{"character": sight_caster, "hex_position": Vector2i.ZERO}]
	wall_cast.player_index = 0
	wall_cast.grid = area_grid
	wall_cast.target_coord = Vector2i.ZERO
	wall_cast.command_selection = [Vector2i(3, 0)]
	SpellCastTargeting.collect_targets(wall_cast)
	_assert(SpellSupport.is_available(wall_spell) and wall_selection.get("success", false) and wall_selection.get("shape", "") == "line" and wall_cast.targets.size() == 4 and wall_cast.targets.front() == Vector2i.ZERO and wall_cast.targets.back() == Vector2i(3, 0) and not invalid_wall_selection.get("success", true), "Wall of Fire is castable and targets an endpoint-selected line up to 60 feet long")
	var area_centers: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	var union_area := SpellCastTargeting.union_sphere_targets(area_centers, 1, area_grid)
	var first_sphere := Targeting.get_sphere_targets(area_centers[0], 1, area_grid)
	var separate_area_size := first_sphere.size()
	for area_hex in Targeting.get_sphere_targets(area_centers[1], 1, area_grid):
		if area_hex not in first_sphere:
			separate_area_size += 1
	_assert(union_area.size() == separate_area_size and SpellCastTargeting.are_legal_area_centers(area_centers, 2, Vector2i.ZERO, 3, area_grid), "Multi-sphere area selection returns overlapping hexes once and accepts distinct in-range centers")
	_assert(not SpellCastTargeting.are_legal_area_centers([Vector2i.ZERO, Vector2i.ZERO], 2, Vector2i.ZERO, 3, area_grid) and not SpellCastTargeting.are_legal_area_centers([Vector2i.ZERO, Vector2i(4, 0)], 2, Vector2i.ZERO, 3, area_grid), "Multi-sphere area selection rejects repeated or out-of-range centers")
	area_grid.free()
	var chain_grid := HexGrid.new()
	for chain_cell in HexUtils.get_hexes_in_range(Vector2i.ZERO, 20):
		var chain_tile := HexTile.new()
		chain_tile.coord = chain_cell
		chain_grid.add_tile(chain_tile)
	var legal_chain: Array[Vector2i] = [Vector2i(1, 0), Vector2i(6, 0), Vector2i(-5, 0)]
	var broken_chain: Array[Vector2i] = [Vector2i(1, 0), Vector2i(8, 0), Vector2i(15, 0)]
	_assert(SpellCastTargeting.are_legal_chain_targets(legal_chain, Vector2i.ZERO, 30, 6, 4, chain_grid), "Chain Lightning accepts secondary targets within 30 feet of the first, even when they are farther apart from one another")
	_assert(not SpellCastTargeting.are_legal_chain_targets([Vector2i(1, 0), Vector2i(6, 0), Vector2i(12, 0)], Vector2i.ZERO, 30, 6, 4, chain_grid), "Chain Lightning refuses a target near another secondary target but beyond 30 feet of the first")
	_assert(not SpellCastTargeting.are_legal_chain_targets(broken_chain, Vector2i.ZERO, 30, 6, 4, chain_grid) and not SpellCastTargeting.are_legal_chain_targets([Vector2i(1, 0), Vector2i(6, 0), Vector2i(6, 0)], Vector2i.ZERO, 30, 6, 4, chain_grid), "Chain Lightning rejects unlinked and repeated targets")
	var chain_object := {"id": "fixture:chain-object", "name": "Wooden Door", "kind": "door", "material": "wood", "hp": 10, "max_hp": 10}
	chain_grid.add_entity({"hex_position": Vector2i(1, 1), "world_object": chain_object})
	var object_cast := SpellCastContext.new()
	object_cast.grid = chain_grid
	object_cast.areas = CombatSpellZones.new()
	var chain_lightning: Dictionary = DataLoader.get_spell("chain_lightning")
	_assert(SpellCastTargeting._has_spell_target_at(object_cast, Vector2i(1, 1), chain_lightning) and not SpellCastTargeting._has_spell_target_at(object_cast, Vector2i(2, 2), chain_lightning), "Chain Lightning accepts an authored combat object as a target and rejects an empty hex")
	_assert(SpellCastTargeting._valid_additional_spell_target(object_cast, Vector2i(1, 0), Vector2i(1, 1), chain_lightning, [Vector2i(1, 0)]), "Chain Lightning can select a combat object within 30 feet of the first target")
	var collocated_player := _fresh_char("Collocated Target", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	collocated_player.character_id = "chain-player"
	collocated_player.inventory.add_item("dagger")
	var carried_copy_id := str(collocated_player.inventory.backpack_instances().back()["instance_id"])
	var worn_copy_id := collocated_player.inventory.equipped_instance_id(Inventory.Slot.BODY)
	object_cast.players = [{"character": collocated_player, "hex_position": Vector2i(1, 1)}]
	object_cast.monsters = [{"id": "chain-monster", "name": "Collocated Goblin", "hex_position": Vector2i(1, 1), "is_alive": true}]
	var collocated_options := SpellCastTargeting.chain_target_options(object_cast, Vector2i(1, 1))
	_assert(collocated_options.size() > 3 and not worn_copy_id.is_empty() and SpellCastTargeting.is_chain_target_selected(object_cast, Vector2i(1, 1), "player:chain-player") and SpellCastTargeting.is_chain_target_selected(object_cast, Vector2i(1, 1), "monster:chain-monster") and SpellCastTargeting.is_chain_target_selected(object_cast, Vector2i(1, 1), "object:fixture:chain-object") and SpellCastTargeting.is_chain_target_selected(object_cast, Vector2i(1, 1), "object:%s" % carried_copy_id) and SpellCastTargeting.is_chain_target_selected(object_cast, Vector2i(1, 1), "object:%s" % worn_copy_id), "Chain Lightning exposes distinct creature, world-object, carried-copy and worn-copy targets on one hex")
	var dropped_inventory := Inventory.new()
	dropped_inventory.add_item("wand_of_magic_missiles")
	var dropped_copy: Dictionary = dropped_inventory.backpack_instances()[0]
	var dropped_instance_id := str(dropped_copy["instance_id"])
	dropped_inventory.equip_instance(Inventory.Slot.HANDS, dropped_instance_id)
	var dropped_record := dropped_inventory.drop_equipped_instance(Inventory.Slot.HANDS)
	var dropped_object := CombatObjectRules.make_dropped_item(dropped_record, Vector2i(3, 3), "chain-player")
	chain_grid.add_entity({"hex_position": Vector2i(3, 3), "world_object": dropped_object})
	var dropped_options := SpellCastTargeting.chain_target_options(object_cast, Vector2i(3, 3))
	_assert(str(dropped_object.get("instance_id", "")) == dropped_instance_id and dropped_options.size() == 1 and str(dropped_options[0].get("id", "")) == "object:%s" % dropped_instance_id and CombatObjectRules.by_key(chain_grid, Vector2i(3, 3), dropped_instance_id) == dropped_object, "Dropped combat gear keeps its exact item-copy identity in object targeting")
	var chain_object_target := CombatObjectRules.make_resolution_target(chain_object)
	var chain_object_caster := _fresh_char("Chain Caster", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 12, "INT": 18, "WIS": 10, "CHA": 10})
	var chain_object_context := SpellResolutionContext.new()
	chain_object_context.caster = chain_object_caster
	chain_object_context.target = chain_object_target
	chain_object_context.spell = chain_lightning
	chain_object_context.slot_level = 6
	chain_object_context.has_damage_payload = true
	var chain_object_result := SpellSaveResolver.resolve(chain_object_context)
	CombatObjectRules.sync_resolution_target(chain_object, chain_object_target)
	_assert(SpellSupport.is_available(chain_lightning) and chain_object_result.get("success", false) and chain_object_result.get("saved", true) == false and int(chain_object["hp"]) == 0, "The available Chain Lightning object path damages an unattended object, which fails Dexterity saves without ability scores")
	var meteor_object := {"id": "fixture:meteor-object", "name": "Wooden Chest", "material": "wood", "flammable": true, "hp": 2000, "max_hp": 2000}
	var meteor_object_caster := _fresh_char("Meteor Caster", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 12, "INT": 18, "WIS": 10, "CHA": 10})
	var meteor_object_result := CombatObjectRules.resolve_meteor_swarm(meteor_object_caster, meteor_object, DataLoader.get_spell("meteor_swarm"), 9)
	_assert(SpellSupport.is_available(DataLoader.get_spell("meteor_swarm")) and meteor_object_result.get("success", false) and meteor_object_result.get("ignited", false) and bool(meteor_object.get("burning", false)) and int(meteor_object["hp"]) < 2000, "Meteor Swarm's available object path damages and ignites a flammable object")
	var carried_meteor_object := {"id": "fixture:carried-object", "name": "Carried Torch", "material": "wood", "flammable": true, "carried": true, "hp": 5, "max_hp": 5}
	_assert(not CombatObjectRules.resolve_meteor_swarm(meteor_object_caster, carried_meteor_object, DataLoader.get_spell("meteor_swarm"), 9).get("success", true) and not carried_meteor_object.has("burning"), "Meteor Swarm excludes objects worn or carried by creatures")
	var magical_meteor_object := {"id": "fixture:magical-object", "name": "Magic Ring", "kind": "loose", "contents": [{"definition_id": "ring_of_protection"}], "material": "mixed", "flammable": false, "hp": 5, "max_hp": 5}
	_assert(CombatObjectRules.is_magical(magical_meteor_object) and not CombatObjectRules.resolve_meteor_swarm(meteor_object_caster, magical_meteor_object, DataLoader.get_spell("meteor_swarm"), 9).get("success", true), "Meteor Swarm excludes a loose room object whose item copy is magical")
	chain_grid.free()
	var mixed_damage_caster := _fresh_char("Mixed Damage Caster", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 12, "INT": 18, "WIS": 10, "CHA": 10})
	var mixed_damage_target := {"name": "Fire-Resistant Target", "current_hp": 1000, "max_hp": 1000, "is_alive": true, "creature_type": "humanoid", "conditions": {}, "ability_scores": {"DEX": 10}, "saving_throw_bonuses": {"DEX": -100}, "damage_resistances": ["fire"], "damage_immunities": []}
	var meteor_context := SpellResolutionContext.new()
	meteor_context.caster = mixed_damage_caster
	meteor_context.target = mixed_damage_target
	meteor_context.spell = DataLoader.get_spell("meteor_swarm")
	meteor_context.spell["_save_dc_override"] = 100
	meteor_context.slot_level = 9
	meteor_context.has_damage_payload = true
	var meteor_damage_result := SpellSaveResolver.resolve(meteor_context)
	var meteor_bludgeoning_damage: Array = meteor_damage_result.get("additional_damage_components", [])
	var meteor_fire_settlement := int(floor(float(meteor_damage_result.get("damage_roll", {}).get("final_total", 0) + CombatAction.spell_damage_bonus(mixed_damage_caster, meteor_context.spell)) / 2.0))
	_assert(not meteor_damage_result.get("saved", true) and meteor_bludgeoning_damage.size() == 1 and meteor_bludgeoning_damage[0].get("type", "") == "bludgeoning" and int(meteor_damage_result.get("damage", -1)) == meteor_fire_settlement + int(meteor_bludgeoning_damage[0].get("value", 0)), "Meteor Swarm uses one save and independently applies Fire resistance to its split Bludgeoning damage packet")
	var fireball_effects: Array = DataLoader.get_spell("fireball").get("effects", [])
	var fireball_data: Dictionary = DataLoader.get_spell("fireball")
	var fireball_area_effect := fireball_effects.any(func(effect): return str(effect.get("type", "")) == "area_selection" and int(effect.get("radius", 0)) == 4)
	_assert(fireball_area_effect and int(fireball_data.get("range", 0)) == 30 and int(fireball_data.get("area_radius", 0)) == 4, "production Fireball uses its 150-foot range and 20-foot sphere on five-foot hexes")
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
	var early_spell_ids := ["fire_bolt", "ray_of_frost", "starry_wisp", "magic_missile", "shield", "mage_armor", "sleep", "bless", "cure_wounds", "thunderwave", "hunters_mark"]
	for spell_id in early_spell_ids:
		var early_spell: Dictionary = DataLoader.get_spell(spell_id)
		var has_resolution_payload: bool = not early_spell.get("effects", []).is_empty() or early_spell.has("damage") or early_spell.has("damage_per_dart") or early_spell.has("damage_per_ray") or early_spell.has("save") or str(early_spell.get("attack_type", "none")) != "none"
		_assert(not early_spell.is_empty(), "%s is present in the curated early-spell cohort" % spell_id)
		_assert(str(early_spell.get("casting_time", "")) in DataLoader.VALID_SPELL_CASTING_TIMES and int(early_spell.get("range", -1)) >= 0, "%s has a valid casting time and range" % spell_id)
		_assert(str(early_spell.get("target", "")) in DataLoader.VALID_SPELL_TARGETS, "%s has a valid target contract" % spell_id)
		_assert(has_resolution_payload, "%s has a production resolution payload" % spell_id)
	var sacred_flame: Dictionary = DataLoader.get_spell("sacred_flame")
	var sacred_caster: Character = _fresh_char("Sacred Flame Cleric", "human", "cleric", {"WIS": 16})
	for _level in 4:
		sacred_caster.level_up()
	var sacred_failed_target := _monster_inst("goblin")
	sacred_failed_target["current_hp"] = 100
	sacred_failed_target["saving_throw_bonuses"] = {"DEX": -100}
	var sacred_failed_cast := CombatAction.resolve_spell(sacred_caster, sacred_failed_target, sacred_flame, false, {}, [], 0, 60)
	var sacred_saved_target := _monster_inst("goblin")
	sacred_saved_target["current_hp"] = 100
	sacred_saved_target["saving_throw_bonuses"] = {"DEX": 100}
	var sacred_saved_cast := CombatAction.resolve_spell(sacred_caster, sacred_saved_target, sacred_flame, false, {}, [], 0, 60)
	_assert(sacred_flame.get("school", "") == "evocation" and sacred_flame.get("range", 0) == 12 and sacred_flame.get("save", "") == "DEX" and sacred_flame.get("damage_type", "") == "radiant" and sacred_flame.get("components", []) == ["V", "S"] and sacred_flame.get("duration", "") == "instantaneous" and sacred_flame.get("ignore_cover_on_save", false), "Sacred Flame records its 60-foot Dexterity save and radiant damage contract")
	_assert(sacred_failed_cast.get("success", false) and not sacred_failed_cast.get("saved", true) and int(sacred_failed_cast.get("damage", 0)) >= 2 and int(sacred_failed_cast.get("damage", 0)) <= 16 and sacred_failed_target["current_hp"] < 100 and sacred_saved_cast.get("success", false) and sacred_saved_cast.get("saved", false) and int(sacred_saved_cast.get("damage", 0)) == 0 and sacred_saved_target["current_hp"] == 100, "Sacred Flame damages only on a failed Dexterity save and scales to 2d8 at level 5")
	_assert("sacred_flame" in DataLoader.get_character_class("cleric").get("spell_list_ids", []), "Sacred Flame is available as a Cleric cantrip")
	var scaling_caster: Character = _fresh_char("Spell Scaling", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	for _level in 4:
		scaling_caster.level_up()
	_assert(CombatAction.spell_damage_formula(scaling_caster, {"level": 0, "damage": "1d10", "scaling": {"5": "2d10", "11": "3d10", "17": "4d10"}}) == "2d10", "Cantrip damage uses the highest character-level upgrade threshold")
	_assert(CombatAction.spell_damage_formula(scaling_caster, {"level": 1, "damage": "2d8+3", "upcast": {"starting_level": 1, "damage_per_level": "1d8"}}, 3) == "2d8+3 + 2d8", "Generic spell damage adds the declared extra dice for each higher slot level")
	_assert(CombatAction.spell_damage_formula(scaling_caster, DataLoader.get_spell("burning_hands"), 3) == "3d6 + 2d6" and CombatAction.spell_damage_formula(scaling_caster, DataLoader.get_spell("cone_of_cold"), 7) == "8d8 + 2d8", "Burning Hands and Cone of Cold each add one damage die per slot above their base level")
	print("AREA_SPELL_UPCAST_CHECKS_COMPLETE")
	var circle_death := DataLoader.get_spell("circle_of_death")
	var circle_caster: Character = _fresh_char("Circle Caster", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 12, "CHA": 10})
	var black_pearl_powder: Dictionary = DataLoader.get_item("black_pearl_powder_500gp")
	_assert(circle_death.get("area_radius", 0) == 12 and circle_death.get("material_component_item_id", "") == "black_pearl_powder_500gp" and not circle_death.get("material_component_consumed", false) and SpellSupport.is_available(circle_death), "Circle of Death records its 60-foot Sphere and required, nonconsumed component")
	_assert(not circle_caster.inventory.has_required_spell_component(circle_death), "Circle of Death cannot pass component preflight when the required powder is absent")
	_assert(black_pearl_powder.get("type", "") == "spell_component" and int(black_pearl_powder.get("value", 0)) == 500 and circle_caster.inventory.add_item("black_pearl_powder_500gp") and circle_caster.inventory.has_required_spell_component(circle_death), "Circle of Death accepts the carried 500 GP black-pearl powder")
	_assert(circle_caster.inventory.count_item("black_pearl_powder_500gp") == 1, "Checking a nonconsumed component leaves it in inventory")
	_assert(CombatAction.spell_damage_formula(circle_caster, circle_death, 7) == "8d8 + 2d8", "Circle of Death adds 2d8 per slot above its 6th-level base")
	print("CIRCLE_OF_DEATH_COMPONENT_CHECKS_COMPLETE")
	var power_word_stun: Dictionary = DataLoader.get_spell("power_word_stun")
	var stun_caster: Character = _fresh_char("Power Word Stun Caster", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 12, "CHA": 10})
	var stunned_target := _monster_inst("goblin")
	stunned_target["current_hp"] = 150
	stunned_target["saving_throw_bonuses"] = {"CON": 1000}
	var stun_result := CombatAction.resolve_spell(stun_caster, stunned_target, power_word_stun, false, {}, [], 8, 60)
	_assert(stun_result.get("success", false) and not stun_result.has("saved") and CombatAction.has_condition(stunned_target, "stunned") and FighterRules.monster_speed(stunned_target) == 0, "Power Word Stun applies Stunned at 150 HP without an initial save and sets Speed to 0")
	var stun_source := str(stun_result.get("effect_cast", {}).get("source_id", ""))
	SpellEffects.tick_boundary([stunned_target], SpellEffects.caster_id(stun_caster), "end")
	CombatAction.tick_condition_sources(stunned_target)
	_assert(CombatAction.has_condition(stunned_target, "stunned") and SpellEffects.records(stunned_target).get(stun_source, {}).get("remaining_seconds", 0) == -1, "Power Word Stun persists until its target succeeds on the repeat save")
	var repeat_stun_save := CombatAction.resolve_condition_spell_repeat_save(stunned_target, stun_source)
	_assert(repeat_stun_save.get("success", false) and repeat_stun_save.get("saved", false) and not CombatAction.has_condition(stunned_target, "stunned"), "A successful end-of-turn Constitution save ends Power Word Stun")
	stun_caster.character_id = "power_word_stun_save_caster"
	var saved_stun_target: Character = _fresh_char("Saved Stun Target", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	saved_stun_target.character_id = "power_word_stun_target"
	saved_stun_target.current_hp = 150
	var saved_stun_cast := CombatAction.resolve_spell(stun_caster, saved_stun_target, power_word_stun, false, {}, [], 8, 60)
	var saved_stun_dto := saved_stun_target.to_dict()
	var pws_party_state := {stun_caster.character_id: stun_caster.to_dict(), saved_stun_target.character_id: saved_stun_dto}
	var restored_stun_target: Character = _fresh_char("Restored Stun Target", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	restored_stun_target.from_dict(saved_stun_dto)
	var restored_stun_source := str(saved_stun_cast.get("effect_cast", {}).get("source_id", ""))
	_assert(SpellEffects.saved_state_error(saved_stun_dto).is_empty() and SpellEffects.saved_party_error(pws_party_state).is_empty() and CombatAction.has_condition(restored_stun_target, "stunned") and SpellEffects.records(restored_stun_target).get(restored_stun_source, {}).get("remaining_seconds", 0) == -1, "Power Word Stun's repeat-save grant passes save validation and survives a Character roundtrip")
	var speed_zero_target := _monster_inst("goblin")
	speed_zero_target["current_hp"] = 151
	var speed_zero_cast := CombatAction.resolve_spell(stun_caster, speed_zero_target, power_word_stun, false, {}, [], 8, 60)
	var speed_zero_source := str(speed_zero_cast.get("effect_cast", {}).get("source_id", ""))
	_assert(speed_zero_cast.get("success", false) and FighterRules.monster_speed(speed_zero_target) == 0 and not CombatAction.has_condition(speed_zero_target, "stunned"), "Above 150 HP, Power Word Stun sets Speed to 0 without stunning the target")
	SpellEffects.tick_boundary([speed_zero_target], SpellEffects.caster_id(stun_caster), "start")
	_assert(not CombatAction.has_condition(speed_zero_target, "power_word_stun_speed_zero") and FighterRules.monster_speed(speed_zero_target) > 0 and not SpellEffects.records(speed_zero_target).has(speed_zero_source), "The above-threshold Speed reduction ends at the caster's next turn")
	print("POWER_WORD_STUN_CHECKS_COMPLETE")
	var thunderwave: Dictionary = DataLoader.get_spell("thunderwave")
	_assert(thunderwave.get("effects", [])[0].get("shape", "") == "cube" and SpellSupport.is_available(thunderwave) and thunderwave.get("effects", [])[1].get("on_failed_save", false), "Thunderwave exposes its directional Cube and failed-save push in the playable spell slice")
	print("THUNDERWAVE_CUBE_PUSH_CHECKS_COMPLETE")
	_assert(CombatAction.spell_damage_formula(scaling_caster, DataLoader.get_spell("starry_wisp")) == "2d8", "Starry Wisp receives its level-5 cantrip damage upgrade")
	var sorcerous_burst: Dictionary = DataLoader.get_spell("sorcerous_burst")
	var burst_caster: Character = _fresh_char("Burst Sorcerer", "human", "sorcerer",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 18})
	for _level in 4:
		burst_caster.level_up()
	var burst_target := _monster_inst("goblin")
	burst_target["armor_class"] = 1
	burst_target["current_hp"] = 500
	var burst_result: Dictionary = {}
	for _attempt in 40:
		burst_result = CombatAction.resolve_spell(burst_caster, burst_target, sorcerous_burst)
		if burst_result.get("hit", false):
			break
	var burst_dice: Array = burst_result.get("damage_roll", {}).get("dice_terms", [])
	var burst_die_count := 0
	for term in burst_dice:
		burst_die_count += int(term.get("count", 0))
	_assert(not sorcerous_burst.is_empty() and sorcerous_burst.get("components", []) == ["V", "S"] and sorcerous_burst.get("duration", "") == "instantaneous" and sorcerous_burst.get("damage_type_options", []).size() == 7, "Sorcerous Burst records its components, instant duration, and seven selectable damage types")
	_assert("sorcerous_burst" in DataLoader.get_character_class("sorcerer").get("cantrips_known", []) and "sorcerous_burst" in DataLoader.get_character_class("sorcerer").get("spell_list_ids", []), "Sorcerous Burst is eligible and learnable as a Sorcerer cantrip")
	_assert(CombatAction.spell_damage_formula(burst_caster, sorcerous_burst) == "2d8", "Sorcerous Burst receives its level-5 cantrip scaling")
	_assert(burst_result.get("success", false) and burst_result.get("hit", false) and burst_result.get("damage_type", "acid") == "acid" and burst_die_count >= 2 and burst_die_count <= 6, "Sorcerous Burst resolves a typed hit and caps its exploding damage dice at the Sorcerer's +4 Charisma modifier")
	var poison_spray: Dictionary = DataLoader.get_spell("poison_spray")
	var poison_target := _monster_inst("goblin")
	poison_target["armor_class"] = -100
	poison_target["current_hp"] = 500
	var poison_result: Dictionary = {}
	for _attempt in 40:
		poison_result = CombatAction.resolve_spell(burst_caster, poison_target, poison_spray)
		if bool(poison_result.get("hit", false)):
			break
	var poison_dice: Array = poison_result.get("damage_roll", {}).get("dice_terms", [])
	var poison_die_count := 0
	for term in poison_dice:
		poison_die_count += int(term.get("count", 0))
	_assert(poison_spray.get("school", "") == "necromancy" and poison_spray.get("range", 0) == 6 and poison_spray.get("attack_type", "") == "ranged_spell" and poison_spray.get("components", []) == ["V", "S"] and poison_spray.get("duration", "") == "instantaneous" and not poison_spray.has("save"), "Poison Spray records the 2024 ranged spell attack, 30-foot range, components, and instant duration")
	_assert(poison_result.get("success", false) and poison_result.get("hit", false) and poison_result.get("damage_type", "") == "poison" and poison_die_count == (4 if poison_result.get("crit", false) else 2) and int(poison_result.get("damage", 0)) >= 2 and int(poison_result.get("damage", 0)) <= (48 if poison_result.get("crit", false) else 24) and CombatAction.spell_damage_formula(burst_caster, poison_spray) == "2d12", "Poison Spray applies its level-5 cantrip scaling through the ranged spell attack resolver")
	for poison_class in ["druid", "sorcerer", "warlock", "wizard"]:
		_assert("poison_spray" in DataLoader.get_character_class(poison_class).get("spell_list_ids", []), "Poison Spray is available to %s" % poison_class.capitalize())
	var chill_touch: Dictionary = DataLoader.get_spell("chill_touch")
	var chill_caster: Character = _fresh_char("Chill Touch Sorcerer", "human", "sorcerer", {"CHA": 16})
	for _level in 4:
		chill_caster.level_up()
	var chill_target: Character = _fresh_char("Chill Touch Target", "human", "fighter", {"DEX": 8})
	chill_target.max_hp = 100
	chill_target.current_hp = 100
	chill_target.base_ac = 1
	var chill_result: Dictionary = {}
	for _attempt in 40:
		chill_result = CombatAction.resolve_spell(chill_caster, chill_target, chill_touch, false, {}, [], 0, 5)
		if bool(chill_result.get("hit", false)):
			break
	var chill_source_id := str(chill_caster.get_instance_id())
	var chill_applied := CombatAction.apply_spell_hit_effects(chill_target, chill_touch, chill_result, chill_source_id)
	chill_target.current_hp = 50
	var chill_hp_after_hit := chill_target.current_hp
	var chill_event_healing := EventResolver.apply_effects(chill_target, [{"type": "heal", "value": 10}], chill_caster)
	var chill_hp_after_blocked_heal := chill_target.current_hp
	CombatAction.tick_healing_suppression_for_source(chill_target, chill_source_id)
	var chill_still_blocked := chill_target.heal(10) == 0
	CombatAction.tick_healing_suppression_for_source(chill_target, chill_source_id)
	var chill_recovered := chill_target.heal(10)
	var chill_dict_target := _monster_inst("goblin")
	chill_dict_target["current_hp"] = maxi(1, int(chill_dict_target.get("max_hp", 10)) - 10)
	var chill_dict_hp := int(chill_dict_target["current_hp"])
	CombatAction.apply_spell_hit_effects(chill_dict_target, chill_touch, {"hit": true}, chill_source_id)
	var chill_dict_cleric: Character = _fresh_char("Chill Touch Healer", "human", "cleric", {"WIS": 16})
	var chill_dict_spark := ClericRules.resolve_divine_spark(chill_dict_cleric, chill_dict_target, "heal")
	var vicious_mockery := DataLoader.get_spell("vicious_mockery")
	var mockery_caster: Character = _fresh_char("Mockery Bard", "human", "bard", {"CHA": 18})
	var mockery_target := _monster_inst("goblin")
	var mockery_resolution: Dictionary = {}
	for _attempt in 40:
		mockery_resolution = CombatAction.resolve_spell(mockery_caster, mockery_target, vicious_mockery)
		if not bool(mockery_resolution.get("saved", true)):
			break
	var mockery_effects := CombatAction.apply_spell_failed_save_effects(mockery_target, vicious_mockery, mockery_resolution)
	var mockery_monster_attacker := CombatState._make_temp_monster_character(mockery_target)
	var mockery_attack := mockery_monster_attacker.make_attack_roll()
	CombatState._sync_consumed_monster_attack_conditions(mockery_target, mockery_monster_attacker)
	var mockery_expired_without_attack := _monster_inst("goblin")
	CombatAction.apply_condition(mockery_expired_without_attack, "vicious_mockery_disadvantage", 1)
	CombatState.tick_monster_condition_durations(mockery_expired_without_attack)
	var mockery_expired_attacker := CombatState._make_temp_monster_character(mockery_expired_without_attack)
	var mockery_attack_after_expiry := mockery_expired_attacker.make_attack_roll()
	var chill_miss_target: Character = _fresh_char("Chill Touch Miss Target", "human", "fighter", {"DEX": 8})
	chill_miss_target.base_ac = 1000
	var chill_miss: Dictionary = {}
	for _attempt in 40:
		chill_miss = CombatAction.resolve_spell(chill_caster, chill_miss_target, chill_touch)
		if not bool(chill_miss.get("hit", true)):
			break
	var missed_chill_effects := CombatAction.apply_spell_hit_effects(chill_miss_target, chill_touch, chill_miss, chill_source_id)
	var acid_splash := DataLoader.get_spell("acid_splash")
	var acid_splash_target := _monster_inst("goblin")
	acid_splash_target["saving_throw_bonuses"] = {"DEX": -100}
	var acid_splash_result := CombatAction.resolve_spell(mockery_caster, acid_splash_target, acid_splash, false, {}, [], 0, 60)
	var acid_splash_area := EventResolver.resolve_area_selection(acid_splash.get("effects", [])[0])
	var color_spray := DataLoader.get_spell("color_spray")
	var color_spray_target: Character = _fresh_char("Color Spray Target", "human", "fighter", {"CON": 8})
	var color_spray_resolution: Dictionary = {}
	for _attempt in 40:
		color_spray_resolution = CombatAction.resolve_spell(mockery_caster, color_spray_target, color_spray)
		if not bool(color_spray_resolution.get("saved", true)):
			break
	var color_spray_effects := CombatAction.apply_spell_failed_save_effects(color_spray_target, color_spray, color_spray_resolution)
	var color_spray_attack := color_spray_target.make_attack_roll()
	color_spray_target.tick_conditions()
	var command_spell: Dictionary = DataLoader.get_spell("command")
	var command_target := _monster_inst("goblin")
	command_target["saving_throw_bonuses"] = {"WIS": -100}
	var command_resolution := CombatAction.resolve_spell(mockery_caster, command_target, command_spell, false, {}, [], 1, 60)
	var command_effects := CombatAction.apply_spell_failed_save_effects(command_target, command_spell, command_resolution)
	command_target["saving_throw_bonuses"] = {"WIS": 100}
	var command_saved := CombatAction.resolve_spell(mockery_caster, command_target, command_spell, false, {}, [], 1, 60)
	var blade_ward: Dictionary = DataLoader.get_spell("blade_ward")
	var ward_attacker: Character = _fresh_char("Ward Attacker", "human", "fighter", {"STR": 16})
	var ward_target: Character = _fresh_char("Ward Target", "human", "fighter", {"DEX": 10})
	ward_target.add_condition("blade_ward", 10)
	var warded_attack := {"total": 18, "activity_modifiers": [], "bonus_dice_terms": []}
	var ward_penalty := CombatAction.apply_blade_ward_attack_penalty(ward_target, ward_attacker, warded_attack)
	var unwarded_attack := {"total": 18, "activity_modifiers": [], "bonus_dice_terms": []}
	var no_ward_penalty := CombatAction.apply_blade_ward_attack_penalty(_fresh_char("Unwarded", "human", "fighter", {}), ward_attacker, unwarded_attack)
	var guidance_spell: Dictionary = DataLoader.get_spell("guidance")
	var guidance_target: Character = _fresh_char("Guidance Target", "human", "fighter", {"INT": 12})
	guidance_target.add_condition("guidance", 10)
	guidance_target.guidance_skill = "Arcana"
	var guidance_check := EventResolver.resolve_skill_check(guidance_target, {"skill": "Arcana", "ability": "INT", "dc": 1})
	var unrelated_guidance_check := EventResolver.resolve_skill_check(guidance_target, {"skill": "History", "ability": "INT", "dc": 1})
	var resistance_spell: Dictionary = DataLoader.get_spell("resistance")
	var resistance_target: Character = _fresh_char("Resistance Target", "human", "fighter", {})
	resistance_target.add_condition("resistance_spell", 10)
	resistance_target.resistance_damage_type = "fire"
	var resistance_damage := CombatAction.resolve_damage(resistance_target, 10, "fire")
	var resistance_second_damage := CombatAction.resolve_damage(resistance_target, 10, "fire")
	var resistance_other_type := CombatAction.resolve_damage(resistance_target, 10, "cold")
	CombatAction.advance_combat_turn()
	var resistance_next_turn_damage := CombatAction.resolve_damage(resistance_target, 10, "fire")
	var shillelagh_spell: Dictionary = DataLoader.get_spell("shillelagh")
	var longstrider_spell: Dictionary = DataLoader.get_spell("longstrider")
	var longstrider_target: Character = _fresh_char("Longstrider Target", "human", "fighter", {})
	var longstrider_base_speed := longstrider_target.get_speed()
	longstrider_target.add_condition("longstrider", 1)
	var longstrider_buffed_speed := longstrider_target.get_speed()
	longstrider_target.tick_conditions()
	var longstrider_expired_speed := longstrider_target.get_speed()
	var longstrider_monster := {"speed": 8, "conditions": {"longstrider": 1}}
	CombatState.tick_monster_condition_durations(longstrider_monster)
	var animal_friendship_spell: Dictionary = DataLoader.get_spell("animal_friendship")
	var charm_person_spell: Dictionary = DataLoader.get_spell("charm_person")
	var charm_monster_spell: Dictionary = DataLoader.get_spell("charm_monster")
	var animal_friendship_caster: Character = _fresh_char("Animal Friendship Druid", "human", "druid", {"WIS": 16})
	animal_friendship_caster.character_id = "animal_friendship_caster"
	var friendly_beast := {"id": "friendly_beast", "name": "Beast", "creature_type": "beast", "current_hp": 30, "max_hp": 30, "is_alive": true, "conditions": {}, "saving_throw_bonuses": {"WIS": -100}}
	var wrong_animal_friendship_target := {"id": "not_a_beast", "creature_type": "humanoid", "is_alive": true, "conditions": {}}
	var animal_friendship_validation := CombatAction.validate_spell_target(animal_friendship_caster, friendly_beast, animal_friendship_spell, 30)
	var animal_friendship_rejection := CombatAction.validate_spell_target(animal_friendship_caster, wrong_animal_friendship_target, animal_friendship_spell, 30)
	var animal_friendship_upcast := animal_friendship_spell.duplicate(true)
	animal_friendship_upcast["_selected_spell_slot_level"] = 3
	var animal_friendship_targeting_state := CombatState.new()
	var animal_friendship_maximum_targets: int = animal_friendship_targeting_state._spell_upcast_maximum_targets(animal_friendship_upcast)
	animal_friendship_targeting_state.free()
	var charm_monster_upcast := charm_monster_spell.duplicate(true)
	charm_monster_upcast["_selected_spell_slot_level"] = 6
	var charm_monster_targeting_state := CombatState.new()
	var charm_monster_maximum_targets: int = charm_monster_targeting_state._spell_upcast_maximum_targets(charm_monster_upcast)
	charm_monster_targeting_state.free()
	var animal_friendship_resolution := CombatAction.resolve_spell(animal_friendship_caster, friendly_beast, animal_friendship_spell, false, {}, [], 1, 30)
	var charm_person_caster: Character = _fresh_char("Charm Caster", "human", "wizard", {"INT": 16})
	charm_person_caster.character_id = "charm_person_caster"
	var charm_monster_caster: Character = _fresh_char("Charm Monster Caster", "human", "wizard", {"INT": 16})
	charm_monster_caster.character_id = "charm_monster_caster"
	var charmed_humanoid := {"id": "charmed_humanoid", "name": "Guard", "creature_type": "humanoid", "current_hp": 30, "max_hp": 30, "is_alive": true, "conditions": {}, "saving_throw_bonuses": {"WIS": -100}}
	var charm_person_resolution := CombatAction.resolve_spell(charm_person_caster, charmed_humanoid, charm_person_spell, false, {}, [], 1, 30)
	var charm_person_condition_applied: bool = charmed_humanoid.get("conditions", {}).has("charmed") and SpellEffects.has_spell(charmed_humanoid, "charm_person")
	var charmed_creature := {"id": "charmed_creature", "name": "Ogre", "creature_type": "giant", "current_hp": 30, "max_hp": 30, "is_alive": true, "conditions": {}, "saving_throw_bonuses": {"WIS": -100}}
	var charm_monster_resolution := CombatAction.resolve_spell(charm_monster_caster, charmed_creature, charm_monster_spell, false, {}, [], 4, 30)
	var charm_monster_condition_applied: bool = charmed_creature.get("conditions", {}).has("charmed") and SpellEffects.has_spell(charmed_creature, "charm_monster")
	var plain_charm_person := charm_person_spell.duplicate(true)
	plain_charm_person.erase("save_advantage_if_fighting_target")
	var charm_save_advantage_seen: bool = false
	for charm_seed in range(1, 80):
		seed(charm_seed)
		var advantaged_charm_target := {"id": "advantaged_charm_target", "name": "Guard", "creature_type": "humanoid", "current_hp": 30, "max_hp": 30, "is_alive": true, "conditions": {}, "saving_throw_bonuses": {"WIS": 0}}
		var advantaged_charm_result := CombatAction.resolve_spell(charm_person_caster, advantaged_charm_target, charm_person_spell, false, {}, [], 1, 30)
		seed(charm_seed)
		var normal_charm_target := {"id": "normal_charm_target", "name": "Guard", "creature_type": "humanoid", "current_hp": 30, "max_hp": 30, "is_alive": true, "conditions": {}, "saving_throw_bonuses": {"WIS": 0}}
		var normal_charm_result := CombatAction.resolve_spell(charm_person_caster, normal_charm_target, plain_charm_person, false, {}, [], 1, 30)
		if advantaged_charm_result.get("saved", false) and not normal_charm_result.get("saved", false):
			charm_save_advantage_seen = true
			break
	var charm_person_ally: Character = _fresh_char("Charm Caster Ally", "human", "fighter", {})
	charm_person_ally.character_id = "charm_person_ally"
	CombatAction.resolve_damage(charmed_humanoid, 1, "slashing", {}, false, false, charm_person_ally)
	CombatAction.resolve_damage(charmed_creature, 1, "slashing", {}, false, false, charm_person_ally)
	var charmed_character: Character = _fresh_char("Charmed Character", "human", "fighter", {})
	var character_charm_cast := SpellEffects.begin_cast(charm_person_caster, charm_person_spell)
	SpellEffects.grant(charmed_character, character_charm_cast, "charmed")
	CombatAction.resolve_damage(charmed_character, 1, "slashing", {}, false, false, charm_person_ally)
	var animal_friendship_source := "animal_friendship:%s" % animal_friendship_caster.character_id
	var party_damage_target := {"current_hp": 30, "max_hp": 30, "conditions": {"charmed": 14400}, "condition_sources": {"charmed": {animal_friendship_source: 14400}}, "animal_friendship_caster_ids": [animal_friendship_caster.character_id], "damage_resistances": [], "damage_immunities": []}
	var animal_friendship_ally: Character = _fresh_char("Animal Friendship Ally", "human", "fighter", {})
	animal_friendship_ally.character_id = "animal_friendship_ally"
	CombatAction.resolve_damage(party_damage_target, 1, "slashing", {}, false, false, animal_friendship_ally)
	var unrelated_damage_target := {"current_hp": 30, "max_hp": 30, "conditions": {"charmed": 14400}, "condition_sources": {"charmed": {animal_friendship_source: 14400}}, "animal_friendship_caster_ids": [animal_friendship_caster.character_id], "damage_resistances": [], "damage_immunities": []}
	var non_party_attacker := Character.new()
	CombatAction.resolve_damage(unrelated_damage_target, 1, "slashing", {}, false, false, non_party_attacker)
	var shillelagh_caster: Character = _fresh_char("Shillelagh Druid", "human", "druid", {"STR": 8, "WIS": 18})
	var shillelagh_target := {"id": "shillelagh_target", "name": "Shillelagh Target", "current_hp": 100, "max_hp": 100, "armor_class": -100, "is_alive": true, "conditions": {}, "damage_resistances": [], "damage_immunities": []}
	var shillelagh_invalid := CombatAction.validate_spell_target(shillelagh_caster, shillelagh_caster, shillelagh_spell, 0)
	shillelagh_caster.inventory.equip(Inventory.Slot.WEAPON, "quarterstaff", true)
	shillelagh_caster.add_condition("shillelagh", 10)
	shillelagh_caster.shillelagh_weapon_id = "quarterstaff"
	var shillelagh_hit := CombatAction.resolve_weapon_attack(shillelagh_caster, shillelagh_target, DataLoader.get_item("quarterstaff"), false, false, {"shillelagh_damage_type": "force"})
	_assert(chill_touch.get("school", "") == "necromancy" and chill_touch.get("range", 0) == 1 and chill_touch.get("attack_type", "") == "melee_spell" and chill_touch.get("damage", "") == "1d10" and chill_touch.get("damage_type", "") == "necrotic" and chill_touch.get("components", []) == ["V", "S"] and chill_touch.get("duration", "") == "instantaneous", "Chill Touch records the 2024 melee spell attack, touch range, Necrotic damage, components, and duration")
	_assert(chill_result.get("success", false) and chill_result.get("hit", false) and int(chill_result.get("damage", 0)) >= 2 and int(chill_result.get("damage", 0)) <= 40 and chill_applied.size() == 1, "Chill Touch lands its level-5 melee spell attack and applies its hit effect")
	_assert(chill_hp_after_blocked_heal == chill_hp_after_hit, "Chill Touch keeps the target's HP unchanged when direct spell healing is attempted")
	_assert(not chill_event_healing.is_empty() and int(chill_event_healing[0].get("amount", -1)) == 0, "Chill Touch reports zero HP restored by direct spell healing")
	_assert(int(chill_dict_spark.get("healing", -1)) == 0 and int(chill_dict_target["current_hp"]) == chill_dict_hp, "Chill Touch blocks Divine Spark healing for a monster target")
	_assert(chill_still_blocked and chill_recovered > 0, "Chill Touch remains active through one caster turn end and expires at the next")
	_assert(vicious_mockery.get("school", "") == "enchantment" and vicious_mockery.get("range", 0) == 12 and vicious_mockery.get("components", []) == ["V"] and vicious_mockery.get("duration", "") == "instantaneous" and vicious_mockery.get("damage", "") == "1d6" and vicious_mockery.get("damage_type", "") == "psychic" and vicious_mockery.get("save", "") == "WIS", "Vicious Mockery records the 2024 60-foot Wisdom save and 1d6 Psychic damage")
	_assert(CombatAction.spell_damage_formula(scaling_caster, vicious_mockery) == "2d6" and "vicious_mockery" in DataLoader.get_character_class("bard").get("spell_list_ids", []), "Vicious Mockery receives its level-5 upgrade and remains a Bard cantrip")
	_assert(acid_splash.get("school", "") == "evocation" and acid_splash.get("target", "") == "area" and acid_splash.get("range", 0) == 12 and acid_splash.get("components", []) == ["V", "S"] and acid_splash.get("duration", "") == "instantaneous" and acid_splash_area.get("success", false) and int(acid_splash_area.get("radius", 0)) == 1, "Acid Splash records its 60-foot, 5-foot Sphere, components, and instantaneous duration")
	_assert(acid_splash_result.get("success", false) and not acid_splash_result.get("saved", true) and acid_splash_result.get("damage_type", "") == "acid" and int(acid_splash_result.get("damage", 0)) >= 1 and int(acid_splash_result.get("damage", 0)) <= 6, "Acid Splash applies its failed-save Acid damage")
	_assert("acid_splash" in DataLoader.get_character_class("sorcerer").get("spell_list_ids", []) and "acid_splash" in DataLoader.get_character_class("wizard").get("spell_list_ids", []), "Acid Splash is available to Sorcerer and Wizard")
	_assert(CombatAction.spell_damage_formula(scaling_caster, acid_splash) == "2d6", "Acid Splash receives its level-5 cantrip upgrade")
	_assert(color_spray.get("school", "") == "illusion" and color_spray.get("target", "") == "cone" and color_spray.get("range", -1) == 0 and color_spray.get("components", []) == ["V", "S", "M"] and color_spray.get("duration", "") == "instantaneous" and color_spray.get("save", "") == "CON" and int(color_spray.get("effects", [])[0].get("size", 0)) == 3, "Color Spray records the 15-foot Constitution-save cone, components, and instant duration")
	_assert(not color_spray_resolution.get("saved", true) and color_spray_effects.size() == 1 and color_spray_target.has_condition("blinded") == false and color_spray_attack.get("disadvantage", false), "Color Spray Blinds a creature on a failed save and imposes attack Disadvantage")
	_assert("color_spray" in DataLoader.get_character_class("bard").get("spell_list_ids", []) and "color_spray" in DataLoader.get_character_class("sorcerer").get("spell_list_ids", []) and "color_spray" in DataLoader.get_character_class("wizard").get("spell_list_ids", []), "Color Spray is available to Bard, Sorcerer, and Wizard")
	_assert(command_spell.get("save", "") == "WIS" and command_spell.get("components", []) == ["V"] and command_spell.get("target_creature_type_exclusions", []) == ["undead"] and command_spell.get("upcast", {}).get("additional_targets_per_level", 0) == 1, "Command records its Wisdom save, verbal component, Undead exclusion, and extra target per upcast level")
	_assert(not command_resolution.get("saved", true) and command_effects.size() == 1 and command_effects[0].get("type", "") == "command" and command_saved.get("saved", false) and CombatAction.apply_spell_failed_save_effects(command_target, command_spell, command_saved).is_empty(), "Command produces an instruction only after a failed Wisdom save")
	for command_class in ["bard", "cleric", "paladin"]:
		_assert("command" in DataLoader.get_character_class(command_class).get("spell_list_ids", []), "Command is available to %s" % command_class.capitalize())
	_assert(blade_ward.get("school", "") == "abjuration" and blade_ward.get("casting_time", "") == "action" and blade_ward.get("range", -1) == 0 and blade_ward.get("components", []) == ["V", "S"] and blade_ward.get("concentration", false) and blade_ward.get("duration", "") == "concentration, up to 1 minute", "Blade Ward records the 2024 self-targeted, Verbal and Somatic, one-minute concentration spell")
	_assert(ward_penalty >= 1 and ward_penalty <= 4 and warded_attack["total"] == 18 - ward_penalty and warded_attack["activity_modifiers"][0].get("label", "") == "Blade Ward" and no_ward_penalty == 0 and unwarded_attack["total"] == 18, "Blade Ward subtracts a recorded 1d4 from attacks against the warded target only")
	for ward_class in ["bard", "sorcerer", "warlock", "wizard"]:
		_assert("blade_ward" in DataLoader.get_character_class(ward_class).get("spell_list_ids", []), "Blade Ward is available to %s" % ward_class.capitalize())
	_assert(guidance_spell.get("school", "") == "divination" and guidance_spell.get("casting_time", "") == "action" and guidance_spell.get("range", -1) == 1 and guidance_spell.get("components", []) == ["V", "S"] and guidance_spell.get("concentration", false) and guidance_spell.get("duration", "") == "concentration, up to 1 minute", "Guidance records the 2024 touch-range, Verbal and Somatic, one-minute concentration spell")
	_assert(resistance_spell.get("school", "") == "abjuration" and resistance_spell.get("components", []) == ["V", "S"] and resistance_spell.get("concentration", false) and resistance_spell.get("damage_type_options", []).size() == 11, "Resistance records the 2024 damage ward options and one-minute concentration")
	_assert(resistance_damage.get("resistance_spell_reduction", 0) >= 1 and resistance_damage.get("resistance_spell_reduction", 0) <= 4 and resistance_second_damage.get("resistance_spell_reduction", -1) == 0 and resistance_other_type.get("resistance_spell_reduction", -1) == 0 and resistance_next_turn_damage.get("resistance_spell_reduction", 0) >= 1 and resistance_next_turn_damage.get("resistance_spell_reduction", 0) <= 4, "Resistance reduces one matching damage instance each combatant turn")
	_assert("resistance" in DataLoader.get_character_class("cleric").get("spell_list_ids", []) and "resistance" in DataLoader.get_character_class("druid").get("spell_list_ids", []), "Resistance is available to Cleric and Druid")
	_assert(shillelagh_spell.get("casting_time", "") == "bonus_action" and shillelagh_spell.get("target", "") == "self" and shillelagh_spell.get("range", -1) == 0 and shillelagh_spell.get("components", []) == ["V", "S", "M"] and shillelagh_spell.get("duration", "") == "1 minute", "Shillelagh records the 2024 self-range Bonus Action spell metadata")
	_assert(not shillelagh_invalid.get("success", true) and CombatAction.shillelagh_damage_die(1) == "1d8" and CombatAction.shillelagh_damage_die(5) == "1d10" and CombatAction.shillelagh_damage_die(11) == "1d12" and CombatAction.shillelagh_damage_die(17) == "2d6", "Shillelagh requires an equipped valid weapon and scales its damage die at levels 5, 11, and 17")
	_assert(shillelagh_hit.get("hit", false) and shillelagh_hit.get("damage_type", "") == "force" and int(shillelagh_hit.get("damage", 0)) >= 5 and int(shillelagh_hit.get("damage", 0)) <= 12 and "shillelagh" in DataLoader.get_character_class("druid").get("spell_list_ids", []), "Shillelagh uses Wisdom for an equipped Quarterstaff attack and can change its damage to Force (%s)" % str(shillelagh_hit))
	_assert(longstrider_spell.get("range", 0) == 1 and longstrider_spell.get("components", []) == ["V", "S", "M"] and longstrider_spell.get("duration", "") == "1 hour" and longstrider_spell.get("upcast", {}).get("additional_targets_per_level", 0) == 1, "Longstrider records the 2024 touch-range, one-hour duration, components, and extra target per higher slot")
	_assert(longstrider_buffed_speed == longstrider_base_speed + 2 and longstrider_expired_speed == longstrider_base_speed and longstrider_monster.get("speed", 0) == 6 and not longstrider_monster.get("conditions", {}).has("longstrider"), "Longstrider adds 10 feet to player and monster movement and removes the bonus when it expires")
	for longstrider_class in ["bard", "druid", "ranger", "wizard"]:
		_assert("longstrider" in DataLoader.get_character_class(longstrider_class).get("spell_list_ids", []), "Longstrider is available to %s" % longstrider_class.capitalize())
	_assert(animal_friendship_spell.get("range", 0) == 6 and animal_friendship_spell.get("components", []) == ["V", "S", "M"] and animal_friendship_spell.get("duration", "") == "24 hours" and animal_friendship_spell.get("condition_on_failed_save", "") == "charmed" and animal_friendship_spell.get("upcast", {}).get("additional_targets_per_level", 0) == 1, "Animal Friendship records its 2024 30-foot Beast-only charm, 24-hour duration, and upcast targets")
	_assert(animal_friendship_validation.get("success", false) and not animal_friendship_rejection.get("success", true) and animal_friendship_maximum_targets == 3, "Animal Friendship accepts Beasts only and a level-3 slot selects three targets")
	_assert(not animal_friendship_resolution.get("saved", true) and friendly_beast.get("conditions", {}).has("charmed") and friendly_beast.get("condition_sources", {}).get("charmed", {}).has(animal_friendship_resolution.get("effect_cast", {}).get("source_id", "")) and not str(animal_friendship_resolution.get("message", "")).contains("damage"), "Animal Friendship charms a Beast that fails its Wisdom save and reports no damage")
	_assert(not party_damage_target.get("conditions", {}).has("charmed") and party_damage_target.get("animal_friendship_caster_ids", []).is_empty() and unrelated_damage_target.get("conditions", {}).has("charmed"), "Party damage ends Animal Friendship, while damage from a non-party attacker does not")
	_assert(charm_person_spell.get("duration_seconds", 0) == 3600 and charm_person_spell.get("end_on_target_damage", false) and charm_person_spell.get("save_advantage_if_fighting_target", false) and charm_person_spell.get("upcast", {}).get("additional_targets_per_level", 0) == 1 and charm_monster_spell.get("end_on_target_damage", false) and charm_monster_spell.get("upcast", {}).get("additional_targets_per_level", 0) == 1 and charm_monster_maximum_targets == 3, "Charm Person and Charm Monster record 2024 duration, fighting-save Advantage, damage break and upcast target counts")
	_assert(charm_save_advantage_seen, "A creature fighting the party has Advantage on its Charm Person save")
	_assert(SpellSupport.is_available(charm_monster_spell) and not charm_monster_resolution.get("saved", true) and charm_monster_condition_applied and not charmed_creature.get("conditions", {}).has("charmed") and not SpellEffects.has_spell(charmed_creature, "charm_monster"), "Charm Monster is available, applies a source-owned Charmed condition and ends it when the party damages the target")
	_assert(not charm_person_resolution.get("saved", true) and charm_person_condition_applied and not charmed_humanoid.get("conditions", {}).has("charmed") and not SpellEffects.has_spell(charmed_humanoid, "charm_person"), "Charm Person applies a source-owned Charmed condition and ends it when the party damages the target")
	_assert(not charmed_character.has_condition("charmed") and not SpellEffects.has_spell(charmed_character, "charm_person"), "Charm Person also ends on damage when its target is a player character")
	for animal_friendship_class in ["bard", "druid", "ranger"]:
		_assert("animal_friendship" in DataLoader.get_character_class(animal_friendship_class).get("spell_list_ids", []), "Animal Friendship is available to %s" % animal_friendship_class.capitalize())
	var animal_messenger_spell: Dictionary = DataLoader.get_spell("animal_messenger")
	var animal_messenger_caster: Character = _fresh_char("Animal Messenger Druid", "human", "druid", {"WIS": 16})
	var animal_messenger_destination := {"id": "6,0", "name": "Northwatch", "coord": [6, 0]}
	var animal_messenger_visits: Array[Dictionary] = [animal_messenger_destination]
	var animal_messenger_valid_order := AnimalMessengerRules.validate_order({"destination_id": "6,0", "recipient": "the town guard", "message": "The party is on its way."}, animal_messenger_visits)
	var animal_messenger_unvisited_order := AnimalMessengerRules.validate_order({"destination_id": "7,0", "recipient": "the town guard", "message": "Hello."}, animal_messenger_visits)
	var animal_messenger_long_order := AnimalMessengerRules.validate_order({"destination_id": "6,0", "recipient": "the town guard", "message": "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twenty one twenty two twenty three twenty four twenty five twenty six"}, animal_messenger_visits)
	var animal_messenger_land := AnimalMessengerRules.create_delivery("test-land", animal_messenger_caster.character_id, animal_messenger_caster.character_name, Vector2i.ZERO, animal_messenger_destination, "the town guard", "The party is on its way.", 86400, false)
	var animal_messenger_land_outcome := AnimalMessengerRules.advance_deliveries([animal_messenger_land], 86400)
	var animal_messenger_upcast := AnimalMessengerRules.create_delivery("test-upcast", animal_messenger_caster.character_id, animal_messenger_caster.character_name, Vector2i.ZERO, animal_messenger_destination, "the town guard", "The party is on its way.", 259200, false)
	var animal_messenger_upcast_day_one := AnimalMessengerRules.advance_deliveries([animal_messenger_upcast], 86400)
	var animal_messenger_upcast_day_two := AnimalMessengerRules.advance_deliveries(animal_messenger_upcast_day_one.get("deliveries", []), 86400)
	var animal_messenger_flying := AnimalMessengerRules.create_delivery("test-flight", animal_messenger_caster.character_id, animal_messenger_caster.character_name, Vector2i.ZERO, {"id": "3,0", "name": "Eastgate", "coord": [3, 0]}, "the gatekeeper", "A warning.", 86400, true)
	var animal_messenger_flying_outcome := AnimalMessengerRules.advance_deliveries([animal_messenger_flying], 86400)
	_assert(animal_messenger_spell.get("save", "") == "CHA" and animal_messenger_spell.get("target_creature_types", []) == ["beast"] and animal_messenger_spell.get("target_sizes", []) == ["tiny"] and animal_messenger_spell.get("ritual", false) and animal_messenger_spell.get("max_message_words", 0) == 25 and animal_messenger_spell.get("travel_miles_per_24_hours", 0) == 25 and animal_messenger_spell.get("flying_travel_miles_per_24_hours", 0) == 50 and animal_messenger_spell.get("upcast", {}).get("additional_duration_seconds_per_level", 0) == 172800 and animal_messenger_spell.get("rules_status", "") == "2024-supported" and not str(animal_messenger_spell.get("description", "")).ends_with("..."), "Animal Messenger records its supported 2024 Tiny Beast, save, ritual, message, travel, and upcast rules")
	_assert(animal_messenger_valid_order.get("success", false) and not animal_messenger_unvisited_order.get("success", true) and not animal_messenger_long_order.get("success", true), "Animal Messenger requires a visited destination and a message of at most 25 words")
	_assert(animal_messenger_land_outcome.get("notifications", [])[0].get("status", "") == "returned" and animal_messenger_upcast_day_one.get("notifications", []).is_empty() and animal_messenger_upcast_day_two.get("notifications", [])[0].get("status", "") == "delivered" and animal_messenger_flying_outcome.get("notifications", [])[0].get("status", "") == "delivered", "Animal Messenger follows walking and flying speeds and its duration increases by 48 hours per higher slot")
	_assert(AnimalMessengerRules.validate_saved_deliveries(animal_messenger_upcast_day_two.get("deliveries", [])) == "" and not AnimalMessengerRules.validate_saved_deliveries([{"id": "bad", "status": "in_transit"}]).is_empty(), "Animal Messenger save validation accepts complete delivery records and rejects incomplete records")
	for animal_messenger_class in ["bard", "druid", "ranger"]:
		_assert("animal_messenger" in DataLoader.get_character_class(animal_messenger_class).get("spell_list_ids", []), "Animal Messenger is available to %s" % animal_messenger_class.capitalize())
	var dancing_lights_spell: Dictionary = DataLoader.get_spell("dancing_lights")
	var dancing_lights_set := DancingLightsRules.create_light_set("test-caster", "Test Caster", Vector2i.ZERO, Vector2i.ZERO)
	var dancing_lights_moved := DancingLightsRules.move_light_set(dancing_lights_set.get("lights", {}), Vector2i.ZERO, Vector2i(12, 0))
	var dancing_lights_too_far := DancingLightsRules.move_light_set(dancing_lights_set.get("lights", {}), Vector2i.ZERO, Vector2i(13, 0))
	var dancing_two_lights := DancingLightsRules.create_light_set("test-caster", "Test Caster", Vector2i.ZERO, Vector2i.ZERO, false, 2)
	var dancing_humanoid := DancingLightsRules.create_light_set("test-caster", "Test Caster", Vector2i.ZERO, Vector2i.ZERO, true)
	_assert(dancing_lights_spell.get("school", "") == "illusion" and dancing_lights_spell.get("range", 0) == 24 and dancing_lights_spell.get("target", "") == "point" and dancing_lights_spell.get("duration_seconds", 0) == 60 and dancing_lights_spell.get("concentration", false) and dancing_lights_spell.get("rules_status", "") == "2024-supported" and dancing_lights_set.get("lights", {}).get("positions", []).size() == 4 and dancing_two_lights.get("lights", {}).get("positions", []).size() == 2 and dancing_humanoid.get("lights", {}).get("positions", []).size() == 1, "Dancing Lights records its Illusion school, range, point target, duration, concentration, variable number of lights, and humanoid form")
	_assert(dancing_lights_moved.get("success", false) and not dancing_lights_too_far.get("success", true) and dancing_lights_moved.get("light_set", {}).get("positions", []).size() == 4, "Dancing Lights move up to 60 feet as a linked set")
	for dancing_lights_class in ["bard", "sorcerer", "wizard"]:
		_assert("dancing_lights" in DataLoader.get_character_class(dancing_lights_class).get("spell_list_ids", []), "Dancing Lights is available to %s" % dancing_lights_class.capitalize())
	var light_spell: Dictionary = DataLoader.get_spell("light")
	var light_marker := LightRules.create_marker(Vector2i(1, -1), "test-caster", "Test Caster")
	var light_tick := LightRules.tick(light_marker)
	_assert(light_spell.get("rules_source", "") == "SRD5.2.1" and light_spell.get("rules_status", "") == "2024-gameplay-partial" and light_spell.get("target", "") == "point" and light_spell.get("range", -1) == 1 and light_spell.get("duration", "") == "1 hour" and not light_spell.get("effects", []).any(func(effect: Dictionary) -> bool: return effect.get("type", "") == "vision_bonus"), "Light records its one-hex touch range, hour duration and light markers without granting unsupported vision")
	_assert(light_marker.get("position", []) == [1, -1] and light_marker.get("rounds_remaining", 0) == 600 and light_tick.get("active", false) and light_tick.get("marker", {}).get("rounds_remaining", 0) == 599 and LightRules.BRIGHT_RADIUS_HEXES == 4 and LightRules.DIM_RADIUS_HEXES == 8, "Light marker tracks its touched space, bright and dim radii, and one-hour combat duration")
	for light_class in ["bard", "cleric", "sorcerer", "wizard"]:
		_assert("light" in DataLoader.get_character_class(light_class).get("spell_list_ids", []), "Light is available to %s" % light_class.capitalize())
	var mage_hand_spell: Dictionary = DataLoader.get_spell("mage_hand")
	var mage_hand := MageHandRules.create_hand(Vector2i(1, 0), "test-caster", "Test Caster", 1)
	var mage_hand_tick := MageHandRules.tick(mage_hand)
	_assert(mage_hand_spell.get("rules_source", "") == "SRD5.2.1" and mage_hand_spell.get("rules_status", "") == "2024-gameplay-partial" and mage_hand_spell.get("range", 0) == MageHandRules.RANGE_HEXES and mage_hand_spell.get("target", "") == "point" and mage_hand_spell.get("duration_seconds", 0) == 60, "Mage Hand records its SRD range, point target, duration and explicit partial object-interaction scope")
	_assert(MageHandRules.can_move(mage_hand, Vector2i.ZERO, Vector2i(6, 0)) and not MageHandRules.can_move(mage_hand, Vector2i.ZERO, Vector2i(7, 0)) and not MageHandRules.can_move(mage_hand, Vector2i.ZERO, Vector2i(7, -1)) and mage_hand_tick.get("active", false) and mage_hand_tick.get("hand", {}).get("rounds_remaining", 0) == 9, "Mage Hand moves up to 30 feet and stays within 30 feet of its caster for ten rounds")
	for mage_hand_class in ["bard", "sorcerer", "warlock", "wizard"]:
		_assert("mage_hand" in DataLoader.get_character_class(mage_hand_class).get("spell_list_ids", []), "Mage Hand is available to %s" % mage_hand_class.capitalize())
	var message_spell: Dictionary = DataLoader.get_spell("message")
	var private_message := MessageRules.create_exchange("caster", "recipient", "  Meet at the gate.  ", "I will be there.")
	_assert(message_spell.get("rules_source", "") == "SRD5.2.1" and message_spell.get("rules_status", "") == "2024-gameplay-partial" and message_spell.get("range", 0) == MessageRules.RANGE_HEXES and message_spell.get("duration_seconds", 0) == 6 and message_spell.get("components", []) == ["S", "M"], "Message records its SRD range, components, round duration and supported hot-seat boundary")
	_assert(private_message.get("message", "") == "Meet at the gate." and private_message.get("reply", "") == "I will be there." and private_message.get("rounds_remaining", 0) == MessageRules.DURATION_ROUNDS and MessageRules.activity_summary("Caster", "Recipient") == "Caster sends a private Message to Recipient.", "Message content stays in its transient exchange while the activity summary contains no whisper text")
	for message_class in ["bard", "druid", "sorcerer", "wizard"]:
		_assert("message" in DataLoader.get_character_class(message_class).get("spell_list_ids", []), "Message is available to %s" % message_class.capitalize())
	var minor_illusion_spell: Dictionary = DataLoader.get_spell("minor_illusion")
	var minor_illusion := MinorIllusionRules.create_illusion(Vector2i(2, -1), "illusion-caster", "Illusion Caster", "image", "A wooden chest", 3)
	var minor_illusion_tick := MinorIllusionRules.tick(minor_illusion)
	_assert(minor_illusion_spell.get("rules_source", "") == "SRD5.2.1" and minor_illusion_spell.get("rules_status", "") == "2024-gameplay-partial" and minor_illusion_spell.get("duration_seconds", 0) == 60 and minor_illusion_spell.get("components", []) == ["S", "M"] and not str(minor_illusion_spell.get("description", "")).ends_with("..."), "Minor Illusion records the complete 2024 minute-long sound/image spell contract and partial world-interaction boundary")
	_assert(minor_illusion_tick.get("active", false) and minor_illusion_tick.get("illusion", {}).get("rounds_remaining", 0) == 9 and MinorIllusionRules.create_illusion(Vector2i.ZERO, "caster", "Caster", "both", "", 0).is_empty(), "Minor Illusion markers expire after ten rounds and reject unsupported forms or blank descriptions")
	for illusion_class in ["bard", "sorcerer", "warlock", "wizard"]:
		_assert("minor_illusion" in DataLoader.get_character_class(illusion_class).get("spell_list_ids", []), "Minor Illusion is available to %s" % illusion_class.capitalize())
	var prestidigitation_spell: Dictionary = DataLoader.get_spell("prestidigitation")
	var magic_mark := PrestidigitationRules.create_effect(Vector2i(1, 0), "trickster", "Trickster", "magic_mark", "A silver spiral", 5)
	var minor_trinket := PrestidigitationRules.create_effect(Vector2i(1, 0), "trickster", "Trickster", "minor_creation", "A tiny brass key", 5)
	var ticked_magic_mark := PrestidigitationRules.tick([magic_mark])
	_assert(prestidigitation_spell.get("rules_source", "") == "SRD5.2.1" and prestidigitation_spell.get("rules_status", "") == "2024-gameplay-partial" and prestidigitation_spell.get("range", 0) == PrestidigitationRules.RANGE_HEXES and prestidigitation_spell.get("duration_seconds", 0) == 3600 and not str(prestidigitation_spell.get("description", "")).ends_with("..."), "Prestidigitation records the 2024 spell options, 10-foot range, one-hour maximum, and gameplay-partial object boundary")
	_assert(magic_mark.get("rounds_remaining", 0) == PrestidigitationRules.HOUR_ROUNDS and minor_trinket.get("rounds_remaining", 0) == 2 and ticked_magic_mark.size() == 1 and ticked_magic_mark[0].get("rounds_remaining", 0) == PrestidigitationRules.HOUR_ROUNDS - 1 and PrestidigitationRules.MAX_ACTIVE_EFFECTS == 3, "Prestidigitation marks, hand-sized creations, the three-effect cap, and duration ticks are represented")
	for prestidigitation_class in ["bard", "sorcerer", "warlock", "wizard"]:
		_assert("prestidigitation" in DataLoader.get_character_class(prestidigitation_class).get("spell_list_ids", []), "Prestidigitation is available to %s" % prestidigitation_class.capitalize())
	var produce_flame_spell: Dictionary = DataLoader.get_spell("produce_flame")
	var produced_flame := ProduceFlameRules.create_flame("druid-1", "Druid", Vector2i(2, 1), 7)
	var expired_flame := produced_flame.duplicate(true)
	expired_flame["rounds_remaining"] = 1
	_assert(produce_flame_spell.get("rules_source", "") == "SRD5.2.1" and produce_flame_spell.get("rules_status", "") == "2024-gameplay-partial" and produce_flame_spell.get("casting_time", "") == "bonus_action" and produce_flame_spell.get("duration_seconds", 0) == 600 and not str(produce_flame_spell.get("description", "")).ends_with("..."), "Produce Flame records the complete SRD duration, light, hurl, and scaling rules")
	_assert(produced_flame.get("rounds_remaining", 0) == ProduceFlameRules.DURATION_ROUNDS and ProduceFlameRules.tick(produced_flame).get("rounds_remaining", 0) == ProduceFlameRules.DURATION_ROUNDS - 1 and ProduceFlameRules.tick(expired_flame).is_empty() and ProduceFlameRules.RANGE_HEXES == 12 and ProduceFlameRules.BRIGHT_LIGHT_RADIUS_HEXES == 4 and ProduceFlameRules.DIM_LIGHT_RADIUS_HEXES == 8, "Produce Flame lasts ten minutes, sheds its expected grid radii, and hurls within 60 feet")
	_assert(ProduceFlameRules.action_cost_for_mode("create") == "bonus_action" and ProduceFlameRules.action_cost_for_mode("hurl") == "magic_action", "Produce Flame creation and hurling require their separate SRD actions")
	_assert("produce_flame" in DataLoader.get_character_class("druid").get("spell_list_ids", []), "Produce Flame is available to Druids")
	var protection_energy_spell: Dictionary = DataLoader.get_spell("protection_from_energy")
	var energy_protected := AbilityScores.new()
	energy_protected.from_dict({"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	var energy_target := Character.new()
	energy_target.initialize("Energy Target", "", "wizard", energy_protected)
	energy_target.protection_from_energy_type = "fire"
	energy_target.add_condition("superior_defense", 99)
	var protected_fire := energy_target.resist_damage(17, "fire")
	energy_target.remove_condition("superior_defense")
	var unprotected_cold := energy_target.resist_damage(17, "cold")
	_assert(protection_energy_spell.get("rules_source", "") == "SRD5.2.1" and protection_energy_spell.get("rules_status", "") == "2024-gameplay-partial" and protection_energy_spell.get("concentration", false) and protection_energy_spell.get("duration_seconds", 0) == 3600 and protection_energy_spell.get("effects", [])[0].get("damage_types", []).size() == 5 and not str(protection_energy_spell.get("description", "")).ends_with("..."), "Protection from Energy records its SRD duration, concentration, and five eligible damage types")
	_assert(protected_fire == 8 and unprotected_cold == 17, "Protection from Energy grants Resistance only to its selected damage type and does not stack with another Resistance source")
	for energy_class in ["cleric", "druid", "ranger", "sorcerer", "wizard"]:
		_assert("protection_from_energy" in DataLoader.get_character_class(energy_class).get("spell_list_ids", []), "Protection from Energy is available to %s" % energy_class.capitalize())
	var evil_protection_spell: Dictionary = DataLoader.get_spell("protection_from_evil_and_good")
	var holy_water: Dictionary = DataLoader.get_item("holy_water")
	var holy_water_inventory := Inventory.new()
	var holy_water_missing := not holy_water_inventory.has_spell_component("holy_water", 25)
	holy_water_inventory.add_item("holy_water")
	var party_ward_target := _fresh_char("Warded Ally", "human", "wizard", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	party_ward_target.protection_from_evil_and_good_sources["cleric-1"] = evil_protection_spell.get("protected_creature_types", []).duplicate()
	var fiend_attacker := _fresh_char("Fiend", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 12, "INT": 10, "WIS": 10, "CHA": 10})
	fiend_attacker.creature_type = "fiend"
	var fiend_attack := CombatAction.resolve_weapon_attack(fiend_attacker, party_ward_target, {"id": "club", "type": "weapon", "damage": "1d4", "ability": "STR", "range": 1})
	var prevented_fright := CombatAction.apply_spell_failed_save_effects(party_ward_target, {"effects": [{"type": "grant_condition", "condition": "frightened", "duration": 3, "on_failed_save": true}]}, {"saved": false, "caster_creature_type": "fiend"})
	var allowed_fright := CombatAction.apply_spell_failed_save_effects(party_ward_target, {"effects": [{"type": "grant_condition", "condition": "frightened", "duration": 3, "on_failed_save": true}]}, {"saved": false, "caster_creature_type": "humanoid"})
	_assert(evil_protection_spell.get("rules_source", "") == "SRD5.2.1" and evil_protection_spell.get("rules_status", "") == "2024-gameplay-partial" and evil_protection_spell.get("duration_seconds", 0) == 600 and evil_protection_spell.get("material_component_consumed", false) and evil_protection_spell.get("material_component_cost", 0) == 25 and not str(evil_protection_spell.get("description", "")).ends_with("...") and holy_water.get("value", 0) == 25 and holy_water_missing and holy_water_inventory.has_spell_component("holy_water", 25), "Protection from Evil and Good records its 10-minute ward and the 25 GP consumed Holy Water component")
	_assert(fiend_attack.get("activity_roll", {}).get("disadvantage", false) and prevented_fright.is_empty() and allowed_fright.size() == 1, "Protection from Evil and Good penalizes covered creature attacks and blocks their Charmed or Frightened conditions")
	for evil_protection_class in ["cleric", "druid", "paladin", "warlock", "wizard"]:
		_assert("protection_from_evil_and_good" in DataLoader.get_character_class(evil_protection_class).get("spell_list_ids", []), "Protection from Evil and Good is available to %s" % evil_protection_class.capitalize())
	var protection_poison_spell: Dictionary = DataLoader.get_spell("protection_from_poison")
	var poison_protected := _fresh_char("Poison Protected", "human", "cleric", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 14, "CHA": 10})
	poison_protected.add_condition("protection_from_poison", 600)
	var poison_damage_resisted := poison_protected.resist_damage(17, "poison")
	var poison_damage_other := poison_protected.resist_damage(17, "fire")
	var poison_monster := {"current_hp": 30, "max_hp": 30, "is_alive": true, "conditions": {"protection_from_poison": 600}, "damage_resistances": [], "damage_immunities": []}
	var poison_monster_damage := CombatAction.resolve_damage(poison_monster, 17, "poison")
	_assert(protection_poison_spell.get("rules_status", "") == "2024-gameplay-partial" and protection_poison_spell.get("duration_seconds", 0) == 3600 and protection_poison_spell.get("neutralizes_condition", "") == "poisoned" and CombatAction.spell_grants_condition({"condition_on_failed_save": "poisoned"}, "poisoned") and poison_damage_resisted == 8 and poison_damage_other == 17 and int(poison_monster_damage.get("resolved", -1)) == 8, "Protection from Poison records its neutralization and duration and halves Poison damage once for both characters and monsters")
	var resilient_sphere: Dictionary = DataLoader.get_spell("resilient_sphere")
	var sphere_caster := _fresh_char("Sphere Wizard", "human", "wizard", {"INT": 16})
	var sphere_monster := {"id": "sphere_target", "name": "Sphere Target", "current_hp": 40, "max_hp": 40, "is_alive": true, "size": "medium", "creature_type": "humanoid", "conditions": {}, "saving_throw_bonuses": {"DEX": -100}, "ability_scores": {}}
	var sphere_resolution := CombatAction.resolve_spell(sphere_caster, sphere_monster, resilient_sphere, false, {}, [], 4, 30)
	var sphere_applied := CombatAction.apply_spell_failed_save_effects(sphere_monster, resilient_sphere, sphere_resolution)
	var sphere_damage := CombatAction.resolve_damage(sphere_monster, 20, "fire", {}, false, false, sphere_caster)
	var sphere_weapon_attack := CombatAction.resolve_weapon_attack(sphere_caster, sphere_monster, {"id": "club", "type": "weapon", "damage": "1d4", "ability": "STR", "range": 1})
	var sphere_spell_block := CombatAction.validate_spell_target(sphere_caster, sphere_monster, {"id": "cure_wounds", "name": "Cure Wounds", "casting_time": "action", "range": 1, "target": "single", "components": ["V", "S"]}, 5)
	var saved_sphere_monster := {"id": "saved_sphere_target", "name": "Saved Target", "current_hp": 40, "max_hp": 40, "is_alive": true, "size": "large", "creature_type": "humanoid", "conditions": {}, "saving_throw_bonuses": {"DEX": 1000}, "ability_scores": {}}
	var saved_sphere_resolution := CombatAction.resolve_spell(sphere_caster, saved_sphere_monster, resilient_sphere, false, {}, [], 4, 30)
	var disintegrate_sphere := CombatAction.resolve_spell(sphere_caster, sphere_monster, DataLoader.get_spell("disintegrate"), false, {}, [], 6, 30)
	var small_sphere_target := _fresh_char("Small Sphere Target", "gnome", "wizard", {"DEX": 10})
	var small_sphere_valid := CombatAction.validate_spell_target(sphere_caster, small_sphere_target, resilient_sphere, 5)
	var willing_sphere_resolution := CombatAction.resolve_spell(sphere_caster, small_sphere_target, resilient_sphere, false, {}, [], 4, 5)
	var willing_sphere_applied := CombatAction.apply_spell_failed_save_effects(small_sphere_target, resilient_sphere, willing_sphere_resolution)
	var sphere_caster_speed := sphere_caster.get_speed()
	sphere_caster.add_condition("resilient_sphere", 3)
	var sphere_speed := sphere_caster.get_speed()
	var sphere_outgoing_spell := CombatAction.validate_spell_target(sphere_caster, small_sphere_target, {"id": "cure_wounds", "name": "Cure Wounds", "casting_time": "action", "range": 1, "target": "single", "components": ["V", "S"]}, 5)
	_assert(resilient_sphere.get("name", "") == "Otiluke's Resilient Sphere" and resilient_sphere.get("rules_source", "") == "SRD5.2.1" and resilient_sphere.get("target_sizes", []).size() == 4 and resilient_sphere.get("classes", []) == ["cleric", "paladin", "wizard"] and not sphere_resolution.get("saved", true) and sphere_applied.size() == 1 and sphere_monster.get("conditions", {}).has("resilient_sphere"), "Resilient Sphere records its 2024 SRD list, eligible sizes, and failed-save enclosure")
	_assert(int(sphere_damage.get("damage", -1)) == 0 and sphere_damage.get("blocked_by_resilient_sphere", false) and not sphere_weapon_attack.get("hit", true) and not sphere_spell_block.get("success", true) and not sphere_outgoing_spell.get("success", true), "Resilient Sphere blocks external damage and attacks, incoming spells, and spells cast outward from inside")
	_assert(saved_sphere_resolution.get("saved", false) and not saved_sphere_monster.get("conditions", {}).has("resilient_sphere") and disintegrate_sphere.get("sphere_destroyed", false) and int(disintegrate_sphere.get("damage", -1)) == 0, "A successful save avoids enclosure, while Disintegrate ends the sphere without harming its occupant")
	_assert(small_sphere_valid.get("success", false) and willing_sphere_applied.size() == 1 and willing_sphere_resolution.get("message", "").contains("without a saving throw") and sphere_speed == 0 and sphere_caster_speed > 0 and FighterRules.monster_speed(sphere_monster) == 0, "Resilient Sphere encloses willing Small characters without a save and stops ordinary movement for enclosed creatures")
	var hold_monster_spell: Dictionary = DataLoader.get_spell("hold_monster")
	var hold_monster_caster := _fresh_char("Hold Monster Wizard", "human", "wizard", {"INT": 16})
	var hold_monster_victim := {"id": "hold_monster_victim", "name": "Held Victim", "current_hp": 40, "max_hp": 40, "is_alive": true, "size": "medium", "creature_type": "fiend", "conditions": {}, "saving_throw_bonuses": {"WIS": -100}, "ability_scores": {}}
	var hold_monster_result := CombatAction.resolve_spell(hold_monster_caster, hold_monster_victim, hold_monster_spell, false, {}, [], 5, 30)
	var initially_paralyzed := CombatAction.is_paralyzed(hold_monster_victim)
	var hold_monster_repeat_fail := CombatAction.resolve_hold_monster_repeat_save(hold_monster_victim, 14)
	var still_paralyzed_after_failed_save := CombatAction.is_paralyzed(hold_monster_victim)
	hold_monster_victim["armor_class"] = -100
	var hold_monster_critical := CombatAction.resolve_weapon_attack(hold_monster_caster, hold_monster_victim, {"id": "club", "type": "weapon", "damage": "1d4", "ability": "STR", "range": 1, "attack_distance": 1})
	var paralyzed_monster_speed := FighterRules.monster_speed(hold_monster_victim)
	hold_monster_victim["saving_throw_bonuses"]["WIS"] = 1000
	var hold_monster_repeat_success := CombatAction.resolve_hold_monster_repeat_save(hold_monster_victim, 14)
	var hold_monster_save_victim := {"id": "hold_monster_saved_victim", "name": "Saved Victim", "current_hp": 40, "max_hp": 40, "is_alive": true, "size": "medium", "creature_type": "humanoid", "conditions": {}, "saving_throw_bonuses": {"WIS": 1000}, "ability_scores": {}}
	var hold_monster_saved_result := CombatAction.resolve_spell(hold_monster_caster, hold_monster_save_victim, hold_monster_spell, false, {}, [], 5, 30)
	var paralyzed_dex_target := {"id": "paralyzed_dex_target", "name": "Paralyzed Dexterity Target", "current_hp": 40, "max_hp": 40, "is_alive": true, "size": "medium", "creature_type": "humanoid", "conditions": {"paralyzed": 3}, "saving_throw_bonuses": {"DEX": 1000}, "ability_scores": {}}
	var paralyzed_dex_save := CombatAction.resolve_spell(hold_monster_caster, paralyzed_dex_target, DataLoader.get_spell("sacred_flame"), false, {}, [], 1, 30)
	var hold_monster_already_paralyzed := {"id": "held_already", "name": "Already Held", "current_hp": 40, "max_hp": 40, "is_alive": true, "size": "medium", "creature_type": "humanoid", "conditions": {"paralyzed": 3}, "saving_throw_bonuses": {"WIS": -100}, "ability_scores": {}}
	hold_monster_caster.spell_slots["5"] = 1
	var hold_monster_slot_before: int = int(hold_monster_caster.spell_slots["5"])
	var duplicate_hold_monster := CombatAction.resolve_spell(hold_monster_caster, hold_monster_already_paralyzed, hold_monster_spell, true, {}, [], 5, 30)
	_assert(hold_monster_spell.get("rules_source", "") == "SRD5.2.1" and hold_monster_spell.get("duration_seconds", 0) == 60 and hold_monster_spell.get("upcast", {}).get("additional_targets_per_level", 0) == 1 and hold_monster_spell.get("classes", []) == ["bard", "sorcerer", "warlock", "wizard"] and not hold_monster_result.get("saved", true) and initially_paralyzed, "Hold Monster records its SRD duration, classes, upcast targets, and Paralyzed result on a failed Wisdom save")
	_assert(not hold_monster_repeat_fail.get("saved", true) and still_paralyzed_after_failed_save and hold_monster_repeat_success.get("saved", false) and not hold_monster_victim.get("conditions", {}).has("paralyzed") and hold_monster_critical.get("crit", false), "Hold Monster repeats Wisdom saves and removes Paralyzed on success; adjacent attacks critically hit")
	_assert(hold_monster_saved_result.get("saved", false) and not hold_monster_save_victim.get("conditions", {}).has("paralyzed") and duplicate_hold_monster.get("success", false) and int(hold_monster_caster.spell_slots["5"]) == hold_monster_slot_before - 1 and hold_monster_already_paralyzed.get("condition_sources", {}).get("paralyzed", {}).has("ordinary"), "A successful initial save avoids Paralyzed, and a legal overlapping cast spends a slot and preserves the ordinary Paralyzed source")
	_assert(not paralyzed_dex_save.get("saved", true) and paralyzed_monster_speed == 0, "Paralyzed monsters automatically fail Dexterity saves and cannot move")
	var paralyzed_speed_character := _fresh_char("Paralyzed Speed", "human", "fighter", {})
	paralyzed_speed_character.add_condition("paralyzed", 2)
	_assert(paralyzed_speed_character.get_speed() == 0, "Paralyzed characters have no movement speed")
	for hold_monster_class in ["bard", "sorcerer", "warlock", "wizard"]:
		_assert("hold_monster" in DataLoader.get_character_class(hold_monster_class).get("spell_list_ids", []), "Hold Monster is available to %s" % hold_monster_class.capitalize())
	for poison_class in ["cleric", "druid", "paladin", "ranger"]:
		_assert("protection_from_poison" in DataLoader.get_character_class(poison_class).get("spell_list_ids", []), "Protection from Poison is available to %s" % poison_class.capitalize())
	var purify_spell: Dictionary = DataLoader.get_spell("purify_food_and_drink")
	var purify_caster := _fresh_char("Purify Caster", "human", "cleric", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 14, "CHA": 10})
	_assert(SpellSupport.is_available(purify_spell) and purify_spell.get("rules_source", "") == "SRD5.2.1" and purify_spell.get("rules_status", "") == "2024-gameplay-partial" and purify_spell.get("area_shape", "") == "sphere" and purify_spell.get("area_radius_feet", 0) == 5 and purify_spell.get("range", 0) == 2 and purify_spell.get("removes", []).size() == 2, "Purify Food and Drink is enabled for its bounded room-object path with the SRD range, area and removal rules")
	var reincarnate_spell: Dictionary = DataLoader.get_spell("reincarnate")
	var reincarnate_caster := _fresh_char("Reincarnate Caster", "elf", "druid", {})
	reincarnate_caster.spell_slots["5"] = 1
	var reincarnate_slots_before: Dictionary = reincarnate_caster.spell_slots.duplicate(true)
	var reincarnate_target := _fresh_char("Reincarnate Target", "human", "fighter", {})
	reincarnate_target.current_hp = 0
	reincarnate_target.is_alive = false
	var reincarnate_result := CombatAction.resolve_spell(reincarnate_caster, reincarnate_target, reincarnate_spell, true)
	_assert(reincarnate_spell.get("rules_source", "") == "SRD5.2.1" and reincarnate_spell.get("rules_status", "") == "2024-gameplay-partial" and reincarnate_spell.get("casting_time", "") == "hour" and reincarnate_spell.get("maximum_time_since_death_days", 0) == 10 and reincarnate_spell.get("species_table", []).size() == 10 and reincarnate_result.get("unavailable", false) and reincarnate_caster.spell_slots == reincarnate_slots_before, "Reincarnate records the current hour-long SRD spell but safely refuses to spend a slot without corpse, death-time, and species-choice state")
	var ray_sickness: Dictionary = DataLoader.get_spell("ray_of_sickness")
	var ray_caster := _fresh_char("Ray Caster", "human", "wizard", {"STR": 10, "DEX": 10, "CON": 10, "INT": 16, "WIS": 10, "CHA": 10})
	ray_caster.level = 5
	var ray_sickness_target := {"id": "ray_target", "name": "Ray Target", "current_hp": 30, "max_hp": 30, "is_alive": true, "conditions": {}}
	var missed_ray_effects := CombatAction.apply_spell_hit_effects(ray_sickness_target, ray_sickness, {"hit": false}, "ray_caster")
	var hit_ray_effects := CombatAction.apply_spell_hit_effects(ray_sickness_target, ray_sickness, {"hit": true}, "ray_caster")
	_assert(ray_sickness.get("school", "") == "necromancy" and ray_sickness.get("rules_status", "") == "2024-gameplay-partial" and ray_sickness.get("upcast", {}).get("damage_per_level", "") == "1d8" and CombatAction.spell_damage_formula(ray_caster, ray_sickness, 4) == "2d8 + 3d8" and missed_ray_effects.is_empty() and hit_ray_effects.size() == 1 and ray_sickness_target.get("conditions", {}).has("poisoned"), "Ray of Sickness uses the 2024 no-save hit poison effect, scales up by slot, and does nothing on a miss")
	for ray_class in ["sorcerer", "wizard"]:
		_assert("ray_of_sickness" in DataLoader.get_character_class(ray_class).get("spell_list_ids", []), "Ray of Sickness is available to %s" % ray_class.capitalize())
	var ray_enfeeblement: Dictionary = DataLoader.get_spell("ray_of_enfeeblement")
	var enfeebled_attacker := _fresh_char("Enfeebled Attacker", "human", "fighter", {"STR": 16, "DEX": 10, "CON": 12, "INT": 10, "WIS": 10, "CHA": 10})
	enfeebled_attacker.add_condition("ray_of_enfeeblement", 10)
	var enfeebled_attack := enfeebled_attacker.make_attack_roll("STR")
	var dexterous_attack := enfeebled_attacker.make_attack_roll("DEX")
	var enfeebled_damage_target := {"id": "enfeeblement_damage_target", "current_hp": 30, "max_hp": 30, "is_alive": true, "conditions": {}, "damage_resistances": [], "damage_immunities": []}
	var enfeebled_damage := CombatAction.resolve_damage(enfeebled_damage_target, 20, "force", {}, false, false, enfeebled_attacker)
	var enfeebled_monster_attacker := _fresh_char("Monster Attack", "human", "fighter", {"STR": 16, "DEX": 10, "CON": 12, "INT": 10, "WIS": 10, "CHA": 10})
	enfeebled_monster_attacker.add_condition("ray_of_enfeeblement", 10)
	var monster_damage_target := {"id": "enfeeblement_monster_target", "current_hp": 30, "max_hp": 30, "is_alive": true, "conditions": {}, "damage_resistances": [], "damage_immunities": []}
	var monster_enfeebled_damage := CombatAction.resolve_damage(monster_damage_target, 20, "force", {}, false, false, enfeebled_monster_attacker)
	_assert(ray_enfeeblement.get("school", "") == "necromancy" and ray_enfeeblement.get("repeat_save", "") == "CON" and ray_enfeeblement.get("damage_roll_penalty", "") == "1d8" and enfeebled_attack.get("disadvantage", false) and not dexterous_attack.get("disadvantage", false) and int(enfeebled_damage.get("resolved", -1)) >= 12 and int(enfeebled_damage.get("resolved", -1)) <= 19 and int(monster_enfeebled_damage.get("resolved", -1)) >= 12 and int(monster_enfeebled_damage.get("resolved", -1)) <= 19, "Ray of Enfeeblement applies Disadvantage to Strength attacks and reduces its target's Character and monster damage rolls")
	var regenerate: Dictionary = DataLoader.get_spell("regenerate")
	var regenerate_caster := _fresh_char("Regeneration Caster", "human", "cleric", {"STR": 10, "DEX": 10, "CON": 12, "INT": 10, "WIS": 16, "CHA": 10})
	var regenerate_target := _fresh_char("Regeneration Target", "human", "fighter", {"STR": 16, "DEX": 10, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	regenerate_target.level = 10
	regenerate_target.max_hp = 100
	regenerate_target.current_hp = 1
	var regenerate_result := CombatAction.resolve_spell(regenerate_caster, regenerate_target, regenerate, false, {}, [], 7, 0)
	var regenerate_monster := {"id": "regenerate_monster", "name": "Regenerating Monster", "current_hp": 1, "max_hp": 100, "is_alive": true, "conditions": {}}
	var regenerate_monster_result := CombatAction.resolve_spell(regenerate_caster, regenerate_monster, regenerate, false, {}, [], 7, 0)
	_assert(regenerate.get("rules_source", "") == "SRD5.2.1" and regenerate.get("rules_status", "") == "2024-gameplay-partial" and regenerate.get("healing_per_turn", 0) == 1 and regenerate.get("restores_body_parts_after_seconds", 0) == 120 and regenerate_result.get("healing", 0) >= 19 and regenerate_target.has_condition("regenerate") and regenerate_result.get("regeneration_turns", 0) == 600 and regenerate_monster_result.get("healing", 0) >= 19 and regenerate_monster.get("conditions", {}).has("regenerate"), "Regenerate immediately heals Characters and monsters and grants one hour of turn-start regeneration")
	var remove_curse: Dictionary = DataLoader.get_spell("remove_curse")
	_assert(remove_curse.get("rules_source", "") == "SRD5.2.1" and remove_curse.get("rules_status", "") == "2024-gameplay-partial" and remove_curse.get("removes_conditions", []) == ["cursed"] and bool(remove_curse.get("breaks_cursed_item_attunement", false)), "Remove Curse records its 2024 creature curse and cursed-item behavior while item attunement stays outside current support")
	for curse_class in ["cleric", "paladin", "warlock", "wizard"]:
		_assert("remove_curse" in DataLoader.get_character_class(curse_class).get("spell_list_ids", []), "Remove Curse is available to %s" % curse_class.capitalize())
	_assert(guidance_check.get("guidance_bonus", 0) >= 1 and guidance_check.get("guidance_bonus", 0) <= 4 and guidance_check.get("total", 0) == guidance_check.get("natural_roll", 0) + guidance_check.get("modifier", 0) + guidance_check.get("guidance_bonus", 0) and unrelated_guidance_check.get("guidance_bonus", -1) == 0, "Guidance adds 1d4 to checks using the chosen skill only")
	for guidance_class in ["bard", "cleric", "druid"]:
		_assert("guidance" in DataLoader.get_character_class(guidance_class).get("spell_list_ids", []), "Guidance is available to %s" % guidance_class.capitalize())
	_assert(not mockery_resolution.get("saved", true) and int(mockery_resolution.get("damage", 0)) >= 1 and int(mockery_resolution.get("damage", 0)) <= 6 and mockery_effects.size() == 1 and mockery_attack.get("disadvantage", false) and not mockery_target.get("conditions", {}).has("vicious_mockery_disadvantage"), "Vicious Mockery applies Disadvantage to and consumes a monster's next attack after a failed save")
	_assert(CombatAction.apply_spell_failed_save_effects(mockery_target, vicious_mockery, {"saved": true}).is_empty() and not mockery_attack_after_expiry.get("disadvantage", false), "Vicious Mockery has no effect on a successful save and expires at the target's turn end")
	_assert(missed_chill_effects.is_empty() and not CombatAction.is_healing_suppressed(chill_miss_target), "Chill Touch applies no healing restriction on a miss")
	for chill_class in ["sorcerer", "warlock", "wizard"]:
		_assert("chill_touch" in DataLoader.get_character_class(chill_class).get("spell_list_ids", []), "Chill Touch is available to %s" % chill_class.capitalize())
	var starry_target := _monster_inst("goblin")
	starry_target["conditions"]["invisible"] = 3
	var starry_spell := DataLoader.get_spell("starry_wisp")
	_assert(starry_spell.get("range", 0) == 12 and starry_spell.get("rules_source", "") == "SRD5.2.1", "Starry Wisp records its 60-foot SRD range")
	var missed_starry_effects := CombatAction.apply_spell_hit_effects(starry_target, starry_spell, {"hit": false})
	_assert(missed_starry_effects.is_empty() and CombatAction.is_invisible(starry_target), "Starry Wisp does not remove Invisible benefits on a missed spell attack")
	var applied_starry_effects := CombatAction.apply_spell_hit_effects(starry_target, starry_spell, {"hit": true})
	_assert(applied_starry_effects.size() == 1 and starry_target["conditions"].has("starry_wisp") and not CombatAction.is_invisible(starry_target), "Starry Wisp hit suppresses Invisible benefits through the target's next turn")
	var guiding_bolt: Dictionary = DataLoader.get_spell("guiding_bolt")
	var guiding_target := _monster_inst("goblin")
	var missed_guiding_effects := CombatAction.apply_spell_hit_effects(guiding_target, guiding_bolt, {"hit": false})
	var hit_guiding_effects := CombatAction.apply_spell_hit_effects(guiding_target, guiding_bolt, {"hit": true})
	_assert(CombatAction.spell_damage_formula(scaling_caster, guiding_bolt, 3) == "4d6 + 2d6" and missed_guiding_effects.is_empty() and hit_guiding_effects.size() == 1 and guiding_target["conditions"].has("guiding_bolt"), "Guiding Bolt adds 1d6 per higher slot and marks its target only on a hit")
	_assert(CombatAction.consume_guiding_bolt_advantage(guiding_target) and not guiding_target["conditions"].has("guiding_bolt") and not CombatAction.consume_guiding_bolt_advantage(guiding_target), "Guiding Bolt grants Advantage once and its mark is consumed by that attack")
	_assert("guiding_bolt" in DataLoader.get_character_class("cleric").get("spells_known_by_level", {}).get("1", []) and "guiding_bolt" in DataLoader.get_character_class("cleric").get("spell_list_ids", []), "Guiding Bolt is available as a Cleric level-1 spell")
	var inflict_wounds: Dictionary = DataLoader.get_spell("inflict_wounds")
	var inflict_saved_target := _monster_inst("goblin")
	inflict_saved_target["saving_throw_bonuses"] = {"CON": 100}
	var inflict_failed_target := _monster_inst("goblin")
	inflict_failed_target["saving_throw_bonuses"] = {"CON": -100}
	var inflict_saved_cast := CombatAction.resolve_spell(scaling_caster, inflict_saved_target, inflict_wounds, false, {}, [], 3)
	var inflict_failed_cast := CombatAction.resolve_spell(scaling_caster, inflict_failed_target, inflict_wounds, false, {}, [], 3)
	_assert(inflict_wounds.get("school", "") == "necromancy" and inflict_wounds.get("save", "") == "CON" and inflict_wounds.get("half_on_save", false) and inflict_wounds.get("components", []) == ["V", "S"] and CombatAction.spell_damage_formula(scaling_caster, inflict_wounds, 3) == "2d10 + 2d10" and inflict_saved_cast.get("saved", false) and int(inflict_saved_cast.get("damage", 0)) >= 2 and int(inflict_saved_cast.get("damage", 0)) <= 20 and not inflict_failed_cast.get("saved", true) and int(inflict_failed_cast.get("damage", 0)) >= 4 and int(inflict_failed_cast.get("damage", 0)) <= 40, "Inflict Wounds uses its Constitution save, half damage, and 1d10 per higher slot")
	_assert("inflict_wounds" in DataLoader.get_character_class("cleric").get("spells_known_by_level", {}).get("1", []) and "inflict_wounds" in DataLoader.get_character_class("cleric").get("spell_list_ids", []), "Inflict Wounds is learnable as a Cleric level-1 spell")
	var healing_word: Dictionary = DataLoader.get_spell("healing_word")
	var word_target: Character = _fresh_char("Healing Word Target", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	word_target.max_hp = 100
	word_target.current_hp = 1
	var word_effects := CombatAction.spell_effects_for_slot_level(healing_word, 3)
	var word_heal_results := EventResolver.apply_effects(word_target, word_effects, scaling_caster)
	_assert(healing_word.get("casting_time", "") == "bonus_action" and healing_word.get("components", []) == ["V"] and word_effects[0].get("value", "") == "2d4 + 4d4" and int(word_heal_results[0].get("amount", 0)) >= 9 and int(word_heal_results[0].get("amount", 0)) <= 27, "Healing Word upcasts by 2d4 and adds the caster's spellcasting modifier")
	var cure_wounds: Dictionary = DataLoader.get_spell("cure_wounds")
	var cure_target: Character = _fresh_char("Cure Wounds Target", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	cure_target.max_hp = 100
	cure_target.current_hp = 1
	var cure_effects := CombatAction.spell_effects_for_slot_level(cure_wounds, 3)
	var cure_heal_results := EventResolver.apply_effects(cure_target, cure_effects, scaling_caster)
	var undead_heal_target := {"id": "undead_heal_target", "name": "Undead", "creature_type": "undead", "current_hp": 20, "max_hp": 20, "is_alive": true}
	_assert(cure_wounds.get("school", "") == "abjuration" and cure_effects[0].get("value", "") == "2d8 + 4d8" and int(cure_heal_results[0].get("amount", 0)) >= 9 and int(cure_heal_results[0].get("amount", 0)) <= 51 and CombatAction.validate_spell_target(scaling_caster, undead_heal_target, healing_word).get("success", false), "Cure Wounds uses 2024 2d8 scaling and caster modifier; healing spells can target Undead")
	for healing_class in ["bard", "cleric", "druid"]:
		_assert("healing_word" in DataLoader.get_character_class(healing_class).get("spells_known_by_level", {}).get("1", []) and "healing_word" in DataLoader.get_character_class(healing_class).get("spell_list_ids", []), "Healing Word is available to %s" % healing_class.capitalize())
	var shocking_grasp: Dictionary = DataLoader.get_spell("shocking_grasp")
	var shocked_target := _monster_inst("goblin")
	var missed_shock_effects := CombatAction.apply_spell_hit_effects(shocked_target, shocking_grasp, {"hit": false})
	var hit_shock_effects := CombatAction.apply_spell_hit_effects(shocked_target, shocking_grasp, {"hit": true})
	var level_eleven_caster: Character = _fresh_char("Level Eleven Caster", "human", "wizard", {"INT": 16})
	for _level in 10:
		level_eleven_caster.level_up()
	_assert(CombatAction.spell_damage_formula(level_eleven_caster, DataLoader.get_spell("poison_spray")) == "3d12" and CombatAction.spell_damage_formula(level_eleven_caster, sacred_flame) == "3d8" and CombatAction.spell_damage_formula(level_eleven_caster, DataLoader.get_spell("chill_touch")) == "3d10" and CombatAction.spell_damage_formula(level_eleven_caster, vicious_mockery) == "3d6" and CombatAction.spell_damage_formula(level_eleven_caster, acid_splash) == "3d6", "Poison Spray, Sacred Flame, Chill Touch, Vicious Mockery, and Acid Splash receive their level-11 cantrip upgrades")
	var level_seventeen_caster: Character = _fresh_char("Level Seventeen Caster", "human", "cleric", {"WIS": 16})
	for _level in 16:
		level_seventeen_caster.level_up()
	_assert(CombatAction.spell_damage_formula(level_seventeen_caster, sacred_flame) == "4d8" and CombatAction.spell_damage_formula(level_seventeen_caster, DataLoader.get_spell("chill_touch")) == "4d10" and CombatAction.spell_damage_formula(level_seventeen_caster, vicious_mockery) == "4d6" and CombatAction.spell_damage_formula(level_seventeen_caster, acid_splash) == "4d6", "Sacred Flame, Chill Touch, Vicious Mockery, and Acid Splash receive their level-17 cantrip upgrades")
	_assert(shocking_grasp.get("attack_type", "") == "melee_spell" and shocking_grasp.get("components", []) == ["V", "S"] and CombatAction.spell_damage_formula(scaling_caster, shocking_grasp) == "2d8" and CombatAction.spell_damage_formula(level_eleven_caster, shocking_grasp) == "3d8" and missed_shock_effects.is_empty() and hit_shock_effects.size() == 1 and CombatAction.blocks_opportunity_attack(shocked_target), "Shocking Grasp uses melee spell attack and official cantrip scaling, blocking Opportunity Attacks only after a hit")
	CombatAction.clear_shocking_grasp(shocked_target)
	_assert(not CombatAction.blocks_opportunity_attack(shocked_target), "Shocking Grasp's Opportunity Attack restriction clears at the start of the target's next turn")
	for shock_class in ["sorcerer", "wizard"]:
		_assert("shocking_grasp" in DataLoader.get_character_class(shock_class).get("spell_list_ids", []), "Shocking Grasp counts as a %s cantrip" % shock_class.capitalize())
	var blight_spell := DataLoader.get_spell("blight")
	var plant_target := _monster_inst("goblin")
	plant_target["creature_type"] = "plant"
	plant_target["current_hp"] = 200
	var blight_cast := CombatAction.resolve_spell(scaling_caster, plant_target, blight_spell, false, {}, [], 5)
	_assert(CombatAction.spell_damage_formula(scaling_caster, blight_spell, 5) == "8d8 + 1d8" and blight_cast.get("success", false) and not blight_cast.get("saved", true) and int(blight_cast.get("damage", 0)) >= 9 and int(blight_cast.get("damage", 0)) <= 72, "Blight automatically fails Plant saves and adds its higher-slot damage through the shared resolver")
	var heal_spell := DataLoader.get_spell("heal")
	var healed_character: Character = _fresh_char("Heal Target", "human", "cleric", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 14, "CHA": 10})
	healed_character.current_hp = 1
	for condition in ["blinded", "deafened", "poisoned"]:
		healed_character.add_condition(condition, 4)
	var heal_cast := CombatAction.resolve_spell(scaling_caster, healed_character, heal_spell, false, {}, [], 7)
	var heal_effect_results := EventResolver.apply_effects(healed_character, CombatAction.spell_effects_for_slot_level(heal_spell, int(heal_cast.get("slot_level", 0))), scaling_caster)
	_assert(heal_cast.get("success", false) and healed_character.current_hp > 1 and not healed_character.has_condition("blinded") and not healed_character.has_condition("deafened") and not healed_character.has_condition("poisoned") and heal_effect_results.size() == 4, "Heal restores upcast-scaled HP and ends its three listed conditions")
	var shield_of_faith: Dictionary = DataLoader.get_spell("shield_of_faith")
	var faith_caster: Character = _fresh_char("Faith Cleric", "human", "cleric", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	var faith_target: Character = _fresh_char("Faith Target", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	var faith_ac_before := faith_target.get_ac()
	var faith_cast := CombatAction.resolve_spell(faith_caster, faith_target, shield_of_faith)
	var faith_effects := EventResolver.apply_effects(faith_target, shield_of_faith.get("effects", []), faith_caster)
	_assert(shield_of_faith.get("range", 0) == 12 and shield_of_faith.get("components", []) == ["V", "S", "M"] and shield_of_faith.get("concentration", false) and faith_cast.get("success", false) and faith_effects.size() == 1 and faith_target.get_ac() == faith_ac_before + 2, "Shield of Faith resolves a concentration-bound single-ally cast and grants +2 AC")
	for shield_class in ["cleric", "paladin"]:
		var shield_class_data: Dictionary = DataLoader.get_character_class(shield_class)
		_assert("shield_of_faith" in shield_class_data.get("spells_known_by_level", {}).get("1", []) and "shield_of_faith" in shield_class_data.get("spell_list_ids", []), "Shield of Faith is learnable by %s" % shield_class.capitalize())
	var false_life: Dictionary = DataLoader.get_spell("false_life")
	var false_life_base: Character = _fresh_char("False Life Base", "human", "sorcerer", {"STR": 8, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 16})
	var false_life_cast := CombatAction.resolve_spell(false_life_base, false_life_base, false_life)
	var false_life_effects := EventResolver.apply_effects(false_life_base, CombatAction.spell_effects_for_slot_level(false_life, 1), false_life_base)
	var false_life_upcast: Character = _fresh_char("False Life Upcast", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 16, "WIS": 10, "CHA": 10})
	var false_life_upcast_cast := CombatAction.resolve_spell(false_life_upcast, false_life_upcast, false_life, false, {}, [], 3)
	var false_life_upcast_effects := EventResolver.apply_effects(false_life_upcast, CombatAction.spell_effects_for_slot_level(false_life, 3), false_life_upcast)
	_assert(false_life_cast.get("success", false) and false_life_base.temp_hp >= 6 and false_life_base.temp_hp <= 12 and false_life_effects.size() == 1 and false_life_upcast_cast.get("success", false) and false_life_upcast.temp_hp >= 16 and false_life_upcast.temp_hp <= 22 and false_life_upcast_effects.size() == 1, "False Life grants 2d4+4 temporary HP and adds 5 per spell slot level above 1")
	false_life_base.temp_hp = 99
	var false_life_no_stack := EventResolver.apply_effects(false_life_base, CombatAction.spell_effects_for_slot_level(false_life, 1), false_life_base)
	_assert(false_life_base.temp_hp == 99 and int(false_life_no_stack[0].get("amount", -1)) == 0, "False Life keeps the higher existing temporary HP total")
	for false_life_class in ["sorcerer", "wizard"]:
		var false_life_class_data: Dictionary = DataLoader.get_character_class(false_life_class)
		_assert("false_life" in false_life_class_data.get("spells_known_by_level", {}).get("1", []) and "false_life" in false_life_class_data.get("spell_list_ids", []), "False Life is learnable by %s" % false_life_class.capitalize())
	var ice_knife: Dictionary = DataLoader.get_spell("ice_knife")
	_assert(not ice_knife.is_empty() and ice_knife.get("attack_type", "") == "ranged_spell" and ice_knife.get("splash_save", "") == "DEX" and ice_knife.get("splash_radius", 0) == 1 and ice_knife.get("components", []) == ["S", "M"], "Ice Knife records its piercing attack, 5-foot burst, saving throw, and components")
	for spell_class in ["druid", "sorcerer", "wizard"]:
		var class_data: Dictionary = DataLoader.get_character_class(spell_class)
		_assert("ice_knife" in class_data.get("spells_known_by_level", {}).get("1", []) and "ice_knife" in class_data.get("spell_list_ids", []), "Ice Knife is available to %s and participates in its class spell rules" % spell_class.capitalize())
	for spell_class in ["bard", "druid"]:
		_assert("starry_wisp" in DataLoader.get_character_class(spell_class).get("spell_list_ids", []), "Starry Wisp counts as a %s spell for class features" % spell_class.capitalize())
	for spell_class in ["druid", "sorcerer", "warlock", "wizard"]:
		_assert("blight" in DataLoader.get_character_class(spell_class).get("spell_list_ids", []), "Blight counts as a %s spell for class features" % spell_class.capitalize())
	for spell_class in ["cleric", "druid"]:
		_assert("heal" in DataLoader.get_character_class(spell_class).get("spell_list_ids", []), "Heal counts as a %s spell for class features" % spell_class.capitalize())
	var ice_splash := ice_knife.duplicate(true)
	ice_splash["attack_type"] = "none"
	ice_splash["damage"] = ice_knife.get("splash_damage", "2d6")
	ice_splash["damage_type"] = ice_knife.get("splash_damage_type", "cold")
	ice_splash["save"] = ice_knife.get("splash_save", "DEX")
	ice_splash["half_on_save"] = true
	ice_splash["upcast"]["damage_per_level"] = ice_splash["upcast"]["splash_damage_per_level"]
	var ice_target := _monster_inst("goblin")
	ice_target["current_hp"] = 100
	var ice_splash_result := CombatAction.resolve_spell(scaling_caster, ice_target, ice_splash, false, {}, [], 2, 30)
	_assert(ice_splash_result.get("success", false) and CombatAction.spell_damage_formula(scaling_caster, ice_splash, 2) == "2d6 + 1d6" and int(ice_splash_result.get("damage", -1)) >= 0 and int(ice_splash_result.get("damage", -1)) <= 18, "Ice Knife burst uses a Dexterity save, halves on success, and adds 1d6 when upcast")
	var acid_arrow: Dictionary = DataLoader.get_spell("melfs_acid_arrow")
	var acid_arrow_access: Dictionary = DataLoader.get_character_class("wizard")
	_assert(not acid_arrow.is_empty() and acid_arrow.get("components", []) == ["V", "S", "M"] and acid_arrow.get("duration", "") == "instantaneous" and "melfs_acid_arrow" in acid_arrow_access.get("spells_known_by_level", {}).get("2", []) and "melfs_acid_arrow" in acid_arrow_access.get("spell_list_ids", []), "Melf's Acid Arrow has SRD components and is a Wizard level-2 spell")
	_assert(CombatAction.spell_damage_formula(scaling_caster, acid_arrow, 3) == "4d4 + 1d4" and CombatAction.spell_delayed_damage_for_resolution(scaling_caster, acid_arrow, {"hit": true, "slot_level": 3}).get("formula", "") == "2d4 + 1d4" and CombatAction.spell_delayed_damage_for_resolution(scaling_caster, acid_arrow, {"hit": false, "slot_level": 3}).is_empty(), "Melf's Acid Arrow upcasts both damage rolls but queues delayed damage only on a hit")
	var acid_miss_target := _monster_inst("goblin")
	acid_miss_target["armor_class"] = 1000
	acid_miss_target["current_hp"] = 1000
	var acid_miss_result: Dictionary = {}
	for _attempt in 40:
		acid_miss_result = CombatAction.resolve_spell(scaling_caster, acid_miss_target, acid_arrow, false, {}, [], 3, 30)
		if not bool(acid_miss_result.get("hit", true)):
			break
	_assert(acid_miss_result.get("success", false) and not acid_miss_result.get("hit", true) and int(acid_miss_result.get("damage", -1)) >= 2 and int(acid_miss_result.get("damage", -1)) <= 10, "Melf's Acid Arrow deals half its upcast initial damage on a miss and skips its later damage")
	var disintegrate_spell: Dictionary = DataLoader.get_spell("disintegrate")
	for spell_class in ["sorcerer", "wizard"]:
		var disintegrate_class: Dictionary = DataLoader.get_character_class(spell_class)
		_assert("disintegrate" in disintegrate_class.get("spells_known_by_level", {}).get("6", []) and "disintegrate" in disintegrate_class.get("spell_list_ids", []), "Disintegrate is available to %s for level-6 spell features" % spell_class.capitalize())
	var disintegrate_target := _monster_inst("goblin")
	disintegrate_target["current_hp"] = 1000
	var disintegrate_result := CombatAction.resolve_spell(scaling_caster, disintegrate_target, disintegrate_spell, false, {}, [], 7, 30)
	_assert(disintegrate_result.get("success", false) and disintegrate_spell.get("save", "") == "DEX" and disintegrate_spell.get("half_on_save", false) and CombatAction.spell_damage_formula(scaling_caster, disintegrate_spell, 7) == "10d6+40 + 3d6" and int(disintegrate_result.get("damage", 0)) >= 26 and int(disintegrate_result.get("damage", 0)) <= 118, "Disintegrate uses its Dexterity save, half damage, and 3d6 level-7 upcast increase")
	var disintegrated_character: Character = _fresh_char("Dust Target", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	disintegrated_character.disintegrated = true
	var restored_disintegrated: Character = Character.new()
	restored_disintegrated.from_dict(disintegrated_character.to_dict())
	_assert(restored_disintegrated.disintegrated and restored_disintegrated.heal(20) == 0, "Disintegrated state survives saves and prevents ordinary healing")
	# Fireball: level 3 save-based AoE. Caster is a wizard with INT.
	var caster: Character = _fresh_char("Mage", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	caster.spell_slots = {"3": 1}
	var fb: Dictionary = DataLoader.get_spell("fireball")
	var fire_bolt_data: Dictionary = DataLoader.get_spell("fire_bolt")
	var ray_of_frost_data: Dictionary = DataLoader.get_spell("ray_of_frost")
	var light_data: Dictionary = DataLoader.get_spell("light")
	var scorching_ray_data: Dictionary = DataLoader.get_spell("scorching_ray")
	var counterspell_data: Dictionary = DataLoader.get_spell("counterspell")
	var sleep_data: Dictionary = DataLoader.get_spell("sleep")
	_assert(int(fire_bolt_data.get("range", 0)) == 24 and int(ray_of_frost_data.get("range", 0)) == 12 and int(light_data.get("range", 0)) == 1 and int(scorching_ray_data.get("range", 0)) == 24 and int(counterspell_data.get("range", 0)) == 12, "Curated spell ranges match 120-foot, 60-foot, and touch ranges on five-foot hexes")
	_assert(SpellSupport.is_available(sleep_data) and SpellEffects.manages(sleep_data) and sleep_data.get("save", "") == "WIS" and int(sleep_data.get("area_radius", 0)) == 1 and bool(sleep_data.get("concentration", false)) and bool(sleep_data.get("end_on_any_damage", false)), "Sleep is available with its 2024 Wisdom save, five-foot sphere, concentration, and damage-break metadata")
	var one_ray_spell := scorching_ray_data.duplicate(true)
	one_ray_spell["_scorching_ray_count_for_target"] = 1
	var two_ray_spell := scorching_ray_data.duplicate(true)
	two_ray_spell["_scorching_ray_count_for_target"] = 2
	_assert(CombatAction.scorching_ray_count(null, one_ray_spell, 2) == 1 and CombatAction.scorching_ray_count(null, two_ray_spell, 2) == 2 and CombatAction.scorching_ray_count(null, scorching_ray_data, 3) == 4, "Scorching Ray assigns each base/upcast ray to a chosen target")
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
	var shatter_spell: Dictionary = DataLoader.get_spell("shatter")
	_assert(SpellSupport.is_available(shatter_spell) and shatter_spell.get("rules_source", "") == "SRD5.2.1" and shatter_spell.get("area_radius", 0) == 2 and CombatAction.spell_damage_formula(caster, shatter_spell, 3) == "3d8 + 1d8", "Shatter is available for creature targets with its 10-foot Sphere and 1d8-per-slot upcast")
	var shatter_construct: Dictionary = _monster_inst("goblin")
	shatter_construct["creature_type"] = "construct"
	shatter_construct["current_hp"] = 1000
	var shatter_result := CombatAction.resolve_spell(caster, shatter_construct, shatter_spell, false, {}, [], 3, 30)
	_assert(shatter_result.get("success", false) and shatter_result.get("save_disadvantage", false) and int(shatter_result.get("damage", 0)) > 0 and int(shatter_result.get("damage", 0)) <= 32, "Shatter applies Construct saving-throw Disadvantage and upcast Thunder damage")
	# Curated multi-roll spell boundary: Magic Missile auto-hits and resolves all darts.
	var mm: Dictionary = DataLoader.get_spell("magic_missile")
	_assert(int(mm.get("range", 0)) == 24, "Magic Missile uses its 120-foot range on five-foot hexes")
	var caster2: Character = _fresh_char("Mage2", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	var t2: Dictionary = _monster_inst("goblin")
	t2["current_hp"] = 100
	var res3: Dictionary = CombatAction.resolve_spell(caster2, t2, mm, false)
	_assert(res3.get("success", false), "magic_missile spell resolves")
	_assert(res3.get("hit", false) and int(res3.get("dart_count", 0)) == 3 and int(res3.get("damage", 0)) > 0, "Magic Missile resolves three automatic force darts")
	var one_dart_spell := mm.duplicate(true)
	one_dart_spell["_magic_missile_darts_for_target"] = 1
	var two_dart_spell := mm.duplicate(true)
	two_dart_spell["_magic_missile_darts_for_target"] = 2
	_assert(CombatAction.magic_missile_dart_count(one_dart_spell, 1) == 1 and CombatAction.magic_missile_dart_count(two_dart_spell, 1) == 2 and CombatAction.magic_missile_dart_count(mm, 2) == 4, "Magic Missile resolves only the darts assigned to each target and scales assignments when upcast")
	var shield_target := Character.new()
	shield_target.character_name = "Shielded Target"
	SpellPermissionChecks.grant_slot_permission(shield_target, ["shield"])
	shield_target.spell_slots = {"1": 1}
	var shielded_missile := CombatAction.resolve_spell(caster2, shield_target, mm, false, {"shield": true})
	_assert(shielded_missile.get("shield_used", false) and int(shielded_missile.get("damage", -1)) == 0 and not shield_target.reaction_available and int(shield_target.spell_slots.get("1", 0)) == 0 and shield_target.has_condition("shield"), "Shield reaction blocks Magic Missile before damage and spends one Reaction and slot")
	var existing_shield_target := Character.new()
	existing_shield_target.character_name = "Already Shielded Target"
	existing_shield_target.add_condition("shield", 1)
	var existing_shield_missile := CombatAction.resolve_spell(caster2, existing_shield_target, mm, false)
	_assert(existing_shield_missile.get("shield_blocked", false) and int(existing_shield_missile.get("damage", -1)) == 0, "Existing Shield effect prevents Magic Missile damage without another Reaction")
	var ray: Dictionary = DataLoader.get_spell("scorching_ray")
	var ray_target: Dictionary = _monster_inst("goblin")
	ray_target["armor_class"] = 0
	ray_target["current_hp"] = 100
	var ray_cast := CombatAction.resolve_spell(caster2, ray_target, ray, false)
	_assert(ray_cast.get("success", false) and int(ray_cast.get("ray_count", 0)) == 3 and int(ray_cast.get("rays_hit", 0)) > 0 and int(ray_cast.get("damage", 0)) > 0, "Scorching Ray resolves one spell attack and damage roll per ray")
	var shielded_ray_target := Character.new()
	shielded_ray_target.character_name = "Shielded Ray Target"
	SpellPermissionChecks.grant_slot_permission(shielded_ray_target, ["shield"])
	shielded_ray_target.spell_slots = {"1": 1}
	shielded_ray_target.add_modifier("stat", "AC", -20, 5)
	var shielded_ray_ac_before := shielded_ray_target.get_ac()
	var shielded_ray := CombatAction.resolve_spell(caster2, shielded_ray_target, ray, false, {"shield": true})
	_assert(shielded_ray.get("shield_used", false) and shielded_ray.get("rays_hit", 0) == shielded_ray.get("ray_count", 0) and shielded_ray_target.get_ac() == shielded_ray_ac_before + 5 and not shielded_ray_target.reaction_available and int(shielded_ray_target.spell_slots.get("1", 0)) == 0 and shielded_ray_target.has_condition("shield"), "Scorching Ray checks later rays against Shield's +5 AC and spends one Reaction and slot")
	var eldritch_blast_data: Dictionary = DataLoader.get_spell("eldritch_blast")
	var shielded_blast_target := Character.new()
	shielded_blast_target.character_name = "Shielded Blast Target"
	SpellPermissionChecks.grant_slot_permission(shielded_blast_target, ["shield"])
	shielded_blast_target.spell_slots = {"1": 1}
	shielded_blast_target.add_modifier("stat", "AC", -20, 5)
	var shielded_blast_ac_before := shielded_blast_target.get_ac()
	var shielded_blast := CombatAction.resolve_spell(caster2, shielded_blast_target, eldritch_blast_data, false, {"shield": true})
	_assert(shielded_blast.get("shield_used", false) and shielded_blast.get("rays_hit", 0) == shielded_blast.get("ray_count", 0) and shielded_blast_target.get_ac() == shielded_blast_ac_before + 5 and not shielded_blast_target.reaction_available and int(shielded_blast_target.spell_slots.get("1", 0)) == 0 and shielded_blast_target.has_condition("shield"), "Eldritch Blast checks later beams against Shield's +5 AC and spends one Reaction and slot")
	var effect_only: Dictionary = CombatAction.resolve_spell(caster2, caster2, DataLoader.get_spell("mage_armor"), false)
	_assert(effect_only.get("success", false) and effect_only.get("hit", false) and int(effect_only.get("damage", -1)) == 0, "Effect-only Mage Armor resolves without an invalid attack roll")
	var invalid_mage_armor: Dictionary = CombatAction.resolve_spell(caster2, t2, DataLoader.get_spell("mage_armor"), true)
	_assert(not invalid_mage_armor.get("success", true), "Mage Armor rejects a monster target before spending a slot")
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
	pact_warlock.level_up()
	_assert(pact_warlock.spell_slots.get("2", 0) == 2, "Warlock reaches two level-2 pact slots at class level 3")
	var pact_level_two_cast := CombatAction.resolve_spell(pact_warlock, pact_target, mm, true)
	_assert(pact_level_two_cast.get("success", false) and pact_warlock.spell_slots.get("2", 0) == 1 and int(pact_level_two_cast.get("dart_count", 0)) == 4, "Warlock can cast a lower-level spell using a higher-level pact slot and gains its extra dart")
	var magical_cunning: Dictionary = pact_warlock.get_feature("warlock_magical_cunning")
	_assert(magical_cunning.get("type", "") == "active" and magical_cunning.get("action_cost", "") == "action" and magical_cunning.get("uses_per", "") == "long_rest", "Warlock Magical Cunning is a once-per-long-rest action contract")
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
	var font_sorcerer: Character = _fresh_char("Font of Magic", "human", "sorcerer", {"STR": 8, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	font_sorcerer.level_up()
	var font_points_before := font_sorcerer.get_sorcery_points()
	var font_slots_before := int(font_sorcerer.spell_slots.get("1", 0))
	_assert(font_sorcerer.spend_sorcery_points(1), "Font of Magic fixture can spend one point before conversion")
	var convert_command := CombatCommand.from_hud_for_character("font_of_magic_convert", {"slot_level": 1}, font_sorcerer)
	var converted_points := SorcererRules.convert_slot_to_points(font_sorcerer, 1)
	_assert(convert_command != null and converted_points.get("success", false) and font_sorcerer.get_sorcery_points() == font_points_before and int(font_sorcerer.spell_slots.get("1", 0)) == font_slots_before - 1, "Combat Font of Magic converts a selected slot without spending an action")
	var create_command := CombatCommand.from_hud_for_character("font_of_magic_create", {"slot_level": 1}, font_sorcerer)
	var font_budget := CombatTurnBudget.new()
	font_budget.bonus_action_available = false
	var rejected_font_slot := SorcererRules.create_spell_slot(font_sorcerer, 1, font_budget)
	_assert(create_command != null and not rejected_font_slot.get("success", false) and font_sorcerer.get_sorcery_points() == font_points_before, "Combat Font of Magic preserves points when no Bonus Action is available")
	font_budget.bonus_action_available = true
	var created_font_slot := SorcererRules.create_spell_slot(font_sorcerer, 1, font_budget)
	_assert(created_font_slot.get("success", false) and font_sorcerer.get_sorcery_points() == 0 and not font_budget.bonus_action_available, "Combat Font of Magic spends its slot cost and Bonus Action")
	font_sorcerer.long_rest()
	var distant_points_before := font_sorcerer.get_sorcery_points()
	_assert(SorcererRules.spend_metamagic_cost(font_sorcerer, 1, {}) and font_sorcerer.get_sorcery_points() == distant_points_before - 1, "Distant Spell pays its Sorcery Point cost when Arcane Apotheosis is unavailable")
	var innate_sorcery: Dictionary = sorcerer_for_test.get_feature("sorcerer_innate_sorcery")
	_assert(innate_sorcery.get("type", "") == "active" and innate_sorcery.get("action_cost", "") == "bonus_action" and innate_sorcery.get("uses_per", "") == "long_rest" and int(innate_sorcery.get("uses", 0)) == 2, "Sorcerer Innate Sorcery has its SRD two-use long-rest contract")
	var normal_sorcerer_dc := sorcerer_for_test.get_spell_save_dc()
	_assert(sorcerer_for_test.use_feature("sorcerer_innate_sorcery"), "Sorcerer Innate Sorcery spends its combat use")
	var innate_results := EventResolver.apply_effects(sorcerer_for_test, innate_sorcery.get("effects", []))
	_assert(innate_results.size() == 1 and sorcerer_for_test.has_condition("innate_sorcery") and sorcerer_for_test.get_spell_save_dc() == normal_sorcerer_dc + 1, "Innate Sorcery raises the Sorcerer's spell save DC while active")
	var innate_attack := sorcerer_for_test.make_attack_roll("CHA", sorcerer_for_test.has_condition("innate_sorcery"))
	_assert(innate_attack.get("advantage", false), "Innate Sorcery routes spell attacks through the shared advantage roll")
	sorcerer_for_test.level_up()
	_assert(ClassProgression.choose_sorcerer_metamagic(sorcerer_for_test, ["empowered_spell", "heightened_spell"]), "Sorcerer selects the two Metamagic options gained at level 2")
	var twinned_sorcerer: Character = _fresh_char("Twinned Sorcerer", "human", "sorcerer", {"STR": 8, "DEX": 12, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	twinned_sorcerer.level_up()
	_assert(ClassProgression.choose_sorcerer_metamagic(twinned_sorcerer, ["twinned_spell", "extended_spell"]), "Sorcerer selects Twinned Spell from its level-2 Metamagic choices")
	var charm_person_for_twinned := DataLoader.get_spell("charm_person")
	var twinned_charm_person := SorcererRules.apply_twinned_spell(charm_person_for_twinned)
	_assert(SorcererRules.can_twinned_spell(twinned_sorcerer, charm_person_for_twinned, 1) and SorcererRules.twinned_extra_target_count(twinned_charm_person, 2) == 1, "Twinned Spell adds the spell's level-2 upcast target when cast with a level-1 slot")
	_assert(SorcererRules.metamagic_capacity(9) == 2 and SorcererRules.metamagic_capacity(10) == 4 and SorcererRules.metamagic_capacity(17) == 6, "Sorcerer Metamagic choice capacity grows at levels 10 and 17")
	_assert(SorcererRules.distant_spell_range(1) == 6 and SorcererRules.distant_spell_range(8) == 16 and SorcererRules.distant_spell_range(0) == 0, "Distant Spell changes Touch range to 30 feet and doubles longer spell ranges")
	var transmuted_spell := DataLoader.get_spell("fire_bolt").duplicate(true)
	var transmuted_options := SorcererRules.transmuted_damage_options(str(transmuted_spell.get("damage_type", "")))
	_assert(transmuted_options.size() == 5 and "fire" not in transmuted_options and SorcererRules.transmuted_damage_options("force").is_empty(), "Transmuted Spell offers only the other five eligible damage types")
	_assert(SorcererRules.apply_transmuted_damage_type(transmuted_spell, "cold") and str(transmuted_spell.get("damage_type", "")) == "cold" and not SorcererRules.apply_transmuted_damage_type(transmuted_spell, "force"), "Transmuted Spell changes eligible spell damage and rejects ineligible types")
	var transmuted_target: Dictionary = _monster_inst("goblin")
	transmuted_target["armor_class"] = 0
	var transmuted_cast := CombatAction.resolve_spell(sorcerer_for_test, transmuted_target, transmuted_spell)
	_assert(transmuted_cast.get("success", false) and str(transmuted_cast.get("message", "")).contains("cold damage"), "Transmuted damage type reaches the shared production spell resolver")
	var seeking_sorcerer: Character = _fresh_char("Seeking Sorcerer", "human", "sorcerer", {"STR": 8, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	seeking_sorcerer.level_up()
	_assert(ClassProgression.choose_sorcerer_metamagic(seeking_sorcerer, ["seeking_spell", "empowered_spell"]), "Sorcerer can select Seeking Spell from its Metamagic choices")
	var seeking_target: Dictionary = _monster_inst("goblin")
	seeking_target["armor_class"] = 1000
	var seeking_was_used := false
	for rng_seed in range(1, 25):
		seed(rng_seed)
		seeking_sorcerer.feature_uses["sorcery_points"] = 2
		var seeking_cast := CombatAction.resolve_spell(seeking_sorcerer, seeking_target.duplicate(true), transmuted_spell, false, {"metamagic:seeking": true})
		if str(seeking_cast.get("message", "")).contains("Seeking Spell rerolls"):
			seeking_was_used = true
			_assert(seeking_cast.get("success", false) and seeking_cast.get("metamagic_used", false) and seeking_sorcerer.get_sorcery_points() == 1, "Seeking Spell spends one point and keeps the attack's new roll")
		else:
			_assert(seeking_sorcerer.get_sorcery_points() == 2, "Seeking Spell does not spend a point when the first spell attack hits")
	_assert(seeking_was_used, "Seeking Spell triggers on a missed spell attack")
	var stroke_rogue: Character = _fresh_char("Stroke of Luck Rogue", "human", "rogue", {"STR": 8, "DEX": 16, "CON": 12, "INT": 10, "WIS": 10, "CHA": 12})
	for _level in range(19):
		stroke_rogue.level_up()
	var stroke_spell := DataLoader.get_spell("fire_bolt")
	var certain_hit_target: Dictionary = _monster_inst("goblin")
	certain_hit_target["armor_class"] = -100
	seed(1)
	var unneeded_stroke := CombatAction.resolve_spell(stroke_rogue, certain_hit_target, stroke_spell, false, {"stroke_of_luck": true})
	_assert(unneeded_stroke.get("success", false) and not unneeded_stroke.get("stroke_of_luck_used", false) and int(stroke_rogue.feature_uses.get("rogue_stroke_of_luck", 0)) == 1, "Stroke of Luck preserves its use when a spell attack already hits")
	var stroke_target: Dictionary = _monster_inst("goblin")
	stroke_target["armor_class"] = 1000
	var spell_stroke_was_used := false
	for rng_seed in range(1, 25):
		seed(rng_seed)
		stroke_rogue.feature_uses["rogue_stroke_of_luck"] = 1
		var stroke_cast := CombatAction.resolve_spell(stroke_rogue, stroke_target.duplicate(true), stroke_spell, false, {"stroke_of_luck": true})
		if stroke_cast.get("stroke_of_luck_used", false):
			spell_stroke_was_used = true
			_assert(stroke_cast.get("hit", false) and stroke_rogue.feature_uses.get("rogue_stroke_of_luck", 1) == 0, "Stroke of Luck turns a failed spell attack into a critical hit")
	_assert(spell_stroke_was_used, "Stroke of Luck can override a failed spell attack roll")
	var stroke_save_target: Character = _fresh_char("Stroke Save Rogue", "human", "rogue", {"STR": 8, "DEX": 16, "CON": 12, "INT": 10, "WIS": 10, "CHA": 12})
	for _level in range(19):
		stroke_save_target.level_up()
	var stroke_save_caster: Character = _fresh_char("Stroke Save Caster", "human", "wizard", {"STR": 8, "DEX": 10, "CON": 12, "INT": 20, "WIS": 10, "CHA": 10})
	for _level in range(19):
		stroke_save_caster.level_up()
	var stroke_save_spell := DataLoader.get_spell("charm_person")
	var stroke_save_was_used := false
	for rng_seed in range(1, 80):
		seed(rng_seed)
		stroke_save_target.remove_condition("charmed")
		stroke_save_target.feature_uses["rogue_stroke_of_luck"] = 1
		var stroke_save := CombatAction.resolve_spell(stroke_save_caster, stroke_save_target, stroke_save_spell, false, {"stroke_of_luck:%s" % stroke_save_target.character_id: true})
		if stroke_save.get("stroke_of_luck_used", false):
			stroke_save_was_used = true
			_assert(stroke_save.get("saved", false) and not stroke_save_target.has_condition("charmed") and int(stroke_save_target.feature_uses.get("rogue_stroke_of_luck", 1)) == 0, "Stroke of Luck turns a failed spell saving throw into a successful 20")
			break
	_assert(stroke_save_was_used, "Stroke of Luck can override a failed saving throw")
	var stroke_death_target: Character = _fresh_char("Stroke Death Save Rogue", "human", "rogue", {"STR": 8, "DEX": 16, "CON": 12, "INT": 10, "WIS": 10, "CHA": 12})
	for _level in range(19):
		stroke_death_target.level_up()
	stroke_death_target.current_hp = 0
	stroke_death_target.is_alive = false
	var stroke_death_was_used := false
	for rng_seed in range(1, 80):
		seed(rng_seed)
		stroke_death_target.current_hp = 0
		stroke_death_target.is_alive = false
		stroke_death_target.death_save_successes = 0
		stroke_death_target.death_save_failures = 0
		stroke_death_target.feature_uses["rogue_stroke_of_luck"] = 1
		var death_test := stroke_death_target.make_death_save(false, true)
		if death_test.get("stroke_of_luck_used", false):
			stroke_death_was_used = true
			_assert(death_test.get("natural", 0) == 20 and stroke_death_target.current_hp == 1, "Stroke of Luck turns a failed death save into a 20 and restores 1 HP")
			break
	_assert(stroke_death_was_used, "Stroke of Luck can override a failed death saving throw")
	randomize()
	for _level in range(8):
		sorcerer_for_test.level_up()
	_assert(sorcerer_for_test.sorcerer_metamagic_pending == 2 and sorcerer_for_test.sorcerer_metamagic_replacement_available, "Sorcerer level 10 adds two options and one replacement opportunity")
	_assert(ClassProgression.choose_sorcerer_metamagic(sorcerer_for_test, ["careful_spell", "distant_spell"]), "Sorcerer can select new Metamagic options at level 10")
	var careful_spell := DataLoader.get_spell("fireball").duplicate(true)
	careful_spell["duration_seconds"] = 6
	careful_spell["effects"].append({"type": "grant_condition", "condition": "blinded", "on_failed_save": true})
	var careful_target: Dictionary = _monster_inst("goblin")
	careful_target["id"] = "careful-test-target"
	careful_target["current_hp"] = 100
	var careful_result := CombatAction.resolve_spell(sorcerer_for_test, careful_target, careful_spell, false, {"metamagic:careful_targets": ["careful-test-target"]})
	_assert(careful_result.get("saved", false) and int(careful_result.get("damage", -1)) == 0 and not careful_target.get("conditions", {}).has("blinded"), "Careful Spell makes a selected save target succeed, prevents half-on-save damage, and avoids failed-save conditions")
	_assert(SorcererRules.careful_spell_target_limit(sorcerer_for_test) == 3 and SorcererRules.careful_spell_target_limit(null) == 1, "Careful Spell selects up to the Charisma modifier, with a minimum of one creature")
	var extended_sorcerer: Character = _fresh_char("Extended Sorcerer", "human", "sorcerer", {"STR": 8, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	extended_sorcerer.level_up()
	_assert(ClassProgression.choose_sorcerer_metamagic(extended_sorcerer, ["extended_spell", "distant_spell"]), "Sorcerer can select Extended Spell from the Metamagic choices")
	var extended_bless := SorcererRules.apply_extended_spell(DataLoader.get_spell("bless"))
	var extended_cast := SpellEffects.begin_cast(extended_sorcerer, extended_bless)
	_assert(extended_bless.get("_metamagic_extended", false) and int(extended_bless.get("duration_seconds", 0)) == 120 and int(extended_cast.get("remaining_seconds", 0)) == 120 and SharedSpell.content_error(extended_bless).is_empty(), "Extended Spell doubles the shared Bless source lifetime without adding legacy effect fields")
	var extended_permanent := SorcererRules.apply_extended_spell({"duration_seconds": 3600, "effects": [{"type": "set_base_ac", "duration": -1}]})
	_assert(int(extended_permanent.get("duration_seconds", 0)) == 7200 and int(extended_permanent["effects"][0].get("duration", 0)) == -1 and not SorcererRules.can_extend_spell(extended_sorcerer, {"duration_seconds": 6}), "Extended Spell preserves permanent effects and rejects spell durations under one minute")
	var subtle_sorcerer: Character = _fresh_char("Subtle Sorcerer", "human", "sorcerer", {"STR": 8, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	subtle_sorcerer.level_up()
	_assert(ClassProgression.choose_sorcerer_metamagic(subtle_sorcerer, ["subtle_spell", "distant_spell"]), "Sorcerer can select Subtle Spell from the Metamagic choices")
	var subtle_fireball := SorcererRules.apply_subtle_spell(DataLoader.get_spell("fireball"))
	_assert(SorcererRules.can_subtle_spell(subtle_sorcerer, DataLoader.get_spell("fireball")) and subtle_fireball.get("_metamagic_subtle", false) and subtle_fireball.get("components", []).is_empty(), "Subtle Spell removes verbal, somatic, and free material components from a supported cast")
	var costly_subtle := SorcererRules.apply_subtle_spell({"components": ["V", "S", "M"], "material_component_cost": 100})
	var consumed_subtle := SorcererRules.apply_subtle_spell({"components": ["V", "S", "M"], "material_component_consumed": true})
	_assert(costly_subtle.get("components", []) == ["M"] and consumed_subtle.get("components", []) == ["M"] and not SorcererRules.can_subtle_spell(subtle_sorcerer, {"components": ["M"], "material_component_cost": 100}), "Subtle Spell preserves costly or consumed Material components and offers no useless component-only choice")
	var subtle_counterspeller: Character = _fresh_char("Subtle Counterspeller", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 12, "INT": 16, "WIS": 12, "CHA": 10})
	SpellPermissionChecks.grant_slot_permission(subtle_counterspeller, ["counterspell"])
	subtle_counterspeller.spell_slots["3"] = 1
	var subtle_counter_result := CombatAction.resolve_spell(subtle_sorcerer, subtle_counterspeller, subtle_fireball, false, {"counterspell:%s" % subtle_counterspeller.character_name: true}, [subtle_counterspeller])
	var costly_counterspell_data := DataLoader.get_spell("fireball").duplicate(true)
	costly_counterspell_data["material_component_cost"] = 100
	costly_counterspell_data = SorcererRules.apply_subtle_spell(costly_counterspell_data)
	subtle_sorcerer.add_modifier("roll", "save:CON", -1000, 4)
	var costly_counterspeller: Character = _fresh_char("Costly Counterspeller", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 12, "INT": 16, "WIS": 12, "CHA": 10})
	SpellPermissionChecks.grant_slot_permission(costly_counterspeller, ["counterspell"])
	costly_counterspeller.spell_slots["3"] = 1
	costly_counterspeller.add_modifier("roll", "save:CON", -1000, 4)
	var costly_counter_result := CombatAction.resolve_spell(subtle_sorcerer, costly_counterspeller, costly_counterspell_data, false, {"counterspell:%s" % costly_counterspeller.character_name: true}, [costly_counterspeller])
	_assert(subtle_counter_result.get("success", false) and subtle_counterspeller.reaction_available and int(subtle_counterspeller.spell_slots.get("3", 0)) == 1, "A component-free Subtle Spell cannot be countered before it resolves")
	_assert(costly_counter_result.get("countered", false) and not costly_counterspeller.reaction_available and int(costly_counterspeller.spell_slots.get("3", 0)) == 0, "Subtle Spell retains a costly Material component, so its cast remains eligible for Counterspell")
	var distant_spell_combat := CombatState.new()
	distant_spell_combat.active_character = sorcerer_for_test
	_assert(distant_spell_combat._spell_target_range({"range": 1, "_metamagic_distant": true}) == 6 and distant_spell_combat._spell_target_range({"range": 8, "_metamagic_distant": true}) == 16, "Distant Spell extends the combat targeting range for touch and ranged spells")
	distant_spell_combat.free()
	_assert(ClassProgression.replace_sorcerer_metamagic(sorcerer_for_test, "careful_spell", "quickened_spell") and not sorcerer_for_test.sorcerer_metamagic_replacement_available, "Sorcerer can replace one known option once per level-up")
	var quickened_budget := CombatTurnBudget.new()
	quickened_budget.action_available = false
	var quickened_spell := {"id": "fixture:action_spell", "level": 1, "casting_time": "action"}
	_assert(SorcererRules.can_quicken_spell(sorcerer_for_test, quickened_spell, false, quickened_budget), "Quickened Spell can use the available Bonus Action after the Magic action is spent")
	var quickened_copy := SorcererRules.apply_quickened_spell(quickened_spell)
	var quickened_state := CombatState.new()
	_assert(str(quickened_copy.get("casting_time", "")) == "bonus_action" and quickened_state._action_cost_for_command("cast_spell", {"spell": quickened_copy}) == "bonus_action", "Quickened Spell changes the production spell command to a Bonus Action")
	quickened_state.free()
	var saved_quickened_points := sorcerer_for_test.get_sorcery_points()
	sorcerer_for_test.feature_uses["sorcery_points"] = 2
	_assert(SorcererRules.remaining_metamagic_points(sorcerer_for_test, quickened_copy) == 0 and SorcererRules.remaining_metamagic_points(sorcerer_for_test, SorcererRules.apply_quickened_spell(quickened_spell, true)) == 2, "Metamagic affordability reserves Quickened's cost and respects its free-cost marker")
	sorcerer_for_test.feature_uses["sorcery_points"] = saved_quickened_points
	_assert(SorcererRules.spend_metamagic_cost(sorcerer_for_test, SorcererRules.QUICKENED_SPELL_COST, {}) and quickened_budget.spend("bonus_action") and not quickened_budget.action_available, "Quickened Spell pays its Sorcery Point cost and spends only the Bonus Action")
	sorcerer_for_test.feature_uses["sorcerer_quickened_spell_cast_this_turn"] = true
	_assert(SorcererRules.quickened_spell_blocks_cast(sorcerer_for_test, quickened_spell) and not SorcererRules.quickened_spell_blocks_cast(sorcerer_for_test, {"level": 0}), "Quickened Spell blocks later level 1+ casts but permits cantrips")
	sorcerer_for_test.feature_uses.erase("sorcerer_quickened_spell_cast_this_turn")
	SorcererRules.mark_spell_cast_this_turn(sorcerer_for_test, quickened_spell)
	_assert(not SorcererRules.can_quicken_spell(sorcerer_for_test, quickened_spell, true, quickened_budget), "Quickened Spell is unavailable after a level 1+ spell has been cast this turn")
	sorcerer_for_test.feature_uses.erase("sorcerer_levelled_spell_cast_this_turn")
	sorcerer_for_test.feature_uses["sorcerer_quickened_spell_cast_this_turn"] = true
	_assert(not SorcererRules.can_quicken_spell(sorcerer_for_test, quickened_spell, false, quickened_budget), "Quickened Spell cannot be applied twice during the same turn")
	sorcerer_for_test.feature_uses.erase("sorcerer_quickened_spell_cast_this_turn")
	var no_quickened_bonus := CombatTurnBudget.new()
	no_quickened_bonus.bonus_action_available = false
	_assert(not SorcererRules.can_quicken_spell(sorcerer_for_test, quickened_spell, false, no_quickened_bonus), "Quickened Spell requires an available Bonus Action")
	var quickened_points_before := sorcerer_for_test.get_sorcery_points()
	_assert(SorcererRules.spend_metamagic_cost(sorcerer_for_test, SorcererRules.QUICKENED_SPELL_COST, {}) and sorcerer_for_test.get_sorcery_points() == quickened_points_before - 2, "Quickened Spell spends 2 Sorcery Points when the cast is committed")
	sorcerer_for_test.feature_uses["sorcery_points"] = sorcerer_for_test.get_max_sorcery_points()
	for _level in range(7):
		sorcerer_for_test.level_up()
	_assert(sorcerer_for_test.sorcerer_metamagic_pending == 2, "Sorcerer level 17 adds two further Metamagic choices")
	_assert(ClassProgression.choose_sorcerer_metamagic(sorcerer_for_test, ["extended_spell", "subtle_spell"]) and sorcerer_for_test.sorcerer_metamagic_choices.size() == 6, "Sorcerer can fill all six level-17 Metamagic choices")
	var metamagic_target: Dictionary = _monster_inst("goblin")
	metamagic_target["armor_class"] = 0
	var empowered_cast := CombatAction.resolve_spell(sorcerer_for_test, metamagic_target, mm, false, {"metamagic:empowered": true, "metamagic:empowered_dice": [0]})
	_assert(sorcerer_for_test.get_feature("sorcerer_metamagic").get("effects", [])[0].get("type", "") == "metamagic" and sorcerer_for_test.get_sorcery_points() == sorcerer_for_test.get_max_sorcery_points() - 1, "Sorcerer receives production Metamagic and spends one Sorcery Point")
	_assert(empowered_cast.get("success", false) and empowered_cast.get("metamagic_used", false), "Empowered Spell modifies a resolved spell through the shared spell boundary")
	sorcerer_for_test.long_rest()
	_assert(sorcerer_for_test.get_sorcery_points() == sorcerer_for_test.get_max_sorcery_points(), "Sorcery Points fully restore on a long rest")
	for _level in range(3):
		sorcerer_for_test.level_up()
	sorcerer_for_test.feature_uses["sorcerer_innate_sorcery"] = 0
	sorcerer_for_test.remove_condition("innate_sorcery")
	var sorcery_incarnate_points := sorcerer_for_test.get_sorcery_points()
	var no_bonus_action := CombatTurnBudget.new()
	no_bonus_action.bonus_action_available = false
	_assert(not ClassFeature.execute(sorcerer_for_test, sorcerer_for_test.get_feature("sorcerer_innate_sorcery"), null, no_bonus_action).get("success", false) and sorcerer_for_test.get_sorcery_points() == sorcery_incarnate_points, "Sorcery Incarnate cannot bypass an unavailable Bonus Action")
	var sorcery_incarnate_result := ClassFeature.execute(sorcerer_for_test, sorcerer_for_test.get_feature("sorcerer_innate_sorcery"))
	_assert(sorcery_incarnate_result.get("success", false) and sorcerer_for_test.get_sorcery_points() == sorcery_incarnate_points - 2 and sorcerer_for_test.has_condition("innate_sorcery"), "Sorcery Incarnate spends two points to reactivate exhausted Innate Sorcery")
	_assert(not ClassFeature.execute(sorcerer_for_test, sorcerer_for_test.get_feature("sorcerer_innate_sorcery")).get("success", false), "Innate Sorcery cannot be reactivated while its effect is already active")
	var arcane_apotheosis_points := sorcerer_for_test.get_sorcery_points()
	var arcane_apotheosis_cast := CombatAction.resolve_spell(sorcerer_for_test, metamagic_target, mm, false, {"metamagic:empowered": true, "metamagic:empowered_dice": [0], "metamagic:arcane_apotheosis": true})
	_assert(arcane_apotheosis_cast.get("success", false) and arcane_apotheosis_cast.get("metamagic_used", false) and sorcerer_for_test.get_sorcery_points() == arcane_apotheosis_points and sorcerer_for_test.feature_uses.get("sorcerer_arcane_apotheosis_used_this_turn", false), "Arcane Apotheosis waives one Metamagic cost while Innate Sorcery is active")
	var restoration_sorcerer: Character = _fresh_char("Restoration Sorcerer", "human", "sorcerer", {"STR": 8, "DEX": 12, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	for _level in range(4):
		restoration_sorcerer.level_up()
	_assert(restoration_sorcerer.spend_sorcery_points(5), "Sorcerer can spend the level-5 Sorcery Point pool before recovery")
	restoration_sorcerer.short_rest()
	_assert(restoration_sorcerer.get_sorcery_points() == 2, "Sorcerous Restoration recovers half the Sorcerer level after a Short Rest")
	var points_before_second_rest := restoration_sorcerer.get_sorcery_points()
	restoration_sorcerer.short_rest()
	_assert(restoration_sorcerer.get_sorcery_points() == points_before_second_rest, "Sorcerous Restoration cannot be used twice before a Long Rest")
	restoration_sorcerer.long_rest()
	_assert(restoration_sorcerer.get_sorcery_points() == restoration_sorcerer.get_max_sorcery_points(), "Long Rest resets the Sorcerous Restoration use and fills Sorcery Points")
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
	# Counterspell reactions resolve a Constitution save before the incoming spell.
	var victim: Character = _fresh_char("Victim", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	SpellPermissionChecks.grant_slot_permission(victim, ["counterspell"])
	victim.max_hp = 1000
	victim.current_hp = 1000
	victim.spell_slots = {"3": 1}
	victim.reaction_available = true
	var caster3: Character = _fresh_char("Mage3", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	var res4: Dictionary = CombatAction.resolve_spell(caster3, victim, fb, false)
	_assert(res4.get("success", false) and victim.reaction_available and int(victim.spell_slots.get("3", 0)) == 1, "Counterspell only runs when CombatState supplies an eligible observer reaction")
	victim.reaction_available = true
	victim.spell_slots["3"] = 1
	var declined_counterspell := CombatAction.resolve_spell(caster3, target, fb, false, {"counterspell:%s" % victim.character_name: false}, [victim])
	_assert(declined_counterspell.get("success", false) and victim.reaction_available and victim.spell_slots["3"] == 1, "declining an observer Counterspell preserves reaction and slot")
	victim.reaction_available = true
	victim.spell_slots["3"] = 1
	caster3.add_modifier("roll", "save:CON", -1000, 4)
	var accepted_counterspell := CombatAction.resolve_spell(caster3, target, fb, false, {"counterspell:%s" % victim.character_name: true}, [victim])
	if not accepted_counterspell.get("countered", false): print("021 reaction diagnostic: " + JSON.stringify({"result":accepted_counterspell,"choices":SpellPermissionRules.payment_choices(victim,"counterspell"),"slots":victim.spell_slots,"reaction":victim.reaction_available}))
	_assert(accepted_counterspell.get("countered", false) and not victim.reaction_available and victim.spell_slots["3"] == 0, "An accepted Counterspell spends its slot and Reaction and interrupts on a failed Constitution save")
	print("COUNTERSPELL_SAVE_AND_REFUND_CHECKS_COMPLETE")

func _test_grease_spell() -> void:
	var grease: Dictionary = DataLoader.get_spell("grease")
	var area_effect: Dictionary = grease.get("effects", [])[0] if not grease.get("effects", []).is_empty() else {}
	var area_selection := EventResolver.resolve_area_selection(area_effect)
	_assert(SpellSupport.is_available(grease) and grease.get("rules_source", "") == "SRD5.2.1" and grease.get("save", "") == "DEX" and grease.get("condition_on_failed_save", "") == "prone", "Grease is an available SRD spell with its Dexterity save and Prone consequence")
	_assert(area_selection.get("success", false) and area_selection.get("shape", "") == "square" and int(area_selection.get("size_feet", 0)) == 10, "Grease resolves a validated 10-foot square area selection")
	var grid := _build_grid(3)
	var square := Targeting.get_square_targets(Vector2i.ZERO, 10, grid)
	_assert(square.size() == 7 and Vector2i.ZERO in square, "The 10-foot square uses the documented seven-hex approximation")
	var affected: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	grid.add_difficult_terrain("grease:test:1", affected)
	grid.add_difficult_terrain("grease:test:2", affected)
	_assert(is_equal_approx(grid.get_hex_cost(Vector2i.ZERO), 2.0), "Overlapping difficult terrain sources add only one extra movement point")
	grid.remove_difficult_terrain("grease:test:1")
	_assert(is_equal_approx(grid.get_hex_cost(Vector2i.ZERO), 2.0), "Removing one overlapping zone leaves the other zone's movement cost")
	grid.remove_difficult_terrain("grease:test:2")
	_assert(is_equal_approx(grid.get_hex_cost(Vector2i.ZERO), 1.0), "Removing the last zone restores the underlying movement cost")
	print("GREASE_AREA_CHECKS_COMPLETE")
	grid.free()


func _test_spike_growth_spell() -> void:
	var spike_growth: Dictionary = DataLoader.get_spell("spike_growth")
	var area_effect: Dictionary = spike_growth.get("effects", [])[0] if not spike_growth.get("effects", []).is_empty() else {}
	var area_selection := EventResolver.resolve_area_selection(area_effect)
	_assert(SpellSupport.is_available(spike_growth) and spike_growth.get("rules_source", "") == "SRD5.2.1" and spike_growth.get("damage_type", "") == "piercing" and spike_growth.get("damage", "") == "2d4" and bool(spike_growth.get("concentration", false)), "Spike Growth is an available SRD concentration spell with 2d4 piercing damage")
	_assert(area_selection.get("success", false) and area_selection.get("shape", "") == "sphere" and int(area_selection.get("radius", 0)) == 4 and CombatAction.spell_damage_formula(_fresh_char("Spike Formula", "human", "druid", {"WIS": 16}), spike_growth, 3) == "2d4", "Spike Growth selects a 20-foot Sphere and does not add damage when upcast")
	var grid := _build_grid(7)
	var sphere := Targeting.get_sphere_targets(Vector2i.ZERO, 4, grid)
	_assert(sphere.size() == 61 and Vector2i(4, 0) in sphere and Vector2i(5, 0) not in sphere, "The 20-foot Sphere covers four five-foot hexes in each direction")
	grid.add_difficult_terrain("spike_growth:test", sphere)
	_assert(is_equal_approx(grid.get_hex_cost(Vector2i(2, 0)), 2.0), "Spike Growth marks each Sphere hex as Difficult Terrain")
	grid.remove_difficult_terrain("spike_growth:test")
	grid.free()
	print("SPIKE_GROWTH_AREA_CHECKS_COMPLETE")


func _test_entangle_spell() -> void:
	var entangle: Dictionary = DataLoader.get_spell("entangle")
	var area_effect: Dictionary = entangle.get("effects", [])[0] if not entangle.get("effects", []).is_empty() else {}
	var area_selection := EventResolver.resolve_area_selection(area_effect)
	_assert(SpellSupport.is_available(entangle) and entangle.get("rules_source", "") == "SRD5.2.1" and entangle.get("save", "") == "STR" and entangle.get("condition_on_failed_save", "") == "restrained" and bool(entangle.get("concentration", false)), "Entangle is available with its Strength save, Restrained consequence and concentration")
	_assert(area_selection.get("success", false) and area_selection.get("shape", "") == "square" and int(area_selection.get("size_feet", 0)) == 20, "Entangle validates its 20-foot square selection")
	var grid := _build_grid(4)
	var area := Targeting.get_square_targets(Vector2i.ZERO, 20, grid)
	_assert(area.size() == 19 and Vector2i.ZERO in area, "Entangle uses the documented radius-two hex approximation")
	var restrained: Character = _fresh_char("Entangled", "human", "fighter", {"STR": 30, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	CombatAction.apply_condition(restrained, "restrained", 99, "entangle:test:1")
	CombatAction.apply_condition(restrained, "restrained", 99, "entangle:test:2")
	_assert(restrained.get_speed() == 0 and EventResolver.resolve_skill_check(restrained, {"ability": "STR", "skill": "Athletics", "dc": 10, "use_primal_knowledge": false}).get("success", false), "Restrained blocks movement and a Strength (Athletics) check resolves through the shared check rules")
	CombatAction.remove_condition_source(restrained, "entangle:test:1", ["restrained"])
	_assert(CombatAction.has_condition(restrained, "restrained"), "Removing one Entangle source preserves an overlapping Restrained source")
	CombatAction.remove_condition_source(restrained, "entangle:test:2", ["restrained"])
	_assert(not CombatAction.has_condition(restrained, "restrained") and restrained.get_speed() > 0, "Removing the last Entangle source restores movement")
	grid.free()
	print("ENTANGLE_AREA_CHECKS_COMPLETE")


func _test_black_tentacles_spell() -> void:
	var black_tentacles: Dictionary = DataLoader.get_spell("black_tentacles")
	var area_effect: Dictionary = black_tentacles.get("effects", [])[0] if not black_tentacles.get("effects", []).is_empty() else {}
	var area_selection := EventResolver.resolve_area_selection(area_effect)
	var upcast: Dictionary = black_tentacles.get("duration_upcast", {})
	_assert(SpellSupport.is_available(black_tentacles) and black_tentacles.get("rules_source", "") == "SRD5.2.1" and black_tentacles.get("save", "") == "STR" and black_tentacles.get("damage", "") == "3d6" and black_tentacles.get("damage_type", "") == "bludgeoning" and black_tentacles.get("condition_on_failed_save", "") == "restrained" and bool(black_tentacles.get("concentration", false)), "Black Tentacles is available with its SRD Strength save, Bludgeoning damage, Restrained condition, and level-4 concentration")
	_assert(area_selection.get("success", false) and area_selection.get("shape", "") == "square" and int(area_selection.get("size_feet", 0)) == 20 and upcast.get("slot_durations", {}).get("5-6", "") == "8 hours" and upcast.get("slot_durations", {}).get("7-8", "") == "24 hours" and upcast.get("slot_durations", {}).get("9", "") == "until dispelled", "Black Tentacles selects a 20-foot square and records each SRD higher-slot duration")
	var grid := _build_grid(4)
	var area := Targeting.get_square_targets(Vector2i.ZERO, 20, grid)
	_assert(area.size() == 19 and Vector2i.ZERO in area, "The 20-foot square uses the documented radius-two hex approximation")
	var caster: Character = _fresh_char("Tentacle Wizard", "human", "wizard", {"STR": 8, "DEX": 10, "CON": 10, "INT": 20, "WIS": 10, "CHA": 10})
	var target: Character = _fresh_char("Tentacle Target", "human", "fighter", {"STR": 3, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	target.add_modifier("roll", "save:STR", -1000, 1)
	var failed_save := CombatAction.resolve_spell(caster, target, black_tentacles, false, {}, [], 4, 0)
	_assert(not bool(failed_save.get("saved", true)) and int(failed_save.get("damage", 0)) > 0, "A failed Black Tentacles save deals 3d6 Bludgeoning damage")
	target.add_modifier("roll", "save:STR", 2000, 99)
	var successful_save := CombatAction.resolve_spell(caster, target, black_tentacles, false, {}, [], 4, 0)
	_assert(bool(successful_save.get("saved", false)) and int(successful_save.get("damage", -1)) == 0, "A successful Black Tentacles save takes no damage")
	var source_target: Character = _fresh_char("Overlapping Tentacle Target", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	CombatAction.apply_condition(source_target, "restrained", 99, "black_tentacles:test:1")
	CombatAction.apply_condition(source_target, "restrained", 99, "black_tentacles:test:2")
	CombatAction.remove_condition_source(source_target, "black_tentacles:test:1", ["restrained"])
	_assert(source_target.has_condition("restrained"), "Ending one Black Tentacles source preserves another Restrained source")
	CombatAction.remove_condition_source(source_target, "black_tentacles:test:2", ["restrained"])
	_assert(not source_target.has_condition("restrained"), "Ending the last Black Tentacles source removes Restrained")
	grid.free()
	print("BLACK_TENTACLES_AREA_CHECKS_COMPLETE")


func _test_sleet_storm_spell() -> void:
	var sleet_storm: Dictionary = DataLoader.get_spell("sleet_storm")
	var area_effect: Dictionary = sleet_storm.get("effects", [])[0] if not sleet_storm.get("effects", []).is_empty() else {}
	var area_selection := EventResolver.resolve_area_selection(area_effect)
	var grid := _build_grid(5)
	var area := Targeting.get_sphere_targets(Vector2i.ZERO, int(area_effect.get("radius", 0)), grid)
	var caster: Character = _fresh_char("Sleet Storm Wizard", "human", "wizard", {"STR": 10, "DEX": 10, "CON": 10, "INT": 16, "WIS": 10, "CHA": 10})
	var failed_target: Character = _fresh_char("Sleet Storm Target", "human", "fighter", {"STR": 10, "DEX": 3, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	failed_target.add_modifier("roll", "save:DEX", -1000, 1)
	var failed_save := CombatAction.resolve_spell(caster, failed_target, sleet_storm, false, {}, [], 3, 0)
	var saved_target: Character = _fresh_char("Sleet Storm Dodger", "human", "fighter", {"STR": 10, "DEX": 30, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	saved_target.add_modifier("roll", "save:DEX", 1000, 1)
	var successful_save := CombatAction.resolve_spell(caster, saved_target, sleet_storm, false, {}, [], 3, 0)
	_assert(SpellSupport.is_available(sleet_storm) and sleet_storm.get("rules_source", "") == "SRD5.2.1" and int(sleet_storm.get("range", 0)) == 30 and sleet_storm.get("save", "") == "DEX" and sleet_storm.get("condition_on_failed_save", "") == "prone" and bool(sleet_storm.get("concentration", false)), "Sleet Storm is an available 150-foot SRD Concentration spell with Dexterity saves and Prone on a failed save")
	_assert(area_selection.get("success", false) and area_selection.get("shape", "") == "sphere" and int(area_selection.get("radius", 0)) == 4 and int(sleet_storm.get("area_height_feet", 0)) == 40 and bool(sleet_storm.get("area_heavily_obscured", false)) and bool(sleet_storm.get("douses_exposed_flames", false)), "Sleet Storm records a 20-foot-radius, 40-foot-high Cylinder with Heavily Obscured and flame-dousing properties")
	_assert(area.size() == 61 and Vector2i.ZERO in area, "The 20-foot-radius Cylinder uses its documented radius-four ground projection on the hex map")
	_assert(not bool(failed_save.get("saved", true)) and failed_target.has_condition("prone") and int(failed_save.get("damage", 0)) == 0, "A failed Sleet Storm save causes Prone without damage")
	_assert(bool(successful_save.get("saved", false)) and not saved_target.has_condition("prone"), "A successful Sleet Storm save avoids Prone")
	grid.free()
	print("SLEET_STORM_AREA_CHECKS_COMPLETE")


func _test_cloud_of_daggers_spell() -> void:
	var cloud: Dictionary = DataLoader.get_spell("cloud_of_daggers")
	var area_effect: Dictionary = cloud.get("effects", [])[0] if not cloud.get("effects", []).is_empty() else {}
	var area_selection := EventResolver.resolve_area_selection(area_effect)
	var caster: Character = _fresh_char("Daggers Wizard", "human", "wizard", {"STR": 10, "DEX": 10, "CON": 10, "INT": 16, "WIS": 10, "CHA": 10})
	var target: Character = _fresh_char("Daggers Target", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	var damage_formula := CombatAction.spell_damage_formula(caster, cloud, 4)
	_assert(SpellSupport.is_available(cloud) and cloud.get("rules_source", "") == "PHB2024" and cloud.get("damage_type", "") == "slashing" and bool(cloud.get("concentration", false)), "Cloud of Daggers loads as an available 2024 Concentration spell with Slashing damage")
	_assert(area_selection.get("success", false) and area_selection.get("shape", "") == "point" and damage_formula == "4d4 + 4d4", "Cloud of Daggers targets one 5-foot point and increases damage by 2d4 per slot level above 2")
	_assert(int(cloud.get("duration_seconds", 0)) == 60 and str(cloud.get("material", "")) == "a sliver of glass", "Cloud of Daggers records its one-minute duration and glass material")
	print("CLOUD_OF_DAGGERS_AREA_CHECKS_COMPLETE")


func _test_cloudkill_spell() -> void:
	var cloudkill: Dictionary = DataLoader.get_spell("cloudkill")
	var area_effect: Dictionary = cloudkill.get("effects", [])[0] if not cloudkill.get("effects", []).is_empty() else {}
	var area_selection := EventResolver.resolve_area_selection(area_effect)
	var caster: Character = _fresh_char("Cloudkill Wizard", "human", "wizard", {"STR": 10, "DEX": 10, "CON": 10, "INT": 16, "WIS": 10, "CHA": 10})
	_assert(SpellSupport.is_available(cloudkill) and cloudkill.get("rules_source", "") == "SRD5.2.1" and int(cloudkill.get("range", 0)) == 24 and cloudkill.get("save", "") == "CON" and cloudkill.get("damage_type", "") == "poison" and bool(cloudkill.get("half_on_save", false)), "Cloudkill is an available SRD concentration spell with a 120-foot range and Constitution Poison save")
	_assert(area_selection.get("success", false) and area_selection.get("shape", "") == "sphere" and int(area_selection.get("radius", 0)) == 4 and bool(cloudkill.get("area_heavily_obscured", false)), "Cloudkill records its 20-foot-radius Heavily Obscured Sphere")
	_assert(int(cloudkill.get("duration_seconds", 0)) == 600 and CombatAction.spell_damage_formula(caster, cloudkill, 6) == "5d8 + 1d8", "Cloudkill lasts 10 minutes and upcasts by 1d8 per slot level above 5")
	print("CLOUDKILL_AREA_CHECKS_COMPLETE")


func _test_conjure_animals_spell() -> void:
	var animals: Dictionary = DataLoader.get_spell("conjure_animals")
	var area_effect: Dictionary = animals.get("effects", [])[0] if not animals.get("effects", []).is_empty() else {}
	var area_selection := EventResolver.resolve_area_selection(area_effect)
	var caster: Character = _fresh_char("Conjure Animals Druid", "human", "druid", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 10})
	_assert(SpellSupport.is_available(animals) and animals.get("rules_source", "") == "SRD5.2.1" and int(animals.get("range", 0)) == 12 and animals.get("save", "") == "DEX" and animals.get("damage_type", "") == "slashing" and bool(animals.get("concentration", false)), "Conjure Animals is an available SRD concentration spell with a 60-foot range and Dexterity Slashing save")
	_assert(area_selection.get("success", false) and area_selection.get("shape", "") == "sphere" and int(area_selection.get("radius", 0)) == 2, "Conjure Animals records a 10-foot pack trigger area on the hex map")
	_assert(int(animals.get("duration_seconds", 0)) == 600 and CombatAction.spell_damage_formula(caster, animals, 5) == "3d10 + 2d10" and not bool(animals.get("half_on_save", false)), "Conjure Animals lasts 10 minutes, upcasts by 1d10, and successful saves take no damage")
	caster.feature_uses["conjure_animals_strength_advantage"] = true
	_assert(caster._has_saving_throw_advantage("STR") and not caster._has_saving_throw_advantage("DEX"), "The caster gains Strength-save Advantage only while near the pack")
	print("CONJURE_ANIMALS_AREA_CHECKS_COMPLETE")


func _test_conjure_celestial_spell() -> void:
	var celestial: Dictionary = DataLoader.get_spell("conjure_celestial")
	var area_effect: Dictionary = celestial.get("effects", [])[0] if not celestial.get("effects", []).is_empty() else {}
	var area_selection := EventResolver.resolve_area_selection(area_effect)
	var caster: Character = _fresh_char("Conjure Celestial Cleric", "human", "cleric", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 10})
	_assert(SpellSupport.is_available(celestial) and celestial.get("rules_source", "") == "SRD5.2.1" and int(celestial.get("range", 0)) == 18 and celestial.get("save", "") == "DEX" and celestial.get("damage_type", "") == "radiant" and bool(celestial.get("concentration", false)), "Conjure Celestial is an available SRD concentration spell with a 90-foot range and Dexterity Radiant save")
	_assert(area_selection.get("success", false) and area_selection.get("shape", "") == "sphere" and int(area_selection.get("radius", 0)) == 2 and int(celestial.get("area_height_feet", 0)) == 40 and bool(celestial.get("area_bright_light", false)), "Conjure Celestial records a 10-foot-radius, 40-foot-high Bright Light cylinder approximation")
	_assert(int(celestial.get("duration_seconds", 0)) == 600 and CombatAction.spell_damage_formula(caster, celestial, 9) == "6d12 + 2d12", "Conjure Celestial lasts 10 minutes and upcasts Searing Light by 1d12 per slot above 7")
	_assert(str(celestial.get("description", "")).contains("4d12 plus your spellcasting ability modifier"), "Healing Light restores 4d12 plus the caster's spellcasting modifier")
	print("CONJURE_CELESTIAL_AREA_CHECKS_COMPLETE")


func _test_conjure_elemental_spell() -> void:
	var elemental: Dictionary = DataLoader.get_spell("conjure_elemental")
	var caster: Character = _fresh_char("Conjure Elemental Wizard", "human", "wizard", {"STR": 10, "DEX": 10, "CON": 10, "INT": 16, "WIS": 10, "CHA": 10})
	_assert(SpellSupport.is_available(elemental) and elemental.get("rules_source", "") == "SRD5.2.1" and int(elemental.get("range", 0)) == 12 and elemental.get("save", "") == "DEX" and bool(elemental.get("concentration", false)), "Conjure Elemental is an available SRD concentration spell with a 60-foot range and Dexterity save")
	_assert(int(elemental.get("duration_seconds", 0)) == 600 and elemental.get("summon_size", "") == "Large" and bool(elemental.get("summon_intangible", false)), "Conjure Elemental summons a Large intangible spirit for up to 10 minutes")
	_assert(elemental.get("element_choices", {}) == {"air": "lightning", "earth": "thunder", "fire": "fire", "water": "cold"}, "Air, Earth, Fire, and Water select Lightning, Thunder, Fire, and Cold damage")
	_assert(CombatAction.spell_damage_formula(caster, elemental, 5) == "8d8" and CombatAction.spell_damage_formula(caster, elemental, 7) == "8d8 + 2d8", "Conjure Elemental starts at 8d8 and adds 1d8 per slot above 5 under SRD 5.2.1")
	print("CONJURE_ELEMENTAL_SUMMON_CHECKS_COMPLETE")


func _test_conjure_fey_spell() -> void:
	var fey: Dictionary = DataLoader.get_spell("conjure_fey")
	var caster: Character = _fresh_char("Conjure Fey Druid", "human", "druid", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 10})
	_assert(SpellSupport.is_available(fey) and fey.get("rules_source", "") == "SRD5.2.1" and int(fey.get("range", 0)) == 12 and fey.get("damage_type", "") == "psychic" and bool(fey.get("concentration", false)), "Conjure Fey is an available SRD concentration spell with a 60-foot range and Psychic melee spell attack")
	_assert(int(fey.get("duration_seconds", 0)) == 600 and fey.get("summon_size", "") == "Medium" and bool(fey.get("frightened_on_hit", false)), "Conjure Fey summons a Medium spirit for up to 10 minutes and frightens a creature on a hit")
	_assert(CombatAction.spell_damage_formula(caster, fey, 6) == "3d12" and CombatAction.spell_damage_formula(caster, fey, 8) == "3d12 + 2d12", "Conjure Fey deals 3d12 plus the caster's spellcasting modifier and gains 1d12 per slot above 6 under SRD 5.2.1")
	print("CONJURE_FEY_SUMMON_CHECKS_COMPLETE")


func _test_conjure_minor_elementals_spell() -> void:
	var spell: Dictionary = DataLoader.get_spell("conjure_minor_elementals")
	var rider_types: Array = spell.get("attack_damage_rider_type_choices", [])
	_assert(SpellSupport.is_available(spell) and spell.get("rules_source", "") == "SRD5.2.1" and spell.get("target", "") == "self" and bool(spell.get("concentration", false)), "Conjure Minor Elementals is an available SRD self emanation with Concentration")
	_assert(int(spell.get("emanation_radius_feet", 0)) == 15 and int(spell.get("emanation_radius_hexes", 0)) == 3 and int(spell.get("duration_seconds", 0)) == 600, "Conjure Minor Elementals records a 15-foot Emanation and 10-minute duration")
	_assert(spell.get("attack_damage_rider", "") == "2d8" and rider_types == ["acid", "cold", "fire", "lightning"] and bool(spell.get("enemy_difficult_terrain", false)), "The spell adds a chosen elemental damage type on hits and makes the Emanation Difficult Terrain for enemies")
	_assert(spell.get("upcast", {}).get("starting_level", 0) == 4 and spell.get("upcast", {}).get("damage_per_level", "") == "1d8", "Higher-level slots add 1d8 to the attack rider per level above four under SRD 5.2.1")
	print("CONJURE_MINOR_ELEMENTALS_DATA_CHECKS_COMPLETE")


func _test_conjure_woodland_beings_spell() -> void:
	var spell: Dictionary = DataLoader.get_spell("conjure_woodland_beings")
	var caster: Character = _fresh_char("Woodland Beings Druid", "human", "druid", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 10})
	_assert(SpellSupport.is_available(spell) and spell.get("rules_source", "") == "SRD5.2.1" and spell.get("target", "") == "self" and spell.get("save", "") == "WIS" and bool(spell.get("concentration", false)), "Conjure Woodland Beings is an available SRD self Emanation with a Wisdom save and Concentration")
	_assert(int(spell.get("emanation_radius_feet", 0)) == 10 and int(spell.get("emanation_radius_hexes", 0)) == 2 and int(spell.get("duration_seconds", 0)) == 600, "Conjure Woodland Beings records its 10-foot Emanation and 10-minute duration")
	_assert(spell.get("damage", "") == "5d8" and spell.get("damage_type", "") == "force" and bool(spell.get("half_on_save", false)) and CombatAction.spell_damage_formula(caster, spell, 5) == "5d8 + 1d8", "The zone deals 5d8 Force or half on a success and adds 1d8 per slot above four")
	_assert(bool(spell.get("bonus_action_disengage", false)) and spell.get("classes", []) == ["druid", "ranger"], "The active spell also grants Bonus Action Disengage to its Druid and Ranger casters")
	print("CONJURE_WOODLAND_BEINGS_DATA_CHECKS_COMPLETE")


func _test_spirit_guardians_spell() -> void:
	var spell: Dictionary = DataLoader.get_spell("spirit_guardians")
	var caster: Character = _fresh_char("Spirit Guardians Cleric", "human", "cleric", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 10})
	_assert(SpellSupport.is_available(spell) and spell.get("rules_source", "") == "SRD5.2.1" and spell.get("target", "") == "self" and spell.get("save", "") == "WIS" and bool(spell.get("concentration", false)), "Spirit Guardians is an available SRD self Emanation with a Wisdom save and Concentration")
	_assert(int(spell.get("emanation_radius_feet", 0)) == 15 and int(spell.get("emanation_radius_hexes", 0)) == 3 and int(spell.get("duration_seconds", 0)) == 600, "Spirit Guardians records its 15-foot Emanation and 10-minute duration")
	_assert(spell.get("damage", "") == "3d8" and spell.get("damage_type_choices", []) == ["radiant", "necrotic"] and bool(spell.get("half_on_save", false)) and CombatAction.spell_damage_formula(caster, spell, 5) == "3d8 + 2d8", "Spirit Guardians selects alignment damage, halves damage on a success, and adds 1d8 per slot above three")
	_assert(spell.get("classes", []) == ["cleric"] and str(spell.get("description", "")).contains("Speed is halved") and str(spell.get("description", "")).contains("designate creatures"), "The SRD entry includes its Speed reduction and unaffected-creature designation")
	print("SPIRIT_GUARDIANS_DATA_CHECKS_COMPLETE")


func _test_aura_of_life_spell() -> void:
	var spell: Dictionary = DataLoader.get_spell("aura_of_life")
	_assert(SpellSupport.is_available(spell) and spell.get("rules_source", "") == "SRD5.2.1" and spell.get("target", "") == "self" and bool(spell.get("concentration", false)), "Aura of Life is an available SRD concentration Emanation")
	_assert(int(spell.get("emanation_radius_feet", 0)) == 30 and int(spell.get("emanation_radius_hexes", 0)) == 6 and int(spell.get("duration_seconds", 0)) == 600, "Aura of Life records its 30-foot range and 10-minute duration")
	_assert(str(spell.get("description", "")).contains("Resistance to Necrotic") and str(spell.get("description", "")).contains("Hit Point maximums can't be reduced") and str(spell.get("description", "")).contains("regains 1 Hit Point"), "Aura of Life records its three core protection and healing effects")
	var protected: Character = _fresh_char("Life Aura Protected", "human", "cleric", {"WIS": 16})
	protected.aura_of_life_sources.append("aura_of_life:test")
	_assert(protected.resist_damage(11, "necrotic") == 5 and protected.resist_damage(11, "fire") == 11, "Aura of Life halves Necrotic damage without affecting other damage types")
	print("AURA_OF_LIFE_DATA_CHECKS_COMPLETE")


func _test_moonbeam_spell() -> void:
	var moonbeam: Dictionary = DataLoader.get_spell("moonbeam")
	var area_effect: Dictionary = moonbeam.get("effects", [])[0] if not moonbeam.get("effects", []).is_empty() else {}
	var area_selection := EventResolver.resolve_area_selection(area_effect)
	_assert(SpellSupport.is_available(moonbeam) and moonbeam.get("rules_source", "") == "SRD5.2.1" and moonbeam.get("save", "") == "CON" and moonbeam.get("damage_type", "") == "radiant" and bool(moonbeam.get("concentration", false)), "Moonbeam is an available SRD concentration spell with a Constitution save and Radiant damage")
	_assert(area_selection.get("success", false) and area_selection.get("shape", "") == "sphere" and int(area_selection.get("radius", 0)) == 1 and CombatAction.spell_damage_formula(_fresh_char("Moonbeam Formula", "human", "druid", {"WIS": 16}), moonbeam, 3) == "2d10 + 1d10", "Moonbeam selects its 5-foot-radius Cylinder approximation and upcasts by 1d10")
	var shifter: Character = _fresh_char("Moonbeam Shifter", "human", "druid", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 10})
	shifter.level = 2
	shifter.features.append({"id": "druid_wild_shape", "name": "Wild Shape"})
	DruidRules.learn_form(shifter, "wolf")
	shifter.feature_uses["druid_wild_shape_uses"] = 1
	shifter.add_condition("moonbeam_shape_lock", 99, "moonbeam:test:shape_lock")
	var blocked_shape := DruidRules.transform(shifter, "wolf")
	_assert(not blocked_shape.get("success", false) and not DruidRules.is_shaped(shifter), "Moonbeam's shape-shift lock prevents Wild Shape while the target remains in the Cylinder")
	print("MOONBEAM_AREA_CHECKS_COMPLETE")


func _test_plant_growth_spell() -> void:
	var plant_growth: Dictionary = DataLoader.get_spell("plant_growth")
	var area_effect: Dictionary = plant_growth.get("effects", [])[0] if not plant_growth.get("effects", []).is_empty() else {}
	var area_selection := EventResolver.resolve_area_selection(area_effect)
	var grid := _build_grid(4)
	var coord := Vector2i.ZERO
	var coords: Array[Vector2i] = [coord]
	var normal_cost: float = grid.get_hex_cost(coord)
	_assert(SpellSupport.is_available(plant_growth) and plant_growth.get("rules_source", "") == "SRD5.2.1" and plant_growth.get("classes", []) == ["bard", "druid", "ranger"] and plant_growth.get("duration", "") == "Instantaneous", "Plant Growth is available with SRD source, class access and Instantaneous spell duration metadata")
	_assert(area_selection.get("success", false) and area_selection.get("shape", "") == "sphere" and int(area_selection.get("radius", 0)) == 20 and int(plant_growth.get("range", 0)) == 30, "Plant Growth Overgrowth selects its 100-foot Sphere and 150-foot range")
	grid.add_difficult_terrain("other_terrain", coords)
	grid.add_movement_cost_override("plant_growth:test:one", coords, 4.0)
	grid.add_movement_cost_override("plant_growth:test:two", coords, 4.0)
	_assert(is_equal_approx(grid.get_hex_cost(coord), 4.0), "Plant Growth sets a fourfold movement cost that does not stack with Difficult Terrain or itself")
	grid.remove_movement_cost_override("plant_growth:test:one")
	_assert(is_equal_approx(grid.get_hex_cost(coord), 4.0), "Removing one overlapping Plant Growth source preserves the other")
	grid.remove_movement_cost_override("plant_growth:test:two")
	_assert(is_equal_approx(grid.get_hex_cost(coord), normal_cost + 1.0), "Removing the last Plant Growth source restores underlying Difficult Terrain cost")
	grid.free()
	print("PLANT_GROWTH_AREA_CHECKS_COMPLETE")


func _test_barkskin_spell() -> void:
	var barkskin: Dictionary = DataLoader.get_spell("barkskin")
	var caster: Character = _fresh_char("Barkskin Caster", "human", "druid", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 10})
	var target: Character = _fresh_char("Barkskin Target", "human", "fighter", {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	target.base_ac = 10
	_assert(SpellSupport.is_available(barkskin) and SpellEffects.manages(barkskin) and barkskin.get("rules_source", "") == "SRD5.2.1" and barkskin.get("casting_time", "") == "bonus_action" and barkskin.get("duration_seconds", 0) == 3600 and barkskin.get("target", "") == "single_ally", "Barkskin is available with its SRD Bonus Action, willing ally and one-hour contract")
	var cast := SpellEffects.begin_cast(caster, barkskin)
	var granted := SpellEffects.grant_barkskin(target, cast)
	_assert(granted and target.get_ac() == 17, "Barkskin raises a low Armor Class to its floor of 17 (AC %d)" % target.get_ac())
	_assert(SpellEffects.saved_state_error(target.to_dict()).is_empty(), "The source-owned Barkskin floor passes the saved spell-effect data checks")
	target.base_ac = 18
	_assert(target.get_ac() == 19, "Barkskin does not lower Armor Class that is already above 17 (AC %d)" % target.get_ac())
	target.base_ac = 10
	SpellEffects.remove(target, str(cast.get("source_id", "")))
	_assert(target.get_ac() == 11 and not SpellEffects.has_spell(target, "barkskin"), "Removing one Barkskin source restores the target's normal Armor Class (AC %d)" % target.get_ac())
	var monster: Dictionary = {"spell_effects": {}, "conditions": {}, "condition_sources": {}, "armor_class": 13}
	var monster_cast := SpellEffects.begin_cast(caster, barkskin)
	SpellEffects.grant_barkskin(monster, monster_cast)
	_assert(SpellEffects.effective_ac(monster, 13) == 17, "Barkskin AC floors also apply to monster targets")
	SpellEffects.advance_time([caster, monster], 3600)
	_assert(SpellEffects.effective_ac(monster, 13) == 13 and not SpellEffects.has_spell(monster, "barkskin"), "Barkskin expires after its one-hour duration")
	print("BARKSKIN_AC_FLOOR_CHECKS_COMPLETE")


func _test_mage_armor_spell() -> void:
	var mage_armor: Dictionary = DataLoader.get_spell("mage_armor")
	var caster: Character = _fresh_char("Mage Armor Caster", "human", "wizard", {"STR": 10, "DEX": 10, "CON": 10, "INT": 16, "WIS": 10, "CHA": 10})
	var target: Character = _fresh_char("Mage Armor Target", "human", "wizard", {"STR": 10, "DEX": 14, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	_assert(SpellSupport.is_available(mage_armor) and SpellEffects.manages(mage_armor) and mage_armor.get("rules_source", "") == "SRD5.2.1" and mage_armor.get("duration_seconds", 0) == 28800 and mage_armor.get("target", "") == "single_ally", "Mage Armor is available with willing-ally targeting and its eight-hour SRD duration")
	var cast := SpellEffects.begin_cast(caster, mage_armor)
	SpellEffects.grant(target, cast, "mage_armor", "start")
	_assert(SpellEffects.has_spell(target, "mage_armor") and target.get_ac() == 15, "Mage Armor sets base AC to 13 plus the target's Dexterity modifier")
	_assert(SpellEffects.saved_state_error(target.to_dict()).is_empty(), "The timed Mage Armor condition passes saved spell-effect validation")
	target.inventory.equipped[Inventory.Slot.BODY] = "leather_armor"
	target._recalculate_ac()
	_assert(not SpellEffects.has_spell(target, "mage_armor") and target.get_ac() == 13, "Donning armor ends Mage Armor and restores normal armor AC")
	var timed_target: Character = _fresh_char("Timed Mage Armor", "human", "wizard", {"STR": 10, "DEX": 14, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	var timed_cast := SpellEffects.begin_cast(caster, mage_armor)
	SpellEffects.grant(timed_target, timed_cast, "mage_armor", "start")
	SpellEffects.advance_time([caster, timed_target], 28800)
	_assert(not SpellEffects.has_spell(timed_target, "mage_armor") and timed_target.get_ac() == timed_target.base_ac, "Mage Armor expires after eight hours and restores ordinary AC")
	var monk_target: Character = _fresh_char("Higher Unarmored AC", "human", "monk", {"STR": 10, "DEX": 14, "CON": 10, "INT": 10, "WIS": 20, "CHA": 10})
	var monk_cast := SpellEffects.begin_cast(caster, mage_armor)
	SpellEffects.grant(monk_target, monk_cast, "mage_armor", "start")
	_assert(monk_target.get_ac() == 17, "Mage Armor does not lower a target's higher Unarmored Defense calculation")
	print("MAGE_ARMOR_AC_CHECKS_COMPLETE")


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
	var friendly_caster: Character = _fresh_char("Friendly Caster", "human", "druid", {"STR": 10})
	friendly_caster.character_id = "friendly_caster"
	var other_party_member: Character = _fresh_char("Other Party Member", "human", "fighter", {"STR": 10})
	var charmed_beast := _monster_inst("wolf")
	charmed_beast["animal_friendship_caster_ids"] = [friendly_caster.character_id]
	charmed_beast["hex_position"] = Vector2i(0, 0)
	var friendship_players := [{"character": friendly_caster, "hex_position": Vector2i(1, 0), "is_alive": true}, {"character": other_party_member, "hex_position": Vector2i(-2, 0), "is_alive": true}]
	var friendship_ai_decision := AIController.get_monster_action(charmed_beast, charmed_beast["hex_position"], grid, friendship_players)
	_assert(friendship_ai_decision.get("target_id", "") == other_party_member.character_name, "Animal Friendship prevents the charmed Beast from targeting its caster")
	var charm_caster: Character = _fresh_char("Charm Caster", "human", "wizard", {"INT": 16})
	charm_caster.character_id = "charm_caster"
	var charm_ally: Character = _fresh_char("Charm Ally", "human", "fighter", {"STR": 10})
	var charmed_guard := _monster_inst("goblin")
	charmed_guard["conditions"] = {"charmed": 600}
	charmed_guard["spell_effects"] = {"spell:charm_caster:1": {"spell_id": "charm_person", "caster_id": charm_caster.character_id, "conditions": ["charmed"]}}
	charmed_guard["hex_position"] = Vector2i.ZERO
	var charm_players := [{"character": charm_caster, "hex_position": Vector2i(1, 0), "is_alive": true}, {"character": charm_ally, "hex_position": Vector2i(-2, 0), "is_alive": true}]
	var charm_ai_decision := AIController.get_monster_action(charmed_guard, charmed_guard["hex_position"], grid, charm_players)
	_assert(charm_ai_decision.get("target_id", "") == charm_ally.character_name, "A monster Charmed by Charm Person does not target its caster")
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
	for i in Inventory.MAX_BACKPACK_SIZE:
		inv2.add_item("gold_100")
	_assert(inv2.backpack.size() == Inventory.MAX_BACKPACK_SIZE, "backpack reaches its configured capacity")
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
	var immune_character := _fresh_char("Immune Cond", "human", "fighter", {"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	immune_character.features.append({"id": "test_frightened_immunity", "effects": [{"type": "immunity", "condition": "frightened"}], "passive_effects": []})
	CombatAction.apply_condition(immune_character, "frightened", 5, "test-source")
	_assert(not immune_character.has_condition("frightened"), "Character condition immunity blocks shared source-owned condition application")
	var overlapping := _fresh_char("Overlapping Cond", "human", "fighter", {"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	overlapping.add_condition("poisoned", 3, "poison:one")
	overlapping.add_condition("poisoned", 5, "poison:two")
	CombatAction.remove_condition_source(overlapping, "poison:one", ["poisoned"])
	_assert(overlapping.has_condition("poisoned") and not overlapping.condition_sources.get("poisoned", {}).has("poison:one") and overlapping.condition_sources.get("poisoned", {}).has("poison:two"), "Removing one poison source preserves a separately owned overlapping poison")
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
	_assert(modifier_results.size() == 3 and c.get_ac() == c.base_ac + 3, "typed AC, roll, and movement modifiers apply through one effect vocabulary")
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
	scout.inventory.add_item("torch")
	var torch_instance_id := str(scout.inventory.backpack_instances().back().get("instance_id", ""))
	var torch_use := scout.inventory.consume_instance(torch_instance_id, scout)
	var torch_record := scout.inventory.get_instance(torch_instance_id)
	var light_grid: HexGrid = _build_grid(13)
	FogOfWar.update_visibility(light_grid)
	_assert(torch_use.get("success", false) and not torch_use.get("consumed", true) and LightSourceRules.dim_radius_hexes(torch_record) == 8 and light_grid.get_tile(Vector2i(8, 0)).is_visible and not light_grid.get_tile(Vector2i(9, 0)).is_visible, "A lit Torch copy persists and reveals its 40-foot Dim Light radius")
	LightSourceRules.advance_inventory(scout.inventory, 3600)
	FogOfWar.update_visibility(light_grid)
	_assert(not light_grid.get_tile(Vector2i(8, 0)).is_visible, "A Torch's light radius ends after one hour of elapsed light-source time")
	scout.inventory.add_item("lantern_hooded")
	scout.inventory.add_item("oil_flask")
	scout.inventory.add_item("oil_flask")
	var portable_records := scout.inventory.backpack_instances()
	var lantern_instance_id := ""
	var oil_instance_ids: Array[String] = []
	for record in portable_records:
		if str(record.get("definition_id", "")) == "lantern_hooded":
			lantern_instance_id = str(record.get("instance_id", ""))
		elif str(record.get("definition_id", "")) == "oil_flask":
			oil_instance_ids.append(str(record.get("instance_id", "")))
	var lantern_use := scout.inventory.consume_instance(lantern_instance_id, scout)
	var lantern_record := scout.inventory.get_instance(lantern_instance_id)
	FogOfWar.update_visibility(light_grid)
	_assert(lantern_use.get("success", false) and scout.inventory.get_instance(oil_instance_ids[0]).is_empty() and not scout.inventory.get_instance(oil_instance_ids[1]).is_empty() and LightSourceRules.dim_radius_hexes(lantern_record) == 12 and light_grid.get_tile(Vector2i(12, 0)).is_visible and not light_grid.get_tile(Vector2i(13, 0)).is_visible, "A Hooded Lantern consumes one selected oil flask and reveals its 60-foot Dim Light radius")
	LightSourceRules.advance_inventory(scout.inventory, 21600)
	FogOfWar.update_visibility(light_grid)
	_assert(not light_grid.get_tile(Vector2i(12, 0)).is_visible, "A Hooded Lantern's light ends after its six-hour fuel duration")
	var darkvision_cast := SpellEffects.begin_cast(scout, DataLoader.get_spell("darkvision"))
	SpellEffects.grant(scout, darkvision_cast, "darkvision")
	var darkvision_grid: HexGrid = _build_grid(30)
	FogOfWar.update_visibility(darkvision_grid)
	var darkvision_far: HexTile = darkvision_grid.get_tile(Vector2i(30, 0))
	_assert(darkvision_far != null and darkvision_far.is_visible, "Darkvision extends exploration vision to its 150-foot range")
	SpellEffects.advance_time([scout], 28800)
	FogOfWar.update_visibility(darkvision_grid)
	_assert(not darkvision_far.is_visible, "Exploration vision returns to normal when Darkvision expires")
	grid.free()
	grid2.free()
	light_grid.free()
	darkvision_grid.free()

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
	var area_grid := _build_grid(5)
	var cube_targets := Targeting.get_cube_targets(Vector2i.ZERO, Vector2i(1, 0), 3, area_grid)
	_assert(cube_targets.size() == 9 and Vector2i(3, 0) in cube_targets and Vector2i(4, 0) not in cube_targets and Vector2i.ZERO not in cube_targets, "15-foot directional cube selects three forward layers and excludes its caster")
	var pushed := Targeting.get_pushed_position(Vector2i(1, 0), Vector2i.ZERO, 2, area_grid)
	_assert(pushed == Vector2i(3, 0), "forced movement pushes two hexes directly away from its origin")
	var blocked_push := Targeting.get_pushed_position(Vector2i(1, 0), Vector2i.ZERO, 2, area_grid, [Vector2i(2, 0)])
	_assert(blocked_push == Vector2i(1, 0), "forced movement stops before an occupied hex")
	area_grid.free()
	# static A* pathfinding
	var path: Array[Vector2i] = HexUtils.find_path(Vector2i.ZERO, Vector2i(3, 0),
		func(h: Vector2i) -> bool: return true, func(h: Vector2i) -> float: return 1.0, 100)
	_assert(path.size() >= 2 and path[0] == Vector2i.ZERO and path[-1] == Vector2i(3, 0), "static find_path endpoints correct")

func _test_activity_history() -> void:
	print("\n[Group] Activity history")
	ActivityHistory.clear()
	var draft := _activity_attack_draft()
	var published: Dictionary = ActivityHistory.publish(draft)
	_assert(int(published.get("sequence", 0)) == 1 and published.get("id", "") == "activity-000001", "activity store assigns stable campaign sequence and id")
	_assert(int(published.get("payload", {}).get("final_total", 0)) == 17, "activity record preserves authoritative resolved total")
	draft["payload"]["final_total"] = 99
	published["payload"]["final_total"] = 88
	_assert(int(ActivityHistory.get_records()[0]["payload"]["final_total"]) == 17, "published activity is isolated from caller mutation")
	var returned_records := ActivityHistory.get_records()
	returned_records[0]["summary"] = "mutated"
	_assert(ActivityHistory.get_records()[0]["summary"] == "17 vs AC 14 - Hit", "activity queries return immutable copies")

	var malformed := published.duplicate(true)
	malformed.erase("payload")
	var future := published.duplicate(true)
	future["schema_version"] = ActivityRecord.SCHEMA_VERSION + 1
	var prepared := ActivityHistory.prepare_snapshot({
		"schema_version": ActivityHistory.STORE_SCHEMA_VERSION,
		"next_sequence": 41,
		"records": [published, malformed, future],
	})
	_assert(prepared.get("records", []).size() == 1, "snapshot preparation skips malformed and future activity records")
	_assert(prepared.get("diagnostics", []).size() == 2 and not prepared.get("notices", []).is_empty(), "skipped activity records retain diagnostics and a player-safe notice")
	ActivityHistory.apply_prepared_snapshot(prepared)
	_assert(ActivityHistory.get_next_sequence() == 41, "activity snapshot preserves the next campaign sequence")

	# Deterministic resolver-to-record proof: the activity builder copies the
	# settled roll, comparison, and damage instead of reconstructing any math.
	ActivityHistory.clear()
	seed(4242)
	var activity_attacker := _fresh_char("Record Fighter", "human", "fighter", {"STR": 16, "DEX": 10, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
	activity_attacker.character_id = "pc-record-fighter"
	var activity_target := {"id": "monster-record-target", "name": "Training Ogre", "armor_class": -100, "current_hp": 999, "is_alive": true}
	var activity_weapon: Dictionary = DataLoader.get_item("longsword")
	var resolver_result := CombatAction.resolve_weapon_attack(activity_attacker, activity_target, activity_weapon)
	var resolver_draft := CombatActivityRecord.attack_action(activity_attacker, activity_target, activity_weapon, [resolver_result], "the_lost_crown", 3)
	var resolver_record := ActivityHistory.publish(resolver_draft)
	_assert(ActivityHistory.get_records().size() == 1, "one resolved Attack action publishes exactly one top-level activity record")
	_assert(resolver_record.get("payload", {}).get("dice_terms", []) == resolver_result.get("activity_roll", {}).get("dice_terms", []), "activity record dice and kept flags equal the resolver output")
	_assert(int(resolver_record.get("payload", {}).get("final_total", 0)) == int(resolver_result.get("attack_roll", 0)), "activity record final attack total equals the resolver output")
	_assert(resolver_record.get("payload", {}).get("comparison", {}) == resolver_result.get("activity_roll", {}).get("comparison", {}), "activity record target, margin, and outcome equal the resolver output")
	var resolver_attacks: Array = resolver_record.get("payload", {}).get("sections", {}).get("attacks", [])
	_assert(not resolver_attacks.is_empty() and int(resolver_attacks[0].get("applied_damage", -1)) == int(resolver_result.get("damage", -2)), "activity record applied damage equals the resolver output")
	var grouped_draft := CombatActivityRecord.attack_action(activity_attacker, activity_target, activity_weapon, [resolver_result, resolver_result.duplicate(true)], "the_lost_crown", 3)
	ActivityHistory.clear()
	var grouped_record := ActivityHistory.publish(grouped_draft)
	_assert(grouped_record.get("payload", {}).get("sections", {}).get("attacks", []).size() == 2 and ActivityHistory.get_records().size() == 1, "Extra Attack swings remain children of one top-level Attack action record")

	ActivityHistory.clear()
	var all_published: Array[Dictionary] = []
	for index in 201:
		all_published.append(ActivityHistory.publish(_activity_attack_draft("Attack %d" % (index + 1))))
	var bounded_records := ActivityHistory.get_records()
	_assert(bounded_records.size() == ActivityHistory.CAPACITY, "activity store retains at most 200 top-level records")
	_assert(int(bounded_records.front().get("sequence", 0)) == 2 and int(bounded_records.back().get("sequence", 0)) == 201, "the 201st activity trims exactly the oldest complete record")
	_assert(ActivityHistory.get_next_sequence() == 202, "activity sequence remains monotonic after trimming")
	var loaded_over_capacity := ActivityHistory.prepare_snapshot({"schema_version": 1, "next_sequence": 202, "records": all_published})
	_assert(loaded_over_capacity.get("records", []).size() == ActivityHistory.CAPACITY and int(loaded_over_capacity.get("records", []).front().get("sequence", 0)) == 2, "snapshot loader also clamps externally oversized history to the newest 200 records")
	var serialized_text := JSON.stringify(ActivityHistory.serialize())
	_assert(not serialized_text.contains("<RefCounted") and not serialized_text.contains("Object("), "activity history serializes as plain JSON-safe DTO data")
	ActivityHistory.clear()


func _test_save_load() -> void:
	print("\n[Group] Save/Load")
	# Set up minimal game-in-progress state
	var camp: Dictionary = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	PlayerManager.reset()
	PlayerManager.add_player("Sava")
	var sc: Character = _fresh_char("Sava", "human", "monk", {"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	sc.level_up()
	sc.spend_focus_points(1)
	PlayerManager.set_player_character(0, sc)
	PartyManager.sync_from_player_manager()
	ActivityHistory.clear()
	var published_activity := ActivityHistory.publish(_activity_attack_draft("Opening Longsword"))
	_assert(not published_activity.is_empty(), "deterministic activity fixture publishes before save")
	var slot := "rook_test_slot"
	# clean any prior
	SaveManager.delete_save(slot)
	var saved := SaveManager.save_game(slot)
	_assert(saved, "save_game returns true when game in progress")
	var saved_file := FileAccess.open(SaveManager.SAVE_DIR + "%s.sav" % slot, FileAccess.READ)
	var saved_json := JSON.new()
	var saved_parse := saved_json.parse(saved_file.get_as_text()) if saved_file != null else ERR_FILE_NOT_FOUND
	if saved_file != null: saved_file.close()
	var saved_dto: Dictionary = saved_json.data if saved_parse == OK and saved_json.data is Dictionary else {}
	_assert(SaveManager._validate_save_data(saved_dto).is_empty(), "saved party DTO passes structural validation")
	_assert(saved_dto.get("activity_history", {}).get("records", []).size() == 1, "save DTO contains campaign activity history")
	var malformed_activity_slot := "rook_activity_malformed"
	SaveManager.delete_save(malformed_activity_slot)
	var malformed_activity_save := saved_dto.duplicate(true)
	malformed_activity_save["activity_history"]["records"].append({"schema_version": 1})
	var malformed_activity_file := FileAccess.open(SaveManager.SAVE_DIR + "%s.sav" % malformed_activity_slot, FileAccess.WRITE)
	if malformed_activity_file != null:
		malformed_activity_file.store_string(JSON.stringify(malformed_activity_save))
		malformed_activity_file.close()
	ActivityHistory.clear()
	GameManager.test_mode = true
	_assert(SaveManager.load_game(malformed_activity_slot), "one malformed activity record does not reject the campaign save")
	_assert(PlayerManager.get_player(0)["character"].get_focus_points() == 1, "SaveManager reload preserves spent Focus rather than refilling it")
	_assert(ActivityHistory.get_records().size() == 1 and not ActivityHistory.get_diagnostics().is_empty(), "load skips malformed activity and retains the readable record with diagnostics")
	SaveManager.delete_save(malformed_activity_slot)
	var backup_text := FileAccess.get_file_as_string(SaveManager.SAVE_DIR + "%s.sav" % slot)
	var backup_file := FileAccess.open(SaveManager.SAVE_DIR + "%s.sav.bak" % slot, FileAccess.WRITE)
	if backup_file != null:
		backup_file.store_string(backup_text)
		backup_file.close()
	var interrupted_file := FileAccess.open(SaveManager.SAVE_DIR + "%s.sav" % slot, FileAccess.WRITE)
	if interrupted_file != null:
		interrupted_file.store_string("{\"schema_version\":")
		interrupted_file.close()
	ActivityHistory.clear()
	GameManager.test_mode = true
	_assert(SaveManager.load_game(slot), "interrupted primary save falls back to the last committed backup")
	_assert(GameManager.current_state == GameManager.GameState.OVERWORLD, "backup recovery restores a resumable state")
	_assert(ActivityHistory.get_records().size() == 1 and int(ActivityHistory.get_records()[0]["payload"]["final_total"]) == 17, "activity arithmetic survives SaveManager round trip")
	_assert(slot in SaveManager.get_available_saves(), "backup-only recovery keeps the save slot discoverable")
	var fixture_file := FileAccess.open("res://data/fixtures/save_v1_compat.json", FileAccess.READ)
	var fixture_json := JSON.new()
	var fixture_parse := fixture_json.parse(fixture_file.get_as_text()) if fixture_file != null else ERR_FILE_NOT_FOUND
	if fixture_file != null: fixture_file.close()
	var fixture_dto: Dictionary = fixture_json.data if fixture_parse == OK and fixture_json.data is Dictionary else {}
	_assert(not SaveManager._validate_save_data(fixture_dto).is_empty(), "legacy schema 1 is explicitly incompatible, not silently converted")
	_assert(saved_dto.get("schema_version", 0) == 2 and saved_dto.get("ruleset_id", "") == SaveManager.RULESET_ID, "new campaigns persist schema 2 and the 2024 rules identity")
	var foreign_rules := saved_dto.duplicate(true)
	foreign_rules["ruleset_id"] = "legacy-2014"
	_assert(not SaveManager._validate_save_data(foreign_rules).is_empty(), "foreign rules identity is rejected even with the current schema")
	var legacy_path := SaveManager.LEGACY_SAVE_DIR + "legacy_boundary_test.sav"
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(fixture_dto))
	legacy_file.close()
	var legacy_text := FileAccess.get_file_as_string(legacy_path)
	_assert("legacy_boundary_test" in SaveManager.get_legacy_save_names(), "legacy slots are detectable for an incompatibility explanation")
	_assert("legacy_boundary_test" not in SaveManager.get_available_saves() and not SaveManager.load_game("legacy_boundary_test"), "legacy slot cannot enter the new save engine")
	_assert(FileAccess.get_file_as_string(legacy_path) == legacy_text, "attempting a legacy load preserves its bytes")
	DirAccess.remove_absolute(legacy_path)
	var invalid_party := saved_dto.duplicate(true)
	invalid_party["party"]["party_slots"][0]["character_id"] = "missing_character"
	_assert(not SaveManager._validate_save_data(invalid_party).is_empty(), "save validation rejects a missing party character reference")
	var invalid_slot := "rook_invalid_fixture"
	var invalid_file := FileAccess.open(SaveManager.SAVE_DIR + "%s.sav" % invalid_slot, FileAccess.WRITE)
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
	var save_file := FileAccess.open(SaveManager.SAVE_DIR + "%s.sav" % slot, FileAccess.READ)
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
	ActivityHistory.clear()
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
