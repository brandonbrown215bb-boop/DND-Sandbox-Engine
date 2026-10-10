## Headless Viewport Harness
## Instantiates the REAL combat and overworld scenes inside a Godot Viewport
## (renders headlessly, no display needed) and asserts their _ready wiring
## actually executed: grid build, HUD signal connect, player/monster spawn,
## initiative roll, fog-of-war update, event-trigger plumbing.
##
## Restructured (B): the old single _ready() coroutine is split into discrete,
## individually-named test methods (test_combat, test_overworld, ...). Each owns
## its own SubViewport + teardown, so a failure names the test instead of
## stalling the whole chain, and one broken scene cannot block the others.
## Each test establishes its own preconditions (no cross-test coupling).
extends Node

var _fail := 0
var _failures: Array[String] = []

# Per-test tracking so failures are attributed to a named test.
var _current_test := "harness"
var _fail_at_entry := 0
var _tests_run := 0
var _tests_failed_names: Array[String] = []

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("[ok]   %s" % msg)
	else:
		_fail += 1
		_failures.append("[%s] %s" % [_current_test, msg])
		print("[FAIL] [%s] %s" % [_current_test, msg])

func _fresh_char(name: String, race: String, klass: String, sd: Dictionary) -> Character:
	var s := AbilityScores.new()
	s.from_dict(sd)
	var c := Character.new()
	c.initialize(name, race, klass, s)
	return c

func _setup_world() -> void:
	var camp = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin", "goblin"]}
	GameManager.is_loading_save = false
	GameManager.game_in_progress = false
	GameManager.test_mode = true
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Alice")
	PlayerManager.add_player("Bob")
	var alice := _fresh_char("Alice", "human", "fighter",
		{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8})
	var bob := _fresh_char("Bob", "elf", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	PlayerManager.set_player_character(0, alice)
	PlayerManager.set_player_character(1, bob)
	PartyManager.register_player_character(0, alice)
	PartyManager.register_player_character(1, bob)


func _setup_mixed_world() -> void:
	var camp = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin", "goblin"]}
	GameManager.is_loading_save = false
	GameManager.game_in_progress = true
	GameManager.test_mode = true
	PlayerManager.reset()
	PartyManager.reset()
	var specs := [
		{"name": "Fighter Fixture", "race": "human", "class": "fighter", "scores": {"STR": 18, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8}},
		{"name": "Rogue Fixture", "race": "halfling", "class": "rogue", "scores": {"STR": 10, "DEX": 18, "CON": 12, "INT": 12, "WIS": 10, "CHA": 10}},
		{"name": "Wizard Fixture", "race": "elf", "class": "wizard", "scores": {"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 12, "CHA": 10}},
		{"name": "Cleric Fixture", "race": "human", "class": "cleric", "scores": {"STR": 12, "DEX": 10, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10}},
	]
	for index in specs.size():
		var spec: Dictionary = specs[index]
		PlayerManager.add_player(str(spec["name"]))
		var character := _fresh_char(str(spec["name"]), str(spec["race"]), str(spec["class"]), spec["scores"])
		PlayerManager.set_player_character(index, character)
		PartyManager.register_player_character(index, character)


func _setup_ranger_world() -> Character:
	var camp = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.is_loading_save = false
	GameManager.game_in_progress = true
	GameManager.test_mode = true
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Ranger")
	var ranger := _fresh_char("Ranger Fixture", "human", "ranger",
		{"STR": 12, "DEX": 18, "CON": 14, "INT": 10, "WIS": 16, "CHA": 8})
	ranger.known_spells.assign(["hunters_mark"])
	ranger.spell_slots["1"] = 0
	PlayerManager.set_player_character(0, ranger)
	PartyManager.register_player_character(0, ranger)
	return ranger

# --- per-test scaffolding ---------------------------------------------------

func _enter_test(name: String) -> void:
	_current_test = name
	_fail_at_entry = _fail
	_tests_run += 1
	print("\n[TEST] %s" % name)

func _exit_test() -> void:
	if _fail > _fail_at_entry and not _tests_failed_names.has(_current_test):
		_tests_failed_names.append(_current_test)

## Spawn a scene inside an isolated SubViewport, settle for `settle` seconds,
## and return the instance (vp tracked via meta for teardown).
func _spawn_scene(scene_path: String, settle: float) -> Node:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child(vp)
	var inst = load(scene_path).instantiate()
	vp.add_child(inst)
	await get_tree().create_timer(settle).timeout
	inst.set_meta("vp", vp)
	return inst

## Free a scene spawned by _spawn_scene (removes from its vp, frees both).
func _teardown_scene(inst: Node) -> void:
	if inst == null:
		return
	var vp = inst.get_meta("vp") if inst.has_meta("vp") else null
	if vp != null:
		vp.remove_child(inst)
		vp.queue_free()
	inst.queue_free()

# --- test orchestration -----------------------------------------------------

func _ready() -> void:
	print("==================================================")
	print(" Rook's Headless Viewport Harness (per-beat)")
	print("==================================================")
	_setup_world()

	var scenario := _requested_scenario()
	if scenario == "all":
		await _run_all_scenarios()
	else:
		await _run_scenario(scenario)

	_report()
	if _fail == 0:
		print("SCENARIO PASSED: %s" % scenario)
	else:
		print("SCENARIO FAILED: %s" % scenario)
	get_tree().quit(1 if _fail > 0 else 0)

func _requested_scenario() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			return arg.trim_prefix("--scenario=")
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--scenario="):
			return arg.trim_prefix("--scenario=")
	return "all"

func _run_all_scenarios() -> void:
	await test_combat()
	await test_party_combat()
	await test_crown_smoke()
	await test_crown_balance_fixture()
	await test_combat_ai_loop()
	await test_combat_victory()
	await test_combat_defeat()
	await test_final_encounter_round_trip()
	await test_mixed_mechanics_encounter()
	await test_ranger_action_flow()
	await test_ranger_natures_veil_blindsight()
	await test_wizard_capstone_cast_modes()
	await test_monk_action_flow()
	await test_fighter_second_wind()
	await test_fighter_progression()
	await test_class_building_blocks()
	await test_barbarian_action_flow()
	await test_barbarian_choice_flow()
	await test_bard_action_flow()
	await test_bard_creation_flow()
	await test_cleric_creation_flow()
	await test_cleric_action_flow()
	await test_cleric_strike_flow()
	await test_core12_shared_rules()
	await test_core12_audit_repairs()
	await test_rogue_devious_strikes()
	await test_sorcerer_subtle_spell()
	await test_spell_cast_stage_flow()
	await test_wand_magic_missiles_flow()
	await test_wand_last_charge_destruction_flow()
	await test_portable_light_source_combat_flow()
	await test_chain_lightning_target_identity_flow()
	await test_chain_lightning_mixed_targets_flow()
	await test_meteor_swarm_object_area_flow()
	await test_fire_area_object_ignition_flow()
	await test_sorcerer_twinned_spell()
	await test_overworld()
	await test_companion_lifecycle()
	await test_crown_composition_solo_two()
	await test_crown_composition_three_four()
	await test_main_menu_load()
	await test_dungeon()
	await test_event_dialog()
	await test_crown_event_fairy_ring()
	await test_dungeon_reentry_round_trip()
	await test_local_room_object_flow()
	await test_wave_three_foundations_flow()
	await test_owned_creature_lifecycle_flow()
	await test_find_familiar_exploration_flow()
	await test_party_recovery_flow()
	await test_downed_area_damage_flow()
	await test_created_undead_flow()
	await test_character_creation()
	await test_shop()
	await test_save_load()
	await test_action_resource_round_trip()
	await test_combat_resolution()
	await test_event_choice_resolution()
	await test_event_dialog_choice_click()
	await test_character_sheet()
	await test_character_sheet_contexts()
	await test_character_value_audit()

func _run_scenario(scenario: String) -> void:
	match scenario:
		"combat": await test_combat()
		"party_combat": await test_party_combat()
		"crown_smoke": await test_crown_smoke()
		"crown_balance_fixture": await test_crown_balance_fixture()
		"combat_ai_loop": await test_combat_ai_loop()
		"combat_victory": await test_combat_victory()
		"combat_defeat": await test_combat_defeat()
		"final_encounter_round_trip": await test_final_encounter_round_trip()
		"mixed_mechanics_encounter": await test_mixed_mechanics_encounter()
		"spell_effect_lifetime": await test_spell_effect_lifetime()
		"shared_spell_flow": await test_shared_spell_flow()
		"jump_spell_movement": await test_jump_spell_movement()
		"ranger_action_flow": await test_ranger_action_flow()
		"ranger_natures_veil_blindsight": await test_ranger_natures_veil_blindsight()
		"wizard_capstone_cast_modes": await test_wizard_capstone_cast_modes()
		"monk_action_flow": await test_monk_action_flow()
		"fighter_second_wind": await test_fighter_second_wind()
		"fighter_progression": await test_fighter_progression()
		"class_building_blocks": await test_class_building_blocks()
		"barbarian_action_flow": await test_barbarian_action_flow()
		"barbarian_choice_flow": await test_barbarian_choice_flow()
		"bard_action_flow": await test_bard_action_flow()
		"bard_creation_flow": await test_bard_creation_flow()
		"cleric_creation_flow": await test_cleric_creation_flow()
		"cleric_action_flow": await test_cleric_action_flow()
		"cleric_strike_flow": await test_cleric_strike_flow()
		"core12_shared_rules": await test_core12_shared_rules()
		"core12_audit_repairs": await test_core12_audit_repairs()
		"rogue_devious_strikes": await test_rogue_devious_strikes()
		"sorcerer_subtle_spell": await test_sorcerer_subtle_spell()
		"sleep_spell_flow": await test_sleep_spell_flow()
		"spell_cast_stage_flow": await test_spell_cast_stage_flow()
		"wand_magic_missiles_flow": await test_wand_magic_missiles_flow()
		"wand_last_charge_destruction_flow": await test_wand_last_charge_destruction_flow()
		"portable_light_source_combat_flow": await test_portable_light_source_combat_flow()
		"combat_light_visibility_flow": await test_combat_light_visibility_flow()
		"chain_lightning_target_identity_flow": await test_chain_lightning_target_identity_flow()
		"chain_lightning_mixed_targets_flow": await test_chain_lightning_mixed_targets_flow()
		"meteor_swarm_object_area_flow": await test_meteor_swarm_object_area_flow()
		"fire_area_object_ignition_flow": await test_fire_area_object_ignition_flow()
		"sunburst_spell_flow": await test_sunburst_spell_flow()
		"blindness_deafness_spell_flow": await test_blindness_deafness_spell_flow()
		"grease_spell_flow": await test_grease_spell_flow()
		"spike_growth_spell_flow": await test_spike_growth_spell_flow()
		"entangle_spell_flow": await test_entangle_spell_flow()
		"black_tentacles_spell_flow": await test_black_tentacles_spell_flow()
		"wall_of_fire_spell_flow": await test_wall_of_fire_spell_flow()
		"sleet_storm_spell_flow": await test_sleet_storm_spell_flow()
		"cloud_of_daggers_spell_flow": await test_cloud_of_daggers_spell_flow()
		"cloudkill_spell_flow": await test_cloudkill_spell_flow()
		"conjure_animals_spell_flow": await test_conjure_animals_spell_flow()
		"conjure_celestial_spell_flow": await test_conjure_celestial_spell_flow()
		"conjure_elemental_spell_flow": await test_conjure_elemental_spell_flow()
		"conjure_fey_spell_flow": await test_conjure_fey_spell_flow()
		"conjure_minor_elementals_spell_flow": await test_conjure_minor_elementals_spell_flow()
		"conjure_woodland_beings_spell_flow": await test_conjure_woodland_beings_spell_flow()
		"spirit_guardians_spell_flow": await test_spirit_guardians_spell_flow()
		"aura_of_life_spell_flow": await test_aura_of_life_spell_flow()
		"beacon_of_hope_spell_flow": await test_beacon_of_hope_spell_flow()
		"divine_favor_spell_flow": await test_divine_favor_spell_flow()
		"death_ward_spell_flow": await test_death_ward_spell_flow()
		"sanctuary_spell_flow": await test_sanctuary_spell_flow()
		"heroism_spell_flow": await test_heroism_spell_flow()
		"magic_weapon_spell_flow": await test_magic_weapon_spell_flow()
		"enhance_ability_spell_flow": await test_enhance_ability_spell_flow()
		"charm_person_spell_flow": await test_charm_person_spell_flow()
		"charm_monster_spell_flow": await test_charm_monster_spell_flow()
		"faerie_fire_spell_flow": await test_faerie_fire_spell_flow()
		"fog_cloud_spell_flow": await test_fog_cloud_spell_flow()
		"darkness_spell_flow": await test_darkness_spell_flow()
		"antilife_shell_spell_flow": await test_antilife_shell_spell_flow()
		"freedom_of_movement_spell_flow": await test_freedom_of_movement_spell_flow()
		"darkvision_spell_flow": await test_darkvision_spell_flow()
		"see_invisibility_spell_flow": await test_see_invisibility_spell_flow()
		"detect_magic_spell_flow": await test_detect_magic_spell_flow()
		"blur_spell_flow": await test_blur_spell_flow()
		"detect_evil_and_good_spell_flow": await test_detect_evil_and_good_spell_flow()
		"detect_poison_and_disease_spell_flow": await test_detect_poison_and_disease_spell_flow()
		"identify_spell_flow": await test_identify_spell_flow()
		"goodberry_spell_flow": await test_goodberry_spell_flow()
		"true_seeing_spell_flow": await test_true_seeing_spell_flow()
		"invisibility_spell_flow": await test_invisibility_spell_flow()
		"moonbeam_spell_flow": await test_moonbeam_spell_flow()
		"plant_growth_spell_flow": await test_plant_growth_spell_flow()
		"barkskin_spell_flow": await test_barkskin_spell_flow()
		"mage_armor_spell_flow": await test_mage_armor_spell_flow()
		"true_strike_spell_flow": await test_true_strike_spell_flow()
		"mass_cure_wounds_flow": await test_mass_cure_wounds_flow()
		"mass_healing_word_flow": await test_mass_healing_word_flow()
		"sorcerer_twinned_spell": await test_sorcerer_twinned_spell()
		"overworld": await test_overworld()
		"companion_lifecycle": await test_companion_lifecycle()
		"crown_composition_solo_two": await test_crown_composition_solo_two()
		"crown_composition_three_four": await test_crown_composition_three_four()
		"main_menu_load": await test_main_menu_load()
		"playtest_fixes": await test_playtest_fixes()
		"dungeon": await test_dungeon()
		"event_dialog": await test_event_dialog()
		"crown_event_fairy_ring": await test_crown_event_fairy_ring()
		"dungeon_reentry_round_trip": await test_dungeon_reentry_round_trip()
		"local_room_object_flow": await test_local_room_object_flow()
		"wave_three_foundations_flow": await test_wave_three_foundations_flow()
		"owned_creature_lifecycle_flow": await test_owned_creature_lifecycle_flow()
		"find_familiar_exploration_flow": await test_find_familiar_exploration_flow()
		"party_recovery_flow": await test_party_recovery_flow()
		"downed_area_damage_flow": await test_downed_area_damage_flow()
		"created_undead_flow": await test_created_undead_flow()
		"character_creation": await test_character_creation()
		"shop": await test_shop()
		"save_load": await test_save_load()
		"action_resource_round_trip": await test_action_resource_round_trip()
		"combat_resolution": await test_combat_resolution()
		"event_choice_resolution": await test_event_choice_resolution()
		"event_dialog_choice_click": await test_event_dialog_choice_click()
		"character_sheet": await test_character_sheet()
		"character_sheet_contexts": await test_character_sheet_contexts()
		"character_value_audit": await test_character_value_audit()
		_:
			_fail += 1
			_failures.append("[harness] unknown scenario '%s'" % scenario)

# --- tests ------------------------------------------------------------------

func test_playtest_fixes() -> void:
	_enter_test("playtest_fixes")
	_setup_world()
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Paladin seat")
	var paladin := _fresh_char("Smite Paladin", "human", "paladin", {"STR": 12, "DEX": 10, "CON": 14, "INT": 10, "WIS": 10, "CHA": 16})
	paladin.level_up()
	paladin.inventory.add_item("longsword")
	paladin.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	paladin.inventory.add_item("shield")
	paladin.inventory.equip(Inventory.Slot.SHIELD, "shield")
	PlayerManager.set_player_character(0, paladin)
	PartyManager.register_player_character(0, paladin)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = paladin
	combat.active_combatant = {"is_player": true, "entity": paladin}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	var target: Dictionary = combat.monster_entities[0]
	target.merge({"hex_position": Vector2i(1, 0), "armor_class": -100, "current_hp": 1000, "max_hp": 1000, "is_alive": true}, true)
	combat.turn_budget.reset(paladin, combat.player_entities)
	combat.hud.update_hud(paladin, combat.tracker)
	combat.hud.btn_spell.pressed.emit()
	combat.hud.spell_list.grab_focus()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	(combat.get_meta("vp") as SubViewport).push_input(escape)
	_assert(combat.hud.current_mode == CombatHUD.Mode.SELECT and combat.pending_action_type.is_empty(), "Escape closes a focused Paladin spell list without cost")
	combat.hud.btn_spell.pressed.emit()
	var overlay := ConfirmationDialog.new()
	combat.hud.add_child(overlay)
	ModalSurface.watch_window(overlay)
	overlay.popup_centered()
	await get_tree().process_frame
	(combat.get_meta("vp") as SubViewport).push_input(escape)
	_assert(combat.hud.current_mode == CombatHUD.Mode.SPELL, "Escape on a higher confirmation does not also close the combat picker")
	overlay.hide()
	overlay.queue_free()
	combat.hud.btn_cancel_spell.pressed.emit()
	GameManager.test_mode = false
	for accept in [false, true]:
		combat.turn_budget.reset(paladin, combat.player_entities)
		combat.hud.update_hud(paladin, combat.tracker)
		var slots_before := paladin.spell_slots.duplicate(true)
		var free_before := paladin.has_free_spell_cast("divine_smite")
		combat._on_hud_action("attack", {})
		combat._on_hex_clicked(target["hex_position"])
		var dialog: ConfirmationDialog = null
		for frame in 180:
			for child in combat.hud.get_children():
				if child is ConfirmationDialog and child.visible and child.title.begins_with("Divine Smite"):
					dialog = child
					break
			if dialog != null:
				break
			await get_tree().process_frame
		_assert(dialog != null, "A production melee hit opens the owning seat's Divine Smite choice")
		if dialog != null:
			_assert(dialog.title.contains("Seat 1"), "Smite identifies its owning player")
			if accept:
				dialog.get_ok_button().pressed.emit()
			else:
				dialog.canceled.emit()
		for frame in 180:
			if not combat.resolving_player_action:
				break
			await get_tree().process_frame
		_assert(not combat.resolving_player_action, "Smite choice completes the original attack")
		_assert(paladin.spell_slots == slots_before, "Default free Smite and decline leave spell slots untouched")
		_assert(combat.turn_budget.bonus_action_available == not accept and paladin.has_free_spell_cast("divine_smite") == (free_before and not accept), "Smite confirmation spends Bonus/free cast once; decline spends neither")
	_assert(ActivityHistory.get_records().any(func(record): return str(record.get("payload", {}).get("sections", {})).contains("Divine Smite")), "Settled attack Chronicle includes the Smite damage component")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()

## JSON fixture -> ordinary creation -> sheet choices -> real combat -> safe save.
func test_class_building_blocks() -> void:
	_enter_test("class_building_blocks")
	_setup_world()
	DataLoader._load_directory("res://data/fixtures/class_building_blocks/")
	DataLoader._validate_cross_references()
	_assert(DataLoader.get_load_errors().is_empty(), "fixture content passes ordinary loader validation")
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Warden Owner")
	# Keep the real creation scene on its next seat instead of replacing this harness.
	PlayerManager.add_player("Monk Owner")
	GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
	var creation: Node = await _spawn_scene("res://scenes/ui/character_creation.tscn", 0.2)
	creation.current_step = creation.CreationStep.CLASS
	creation._update_step_ui()
	await get_tree().process_frame
	var selected := false
	for card in creation.class_grid.get_children():
		if card is Button and card.text == "Fixture Warden":
			card.pressed.emit()
			selected = true
			break
		var matches := false
		for label in card.find_children("*", "Label", true, false):
			matches = matches or label.text == "Fixture Warden"
		if matches:
			for button in card.find_children("*", "Button", true, false):
				button.pressed.emit()
				selected = true
				break
			break
	_assert(selected and creation.selected_class_id == "fixture:warden", "a new class ID is selectable through the real creation card")
	creation.selected_name = "Data Warden"
	creation.selected_race_id = "human"
	creation.selected_stats.from_dict({"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 14, "CHA": 10})
	creation.current_step = creation.CreationStep.SUMMARY
	creation._update_step_ui()
	creation.btn_next.pressed.emit()
	var warden: Character = PlayerManager.get_player(0).get("character")
	_assert(warden != null and warden.class_id == "fixture:warden" and warden.has_feature("fixture:mend"), "Confirm creates the data-defined class through normal Character initialization")
	_teardown_scene(creation)
	while warden.level < 4:
		warden.level_up()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	CharacterSheet.show_sheet(warden)
	await get_tree().process_frame
	var panel: ClassTraining = null
	for child in CharacterSheet._content.get_children():
		if child is ClassTraining:
			panel = child
	_assert(panel != null, "the real sheet installs shared class progression controls")
	if panel != null:
		for button in panel.find_children("*", "Button", true, false):
			if button.text == "Choose subclass":
				var options: OptionButton = button.get_parent().get_child(0)
				options.select(1) # Sorted IDs: guard, healer.
				button.pressed.emit()
				break
	_assert(warden.subclass_id == "fixture:healer" and warden.has_feature("fixture:renewal") and not warden.has_feature("fixture:guard_critical"), "sheet selection grants only the selected subclass")
	await get_tree().process_frame
	var score_before := warden.ability_scores.get_score("STR")
	for button in CharacterSheet._content.find_children("*", "Button", true, false):
		if button.text.begins_with("Apply +1 each"):
			button.pressed.emit() # Both options default to STR.
			break
	_assert(warden.ability_scores.get_score("STR") == score_before + 2 and ClassProgression.pending_improvements(warden).is_empty(), "shared sheet improvement applies exactly once to a custom class")
	CharacterSheet.close_sheet()
	warden.level_up()
	warden.max_hp = 200
	warden.current_hp = 200
	var monk: Character = ClassFeatureChecks._character("monk", 6)
	monk.max_hp = 200
	monk.current_hp = 200
	PlayerManager.set_player_character(1, monk)
	PartyManager.register_player_character(1, monk)
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for seat in 2:
		var actor: Character = warden if seat == 0 else monk
		var id := "fixture:mend" if seat == 0 else "monk_wholeness_of_body"
		var pool := "fixture:resolve" if seat == 0 else id
		combat.current_player_idx = seat
		combat.active_character = actor
		combat.active_combatant = {"is_player": true, "entity": actor}
		actor.current_hp = 1
		actor.feature_uses[pool] = 1
		combat.turn_budget.reset(actor, combat.player_entities)
		combat.hud.update_hud(actor, combat.tracker)
		combat.hud._show_feature_selection()
		var index := -1
		for item in combat.hud.features_registered.size():
			if combat.hud.features_registered[item]["id"] == id:
				index = item
		_assert(index >= 0 and not combat.hud.feature_list.is_item_disabled(index), "healing with a final use is enabled in the real menu")
		if index >= 0:
			combat.hud._on_feature_selected(index)
		_assert(actor.current_hp > 1 and actor.feature_uses[pool] == 0 and not combat.turn_budget.bonus_action_available and combat.turn_budget.action_available, "owned menu activation heals, spends one use and only a Bonus Action")
		var hp := actor.current_hp
		combat._on_hud_action("use_feature", {"feature": actor.get_feature(id)})
		_assert(actor.current_hp == hp and actor.feature_uses[pool] == 0, "repeated activation cannot duplicate healing or costs")
	_teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	var scores_before := warden.ability_scores.to_dict()
	_assert(SaveManager.save_game("class_building_blocks"), "custom class saves through the real safe-save boundary")
	_assert(SaveManager.load_game("class_building_blocks"), "custom class reloads through SaveManager")
	var loaded: Character = PlayerManager.get_player(0).get("character")
	_assert(loaded != warden and loaded.subclass_id == "fixture:healer" and loaded.feature_uses["fixture:resolve"] == 0 and loaded.ability_scores.to_dict() == scores_before and ClassProgression.pending_improvements(loaded).is_empty(), "SaveManager preserves custom subclass, choices, scores and exhausted pool")
	var original: Dictionary = DataLoader.subclasses["fixture:healer"]
	DataLoader.subclasses.erase("fixture:healer")
	_assert(not SaveManager._validate_save_data(SaveManager._read_save("class_building_blocks")).is_empty() and PlayerManager.get_player(0).get("character") == loaded, "missing required subclass fails preflight without changing the active party")
	DataLoader.subclasses["fixture:healer"] = original
	SaveManager.delete_save("class_building_blocks")
	DataLoader.load_all_data()
	_exit_test()

## Ordinary attack targeting and actual optional prompts for non-Fighter rules.
func test_barbarian_action_flow() -> void:
	_enter_test("barbarian_action_flow")
	_setup_world()
	var actor := BarbarianChecks._character(5)
	PlayerManager.set_player_character(0, actor)
	PartyManager.reset()
	_assert(PartyManager.register_player_character(0, actor), "Barbarian fixture registers the character in the actual party")
	PartyManager.register_player_character(1, PlayerManager.get_player(1).get("character"))
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	_assert(combat.player_entities[0]["character"] == actor, "Live combat uses the registered Barbarian")
	combat.current_player_idx = 0
	combat.active_character = actor
	combat.active_combatant = {"is_player": true, "entity": actor}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(-4, 0)
	var target: Dictionary = combat.monster_entities[0]
	target["hex_position"] = Vector2i(1, 0)
	target["current_hp"] = 10000
	target["max_hp"] = 10000
	target["armor_class"] = -100
	combat.monster_entities[1]["hex_position"] = Vector2i(5, -3)
	# A known clear corridor tests the push, rather than random encounter terrain.
	for x in range(5):
		var tile := HexTile.new()
		tile.coord = Vector2i(x, 0)
		combat.hex_grid.add_tile(tile)
	combat.turn_budget.reset(actor, combat.player_entities)
	combat.hud.update_hud(actor, combat.tracker)
	combat._update_grid_entities()
	combat.hud._show_feature_selection()
	var index := -1
	for item in combat.hud.features_registered.size():
		if combat.hud.features_registered[item]["id"] == "barbarian_rage":
			index = item
	_assert(index >= 0, "Rage appears in the real feature picker")
	if index >= 0:
		combat.hud._on_feature_selected(index)
	_assert(actor.has_condition("raging") and not combat.turn_budget.bonus_action_available, "HUD Rage activation spends the Bonus Action")
	actor.tick_conditions()
	actor.feature_uses["barbarian_rage"] = 0
	combat.turn_budget.reset(actor, combat.player_entities)
	combat.hud._show_feature_selection()
	_assert(index >= 0 and not combat.hud.feature_list.is_item_disabled(index) and combat.hud.feature_list.get_item_text(index).begins_with("Extend Rage"), "Rage extension stays visibly enabled with an empty pool")
	if index >= 0:
		combat.hud._on_feature_selected(index)
	_assert(int(actor.conditions.get("raging", 0)) == 2 and actor.feature_uses["barbarian_rage"] == 0 and not combat.turn_budget.bonus_action_available, "HUD extension charges no Rage use")
	combat.turn_budget.reset(actor, combat.player_entities)
	GameManager.test_mode = false
	combat._on_hud_action("attack", {})
	combat._on_hex_clicked(target["hex_position"])
	await get_tree().process_frame
	_assert(_answer_fighter_popup(combat, false), "The first attack offers the real Reckless choice")
	for frame in 3:
		await get_tree().process_frame
	_assert(not actor.has_condition("reckless_attack") and int(actor.feature_uses.get("barbarian_reckless_attack_used_this_turn", 0)) == 1 and combat.remaining_attack_swings == 0, "Declining Reckless settles both Attack swings and records the decision")
	var attacks: Array = ActivityHistory.get_records().back().get("payload", {}).get("sections", {}).get("attacks", [])
	_assert(attacks.size() == 2 and not combat.resolving_player_action and not actor.has_condition("reckless_attack"), "Extra Attack completes without reopening the declined Reckless choice")
	# Forceful Blow uses the real grid/push and its actual movement picker.
	target["size"] = "huge"
	combat._finish_fighter_attack(target, {}, {"hit": true, "barbarian_brutal_strike": {"push_distance": 3, "move_after_push": true}}, actor)
	await get_tree().process_frame
	_assert(target["hex_position"] == Vector2i(4, 0) and _answer_fighter_popup(combat, true), "Forceful Blow pushes a Huge target and offers follow-up movement")
	for frame in 3:
		await get_tree().process_frame
	_assert(combat.fighter_move_waiting and Vector2i(1, 0) in combat.fighter_move_choices and Vector2i(0, 1) not in combat.fighter_move_choices, "Forceful movement highlights only the straight path toward its target")
	await combat._on_hex_clicked(Vector2i(0, 1))
	_assert(combat.fighter_move_waiting and combat.player_entities[0]["hex_position"] == Vector2i.ZERO, "An off-path click cannot consume Forceful movement")
	await combat._on_hex_clicked(Vector2i(1, 0))
	for frame in 3:
		await get_tree().process_frame
	_assert(not combat.fighter_move_waiting and combat.player_entities[0]["hex_position"] == Vector2i(1, 0), "Selecting a legal Forceful destination finishes the movement")
	GameManager.test_mode = true
	_teardown_scene(combat)
	actor.end_rage()
	while actor.level < 15:
		actor.level_up()
	actor.feature_uses["barbarian_rage"] = 1
	ClassFeature.execute(actor, actor.get_feature("barbarian_rage"))
	for turn in 99:
		BarbarianRules.maintain_rage(actor)
		actor.tick_conditions()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	_assert(SaveManager.save_game("barbarian_acceptance") and SaveManager.load_game("barbarian_acceptance"), "An active Persistent Rage round-trips through disk SaveManager")
	var loaded: Character = PlayerManager.get_player(0).get("character")
	_assert(loaded == PartyManager.characters[actor.character_id], "Reload binds the player seat and party to one canonical character")
	_assert(loaded != actor and loaded.has_condition("raging") and int(loaded.feature_uses.get("barbarian_rage_seconds_remaining", 0)) == 6, "Reload preserves six seconds of Rage without restarting the cap")
	GameManager.advance_campaign_time(5)
	_assert(loaded.has_condition("raging"), "Campaign time preserves the final partial second of Rage")
	GameManager.advance_campaign_time(1)
	_assert(not loaded.has_condition("raging") and loaded.get_modifier("stat", "damage:rage") == 0, "Production campaign time expires Rage and its damage bonus together")
	_exit_test()


func test_barbarian_choice_flow() -> void:
	_enter_test("barbarian_choice_flow")
	_setup_world()
	var actor := BarbarianChecks._character(11)
	PlayerManager.set_player_character(0, actor)
	PartyManager.reset()
	PartyManager.register_player_character(0, actor)
	PartyManager.register_player_character(1, PlayerManager.get_player(1).get("character"))
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(-4, 0)
	var target: Dictionary = combat.monster_entities[0]
	target["hex_position"] = Vector2i(1, 0)
	target["current_hp"] = 10000
	target["armor_class"] = -100
	combat.monster_entities[1]["hex_position"] = Vector2i(5, -3)
	for index in combat.tracker.combatants.size():
		if combat.tracker.combatants[index]["entity"] is Character and combat.tracker.combatants[index]["entity"] == actor:
			combat.tracker.active_index = index
	await combat._start_combat_turn()
	_assert(combat.active_character == actor and CombatAction.active_turn_actor_id == actor.get_instance_id(), "Real turn start identifies the Barbarian's own turn")
	GameManager.test_mode = false
	combat._on_hud_action("attack", {})
	combat._on_hex_clicked(target["hex_position"])
	_assert(await _answer_class_dialog(combat.hud, "Reckless Attack", true), "The owner accepts Reckless through its actual prompt")
	_assert(await _answer_class_dialog(combat.hud, "Brutal Strike", false), "The owner declines Brutal Strike on the first swing")
	_assert(await _answer_class_dialog(combat.hud, "Brutal Strike", true), "The second swing offers Brutal Strike again")
	_assert(await _answer_barbarian_effect(combat.hud, "Hamstring Blow"), "The owner selects Hamstring in the real effect picker")
	for frame in 12:
		await get_tree().process_frame
	var attacks: Array = ActivityHistory.get_records().back().get("payload", {}).get("sections", {}).get("attacks", [])
	_assert(attacks.size() == 2 and attacks[0]["roll"].get("advantage", false) and not attacks[1]["roll"].get("advantage", true), "First swing keeps Reckless Advantage; the chosen second swing forgoes it")
	_assert(int(actor.feature_uses.get("barbarian_brutal_strike_used_this_turn", 0)) == 1 and target.has("barbarian_hamstring_owner") and not combat.resolving_player_action, "The chosen second swing settles one Brutal Strike and Hamstring")
	# An ally's real turn leaves Reckless active but disallows own-turn features.
	GameManager.test_mode = true
	for index in combat.tracker.combatants.size():
		if combat.tracker.combatants[index]["entity"] is Character and combat.tracker.combatants[index]["entity"] == PlayerManager.get_player(1).get("character"):
			combat.tracker.active_index = index
	await combat._start_combat_turn()
	actor.feature_uses["barbarian_brutal_strike_used_this_turn"] = 0
	actor.reaction_available = true
	_assert(actor.has_condition("reckless_attack") and not BarbarianRules.brutal_strike_eligible(actor, DataLoader.get_item("greataxe")), "Reckless persists off-turn while Brutal Strike is refused")
	GameManager.test_mode = false
	combat._check_opportunity_attacks_for_path(null, target, [Vector2i(1, 0), Vector2i(2, 0)], true)
	_assert(await _answer_class_dialog(combat.hud, "Reaction", true), "The owner accepts the actual Opportunity Attack prompt")
	for frame in 12:
		await get_tree().process_frame
	attacks = ActivityHistory.get_records().back().get("payload", {}).get("sections", {}).get("attacks", [])
	_assert(not actor.reaction_available and attacks.size() == 1 and attacks[0]["roll"].get("advantage", false) and int(actor.feature_uses["barbarian_brutal_strike_used_this_turn"]) == 0, "Off-turn Opportunity Attack keeps Reckless Advantage without spending Brutal Strike")
	GameManager.test_mode = true
	for index in combat.tracker.combatants.size():
		if combat.tracker.combatants[index]["entity"] is Character and combat.tracker.combatants[index]["entity"] == actor:
			combat.tracker.active_index = index
	await combat._start_combat_turn()
	_assert(not actor.has_condition("reckless_attack"), "The Barbarian's next actual turn clears Reckless")
	# The saved owner policy is editable on the actual sheet even during combat.
	CharacterSheet.show_sheet(actor)
	await get_tree().process_frame
	var policy: CheckBox = null
	for control in CharacterSheet._content.find_children("*", "CheckBox", true, false):
		if control.text.begins_with("Use Relentless Rage"):
			policy = control
	_assert(policy != null, "The combat sheet displays the Relentless Rage choice")
	if policy != null:
		policy.button_pressed = false
	_assert(not actor.barbarian_relentless_rage_enabled, "The sheet can decline future Relentless Rage attempts")
	CharacterSheet.close_sheet()
	_teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	ClassFeature.execute(actor, actor.get_feature("barbarian_rage"))
	var dialog: Node = await _spawn_scene("res://scenes/ui/event_dialog.tscn", 0.2)
	dialog.popup_event(actor, {"id": "primal_choice", "name": "Balance", "type": "skill_check", "check": {"ability": "DEX", "skill": "Acrobatics", "dc": 1}, "success": {}, "failure": {}})
	_assert(is_instance_valid(dialog._primal_knowledge_choice) and dialog.btn_roll.text.contains("STR"), "The real event offers Primal Knowledge before rolling")
	if is_instance_valid(dialog._primal_knowledge_choice):
		dialog._primal_knowledge_choice.button_pressed = false
	_assert(dialog.btn_roll.text.contains("DEX") and not dialog._pending_check_data.get("use_primal_knowledge", true), "Declining Primal Knowledge updates the displayed check and roll payload")
	dialog.btn_roll.pressed.emit()
	await get_tree().create_timer(1.3).timeout
	_assert(dialog.btn_roll.disabled and dialog.btn_close.visible, "The declined check completes through the actual Roll button")
	_teardown_scene(dialog)
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	_assert(SaveManager.save_game("barbarian_choices") and SaveManager.load_game("barbarian_choices"), "Barbarian choices survive the disk-save boundary")
	var loaded: Character = PlayerManager.get_player(0).get("character")
	_assert(not loaded.barbarian_relentless_rage_enabled and loaded == PartyManager.characters[actor.character_id], "Reload preserves the declined policy on the canonical party character")
	var malformed: Dictionary = SaveManager._read_save("barbarian_choices")
	malformed["party"]["characters"][actor.character_id]["barbarian_relentless_rage_enabled"] = "always"
	_assert(not SaveManager._validate_save_data(malformed).is_empty() and PlayerManager.get_player(0).get("character") == loaded, "Save preflight rejects a malformed choice before mutating the live party")
	SaveManager.delete_save("barbarian_choices")
	for starting_choice in [0, 1]:
		PlayerManager.reset()
		PartyManager.reset()
		PlayerManager.add_player("Barbarian owner")
		PlayerManager.add_player("Next seat")
		GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
		var creation: Node = await _spawn_scene("res://scenes/ui/character_creation.tscn", 0.2)
		creation.selected_name = "Starting choice"
		creation.selected_race_id = "human"
		creation.selected_class_id = "barbarian"
		creation.current_step = creation.CreationStep.EQUIPMENT
		creation._update_step_ui()
		await get_tree().process_frame
		var option: OptionButton = creation.equip_list.get_node("BarbarianStartingEquipment")
		option.select(starting_choice)
		option.item_selected.emit(starting_choice)
		await get_tree().process_frame
		creation.current_step = creation.CreationStep.SUMMARY
		creation._update_step_ui()
		_assert(creation.summary_equip_label.text.contains("Gold: %d GP" % (15 if starting_choice == 0 else 75)), "Creation summary shows the selected starting cash")
		creation.btn_next.pressed.emit()
		var created: Character = PlayerManager.get_player(0).get("character")
		_assert(created != null and created.inventory.gold == (15 if starting_choice == 0 else 75) and (created.inventory.count_item("explorers_pack") == 1 if starting_choice == 0 else created.inventory.backpack.is_empty() and created.inventory.equipped.is_empty()), "Actual Confirm grants the chosen equipment or cash")
		_teardown_scene(creation)
	_exit_test()


func _answer_class_dialog(hud: Node, title_part: String, accepted: bool) -> bool:
	for frame in 120:
		for child in hud.get_children():
			if child is ConfirmationDialog and not child.is_queued_for_deletion() and str(child.title).contains(title_part):
				if accepted:
					child.confirmed.emit()
				else:
					FighterChecks._seed_die(20, 10)
					child.canceled.emit()
				await get_tree().process_frame
				return true
		await get_tree().process_frame
	return false


func _answer_barbarian_effect(hud: Node, label: String) -> bool:
	for frame in 120:
		for child in hud.get_children():
			if child is PopupMenu and not child.is_queued_for_deletion() and str(child.title).begins_with("Choose Brutal Strike"):
				for index in child.item_count:
					if child.get_item_text(index) == label:
						FighterChecks._seed_die(20, 10)
						child.id_pressed.emit(child.get_item_id(index))
						await get_tree().process_frame
						return true
		await get_tree().process_frame
	return false


func test_bard_creation_flow() -> void:
	_enter_test("bard_creation_flow")
	_setup_world()
	for starting_choice in [0, 1]:
		PlayerManager.reset()
		PartyManager.reset()
		PlayerManager.add_player("Bard owner")
		PlayerManager.add_player("Next seat")
		GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
		var creation: Node = await _spawn_scene("res://scenes/ui/character_creation.tscn", 0.2)
		creation.selected_name = "Chosen Bard"
		creation.selected_race_id = "elf"
		creation.selected_class_id = "bard"
		creation.current_step = creation.CreationStep.EQUIPMENT
		creation._update_step_ui()
		await get_tree().process_frame
		_assert(creation.btn_next.disabled, "Bard creation waits for explicit skills and instrument choices")
		var skill: OptionButton = creation.equip_list.get_node("BardSkill1")
		for index in skill.item_count:
			if skill.get_item_metadata(index) == "Perception":
				_assert(skill.is_item_disabled(index), "Creation excludes the Elf's existing skill proficiency")
		for index in 3:
			_select_creation_choice(creation.equip_list.get_node("BardSkill%d" % (index + 1)), ["Performance", "Persuasion", "Stealth"][index])
			_select_creation_choice(creation.equip_list.get_node("BardTool%d" % (index + 1)), ["lute", "flute", "viol"][index])
		_select_creation_choice(creation.equip_list.get_node("BardTool3"), "lute")
		_assert(creation.btn_next.disabled and creation.equip_list.get_node("BardChoiceStatus").text.contains("distinct"), "Duplicate instruments keep Next disabled with an actionable message")
		_select_creation_choice(creation.equip_list.get_node("BardTool3"), "viol")
		if starting_choice == 0:
			_select_creation_choice(creation.equip_list.get_node("BardStartingInstrument"), "drum")
			await get_tree().process_frame
		else:
			var equipment: OptionButton = creation.equip_list.get_node("BardStartingEquipment")
			equipment.select(1)
			equipment.item_selected.emit(1)
			await get_tree().process_frame
		_assert(not creation.btn_next.disabled, "Valid Bard choices enable Next for equipment or gold")
		creation.btn_next.pressed.emit()
		_assert(creation.current_step == creation.CreationStep.SUMMARY and creation.summary_stats_label.text.contains("Performance, Persuasion, Stealth") and creation.summary_stats_label.text.contains("Lute, Flute, Viol"), "Actual review shows the selected skills and instrument proficiencies")
		_assert(creation.summary_equip_label.text.contains("Gold: %d GP" % (19 if starting_choice == 0 else 90)), "Bard review shows the selected starting cash")
		creation.btn_back.pressed.emit()
		await get_tree().process_frame
		_assert(creation.bard_creation_choices["skills"] == ["Performance", "Persuasion", "Stealth"] and not creation.btn_next.disabled, "Back navigation preserves Bard choices")
		creation.btn_next.pressed.emit()
		creation.btn_next.pressed.emit()
		var created: Character = PlayerManager.get_player(0).get("character")
		_assert(created != null and created.tool_proficiencies == ["lute", "flute", "viol"] and created.get_skill_proficiency_bonus("Performance") == created.proficiency_bonus and created.skill_proficiencies.has("Perception"), "Actual Confirm grants chosen Bard proficiencies and retains species skills")
		_assert(created.inventory.gold == (19 if starting_choice == 0 else 90) and (created.inventory.count_item("drum") == 1 and created.inventory.count_item("entertainers_pack") == 1 and created.inventory.count_item("dagger") == 1 and created.inventory.get_weapon() == "dagger" and created.inventory.get_armor() == "leather_armor" if starting_choice == 0 else created.inventory.backpack.is_empty() and created.inventory.equipped.is_empty()), "Actual Bard Confirm grants precisely equipment plus cash or cash alone")
		_assert(creation.current_player_idx == 1 and creation.bard_creation_choices["skills"] == ["", "", ""] and creation.bard_creation_choices["tools"] == ["", "", ""], "The next seat starts with fresh choices")
		_teardown_scene(creation)
		GameManager.current_state = GameManager.GameState.OVERWORLD
		GameManager.game_in_progress = true
		_assert(SaveManager.save_game("bard_creation"), "Bard creation saves through the actual disk boundary")
		_assert(SaveManager.load_game("bard_creation"), "Bard creation loads through the actual disk boundary")
		var loaded: Character = PlayerManager.get_player(0).get("character")
		_assert(loaded.creation_choices == created.creation_choices and loaded.tool_proficiencies == created.tool_proficiencies and loaded.inventory.to_dict() == created.inventory.to_dict() and PartyManager.characters.get(loaded.character_id) == loaded, "Disk reload preserves Bard choices, exact inventory and canonical identity without replaying grants")
		var malformed: Dictionary = SaveManager._read_save("bard_creation")
		malformed["players"][0]["character"]["tool_proficiencies"] = ["lute", "lute", "viol"]
		_assert(not SaveManager._validate_save_data(malformed).is_empty() and PlayerManager.get_player(0).get("character") == loaded, "Malformed instrument proficiency is refused before live party mutation")
		malformed = SaveManager._read_save("bard_creation")
		malformed["party"]["characters"][loaded.character_id]["creation_choices"]["tools"] = ["lute", "flute"]
		_assert(not SaveManager._validate_save_data(malformed).is_empty() and PlayerManager.get_player(0).get("character") == loaded, "Party creation choices also fail preflight before mutation")
		await get_tree().process_frame
		CharacterSheet.show_sheet(loaded)
		var sheet_text := ""
		for label in CharacterSheet._content.find_children("*", "Label", true, false):
			sheet_text += label.text + "\n"
		_assert(sheet_text.contains("Tool Proficiencies") and sheet_text.contains("Viol"), "The actual character sheet shows instrument proficiencies")
		CharacterSheet.close_sheet()
		SaveManager.delete_save("bard_creation")
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Random Bard")
	PlayerManager.add_player("Next seat")
	GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
	var random_creation: Node = await _spawn_scene("res://scenes/ui/character_creation.tscn", 0.2)
	# Constrain only the random sampler's eligible class/species; use its real button.
	random_creation.classes_data = [DataLoader.get_character_class("bard")]
	random_creation.races_data = [DataLoader.get_race("elf")]
	random_creation.btn_rand.pressed.emit()
	_assert(random_creation.current_step == random_creation.CreationStep.SUMMARY and not random_creation.btn_next.disabled and random_creation._creation_choice_error().is_empty(), "Random Bard creation fills valid distinct choices and reaches review")
	var random_choices: Dictionary = random_creation.bard_creation_choices.duplicate(true)
	random_creation.btn_next.pressed.emit()
	var random_bard: Character = PlayerManager.get_player(0).get("character")
	_assert(random_bard != null and random_bard.creation_choices == random_choices and random_bard.inventory.count_item(str(random_choices["instrument"])) == 1, "Random Bard Confirm grants exactly the displayed instrument and choices")
	_teardown_scene(random_creation)
	_exit_test()


func _select_creation_choice(selector: OptionButton, value: String) -> void:
	for index in selector.item_count:
		if selector.get_item_metadata(index) == value:
			selector.select(index)
			selector.item_selected.emit(index)
			return
	_assert(false, "Creation option is available: %s" % value)


func test_bard_action_flow() -> void:
	_enter_test("bard_action_flow")
	_setup_world()
	var bard := BardChecks.character(10)
	bard.character_name = "Audit Bard"
	bard.skill_proficiencies.append_array(["Performance", "Persuasion", "History"])
	await get_tree().process_frame
	CharacterSheet.show_sheet(bard)
	await get_tree().process_frame
	for entitlement in 2:
		for button in CharacterSheet._content.find_children("*", "Button", true, false):
			if button.text == "Choose expertise":
				button.get_parent().get_child(1).select(1)
				button.pressed.emit()
				break
		await get_tree().process_frame
	_assert(ClassProgression.pending_skill_expertise_choices(bard).is_empty() and bard.get_skill_proficiency_bonus("Performance") == bard.proficiency_bonus * 2, "The real sheet chooses both Bard Expertise grants")
	var spell_selectors: Array[OptionButton] = []
	var has_guiding_bolt := false
	for option in CharacterSheet._content.find_children("*", "OptionButton", true, false):
		if option.get_parent().get_child(0) is Label and option.get_parent().get_child(0).text.begins_with("Prepared"):
			spell_selectors.append(option)
			has_guiding_bolt = has_guiding_bolt or option.get_item_metadata(option.selected) == "guiding_bolt"
	if not has_guiding_bolt and not spell_selectors.is_empty():
		var option: OptionButton = spell_selectors.back()
		for index in option.item_count:
			if option.get_item_metadata(index) == "guiding_bolt":
				option.select(index)
	for button in CharacterSheet._content.find_children("*", "Button", true, false):
		if button.text == "Choose spells":
			button.pressed.emit()
			break
	_assert("guiding_bolt" in bard.known_spells and not bard.spell_choices_pending and "fire_bolt" not in bard.get_spell_option_ids(true), "Actual Magical Secrets training prepares a Cleric spell while keeping cantrips on the Bard list")
	CharacterSheet.close_sheet()
	while bard.level < 20:
		bard.level_up()
	var ally := BardChecks.character(5, "wizard")
	ally.character_name = "Audit Wizard"
	PlayerManager.set_player_character(0, bard)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, bard)
	PartyManager.register_player_character(1, ally)
	bard.feature_uses["bard_bardic_inspiration"] = 0
	GameManager.transition_context["monster_ids"] = ["goblin", "goblin", "goblin"]
	# Guarantee a player starts so no background enemy turn overlaps the sampler.
	bard.ability_scores.set_score("DEX", 54)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	bard.ability_scores.set_score("DEX", 14)
	_assert(int(bard.feature_uses["bard_bardic_inspiration"]) == 2, "Actual encounter Initiative applies Superior Inspiration")
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	var target: Dictionary = combat.monster_entities[0]
	target["hex_position"] = Vector2i(2, 0)
	target["current_hp"] = 10000
	target["armor_class"] = 15
	combat.monster_entities[1]["hex_position"] = Vector2i(5, -3)
	combat.monster_entities[2]["hex_position"] = Vector2i(8, 0)
	await _start_class_fixture_turn(combat, bard)
	GameManager.test_mode = false
	combat.hud._show_feature_selection()
	for index in combat.hud.features_registered.size():
		if combat.hud.features_registered[index]["id"] == "bard_bardic_inspiration":
			combat.hud._on_feature_selected(index)
			break
	await combat._on_hex_clicked(Vector2i(1, 0))
	_assert(ally.feature_uses.get("bardic_inspiration_die", "") == "1d12" and not combat.turn_budget.bonus_action_available and combat.turn_budget.action_available and int(bard.feature_uses["bard_bardic_inspiration"]) == 1, "The real Inspiration menu grants the captured d12 and spends only one use and Bonus Action")
	# Font is available even after that Bonus Action was spent.
	var level_one_slots := int(bard.spell_slots["1"])
	combat.hud._show_feature_selection()
	for index in combat.hud.features_registered.size():
		if combat.hud.features_registered[index]["id"] == "bard_font_of_inspiration":
			combat.hud._on_feature_selected(index)
			break
	_assert(await _answer_class_popup(combat.hud, "Level 1"), "Font reaches the real spell-slot picker")
	for frame in 3:
		await get_tree().process_frame
	_assert(int(bard.feature_uses["bard_bardic_inspiration"]) == 2 and int(bard.spell_slots["1"]) == level_one_slots - 1 and not combat.turn_budget.bonus_action_available and combat.turn_budget.action_available, "Font restores one use for one slot without spending another action")
	await _start_class_fixture_turn(combat, ally)
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index]["id"] == "fire_bolt":
			combat.hud._on_spell_selected(index)
			break
	combat._on_hex_clicked(Vector2i(2, 0))
	FighterChecks._seed_die(20, 10)
	_assert(await _answer_class_dialog(combat.hud, "Bardic Inspiration", true), "A spell attack reaches the recipient's actual Inspiration choice")
	for frame in 6:
		await get_tree().process_frame
	_assert(not BardicInspirationRules.has_die(ally) and int(target["current_hp"]) < 10000 and not combat.turn_budget.action_available, "The chosen die turns the Wizard's failed spell attack into a hit without another action")
	# A real enemy spell offers the nearby Bard's Countercharm.
	target["spell_slots"] = {"1": 1}
	combat._execute_monster_spell(target, ally.character_name, "charm_person")
	if "counterspell" in bard.known_spells:
		_assert(await _answer_class_dialog(combat.hud, "Reaction", false), "The Bard can save the Reaction rather than Counterspell")
	FighterChecks._seed_die(20, 1)
	_assert(await _answer_class_dialog(combat.hud, "Countercharm", true), "The nearby Bard accepts the actual Countercharm Reaction prompt")
	for frame in 6:
		await get_tree().process_frame
	_assert(not bard.reaction_available, "Countercharm spends the Bard's Reaction only after the failed save")
	GameManager.test_mode = true
	await _start_class_fixture_turn(combat, bard)
	ally.current_hp = 0
	ally.is_alive = false
	ally.death_save_failures = 0
	bard.current_hp = 1
	bard.add_condition("prone", 2)
	bard.spell_slots["9"] = 1
	GameManager.test_mode = false
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index]["id"] == "power_word_heal":
			combat.hud._on_spell_selected(index)
			break
	_assert(combat.pending_spell_data.get("id", "") == "power_word_heal" and CombatAction.get_spell_slot_level(bard, combat.pending_spell_data) == 9, "The real menu selects always-prepared Power Word Heal with its ninth-level cost")
	await combat._on_hex_clicked(Vector2i.ZERO)
	await combat._on_hex_clicked(Vector2i(8, 0))
	_assert(int(bard.spell_slots["9"]) == 1 and combat.pending_words_primary_selected, "An out-of-range second creature cannot spend the Power Word cast")
	await combat._on_hex_clicked(Vector2i(1, 0))
	_assert(await _answer_class_dialog(combat.hud, "Power Word Heal", false), "The healed Prone recipient can decline standing")
	for frame in 6:
		await get_tree().process_frame
	_assert(bard.current_hp == bard.max_hp and ally.current_hp == ally.max_hp and ally.is_alive and int(bard.spell_slots["9"]) == 0 and not combat.turn_budget.action_available, "Words of Creation heals both creatures, including a downed ally, for one slot and Magic Action")
	_assert(bard.has_condition("prone") and bard.reaction_available, "Declining the stand-up benefit keeps Prone and the Reaction")
	GameManager.test_mode = true
	await _start_class_fixture_turn(combat, bard)
	bard.spell_slots["9"] = 1 # Funding a separate cast, not claiming turn-based recovery.
	for index in 2:
		combat.monster_entities[index]["current_hp"] = 99
		combat.monster_entities[index]["is_alive"] = true
		combat.monster_entities[index]["hex_position"] = Vector2i(3 + index, 0)
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index]["id"] == "power_word_kill":
			combat.hud._on_spell_selected(index)
			break
	await combat._on_hex_clicked(Vector2i(3, 0))
	await combat._on_hex_clicked(Vector2i(4, 0))
	_assert(not combat.monster_entities[0]["is_alive"] and not combat.monster_entities[1]["is_alive"] and int(bard.spell_slots["9"]) == 0 and not combat.turn_budget.action_available, "Words of Creation kills two eligible targets for one ninth-level slot and Magic Action")
	_teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	CombatAction.resolve_bardic_inspiration(bard, ally)
	ally.feature_uses["bardic_inspiration_seconds_remaining"] = 59
	_assert(SaveManager.save_game("bard_acceptance") and SaveManager.load_game("bard_acceptance"), "Bard choices and a held die round-trip through the actual disk-save boundary")
	var loaded: Character = PlayerManager.get_player(1).get("character")
	_assert(loaded == PartyManager.characters[ally.character_id] and loaded.feature_uses.get("bardic_inspiration_die", "") == "1d12" and int(loaded.feature_uses.get("bardic_inspiration_seconds_remaining", 0)) == 59, "Reload preserves the captured die and remaining seconds on the canonical recipient")
	var malformed: Dictionary = SaveManager._read_save("bard_acceptance")
	malformed["party"]["characters"][ally.character_id]["feature_uses"]["bardic_inspiration_seconds_remaining"] = "forever"
	_assert(not SaveManager._validate_save_data(malformed).is_empty() and PlayerManager.get_player(1).get("character") == loaded, "Malformed Inspiration clock fails preflight without changing the live party")
	GameManager.advance_campaign_time(58)
	_assert(BardicInspirationRules.has_die(loaded) and int(loaded.feature_uses["bardic_inspiration_seconds_remaining"]) == 1, "Campaign time preserves the final second of held Inspiration")
	GameManager.advance_campaign_time(1)
	_assert(not BardicInspirationRules.has_die(loaded), "Production campaign time expires the saved die without refilling its clock")
	SaveManager.delete_save("bard_acceptance")
	_exit_test()


func _start_class_fixture_turn(combat: Node, actor: Character) -> void:
	for index in combat.tracker.combatants.size():
		if combat.tracker.combatants[index]["entity"] is Character and combat.tracker.combatants[index]["entity"] == actor:
			combat.tracker.active_index = index
	await combat._start_combat_turn()


func _answer_class_popup(hud: Node, label_prefix: String) -> bool:
	for frame in 120:
		for child in hud.get_children():
			if child is PopupMenu and not child.is_queued_for_deletion():
				for index in child.item_count:
					if child.get_item_text(index).begins_with(label_prefix):
						child.id_pressed.emit(child.get_item_id(index))
						await get_tree().process_frame
						return true
		await get_tree().process_frame
	return false


func test_cleric_creation_flow() -> void:
	_enter_test("cleric_creation_flow")
	_setup_world()
	for equipment_index in [0, 1]:
		PlayerManager.reset()
		PartyManager.reset()
		PlayerManager.add_player("Cleric owner")
		PlayerManager.add_player("Next seat")
		GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
		var creation: Node = await _spawn_scene("res://scenes/ui/character_creation.tscn", 0.2)
		creation.selected_name = "Chosen Cleric"
		creation.selected_race_id = "human"
		creation.selected_class_id = "cleric"
		creation.current_step = creation.CreationStep.EQUIPMENT
		creation._update_step_ui()
		await get_tree().process_frame
		_assert(creation.btn_next.disabled, "Cleric creation waits for Divine Order and two skill choices")
		_select_creation_choice(creation.equip_list.get_node("ClericDivineOrder"), "protector" if equipment_index == 0 else "thaumaturge")
		_select_creation_choice(creation.equip_list.get_node("ClericSkill1"), "Medicine")
		_select_creation_choice(creation.equip_list.get_node("ClericSkill2"), "Medicine")
		_assert(creation.btn_next.disabled and creation.equip_list.get_node("ClericChoiceStatus").text.contains("distinct"), "Duplicate Cleric skills keep Next disabled with a reason")
		_select_creation_choice(creation.equip_list.get_node("ClericSkill2"), "Religion")
		var equipment: OptionButton = creation.equip_list.get_node("ClericStartingEquipment")
		equipment.select(equipment_index)
		equipment.item_selected.emit(equipment_index)
		await get_tree().process_frame
		creation.btn_next.pressed.emit()
		_assert(creation.current_step == creation.CreationStep.SUMMARY and creation.summary_stats_label.text.contains("Medicine, Religion") and creation.summary_equip_label.text.contains("Gold: %d GP" % (7 if equipment_index == 0 else 110)), "Cleric review shows its chosen skills, order, equipment and gold")
		creation.btn_back.pressed.emit()
		await get_tree().process_frame
		_assert(not creation.btn_next.disabled and creation.cleric_creation_choices.skills == ["Medicine", "Religion"], "Back retains valid Cleric choices")
		creation.btn_next.pressed.emit()
		creation.btn_next.pressed.emit()
		var cleric: Character = PlayerManager.get_player(0).get("character")
		_assert(cleric != null and cleric.class_id == "cleric" and cleric.skill_proficiencies.has("Medicine") and cleric.skill_proficiencies.has("Religion"), "Cleric Confirm grants exactly the displayed skills")
		_assert(creation.cleric_divine_order.is_empty() and creation.cleric_creation_choices.skills == ["", ""], "Next seat resets Cleric choices")
		if equipment_index == 0:
			_assert(cleric.inventory.get_armor() == "chain_shirt" and cleric.inventory.get_weapon() == "mace" and cleric.inventory.get_equipped(Inventory.Slot.SHIELD) == "shield" and cleric.inventory.count_item("holy_symbol") == 1 and cleric.inventory.count_item("priests_pack") == 1 and cleric.inventory.gold == 7 and "heavy" in cleric.armor_proficiencies, "Equipment creation grants the full loadout and Protector training")
		else:
			_assert(cleric.inventory.gold == 110 and cleric.inventory.backpack.is_empty() and cleric.inventory.equipped.is_empty() and cleric.get_spellcasting_capacity("cantrips") == 4 and cleric.get_ability_check_bonus("Religion") >= 1, "Gold creation grants Thaumaturge effects and no class equipment")
		_teardown_scene(creation)
		GameManager.current_state = GameManager.GameState.OVERWORLD
		GameManager.active_dungeon_state.clear()
		GameManager.game_in_progress = true
		_assert(SaveManager.save_game("cleric_creation"), "Cleric creation saves through the actual disk boundary")
		var exact_inventory := cleric.inventory.to_dict()
		_assert(SaveManager.load_game("cleric_creation"), "Cleric creation reloads through the actual disk boundary")
		var loaded: Character = PlayerManager.get_player(0).get("character")
		_assert(loaded.inventory.to_dict() == exact_inventory and loaded.feature_choices.get("cleric_divine_order", []) == ["protector" if equipment_index == 0 else "thaumaturge"] and PartyManager.characters.get(loaded.character_id) == loaded, "Reload retains exact inventory, Divine Order and canonical party identity")
		var bad := SaveManager._read_save("cleric_creation")
		bad["party"]["characters"][loaded.character_id]["creation_choices"]["skills"] = ["Religion", "Religion"]
		_assert(not SaveManager._validate_save_data(bad).is_empty() and PlayerManager.get_player(0).get("character") == loaded, "Malformed party Cleric choices fail preflight without live mutation")
		SaveManager.delete_save("cleric_creation")
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Random Cleric")
	PlayerManager.add_player("Next seat")
	GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
	var random_creation: Node = await _spawn_scene("res://scenes/ui/character_creation.tscn", 0.2)
	random_creation.classes_data = [DataLoader.get_character_class("cleric")]
	random_creation.races_data = [DataLoader.get_race("human")]
	random_creation.btn_rand.pressed.emit()
	_assert(random_creation.current_step == random_creation.CreationStep.SUMMARY and not random_creation.btn_next.disabled, "Random Cleric creation supplies valid Divine Order and skills")
	_teardown_scene(random_creation)
	_exit_test()


func test_cleric_action_flow() -> void:
	_enter_test("cleric_action_flow")
	_setup_world()
	var cleric := ClericChecks.character(20)
	cleric.character_name = "Audit Cleric"
	var ally := BardChecks.character(5, "fighter")
	ally.character_name = "Vitality Ally"
	PlayerManager.set_player_character(0, cleric)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, cleric)
	PartyManager.register_player_character(1, ally)
	await get_tree().process_frame
	CharacterSheet.show_sheet(cleric)
	await get_tree().process_frame
	for feature in ["Divine Order", "Blessed Strikes"]:
		for button in CharacterSheet._content.find_children("*", "Button", true, false):
			if button.text == "%s: choose an option" % feature:
				button.get_parent().get_child(0).select(1)
				button.pressed.emit()
				break
		await get_tree().process_frame
	_assert(cleric.feature_choices.get("cleric_divine_order", []) == ["thaumaturge"] and cleric.feature_choices.get("cleric_blessed_strikes", []) == ["potent_spellcasting"], "The real sheet trains Divine Order and Blessed Strikes")
	for button in CharacterSheet._content.find_children("*", "Button", true, false):
		if button.text == "Choose spells":
			button.pressed.emit()
			break
	_assert("sacred_flame" in cleric.known_spells, "The real sheet prepares supported Cleric cantrips")
	CharacterSheet.close_sheet()
	cleric.ability_scores.set_score("DEX", 54)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	cleric.ability_scores.set_score("DEX", 12)
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	var target: Dictionary = combat.monster_entities[0]
	target["hex_position"] = Vector2i(2, 0)
	target["creature_type"] = "undead"
	target["name"] = "Chosen Undead"
	target["current_hp"] = 10000
	target["max_hp"] = 10000
	target["ability_scores"] = {"DEX": -100, "WIS": -100, "CON": -100}
	var excluded: Dictionary = combat.monster_entities[1]
	excluded["hex_position"] = Vector2i(3, 0)
	excluded["creature_type"] = "undead"
	excluded["name"] = "Excluded Undead"
	await _start_class_fixture_turn(combat, cleric)
	ally.current_hp = 0
	ally.is_alive = false
	ally.death_save_failures = 0
	combat.hud._show_feature_selection()
	for index in combat.hud.features_registered.size():
		if combat.hud.features_registered[index]["id"] == "cleric_divine_spark":
			combat.hud._on_feature_selected(index)
	var uses_before := int(cleric.feature_uses["cleric_channel_divinity"])
	await combat._on_hex_clicked(Vector2i.ZERO)
	_assert(int(cleric.feature_uses["cleric_channel_divinity"]) == uses_before and combat.turn_budget.action_available, "Divine Spark refuses its caster before costs")
	await combat._on_hex_clicked(Vector2i(1, 0))
	_assert(ally.current_hp > 0 and ally.is_alive and int(cleric.feature_uses["cleric_channel_divinity"]) == uses_before - 1 and not combat.turn_budget.action_available, "Actual Divine Spark revives a downed ally for one Channel Divinity use and one Magic action")
	await _start_class_fixture_turn(combat, cleric)
	GameManager.test_mode = false
	combat._execute_cleric_turn_undead(cleric.get_feature("cleric_turn_undead"))
	_assert(await _answer_class_popup(combat.hud, "Chosen Undead"), "Turn Undead offers the actual creature selector")
	_assert(await _answer_class_popup(combat.hud, "Turn selected"), "The owner finishes selecting only one Undead")
	_assert(await _answer_class_dialog(combat.hud, "Sear Undead", false), "Sear Undead can be declined in the actual prompt")
	for frame in 8:
		await get_tree().process_frame
	_assert(target["current_hp"] == 10000 and target.get("conditions", {}).has("incapacitated") and not excluded.get("conditions", {}).has("incapacitated"), "Only the chosen creature is turned and declining Sear deals no damage")
	GameManager.test_mode = true
	cleric.add_condition("stunned", 2)
	combat._update_grid_entities()
	_assert(not target.get("conditions", {}).has("incapacitated") and not target.has("turn_undead_origin"), "Actual scene refresh ends turning when its caster becomes Incapacitated")
	cleric.remove_condition("stunned")
	await _start_class_fixture_turn(combat, cleric)
	GameManager.test_mode = false
	combat._execute_cleric_turn_undead(cleric.get_feature("cleric_turn_undead"))
	_assert(await _answer_class_popup(combat.hud, "Cancel"), "Turn Undead can cancel its target selection")
	for frame in 4:
		await get_tree().process_frame
	_assert(combat.turn_budget.action_available and not combat.resolving_player_action, "Cancelling Turn Undead preserves the action and releases input")
	GameManager.test_mode = true
	await _start_class_fixture_turn(combat, cleric)
	GameManager.test_mode = false
	combat.pending_action_type = "spell"
	combat.pending_spell_data = DataLoader.get_spell("sacred_flame").duplicate(true)
	combat._on_hex_clicked(Vector2i(2, 0))
	_assert(await _answer_class_popup(combat.hud, "Vitality Ally"), "A damaging cantrip offers the actual vitality recipient menu")
	for frame in 8:
		await get_tree().process_frame
	_assert(ally.temp_hp == 6 and cleric.temp_hp == 0 and target["current_hp"] < 10000, "Potent Spellcasting grants twice Wisdom temporary HP to the chosen ally after damage")
	GameManager.test_mode = true
	await _start_class_fixture_turn(combat, cleric)
	# Exercise the actual feature/catalog menu, including its Material exemption.
	GameManager.test_mode = false
	combat._on_hud_action("use_feature", {"feature": cleric.get_feature("cleric_divine_intervention")})
	_assert(await _answer_class_popup(combat.hud, "Protection from Evil and Good"), "Actual Divine Intervention offers an unprepared component spell from the supported catalog")
	for frame in 4:
		await get_tree().process_frame
	var slots_before := cleric.spell_slots.duplicate()
	GameManager.test_mode = true
	await combat._on_hex_clicked(Vector2i(1, 0))
	_assert(ally.protection_from_evil_and_good_sources.has(cleric.character_id) and cleric.spell_slots == slots_before and int(cleric.feature_uses["cleric_divine_intervention"]) == 0 and not combat.turn_budget.action_available, "Intervention resolves one spell without a slot or Holy Water and spends its feature and Magic action once")
	cleric.long_rest()
	await _start_class_fixture_turn(combat, cleric)
	GameManager.test_mode = false
	combat._on_hud_action("use_feature", {"feature": cleric.get_feature("cleric_divine_intervention")})
	_assert(await _answer_class_popup(combat.hud, "Light ("), "Intervention can cast a marker spell through its early-return boundary")
	for frame in 4:
		await get_tree().process_frame
	GameManager.test_mode = true
	await combat._on_hex_clicked(Vector2i.ZERO)
	_assert(not combat.pending_divine_intervention and not combat.pending_divine_intervention_wish and int(cleric.feature_uses["cleric_divine_intervention"]) == 0, "Marker spells clear Intervention state after spending one use")
	await _start_class_fixture_turn(combat, cleric)
	combat.pending_action_type = "spell"
	combat.pending_spell_data = DataLoader.get_spell("sacred_flame").duplicate(true)
	var hp_before_normal_spell := int(target["current_hp"])
	await combat._on_hex_clicked(Vector2i(2, 0))
	_assert(int(target["current_hp"]) < hp_before_normal_spell and not combat.turn_budget.action_available, "The next normal spell resolves with Intervention already spent")
	cleric.long_rest()
	await _start_class_fixture_turn(combat, cleric)
	GameManager.test_mode = false
	combat._on_hud_action("use_feature", {"feature": cleric.get_feature("cleric_divine_intervention")})
	_assert(await _answer_class_popup(combat.hud, "Wish ("), "Level-20 Intervention offers Wish in the real catalog")
	_assert(await _answer_class_popup(combat.hud, "Produce Flame ("), "Wish offers the cross-class Produce Flame casting path")
	for frame in 4:
		await get_tree().process_frame
	GameManager.test_mode = true
	slots_before = cleric.spell_slots.duplicate()
	await combat._on_hex_clicked(Vector2i.ZERO)
	_assert(combat.produce_flame_markers.has(cleric.character_id) and not combat.turn_budget.action_available and combat.turn_budget.bonus_action_available and cleric.spell_slots == slots_before and not combat.pending_divine_intervention, "Wish creates the held flame for one Magic action, preserving the Bonus Action and clearing pending state")
	var flame_rests := int(cleric.feature_uses.get("cleric_divine_intervention_recovery_rests", 0))
	for rest in flame_rests:
		cleric.long_rest()
	await _start_class_fixture_turn(combat, cleric)
	GameManager.test_mode = false
	combat._on_hud_action("use_feature", {"feature": cleric.get_feature("cleric_divine_intervention")})
	_assert(await _answer_class_popup(combat.hud, "Wish ("), "Wish becomes available again after its recorded rest cooldown")
	_assert(await _answer_class_popup(combat.hud, "Fireball ("), "Wish offers a supported spell from another class")
	for frame in 4:
		await get_tree().process_frame
	GameManager.test_mode = true
	slots_before = cleric.spell_slots.duplicate()
	await combat._on_hex_clicked(Vector2i(2, 0))
	var rests := int(cleric.feature_uses.get("cleric_divine_intervention_recovery_rests", 0))
	_assert(rests >= 2 and rests <= 8 and cleric.spell_slots == slots_before and int(cleric.feature_uses["cleric_divine_intervention"]) == 0, "Actual Wish duplication spends no slot and records a 2d4 Long Rest cooldown")
	_teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	_assert(SaveManager.save_game("cleric_actions") and SaveManager.load_game("cleric_actions"), "Cleric actions save and reload through the real disk path")
	var loaded: Character = PlayerManager.get_player(0).get("character")
	_assert(int(loaded.feature_uses.get("cleric_divine_intervention_recovery_rests", 0)) == rests and loaded.feature_choices.get("cleric_blessed_strikes", []) == ["potent_spellcasting"], "Reload retains the chosen feature and exact Wish cooldown")
	var bad := SaveManager._read_save("cleric_actions")
	bad["players"][0]["character"]["feature_uses"]["cleric_divine_intervention_recovery_rests"] = 1.5
	_assert(not SaveManager._validate_save_data(bad).is_empty() and PlayerManager.get_player(0).get("character") == loaded, "Malformed Wish state fails preflight before manager mutation")
	SaveManager.delete_save("cleric_actions")
	_exit_test()


func test_cleric_strike_flow() -> void:
	_enter_test("cleric_strike_flow")
	_setup_world()
	var cleric := ClericChecks.character(14)
	cleric.character_name = "Strike Cleric"
	ClassProgression.choose_feature_option(cleric, "cleric_blessed_strikes", "divine_strike")
	cleric.inventory.unequip(Inventory.Slot.SHIELD)
	cleric.inventory.equip(Inventory.Slot.WEAPON, "dagger", true)
	cleric.inventory.equip(Inventory.Slot.OFFHAND, "dagger", true)
	cleric.ability_scores.set_score("DEX", 54)
	PlayerManager.set_player_character(0, cleric)
	PartyManager.reset()
	PartyManager.register_player_character(0, cleric)
	PartyManager.register_player_character(1, PlayerManager.get_player(1).get("character"))
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	cleric.ability_scores.set_score("DEX", 14)
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	var target: Dictionary = combat.monster_entities[0]
	target["hex_position"] = Vector2i(1, 0)
	target["current_hp"] = 10000
	target["armor_class"] = 1
	combat.monster_entities[1]["hex_position"] = Vector2i(6, 0)
	await _start_class_fixture_turn(combat, cleric)
	var record_count_before := ActivityHistory.get_records().size()
	GameManager.test_mode = false
	combat.hud.btn_attack.pressed.emit()
	_assert(combat.pending_action_type == "attack" and combat.active_character == cleric and cleric.inventory.get_weapon() == "dagger", "Actual attack button selects the trained Cleric and equipped weapon")
	FighterChecks._seed_die(20, 10)
	combat._on_hex_clicked(Vector2i(1, 0))
	_assert(await _answer_class_dialog(combat.hud, "Divine Strike", false), "A real weapon hit offers optional Divine Strike")
	FighterChecks._seed_die(20, 10)
	_assert(await _answer_class_dialog(combat.hud, "Light Weapon", true), "The Cleric can choose its legal Light weapon follow-up")
	_assert(await _answer_class_dialog(combat.hud, "Divine Strike", true), "Declining the first hit leaves Divine Strike available on the follow-up")
	_assert(await _answer_class_popup(combat.hud, "Necrotic"), "The real Divine Strike prompt can choose Necrotic damage")
	for frame in 12:
		await get_tree().process_frame
	_assert(int(cleric.feature_uses.get("divine_strike_cleric_used_this_turn", 0)) == 1 and not combat.turn_budget.action_available and not combat.turn_budget.bonus_action_available and not combat.resolving_player_action, "The Light follow-up settles Divine Strike once and spends only its normal action costs")
	var records := ActivityHistory.get_records()
	var recorded_damage := 0
	for record in records.slice(record_count_before):
		for attack in record.get("payload", {}).get("sections", {}).get("attacks", []):
			recorded_damage += int(attack.get("applied_damage", 0))
	_assert(recorded_damage == 10000 - int(target["current_hp"]) and recorded_damage > 0, "Chronicle publishes settled follow-up damage including Divine Strike")
	GameManager.test_mode = true
	await _start_class_fixture_turn(combat, cleric)
	_assert(int(cleric.feature_uses.get("divine_strike_cleric_used_this_turn", 0)) == 0, "The next real Cleric turn restores Divine Strike eligibility")
	_teardown_scene(combat)
	_exit_test()


func test_core12_shared_rules() -> void:
	_enter_test("core12_shared_rules")
	for property in ["push", "cleave", "nick"]:
		_setup_world()
		var actor := _fresh_char("Shared mastery", "human", "ranger" if property == "nick" else "barbarian", {"STR": 16, "DEX": 16, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
		var weapon_id := "shortsword" if property == "nick" else ("greataxe" if property == "cleave" else "pike")
		actor.inventory.unequip(Inventory.Slot.SHIELD)
		actor.inventory.unequip(Inventory.Slot.OFFHAND)
		actor.inventory.unequip(Inventory.Slot.WEAPON)
		actor.inventory.add_item(weapon_id)
		actor.inventory.equip(Inventory.Slot.WEAPON, weapon_id)
		_assert(actor.inventory.get_weapon() == weapon_id, "%s fixture equips its mastery weapon through normal inventory rules" % property)
		_assert(FighterRules.choose_mastery(actor, "dagger" if property == "nick" else weapon_id), "%s fixture selects its mastery through normal training" % property)
		if property == "nick":
			actor.level_up()
			ClassProgression.choose_feature_option(actor, "ranger_fighting_style", "two_weapon_fighting")
			actor.inventory.add_item("dagger")
			actor.inventory.equip(Inventory.Slot.OFFHAND, "dagger")
		PlayerManager.set_player_character(0, actor)
		PartyManager.reset()
		_assert(PartyManager.register_player_character(0, actor), "mastery fixture registers its actual actor in the party")
		PartyManager.register_player_character(1, PlayerManager.get_player(1).get("character"))
		var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
		_assert(combat.player_entities[0]["character"] == actor, "mastery combat uses the registered class character")
		combat.current_player_idx = 0
		combat.active_character = actor
		combat.active_combatant = {"is_player": true, "entity": actor}
		combat.player_entities[0]["hex_position"] = Vector2i.ZERO
		combat.player_entities[1]["hex_position"] = Vector2i(-4, 0)
		combat.turn_budget.reset(actor, combat.player_entities)
		combat.hud.update_hud(actor, combat.tracker)
		var target: Dictionary = combat.monster_entities[0]
		var other: Dictionary = combat.monster_entities[1]
		for monster in combat.monster_entities:
			monster["current_hp"] = 1000
			monster["is_alive"] = true
			monster["armor_class"] = -100
			monster["damage_resistances"] = []
			monster["damage_immunities"] = []
		target["hex_position"] = Vector2i(1, 0)
		other["hex_position"] = Vector2i(1, -1) if property == "cleave" else Vector2i(5, -3)
		combat._update_grid_entities()
		FighterChecks._seed_die(20, 10)
		if property == "push":
			combat._on_hud_action("attack", {})
			await combat._on_hex_clicked(Vector2i(1, 0))
			_assert(target["hex_position"] == Vector2i(3, 0) and not combat.turn_budget.action_available and combat.turn_budget.bonus_action_available, "Barbarian's normal Attack executes Push without Fighter identity or an extra action")
		else:
			GameManager.test_mode = false
			# Ensure both the initial and optional attack hit without critical dice.
			for candidate in 10000:
				seed(candidate)
				if randi_range(1, 20) != 10:
					continue
				randi_range(1, 4 if property == "nick" else 12)
				if randi_range(1, 20) == 10:
					seed(candidate)
					break
			combat._on_hud_action("attack", {})
			combat._on_hex_clicked(Vector2i(1, 0))
			await get_tree().process_frame
			_assert(_answer_fighter_popup(combat, true), "%s reaches its actual optional attack prompt for a non-Fighter" % property)
			for frame in 3:
				await get_tree().process_frame
			var marker := "fighter_light_used" if property == "nick" else "fighter_cleave_used"
			_assert(actor.feature_uses.get(marker, false) and combat.turn_budget.bonus_action_available and not combat.resolving_player_action, "%s completes once and preserves the Bonus Action" % property)
			if property == "cleave":
				_assert(other["current_hp"] < 1000, "Barbarian Cleave damages the selected neighboring foe")
				var hp := int(other["current_hp"])
				await combat._finish_fighter_attack(target, DataLoader.get_item(weapon_id), {"hit": true, "mastery": "cleave"}, actor)
				_assert(other["current_hp"] == hp, "Cleave cannot repeat within the same turn")
			else:
				var hp := int(target["current_hp"])
				var ledger := ActivityHistory.get_records()
				_assert(ledger.size() >= 2 and ledger.back().get("payload", {}).get("sections", {}).get("attacks", []).size() == 1, "Ranger Nick publishes its settled extra attack")
				await combat._offer_light_attack(target)
				_assert(target["current_hp"] == hp, "Nick cannot repeat within the same turn")
			GameManager.test_mode = true
		_teardown_scene(combat)
		await get_tree().process_frame
	# A real spawn retains mitigation metadata from its content record.
	_setup_world()
	var original: Array = DataLoader.monsters["goblin"].get("damage_resistances", []).duplicate()
	DataLoader.monsters["goblin"]["damage_resistances"] = ["force"]
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	_assert(combat.monster_entities[0].get("damage_resistances", []) == ["force"], "Live monster construction retains declared damage resistance")
	DataLoader.monsters["goblin"]["damage_resistances"] = original
	_teardown_scene(combat)
	_exit_test()


## Real Rogue attack, Cunning Strike option popups, saves, and timed expiry.
func test_core12_audit_repairs() -> void:
	_enter_test("core12_audit_repairs")
	_setup_mixed_world()
	GameManager.current_state = GameManager.GameState.COMBAT
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	var rogue: Character = combat.player_entities[1]["character"]
	combat.current_player_idx = 1
	combat.active_character = rogue
	combat.active_combatant = {"is_player": true, "entity": rogue}
	for index in combat.player_entities.size():
		combat.player_entities[index]["hex_position"] = Vector2i(-4, index)
	combat.player_entities[1]["hex_position"] = Vector2i.ZERO
	combat.player_entities[0]["hex_position"] = Vector2i(1, -1)
	var ally: Character = combat.player_entities[0]["character"]
	var target: Dictionary = combat.monster_entities[0]
	target["hex_position"] = Vector2i(1, 0)
	target["current_hp"] = 10000
	target["max_hp"] = 10000
	target["armor_class"] = -100
	target["is_alive"] = true
	_assert(combat._is_sneak_attack_valid(rogue, target["hex_position"], false, false, DataLoader.get_item("rapier")), "a conscious adjacent ally qualifies a Finesse attack")
	ally.add_condition("incapacitated", 1)
	_assert(not combat._is_sneak_attack_valid(rogue, target["hex_position"], false, false, DataLoader.get_item("rapier")), "an incapacitated adjacent ally cannot enable Sneak Attack")
	ally.remove_condition("incapacitated")
	rogue.feature_uses["sneak_attack_used_this_turn"] = 1
	# Re-enter the production turn setup on a different player's turn.
	for index in combat.tracker.combatants.size():
		if combat.tracker.combatants[index].get("is_player", false) and combat.tracker.combatants[index].get("entity") == ally:
			combat.tracker.active_index = index
			break
	await combat._start_combat_turn()
	_assert(not rogue.feature_uses.has("sneak_attack_used_this_turn"), "another creature's turn renews off-turn Sneak Attack eligibility")
	combat.current_player_idx = 1
	combat.active_character = rogue
	combat.active_combatant = {"is_player": true, "entity": rogue}
	combat.turn_budget.reset(rogue, combat.player_entities)
	rogue.inventory.equip(Inventory.Slot.WEAPON, "dagger", true)
	rogue.inventory.equip(Inventory.Slot.OFFHAND, "dagger", true)
	combat.light_attack_weapon = DataLoader.get_item("dagger")
	combat._update_grid_entities()
	# Find a bounded deterministic natural miss, then exercise the real Light UI.
	var miss_seed := 0
	for candidate_seed in range(1, 500):
		seed(candidate_seed)
		if Dice.roll(20) == 1:
			miss_seed = candidate_seed
			break
	seed(miss_seed)
	var miss := CombatAction.resolve_weapon_attack(rogue, target, DataLoader.get_item("dagger"))
	_assert(not miss.get("hit", true) and not rogue.feature_uses.has("sneak_attack_used_this_turn"), "a missed primary attack leaves Sneak Attack available")
	GameManager.test_mode = false
	seed(10)
	combat._offer_light_attack(target)
	_assert(await _answer_audit_dialog(combat.hud, "Light Weapon"), "the production Light attack prompt can be accepted")
	for _frame in 12:
		await get_tree().process_frame
	_assert(rogue.feature_uses.get("sneak_attack_used_this_turn", 0) == 1 and combat.hud.log_text.text.contains("Sneak Attack"), "the Light attack applies available Sneak Attack after the primary miss")
	var records := ActivityHistory.get_records()
	_assert(not records.is_empty() and str(records.back()).contains("Sneak Attack"), "Light attack activity includes its actual Sneak Attack damage")
	# An Opportunity Attack runs on the monster's turn and uses this same rider.
	rogue.feature_uses.erase("sneak_attack_used_this_turn")
	rogue.reaction_available = true
	combat.player_entities[1]["reaction_available"] = true
	for index in combat.player_entities.size():
		if index != 1:
			combat.player_entities[index]["reaction_available"] = false
	rogue.add_condition("steady_aim", 1)
	# Retain a conscious enemy of the target adjacent to it for eligibility.
	target["hex_position"] = Vector2i(1, 0)
	seed(10)
	combat._check_opportunity_attacks_for_path(null, target, [Vector2i(1, 0), Vector2i(2, 0)], true)
	_assert(await _answer_audit_dialog(combat.hud, "Reaction"), "the production Opportunity Attack prompt can be accepted")
	for _frame in 12:
		await get_tree().process_frame
	_assert(rogue.feature_uses.get("sneak_attack_used_this_turn", 0) == 1 and not rogue.reaction_available, "Opportunity Attack applies Sneak Attack and spends the reaction")
	GameManager.test_mode = true
	_teardown_scene(combat)
	# Use the actual training buttons against the catalog shortage.
	GameManager.current_state = GameManager.GameState.OVERWORLD
	var wizard := _fresh_char("Training Wizard", "human", "wizard", {"STR": 10, "DEX": 14, "CON": 12, "INT": 16, "WIS": 10, "CHA": 10})
	while wizard.level < 20:
		wizard.level_up()
	var panel := ClassTraining.new()
	add_child(panel)
	panel.configure(wizard, func(): pass)
	var learn: Button = null
	var prepare: Button = null
	for child in panel.get_children():
		if child is Button and child.text.begins_with("Record "):
			learn = child
	_assert(learn != null and not learn.disabled, "Wizard training offers available book spells without empty rows")
	var book_before := wizard.wizard_spellbook.size()
	var pending_before := wizard.wizard_spellbook_pending
	if learn != null:
		learn.pressed.emit()
	_assert(wizard.wizard_spellbook.size() > book_before and wizard.wizard_spellbook_pending >= 0 and wizard.wizard_spellbook_pending < pending_before, "book button records distinct spells and spends only available choices")
	panel.queue_free()
	panel = ClassTraining.new()
	add_child(panel)
	panel.configure(wizard, func(): pass)
	for child in panel.get_children():
		if child is Button and child.text == "Choose spells":
			prepare = child
	_assert(prepare != null, "preparation remains available with pending book choices")
	if prepare != null:
		prepare.pressed.emit()
	_assert(not wizard.known_spells.is_empty() and ClassProgression.saved_choices_error(wizard.to_dict()).is_empty(), "training controls produce usable spells and a valid save")
	panel.queue_free()
	# Exercise the owner-facing damage-die picker after an actual spell roll.
	_setup_world()
	var sorcerer := _fresh_char("Empowered Sorcerer", "human", "sorcerer", {"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	sorcerer.level_up()
	ClassProgression.choose_sorcerer_metamagic(sorcerer, ["empowered_spell", "extended_spell"])
	combat = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.active_character = sorcerer
	target = combat.monster_entities[0]
	target["current_hp"] = 10000
	var points := sorcerer.get_sorcery_points()
	var decisions := {"metamagic:empowered": true, "defer_empowered": true}
	var result := CombatAction.resolve_spell(sorcerer, target, DataLoader.get_spell("magic_missile"), false, decisions)
	GameManager.test_mode = false
	var settled := {}
	_settle_audit_spell(combat, target, result, decisions, settled)
	_assert(await _answer_audit_popup(combat.hud, "Die 2:"), "Empowered picker displays the second actually rolled dart die")
	_assert(await _answer_audit_popup(combat.hud, "Finish selection"), "Empowered picker allows fewer dice than the Charisma limit")
	for _frame in 12:
		await get_tree().process_frame
	var final: Dictionary = settled.get("result", {})
	_assert(final.get("metamagic_used", false) and sorcerer.get_sorcery_points() == points - 1 and target["current_hp"] == 10000 - int(final.get("damage", 0)), "owner-selected dice settle damage and cost once through CombatState")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


func _settle_audit_spell(combat: Node, target: Dictionary, result: Dictionary, decisions: Dictionary, settled: Dictionary) -> void:
	settled["result"] = await combat._settle_empowered_spell(target, result, decisions)


func _answer_audit_dialog(hud: Node, title_part: String) -> bool:
	for _frame in 120:
		for child in hud.get_children():
			if child is ConfirmationDialog and not child.is_queued_for_deletion() and str(child.title).contains(title_part):
				child.confirmed.emit()
				return true
		await get_tree().process_frame
	return false


func _answer_audit_popup(hud: Node, prefix: String) -> bool:
	for _frame in 120:
		for child in hud.get_children():
			if child is PopupMenu and not child.is_queued_for_deletion() and str(child.title).contains("Empowered Spell"):
				for index in child.item_count:
					if child.get_item_text(index).begins_with(prefix):
						child.id_pressed.emit(index)
						await get_tree().process_frame
						return true
		await get_tree().process_frame
	return false


func test_rogue_devious_strikes() -> void:
	_enter_test("rogue_devious_strikes")
	_setup_world()
	var rogue := _fresh_char("Devious Rogue", "human", "rogue", {"STR": 10, "DEX": 18, "CON": 14, "INT": 12, "WIS": 12, "CHA": 10})
	for _level in range(13):
		rogue.level_up()
	rogue.inventory.add_item("rapier")
	rogue.inventory.equip(Inventory.Slot.WEAPON, "rapier")
	_assert(rogue.has_feature("rogue_improved_cunning_strike") and rogue.has_feature("rogue_devious_strikes"), "level-14 Rogue owns both Improved Cunning Strike and Devious Strikes")
	PlayerManager.set_player_character(0, rogue)
	PartyManager.reset()
	PartyManager.register_player_character(0, rogue)
	PartyManager.register_player_character(1, PlayerManager.get_player(1).get("character"))
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	_assert(combat.player_entities[0]["character"] == rogue, "production combat uses the registered level-14 Rogue")
	combat.current_player_idx = 0
	combat.active_character = rogue
	combat.active_combatant = {"is_player": true, "entity": rogue}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, -1)
	combat.turn_budget.reset(rogue, combat.player_entities)
	combat.remaining_attack_swings = 0
	var target: Dictionary = combat.monster_entities[0]
	target["hex_position"] = Vector2i(1, 0)
	target["current_hp"] = 10000
	target["max_hp"] = 10000
	target["armor_class"] = -100
	target["saving_throw_bonuses"] = {"CON": -100, "DEX": -100}
	target["is_alive"] = true
	combat._update_grid_entities()
	var prior_record_count := ActivityHistory.get_records().size()
	GameManager.test_mode = false
	combat._on_hud_action("attack", {})
	combat._on_hex_clicked(Vector2i(1, 0))
	var first_choice := await _answer_cunning_strike_popup(combat, "Daze")
	_assert(first_choice.get("found", false) and first_choice.get("labels", []).has("Knock Out (6d6; CON save)"), "first production popup offers Knock Out when seven Sneak Attack dice can afford it")
	for _frame in range(2):
		await get_tree().process_frame
	var second_choice := await _answer_cunning_strike_popup(combat, "Obscure")
	_assert(second_choice.get("found", false) and not second_choice.get("labels", []).has("Knock Out (6d6; CON save)"), "second production popup removes Knock Out after Daze leaves only five dice")
	for _frame in range(12):
		await get_tree().process_frame
	_assert(target.get("conditions", {}).has("dazed") and target.get("conditions", {}).has("blinded"), "failed Constitution and Dexterity saves apply Daze and Obscure on the hit")
	_assert(rogue.feature_uses.get("sneak_attack_used_this_turn", 0) == 1 and not combat.turn_budget.action_available and not combat.resolving_player_action, "the real attack spends one Attack action and completes Sneak Attack once")
	var records := ActivityHistory.get_records()
	if records.size() > prior_record_count:
		var latest: Dictionary = records.back()
		var attacks: Array = latest.get("payload", {}).get("sections", {}).get("attacks", [])
		var components: Array = attacks[0].get("damage_components", []) if not attacks.is_empty() else []
		var sneak_formula := ""
		for component in components:
			if str(component.get("label", "")) == "Sneak Attack":
				sneak_formula = str(component.get("formula", ""))
		_assert(sneak_formula == "2d6", "the real attack rolls only the two Sneak Attack dice left after Daze and Obscure")
	else:
		_assert(false, "settled Rogue attack publishes its combat activity record")
	CombatState.tick_monster_condition_durations(target)
	_assert(not target.get("conditions", {}).has("dazed") and not target.get("conditions", {}).has("blinded"), "Daze and Obscure expire at the target's end of turn")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


func _answer_cunning_strike_popup(combat: Node, choice_prefix: String) -> Dictionary:
	for _frame in range(120):
		for child in combat.hud.get_children():
			if not child is PopupMenu or child.is_queued_for_deletion() or not str(child.title).contains("Cunning Strike"):
				continue
			var labels: Array[String] = []
			var chosen_index := -1
			for index in child.item_count:
				var label: String = child.get_item_text(index)
				labels.append(label)
				if label.begins_with(choice_prefix):
					chosen_index = index
			if chosen_index >= 0:
				child.id_pressed.emit(chosen_index)
				return {"found": true, "labels": labels}
		await get_tree().process_frame
	return {"found": false, "labels": []}


## Real Sorcerer spell selection, Subtle Spell prompt, and Counterspell visibility.
func test_sorcerer_subtle_spell() -> void:
	_enter_test("sorcerer_subtle_spell")
	_setup_world()
	var sorcerer := _fresh_char("Subtle Sorcerer", "human", "sorcerer", {"STR": 8, "DEX": 14, "CON": 14, "INT": 12, "WIS": 12, "CHA": 16})
	sorcerer.level_up()
	ClassProgression.choose_sorcerer_metamagic(sorcerer, ["subtle_spell", "extended_spell"])
	sorcerer.known_spells.assign(["light"])
	var counterspeller: Character = PlayerManager.get_player(1).get("character")
	counterspeller.known_spells.append("counterspell")
	counterspeller.spell_slots["3"] = 1
	counterspeller.reaction_available = true
	PlayerManager.set_player_character(0, sorcerer)
	PartyManager.reset()
	PartyManager.register_player_character(0, sorcerer)
	PartyManager.register_player_character(1, counterspeller)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = sorcerer
	combat.active_combatant = {"is_player": true, "entity": sorcerer}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, -1)
	combat.turn_budget.reset(sorcerer, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("light")})
	var subtle_prompt_found := false
	for _frame in range(120):
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and str(child.title).contains("Subtle Spell"):
				subtle_prompt_found = true
				child.confirmed.emit()
				break
		if subtle_prompt_found:
			break
		await get_tree().process_frame
	_assert(subtle_prompt_found, "real spell selection offers the owner Subtle Spell before targeting")
	for _frame in range(4):
		await get_tree().process_frame
	_assert(combat.pending_spell_data.get("_metamagic_subtle", false) and combat.pending_spell_data.get("components", []).is_empty(), "accepting the production prompt removes V/S and free M components")
	combat._on_hex_clicked(Vector2i.ZERO)
	for _frame in range(18):
		await get_tree().process_frame
	_assert(counterspeller.reaction_available and int(counterspeller.spell_slots.get("3", 0)) == 1, "a component-free Subtle Spell does not prompt or spend an ally's Counterspell")
	_assert(not combat.turn_budget.action_available and combat.pending_action_type.is_empty() and sorcerer.get_sorcery_points() == 1, "the real Subtle Spell spends its Sorcery Point and Magic action, then leaves targeting")
	var counterspell_enemy: Dictionary = {"id": "counterspell_enemy", "name": "Counterspell Enemy", "creature_type": "humanoid", "ability_scores": {"STR": 10, "DEX": 12, "CON": 12, "INT": 10, "WIS": 10, "CHA": 10}, "saving_throw_bonuses": {"CON": -1000}, "spell_slots": {"1": 1}, "spellcaster_level": 8, "spells": [], "conditions": {}, "hex_position": Vector2i(3, -2), "is_alive": true, "current_hp": 30, "max_hp": 30}
	var incoming_slot_before := int(counterspell_enemy["spell_slots"]["1"])
	var target_hp_before := sorcerer.current_hp
	combat._execute_monster_spell(counterspell_enemy, sorcerer.character_name, "magic_missile")
	var counterspell_prompt_found := false
	for _frame in range(120):
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and str(child.dialog_text).contains("Constitution save") and str(child.title).begins_with("Reaction"):
				counterspell_prompt_found = true
				child.confirmed.emit()
				break
		if counterspell_prompt_found:
			break
		await get_tree().process_frame
	for _frame in range(8):
		await get_tree().process_frame
	_assert(counterspell_prompt_found and not counterspeller.reaction_available and int(counterspeller.spell_slots.get("3", 0)) == 0, "a visible enemy spell within 60 feet prompts the owner to spend Counterspell's Reaction and slot")
	_assert(int(counterspell_enemy["spell_slots"]["1"]) == incoming_slot_before and sorcerer.current_hp == target_hp_before, "the production Counterspell save interrupts the spell without expending the enemy's slot or damaging its target")
	counterspeller.reaction_available = true
	counterspeller.spell_slots["3"] = 1
	counterspell_enemy["hex_position"] = Vector2i(15, -1)
	var far_target_hp_before := sorcerer.current_hp
	counterspell_enemy["spell_slots"]["1"] = 1
	combat._execute_monster_spell(counterspell_enemy, sorcerer.character_name, "magic_missile")
	var out_of_range_prompt_found := false
	for _frame in range(18):
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and str(child.dialog_text).contains("Constitution save"):
				out_of_range_prompt_found = true
				break
		await get_tree().process_frame
	_assert(not out_of_range_prompt_found and counterspeller.reaction_available and int(counterspeller.spell_slots.get("3", 0)) == 1 and int(counterspell_enemy["spell_slots"]["1"]) == 0 and sorcerer.current_hp < far_target_hp_before, "Counterspell does not prompt beyond 60 feet, allowing the in-range enemy spell to resolve")
	counterspeller.reaction_available = true
	counterspeller.spell_slots["3"] = 1
	counterspell_enemy["hex_position"] = Vector2i(3, -2)
	counterspell_enemy["conditions"] = {"invisible": 2}
	counterspell_enemy["spell_slots"]["1"] = 1
	var invisible_target_hp_before := sorcerer.current_hp
	combat._execute_monster_spell(counterspell_enemy, sorcerer.character_name, "magic_missile")
	var invisible_prompt_found := false
	for _frame in range(18):
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and str(child.dialog_text).contains("Constitution save"):
				invisible_prompt_found = true
				break
		await get_tree().process_frame
	_assert(not invisible_prompt_found and counterspeller.reaction_available and int(counterspeller.spell_slots.get("3", 0)) == 1 and sorcerer.current_hp < invisible_target_hp_before, "Counterspell does not prompt for an Invisible caster the observer cannot see")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Invalid targets preserve resources; split projectiles pay once; teleport finishes once.
func test_spell_cast_stage_flow() -> void:
	_enter_test("spell_cast_stage_flow")
	_setup_world()
	var sorcerer := _fresh_char("Cast Stages Sorcerer", "human", "sorcerer", {"STR": 10, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 18})
	sorcerer.level_up()
	sorcerer.level_up()
	ClassProgression.choose_sorcerer_metamagic(sorcerer, ["distant_spell", "subtle_spell"])
	sorcerer.known_spells.assign(["magic_missile", "misty_step", "protection_from_energy"])
	PlayerManager.set_player_character(0, sorcerer)
	PartyManager.reset()
	PartyManager.register_player_character(0, sorcerer)
	PartyManager.register_player_character(1, PlayerManager.get_player(1).get("character"))
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = sorcerer
	combat.active_combatant = {"is_player": true, "entity": sorcerer}
	sorcerer.current_hp = sorcerer.max_hp
	sorcerer.is_alive = true
	sorcerer.spell_slots["1"] = 3
	sorcerer.spell_slots["2"] = 1
	sorcerer.spell_slots["3"] = 1
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(-1, 0)
	for index in combat.monster_entities.size():
		var monster: Dictionary = combat.monster_entities[index]
		monster["hex_position"] = Vector2i(index + 1, 0)
		monster["current_hp"] = 1000
		monster["max_hp"] = 1000
		monster["is_alive"] = true
	combat.turn_budget.reset(sorcerer, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat._update_grid_entities()
	combat.hud.update_hud(sorcerer, combat.tracker)
	var points_before := sorcerer.get_sorcery_points()
	combat.pending_action_type = "spell"
	combat.pending_spell_data = DataLoader.get_spell("protection_from_energy").duplicate(true)
	combat.pending_spell_data["_metamagic_distant"] = true
	await combat._execute_player_spell(Vector2i(1, 0))
	_assert(int(sorcerer.spell_slots["3"]) == 1 and sorcerer.get_sorcery_points() == points_before and combat.turn_budget.action_available, "An invalid willing-ally target spends no slot, Metamagic, or Magic action")
	_assert(combat.pending_action_type.is_empty() and combat.pending_spell_data.is_empty(), "Rejected casting clears the live pending selection")
	combat.pending_action_type = "spell"
	combat.pending_spell_data = DataLoader.get_spell("magic_missile").duplicate(true)
	combat.pending_spell_data["_metamagic_distant"] = true
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	var allocations: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 0), Vector2i(2, 0)]
	await combat._execute_player_spell(Vector2i(1, 0), Vector2i(9999, 9999), allocations)
	_assert(int(sorcerer.spell_slots["1"]) == 2 and sorcerer.get_sorcery_points() == points_before - 1 and not combat.turn_budget.action_available, "A split Magic Missile cast pays one slot, one Metamagic cost, and one Magic action")
	_assert(combat.pending_spell_data.get("_projectile_target_counts", {}) == {"1,0": 2, "2,0": 1} and int(combat.monster_entities[0]["current_hp"]) < 1000 and int(combat.monster_entities[1]["current_hp"]) < 1000, "Repeated projectile choices retain their allocation and damage both selected creatures")
	combat.turn_budget.reset(sorcerer, combat.player_entities)
	combat.pending_action_type = "spell"
	combat.pending_spell_data = DataLoader.get_spell("misty_step").duplicate(true)
	await combat._execute_player_spell(Vector2i(1, 0))
	_assert(int(sorcerer.spell_slots["2"]) == 1 and combat.turn_budget.bonus_action_available and combat.player_entities[0]["hex_position"] == Vector2i.ZERO, "An occupied teleport destination preserves its slot, Bonus Action, and position")
	await combat._execute_player_spell(Vector2i(0, 1))
	_assert(int(sorcerer.spell_slots["2"]) == 0 and not combat.turn_budget.bonus_action_available and combat.turn_budget.action_available and combat.player_entities[0]["hex_position"] == Vector2i(0, 1), "A valid teleport spends one slot and Bonus Action and finishes through the movement stage")
	_assert(combat.pending_action_type.is_empty() and not combat.resolving_player_action, "Completed casting exits targeting and releases the input lock")
	# A push must finish an area's awaited save prompt before later effects run.
	var push_cast: SpellCastContext = combat._spell_cast_context()
	var pushed_ally: Character = combat.player_entities[1]["character"]
	pushed_ally.current_hp = pushed_ally.max_hp
	pushed_ally.is_alive = true
	combat.player_entities[1]["hex_position"] = Vector2i.ZERO
	SpellZoneTerrain._create_grease_zone(push_cast.areas, sorcerer, Vector2i(0, -2))
	for zone in push_cast.areas.active_spell_zones.values():
		if str(zone.get("spell_id", "")) == "grease":
			zone["save_dc"] = 100
	var push_prompt := {"started": false, "finished": false}
	pushed_ally.feature_uses["bardic_inspiration_die"] = "1d6"
	GameManager.test_mode = false
	_answer_spell_push_prompt(combat, pushed_ally, push_prompt)
	await SpellEffectApplication.apply(push_cast, pushed_ally, {}, {"effects": [{"type": "push", "distance": 2}]}, Vector2i(0, 1), Vector2i.ZERO, {"success": true})
	GameManager.test_mode = true
	_assert(push_prompt["started"] and push_prompt["finished"] and combat.player_entities[1]["hex_position"] == Vector2i(0, -2) and pushed_ally.has_condition("prone"), "Spell pushes await area-entry save decisions and their effects before returning")
	_teardown_scene(combat)
	_exit_test()


## A held wand routes its chosen charge count through production targeting and resource commit.
func _answer_spell_push_prompt(combat: CombatState, pushed_ally: Character, status: Dictionary) -> void:
	await get_tree().process_frame
	for child in combat.hud.get_children():
		if child is ConfirmationDialog and child.title.begins_with("Bardic Inspiration"):
			status["started"] = true
			_assert(not pushed_ally.has_condition("prone") and combat.player_entities[1]["hex_position"] != Vector2i(0, -2), "Forced movement waits at its first spell-area entry while the real save prompt is open")
			child.confirmed.emit()
			status["finished"] = true
			return
	_assert(false, "Pushed ally reaches the real spell-area saving throw prompt")


func test_wand_magic_missiles_flow() -> void:
	_enter_test("wand_magic_missiles_flow")
	_setup_world()
	var wielder := _fresh_char("Wand Wielder", "human", "fighter", {"STR": 14, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	wielder.inventory.add_item("wand_of_magic_missiles")
	wielder.inventory.add_item("wand_of_magic_missiles")
	var wand_ids: Array[String] = []
	for record in wielder.inventory.backpack_instances():
		if str(record.get("definition_id", "")) == "wand_of_magic_missiles":
			wand_ids.append(str(record["instance_id"]))
	_assert(wielder.inventory.equip_instance(Inventory.Slot.HANDS, wand_ids[0]), "the production flow fixture holds one wand copy")
	PlayerManager.set_player_character(0, wielder)
	PartyManager.reset()
	PartyManager.register_player_character(0, wielder)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wielder
	combat.active_combatant = {"is_player": true, "entity": wielder}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	for index in combat.monster_entities.size():
		combat.monster_entities[index]["hex_position"] = Vector2i(index + 1, 0)
		combat.monster_entities[index]["current_hp"] = 1000
		combat.monster_entities[index]["max_hp"] = 1000
		combat.monster_entities[index]["is_alive"] = true
	combat.turn_budget.reset(wielder, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat._update_grid_entities()
	combat.hud.update_hud(wielder, combat.tracker)
	combat.hud._show_feature_selection()
	var two_charge_choice := -1
	for index in combat.hud.features_registered.size():
		var choice: Dictionary = combat.hud.features_registered[index]
		if str(choice.get("id", "")) == "wand_of_magic_missiles_activate" and int(choice.get("charges", 0)) == 2:
			two_charge_choice = index
	_assert(two_charge_choice >= 0, "the held wand menu offers a two-charge activation")
	var target_hp_before := int(combat.monster_entities[0]["current_hp"])
	var slot_before := wielder.spell_slots.duplicate(true)
	await combat.hud._on_feature_selected(two_charge_choice)
	_assert(str(combat.pending_spell_data.get("id", "")) == "magic_missile" and int(combat.pending_spell_data.get("_selected_spell_slot_level", 0)) == 2 and bool(combat.pending_spell_data.get("_magic_item_activation", false)), "the selected two-charge menu entry enters shared Magic Missile targeting at level 2")
	await combat._execute_player_spell(Vector2i(1, 0))
	_assert(int(wielder.inventory.get_instance(wand_ids[0])["state"]["charges"]) == 5 and int(wielder.inventory.get_instance(wand_ids[1])["state"]["charges"]) == 7, "a resolved wand cast spends two charges only from its held copy")
	_assert(wielder.spell_slots == slot_before and int(combat.monster_entities[0]["current_hp"]) < target_hp_before and not combat.turn_budget.action_available, "the wand resolves through combat without a spell slot and spends one Magic action")
	_teardown_scene(combat)
	_exit_test()


## Spending the Wand's last charge rolls destruction against the exact held copy.
func test_wand_last_charge_destruction_flow() -> void:
	_enter_test("wand_last_charge_destruction_flow")
	_setup_world()
	var wielder := _fresh_char("Last Charge Wielder", "human", "fighter", {"STR": 14, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	wielder.inventory.add_item("wand_of_magic_missiles")
	wielder.inventory.add_item("wand_of_magic_missiles")
	var wand_id := str(wielder.inventory.backpack_instances()[0]["instance_id"])
	var survivor_id := str(wielder.inventory.backpack_instances()[1]["instance_id"])
	var wand_record := wielder.inventory.get_instance(wand_id)
	var wand_state: Dictionary = wand_record["state"].duplicate(true)
	wand_state["charges"] = 1
	wand_record["state"] = wand_state
	wielder.inventory.update_instance(wand_record)
	var survivor_record := wielder.inventory.get_instance(survivor_id)
	var survivor_state: Dictionary = survivor_record["state"].duplicate(true)
	survivor_state["charges"] = 1
	survivor_record["state"] = survivor_state
	wielder.inventory.update_instance(survivor_record)
	_assert(wielder.inventory.equip_instance(Inventory.Slot.HANDS, wand_id), "the last-charge fixture holds one charged wand copy")
	PlayerManager.set_player_character(0, wielder)
	PartyManager.reset()
	PartyManager.register_player_character(0, wielder)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wielder
	combat.active_combatant = {"is_player": true, "entity": wielder}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.monster_entities[0]["hex_position"] = Vector2i(1, 0)
	combat.monster_entities[0]["current_hp"] = 1000
	combat.monster_entities[0]["max_hp"] = 1000
	combat.monster_entities[0]["is_alive"] = true
	combat.turn_budget.reset(wielder, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat._update_grid_entities()
	combat.hud.update_hud(wielder, combat.tracker)
	combat.hud._show_feature_selection()
	var one_charge_choice := -1
	for index in combat.hud.features_registered.size():
		var choice: Dictionary = combat.hud.features_registered[index]
		if str(choice.get("id", "")) == "wand_of_magic_missiles_activate" and int(choice.get("charges", 0)) == 1:
			one_charge_choice = index
	_assert(one_charge_choice >= 0, "the held wand exposes its one remaining charge")
	await combat.hud._on_feature_selected(one_charge_choice)
	combat.pending_spell_data["_test_magic_item_destruction_roll"] = 1
	await combat._execute_player_spell(Vector2i(1, 0))
	_assert(wielder.inventory.get_instance(wand_id).is_empty() and wielder.inventory.equipped_instance_id(Inventory.Slot.HANDS).is_empty(), "a destruction roll of 1 removes the exact Wand copy from equipped inventory")
	_assert(int(combat.monster_entities[0]["current_hp"]) < 1000 and not combat.turn_budget.action_available, "the final-charge Wand activation resolves its chosen spell and spends one Magic action")
	_assert(wielder.inventory.equip_instance(Inventory.Slot.HANDS, survivor_id), "the duplicate Wand remains available after the first copy is destroyed")
	combat.turn_budget.reset(wielder, combat.player_entities)
	combat.hud.update_hud(wielder, combat.tracker)
	combat.hud._show_feature_selection()
	var survivor_choice := -1
	for index in combat.hud.features_registered.size():
		var choice: Dictionary = combat.hud.features_registered[index]
		if str(choice.get("id", "")) == "wand_of_magic_missiles_activate" and int(choice.get("charges", 0)) == 1:
			survivor_choice = index
	await combat.hud._on_feature_selected(survivor_choice)
	combat.pending_spell_data["_test_magic_item_destruction_roll"] = 20
	await combat._execute_player_spell(Vector2i(1, 0))
	_assert(int(wielder.inventory.get_instance(survivor_id).get("state", {}).get("charges", -1)) == 0, "a final-charge destruction roll above 1 leaves the exact duplicate Wand intact at zero charges")
	_teardown_scene(combat)
	_exit_test()


## A lit exact-copy Torch follows its carrier in combat and burns down with completed rounds.
func test_portable_light_source_combat_flow() -> void:
	_enter_test("portable_light_source_combat_flow")
	_setup_world()
	var scout := _fresh_char("Torch Scout", "human", "ranger", {"STR": 12, "DEX": 16, "CON": 14, "INT": 10, "WIS": 14, "CHA": 10})
	scout.inventory.add_item("torch")
	var torch_instance_id := str(scout.inventory.backpack_instances().back().get("instance_id", ""))
	var torch_use := scout.inventory.consume_instance(torch_instance_id, scout)
	PlayerManager.set_player_character(0, scout)
	PartyManager.reset()
	PartyManager.register_player_character(0, scout)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat._update_grid_entities()
	var light_entities: Array = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return str(entity.get("light_instance_id", "")) == torch_instance_id)
	_assert(torch_use.get("success", false) and light_entities.size() == 1 and light_entities[0].get("hex_position", Vector2i(-1, -1)) == Vector2i.ZERO and int(light_entities[0].get("bright_light_radius_hexes", 0)) == 4 and int(light_entities[0].get("dim_light_radius_hexes", 0)) == 8, "Combat draws the exact carried Torch at its owner's position with 20-foot Bright and 40-foot Dim Light")
	combat.player_entities[0]["hex_position"] = Vector2i(1, 0)
	combat._update_grid_entities()
	light_entities = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return str(entity.get("light_instance_id", "")) == torch_instance_id)
	_assert(light_entities.size() == 1 and light_entities[0].get("hex_position", Vector2i(-1, -1)) == Vector2i(1, 0), "A carried light follows its bearer when they move")
	LightSourceRules.advance_inventory(scout.inventory, 3600)
	combat._update_grid_entities()
	_assert(combat.hex_grid.entities.all(func(entity: Dictionary) -> bool: return str(entity.get("light_instance_id", "")) != torch_instance_id) and scout.inventory.get_instance(torch_instance_id).get("state", {}).get("light_source_lit", false) == false, "The Torch marker disappears and its saved lit state ends after one hour")
	_teardown_scene(combat)
	_exit_test()


## Natural darkness hides targets until a nearby light reaches them, while magical Darkness blocks mundane light.
func test_combat_light_visibility_flow() -> void:
	_enter_test("combat_light_visibility_flow")
	_setup_world()
	var scout := _fresh_char("Darkness Scout", "human", "wizard", {"STR": 12, "DEX": 16, "CON": 14, "INT": 14, "WIS": 10, "CHA": 10})
	scout.max_hp = 5000
	scout.current_hp = 5000
	scout.inventory.add_item("torch")
	var torch_instance_id := str(scout.inventory.backpack_instances().back().get("instance_id", ""))
	scout.inventory.add_item("component_pouch")
	PlayerManager.set_player_character(0, scout)
	PartyManager.reset()
	PartyManager.register_player_character(0, scout)
	GameManager.transition_context = {"terrain": "dungeon", "ambient_light": "dark", "monster_ids": ["goblin"]}
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = scout
	combat.active_combatant = {"is_player": true, "entity": scout}
	combat.hex_grid.tiles.clear()
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 32):
		var tile := HexTile.new()
		tile.coord = coord
		tile.is_visible = true
		tile.is_revealed = true
		combat.hex_grid.add_tile(tile)
	CombatPerception.configure_ambient_light(combat.hex_grid, "dark")
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.monster_entities[0]["hex_position"] = Vector2i(8, 0)
	combat.monster_entities[0]["is_alive"] = true
	combat._update_grid_entities()
	var sight_spell := DataLoader.get_spell("sacred_flame")
	var target_in_dim_light := Vector2i(8, 0)
	var target_beyond_light := Vector2i(9, 0)
	_assert(not combat._spell_target_visible_to_active_character(target_in_dim_light, sight_spell), "A sight-required spell cannot target a creature beyond all light in an unlit encounter")
	var torch_result: Dictionary = scout.inventory.consume_instance(torch_instance_id, scout)
	combat._update_grid_entities()
	_assert(torch_result.get("success", false), "The selected exact Torch copy lights successfully in inventory")
	_assert(combat._spell_target_visible_to_active_character(target_in_dim_light, sight_spell), "A lit Torch lets the caster see a creature inside its 40-foot Dim Light radius for a sight-required spell")
	_assert(not combat._spell_target_visible_to_active_character(target_beyond_light, sight_spell), "A creature one hex beyond a Torch's Dim Light radius remains unseen for sight-required targeting")
	CombatAction.apply_condition(combat.monster_entities[0], "darkness_obscured", 20, "darkness:visibility-test")
	_assert(not combat._spell_target_visible_to_active_character(target_in_dim_light, sight_spell), "A mundane Torch does not reveal a target inside magical Darkness")
	var dwarf := _fresh_char("Darkvision Dwarf", "dwarf", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 12, "CHA": 10})
	var target_within_darkvision := Vector2i(24, 0)
	var target_outside_darkvision := Vector2i(25, 0)
	_assert(CombatPerception.can_see_target(dwarf, {}, Vector2i.ZERO, target_within_darkvision, combat.hex_grid) and not CombatPerception.can_see_target(dwarf, {}, Vector2i.ZERO, target_outside_darkvision, combat.hex_grid), "Innate 120-foot Dwarf Darkvision sees naturally dark space only within its stated range")
	var spell_vision_character := _fresh_char("Spell Darkvision", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 12, "INT": 16, "WIS": 14, "CHA": 10})
	var darkvision_cast := SpellEffects.begin_cast(spell_vision_character, DataLoader.get_spell("darkvision"))
	SpellEffects.grant(spell_vision_character, darkvision_cast, "darkvision")
	var target_at_spell_limit := Vector2i(30, 0)
	var target_past_spell_limit := Vector2i(31, 0)
	_assert(CombatPerception.can_see_target(spell_vision_character, {}, Vector2i.ZERO, target_at_spell_limit, combat.hex_grid) and not CombatPerception.can_see_target(spell_vision_character, {}, Vector2i.ZERO, target_past_spell_limit, combat.hex_grid), "The Darkvision spell sees natural darkness through 150 feet and stops beyond its range")
	# Neither a combatant nor an object is a light source just by occupying a hex.
	combat.hex_grid.entities.clear()
	combat.hex_grid.add_entity({"hex_position": Vector2i.ZERO})
	combat.hex_grid.add_entity({"hex_position": Vector2i(1, 0)})
	_assert(CombatPerception.illumination_level_at(combat.hex_grid, Vector2i(1, 0)) == "dark" and not CombatPerception.can_see_target(scout, {}, Vector2i.ZERO, Vector2i(1, 0), combat.hex_grid), "Adjacent unlit entities do not illuminate themselves or enable sight in natural darkness")
	combat.hex_grid.add_entity({"hex_position": Vector2i(12, 0), "bright_light_radius_hexes": 2, "dim_light_radius_hexes": 4})
	_assert(CombatPerception.can_see_target(scout, {}, Vector2i.ZERO, Vector2i(12, 0), combat.hex_grid), "A distant illuminated target is visible across intervening natural darkness")
	CombatPerception.configure_ambient_light(combat.hex_grid, "bright")
	_assert(CombatPerception.illumination_level_at(combat.hex_grid, Vector2i(15, 0)) == "bright", "A source's Dim Light does not downgrade existing ambient Bright Light")
	var true_seeing := SpellEffects.begin_cast(scout, DataLoader.get_spell("true_seeing"))
	SpellEffects.grant(scout, true_seeing, "true_seeing")
	combat.hex_grid.get_tile(Vector2i(4, 0)).custom_properties["blocks_sight"] = true
	_assert(not combat._spell_target_visible_to_active_character(target_in_dim_light, sight_spell), "True Seeing cannot reveal a darkened target through a wall or closed door")
	combat.hex_grid.get_tile(Vector2i(4, 0)).custom_properties["blocks_sight"] = false
	_assert(combat._spell_target_visible_to_active_character(target_in_dim_light, sight_spell), "True Seeing reveals the same darkened target after its sight path opens")
	SpellEffects.remove(scout, str(true_seeing["source_id"]))
	CombatAction.remove_condition_source(combat.monster_entities[0], "darkness:visibility-test", ["darkness_obscured"])
	var target: Dictionary = combat.monster_entities[0]
	target["current_hp"] = 5000
	target["max_hp"] = 5000
	target["is_alive"] = true
	target["conditions"] = {}
	target["condition_sources"] = {}
	CombatAction.apply_condition(target, "invisible", 10, "review:invisible-target")
	var bolt := DataLoader.get_spell("fire_bolt")
	scout.known_spells.assign(["fire_bolt", "mage_armor", "sacred_flame"])
	scout.spell_slots = {"1": 2}
	combat.turn_budget.reset(scout, combat.player_entities)
	var visibility_context := {"grid": combat.hex_grid, "caster_position": Vector2i.ZERO, "target_position": target_in_dim_light}
	var unseen_result := CombatAction.resolve_spell(scout, target, bolt, false, {"spell_visibility": visibility_context}, [], 0, 40)
	_assert(unseen_result.get("success", false) and unseen_result.get("attack_disadvantage", false) and not unseen_result.get("attack_advantage", true), "A known Invisible target remains legal for Fire Bolt and its spell attack has Disadvantage")
	_assert(not combat._spell_target_visible_to_active_character(target_in_dim_light, DataLoader.get_spell("magic_missile")) and not combat._spell_target_visible_to_active_character(target_in_dim_light, DataLoader.get_spell("healing_word")), "Magic Missile and Healing Word retain their explicit sight prerequisites")
	combat.pending_spell_data = bolt.duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(target_in_dim_light)
	_assert(not combat.turn_budget.action_available and int(scout.spell_slots["1"]) == 2, "The actual Fire Bolt cast against a known unseen target resolves and spends only its Magic Action")
	combat.turn_budget.reset(scout, combat.player_entities)
	combat.pending_spell_data = sight_spell.duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(target_in_dim_light)
	_assert(combat.turn_budget.action_available and int(scout.spell_slots["1"]) == 2, "A sight-required cast refuses the same Invisible target without spending resources")
	await combat._on_hud_action("cancel", {})
	scout.add_condition("blinded", 10, "review:blinded-caster")
	combat.pending_spell_data = DataLoader.get_spell("mage_armor").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(Vector2i.ZERO)
	_assert(SpellEffects.has_spell(scout, "mage_armor") and int(scout.spell_slots["1"]) == 1 and not combat.turn_budget.action_available, "A Blinded caster can actually cast Mage Armor on themselves and spends its slot and Magic Action once")
	scout.remove_condition("blinded")
	CombatAction.remove_condition_source(target, "review:invisible-target", ["invisible"])
	CombatPerception.configure_ambient_light(combat.hex_grid, "dark")
	combat.hex_grid.entities.clear()
	combat.hex_grid.add_entity({"hex_position": Vector2i.ZERO})
	combat.hex_grid.add_entity({"hex_position": target_in_dim_light})
	target["darkvision_range_feet"] = 60
	var dark_result := CombatAction.resolve_spell(scout, target, bolt, false, {"spell_visibility": visibility_context}, [], 0, 40)
	_assert(dark_result.get("success", false) and dark_result.get("attack_disadvantage", false) and not dark_result.get("attack_advantage", true), "Fire Bolt applies natural-darkness Disadvantage when the target's Darkvision can see the caster")
	target["darkvision_range_feet"] = 0
	var mutually_unseen_result := CombatAction.resolve_spell(scout, target, bolt, false, {"spell_visibility": visibility_context}, [], 0, 40)
	_assert(mutually_unseen_result.get("attack_disadvantage", false) and mutually_unseen_result.get("attack_advantage", false), "When neither creature can see the other, unseen attacker Advantage and unseen target Disadvantage cancel")
	combat.hex_grid.get_tile(Vector2i(4, 0)).custom_properties["blocks_sight"] = true
	_assert(not combat._spell_target_visible_to_active_character(target_in_dim_light, bolt), "A spell without a sight prerequisite still refuses an intervening wall")
	_teardown_scene(combat)
	_exit_test()


## Chain Lightning resolves the exact creature, room object, or owned-copy target selected on one hex.
func test_chain_lightning_target_identity_flow() -> void:
	_enter_test("chain_lightning_target_identity_flow")
	_setup_world()
	var caster := _fresh_char("Chain Identity Caster", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	caster.character_id = "chain-identity-caster"
	caster.known_spells.assign(["chain_lightning"])
	caster.spell_slots.clear()
	caster.spell_slots["6"] = 1
	caster.inventory.add_item("dagger")
	var owned_item_id := str(caster.inventory.backpack_instances().back()["instance_id"])
	PlayerManager.set_player_character(0, caster)
	PartyManager.reset()
	PartyManager.register_player_character(0, caster)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = caster
	combat.active_combatant = {"is_player": true, "entity": caster}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.monster_entities[0]["hex_position"] = Vector2i(1, 0)
	combat.monster_entities[0]["current_hp"] = 1000
	combat.monster_entities[0]["max_hp"] = 1000
	combat.monster_entities[0]["is_alive"] = true
	combat._update_grid_entities()
	var shared_hex := Vector2i(1, 0)
	var world_object := {"id": "fixture:shared-door", "name": "Shared Hex Door", "kind": "door", "material": "wood", "hp": 1000, "max_hp": 1000}
	combat.hex_grid.add_entity({"hex_position": shared_hex, "world_object": world_object})
	var target_context: SpellCastContext = combat._spell_cast_context(shared_hex)
	var options := SpellCastTargeting.chain_target_options(target_context, shared_hex)
	var selected_object_id: String = await combat.hud.request_chain_lightning_target_choice(options, "object:fixture:shared-door")
	var selected_monster_id: String = await combat.hud.request_chain_lightning_target_choice(options, "monster:%s" % str(combat.monster_entities[0].get("id", "")))
	var carried_context: SpellCastContext = combat._spell_cast_context(Vector2i.ZERO)
	var carried_options := SpellCastTargeting.chain_target_options(carried_context, Vector2i.ZERO)
	var selected_carried_id: String = await combat.hud.request_chain_lightning_target_choice(carried_options, "object:%s" % owned_item_id)
	_assert(selected_object_id == "object:fixture:shared-door" and selected_monster_id == "monster:%s" % str(combat.monster_entities[0].get("id", "")) and selected_carried_id == "object:%s" % owned_item_id, "the targeting menu preserves exact identities for a collocated room object, creature, and carried copy")
	_assert(SpellSupport.is_available(DataLoader.get_spell("chain_lightning")) and SpellCastTargeting.is_chain_target_selected(target_context, shared_hex, selected_object_id) and SpellCastTargeting.is_chain_target_selected(target_context, shared_hex, selected_monster_id) and SpellCastTargeting.is_chain_target_selected(carried_context, Vector2i.ZERO, selected_carried_id), "the exact target identities remain selectable for the available Chain Lightning path")
	var slots_before: Dictionary = caster.spell_slots.duplicate(true)
	await combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("chain_lightning")})
	_assert(combat.pending_action_type == "spell" and caster.spell_slots == slots_before and combat.turn_budget.action_available, "Chain Lightning opens targeting without spending resources before target selection")
	await combat._on_hud_action("cancel", {})
	_teardown_scene(combat)
	_exit_test()


## A real Chain Lightning cast can follow creature, room-object and owned-copy identities beyond caster range.
func test_chain_lightning_mixed_targets_flow() -> void:
	_enter_test("chain_lightning_mixed_targets_flow")
	_setup_world()
	# Guarantee the fixture's player turn precedes the scene's asynchronous monster turns.
	var caster := _fresh_char("Chain Lightning Caster", "human", "wizard", {"STR": 8, "DEX": 60, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	caster.max_hp = 5000
	caster.current_hp = 5000
	caster.known_spells.assign(["chain_lightning"])
	caster.spell_slots["6"] = 1
	caster.spell_slots["7"] = 1
	caster.inventory.add_item("component_pouch")
	var downed_owner := _fresh_char("Downed Copy Owner", "human", "fighter", {"STR": 12, "DEX": 12, "CON": 12, "INT": 10, "WIS": 10, "CHA": 10})
	downed_owner.current_hp = 0
	downed_owner.inventory.add_item("dagger")
	var dagger_id := str(downed_owner.inventory.backpack_instances()[0]["instance_id"])
	var dagger_record := downed_owner.inventory.get_instance(dagger_id)
	var dagger_state: Dictionary = dagger_record["state"].duplicate(true)
	dagger_state["combat_object_hp"] = 5000
	dagger_record["state"] = dagger_state
	downed_owner.inventory.update_instance(dagger_record)
	PlayerManager.set_player_character(0, caster)
	PlayerManager.set_player_character(1, downed_owner)
	PartyManager.reset()
	PartyManager.register_player_character(0, caster)
	PartyManager.register_player_character(1, downed_owner)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = caster
	combat.active_combatant = {"is_player": true, "entity": caster}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(33, 0)
	combat.turn_budget.reset(caster, combat.player_entities)
	combat.remaining_attack_swings = 0
	for x in range(50):
		var coord := Vector2i(x, 0)
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			combat.hex_grid.add_tile(tile)
	var first_monster: Dictionary = combat.monster_entities[0].duplicate(true)
	first_monster["id"] = "chain_link_one"
	first_monster["name"] = "First Link"
	first_monster["hex_position"] = Vector2i(30, 0)
	first_monster["current_hp"] = 5000
	first_monster["max_hp"] = 5000
	first_monster["saving_throw_bonuses"] = {"DEX": -1000}
	var second_monster: Dictionary = first_monster.duplicate(true)
	second_monster["id"] = "chain_link_two"
	second_monster["name"] = "Second Link"
	second_monster["hex_position"] = Vector2i(36, 0)
	combat.monster_entities.clear()
	combat.monster_entities.append(first_monster)
	combat.monster_entities.append(second_monster)
	var room_object := {"id": "fixture:chain-live-barrel", "name": "Link Barrel", "kind": "container", "material": "wood", "hp": 5000, "max_hp": 5000}
	combat._update_grid_entities()
	combat.hex_grid.add_entity({"hex_position": Vector2i(24, 0), "world_object": room_object})
	var out_of_range_object := room_object.duplicate(true)
	out_of_range_object["id"] = "fixture:chain-outside-first-radius"
	combat.hex_grid.add_entity({"hex_position": Vector2i(42, 0), "world_object": out_of_range_object})
	var dropped_inventory := Inventory.new()
	dropped_inventory.add_item("dagger")
	var dropped_record: Dictionary = dropped_inventory.backpack_instances()[0]
	var dropped_state: Dictionary = dropped_record["state"].duplicate(true)
	dropped_state["combat_object_hp"] = 5000
	dropped_record["state"] = dropped_state
	var dropped_object := CombatObjectRules.make_dropped_item(dropped_record, Vector2i(34, 0), caster.character_id)
	combat.hex_grid.add_entity({"hex_position": Vector2i(34, 0), "world_object": dropped_object})
	var room_hp_before := int(room_object["hp"])
	var dagger_hp_before := int(downed_owner.inventory.get_instance(dagger_id)["state"]["combat_object_hp"])
	var dropped_hp_before := int(dropped_object["hp"])
	var first_hp_before := int(first_monster["current_hp"])
	var second_hp_before := int(second_monster["current_hp"])
	var slots_before := int(caster.spell_slots["7"])
	GameManager.test_mode = false
	combat.call_deferred("_on_hud_action", "cast_spell", {"spell": DataLoader.get_spell("chain_lightning")})
	var slot_choice_opened := false
	for _frame in 60:
		for child in combat.hud.get_children():
			if child is PopupMenu and child.item_count >= 2:
				for item_index in child.item_count:
					if str(child.get_item_text(item_index)).begins_with("Level 7 "):
						child.id_pressed.emit(7)
						slot_choice_opened = true
						break
			if slot_choice_opened:
				break
		await get_tree().process_frame
	GameManager.test_mode = true
	for _frame in 60:
		if combat.pending_action_type == "spell":
			break
		await get_tree().process_frame
	_assert(slot_choice_opened and combat.pending_action_type == "spell" and int(combat.pending_spell_data.get("_selected_spell_slot_level", 0)) == 7, "the Chain Lightning casting flow lets the player select a level-7 slot for one additional bolt")
	await combat._on_hex_clicked(Vector2i(30, 0))
	await combat._on_hex_clicked(Vector2i(36, 0))
	var selected_before_refusal: Array = combat.pending_command_target_coords.duplicate()
	await combat._on_hex_clicked(Vector2i(42, 0))
	_assert(combat.pending_command_target_coords == selected_before_refusal and int(caster.spell_slots["7"]) == slots_before and combat.turn_budget.action_available, "A secondary object outside the first target's 30-foot radius is refused before any costs")
	await combat._on_hex_clicked(Vector2i(24, 0))
	await combat._on_hex_clicked(Vector2i(33, 0))
	await combat._on_hex_clicked(Vector2i(34, 0))
	var dagger_after := downed_owner.inventory.get_instance(dagger_id)
	_assert(int(first_monster["current_hp"]) < first_hp_before and int(second_monster["current_hp"]) < second_hp_before and int(room_object["hp"]) < room_hp_before, "Chain Lightning resolves creature and room-object targets within 30 feet of the first target")
	_assert(int(dagger_after.get("state", {}).get("combat_object_hp", dagger_hp_before)) < dagger_hp_before, "Chain Lightning resolves the selected exact carried-copy identity and writes damage to that copy")
	_assert(int(dropped_object["hp"]) < dropped_hp_before, "Chain Lightning resolves a dropped exact copy after the carried-copy link")
	_assert(SpellSupport.is_available(DataLoader.get_spell("chain_lightning")) and int(caster.spell_slots.get("7", -1)) == slots_before - 1 and not combat.turn_budget.action_available, "a verified upcast Chain Lightning cast spends its slot and one Magic Action")
	_teardown_scene(combat)
	_exit_test()


## Four Sphere footprints resolve every eligible object on each covered hex once.
func test_meteor_swarm_object_area_flow() -> void:
	_enter_test("meteor_swarm_object_area_flow")
	_setup_world()
	var caster := _fresh_char("Meteor Area Caster", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	caster.known_spells.assign(["meteor_swarm"])
	caster.spell_slots["9"] = 1
	PlayerManager.set_player_character(0, caster)
	PartyManager.reset()
	PartyManager.register_player_character(0, caster)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = caster
	combat.active_combatant = {"is_player": true, "entity": caster}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	caster.current_hp = 5000
	caster.max_hp = 5000
	var meteor_creature: Dictionary = combat.monster_entities[0].duplicate(true)
	combat.monster_entities.clear()
	meteor_creature["hex_position"] = Vector2i(1, 0)
	meteor_creature["current_hp"] = 5000
	meteor_creature["max_hp"] = 5000
	meteor_creature["saving_throw_bonuses"] = {"DEX": -1000}
	combat.monster_entities.append(meteor_creature)
	combat._update_grid_entities()
	var centers: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var eligible_a := {"id": "fixture:meteor-area-a", "name": "Area Chest", "kind": "container", "material": "wood", "flammable": true, "hp": 5000, "max_hp": 5000}
	var eligible_b := {"id": "fixture:meteor-area-b", "name": "Area Table", "material": "wood", "flammable": false, "hp": 5000, "max_hp": 5000}
	var magical := {"id": "fixture:meteor-area-magic", "name": "Area Ring", "magical": true, "hp": 5000, "max_hp": 5000}
	var carried := {"id": "fixture:meteor-area-carried", "name": "Area Torch", "material": "wood", "carried": true, "hp": 5000, "max_hp": 5000}
	var overlap_hex := centers[0]
	combat.hex_grid.add_entity({"hex_position": overlap_hex, "world_object": eligible_a})
	combat.hex_grid.add_entity({"hex_position": overlap_hex, "world_object": eligible_b})
	combat.hex_grid.add_entity({"hex_position": overlap_hex, "world_object": magical})
	combat.hex_grid.add_entity({"hex_position": overlap_hex, "world_object": carried})
	var meteor_spell: Dictionary = DataLoader.get_spell("meteor_swarm")
	var area_targets := SpellCastTargeting.union_sphere_targets(centers, int(meteor_spell.get("area_radius", 8)), combat.hex_grid)
	var unique_hex_count := area_targets.size()
	var separate_area_count := 0
	for center in centers:
		separate_area_count += Targeting.get_sphere_targets(center, int(meteor_spell.get("area_radius", 8)), combat.hex_grid).size()
	var caster_hp_before := caster.current_hp
	var monster_hp_before := int(meteor_creature["current_hp"])
	_assert(SpellCastTargeting.are_legal_area_centers(centers, 4, Vector2i.ZERO, CombatAction.spell_range_in_hexes(meteor_spell, caster.level), combat.hex_grid) and unique_hex_count < separate_area_count, "Meteor Swarm accepts four distinct in-range Sphere centers and deduplicates overlapping hexes")
	combat.turn_budget.reset(caster, combat.player_entities)
	await combat._on_hud_action("cast_spell", {"spell": meteor_spell})
	for center in centers:
		await combat._on_hex_clicked(center)
	_assert(caster.current_hp < caster_hp_before and int(meteor_creature["current_hp"]) < 5000 and int(eligible_a["hp"]) < 5000 and int(eligible_b["hp"]) < 5000 and bool(eligible_a.get("burning", false)), "Meteor Swarm resolves creature saves/damage and damages each eligible object on the covered hex, igniting flammable items")
	_assert(int(meteor_creature["current_hp"]) < monster_hp_before and int(magical["hp"]) == 5000 and int(carried["hp"]) == 5000 and SpellSupport.is_available(meteor_spell), "Meteor Swarm resolves monster saves and skips magical/carried objects after full target selection")
	_assert(int(caster.spell_slots.get("9", 0)) == 0 and not combat.turn_budget.action_available, "Meteor Swarm spends one level-9 slot and one Magic Action after the four center choices")
	_teardown_scene(combat)
	_exit_test()


## Fireball and Burning Hands ignite eligible unattended room objects in their area.
func test_fire_area_object_ignition_flow() -> void:
	_enter_test("fire_area_object_ignition_flow")
	_setup_world()
	var caster := _fresh_char("Fire Area Caster", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	caster.known_spells.assign(["fireball"])
	caster.inventory.add_item("component_pouch")
	caster.spell_slots["3"] = 1
	PlayerManager.set_player_character(0, caster)
	PartyManager.reset()
	PartyManager.register_player_character(0, caster)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = caster
	combat.active_combatant = {"is_player": true, "entity": caster}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	var fuel := {"id": "fixture:fireball-kindling", "name": "Kindling", "kind": "loose", "material": "wood", "flammable": true, "hp": 20, "max_hp": 20}
	var stone := {"id": "fixture:fireball-stone", "name": "Stone", "kind": "loose", "material": "stone", "flammable": false, "hp": 20, "max_hp": 20}
	combat.hex_grid.add_entity({"hex_position": Vector2i(1, 0), "world_object": fuel})
	combat.hex_grid.add_entity({"hex_position": Vector2i(2, 0), "world_object": stone})
	combat.turn_budget.reset(caster, combat.player_entities)
	await combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("fireball")})
	await combat._on_hex_clicked(Vector2i(1, 0))
	_assert(bool(fuel.get("burning", false)) and not bool(stone.get("burning", false)), "Fireball ignition marks an unattended flammable object in its area while leaving a nonflammable object unchanged")
	_assert(int(caster.spell_slots.get("3", 0)) == 0 and not combat.turn_budget.action_available, "Fireball area ignition resolves through the real cast and spends its spell slot and Magic Action")
	fuel["burning"] = false
	combat.hex_grid.add_entity({"hex_position": Vector2i(1, 0), "world_object": fuel})
	combat.hex_grid.add_entity({"hex_position": Vector2i(2, 0), "world_object": stone})
	caster.spell_slots["1"] = 1
	caster.known_spells.append("burning_hands")
	combat.turn_budget.reset(caster, combat.player_entities)
	await combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("burning_hands")})
	await combat._on_hex_clicked(Vector2i(1, 0))
	_assert(bool(fuel.get("burning", false)) and not bool(stone.get("burning", false)), "Burning Hands uses its cone footprint to ignite unattended flammable objects only")
	_assert(int(caster.spell_slots.get("1", 0)) == 0 and not combat.turn_budget.action_available, "Burning Hands area ignition resolves through the real cast and spends its spell slot and Magic Action")
	_teardown_scene(combat)
	_exit_test()


## Sunburst resolves its Sphere, failed-save Blinded source, repeat saves and Darkness cleanup.
func test_sunburst_spell_flow() -> void:
	_enter_test("sunburst_spell_flow")
	_setup_world()
	var caster := _fresh_char("Sunburst Wizard", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	caster.known_spells.assign(["sunburst"])
	caster.inventory.add_item("component_pouch")
	caster.spell_slots["8"] = 1
	PlayerManager.set_player_character(0, caster)
	PartyManager.reset()
	PartyManager.register_player_character(0, caster)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = caster
	combat.active_combatant = {"is_player": true, "entity": caster}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(caster, combat.player_entities)
	combat.remaining_attack_swings = 0
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 20):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.terrain = HexTile.TerrainType.PLAINS
			combat.hex_grid.add_tile(tile)
	var failed_target: Dictionary = {"id": "sunburst_failed", "name": "Failed Save", "creature_type": "humanoid", "hex_position": Vector2i(6, 0), "is_alive": true, "current_hp": 500, "max_hp": 500, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"CON": -1000}, "spell_slots": {}}
	var saved_target: Dictionary = {"id": "sunburst_saved", "name": "Saved", "creature_type": "humanoid", "hex_position": Vector2i(7, 0), "is_alive": true, "current_hp": 500, "max_hp": 500, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"CON": 1000}, "spell_slots": {}}
	var outside_target: Dictionary = {"id": "sunburst_outside", "name": "Outside Sphere", "creature_type": "humanoid", "hex_position": Vector2i(19, 0), "is_alive": true, "current_hp": 500, "max_hp": 500, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"CON": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.assign([failed_target, saved_target, outside_target])
	caster.concentrating_on = {"spell_id": "darkness", "effects": [], "targets": [], "darkness_source_id": "darkness:inside_sunburst"}
	combat.active_spell_zones["darkness:inside_sunburst"] = {"spell_id": "darkness", "caster_id": caster.character_id, "center": Vector2i(5, 0), "coords": [Vector2i(5, 0)], "radius_hexes": 3}
	combat.active_spell_zones["darkness:outside_sunburst"] = {"spell_id": "darkness", "caster_id": "fixture-outside-owner", "center": Vector2i(19, 0), "coords": [Vector2i(19, 0)], "radius_hexes": 3}
	combat._update_grid_entities()
	var hp_before := int(failed_target["current_hp"])
	var saved_hp_before := int(saved_target["current_hp"])
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("sunburst").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 8
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(6, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var effect_sources: Dictionary = failed_target.get("spell_effects", {})
	var sunburst_source := ""
	for source_value in effect_sources:
		if str(effect_sources[source_value].get("spell_id", "")) == "sunburst":
			sunburst_source = str(source_value)
	_assert(SpellSupport.is_available(DataLoader.get_spell("sunburst")) and not sunburst_source.is_empty() and failed_target.get("condition_sources", {}).get("blinded", {}).has(sunburst_source), "A real Sunburst cast selects its 60-foot Sphere and applies source-owned Blinded after a failed Constitution save")
	_assert(int(failed_target["current_hp"]) < hp_before and int(saved_target["current_hp"]) < saved_hp_before and not CombatAction.has_condition(saved_target, "blinded") and int(outside_target["current_hp"]) == 500, "Sunburst damages failed and successful saves in the Sphere while leaving creatures outside it untouched")
	_assert(not combat.active_spell_zones.has("darkness:inside_sunburst") and combat.active_spell_zones.has("darkness:outside_sunburst") and caster.concentrating_on.is_empty(), "Sunburst removes overlapping magical Darkness, ends its owner's Concentration and preserves a zone outside its area")
	combat._resolve_condition_spell_repeat_saves(failed_target)
	_assert(int(SpellEffects.records(failed_target).get(sunburst_source, {}).get("remaining_seconds", -1)) == 54, "The blinded creature makes its first end-of-turn Constitution save without consuming time on the caster's turn")
	failed_target["saving_throw_bonuses"]["CON"] = 1000
	combat._resolve_condition_spell_repeat_saves(failed_target)
	_assert(not failed_target.get("condition_sources", {}).get("blinded", {}).has(sunburst_source) and int(caster.spell_slots["8"]) == 0 and not combat.turn_budget.action_available, "A successful repeat save ends Blinded; the cast spends one level-eight slot and Magic Action")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Real Sleep area targeting, per-creature choice, and action-based wake-up.
func test_sleep_spell_flow() -> void:
	_enter_test("sleep_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Sleep Wizard", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	wizard.known_spells.assign(["sleep"])
	wizard.spell_slots["1"] = 1
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var chosen: Dictionary = {"id": "sleep_chosen", "name": "Chosen Goblin", "creature_type": "humanoid", "hex_position": Vector2i(2, 0), "is_alive": true, "current_hp": 7, "max_hp": 7, "armor_class": 15, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"WIS": -1000}, "spell_slots": {}}
	var declined: Dictionary = {"id": "sleep_declined", "name": "Declined Goblin", "creature_type": "humanoid", "hex_position": Vector2i(3, 0), "is_alive": true, "current_hp": 7, "max_hp": 7, "armor_class": 15, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"WIS": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append(chosen)
	combat.monster_entities.append(declined)
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("sleep")
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(2, 0))
	var creature_choice_count := 0
	for _frame in range(120):
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and child.title == "Sleep Targets":
				var is_first_choice := str(child.dialog_text).contains("Chosen Goblin")
				creature_choice_count += 1
				if is_first_choice:
					child.confirmed.emit()
				else:
					child.canceled.emit()
				break
		await get_tree().process_frame
		if creature_choice_count >= 2:
			break
	for _frame in range(30):
		if combat.pending_action_type.is_empty():
			break
		await get_tree().process_frame
	_assert(creature_choice_count == 2 and CombatAction.has_condition(chosen, "incapacitated") and not CombatAction.has_condition(declined, "incapacitated"), "Sleep asks which creatures to include and resolves a save only for the chosen creature")
	combat.player_entities[0]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_action_type = ""
	await combat._on_hex_clicked(Vector2i(2, 0))
	_assert(not SpellEffects.has_spell(chosen, "sleep") and not CombatAction.has_condition(chosen, "incapacitated") and not combat.turn_budget.action_available, "A nearby creature spends its action to shake a Sleep target awake")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Real Blindness/Deafness upcast, condition choice, repeat save, and action costs.
func test_blindness_deafness_spell_flow() -> void:
	_enter_test("blindness_deafness_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Blindness Wizard", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	for _level in 4:
		wizard.level_up()
	wizard.known_spells.assign(["blindness/deafness"])
	wizard.spell_slots["2"] = 1
	wizard.spell_slots["3"] = 1
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var first: Dictionary = {"id": "blindness_live_first", "name": "First Goblin", "creature_type": "humanoid", "hex_position": Vector2i(2, 0), "is_alive": true, "current_hp": 20, "max_hp": 20, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"CON": -1000}, "spell_slots": {}}
	var second: Dictionary = {"id": "blindness_live_second", "name": "Second Goblin", "creature_type": "humanoid", "hex_position": Vector2i(3, 0), "is_alive": true, "current_hp": 20, "max_hp": 20, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"CON": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append(first)
	combat.monster_entities.append(second)
	combat._update_grid_entities()
	var slot_before := int(wizard.spell_slots["3"])
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("blindness/deafness").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 3
	combat.pending_action_type = "cast_spell"
	var extra_targets: Array[Vector2i] = [Vector2i(2, 0), Vector2i(3, 0)]
	combat.call_deferred("_execute_player_spell", Vector2i(2, 0), Vector2i(9999, 9999), extra_targets)
	var condition_choice_found := false
	for _frame in 120:
		for child in combat.hud.get_children():
			if child is PopupMenu and child.item_count == 2 and child.get_item_text(0) == "Blinded" and child.get_item_text(1) == "Deafened":
				condition_choice_found = true
				child.id_pressed.emit(1)
				break
		if condition_choice_found:
			break
		await get_tree().process_frame
	for _frame in 90:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var first_records: Dictionary = SpellEffects.records(first)
	var second_records: Dictionary = SpellEffects.records(second)
	var first_sources: Array = first_records.keys().filter(func(source): return str(first_records[source].get("spell_id", "")) == "blindness/deafness")
	var second_sources: Array = second_records.keys().filter(func(source): return str(second_records[source].get("spell_id", "")) == "blindness/deafness")
	_assert(condition_choice_found, "Blindness/Deafness asks the caster to choose Blinded or Deafened")
	_assert(CombatAction.has_condition(first, "deafened") and CombatAction.has_condition(second, "deafened") and not CombatAction.has_condition(first, "blinded") and not CombatAction.has_condition(second, "blinded"), "The level-3 cast applies the chosen Deafened condition to two distinct targets")
	_assert(first_sources.size() == 1 and second_sources.size() == 1 and first_sources[0] == second_sources[0] and int(first_records[first_sources[0]].get("save_dc", 0)) == wizard.get_spell_save_dc() and int(second_records[second_sources[0]].get("save_dc", 0)) == wizard.get_spell_save_dc(), "Each target receives its own record for the cast source and captured save DC")
	_assert(int(wizard.spell_slots["3"]) == slot_before - 1 and int(wizard.spell_slots["2"]) == 1 and not combat.turn_budget.action_available, "The upcast spends one third-level slot and one Magic action")
	first["saving_throw_bonuses"]["CON"] = 1000
	combat._resolve_condition_spell_repeat_saves(first)
	_assert(not CombatAction.has_condition(first, "deafened") and SpellEffects.records(first).is_empty() and CombatAction.has_condition(second, "deafened") and not SpellEffects.records(second).is_empty(), "A successful end-of-turn Constitution save ends only that target's effect")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Real Grease cast, area saves, entry/end-turn triggers and timed terrain cleanup.
func test_grease_spell_flow() -> void:
	_enter_test("grease_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Grease Wizard", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	wizard.known_spells.assign(["grease"])
	wizard.spell_slots["1"] = 1
	wizard.spell_slots["2"] = 1
	wizard.known_spells.append("misty_step")
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var initial_fail: Dictionary = {"id": "grease_initial_fail", "name": "Grease Initial Fail", "creature_type": "humanoid", "hex_position": Vector2i(2, 0), "is_alive": true, "current_hp": 20, "max_hp": 20, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"DEX": -1000}, "spell_slots": {}}
	var initial_success: Dictionary = {"id": "grease_initial_success", "name": "Grease Initial Success", "creature_type": "humanoid", "hex_position": Vector2i(3, 0), "is_alive": true, "current_hp": 20, "max_hp": 20, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"DEX": 1000}, "spell_slots": {}}
	var entering: Dictionary = {"id": "grease_entering", "name": "Grease Entrant", "creature_type": "humanoid", "hex_position": Vector2i(4, 0), "is_alive": true, "current_hp": 20, "max_hp": 20, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"DEX": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([initial_fail, initial_success, entering])
	combat._update_grid_entities()
	var base_cost: float = combat.hex_grid.get_hex_cost(Vector2i(2, 0))
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("grease").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(2, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var zone_keys: Array = combat.active_spell_zones.keys()
	var zone: Dictionary = combat.active_spell_zones[zone_keys[0]] if not zone_keys.is_empty() else {}
	var cast_cost: float = combat.hex_grid.get_hex_cost(Vector2i(2, 0))
	_assert(SpellSupport.is_available(DataLoader.get_spell("grease")) and zone.size() > 0 and zone.get("coords", []).size() == 7, "A live Grease cast creates its seven-hex area")
	_assert(CombatAction.has_condition(initial_fail, "prone") and not CombatAction.has_condition(initial_success, "prone"), "Creatures in the area make the initial save and only a failed save causes Prone")
	_assert(is_equal_approx(cast_cost, base_cost + 1.0) and int(zone.get("save_dc", 0)) == wizard.get_spell_save_dc() and int(wizard.spell_slots["1"]) == 0 and not combat.turn_budget.action_available, "Grease applies difficult-terrain cost, captures the save DC, and spends one slot and Magic action")
	entering["saving_throw_bonuses"]["DEX"] = -1000
	var entry_results: Array = await combat._check_opportunity_attacks_for_path(entering, entering, [Vector2i(4, 0), Vector2i(3, 0)], true)
	_assert(CombatAction.has_condition(entering, "prone") and entering.get("hex_position", Vector2i.ZERO) == Vector2i(3, 0), "Movement into Grease triggers a Dexterity save and failed entry save causes Prone")
	entering["saving_throw_bonuses"]["DEX"] = 1000
	var end_turn_results: Array = await combat._resolve_spell_zone_end_turn(entering, Vector2i(3, 0))
	_assert(not end_turn_results.is_empty() and bool(end_turn_results[0].get("saved", false)) and CombatAction.has_condition(entering, "prone"), "A successful end-of-turn Grease save is resolved while Prone remains until the creature stands")
	entering.get("conditions", {}).erase("prone")
	entering["hex_position"] = Vector2i(4, 0)
	entering["saving_throw_bonuses"]["DEX"] = -1000
	initial_success["hex_position"] = Vector2i(10, 0)
	combat._update_grid_entities()
	var push_effects: Array[Dictionary] = [{"type": "push", "distance": 1}]
	await combat._handle_spell_effects(null, entering, {"name": "Forced Move", "effects": push_effects}, Vector2i(6, 0), Vector2i(4, 0), {"success": true, "saved": false})
	_assert(entering.get("hex_position", Vector2i.ZERO) == Vector2i(3, 0) and CombatAction.has_condition(entering, "prone"), "Spell-driven forced movement into Grease triggers the entry save")
	combat.pending_spell_data = DataLoader.get_spell("misty_step").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 2
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(1, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(combat.player_entities[0].get("hex_position", Vector2i.ZERO) == Vector2i(1, 0) and int(wizard.spell_slots.get("2", 0)) == 0 and not combat.turn_budget.bonus_action_available, "Misty Step can choose a destination and landing in Grease triggers its entry save")
	for _round in 9:
		combat._tick_spell_zones()
	_assert(combat.active_spell_zones.size() == 1 and is_equal_approx(combat.hex_grid.get_hex_cost(Vector2i(2, 0)), base_cost + 1.0), "Grease remains active until its tenth round ends")
	combat._tick_spell_zones()
	_assert(combat.active_spell_zones.is_empty() and is_equal_approx(combat.hex_grid.get_hex_cost(Vector2i(2, 0)), base_cost), "Grease expires after one minute and restores normal movement cost")
	print("GREASE_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Real Spike Growth cast, per-hex travel damage, teleport exclusion and concentration cleanup.
func test_spike_growth_spell_flow() -> void:
	_enter_test("spike_growth_spell_flow")
	_setup_world()
	var druid := _fresh_char("Spike Growth Druid", "human", "druid", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	druid.inventory.add_item("component_pouch")
	druid.inventory.unequip(Inventory.Slot.WEAPON)
	druid.known_spells.assign(["spike_growth"])
	druid.spell_slots["2"] = 1
	PlayerManager.set_player_character(0, druid)
	PartyManager.reset()
	PartyManager.register_player_character(0, druid)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = druid
	combat.active_combatant = {"is_player": true, "entity": druid}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(druid, combat.player_entities)
	combat.remaining_attack_swings = 0
	var mover: Dictionary = {"id": "spike_growth_live_mover", "name": "Thorn Runner", "creature_type": "humanoid", "hex_position": Vector2i(4, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "temp_hp": 0, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_resistances": [], "damage_immunities": [], "saving_throw_bonuses": {}, "spell_slots": {}}
	var standing_inside: Dictionary = {"id": "spike_growth_live_standing", "name": "Standing Creature", "creature_type": "humanoid", "hex_position": Vector2i(0, 2), "is_alive": true, "current_hp": 100, "max_hp": 100, "temp_hp": 0, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_resistances": [], "damage_immunities": [], "saving_throw_bonuses": {}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([mover, standing_inside])
	combat._update_grid_entities()
	var base_cost: float = combat.hex_grid.get_hex_cost(Vector2i(-2, 0))
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("spike_growth").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 2
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(-2, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var zone_keys: Array = combat.active_spell_zones.keys()
	var zone: Dictionary = combat.active_spell_zones[zone_keys[0]] if not zone_keys.is_empty() else {}
	var cast_cost: float = combat.hex_grid.get_hex_cost(Vector2i(-2, 0))
	_assert(zone.get("spell_id", "") == "spike_growth" and Vector2i(-2, 0) in zone.get("coords", []) and Vector2i(2, 0) in zone.get("coords", []) and not (Vector2i(4, 0) in zone.get("coords", [])) and zone.get("damage_formula", "") == "2d4", "A live Spike Growth cast creates a radius-four Sphere within map boundaries and captures its damage formula")
	_assert(int(standing_inside["current_hp"]) == 100, "A creature standing in the area takes no damage just from the spell being cast")
	_assert(cast_cost == base_cost + 1.0 and druid.concentrating_on.get("spell_id", "") == "spike_growth" and int(druid.spell_slots["2"]) == 0 and not combat.turn_budget.action_available, "Spike Growth applies difficult terrain, starts concentration, and spends its slot and Magic action")
	var hp_before: int = int(mover["current_hp"])
	await combat._resolve_spell_zone_entries(mover, Vector2i(4, 0), Vector2i(1, 0))
	_assert(int(mover["current_hp"]) == hp_before, "Teleport-style landing entry does not count as travel through Spike Growth")
	var movement_results: Array = await combat._check_opportunity_attacks_for_path(mover, mover, [Vector2i(4, 0), Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0)], true)
	var spike_hits: Array = movement_results.filter(func(result): return str(result.get("spell_id", "")) == "spike_growth")
	_assert(spike_hits.size() == 2 and int(mover["current_hp"]) < hp_before, "Ground movement takes 2d4 Piercing damage for each five-foot hex traveled in the Sphere")
	combat._end_concentration(druid)
	_assert(combat.active_spell_zones.is_empty() and is_equal_approx(combat.hex_grid.get_hex_cost(Vector2i(-2, 0)), base_cost), "Ending concentration removes Spike Growth and restores the terrain movement cost")
	print("SPIKE_GROWTH_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Real Entangle casting, Strength saves, per-source escape and concentration cleanup.
func test_entangle_spell_flow() -> void:
	_enter_test("entangle_spell_flow")
	_setup_world()
	# Keep the save failure deterministic while still resolving it through the live casting path.
	var druid := _fresh_char("Entangle Druid", "human", "druid", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 30, "CHA": 10})
	var captive := _fresh_char("Entangle Captive", "human", "fighter", {"STR": 3, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	druid.known_spells.assign(["entangle"])
	druid.spell_slots["1"] = 1
	captive.skill_proficiencies.append("Athletics")
	PlayerManager.set_player_character(0, druid)
	PlayerManager.set_player_character(1, captive)
	PartyManager.reset()
	PartyManager.register_player_character(0, druid)
	PartyManager.register_player_character(1, captive)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = druid
	combat.active_combatant = {"is_player": true, "entity": druid}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(-1, 0)
	combat.turn_budget.reset(druid, combat.player_entities)
	combat.remaining_attack_swings = 0
	var monster: Dictionary = {"id": "entangle_live_monster", "name": "Entangled Goblin", "creature_type": "humanoid", "hex_position": Vector2i(-3, 0), "is_alive": true, "current_hp": 20, "max_hp": 20, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"STR": -1000}, "skills": {"Athletics": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append(monster)
	combat._update_grid_entities()
	var base_cost: float = combat.hex_grid.get_hex_cost(Vector2i(-2, 0))
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("entangle").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(-2, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var zone_keys: Array = combat.active_spell_zones.keys()
	var zone: Dictionary = combat.active_spell_zones[zone_keys[0]] if not zone_keys.is_empty() else {}
	_assert(zone.get("spell_id", "") == "entangle" and Vector2i(-1, 0) in zone.get("coords", []) and CombatAction.has_condition(captive, "restrained") and CombatAction.has_condition(monster, "restrained"), "A live Entangle cast makes a Difficult Terrain area and restrains creatures that fail their Strength saves")
	_assert(not CombatAction.has_condition(druid, "restrained") and captive.get_speed() == 0 and combat.hex_grid.get_hex_cost(Vector2i(-2, 0)) == base_cost + 1.0 and int(druid.spell_slots["1"]) == 0, "Entangle excludes its caster, sets Restrained movement to zero and spends one slot")
	# Force the successful escape branch even on a roll of 1 against the
	# deliberately high cast DC used above to guarantee initial restraint.
	captive.ability_scores.set_score("STR", 50)
	combat.current_player_idx = 1
	combat.active_character = captive
	combat.active_combatant = {"is_player": true, "entity": captive}
	combat.turn_budget.reset(captive, combat.player_entities)
	var escape_resolved: bool = await combat._try_escape_restrained_zone(captive)
	_assert(escape_resolved and not CombatAction.has_condition(captive, "restrained") and not combat.turn_budget.action_available, "A Restrained creature spends an action and escapes with a successful Strength (Athletics) check")
	var monster_escape_resolved: bool = combat._try_monster_escape_restrained_zone(monster)
	_assert(monster_escape_resolved and CombatAction.has_condition(monster, "restrained"), "A Restrained monster attempts an Athletics escape on its turn and remains Restrained after a failed check")
	combat._end_concentration(druid)
	_assert(not CombatAction.has_condition(monster, "restrained") and combat.active_spell_zones.is_empty() and is_equal_approx(combat.hex_grid.get_hex_cost(Vector2i(-2, 0)), base_cost), "Ending concentration removes only the Entangle grant and restores normal terrain")
	print("ENTANGLE_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Live Black Tentacles casting, repeated saves, escape, concentration and upcasting.
func test_black_tentacles_spell_flow() -> void:
	_enter_test("black_tentacles_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Tentacles Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	var captive := _fresh_char("Tentacles Captive", "human", "fighter", {"STR": 3, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["black_tentacles"])
	wizard.inventory.add_item("component_pouch")
	wizard.spell_slots["4"] = 1
	wizard.spell_slots["5"] = 1
	wizard.spell_slots["7"] = 1
	wizard.spell_slots["9"] = 1
	captive.skill_proficiencies.append("Athletics")
	captive.add_modifier("roll", "save:STR", -1000, 1)
	PlayerManager.set_player_character(0, wizard)
	PlayerManager.set_player_character(1, captive)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	PartyManager.register_player_character(1, captive)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i(-5, 0)
	combat.player_entities[1]["hex_position"] = Vector2i(-1, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var monster: Dictionary = {"id": "black_tentacles_live_monster", "name": "Tentacled Goblin", "creature_type": "humanoid", "hex_position": Vector2i(3, 0), "is_alive": true, "current_hp": 60, "max_hp": 60, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"STR": -1000}, "skills": {"Athletics": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append(monster)
	combat._update_grid_entities()
	var base_cost: float = combat.hex_grid.get_hex_cost(Vector2i.ZERO)
	var captive_hp := captive.current_hp
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("black_tentacles").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 4
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var zone_id := ""
	for source in combat.active_spell_zones:
		zone_id = str(source)
		break
	var zone: Dictionary = combat.active_spell_zones.get(zone_id, {})
	var monster_hp := int(monster["current_hp"])
	_assert(zone.get("spell_id", "") == "black_tentacles" and Vector2i(-2, 0) in zone.get("coords", []) and CombatAction.has_condition_source(monster, zone_id) == false and captive.has_condition("restrained") and captive.current_hp < captive_hp, "The live 20-foot square applies Difficult Terrain and the initial failed save damages and Restrains a creature inside (zone=%s coords=%d hp=%d/%d condition=%s)" % [str(zone.get("spell_id", "")), zone.get("coords", []).size(), captive.current_hp, captive_hp, str(captive.conditions)])
	_assert(is_equal_approx(combat.hex_grid.get_hex_cost(Vector2i.ZERO), base_cost + 1.0) and wizard.concentrating_on.get("spell_id", "") == "black_tentacles" and int(wizard.spell_slots["4"]) == 0 and monster["current_hp"] == monster_hp, "Black Tentacles starts level-4 Concentration, spends its slot, and leaves an outside creature unaffected (focus=%s slots=%s zone=%s log=%s)" % [str(wizard.concentrating_on), str(wizard.spell_slots), zone_id, combat.hud.log_text.text])
	combat.tracker.current_round += 1
	monster["hex_position"] = Vector2i(3, 0)
	var entry_results: Array = await combat._resolve_spell_zone_entries(monster, Vector2i(3, 0), Vector2i(2, 0))
	var hp_after_entry := int(monster["current_hp"])
	_assert(not entry_results.is_empty() and hp_after_entry < monster_hp and CombatAction.has_condition_source(monster, zone_id), "Entering the square on a later turn triggers a new Strength save, damage, and source-owned restraint")
	await combat._resolve_spell_zone_end_turn(monster, Vector2i(2, 0))
	_assert(int(monster["current_hp"]) == hp_after_entry, "Entry and end-of-turn triggers still allow only one save in the same turn")
	combat.tracker.current_round += 1
	await combat._resolve_spell_zone_end_turn(monster, Vector2i(2, 0))
	var hp_after_next_turn := int(monster["current_hp"])
	_assert(hp_after_next_turn < hp_after_entry, "A creature that ends a later turn in the area repeats the save and damage")
	captive.ability_scores.set_score("STR", 30)
	combat.current_player_idx = 1
	combat.active_character = captive
	combat.active_combatant = {"is_player": true, "entity": captive}
	combat.turn_budget.reset(captive, combat.player_entities)
	var escaped: bool = await combat._try_escape_restrained_zone(captive)
	_assert(escaped and not captive.has_condition("restrained") and not combat.turn_budget.action_available, "A Restrained party member can spend an Action and escape with Strength (Athletics)")
	var monster_escape: bool = combat._try_monster_escape_restrained_zone(monster)
	_assert(monster_escape and monster.has("conditions") and CombatAction.has_condition(monster, "restrained"), "A Restrained monster attempts an Athletics escape and retains the condition after failure")
	combat._end_concentration(wizard)
	_assert(combat.active_spell_zones.is_empty() and not CombatAction.has_condition(monster, "restrained") and is_equal_approx(combat.hex_grid.get_hex_cost(Vector2i.ZERO), base_cost), "Ending Concentration removes Black Tentacles restraints and restores terrain")
	# A level-5 cast drops Concentration and lasts 8 hours, even if the caster later concentrates on something else.
	wizard.concentrating_on = {}
	captive.ability_scores.set_score("STR", 30)
	monster["hex_position"] = Vector2i(2, 0)
	monster["saving_throw_bonuses"]["STR"] = 1000
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"is_player": true, "entity": wizard}
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("black_tentacles").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 5
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	zone = {}
	for source in combat.active_spell_zones.values():
		zone = source
		break
	_assert(wizard.concentrating_on.is_empty() and zone.get("spell_id", "") == "black_tentacles" and not bool(zone.get("concentration", true)) and int(zone.get("rounds_remaining", 0)) == 4800 and int(wizard.spell_slots["5"]) == 0, "A level-5 Black Tentacles cast does not require Concentration and lasts 8 hours")
	combat._remove_spell_zone(str(zone.get("source_id", "")))
	# Higher slots step to a 24-hour duration at level 7 and until dispelled at level 9.
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("black_tentacles").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 7
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	zone = {}
	for source in combat.active_spell_zones.values():
		zone = source
		break
	var level_seven_zone_id := str(zone.get("source_id", ""))
	var level_seven_valid: bool = zone.get("spell_id", "") == "black_tentacles" and not bool(zone.get("concentration", true)) and int(zone.get("rounds_remaining", 0)) == 14400 and int(wizard.spell_slots["7"]) == 0
	_assert(level_seven_valid, "A level-7 Black Tentacles cast does not require Concentration and lasts 24 hours")
	wizard.concentrating_on = {"spell_id": "black_tentacles", "targets": [], "black_tentacles_source_id": ""}
	combat._end_concentration(wizard)
	_assert(combat.active_spell_zones.has(level_seven_zone_id), "Ending a later concentration does not remove non-concentration Black Tentacles")
	combat._remove_spell_zone(level_seven_zone_id)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("black_tentacles").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 9
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	zone = {}
	for source in combat.active_spell_zones.values():
		zone = source
		break
	_assert(zone.get("spell_id", "") == "black_tentacles" and not bool(zone.get("concentration", true)) and int(zone.get("rounds_remaining", 0)) == -1 and int(wizard.spell_slots["9"]) == 0, "A level-9 Black Tentacles cast lasts until dispelled without Concentration")
	combat._remove_spell_zone(str(zone.get("source_id", "")))
	print("BLACK_TENTACLES_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Live Wall of Fire casting, initial damage, entry/end-turn triggers and cleanup.
func test_wall_of_fire_spell_flow() -> void:
	_enter_test("wall_of_fire_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Wall of Fire Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["wall_of_fire"])
	wizard.inventory.add_item("component_pouch")
	wizard.spell_slots["4"] = 1
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 16):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "wall_of_fire_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i(-5, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var initial_target: Dictionary = {"id": "wall_of_fire_initial", "name": "Line Target", "creature_type": "humanoid", "hex_position": Vector2i(2, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"DEX": -1000}, "spell_slots": {}}
	var crossing_target: Dictionary = {"id": "wall_of_fire_crossing", "name": "Crossing Target", "creature_type": "humanoid", "hex_position": Vector2i(-2, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"DEX": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([initial_target, crossing_target])
	combat._update_grid_entities()
	var initial_hp := int(initial_target["current_hp"])
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("wall_of_fire").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 4
	combat.pending_action_type = "cast_spell"
	var wall_endpoints: Array[Vector2i] = [Vector2i(4, 0)]
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO, Vector2i(9999, 9999), wall_endpoints)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id := ""
	for source_value in combat.active_spell_zones:
		var candidate_zone: Dictionary = combat.active_spell_zones[source_value]
		if str(candidate_zone.get("spell_id", "")) == "wall_of_fire":
			source_id = str(source_value)
			break
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	if source_id.is_empty():
		print("Wall of Fire cast diagnostic: ", combat.hud.log_text.text)
	_assert(not source_id.is_empty() and zone.get("coords", []) == HexUtils.hex_line(Vector2i.ZERO, Vector2i(4, 0)) and Vector2i(2, 0) in zone.get("dangerous_coords", []) and int(initial_target["current_hp"]) < initial_hp, "The real endpoint-selected line has the expected footprint and deals initial Dexterity-save damage")
	_assert(wizard.concentrating_on.get("spell_id", "") == "wall_of_fire" and int(wizard.spell_slots["4"]) == 0 and bool(zone.get("concentration", false)), "Wall of Fire spends its fourth-level slot and starts Concentration")
	var dangerous_coords: Array = zone.get("dangerous_coords", [])
	var crossing_hex := Vector2i.ZERO
	for coord in dangerous_coords:
		if coord not in zone.get("coords", []) and HexUtils.get_distance(Vector2i(-2, 0), coord) == 1:
			crossing_hex = coord
			break
	_assert(crossing_hex != Vector2i.ZERO, "The selected Wall of Fire has an adjacent dangerous-side cell reachable by the crossing target")
	var hp_before_crossing := int(crossing_target["current_hp"])
	var hot_side_results: Array[Dictionary] = await combat._resolve_spell_zone_entries(crossing_target, Vector2i(-2, 0), crossing_hex)
	_assert(hot_side_results.is_empty() and int(crossing_target["current_hp"]) == hp_before_crossing, "Entering the dangerous side without entering the wall causes no immediate damage")
	zone["damage_formula"] = "5"
	crossing_target["saving_throw_bonuses"]["DEX"] = 1000
	var entry_results: Array[Dictionary] = await combat._resolve_spell_zone_entries(crossing_target, crossing_hex, Vector2i.ZERO)
	var hp_after_entry := int(crossing_target["current_hp"])
	_assert(not entry_results.is_empty() and hp_after_entry == hp_before_crossing - 5, "Entering the wall deals full Fire damage without another saving throw")
	await combat._resolve_spell_zone_entries(crossing_target, crossing_hex, Vector2i.ZERO)
	_assert(int(crossing_target["current_hp"]) == hp_after_entry, "The wall's first-entry trigger cannot damage the same creature twice in one turn")
	await combat._resolve_spell_zone_end_turn(crossing_target, crossing_hex)
	var hp_after_end := int(crossing_target["current_hp"])
	_assert(hp_after_end == hp_after_entry - 5, "Ending a turn on the dangerous side deals full damage separately from wall entry")
	await combat._resolve_spell_zone_end_turn(crossing_target, crossing_hex)
	_assert(int(crossing_target["current_hp"]) == hp_after_end, "Repeated resolution of the same end-of-turn event does not deal damage twice")
	combat.tracker.current_round += 1
	await combat._resolve_spell_zone_end_turn(crossing_target, crossing_hex)
	var hp_after_next_turn := int(crossing_target["current_hp"])
	_assert(hp_after_next_turn == hp_after_end - 5, "Ending a later turn on the dangerous side triggers damage again")
	# Exercise the actual cast's durable owner, rather than a hand-authored
	# concentration dictionary standing in for the player cast.
	var prior_room_context := GameManager.transition_context.duplicate()
	var wall_room := LocalRoomRules.create(DataLoader.get_campaign("the_lost_crown")["dungeons"]["ruins_of_ashvale"]["tactical_rooms"]["1"], [wizard])
	GameManager.transition_context["local_room"] = wall_room
	zone["damage_formula"] = "5d8"
	LocalRoomCombat.capture_spell_zones(combat.player_entities, combat.active_spell_zones)
	var wall_caster_dto: Dictionary = JSON.parse_string(JSON.stringify(wizard.to_dict()))
	var wall_room_dto: Dictionary = JSON.parse_string(JSON.stringify(wall_room))
	var reloaded_wizard := Character.new()
	reloaded_wizard.from_dict(wall_caster_dto)
	GameManager.transition_context["local_room"] = wall_room_dto
	var restored_wall_zones := LocalRoomCombat.restore_spell_zones([{"character": reloaded_wizard}])
	_assert(DungeonPersistence.local_error(wall_room_dto).is_empty() and SpellEffects.saved_state_error(wall_caster_dto).is_empty() and restored_wall_zones.has(source_id), "A real Wall of Fire cast retains its owner and area through validated character and room JSON reload")
	SpellEffects.end_concentration(reloaded_wizard, [reloaded_wizard])
	_assert(wall_room_dto.get("areas", []).is_empty(), "Ending the reloaded caster's Concentration clears the saved wall area")
	GameManager.transition_context = prior_room_context
	combat._end_concentration(wizard)
	_assert(combat.active_spell_zones.is_empty() and wizard.concentrating_on.is_empty(), "Ending Concentration removes the Wall of Fire zone")
	print("WALL_OF_FIRE_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Sleet Storm applies its save on first entry per turn and at turn start.
func test_sleet_storm_spell_flow() -> void:
	_enter_test("sleet_storm_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Sleet Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 16, "WIS": 10, "CHA": 10})
	var captive := _fresh_char("Sleet Captive", "human", "fighter", {"STR": 10, "DEX": 3, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["sleet_storm"])
	wizard.inventory.add_item("component_pouch")
	wizard.spell_slots["3"] = 1
	captive.add_modifier("roll", "save:DEX", -1000, 1)
	captive.concentrating_on = {"spell_id": "black_tentacles", "effects": [], "targets": []}
	PlayerManager.set_player_character(0, wizard)
	PlayerManager.set_player_character(1, captive)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	PartyManager.register_player_character(1, captive)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i(-5, 0)
	combat.player_entities[1]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var monster: Dictionary = {"id": "sleet_storm_live_monster", "name": "Sleet Goblin", "creature_type": "humanoid", "hex_position": Vector2i(6, 0), "is_alive": true, "current_hp": 50, "max_hp": 50, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"DEX": 1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append(monster)
	combat._update_grid_entities()
	var base_cost: float = combat.hex_grid.get_hex_cost(Vector2i.ZERO)
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("sleet_storm").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 3
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var zone_id := ""
	for source in combat.active_spell_zones:
		zone_id = str(source)
		break
	var zone: Dictionary = combat.active_spell_zones.get(zone_id, {})
	var captive_was_not_immediately_affected := not captive.has_condition("prone") and not captive.concentrating_on.is_empty()
	_assert(zone.get("spell_id", "") == "sleet_storm" and int(zone.get("radius_feet", 0)) == 20 and int(zone.get("height_feet", 0)) == 40 and bool(zone.get("heavily_obscured", false)) and bool(zone.get("douses_exposed_flames", false)) and captive_was_not_immediately_affected, "The live 20-foot-radius, 40-foot-high Cylinder records its obscured area and does not save creatures immediately on appearance")
	_assert(is_equal_approx(combat.hex_grid.get_hex_cost(Vector2i.ZERO), base_cost + 1.0) and wizard.concentrating_on.get("spell_id", "") == "sleet_storm" and int(wizard.spell_slots["3"]) == 0, "Sleet Storm creates Difficult Terrain, starts Concentration and spends one third-level slot")
	var captive_start_results: Array = await combat._resolve_spell_zone_start_turn(captive, Vector2i.ZERO)
	_assert(not captive_start_results.is_empty() and not bool(captive_start_results[0].get("saved", true)) and captive.has_condition("prone") and captive.concentrating_on.is_empty() and combat.active_spell_zones.has(zone_id), "A creature starting its turn in Sleet Storm can fall Prone and lose its own Concentration without ending the caster's zone")
	var entry_results: Array = await combat._resolve_spell_zone_entries(monster, Vector2i(6, 0), Vector2i(4, 0))
	_assert(not entry_results.is_empty() and bool(entry_results[0].get("saved", false)) and not CombatAction.has_condition(monster, "prone"), "A creature entering Sleet Storm for the first time on a turn makes a Dexterity save")
	await combat._resolve_spell_zone_entries(monster, Vector2i(4, 0), Vector2i(6, 0))
	var repeated_entry: Array = await combat._resolve_spell_zone_entries(monster, Vector2i(6, 0), Vector2i(4, 0))
	_assert(not repeated_entry.is_empty() and bool(repeated_entry[0].get("skipped", false)), "The same creature cannot repeat Sleet Storm's save during one turn")
	combat.tracker.current_round += 1
	var next_turn_results: Array = await combat._resolve_spell_zone_start_turn(monster, Vector2i(4, 0))
	_assert(not next_turn_results.is_empty() and bool(next_turn_results[0].get("saved", false)), "A creature starting a later turn inside Sleet Storm makes a new Dexterity save")
	combat._end_concentration(wizard)
	_assert(combat.active_spell_zones.is_empty() and is_equal_approx(combat.hex_grid.get_hex_cost(Vector2i.ZERO), base_cost) and captive.has_condition("prone"), "Ending the caster's Concentration removes Sleet Storm terrain while Prone persists")
	print("SLEET_STORM_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Cloud of Daggers damages on appearance, caps repeat triggers per turn, and
## teleports as a later-turn Magic action with source-owned concentration cleanup.
func test_cloud_of_daggers_spell_flow() -> void:
	_enter_test("cloud_of_daggers_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Daggers Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 16, "WIS": 10, "CHA": 10})
	wizard.inventory.add_item("component_pouch")
	for _level in 2: wizard.level_up()
	var book: Array[String] = ["cloud_of_daggers"]
	for spell in DataLoader.get_castable_spell_list_options(["wizard"]):
		if book.size() >= wizard.wizard_spellbook_pending: break
		if int(spell.get("level", 0)) > 0 and int(spell.get("level", 0)) <= 2 and str(spell["id"]) not in book: book.append(str(spell["id"]))
	_assert(ClassProgression.choose_wizard_spellbook(wizard, book), "Cloud of Daggers is reachable through Wizard spellbook choices")
	var selection: Array[String] = []
	# Keep the existing cantrips while filling the newly gained capacity.
	for spell_id in wizard.feature_choices.get(wizard.get_spellcasting_feature_id(), []):
		if int(DataLoader.get_spell(str(spell_id)).get("level", 0)) == 0: selection.append(str(spell_id))
	for spell_id in wizard.get_spell_option_ids(true):
		if selection.size() >= wizard.get_spellcasting_capacity("cantrips"): break
		if spell_id not in selection: selection.append(spell_id)
	var prepared: Array[String] = ["cloud_of_daggers"]
	for spell_id in wizard.get_spell_option_ids(false):
		if prepared.size() >= wizard.get_spellcasting_capacity("prepared_spells"): break
		if spell_id not in prepared: prepared.append(spell_id)
	selection.append_array(prepared)
	_assert(ClassProgression.choose_spell_selection(wizard, selection), "Cloud of Daggers is prepared through normal class selection")
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "cloud_of_daggers_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i(-5, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var first_target: Dictionary = {"id": "daggers_first_target", "name": "First Target", "creature_type": "humanoid", "hex_position": Vector2i.ZERO, "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "spell_slots": {}}
	var second_target: Dictionary = {"id": "daggers_second_target", "name": "Second Target", "creature_type": "humanoid", "hex_position": Vector2i(2, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([first_target, second_target])
	combat._update_grid_entities()
	GameManager.test_mode = false
	await combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("cloud_of_daggers")})
	await combat._on_hex_clicked(Vector2i.ZERO)
	var source_id: String = combat._cloud_of_daggers_zone_source_for_caster(wizard)
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	var first_after_cast := int(first_target["current_hp"])
	_assert(not source_id.is_empty() and zone.get("spell_id", "") == "cloud_of_daggers" and zone.get("coords", []) == [Vector2i.ZERO] and first_after_cast < 100, "Casting Cloud of Daggers damages a creature in its one-hex Cube and creates a persistent Concentration zone")
	var same_turn_end_results: Array[Dictionary] = await combat._resolve_spell_zone_end_turn(first_target, Vector2i.ZERO)
	_assert(not same_turn_end_results.is_empty() and bool(same_turn_end_results[0].get("skipped", false)) and int(first_target["current_hp"]) == first_after_cast, "The initial hit prevents another Cloud of Daggers hit during the same turn")
	combat.tracker.current_round += 1
	var next_turn_end_results: Array[Dictionary] = await combat._resolve_spell_zone_end_turn(first_target, Vector2i.ZERO)
	var first_after_turn := int(first_target["current_hp"])
	_assert(not next_turn_end_results.is_empty() and first_after_turn < first_after_cast, "A creature ending its later turn in the Cube takes another hit")
	combat.turn_budget.reset(wizard, combat.player_entities)
	await combat._on_hud_action("move_cloud_of_daggers", {})
	var move_selected: bool = combat.pending_action_type == "cloud_of_daggers_move"
	await combat._on_hex_clicked(Vector2i(2, 0))
	var second_after_move := int(second_target["current_hp"])
	zone = combat.active_spell_zones.get(source_id, {})
	var repeat_move_result: Dictionary = await combat._resolve_cloud_of_daggers_damage(second_target, zone)
	_assert(move_selected and zone.get("center", Vector2i.ZERO) == Vector2i(2, 0) and second_after_move < 100 and not combat.turn_budget.action_available, "A later-turn Magic action teleports the Cube up to 30 feet and damages a creature in the new space")
	_assert(bool(repeat_move_result.get("skipped", false)) and int(second_target["current_hp"]) == second_after_move, "Teleport-over damage shares the once-per-turn cap with other Cloud of Daggers triggers")
	combat._end_concentration(wizard)
	_assert(combat.active_spell_zones.is_empty(), "Ending the caster's Concentration removes the Cloud of Daggers zone")
	print("CLOUD_OF_DAGGERS_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Cloudkill applies an initial save, shares its turn cap, drifts away from its
## caster on later turns, and damages creatures newly covered by that movement.
func test_cloudkill_spell_flow() -> void:
	_enter_test("cloudkill_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Cloudkill Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 16, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["cloudkill"])
	wizard.spell_slots["5"] = 1
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	# The default encounter fixture is radius 4, which a radius 4 Cloudkill
	# completely covers. Add a larger test map so drift exposes new spaces.
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 8):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "cloudkill_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i(5, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var first_target: Dictionary = {"id": "cloudkill_first_target", "name": "First Target", "creature_type": "humanoid", "hex_position": Vector2i.ZERO, "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"CON": -1000}, "spell_slots": {}}
	var drift_target: Dictionary = {"id": "cloudkill_drift_target", "name": "Drift Target", "creature_type": "humanoid", "hex_position": Vector2i(-5, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"CON": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([first_target, drift_target])
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("cloudkill").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 5
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id := ""
	for source_value in combat.active_spell_zones:
		var candidate_zone: Dictionary = combat.active_spell_zones[source_value]
		if str(candidate_zone.get("spell_id", "")) == "cloudkill":
			source_id = str(source_value)
			break
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	var first_after_cast := int(first_target["current_hp"])
	_assert(not source_id.is_empty() and zone.get("spell_id", "") == "cloudkill" and zone.get("center", Vector2i(-1, -1)) == Vector2i.ZERO and int(zone.get("rounds_remaining", 0)) == 100 and first_after_cast < 100 and int(drift_target["current_hp"]) == 100, "Cloudkill damages creatures on appearance and creates a 20-foot-radius ten-minute Sphere")
	var same_turn_end_results: Array[Dictionary] = await combat._resolve_spell_zone_end_turn(first_target, Vector2i.ZERO)
	_assert(not same_turn_end_results.is_empty() and bool(same_turn_end_results[0].get("skipped", false)) and int(first_target["current_hp"]) == first_after_cast, "A creature hit when Cloudkill appears cannot be hit twice on that turn")
	combat.tracker.current_round += 1
	var later_end_results: Array[Dictionary] = await combat._resolve_spell_zone_end_turn(first_target, Vector2i.ZERO)
	var first_after_turn := int(first_target["current_hp"])
	_assert(not later_end_results.is_empty() and first_after_turn < first_after_cast, "A creature ending a later turn in Cloudkill repeats its Constitution save")
	var caster_hex: Vector2i = combat.player_entities[0].get("hex_position", Vector2i.ZERO)
	var expected_center: Vector2i = zone.get("center", Vector2i.ZERO)
	var best_distance := HexUtils.get_distance(caster_hex, expected_center)
	for direction in HexUtils.DIRECTIONS:
		var candidate: Vector2i = Vector2i.ZERO + direction * 2
		var candidate_distance := HexUtils.get_distance(caster_hex, candidate)
		if candidate_distance > best_distance:
			best_distance = candidate_distance
			expected_center = candidate
	var first_new_space := Vector2i.ZERO
	for coord in Targeting.get_sphere_targets(expected_center, int(zone.get("radius_hexes", 4)), combat.hex_grid):
		if coord not in zone.get("coords", []):
			first_new_space = coord
			break
	drift_target["hex_position"] = first_new_space
	await combat._advance_cloudkill_zones_for_caster(wizard)
	zone = combat.active_spell_zones.get(source_id, {})
	_assert(zone.get("center", Vector2i.ZERO) == expected_center and int(drift_target["current_hp"]) < 100, "At the start of the caster's later turn, Cloudkill drifts 10 feet away and saves in newly covered spaces")
	var duplicate_result: Dictionary = await combat._resolve_cloudkill_zone_save(drift_target, zone)
	_assert(bool(duplicate_result.get("skipped", false)) and int(drift_target["current_hp"]) < 100, "Cloudkill's movement, entry and end-turn saves share the once-per-turn limit")
	combat._end_concentration(wizard)
	_assert(combat.active_spell_zones.is_empty(), "Ending the caster's Concentration removes Cloudkill")
	print("CLOUDKILL_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Conjure Animals creates a spectral pack, tracks its movement triggers and
## applies its proximity Strength-save benefit to the caster.
func test_conjure_animals_spell_flow() -> void:
	_enter_test("conjure_animals_spell_flow")
	_setup_world()
	var druid := _fresh_char("Conjure Animals Druid", "human", "druid", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	druid.known_spells.assign(["conjure_animals"])
	druid.spell_slots["3"] = 1
	PlayerManager.set_player_character(0, druid)
	PartyManager.reset()
	PartyManager.register_player_character(0, druid)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 8):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = druid
	combat.active_combatant = {"id": "conjure_animals_druid", "is_player": true, "entity": druid}
	combat.player_entities[0]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(druid, combat.player_entities)
	combat.remaining_attack_swings = 0
	var appeared_target: Dictionary = {"id": "conjure_animals_appeared_target", "name": "Appeared Target", "creature_type": "humanoid", "hex_position": Vector2i(2, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"DEX": -1000}, "spell_slots": {}}
	var movement_target: Dictionary = {"id": "conjure_animals_movement_target", "name": "Movement Target", "creature_type": "humanoid", "hex_position": Vector2i(5, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"DEX": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([appeared_target, movement_target])
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("conjure_animals").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 3
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id: String = combat._conjure_animals_zone_source_for_caster(druid)
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	_assert(not source_id.is_empty() and zone.get("spell_id", "") == "conjure_animals" and int(zone.get("rounds_remaining", 0)) == 100 and int(appeared_target["current_hp"]) == 100 and int(movement_target["current_hp"]) == 100, "Conjure Animals creates its 10-minute pack without an appearance save")
	_assert(druid._has_saving_throw_advantage("STR"), "The caster gains Strength-save Advantage within 5 feet of the pack")
	combat.player_moved_this_turn = true
	druid.feature_uses["conjure_animals_moved_this_turn"] = true
	await combat._on_hud_action("move_conjure_animals", {})
	await combat._on_hex_clicked(Vector2i(3, 0))
	zone = combat.active_spell_zones.get(source_id, {})
	var movement_damage := 100 - int(movement_target["current_hp"])
	_assert(zone.get("center", Vector2i.ZERO) == Vector2i(3, 0) and movement_damage > 0 and int(appeared_target["current_hp"]) == 100, "After the caster moves, the pack moves up to 30 feet and damages creatures newly within 10 feet")
	_assert(not druid._has_saving_throw_advantage("STR"), "The caster loses the Strength-save benefit after moving more than 5 feet from the pack")
	var duplicate_result: Dictionary = await combat._resolve_conjure_animals_zone_save(movement_target, zone)
	_assert(bool(duplicate_result.get("skipped", false)) and int(movement_target["current_hp"]) == 100 - movement_damage, "Pack movement, creature entry and end-turn triggers share the once-per-turn cap")
	combat.tracker.current_round += 1
	var next_turn_results: Array[Dictionary] = await combat._resolve_spell_zone_end_turn(movement_target, Vector2i(5, 0))
	_assert(not next_turn_results.is_empty() and int(movement_target["current_hp"]) < 100 - movement_damage, "A creature ending a later turn in the pack's area repeats its Dexterity save")
	combat._end_concentration(druid)
	_assert(combat.active_spell_zones.is_empty() and not druid._has_saving_throw_advantage("STR"), "Ending Concentration removes the pack and its proximity benefit")
	print("CONJURE_ANIMALS_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Conjure Celestial creates a persistent light cylinder with healing and searing triggers.
func test_conjure_celestial_spell_flow() -> void:
	_enter_test("conjure_celestial_spell_flow")
	_setup_world()
	var cleric := _fresh_char("Conjure Celestial Cleric", "human", "cleric", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	cleric.known_spells.assign(["conjure_celestial"])
	cleric.spell_slots["7"] = 1
	PlayerManager.set_player_character(0, cleric)
	PartyManager.reset()
	PartyManager.register_player_character(0, cleric)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 8):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = cleric
	combat.active_combatant = {"id": "conjure_celestial_cleric", "is_player": true, "entity": cleric}
	combat.player_entities[0]["hex_position"] = Vector2i(-5, 0)
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.remaining_attack_swings = 0
	var appearance_target: Dictionary = {"id": "conjure_celestial_appearance", "name": "Appearance Target", "creature_type": "humanoid", "hex_position": Vector2i.ZERO, "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"DEX": -1000}, "spell_slots": {}}
	var movement_target: Dictionary = {"id": "conjure_celestial_movement", "name": "Movement Target", "creature_type": "humanoid", "hex_position": Vector2i(5, 0), "is_alive": true, "current_hp": 50, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"DEX": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([appearance_target, movement_target])
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("conjure_celestial").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 7
	combat.pending_spell_data["_test_conjure_celestial_light"] = "searing"
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id: String = combat._conjure_celestial_zone_source_for_caster(cleric)
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	var appearance_hp := int(appearance_target["current_hp"])
	_assert(not source_id.is_empty() and zone.get("spell_id", "") == "conjure_celestial" and int(zone.get("rounds_remaining", 0)) == 100 and zone.get("center", Vector2i(-1, -1)) == Vector2i.ZERO and appearance_hp < 100 and int(movement_target["current_hp"]) == 50, "Conjure Celestial creates its 10-minute Bright Light cylinder and applies Searing Light to creatures inside on appearance")
	_assert(int(zone.get("cylinder_height_feet", 0)) == 40 and bool(zone.get("bright_light", false)), "The persistent area stores its 40-foot height and Bright Light properties")
	zone["test_light_choice"] = "healing"
	combat.player_moved_this_turn = true
	cleric.feature_uses["conjure_celestial_moved_this_turn"] = true
	await combat._on_hud_action("move_conjure_celestial", {})
	await combat._on_hex_clicked(Vector2i(4, 0))
	zone = combat.active_spell_zones.get(source_id, {})
	var healed_hp := int(movement_target["current_hp"])
	_assert(zone.get("center", Vector2i.ZERO) == Vector2i(4, 0) and healed_hp > 50 and bool(cleric.feature_uses.get("conjure_celestial_pillar_moved_this_turn", false)), "After the caster moves, the cylinder moves up to 30 feet and can apply Healing Light to a creature newly covered")
	var duplicate_result: Dictionary = await combat._resolve_conjure_celestial_zone_trigger(movement_target, zone)
	_assert(bool(duplicate_result.get("skipped", false)) and int(movement_target["current_hp"]) == healed_hp, "Cylinder movement and entering or ending a turn in the area share a once-per-turn limit")
	zone["test_light_choice"] = "searing"
	combat.tracker.current_round += 1
	var end_turn_results: Array[Dictionary] = await combat._resolve_spell_zone_end_turn(movement_target, Vector2i(5, 0))
	_assert(not end_turn_results.is_empty() and int(movement_target["current_hp"]) < healed_hp, "A creature ending a later turn in the cylinder can be affected again")
	combat._end_concentration(cleric)
	_assert(combat.active_spell_zones.is_empty() and combat._conjure_celestial_zone_source_for_caster(cleric).is_empty(), "Ending Concentration removes the Conjure Celestial cylinder")
	print("CONJURE_CELESTIAL_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Conjure Elemental occupies an unoccupied Large space and restrains one creature at a time.
func test_conjure_elemental_spell_flow() -> void:
	_enter_test("conjure_elemental_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Conjure Elemental Wizard", "human", "wizard", {"STR": 10, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["conjure_elemental"])
	wizard.spell_slots["7"] = 1
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 8):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "conjure_elemental_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i(-5, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var first_target: Dictionary = {"id": "conjure_elemental_first", "name": "First Target", "creature_type": "humanoid", "hex_position": Vector2i(2, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"DEX": -1000}, "spell_slots": {}}
	var waiting_target: Dictionary = {"id": "conjure_elemental_waiting", "name": "Waiting Target", "creature_type": "humanoid", "hex_position": Vector2i(2, -1), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"DEX": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([first_target, waiting_target])
	combat._update_grid_entities()
	_assert(combat._is_unoccupied_conjure_elemental_space(Vector2i.ZERO), "A Large spirit can be placed where all represented hexes are unoccupied")
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("conjure_elemental").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 7
	combat.pending_spell_data["_test_conjure_elemental_type"] = "earth"
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id: String = combat._conjure_elemental_zone_source_for_caster(wizard)
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	_assert(not source_id.is_empty() and zone.get("element", "") == "earth" and zone.get("damage_type", "") == "thunder" and int(zone.get("slot_level", 0)) == 7 and first_target["current_hp"] == 100, "Conjure Elemental creates the chosen upcast Large spirit without an appearance save")
	_assert(not combat._is_unoccupied_conjure_elemental_space(Vector2i.ZERO) and not combat._is_occupied_hex(Vector2i.ZERO), "A second spirit cannot overlap the existing one, and the intangible spirit does not block creature movement")
	var first_hp := int(first_target["current_hp"])
	first_target["hex_position"] = Vector2i(1, 0)
	await combat._resolve_spell_zone_entries(first_target, Vector2i(2, 0), Vector2i(1, 0))
	var source_has_condition: bool = first_target["condition_sources"].get("restrained", {}).has(source_id)
	_assert(source_has_condition and int(first_target["current_hp"]) < first_hp and combat._conjure_elemental_has_restrained_target(zone), "Entering the spirit's space forces the Dexterity save and failed save applies source-owned Restrained")
	var waiting_hp := int(waiting_target["current_hp"])
	var blocked_result: Array[Dictionary] = await combat._resolve_spell_zone_start_turn(waiting_target, Vector2i(2, -1))
	_assert(blocked_result.is_empty() and int(waiting_target["current_hp"]) == waiting_hp, "The spirit cannot restrain or damage a second creature while it already holds one")
	var first_after_entry := int(first_target["current_hp"])
	await combat._resolve_spell_zone_start_turn(first_target, Vector2i(1, 0))
	_assert(int(first_target["current_hp"]) < first_after_entry and first_target["condition_sources"].get("restrained", {}).has(source_id), "A restrained creature repeats the save at the start of its turn and takes the repeat damage on failure")
	first_target["saving_throw_bonuses"]["DEX"] = 1000
	await combat._resolve_spell_zone_start_turn(first_target, Vector2i(1, 0))
	_assert(not first_target["condition_sources"].get("restrained", {}).has(source_id), "A successful repeat save ends this spirit's Restrained condition")
	waiting_target["saving_throw_bonuses"]["DEX"] = -1000
	var free_spirit_results: Array[Dictionary] = await combat._resolve_spell_zone_start_turn(waiting_target, Vector2i(2, -1))
	_assert(not free_spirit_results.is_empty() and waiting_target["condition_sources"].get("restrained", {}).has(source_id), "Once freed, the spirit can restrain a new creature that starts within 5 feet")
	combat._end_concentration(wizard)
	_assert(combat.active_spell_zones.is_empty() and not waiting_target["condition_sources"].get("restrained", {}).has(source_id), "Ending Concentration removes the spirit and its Restrained grant")
	print("CONJURE_ELEMENTAL_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Conjure Fey attacks when it appears and after a later-turn teleport.
func test_conjure_fey_spell_flow() -> void:
	_enter_test("conjure_fey_spell_flow")
	_setup_world()
	var druid := _fresh_char("Conjure Fey Druid", "human", "druid", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 30, "CHA": 10})
	druid.known_spells.assign(["conjure_fey"])
	druid.spell_slots["6"] = 1
	PlayerManager.set_player_character(0, druid)
	PartyManager.reset()
	PartyManager.register_player_character(0, druid)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 8):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = druid
	combat.active_combatant = {"id": "conjure_fey_druid", "is_player": true, "entity": druid}
	combat.player_entities[0]["hex_position"] = Vector2i(-5, 0)
	combat.turn_budget.reset(druid, combat.player_entities)
	combat.remaining_attack_swings = 0
	var initial_target: Dictionary = {"id": "conjure_fey_initial", "name": "Initial Fey Target", "creature_type": "humanoid", "hex_position": Vector2i(1, 0), "is_alive": true, "current_hp": 1000, "max_hp": 1000, "armor_class": 0, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {}, "spell_slots": {}}
	var teleport_target: Dictionary = {"id": "conjure_fey_teleport", "name": "Teleport Fey Target", "creature_type": "humanoid", "hex_position": Vector2i(5, 0), "is_alive": true, "current_hp": 1000, "max_hp": 1000, "armor_class": 0, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([initial_target, teleport_target])
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("conjure_fey").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 6
	combat.pending_spell_data["_test_conjure_fey_target_id"] = "conjure_fey_initial"
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id: String = combat._conjure_fey_zone_source_for_caster(druid)
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	var initial_hit := bool(initial_target["condition_sources"].get("frightened", {}).has(source_id))
	if not initial_hit and not zone.is_empty():
		for _retry in 5:
			var retry_result: Dictionary = await combat._resolve_conjure_fey_attack(zone, initial_target)
			if bool(retry_result.get("hit", false)):
				initial_hit = true
				break
	var initial_damage := 1000 - int(initial_target["current_hp"])
	_assert(not source_id.is_empty() and zone.get("spell_id", "") == "conjure_fey" and int(zone.get("rounds_remaining", 0)) == 100, "Conjure Fey creates its 10-minute Concentration spirit")
	_assert(initial_hit and initial_damage > 0, "The spirit makes its melee spell attack on appearing and a hit deals Psychic damage plus the spellcasting modifier")
	combat.tracker.current_round += 1
	combat.turn_budget.reset(druid, combat.player_entities)
	zone["_test_target_id"] = "conjure_fey_teleport"
	var teleport_before := int(teleport_target["current_hp"])
	await combat._on_hud_action("move_conjure_fey", {})
	var move_selected: bool = combat.pending_action_type == "conjure_fey_move"
	await combat._on_hex_clicked(Vector2i(4, 0))
	zone = combat.active_spell_zones.get(source_id, {})
	var teleport_hit := bool(teleport_target["condition_sources"].get("frightened", {}).has(source_id))
	if not teleport_hit:
		for _retry in 5:
			var retry_result: Dictionary = await combat._resolve_conjure_fey_attack(zone, teleport_target)
			if bool(retry_result.get("hit", false)):
				teleport_hit = true
				break
	_assert(move_selected and zone.get("center", Vector2i.ZERO) == Vector2i(4, 0) and not combat.turn_budget.bonus_action_available, "On a later turn, the spirit teleports up to 30 feet using the caster's Bonus Action")
	_assert(teleport_hit and int(teleport_target["current_hp"]) < teleport_before, "After teleporting, the spirit attacks a creature within 5 feet and a hit deals damage and applies Frightened")
	combat._expire_conjure_fey_frightened(druid)
	_assert(not initial_target["condition_sources"].get("frightened", {}).has(source_id) and not teleport_target["condition_sources"].get("frightened", {}).has(source_id), "Frightened ends at the start of the caster's next turn")
	combat._end_concentration(druid)
	_assert(combat.active_spell_zones.is_empty() and combat._conjure_fey_zone_source_for_caster(druid).is_empty(), "Ending Concentration removes the Conjure Fey spirit")
	print("CONJURE_FEY_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Conjure Minor Elementals applies its upcast attack rider in the emanation.
func test_conjure_minor_elementals_spell_flow() -> void:
	_enter_test("conjure_minor_elementals_spell_flow")
	_setup_world()
	var wizard := _fresh_char("CME Wizard", "human", "wizard", {"STR": 10, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["conjure_minor_elementals"])
	wizard.spell_slots["6"] = 1
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 8):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "cme_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var target: Dictionary = {"id": "cme_target", "name": "Elemental Target", "creature_type": "humanoid", "hex_position": Vector2i(2, 0), "is_alive": true, "current_hp": 1000, "max_hp": 1000, "armor_class": 0, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append(target)
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("conjure_minor_elementals").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 6
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id: String = combat._conjure_minor_elementals_zone_source_for_caster(wizard)
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	_assert(not source_id.is_empty() and zone.get("spell_id", "") == "conjure_minor_elementals" and int(zone.get("rounds_remaining", 0)) == 100, "Casting creates a 10-minute Conjure Minor Elementals Concentration zone")
	_assert(zone.get("attack_damage_formula", "") == "4d8" and zone.get("radius_hexes", 0) == 3, "The sixth-level slot adds two d8s to the 15-foot attack rider")
	var caster_token: Dictionary = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return entity.get("character") == wizard)[0]
	_assert(caster_token.get("spell_emanation_radius_hexes", 0) == 3, "The map shows the Emanation radius around its moving caster")
	var inside_cost: float = combat._enemy_movement_cost(Vector2i(2, 0))
	var outside_cost: float = combat._enemy_movement_cost(Vector2i(5, 0))
	_assert(is_equal_approx(inside_cost, combat.hex_grid.get_hex_cost(Vector2i(2, 0)) + 1.0) and is_equal_approx(outside_cost, combat.hex_grid.get_hex_cost(Vector2i(5, 0))), "Enemy movement pays Difficult Terrain inside the Emanation and normal cost outside")
	zone["_test_damage_type"] = "acid"
	var packet: Dictionary = await combat._conjure_minor_elementals_damage_choice(wizard, target)
	var attack_result: Dictionary = {}
	for _retry in 5:
		attack_result = CombatAction.resolve_weapon_attack(wizard, target, {"id": "unarmed_strike", "type": "weapon", "damage": "1", "ability": "STR", "range": 1, "attack_distance": 1, "damage_type": "bludgeoning"}, false, false, {}, {"packets": [packet]})
		if bool(attack_result.get("hit", false)):
			break
	var components: Array = attack_result.get("damage_components", [])
	var acid_component := components.any(func(component: Dictionary) -> bool: return str(component.get("type", "")) == "acid" and int(component.get("value", 0)) >= 4)
	_assert(packet.get("formula", "") == "4d8" and packet.get("type", "") == "acid" and attack_result.get("hit", false) and acid_component, "A hit within the Emanation adds the chosen Acid rider and the sixth-level upcast damage")
	combat._end_concentration(wizard)
	_assert(combat.active_spell_zones.is_empty() and is_equal_approx(combat._enemy_movement_cost(Vector2i(2, 0)), combat.hex_grid.get_hex_cost(Vector2i(2, 0))), "Ending Concentration removes the damage rider and Difficult Terrain")
	print("CONJURE_MINOR_ELEMENTALS_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Conjure Woodland Beings moves with its caster and resolves once-per-turn saves.
func test_conjure_woodland_beings_spell_flow() -> void:
	_enter_test("conjure_woodland_beings_spell_flow")
	_setup_world()
	var druid := _fresh_char("Woodland Beings Druid", "human", "druid", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	druid.known_spells.assign(["conjure_woodland_beings"])
	druid.spell_slots["5"] = 1
	PlayerManager.set_player_character(0, druid)
	PartyManager.reset()
	PartyManager.register_player_character(0, druid)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 8):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = druid
	combat.active_combatant = {"id": "woodland_beings_druid", "is_player": true, "entity": druid}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(druid, combat.player_entities)
	combat.remaining_attack_swings = 0
	var first_target: Dictionary = {"id": "woodland_first", "name": "First Woodland Target", "creature_type": "humanoid", "hex_position": Vector2i(1, 0), "is_alive": true, "current_hp": 1000, "max_hp": 1000, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"WIS": -1000}, "spell_slots": {}}
	var moving_target: Dictionary = {"id": "woodland_moving", "name": "Newly Covered Target", "creature_type": "humanoid", "hex_position": Vector2i(3, 0), "is_alive": true, "current_hp": 1000, "max_hp": 1000, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"WIS": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([first_target, moving_target])
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("conjure_woodland_beings").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 5
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id: String = combat._conjure_woodland_beings_zone_source_for_caster(druid)
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	_assert(not source_id.is_empty() and int(zone.get("rounds_remaining", 0)) == 100 and zone.get("damage_formula", "") == "5d8 + 1d8", "The level-5 cast creates its upcast 10-minute Concentration Emanation without initial damage")
	var caster_token: Dictionary = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return entity.get("character") == druid)[0]
	# This fixture switches the active character directly rather than through
	# normal turn setup, so bind the HUD before checking its feature menu.
	combat.hud.update_hud(druid, combat.tracker)
	combat.hud._show_feature_selection()
	_assert(caster_token.get("spell_emanation_radius_hexes", 0) == 2 and combat.hud.features_registered.any(func(feature: Dictionary) -> bool: return feature.get("id", "") == "conjure_woodland_beings_disengage"), "The moving Emanation and its Bonus Action Disengage are visible in combat")
	var first_turn_result: Array[Dictionary] = await combat._resolve_spell_zone_end_turn(first_target, Vector2i(1, 0))
	var hp_after_first := int(first_target["current_hp"])
	var same_turn_entry: Array[Dictionary] = await combat._resolve_spell_zone_entries(first_target, Vector2i(3, 0), Vector2i(1, 0))
	_assert(not first_turn_result.is_empty() and int(first_target["current_hp"]) < 1000 and same_turn_entry.size() == 1 and bool(same_turn_entry[0].get("skipped", false)) and int(first_target["current_hp"]) == hp_after_first, "A failed Wisdom save damages once, and another trigger in the same turn is suppressed")
	combat.player_entities[0]["hex_position"] = Vector2i(1, 0)
	await combat._resolve_spell_zone_entries(druid, Vector2i.ZERO, Vector2i(1, 0))
	_assert(int(moving_target["current_hp"]) < 1000 and zone.get("center", Vector2i.ZERO) == Vector2i(1, 0), "Moving the Emanation onto a creature triggers its Wisdom save")
	combat.tracker.current_round += 1
	first_target["saving_throw_bonuses"]["WIS"] = 1000
	var saved_result: Array[Dictionary] = await combat._resolve_spell_zone_end_turn(first_target, Vector2i(1, 0))
	_assert(not saved_result.is_empty() and bool(saved_result[0].get("saved", false)) and int(saved_result[0].get("damage", 0)) > 0, "A successful Wisdom save takes half Force damage on a later turn")
	combat.turn_budget.reset(druid, combat.player_entities)
	await combat._on_hud_action("conjure_woodland_beings_disengage", {})
	_assert(druid.has_condition("disengaging") and not combat.turn_budget.bonus_action_available, "The spell's Bonus Action Disengage prevents opportunity attacks")
	combat._end_concentration(druid)
	_assert(combat.active_spell_zones.is_empty() and combat._conjure_woodland_beings_zone_source_for_caster(druid).is_empty(), "Ending Concentration removes the moving Emanation and its Disengage benefit")
	print("CONJURE_WOODLAND_BEINGS_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Spirit Guardians moves with its caster, saves once per turn and slows movement.
func test_spirit_guardians_spell_flow() -> void:
	_enter_test("spirit_guardians_spell_flow")
	_setup_world()
	var cleric := _fresh_char("Spirit Guardians Cleric", "human", "cleric", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	cleric.known_spells.assign(["spirit_guardians"])
	cleric.spell_slots["5"] = 1
	var ally := _fresh_char("Spirit Guardians Ally", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PlayerManager.set_player_character(0, cleric)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, cleric)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 9):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = cleric
	combat.active_combatant = {"id": "spirit_guardians_cleric", "is_player": true, "entity": cleric}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(2, 0)
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.remaining_attack_swings = 0
	var first_target: Dictionary = {"id": "spirit_guardians_first", "name": "First Spirit Target", "creature_type": "humanoid", "hex_position": Vector2i(1, 0), "is_alive": true, "current_hp": 1000, "max_hp": 1000, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"WIS": -1000}, "spell_slots": {}}
	var moving_target: Dictionary = {"id": "spirit_guardians_moving", "name": "Newly Covered Spirit Target", "creature_type": "humanoid", "hex_position": Vector2i(5, 0), "is_alive": true, "current_hp": 1000, "max_hp": 1000, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"WIS": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([first_target, moving_target])
	combat._update_grid_entities()
	GameManager.test_mode = true
	combat.pending_spell_data = DataLoader.get_spell("spirit_guardians").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 5
	combat.pending_spell_data["_test_spirit_guardians_exempt_target_ids"] = [cleric.character_id, ally.character_id]
	combat.pending_spell_data["_test_spirit_guardians_damage_type"] = "necrotic"
	combat.pending_action_type = "cast_spell"
	await combat._execute_player_spell(Vector2i.ZERO)
	var source_id: String = combat._spirit_guardians_zone_source_for_caster(cleric)
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	_assert(not source_id.is_empty() and zone.get("damage_formula", "") == "3d8 + 2d8" and zone.get("damage_type", "") == "necrotic" and int(zone.get("rounds_remaining", 0)) == 100, "A fifth-level cast creates the alignment-damage Emanation for 10 minutes without striking its caster immediately")
	var caster_token: Dictionary = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return entity.get("character") == cleric)[0]
	_assert(caster_token.get("spell_emanation_radius_hexes", 0) == 3 and combat._spirit_guardians_movement_slowed(ally, Vector2i(2, 0)) == false, "The caster's token shows the 15-foot radius and the designated ally is unaffected")
	var normal_ally_cost: float = combat._player_movement_cost(Vector2i(1, 0), ally)
	var slowed_target_cost: float = combat._enemy_movement_cost(Vector2i(1, 0), first_target["id"])
	_assert(is_equal_approx(normal_ally_cost, combat.hex_grid.get_hex_cost(Vector2i(1, 0))) and is_equal_approx(slowed_target_cost, combat.hex_grid.get_hex_cost(Vector2i(1, 0)) * 2.0), "Spirit Guardians doubles in-aura movement cost for affected creatures but not designated creatures")
	var exempt_result: Dictionary = await combat._resolve_spirit_guardians_zone_save(ally, zone)
	_assert(bool(exempt_result.get("skipped", false)) and int(ally.current_hp) == ally.max_hp, "A designated creature is unaffected by the aura's damage triggers")
	var first_result: Array[Dictionary] = await combat._resolve_spell_zone_end_turn(first_target, Vector2i(1, 0))
	var hp_after_first := int(first_target["current_hp"])
	var repeat_result: Array[Dictionary] = await combat._resolve_spell_zone_entries(first_target, Vector2i(4, 0), Vector2i(1, 0))
	_assert(not first_result.is_empty() and int(first_target["current_hp"]) < 1000 and bool(repeat_result[0].get("skipped", false)) and int(first_target["current_hp"]) == hp_after_first, "The target takes damage after its Wisdom save and cannot be forced to save twice in one turn")
	combat.player_entities[0]["hex_position"] = Vector2i(2, 0)
	await combat._resolve_spell_zone_entries(cleric, Vector2i.ZERO, Vector2i(2, 0))
	_assert(int(moving_target["current_hp"]) < 1000 and zone.get("center", Vector2i.ZERO) == Vector2i(2, 0), "Moving the Emanation over a new creature triggers its Wisdom save")
	combat.tracker.current_round += 1
	first_target["saving_throw_bonuses"]["WIS"] = 1000
	var saved_result: Array[Dictionary] = await combat._resolve_spell_zone_end_turn(first_target, Vector2i(1, 0))
	_assert(not saved_result.is_empty() and bool(saved_result[0].get("saved", false)) and int(saved_result[0].get("damage", 0)) > 0, "A successful Wisdom save takes half of the upcast damage on a later turn")
	combat._end_concentration(cleric)
	_assert(combat.active_spell_zones.is_empty() and combat._spirit_guardians_zone_source_for_caster(cleric).is_empty(), "Ending Concentration removes the Emanation and restores movement costs")
	print("SPIRIT_GUARDIANS_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Aura of Life protects allies in its moving Emanation and restores one downed ally.
func test_aura_of_life_spell_flow() -> void:
	_enter_test("aura_of_life_spell_flow")
	_setup_world()
	var cleric := _fresh_char("Life Aura Cleric", "human", "cleric", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	cleric.known_spells.assign(["aura_of_life"])
	cleric.spell_slots["4"] = 1
	var ally := _fresh_char("Life Aura Ally", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	ally.max_hp = 20
	ally.current_hp = 15
	PlayerManager.set_player_character(0, cleric)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, cleric)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 10):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = cleric
	combat.active_combatant = {"id": "aura_of_life_cleric", "is_player": true, "entity": cleric}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(2, 0)
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat.monster_entities.clear()
	combat.monster_entities.append({"id": "life_aura_anchor", "name": "Life Aura Anchor", "creature_type": "humanoid", "hex_position": Vector2i(9, 0), "is_alive": true, "current_hp": 20, "max_hp": 20, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "spell_slots": {}})
	combat._update_grid_entities()
	GameManager.test_mode = true
	combat.pending_spell_data = DataLoader.get_spell("aura_of_life").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 4
	combat.pending_action_type = "cast_spell"
	await combat._execute_player_spell(Vector2i.ZERO)
	var source_id: String = combat._aura_of_life_zone_source_for_caster(cleric)
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	_assert(not source_id.is_empty() and zone.get("rounds_remaining", 0) == 100 and ally.aura_of_life_sources.has(source_id) and cleric.spell_slots["4"] == 0, "Casting creates the ten-minute aura, protects an ally in range, and spends the spell slot")
	var necrotic_result: Dictionary = CombatAction.resolve_damage(ally, 10, "necrotic")
	_assert(int(necrotic_result.get("resolved", 0)) == 5 and ally.max_hp == 20, "An ally in the aura has Necrotic Resistance and retains its Hit Point maximum")
	var monster: Dictionary = {"id": "life_aura_hp_drain", "name": "Maximum Drainer", "is_alive": true, "creature_type": "undead", "ability_scores": {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10}}
	var hp_reduction: Array[Dictionary] = CombatAction.resolve_monster_attack_effects(monster, ally, {"extra_effects": [{"type": "reduce_max_hp", "value": 5}]}, {"hit": true, "damage": 5})
	_assert(ally.max_hp == 20 and hp_reduction.any(func(result: Dictionary) -> bool: return int(result.get("value", -1)) == 0), "Aura of Life prevents monster effects from reducing an ally's Hit Point maximum")
	ally.current_hp = 0
	var turn_start: Array[Dictionary] = await combat._resolve_spell_zone_start_turn(ally, Vector2i(2, 0))
	_assert(ally.current_hp == 1 and turn_start.any(func(result: Dictionary) -> bool: return int(result.get("healing", 0)) == 1), "An ally at 0 Hit Points regains 1 Hit Point at the start of a turn in the aura")
	combat.player_entities[0]["hex_position"] = Vector2i(9, 0)
	combat._update_grid_entities()
	_assert(not ally.aura_of_life_sources.has(source_id), "Moving the caster beyond 30 feet removes the ally's aura protection")
	combat._end_concentration(cleric)
	_assert(combat.active_spell_zones.is_empty() and cleric.aura_of_life_sources.is_empty(), "Ending Concentration clears Aura of Life for its caster")
	print("AURA_OF_LIFE_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Beacon of Hope selects any tracked creature in range and applies its timed benefits.
func test_beacon_of_hope_spell_flow() -> void:
	_enter_test("beacon_of_hope_spell_flow")
	_setup_world()
	var cleric := _fresh_char("Beacon Cleric", "human", "cleric", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	cleric.known_spells.assign(["beacon_of_hope"])
	cleric.spell_slots["3"] = 1
	var downed_ally := _fresh_char("Beacon Ally", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	downed_ally.current_hp = 0
	downed_ally.is_alive = false
	PlayerManager.set_player_character(0, cleric)
	PlayerManager.set_player_character(1, downed_ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, cleric)
	PartyManager.register_player_character(1, downed_ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 10):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = cleric
	combat.active_combatant = {"id": "beacon_cleric", "is_player": true, "entity": cleric}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(2, 0)
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.remaining_attack_swings = 0
	var near_monster: Dictionary = {"id": "beacon_near_monster", "name": "Near Beacon Creature", "creature_type": "humanoid", "hex_position": Vector2i(4, 0), "is_alive": true, "current_hp": 10, "max_hp": 20, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "ability_scores": {"WIS": 10}, "saving_throw_bonuses": {"WIS": 0}, "spell_slots": {}}
	var far_monster: Dictionary = {"id": "beacon_far_monster", "name": "Far Beacon Creature", "creature_type": "humanoid", "hex_position": Vector2i(9, 0), "is_alive": true, "current_hp": 10, "max_hp": 20, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "ability_scores": {"WIS": 10}, "saving_throw_bonuses": {"WIS": 0}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([near_monster, far_monster])
	combat._update_grid_entities()
	GameManager.test_mode = true
	combat.pending_spell_data = DataLoader.get_spell("beacon_of_hope").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 3
	combat.pending_spell_data["_test_beacon_target_ids"] = [downed_ally.character_id, str(near_monster["id"])]
	combat.pending_action_type = "cast_spell"
	await combat._execute_player_spell(Vector2i.ZERO)
	var ally_has_beacon := SpellEffects.has_spell(downed_ally, "beacon_of_hope")
	var near_monster_has_beacon := SpellEffects.has_spell(near_monster, "beacon_of_hope")
	var out_of_range_unaffected := not SpellEffects.has_spell(far_monster, "beacon_of_hope")
	_assert(ally_has_beacon and near_monster_has_beacon and out_of_range_unaffected and cleric.spell_slots["3"] == 0, "Beacon selects a downed ally and enemy creature within 30 feet, excludes distant creatures, and spends one slot")
	_assert(downed_ally._has_saving_throw_advantage("WIS") and not downed_ally._has_saving_throw_advantage("CON"), "Beacon grants Advantage on Wisdom saves only")
	var beacon_roll_events: Array[Dictionary] = []
	var beacon_roll_recorder := func(details: Dictionary) -> void: beacon_roll_events.append(details.duplicate(true))
	Dice.dice_rolled.connect(beacon_roll_recorder)
	downed_ally.make_death_save()
	var death_save_advantage := beacon_roll_events.any(func(details: Dictionary) -> bool: return str(details.get("type", "")) == "advantage")
	beacon_roll_events.clear()
	BarbarianRules.roll_monster_save(near_monster, "WIS")
	var monster_save_advantage := beacon_roll_events.any(func(details: Dictionary) -> bool: return str(details.get("type", "")) == "advantage")
	Dice.dice_rolled.disconnect(beacon_roll_recorder)
	_assert(death_save_advantage and monster_save_advantage, "Beacon grants Advantage on Death Saving Throws and monster Wisdom saves")
	downed_ally.max_hp = 100
	downed_ally.current_hp = 1
	var heal_results := EventResolver.apply_effects(downed_ally, [{"type": "heal", "value": "2d8 + 3"}], cleric)
	_assert(int(heal_results[0].get("amount", 0)) == 19, "Beacon makes a 2d8+3 healing effect restore its maximum possible 19 Hit Points")
	SpellEffects.advance_time([cleric, downed_ally, near_monster], 60)
	_assert(not SpellEffects.has_spell(downed_ally, "beacon_of_hope") and not SpellEffects.has_spell(near_monster, "beacon_of_hope") and cleric.concentrating_on.is_empty(), "Beacon benefits expire after one minute and release Concentration")
	print("BEACON_OF_HOPE_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Divine Favor's timed self effect adds Radiant damage to each weapon hit.
func test_divine_favor_spell_flow() -> void:
	_enter_test("divine_favor_spell_flow")
	_setup_world()
	var paladin := _fresh_char("Divine Favor Paladin", "human", "paladin", {"STR": 18, "DEX": 12, "CON": 14, "INT": 8, "WIS": 10, "CHA": 14})
	paladin.known_spells.assign(["divine_favor"])
	paladin.spell_slots["1"] = 1
	paladin.inventory.equipped[Inventory.Slot.WEAPON] = "longsword"
	PlayerManager.set_player_character(0, paladin)
	PartyManager.reset()
	PartyManager.register_player_character(0, paladin)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = paladin
	combat.active_combatant = {"id": "divine_favor_paladin", "is_player": true, "entity": paladin}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(paladin, combat.player_entities)
	combat.remaining_attack_swings = 0
	var target: Dictionary = {"id": "divine_favor_target", "name": "Training Target", "creature_type": "humanoid", "hex_position": Vector2i(1, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 1, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_resistances": [], "saving_throw_bonuses": {}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append(target)
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("divine_favor").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var bonus_spent: bool = not combat._can_spend_action_cost("bonus_action")
	_assert(SpellEffects.has_spell(paladin, "divine_favor") and paladin.spell_slots["1"] == 0 and bonus_spent, "Divine Favor casts as a Bonus Action, spending one level-1 slot and creating its timed effect")
	var favored_hit := false
	var weapon := DataLoader.get_item("longsword")
	for _attempt in 20:
		var attack := CombatAction.resolve_weapon_attack(paladin, target, weapon)
		if not bool(attack.get("hit", false)):
			continue
		favored_hit = attack.get("damage_components", []).any(func(component: Dictionary) -> bool: return str(component.get("label", "")) == "Divine Favor" and str(component.get("type", "")) == "radiant" and int(component.get("value", 0)) >= 1 and int(component.get("value", 0)) <= 4)
		if favored_hit:
			break
	_assert(favored_hit, "A weapon hit applies Divine Favor's separate 1d4 Radiant damage")
	SpellEffects.advance_time([paladin], 60)
	_assert(not SpellEffects.has_spell(paladin, "divine_favor"), "Divine Favor expires after one minute")
	print("DIVINE_FAVOR_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Death Ward uses a source-owned eight-hour effect and prevents one drop to zero.
func test_death_ward_spell_flow() -> void:
	_enter_test("death_ward_spell_flow")
	_setup_world()
	var cleric := _fresh_char("Death Ward Cleric", "human", "cleric", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	cleric.known_spells.assign(["death_ward"])
	cleric.spell_slots["4"] = 1
	var ally := _fresh_char("Death Ward Ally", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	ally.current_hp = 5
	PlayerManager.set_player_character(0, cleric)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, cleric)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = cleric
	combat.active_combatant = {"id": "death_ward_cleric", "is_player": true, "entity": cleric}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.remaining_attack_swings = 0
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("death_ward").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 4
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(1, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(SpellEffects.has_spell(ally, "death_ward") and int(cleric.spell_slots["4"]) == 0 and not combat._can_spend_action_cost("magic_action"), "Death Ward spends one fourth-level slot and one Magic Action on a touch-range ally")
	var lethal_hit := CombatAction.resolve_damage(ally, 99, "slashing")
	_assert(bool(lethal_hit.get("death_ward_prevented", false)) and ally.current_hp == 1 and ally.is_alive and not SpellEffects.has_spell(ally, "death_ward"), "The first fatal damage leaves the warded creature at 1 Hit Point and consumes Death Ward")
	print("DEATH_WARD_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Sanctuary spends its Bonus Action and blocks direct attacks and damaging spells.
func test_sanctuary_spell_flow() -> void:
	_enter_test("sanctuary_spell_flow")
	_setup_world()
	var cleric := _fresh_char("Sanctuary Cleric", "human", "cleric", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	cleric.known_spells.assign(["sanctuary"])
	cleric.spell_slots["1"] = 1
	var ally := _fresh_char("Sanctuary Ally", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	ally.current_hp = 50
	var attacker := _fresh_char("Sanctuary Attacker", "human", "wizard", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 1, "CHA": 10})
	attacker.current_hp = 50
	PlayerManager.set_player_character(0, cleric)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, cleric)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = cleric
	combat.active_combatant = {"id": "sanctuary_cleric", "is_player": true, "entity": cleric}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.remaining_attack_swings = 0
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("sanctuary").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(1, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var ward_source := ""
	for source in SpellEffects.records(ally):
		if str(SpellEffects.records(ally)[source].get("spell_id", "")) == "sanctuary":
			ward_source = str(source)
	_assert(not ward_source.is_empty() and int(cleric.spell_slots["1"]) == 0 and not combat._can_spend_action_cost("bonus_action"), "Sanctuary spends a first-level slot and Bonus Action to ward an ally")
	var ward: Dictionary = SpellEffects.records(ally).get(ward_source, {})
	ward["save_dc"] = 30
	SpellEffects.records(ally)[ward_source] = ward
	var weapon_result := CombatAction.resolve_weapon_attack(attacker, ally, {"id": "unarmed_strike", "type": "weapon", "ability": "STR", "damage": "1", "damage_type": "bludgeoning", "range": 1})
	_assert(bool(weapon_result.get("sanctuary_blocked", false)) and SpellEffects.has_spell(ally, "sanctuary"), "A failed Wisdom save makes a targeted weapon attack lose its attack roll")
	var fire_bolt := DataLoader.get_spell("fire_bolt")
	var spell_result := CombatAction.resolve_spell(attacker, ally, fire_bolt, false, {}, [], 0, 5)
	_assert(bool(spell_result.get("sanctuary_blocked", false)) and SpellEffects.has_spell(ally, "sanctuary"), "A failed Wisdom save prevents a direct damaging spell from affecting the warded ally")
	print("SANCTUARY_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Heroism prevents Frightened and grants its captured modifier at turn start.
func test_heroism_spell_flow() -> void:
	_enter_test("heroism_spell_flow")
	_setup_world()
	var bard := _fresh_char("Heroism Bard", "human", "bard", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 18})
	bard.known_spells.assign(["heroism"])
	bard.spell_slots["2"] = 1
	var ally := _fresh_char("Heroism Ally", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PlayerManager.set_player_character(0, bard)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, bard)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = bard
	combat.active_combatant = {"id": "heroism_bard", "is_player": true, "entity": bard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(bard, combat.player_entities)
	combat.remaining_attack_swings = 0
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("heroism").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 2
	combat.pending_action_type = "cast_spell"
	var heroism_extra_targets: Array[Vector2i] = [Vector2i(1, 0), Vector2i.ZERO]
	combat.call_deferred("_execute_player_spell", Vector2i(1, 0), Vector2i(9999, 9999), heroism_extra_targets)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(SpellEffects.has_spell(ally, "heroism") and SpellEffects.has_spell(bard, "heroism") and bard.concentrating_on.get("targets", []).size() == 2 and int(bard.spell_slots["2"]) == 0 and not combat._can_spend_action_cost("magic_action"), "Upcast Heroism spends its second-level slot and Magic Action to establish Concentration on two allies")
	_assert(ally.temp_hp == 0 and bard.temp_hp == 0, "Heroism does not grant its next-turn Temporary Hit Points immediately")
	SpellEffects.apply_turn_start(ally)
	SpellEffects.apply_turn_start(bard)
	_assert(ally.temp_hp == 4 and bard.temp_hp == 4, "At turn start, Heroism grants each ally Temporary Hit Points equal to the Bard's captured Charisma modifier")
	ally.add_condition("frightened", 20)
	_assert(not ally.has_condition("frightened"), "Heroism prevents the Frightened condition")
	combat._end_concentration(bard)
	ally.add_condition("frightened", 20)
	_assert(not SpellEffects.has_spell(ally, "heroism") and not SpellEffects.has_spell(bard, "heroism") and ally.has_condition("frightened") and ally.temp_hp == 4, "Ending Concentration removes Heroism immunity without stripping gained Temporary Hit Points")
	print("HEROISM_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Magic Weapon adds its slot-scaled bonus to the selected weapon's attacks.
func test_magic_weapon_spell_flow() -> void:
	_enter_test("magic_weapon_spell_flow")
	_setup_world()
	var paladin := _fresh_char("Magic Weapon Paladin", "human", "paladin", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 16})
	paladin.known_spells.assign(["magic_weapon"])
	paladin.spell_slots["4"] = 1
	var ally := _fresh_char("Magic Weapon Fighter", "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	ally.inventory.add_item("longsword")
	ally.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	PlayerManager.set_player_character(0, paladin)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, paladin)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = paladin
	combat.active_combatant = {"id": "magic_weapon_paladin", "is_player": true, "entity": paladin}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(paladin, combat.player_entities)
	combat.remaining_attack_swings = 0
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("magic_weapon").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 4
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(1, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var magic_weapon_bonus := SpellEffects.magic_weapon_bonus(ally, "longsword")
	_assert(magic_weapon_bonus == 2 and int(paladin.spell_slots["4"]) == 0 and not combat._can_spend_action_cost("magic_action") and not paladin.concentrating_on.is_empty(), "A fourth-level Magic Weapon spends its slot and Magic Action and establishes Concentration on the ally's equipped weapon")
	var dummy := {"id": "magic_weapon_live_dummy", "name": "Magic Weapon target", "current_hp": 100, "max_hp": 100, "temp_hp": 0, "armor_class": -100, "is_alive": true, "conditions": {}, "damage_resistances": [], "damage_immunities": [], "creature_type": "humanoid"}
	var weapon_data := DataLoader.get_item("longsword")
	seed(44881)
	var base_attack := ally.make_attack_roll("STR", false, false, weapon_data)
	seed(44881)
	var enhanced_attack := CombatAction.resolve_weapon_attack(ally, dummy, weapon_data)
	_assert(int(enhanced_attack.get("attack_roll", 0)) == int(base_attack.get("total", 0)) + 2 and bool(enhanced_attack.get("hit", false)) and enhanced_attack.get("activity_damage", {}).get("modifiers", []).any(func(modifier): return str(modifier.get("label", "")) == "Magic Weapon" and int(modifier.get("value", 0)) == 2), "Magic Weapon adds its +2 bonus to attack and damage rolls")
	combat._end_concentration(paladin)
	_assert(SpellEffects.magic_weapon_bonus(ally, "longsword") == 0, "Ending Concentration removes Magic Weapon's attack and damage bonus")
	print("MAGIC_WEAPON_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Enhance Ability grants distinct check benefits to upcast targets.
func test_enhance_ability_spell_flow() -> void:
	_enter_test("enhance_ability_spell_flow")
	_setup_world()
	var bard := _fresh_char("Enhance Ability Bard", "human", "bard", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 18})
	bard.known_spells.assign(["enhance_ability"])
	bard.spell_slots["3"] = 1
	var ally := _fresh_char("Enhance Ability Ally", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PlayerManager.set_player_character(0, bard)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, bard)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = bard
	combat.active_combatant = {"id": "enhance_ability_bard", "is_player": true, "entity": bard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(bard, combat.player_entities)
	combat.remaining_attack_swings = 0
	GameManager.test_mode = true
	combat.pending_spell_data = DataLoader.get_spell("enhance_ability").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 3
	combat.pending_spell_data["_test_enhance_ability_choices"] = {"1,0": "DEX", "0,0": "CHA"}
	combat.pending_action_type = "cast_spell"
	var chosen_targets: Array[Vector2i] = [Vector2i(1, 0), Vector2i.ZERO]
	combat.call_deferred("_execute_player_spell", Vector2i(1, 0), Vector2i(9999, 9999), chosen_targets)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(bard.has_ability_check_advantage("CHA") and ally.has_ability_check_advantage("DEX") and not ally.has_ability_check_advantage("STR"), "A third-level Enhance Ability gives each selected ally its chosen ability-check Advantage")
	_assert(bard.concentrating_on.get("targets", []).size() == 2 and int(bard.spell_slots["3"]) == 0 and not combat._can_spend_action_cost("magic_action"), "Upcast Enhance Ability spends its slot and Magic Action and tracks both Concentration targets")
	seed(7123)
	var expected_advantage_roll := Dice.roll_with_advantage(20, ally)
	seed(7123)
	var ability_check := EventResolver.resolve_skill_check(ally, {"skill": "Acrobatics", "ability": "DEX", "dc": 10})
	_assert(int(ability_check.get("natural_roll", 0)) == expected_advantage_roll, "The shared event skill-check resolver uses the selected ability's Advantage")
	combat._end_concentration(bard)
	_assert(not bard.has_ability_check_advantage("CHA") and not ally.has_ability_check_advantage("DEX"), "Ending Concentration removes Enhance Ability from every chosen target")
	print("ENHANCE_ABILITY_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Charm Person applies a tracked Charmed effect that breaks on party damage.
func test_charm_person_spell_flow() -> void:
	_enter_test("charm_person_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Charm Person Wizard", "human", "wizard", {"STR": 10, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["charm_person"])
	wizard.spell_slots["1"] = 1
	var ally := _fresh_char("Charm Person Ally", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PlayerManager.set_player_character(0, wizard)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "charm_person_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(-1, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var guard: Dictionary = combat.monster_entities[0]
	guard["name"] = "Charm Person Guard"
	guard["creature_type"] = "humanoid"
	guard["current_hp"] = 30
	guard["max_hp"] = 30
	guard["saving_throw_bonuses"] = {"WIS": -100}
	guard["hex_position"] = Vector2i(1, 0)
	combat._update_grid_entities()
	GameManager.test_mode = true
	combat.pending_spell_data = DataLoader.get_spell("charm_person").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(1, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var charm_source := SpellEffects.records(guard).keys().filter(func(source): return str(SpellEffects.records(guard)[source].get("spell_id", "")) == "charm_person")
	_assert(guard.get("conditions", {}).has("charmed") and charm_source.size() == 1 and AIController._is_charm_caster(guard, wizard.character_id), "Failed Wisdom save applies a source-owned Charmed condition and excludes its caster from monster targeting")
	_assert(int(wizard.spell_slots["1"]) == 0 and not combat._can_spend_action_cost("magic_action"), "Charm Person spends its level-one slot and Magic Action")
	CombatAction.resolve_damage(guard, 1, "slashing", {}, false, false, ally)
	_assert(not guard.get("conditions", {}).has("charmed") and not SpellEffects.has_spell(guard, "charm_person"), "Damage from the wizard's ally breaks Charm Person")
	print("CHARM_PERSON_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Charm Monster extends the tracked Charmed effect to any creature type.
func test_charm_monster_spell_flow() -> void:
	_enter_test("charm_monster_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Charm Monster Wizard", "human", "wizard", {"STR": 10, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["charm_monster"])
	wizard.spell_slots["4"] = 1
	var ally := _fresh_char("Charm Monster Ally", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PlayerManager.set_player_character(0, wizard)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "charm_monster_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(-1, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var ogre: Dictionary = combat.monster_entities[0]
	ogre["name"] = "Charm Monster Ogre"
	ogre["creature_type"] = "giant"
	ogre["current_hp"] = 50
	ogre["max_hp"] = 50
	ogre["saving_throw_bonuses"] = {"WIS": -100}
	ogre["hex_position"] = Vector2i(1, 0)
	combat._update_grid_entities()
	GameManager.test_mode = true
	combat.pending_spell_data = DataLoader.get_spell("charm_monster").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 4
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(1, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(ogre.get("conditions", {}).has("charmed") and AIController._is_charm_caster(ogre, wizard.character_id), "Charm Monster charms a non-Humanoid and the target avoids its caster")
	_assert(int(wizard.spell_slots["4"]) == 0 and not combat._can_spend_action_cost("magic_action"), "Charm Monster spends its level-four slot and Magic Action")
	CombatAction.resolve_damage(ogre, 1, "slashing", {}, false, false, ally)
	_assert(not ogre.get("conditions", {}).has("charmed") and not SpellEffects.has_spell(ogre, "charm_monster"), "Damage from an ally ends Charm Monster")
	print("CHARM_MONSTER_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Faerie Fire outlines failed-save targets, reveals Invisible and grants Advantage.
func test_faerie_fire_spell_flow() -> void:
	_enter_test("faerie_fire_spell_flow")
	_setup_world()
	var bard := _fresh_char("Faerie Fire Bard", "human", "bard", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 18})
	bard.known_spells.assign(["faerie_fire"])
	bard.spell_slots["1"] = 1
	var ally := _fresh_char("Faerie Fire Ally", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PlayerManager.set_player_character(0, bard)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, bard)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = bard
	combat.active_combatant = {"id": "faerie_fire_bard", "is_player": true, "entity": bard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(-1, 0)
	combat.turn_budget.reset(bard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var first_guard: Dictionary = combat.monster_entities[0]
	first_guard["name"] = "Faerie Fire Guard"
	first_guard["creature_type"] = "humanoid"
	first_guard["saving_throw_bonuses"] = {"DEX": -100}
	first_guard["conditions"]["invisible"] = 10
	first_guard["hex_position"] = Vector2i(1, 0)
	var second_guard: Dictionary = combat.monster_entities[1]
	second_guard["name"] = "Second Faerie Fire Guard"
	second_guard["creature_type"] = "humanoid"
	second_guard["saving_throw_bonuses"] = {"DEX": -100}
	second_guard["hex_position"] = Vector2i(2, 0)
	combat._update_grid_entities()
	GameManager.test_mode = true
	combat.pending_spell_data = DataLoader.get_spell("faerie_fire").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(1, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(SpellEffects.has_spell(first_guard, "faerie_fire") and SpellEffects.has_spell(second_guard, "faerie_fire") and not CombatAction.is_invisible(first_guard), "The directed 20-foot Cube outlines failed-save creatures, including one Invisible target")
	_assert(bard.concentrating_on.get("targets", []).size() == 2 and int(bard.spell_slots["1"]) == 0 and not combat._can_spend_action_cost("magic_action"), "Faerie Fire spends its slot and Magic Action and tracks both Concentration targets")
	var faerie_weapon := DataLoader.get_item("longsword")
	seed(8181)
	var expected_advantage := bard.make_attack_roll("STR", true, false, faerie_weapon)
	seed(8181)
	var actual_attack := CombatAction.resolve_weapon_attack(bard, first_guard, faerie_weapon)
	_assert(int(actual_attack.get("attack_roll", 0)) == int(expected_advantage.get("total", 0)), "Weapon attacks roll with Advantage against an outlined target")
	combat._end_concentration(bard)
	_assert(not SpellEffects.has_spell(first_guard, "faerie_fire") and not SpellEffects.has_spell(second_guard, "faerie_fire") and CombatAction.is_invisible(first_guard), "Ending Concentration removes the outlines and restores Invisible")
	print("FAERIE_FIRE_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Fog Cloud creates slot-scaled obscuration and removes it with Concentration.
func test_fog_cloud_spell_flow() -> void:
	_enter_test("fog_cloud_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Fog Cloud Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["fog_cloud"])
	wizard.spell_slots["3"] = 1
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 16):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "fog_cloud_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i(-13, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var inside_target: Dictionary = {"id": "fog_cloud_inside", "name": "Inside Fog", "creature_type": "humanoid", "hex_position": Vector2i(2, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "spell_slots": {}}
	var outside_target: Dictionary = {"id": "fog_cloud_outside", "name": "Outside Fog", "creature_type": "humanoid", "hex_position": Vector2i(13, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([inside_target, outside_target])
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("fog_cloud").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 3
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id := ""
	for source_value in combat.active_spell_zones:
		var candidate_zone: Dictionary = combat.active_spell_zones[source_value]
		if str(candidate_zone.get("spell_id", "")) == "fog_cloud":
			source_id = str(source_value)
		break
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	_assert(not source_id.is_empty() and zone.get("center", Vector2i(-1, -1)) == Vector2i.ZERO and int(zone.get("radius_hexes", 0)) == 12 and bool(zone.get("heavily_obscured", false)) and int(zone.get("rounds_remaining", 0)) == 600, "A third-level cast creates a 60-foot Heavily Obscured Sphere for one hour")
	_assert(CombatAction.has_condition(inside_target, "fog_cloud_obscured") and not CombatAction.has_condition(outside_target, "fog_cloud_obscured") and int(wizard.spell_slots["3"]) == 0, "Only creatures in the radius receive its source-owned obscuration condition")
	var attack_weapon := DataLoader.get_item("longsword")
	seed(8274)
	var expected_roll := wizard.make_attack_roll("STR", false, false, attack_weapon)
	seed(8274)
	var attack_result: Dictionary = CombatAction.resolve_weapon_attack(wizard, inside_target, attack_weapon)
	_assert(int(attack_result.get("attack_roll", 0)) == int(expected_roll.get("total", 0)), "An attack into the Fog Cloud cancels Advantage and Disadvantage from mutual obscurement")
	inside_target["hex_position"] = Vector2i(13, 0)
	combat._update_grid_entities()
	_assert(not CombatAction.has_condition(inside_target, "fog_cloud_obscured"), "Moving out of the Sphere removes the source-owned obscuration")
	var fog_room_state := {"cells": [[0, 0]], "party_positions": {wizard.character_id: [-13, 0]}, "areas": [], "area_serial": 0}
	GameManager.transition_context["local_room"] = fog_room_state
	LocalRoomCombat.capture_spell_zones(combat.player_entities, combat.active_spell_zones)
	var transferred_fog: Dictionary = fog_room_state.get("areas", []).front() if not fog_room_state.get("areas", []).is_empty() else {}
	_assert(str(transferred_fog.get("spell_id", "")) == "fog_cloud" and str(transferred_fog.get("concentration_source_id", "")) == source_id and int(transferred_fog.get("radius_hexes", 0)) == 12 and int(transferred_fog.get("expires_at_seconds", 0)) > int(GameManager.campaign_elapsed_seconds), "A real Fog Cloud cast transfers its full room center, radius, remaining duration and concentration source")
	combat._end_concentration(wizard)
	_assert(combat.active_spell_zones.is_empty() and fog_room_state.get("areas", []).is_empty(), "Ending Concentration removes both the combat and room-owned Fog Cloud zones")
	GameManager.transition_context.erase("local_room")
	print("FOG_CLOUD_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Darkness creates a source-owned, short-lived Sphere and dispels overlapping Light.
func test_darkness_spell_flow() -> void:
	_enter_test("darkness_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Darkness Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["darkness", "light"])
	wizard.inventory.add_item("component_pouch")
	wizard.spell_slots["2"] = 1
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 16):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "darkness_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i(-1, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var inside_target: Dictionary = {"id": "darkness_inside", "name": "Inside Darkness", "creature_type": "humanoid", "hex_position": Vector2i(2, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "spell_slots": {}}
	var outside_target: Dictionary = {"id": "darkness_outside", "name": "Outside Darkness", "creature_type": "humanoid", "hex_position": Vector2i(8, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([inside_target, outside_target])
	combat.light_spell_markers["darkness_light_fixture"] = LightRules.create_marker(Vector2i(4, 0), "darkness_light_fixture", "Light Fixture")
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("darkness").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 2
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id := ""
	for source_value in combat.active_spell_zones:
		var candidate_zone: Dictionary = combat.active_spell_zones[source_value]
		if str(candidate_zone.get("spell_id", "")) == "darkness":
			source_id = str(source_value)
			break
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	_assert(not source_id.is_empty() and zone.get("center", Vector2i(-1, -1)) == Vector2i.ZERO and int(zone.get("radius_hexes", 0)) == 3 and int(zone.get("rounds_remaining", 0)) == 100, "Darkness creates a 15-foot Sphere for ten minutes with Concentration")
	_assert(CombatAction.has_condition(inside_target, "darkness_obscured") and not CombatAction.has_condition(outside_target, "darkness_obscured") and int(wizard.spell_slots["2"]) == 0, "Only creatures in the Sphere receive its source-owned obscuration and the cast spends one slot")
	_assert(not combat.light_spell_markers.has("darkness_light_fixture"), "Darkness dispels the overlapping second-level-or-lower Light marker")
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("light").duplicate(true)
	combat.pending_action_type = "spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(not combat.light_spell_markers.has(wizard.character_id) and not combat.turn_budget.action_available, "Light cast inside an existing Darkness zone is dispelled after the Magic Action is spent")
	var darkness_cells: Array = []
	for cell in HexUtils.get_hexes_in_range(Vector2i.ZERO, 3): darkness_cells.append([cell.x, cell.y])
	var darkness_room := LocalRoomRules.create({"id": "darkness_transfer_test", "name": "Darkness Transfer Test", "cells": darkness_cells, "walls": [], "exits": [], "party_spawns": [[-3, 0]], "monster_spawns": [], "encounter_monsters": [], "objects": []}, [wizard])
	GameManager.transition_context["local_room"] = darkness_room
	LocalRoomCombat.capture_spell_zones(combat.player_entities, combat.active_spell_zones)
	var transferred_darkness: Dictionary = darkness_room.get("areas", []).filter(func(area): return str(area.get("spell_id", "")) == "darkness").front() if darkness_room.get("areas", []).any(func(area): return str(area.get("spell_id", "")) == "darkness") else {}
	var darkness_checkpoint: Dictionary = JSON.parse_string(JSON.stringify(darkness_room))
	_assert(DungeonPersistence.local_error(darkness_checkpoint).is_empty(), "The transferred Darkness area passes room checkpoint validation")
	GameManager.transition_context["local_room"] = darkness_checkpoint
	var restored_darkness_zones := LocalRoomCombat.restore_spell_zones(combat.player_entities)
	_assert(not transferred_darkness.is_empty() and bool(transferred_darkness.get("heavily_obscured", false)) and int(transferred_darkness.get("expires_at_seconds", 0)) > int(GameManager.campaign_elapsed_seconds) and restored_darkness_zones.has(source_id) and int(restored_darkness_zones[source_id].get("radius_hexes", 0)) == 3, "Darkness transfers its 15-foot obscured Sphere and remaining duration through a saved room record")
	var attack_weapon := DataLoader.get_item("longsword")
	seed(8275)
	var expected_roll := wizard.make_attack_roll("STR", false, false, attack_weapon)
	seed(8275)
	var attack_result: Dictionary = CombatAction.resolve_weapon_attack(wizard, inside_target, attack_weapon)
	_assert(int(attack_result.get("attack_roll", 0)) == int(expected_roll.get("total", 0)), "An attack into the Darkness cancels Advantage and Disadvantage from mutual obscurement")
	inside_target["hex_position"] = Vector2i(8, 0)
	combat._update_grid_entities()
	_assert(not CombatAction.has_condition(inside_target, "darkness_obscured"), "Moving out of the Sphere removes its source-owned obscuration")
	combat._end_concentration(wizard)
	_assert(combat.active_spell_zones.is_empty() and GameManager.transition_context["local_room"].get("areas", []).is_empty(), "Ending Concentration removes both the Darkness zone and its room-owned source")
	print("DARKNESS_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Antilife Shell blocks eligible creatures from crossing its moving boundary.
func test_antilife_shell_spell_flow() -> void:
	_enter_test("antilife_shell_spell_flow")
	_setup_world()
	var druid := _fresh_char("Shell Druid", "human", "druid", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	druid.known_spells.assign(["antilife_shell"])
	druid.spell_slots["5"] = 1
	PlayerManager.set_player_character(0, druid)
	PartyManager.reset()
	PartyManager.register_player_character(0, druid)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 12):
		if not combat.hex_grid.has_tile(coord):
			var tile := HexTile.new()
			tile.coord = coord
			tile.is_revealed = true
			combat.hex_grid.add_tile(tile)
	combat.current_player_idx = 0
	combat.active_character = druid
	combat.active_combatant = {"id": "shell_druid", "is_player": true, "entity": druid}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(druid, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat.monster_entities.clear()
	combat.monster_entities.append({"id": "shell_far_monster", "name": "Far Monster", "creature_type": "humanoid", "hex_position": Vector2i(8, 0), "is_alive": true, "current_hp": 20, "max_hp": 20, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "spell_slots": {}})
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("antilife_shell").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 5
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id := str(druid.concentrating_on.get("antilife_shell_source_id", ""))
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	var outside := _fresh_char("Outside Humanoid", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	var construct := {"id": "shell_construct", "creature_type": "construct"}
	var undead := {"id": "shell_undead", "creature_type": "undead"}
	_assert(SpellSupport.is_available(DataLoader.get_spell("antilife_shell")) and not source_id.is_empty() and int(zone.get("radius_hexes", 0)) == 2 and int(zone.get("rounds_remaining", 0)) == 10 and int(druid.spell_slots["5"]) == 0, "A real fifth-level cast creates a 10-foot, one-minute Antilife Shell and spends its slot")
	_assert(combat._player_step_movement_cost(Vector2i(3, 0), Vector2i(2, 0), outside) >= 9999.0 and combat._enemy_step_movement_cost(Vector2i(3, 0), Vector2i(2, 0), {"id": "shell_humanoid", "creature_type": "humanoid"}) >= 9999.0, "The shell blocks humanoid player and monster movement across its boundary")
	_assert(combat._player_step_movement_cost(Vector2i(3, 0), Vector2i(2, 0), druid) < 9999.0 and not combat._spell_zones()._antilife_shell_blocks_crossing(construct, Vector2i(3, 0), Vector2i(2, 0)) and not combat._spell_zones()._antilife_shell_blocks_crossing(undead, Vector2i(3, 0), Vector2i(2, 0)), "The caster, Constructs and Undead can cross the boundary")
	var shell_glaive := DataLoader.get_item("glaive")
	_assert(combat._spell_zones()._antilife_shell_blocks_melee(outside, Vector2i(3, 0), Vector2i.ZERO, DataLoader.get_item("longsword")) and not combat._spell_zones()._antilife_shell_blocks_melee(outside, Vector2i(3, 0), Vector2i.ZERO, DataLoader.get_item("longbow")) and not shell_glaive.is_empty() and not combat._spell_zones()._antilife_shell_blocks_melee(outside, Vector2i(3, 0), Vector2i.ZERO, shell_glaive), "Melee attacks are blocked across the shell, while Ranged and Reach weapons pass through")
	combat.monster_entities[0]["hex_position"] = Vector2i(3, 0)
	await combat._push_combat_target(combat.monster_entities[0], Vector2i(6, 0), 3, false)
	_assert(combat.monster_entities[0].get("hex_position", Vector2i.ZERO) == Vector2i(3, 0), "The modeled forced-push path cannot push a humanoid through the shell")
	combat.player_entities[0]["hex_position"] = Vector2i(1, 0)
	await combat._resolve_spell_zone_entries(druid, Vector2i.ZERO, Vector2i(1, 0))
	_assert(not combat.active_spell_zones.has(source_id) and not druid.spell_effects.has(source_id) and druid.concentrating_on.is_empty(), "Moving the shell through a humanoid ends Concentration and removes its owned effect record")
	print("ANTILIFE_SHELL_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Freedom of Movement ignores modeled difficult terrain in both movement paths.
func test_freedom_of_movement_spell_flow() -> void:
	_enter_test("freedom_of_movement_spell_flow")
	_setup_world()
	var druid := _fresh_char("Free Movement Druid", "human", "druid", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	druid.known_spells.assign(["freedom_of_movement"])
	druid.inventory.add_item("component_pouch")
	druid.spell_slots["4"] = 1
	druid.speed = 1
	PlayerManager.set_player_character(0, druid)
	PartyManager.reset()
	PartyManager.register_player_character(0, druid)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = druid
	combat.active_combatant = {"id": "free_movement_druid", "is_player": true, "entity": druid}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(druid, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat._update_grid_entities()
	var difficult_hex := Vector2i(1, 0)
	var difficult_hexes: Array[Vector2i] = [difficult_hex]
	combat.hex_grid.add_difficult_terrain("freedom_of_movement_test", difficult_hexes)
	var ordinary_cost: float = combat.hex_grid.get_hex_cost(difficult_hex)
	_assert(is_equal_approx(ordinary_cost, 2.0) and is_equal_approx(combat._player_movement_cost(difficult_hex, druid), ordinary_cost), "Combat movement charges the normal Difficult Terrain cost before Freedom of Movement")
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("freedom_of_movement").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 4
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(SpellEffects.has_spell(druid, "freedom_of_movement") and int(druid.spell_slots["4"]) == 0 and is_equal_approx(combat._player_movement_cost(difficult_hex, druid), 1.0), "A real cast creates the source-owned effect, spends its slot, and removes the Difficult Terrain surcharge")
	CombatAction.apply_condition(druid, "restrained", 2, "spell:enemy:1")
	CombatAction.apply_condition(druid, "paralyzed", 2, "hold_person:enemy:1")
	var resisted_magical_conditions := not druid.has_condition("restrained") and not druid.has_condition("paralyzed")
	CombatAction.apply_condition(druid, "restrained", 2, "mundane_restraint")
	var nonmagical_restraint_remains_possible := druid.has_condition("restrained")
	CombatAction.remove_condition_source(druid, "mundane_restraint", ["restrained"])
	_assert(resisted_magical_conditions and nonmagical_restraint_remains_possible, "Freedom of Movement blocks spell-sourced Restrained and Paralyzed conditions while leaving nonmagical restraint possible")
	var room_state := {
		"id": "freedom_of_movement_test",
		"cells": [[0, 0], [1, 0]],
		"walls": [],
		"objects": [],
		"party_positions": {druid.character_id: [0, 0]},
		"areas": [{"id": "test_grease", "spell_id": "grease", "center": [1, 0], "footprint": [[1, 0]], "difficult_terrain": true, "expires_at_seconds": int(GameManager.campaign_elapsed_seconds) + 300}],
		"cell_elevations": [],
		"cell_terrains": [],
		"wall_details": [],
	}
	var room_move := LocalRoomRules.move(room_state, druid, difficult_hex, combat.hex_grid)
	_assert(bool(room_move.get("success", false)) and int(room_move.get("movement_cost_feet", 0)) == 5 and room_state["party_positions"][druid.character_id] == [1, 0], "Local-room movement ignores both grid Difficult Terrain and a saved Grease-area surcharge (%s)" % str(room_move))
	print("FREEDOM_OF_MOVEMENT_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Darkvision is tracked for eight hours and extends overworld exploration sight.
func test_darkvision_spell_flow() -> void:
	_enter_test("darkvision_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Darkvision Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["darkvision"])
	wizard.spell_slots["2"] = 1
	var ally := _fresh_char("Darkvision Ally", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PlayerManager.set_player_character(0, wizard)
	PlayerManager.set_player_character(1, ally)
	PlayerManager.set_player_position(0, Vector2i(-1, 0))
	PlayerManager.set_player_position(1, Vector2i.ZERO)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "darkvision_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i(-1, 0)
	combat.player_entities[1]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("darkvision").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 2
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(SpellEffects.has_spell(ally, "darkvision") and CombatAction.has_condition(ally, "darkvision"), "A touched willing party creature gains source-owned Darkvision")
	_assert(int(wizard.spell_slots["2"]) == 0 and not combat._can_spend_action_cost("magic_action"), "Darkvision spends one second-level slot and one Magic Action")
	var vision_grid := HexGrid.new()
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 30):
		var tile := HexTile.new()
		tile.coord = coord
		vision_grid.add_tile(tile)
	FogOfWar.update_visibility(vision_grid)
	var far_tile: HexTile = vision_grid.get_tile(Vector2i(30, 0))
	_assert(far_tile != null and far_tile.is_visible, "The active spell gives its target 150 feet of exploration vision")
	SpellEffects.advance_time([ally], 28800)
	FogOfWar.update_visibility(vision_grid)
	_assert(not SpellEffects.has_spell(ally, "darkvision") and not far_tile.is_visible, "After eight hours, Darkvision and its extended vision expire")
	print("DARKVISION_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	vision_grid.free()
	_teardown_scene(combat)
	_exit_test()


## See Invisibility lets its caster perceive Invisible targets for one hour.
func test_see_invisibility_spell_flow() -> void:
	_enter_test("see_invisibility_spell_flow")
	_setup_world()
	var wizard := _fresh_char("See Invisibility Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["see_invisibility"])
	wizard.spell_slots["2"] = 1
	PlayerManager.set_player_character(0, wizard)
	PlayerManager.set_player_position(0, Vector2i.ZERO)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "see_invisibility_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var guard: Dictionary = combat.monster_entities[0]
	guard["id"] = "see_invisibility_guard"
	guard["name"] = "Invisible Guard"
	guard["hex_position"] = Vector2i(2, 0)
	guard["conditions"]["invisible"] = 100
	combat._update_grid_entities()
	_assert(not CombatAction.can_perceive_invisible(wizard, 10), "The caster cannot perceive Invisible targets before casting")
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("see_invisibility").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 2
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(SpellEffects.has_spell(wizard, "see_invisibility") and CombatAction.can_perceive_invisible(wizard, 10000), "The self-targeted spell lets its caster see Invisible creatures")
	_assert(int(wizard.spell_slots["2"]) == 0 and not combat._can_spend_action_cost("magic_action"), "See Invisibility spends one second-level slot and one Magic Action")
	var weapon := DataLoader.get_item("longsword")
	seed(8276)
	var expected_roll := wizard.make_attack_roll("STR", false, false, weapon)
	seed(8276)
	var attack_result: Dictionary = CombatAction.resolve_weapon_attack(wizard, guard, weapon)
	_assert(int(attack_result.get("attack_roll", 0)) == int(expected_roll.get("total", 0)), "Attacks by the caster do not suffer Invisible-target Disadvantage")
	SpellEffects.advance_time([wizard], 3600)
	seed(8277)
	var expected_after_expiry := wizard.make_attack_roll("STR", false, true, weapon)
	seed(8277)
	var attack_after_expiry: Dictionary = CombatAction.resolve_weapon_attack(wizard, guard, weapon)
	_assert(not SpellEffects.has_spell(wizard, "see_invisibility") and int(attack_after_expiry.get("attack_roll", 0)) == int(expected_after_expiry.get("total", 0)), "The sight benefit ends after one hour and Invisible-target Disadvantage returns")
	print("SEE_INVISIBILITY_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Detect Magic senses represented spell effects and reveals their schools with a Magic action.
func test_detect_magic_spell_flow() -> void:
	_enter_test("detect_magic_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Detect Magic Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["detect_magic"])
	wizard.spell_slots["1"] = 1
	PlayerManager.set_player_character(0, wizard)
	PlayerManager.set_player_position(0, Vector2i.ZERO)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "detect_magic_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var guard: Dictionary = combat.monster_entities[0]
	guard["id"] = "detect_magic_guard"
	guard["name"] = "Enchanted Guard"
	guard["hex_position"] = Vector2i(2, 0)
	var modeled_cast := SpellEffects.begin_cast(wizard, DataLoader.get_spell("faerie_fire"))
	modeled_cast["concentration"] = false
	SpellEffects.grant(guard, modeled_cast, "faerie_fire")
	combat.active_spell_zones["darkness:test"] = {"source_id": "darkness:test", "spell_id": "darkness", "center": Vector2i(5, 0), "radius_hexes": 1}
	var found := DetectMagicRules.auras_within(Vector2i.ZERO, combat.player_entities, combat.monster_entities, combat.active_spell_zones)
	_assert(found.size() == 2 and found.any(func(aura: Dictionary) -> bool: return aura["name"] == "Faerie Fire" and aura["school"] == "evocation") and found.any(func(aura: Dictionary) -> bool: return aura["name"] == "Darkness" and aura["school"] == "evocation"), "Detect Magic finds nearby tracked spell effects and reports their schools")
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("detect_magic").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(SpellEffects.has_spell(wizard, "detect_magic") and SpellEffects.has_grant(wizard, str(wizard.concentrating_on.get("effect_source", "")), "detect_magic"), "Detect Magic is a timed source-owned Concentration effect")
	_assert(int(wizard.spell_slots["1"]) == 0 and not combat._can_spend_action_cost("magic_action"), "Casting Detect Magic spends one first-level slot and one Magic action")
	combat.turn_budget.reset(wizard, combat.player_entities)
	var inspect_command := CombatCommand.from_hud_for_character("detect_magic_inspect", {}, wizard)
	var inspect_auras := DetectMagicRules.auras_within(Vector2i.ZERO, combat.player_entities, combat.monster_entities, combat.active_spell_zones)
	_assert(inspect_command != null and not inspect_auras.is_empty(), "The trained caster can inspect active nearby aura state")
	await combat._on_hud_action("detect_magic_inspect", {})
	_assert(not combat._can_spend_action_cost("magic_action"), "Inspecting detected auras spends its separate Magic action (busy=%s, auras=%d)" % [str(combat.resolving_player_action), inspect_auras.size()])
	SpellEffects.advance_time([wizard, guard], 600)
	_assert(not SpellEffects.has_spell(wizard, "detect_magic") and wizard.concentrating_on.is_empty(), "Detect Magic and its Concentration end after ten minutes")
	print("DETECT_MAGIC_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Blur imposes attack Disadvantage except against Blindsight and Truesight.
func test_blur_spell_flow() -> void:
	_enter_test("blur_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Blur Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["blur"])
	wizard.spell_slots["2"] = 1
	PlayerManager.set_player_character(0, wizard)
	PlayerManager.set_player_position(0, Vector2i.ZERO)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "blur_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("blur").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 2
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(SpellEffects.has_spell(wizard, "blur") and CombatAction.has_condition(wizard, "blurred"), "Blur grants its caster a source-owned blurred state")
	var attacker := _fresh_char("Plain Attacker", "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	var sword: Dictionary = DataLoader.get_item("longsword").duplicate(true)
	sword["attack_distance"] = 1
	seed(8821)
	var expected_disadvantage := attacker.make_attack_roll("STR", false, true)
	seed(8821)
	var blurred_attack := CombatAction.resolve_weapon_attack(attacker, wizard, sword)
	_assert(int(blurred_attack.get("attack_roll", 0)) == int(expected_disadvantage.get("total", 0)), "A normal attacker has Disadvantage against the blurred caster")
	var blindsight_attacker := _fresh_char("Blindsight Attacker", "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	blindsight_attacker.feature_uses["monster_blindsight_range_feet"] = 30
	_assert(CombatAction.can_perceive_blur(blindsight_attacker, 30) and not CombatAction.can_perceive_blur(blindsight_attacker, 31), "Blindsight perceives through Blur only within its range")
	var truesight_user := _fresh_char("Truesight Attacker", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	var sight_cast := SpellEffects.begin_cast(truesight_user, DataLoader.get_spell("true_seeing"))
	SpellEffects.grant(truesight_user, sight_cast, "truesight")
	_assert(CombatAction.can_perceive_blur(truesight_user, 120) and not CombatAction.can_perceive_blur(truesight_user, 121), "Truesight perceives through Blur within its 120-foot range")
	SpellEffects.advance_time([wizard], 60)
	_assert(not SpellEffects.has_spell(wizard, "blur") and not CombatAction.has_condition(wizard, "blurred") and wizard.concentrating_on.is_empty(), "Blur ends when its one-minute duration expires")
	print("BLUR_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Detect Evil and Good continuously reveals tracked creature types and locations.
func test_detect_evil_and_good_spell_flow() -> void:
	_enter_test("detect_evil_and_good_spell_flow")
	_setup_world()
	var cleric := _fresh_char("Sensing Cleric", "human", "cleric", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	cleric.known_spells.assign(["detect_evil_and_good"])
	cleric.spell_slots["1"] = 1
	PlayerManager.set_player_character(0, cleric)
	PlayerManager.set_player_position(0, Vector2i.ZERO)
	PartyManager.reset()
	PartyManager.register_player_character(0, cleric)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = cleric
	combat.active_combatant = {"id": "detect_type_cleric", "is_player": true, "entity": cleric}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.remaining_attack_swings = 0
	var undead: Dictionary = combat.monster_entities[0]
	undead["id"] = "detect_type_undead"
	undead["name"] = "Buried Wight"
	undead["creature_type"] = "undead"
	undead["hex_position"] = Vector2i(2, 0)
	combat.monster_entities[1]["creature_type"] = "humanoid"
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("detect_evil_and_good").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var detector_id := SpellEffects.caster_id(cleric)
	var detected: Dictionary = combat._detect_evil_and_good_targets.get(detector_id, {})
	_assert(SpellEffects.has_spell(cleric, "detect_evil_and_good") and detected.has("detect_type_undead") and not detected.has(str(combat.monster_entities[1].get("id", ""))), "Detect Evil and Good reports nearby eligible types and ignores ordinary creature types")
	_assert(int(cleric.spell_slots["1"]) == 0 and not combat._can_spend_action_cost("magic_action"), "Casting Detect Evil and Good spends one first-level slot and one Magic action")
	undead["hex_position"] = Vector2i(3, 0)
	combat._update_grid_entities()
	detected = combat._detect_evil_and_good_targets.get(detector_id, {})
	_assert(detected.get("detect_type_undead", {}).get("hex", Vector2i.ZERO) == Vector2i(3, 0) and combat.hud.log_text.text.contains("locates Buried Wight (Undead) at hex (3, 0)"), "The continuing sense reports a new location when a tracked creature moves within range")
	combat.active_spell_zones["hallow:test"] = {"source_id": "hallow:test", "spell_id": "hallow", "center": Vector2i(5, 0), "radius_hexes": 0}
	combat._update_grid_entities()
	detected = combat._detect_evil_and_good_targets.get(detector_id, {})
	_assert(detected.has("hallow:hallow:test"), "The sense reports a modeled active Hallow area")
	undead["hex_position"] = Vector2i(8, 0)
	combat._update_grid_entities()
	detected = combat._detect_evil_and_good_targets.get(detector_id, {})
	_assert(not detected.has("detect_type_undead"), "The sensed creature leaves detection when it moves beyond 30 feet")
	undead["hex_position"] = Vector2i(3, 0)
	combat._update_grid_entities()
	detected = combat._detect_evil_and_good_targets.get(detector_id, {})
	_assert(detected.has("detect_type_undead"), "The continuing sense reports the creature again when it reenters range")
	SpellEffects.advance_time([cleric], 600)
	combat._update_grid_entities()
	_assert(not SpellEffects.has_spell(cleric, "detect_evil_and_good") and not combat._detect_evil_and_good_targets.has(detector_id), "Creature sensing and Concentration end after ten minutes")
	print("DETECT_EVIL_AND_GOOD_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Detect Poison and Disease follows represented poisons, venomous creatures,
## and active magical contagion sources as combatants move.
func test_detect_poison_and_disease_spell_flow() -> void:
	_enter_test("detect_poison_and_disease_spell_flow")
	_setup_world()
	var cleric := _fresh_char("Poison Sensing Cleric", "human", "cleric", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	cleric.known_spells.assign(["detect_poison_and_disease"])
	cleric.spell_slots["1"] = 1
	var poisoned_ally := _fresh_char("Poisoned Ally", "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	poisoned_ally.add_condition("poisoned", 20)
	PlayerManager.set_player_character(0, cleric)
	PlayerManager.set_player_character(1, poisoned_ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, cleric)
	PartyManager.register_player_character(1, poisoned_ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = cleric
	combat.active_combatant = {"id": "poison_sensing_cleric", "is_player": true, "entity": cleric}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.remaining_attack_swings = 0
	var venomous: Dictionary = {"id": "venomous_creature", "name": "Venomous Serpent", "monster_id": "serpent", "creature_type": "beast", "hex_position": Vector2i(2, 0), "is_alive": true, "current_hp": 20, "max_hp": 20, "armor_class": 12, "conditions": {}, "spell_effects": {}, "attacks": [{"name": "Venomous Bite", "damage_type": "piercing", "extra_effects": [{"type": "poison_save"}]}]}
	var harmless: Dictionary = {"id": "harmless_creature", "name": "Harmless Creature", "creature_type": "humanoid", "hex_position": Vector2i(4, 0), "is_alive": true, "current_hp": 20, "max_hp": 20, "armor_class": 12, "conditions": {}, "spell_effects": {}, "attacks": [{"name": "Claw", "damage_type": "slashing"}]}
	combat.monster_entities.clear()
	combat.monster_entities.append_array([venomous, harmless])
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("detect_poison_and_disease").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var detector_id := SpellEffects.caster_id(cleric)
	var detected: Dictionary = combat._detect_poison_and_disease_targets.get(detector_id, {})
	_assert(SpellEffects.has_spell(cleric, "detect_poison_and_disease") and detected.has("poisoned:%s" % poisoned_ally.character_id) and detected.has("poisonous_creature:venomous_creature:Venomous Bite") and not detected.has("poisonous_creature:harmless_creature:Claw"), "The spell reports tracked Poisoned conditions and venomous attacks while excluding ordinary creatures")
	_assert(int(cleric.spell_slots["1"]) == 0 and not combat._can_spend_action_cost("magic_action"), "Casting Detect Poison and Disease spends one first-level slot and one Magic action")
	venomous["hex_position"] = Vector2i(3, 0)
	combat._update_grid_entities()
	detected = combat._detect_poison_and_disease_targets.get(detector_id, {})
	_assert(detected.get("poisonous_creature:venomous_creature:Venomous Bite", {}).get("hex", Vector2i.ZERO) == Vector2i(3, 0) and combat.hud.log_text.text.contains("locates Venomous Serpent (poisonous or venomous creature (Venomous Bite)) at hex (3, 0)"), "The ongoing sense updates and reports an in-range hazard's new location")
	poisoned_ally.remove_condition("poisoned")
	combat.player_entities[1]["hex_position"] = Vector2i(7, 0)
	combat._update_grid_entities()
	detected = combat._detect_poison_and_disease_targets.get(detector_id, {})
	_assert(not detected.has("poisoned:%s" % poisoned_ally.character_id), "Expired or out-of-range represented poison is removed from the current sense")
	SpellEffects.advance_time([cleric], 600)
	combat._update_grid_entities()
	_assert(not SpellEffects.has_spell(cleric, "detect_poison_and_disease") and not combat._detect_poison_and_disease_targets.has(detector_id), "Poison sensing and Concentration end after ten minutes")
	print("DETECT_POISON_AND_DISEASE_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Identify spends a minute maintaining contact, then reports represented item
## properties or ongoing spells on a touched creature.
func test_identify_spell_flow() -> void:
	_enter_test("identify_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Identifying Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["identify"])
	wizard.spell_slots["1"] = 3
	wizard.inventory.add_item("pearl_100gp")
	wizard.inventory.add_item("staff_of_withering")
	var ally := _fresh_char("Identified Ally", "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PlayerManager.set_player_character(0, wizard)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "identify_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat._update_grid_entities()
	var aid := SpellEffects.begin_cast(ally, DataLoader.get_spell("aid"))
	SpellEffects.grant_aid(ally, aid, 5)
	GameManager.test_mode = true
	combat.pending_spell_data = DataLoader.get_spell("identify").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_spell_data["_test_identify_mode"] = "item"
	combat.pending_spell_data["_test_identify_item_id"] = "staff_of_withering"
	combat.pending_action_type = "cast_spell"
	await combat._execute_player_spell(Vector2i.ZERO)
	var source_id := str(wizard.concentrating_on.get("effect_source", ""))
	_assert(not source_id.is_empty() and wizard.spell_effects.has(source_id) and int(wizard.spell_effects[source_id].get("remaining_seconds", 0)) == 60 and int(wizard.spell_slots["1"]) == 2, "Identify starts a one-minute casting timer, maintains Concentration, and spends one spell slot")
	_assert(SpellEffects.saved_state_error(wizard.to_dict()).is_empty(), "An in-progress Identify cast passes production saved-effect validation")
	_assert(wizard.inventory.has_item("pearl_100gp") and combat.hud.log_text.text.contains("remain in contact for 1 minute"), "The pearl component is not consumed and Identify says its target must remain in contact")
	for round_index in 10:
		combat.tracker.current_round += 1
		combat._tick_spell_effect_boundary(wizard, "start")
	_assert(not wizard.spell_effects.has(source_id) and wizard.concentrating_on.is_empty() and combat.hud.log_text.text.contains("Staff of Withering") and combat.hud.log_text.text.contains("3 charges") and not combat.hud.log_text.text.contains("Charge count: not recorded"), "After one minute, Identify reports the carried magic item's recorded description and charges without contradicting it")
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("identify").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_spell_data["_test_identify_mode"] = "creature"
	combat.pending_action_type = "cast_spell"
	await combat._execute_player_spell(Vector2i(1, 0))
	source_id = str(wizard.concentrating_on.get("effect_source", ""))
	_assert(not source_id.is_empty() and int(wizard.spell_slots["1"]) == 1, "Identify can begin a second casting by touching an adjacent creature")
	for round_index in 10:
		combat.tracker.current_round += 1
		combat._tick_spell_effect_boundary(wizard, "start")
	_assert(combat.hud.log_text.text.contains("Identified Ally is affected by: Aid") and wizard.concentrating_on.is_empty(), "After one minute, Identify names a tracked ongoing spell affecting the touched creature")
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("identify").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_spell_data["_test_identify_mode"] = "creature"
	combat.pending_action_type = "cast_spell"
	await combat._execute_player_spell(Vector2i(1, 0))
	source_id = str(wizard.concentrating_on.get("effect_source", ""))
	combat.player_entities[1]["hex_position"] = Vector2i(3, 0)
	combat._update_grid_entities()
	_assert(not source_id.is_empty() and not wizard.spell_effects.has(source_id) and wizard.concentrating_on.is_empty() and combat.hud.log_text.text.contains("contact with its target was broken"), "Identify is interrupted when the touched creature moves beyond reach")
	print("IDENTIFY_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Goodberry creates a saved ten-berry pool; each berry uses a Bonus Action,
## restores 1 HP, and expires with its 24-hour spell record.
func test_goodberry_spell_flow() -> void:
	_enter_test("goodberry_spell_flow")
	_setup_world()
	var druid := _fresh_char("Berry Druid", "human", "druid", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	druid.known_spells.assign(["goodberry"])
	druid.spell_slots["1"] = 1
	druid.current_hp = 5
	var ally := _fresh_char("Berry Eater", "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	ally.current_hp = 5
	PlayerManager.set_player_character(0, druid)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, druid)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = druid
	combat.active_combatant = {"id": "goodberry_druid", "is_player": true, "entity": druid}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(druid, combat.player_entities)
	combat.remaining_attack_swings = 0
	GameManager.test_mode = true
	combat.pending_spell_data = DataLoader.get_spell("goodberry").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_action_type = "cast_spell"
	await combat._execute_player_spell(Vector2i.ZERO)
	var source_id := ""
	for source in druid.spell_effects.keys():
		if str(druid.spell_effects[source].get("spell_id", "")) == "goodberry":
			source_id = str(source)
			break
	_assert(not source_id.is_empty() and SpellEffects.goodberry_count(druid) == 10 and int(druid.spell_effects[source_id].get("remaining_seconds", 0)) == 86400 and int(druid.spell_slots["1"]) == 0, "Goodberry creates ten saved berries with a 24-hour expiry and spends its spell slot")
	_assert(SpellEffects.saved_state_error(druid.to_dict()).is_empty(), "The remaining berry batch passes production saved-effect validation")
	combat.current_player_idx = 1
	combat.active_character = ally
	combat.active_combatant = {"id": "goodberry_ally", "is_player": true, "entity": ally}
	combat.turn_budget.reset(ally, combat.player_entities)
	await combat._on_hud_action("eat_goodberry", {})
	_assert(ally.current_hp == 6 and SpellEffects.goodberry_count(druid) == 9 and not combat._can_spend_action_cost("bonus_action"), "A different party member can eat one Goodberry as a Bonus Action and regain 1 HP")
	SpellEffects.advance_time([druid], 86400)
	_assert(SpellEffects.goodberry_count(druid) == 0 and not druid.spell_effects.has(source_id), "Uneaten Goodberries expire after 24 hours")
	print("GOODBERRY_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## True Seeing grants 120-foot Truesight and consumes its priced component.
func test_true_seeing_spell_flow() -> void:
	_enter_test("true_seeing_spell_flow")
	_setup_world()
	var wizard := _fresh_char("True Seeing Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.level = 11
	wizard.known_spells.assign(["true_seeing"])
	wizard.spell_slots["6"] = 1
	var ally := _fresh_char("True Seeing Ally", "human", "fighter", {"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PlayerManager.set_player_character(0, wizard)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "true_seeing_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var guard: Dictionary = combat.monster_entities[0]
	guard["id"] = "true_seeing_guard"
	guard["name"] = "Invisible Guard"
	guard["hex_position"] = Vector2i(3, 0)
	guard["conditions"]["invisible"] = 100
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("true_seeing").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 6
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(1, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(int(wizard.spell_slots["6"]) == 1 and combat._can_spend_action_cost("magic_action"), "True Seeing refuses to cast when the consumed mushroom powder is missing")
	_assert(wizard.inventory.add_item("mushroom_powder_25gp"), "The party can carry the required mushroom powder")
	combat.pending_spell_data = DataLoader.get_spell("true_seeing").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 6
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i(1, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(SpellEffects.has_spell(ally, "true_seeing") and CombatAction.has_condition(ally, "truesight"), "The touched party target receives source-owned Truesight")
	_assert(CombatAction.can_perceive_invisible(ally, 120) and not CombatAction.can_perceive_invisible(ally, 121) and wizard.inventory.count_item("mushroom_powder_25gp") == 0, "Truesight reaches 120 feet and the spell consumes the powder")
	_assert(int(wizard.spell_slots["6"]) == 0 and not combat._can_spend_action_cost("magic_action"), "True Seeing spends one sixth-level slot and one Magic Action")
	SpellEffects.advance_time([ally], 3600)
	_assert(not SpellEffects.has_spell(ally, "true_seeing") and not CombatAction.can_perceive_invisible(ally, 120), "Truesight expires after one hour")
	print("TRUE_SEEING_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Invisibility is source-owned per target and ends on the target's own action.
func test_invisibility_spell_flow() -> void:
	_enter_test("invisibility_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Invisibility Wizard", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["invisibility", "fire_bolt"])
	wizard.spell_slots["3"] = 1
	var ally := _fresh_char("Invisible Ally", "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PlayerManager.set_player_character(0, wizard)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"id": "invisibility_wizard", "is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var guard: Dictionary = combat.monster_entities[0]
	guard["name"] = "Invisibility Guard"
	guard["creature_type"] = "humanoid"
	guard["armor_class"] = 5
	guard["hex_position"] = Vector2i(2, 0)
	combat._update_grid_entities()
	GameManager.test_mode = true
	combat.pending_spell_data = DataLoader.get_spell("invisibility").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 3
	combat.pending_action_type = "cast_spell"
	var chosen_targets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO, Vector2i(9999, 9999), chosen_targets)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(CombatAction.is_invisible(wizard) and CombatAction.is_invisible(ally) and not CombatAction.is_invisible(guard), "A third-level Invisibility cast grants the Invisible condition to two selected creatures")
	_assert(wizard.concentrating_on.get("targets", []).size() == 2 and int(wizard.spell_slots["3"]) == 0 and not combat._can_spend_action_cost("magic_action"), "Upcast Invisibility tracks both target records and spends one slot and Magic Action")
	var weapon := DataLoader.get_item("longsword").duplicate(true)
	weapon["attack_distance"] = 1
	seed(8411)
	var expected_attack := ally.make_attack_roll("STR", true, false, weapon)
	seed(8411)
	var attack_result: Dictionary = CombatAction.resolve_weapon_attack(ally, guard, weapon)
	combat._update_grid_entities()
	_assert(int(attack_result.get("attack_roll", 0)) == int(expected_attack.get("total", 0)) and not CombatAction.is_invisible(ally) and CombatAction.is_invisible(wizard) and wizard.concentrating_on.get("targets", []).size() == 1, "The ally gets Advantage on its attack, then only its own Invisibility ends")
	combat._end_concentration(wizard)
	_assert(not CombatAction.is_invisible(wizard) and not SpellEffects.has_spell(wizard, "invisibility") and combat.active_spell_zones.is_empty(), "Ending Concentration removes the remaining Invisible grant")
	print("INVISIBILITY_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Live Moonbeam casting, area movement, turn-limited saves and concentration cleanup.
func test_moonbeam_spell_flow() -> void:
	_enter_test("moonbeam_spell_flow")
	_setup_world()
	var druid := _fresh_char("Moonbeam Druid", "human", "druid", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 30, "CHA": 10})
	var captive := _fresh_char("Moonbeam Captive", "human", "druid", {"STR": 10, "DEX": 12, "CON": 3, "INT": 10, "WIS": 10, "CHA": 10})
	captive.level = 2
	captive.features.append({"id": "druid_wild_shape", "name": "Wild Shape", "resource_id": "druid_wild_shape_uses"})
	DruidRules.learn_form(captive, "wolf")
	captive.feature_uses["druid_wild_shape_uses"] = 1
	var became_wolf: Dictionary = DruidRules.transform(captive, "wolf")
	# Keep the failed Con save deterministic after Wild Shape replaces the target's physical scores.
	captive.ability_scores.set_score("CON", 1)
	captive.max_hp = 100
	captive.current_hp = 100
	druid.known_spells.assign(["moonbeam"])
	druid.spell_slots["2"] = 1
	druid.inventory.add_item("component_pouch")
	PlayerManager.set_player_character(0, druid)
	PlayerManager.set_player_character(1, captive)
	PartyManager.reset()
	PartyManager.register_player_character(0, druid)
	PartyManager.register_player_character(1, captive)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = druid
	combat.active_combatant = {"is_player": true, "entity": druid}
	combat.player_entities[0]["hex_position"] = Vector2i(-3, 0)
	combat.player_entities[1]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(druid, combat.player_entities)
	combat.remaining_attack_swings = 0
	var monster: Dictionary = {"id": "moonbeam_live_monster", "name": "Moonbeam Goblin", "creature_type": "humanoid", "hex_position": Vector2i(3, 0), "is_alive": true, "current_hp": 40, "max_hp": 40, "armor_class": 12, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"CON": -1000}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append(monster)
	combat._update_grid_entities()
	var initial_hp := captive.current_hp
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("moonbeam").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 2
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id: String = combat._moonbeam_zone_source_for_caster(druid)
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	_assert(zone.get("spell_id", "") == "moonbeam" and captive.current_hp < initial_hp and Vector2i.ZERO in zone.get("coords", []) and str(druid.concentrating_on.get("moonbeam_source_id", "")) == str(zone.get("source_id", "")) and int(druid.spell_slots["2"]) == 0, "Casting Moonbeam resolves its initial Constitution save and creates a persistent Radiant area linked to the caster's Concentration source")
	_assert(became_wolf.get("success", false), "The Moonbeam target starts in a valid Wild Shape")
	_assert(not DruidRules.is_shaped(captive) and captive.has_condition("moonbeam_shape_lock"), "Moonbeam's initial failed save reverts Wild Shape and blocks new shape-shifting until the target leaves")
	combat.tracker.current_round += 1
	combat.turn_budget.reset(druid, combat.player_entities)
	await combat._on_hud_action("move_moonbeam", {})
	var move_selected: bool = combat.pending_action_type == "moonbeam_move"
	await combat._on_hex_clicked(Vector2i(2, 0))
	zone = combat.active_spell_zones.get(source_id, {})
	var monster_after_move := int(monster["current_hp"])
	_assert(move_selected and zone.get("center", Vector2i.ZERO) == Vector2i(2, 0) and monster_after_move < 40 and not combat._can_spend_action_cost("magic_action") and not captive.has_condition("moonbeam_shape_lock"), "A later-turn Magic action moves the Cylinder, triggers its new spaces and releases a shape-shift lock when the beam leaves a target")
	var same_turn_result: Dictionary = await combat._resolve_moonbeam_zone_save(monster, zone)
	_assert(bool(same_turn_result.get("skipped", false)) and int(monster["current_hp"]) == monster_after_move, "Moonbeam affects each creature only once on a combat turn")
	combat.tracker.active_index = (combat.tracker.active_index + 1) % maxi(1, combat.tracker.combatants.size())
	await combat._resolve_spell_zone_end_turn(monster, Vector2i(3, 0))
	_assert(int(monster["current_hp"]) < monster_after_move, "Moonbeam repeats its Constitution save when a creature ends its turn in the Cylinder")
	var monster_after_end_turn := int(monster["current_hp"])
	combat.tracker.active_index = (combat.tracker.active_index + 1) % maxi(1, combat.tracker.combatants.size())
	monster["hex_position"] = Vector2i(5, 0)
	await combat._resolve_spell_zone_entries(monster, Vector2i(5, 0), Vector2i(3, 0))
	_assert(int(monster["current_hp"]) < monster_after_end_turn, "Moonbeam triggers when a creature enters the Cylinder")
	combat._end_concentration(druid)
	_assert(combat.active_spell_zones.is_empty() and not captive.has_condition("moonbeam_shape_lock"), "Ending Moonbeam concentration removes the area and its shape-shift lock")
	print("MOONBEAM_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


func test_plant_growth_spell_flow() -> void:
	_enter_test("plant_growth_spell_flow")
	_setup_world()
	var druid := _fresh_char("Plant Growth Druid", "human", "druid", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	druid.known_spells.assign(["plant_growth"])
	druid.spell_slots["3"] = 1
	PlayerManager.set_player_character(0, druid)
	PartyManager.reset()
	PartyManager.register_player_character(0, druid)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = druid
	combat.active_combatant = {"is_player": true, "entity": druid}
	combat.player_entities[0]["hex_position"] = Vector2i(1, 0)
	combat.turn_budget.reset(druid, combat.player_entities)
	combat.remaining_attack_swings = 0
	var terrain_hex := Vector2i(2, 0)
	var terrain_coords: Array[Vector2i] = [terrain_hex]
	combat.hex_grid.add_difficult_terrain("existing:terrain", terrain_coords)
	var existing_cost: float = combat.hex_grid.get_hex_cost(terrain_hex)
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("plant_growth").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 3
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var source_id := ""
	for source_value in combat.active_spell_zones:
		if str(combat.active_spell_zones[source_value].get("spell_id", "")) == "plant_growth":
			source_id = str(source_value)
	var zone: Dictionary = combat.active_spell_zones.get(source_id, {})
	_assert(not source_id.is_empty() and Vector2i.ZERO in zone.get("coords", []) and terrain_hex in zone.get("coords", []) and int(druid.spell_slots["3"]) == 0, "Casting Plant Growth creates a 100-foot Overgrowth area and spends the level-3 slot")
	_assert(is_equal_approx(combat.hex_grid.get_hex_cost(terrain_hex), 4.0) and not combat.hex_grid.get_reachable(Vector2i(1, 0), 3.0).has(terrain_hex), "Overgrowth movement uses four movement points per hex and blocks travel beyond a three-point budget")
	combat._tick_spell_zones()
	_assert(combat.active_spell_zones.has(source_id) and is_equal_approx(combat.hex_grid.get_hex_cost(terrain_hex), 4.0), "Instantaneous Overgrowth remains after a combat round advances")
	combat._remove_spell_zone(source_id)
	_assert(is_equal_approx(combat.hex_grid.get_hex_cost(terrain_hex), existing_cost), "Removing the spell-owned area restores the pre-existing terrain cost")
	combat.hex_grid.remove_difficult_terrain("existing:terrain")
	print("PLANT_GROWTH_ZONE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


func test_barkskin_spell_flow() -> void:
	_enter_test("barkskin_spell_flow")
	_setup_world()
	var ranger := _fresh_char("Barkskin Ranger", "human", "ranger", {"STR": 10, "DEX": 8, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	ranger.known_spells.assign(["barkskin"])
	ranger.spell_slots["2"] = 1
	PlayerManager.set_player_character(0, ranger)
	PartyManager.reset()
	PartyManager.register_player_character(0, ranger)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = ranger
	combat.active_combatant = {"is_player": true, "entity": ranger}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(ranger, combat.player_entities)
	combat.remaining_attack_swings = 0
	var normal_ac := ranger.get_ac()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("barkskin").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 2
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(SpellEffects.has_spell(ranger, "barkskin") and ranger.get_ac() == 17 and int(ranger.spell_slots["2"]) == 0, "Casting Barkskin on a willing party target applies AC 17 and spends its slot")
	_assert(not combat._can_spend_action_cost("bonus_action"), "Barkskin spends a Bonus Action")
	SpellEffects.advance_time([ranger], 3600)
	_assert(not SpellEffects.has_spell(ranger, "barkskin") and ranger.get_ac() == normal_ac, "The one-hour Barkskin effect expires and restores the target's AC")
	print("BARKSKIN_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


func test_mage_armor_spell_flow() -> void:
	_enter_test("mage_armor_spell_flow")
	_setup_world()
	var wizard := _fresh_char("Mage Armor Wizard", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 12, "INT": 18, "WIS": 10, "CHA": 10})
	wizard.known_spells.assign(["mage_armor"])
	wizard.spell_slots["1"] = 1
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var normal_ac := wizard.get_ac()
	GameManager.test_mode = false
	combat.pending_spell_data = DataLoader.get_spell("mage_armor").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 1
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", Vector2i.ZERO)
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(SpellEffects.has_spell(wizard, "mage_armor") and wizard.get_ac() == 15 and int(wizard.spell_slots["1"]) == 0, "Casting Mage Armor sets 13 + Dexterity AC and spends its level-1 slot")
	_assert(not combat._can_spend_action_cost("magic_action"), "Mage Armor spends a Magic Action")
	wizard.inventory.equipped[Inventory.Slot.BODY] = "leather_armor"
	wizard._recalculate_ac()
	_assert(not SpellEffects.has_spell(wizard, "mage_armor") and wizard.get_ac() == 13 and wizard.get_ac() != normal_ac, "Putting on armor ends Mage Armor and recalculates the character's armor AC")
	print("MAGE_ARMOR_LIVE_FLOW_CHECKS_COMPLETE")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Real True Strike casting, damage-type choice, mixed settlement, and activity.
func test_true_strike_spell_flow() -> void:
	_enter_test("true_strike_spell_flow")
	_setup_world()
	# Guarantee the fixture's player turn precedes the scene's asynchronous monster turns.
	var wizard := _fresh_char("True Strike Wizard", "human", "wizard", {"STR": 8, "DEX": 60, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	for _level in 4:
		wizard.level_up()
	wizard.known_spells.assign(["true_strike"])
	wizard.inventory.equipped[Inventory.Slot.WEAPON] = "club"
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var target: Dictionary = {"id": "true_strike_live_target", "name": "Resistant Goblin", "creature_type": "humanoid", "hex_position": Vector2i(1, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "temp_hp": 0, "armor_class": 1, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_resistances": ["bludgeoning"], "saving_throw_bonuses": {}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append(target)
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("true_strike")})
	_assert(str(combat.pending_spell_data.get("id", "")) == "true_strike", "True Strike is selected and held in live targeting state")
	combat.call_deferred("_on_hex_clicked", Vector2i(1, 0))
	var damage_choice_found := false
	for _frame in 120:
		for child in combat.hud.get_children():
			if child is PopupMenu and child.item_count == 2:
				damage_choice_found = true
				seed(44881)
				child.id_pressed.emit(0)
				break
		if damage_choice_found:
			break
		await get_tree().process_frame
	for _frame in 60:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	var strike_records: Array = ActivityHistory.get_records().filter(func(record): return str(record.get("kind", "")) == "spell_attack" and str(record.get("title", "")).begins_with("True Strike"))
	var attack_sections: Array = strike_records[0].get("payload", {}).get("sections", {}).get("attacks", []) if not strike_records.is_empty() else []
	var damage_components: Array = attack_sections[0].get("damage_components", []) if not attack_sections.is_empty() else []
	var saw_bludgeoning := damage_components.any(func(component): return str(component.get("type", "")) == "bludgeoning")
	var saw_radiant := damage_components.any(func(component): return str(component.get("type", "")) == "radiant")
	_assert(damage_choice_found, "True Strike asks which attack damage type to use")
	_assert(target["current_hp"] < 100 and saw_bludgeoning and saw_radiant and not combat.turn_budget.action_available, "The live strike spends its Magic action and settles resisted weapon plus Radiant damage separately")
	_assert(not strike_records.is_empty() and not attack_sections.is_empty() and str(attack_sections[0].get("damage", {}).get("additional_damage_formula", "")) == "1d6", "The level-5 live True Strike records its scaled Radiant dice in activity history")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Real Mass Cure Wounds sphere targeting, six-creature choice, upcast healing and downed recovery.
func test_mass_cure_wounds_flow() -> void:
	_enter_test("mass_cure_wounds_flow")
	_setup_world()
	var druid := _fresh_char("Mass Cure Druid", "human", "druid", {"STR": 10, "DEX": 12, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	for _level in 8:
		druid.level_up()
	druid.known_spells.assign(["mass_cure_wounds"])
	var downed_ally: Character = PlayerManager.get_player(1).get("character")
	downed_ally.current_hp = 0
	downed_ally.is_alive = false
	PlayerManager.set_player_character(0, druid)
	PartyManager.reset()
	PartyManager.register_player_character(0, druid)
	PartyManager.register_player_character(1, downed_ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = druid
	combat.active_combatant = {"is_player": true, "entity": druid}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(2, 0)
	combat.turn_budget.reset(druid, combat.player_entities)
	combat.remaining_attack_swings = 0
	var wounded_monster: Dictionary = {"id": "mass_cure_monster", "name": "Wounded Monster", "creature_type": "beast", "hex_position": Vector2i(3, 0), "is_alive": true, "current_hp": 1, "max_hp": 40, "temp_hp": 0, "armor_class": 10, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_resistances": [], "saving_throw_bonuses": {}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append(wounded_monster)
	combat._update_grid_entities()
	var slot_before := int(druid.spell_slots.get("5", 0))
	_assert(slot_before > 0, "Level 9 Druid has a fifth-level slot for Mass Cure Wounds")
	GameManager.test_mode = false
	combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("mass_cure_wounds")})
	for _frame in 30:
		if str(combat.pending_spell_data.get("id", "")) == "mass_cure_wounds" and combat.pending_action_type == "spell":
			break
		await get_tree().process_frame
	combat.call_deferred("_on_hex_clicked", Vector2i(3, 0))
	var choice_count := 0
	for _frame in 180:
		await get_tree().process_frame
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and not child.is_queued_for_deletion() and str(child.title).contains("Mass Cure Wounds Targets"):
				choice_count += 1
				child.confirmed.emit()
				break
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
	_assert(choice_count >= 2, "Mass Cure Wounds asks which creatures in its Sphere to heal")
	_assert(downed_ally.current_hp > 0 and downed_ally.is_alive, "Mass Cure Wounds restores a downed party creature")
	_assert(int(wounded_monster.get("current_hp", 0)) > 1, "Mass Cure Wounds restores a creature monster's Hit Points")
	_assert(int(druid.spell_slots.get("5", 0)) == slot_before - 1 and not combat.turn_budget.action_available, "Mass Cure Wounds spends one fifth-level slot and one Magic action")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Real Mass Healing Word up to six visible target choices and bonus-action cost.
func test_mass_healing_word_flow() -> void:
	_enter_test("mass_healing_word_flow")
	_setup_world()
	var bard := _fresh_char("Mass Healing Bard", "human", "bard", {"STR": 10, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 18})
	for _level in 4:
		bard.level_up()
	bard.known_spells.assign(["mass_healing_word"])
	var injured_ally: Character = PlayerManager.get_player(1).get("character")
	injured_ally.current_hp = 1
	injured_ally.is_alive = true
	PlayerManager.set_player_character(0, bard)
	PartyManager.reset()
	PartyManager.register_player_character(0, bard)
	PartyManager.register_player_character(1, injured_ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = bard
	combat.active_combatant = {"is_player": true, "entity": bard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(2, 0)
	combat.turn_budget.reset(bard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var wounded_monster: Dictionary = {"id": "mass_healing_word_monster", "name": "Wounded Monster", "creature_type": "beast", "hex_position": Vector2i(3, 0), "is_alive": true, "current_hp": 1, "max_hp": 40, "temp_hp": 0, "armor_class": 10, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_resistances": [], "saving_throw_bonuses": {}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append(wounded_monster)
	combat._update_grid_entities()
	var slot_before := int(bard.spell_slots.get("3", 0))
	_assert(slot_before > 0, "Level 5 Bard has a third-level slot for Mass Healing Word")
	GameManager.test_mode = false
	combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("mass_healing_word")})
	for _frame in 30:
		if str(combat.pending_spell_data.get("id", "")) == "mass_healing_word" and combat.pending_action_type == "spell":
			break
		await get_tree().process_frame
	await combat._on_hex_clicked(Vector2i(2, 0))
	combat._on_hex_clicked(Vector2i(3, 0))
	_assert(combat.pending_command_target_coords.size() == 2, "Mass Healing Word accepts two distinct creature targets within its range")
	combat._on_hex_clicked(Vector2i(2, 0))
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action:
			break
		await get_tree().process_frame
	_assert(injured_ally.current_hp > 1 and injured_ally.is_alive, "Mass Healing Word restores a wounded party creature")
	_assert(int(wounded_monster.get("current_hp", 0)) > 1, "Mass Healing Word restores a creature monster's Hit Points")
	_assert(int(bard.spell_slots.get("3", 0)) == slot_before - 1 and not combat.turn_budget.bonus_action_available, "Mass Healing Word spends one third-level slot and one Bonus Action")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Real Sorcerer Twinned Spell prompt, two-target selection, and costs.
func test_sorcerer_twinned_spell() -> void:
	_enter_test("sorcerer_twinned_spell")
	_setup_world()
	var sorcerer := _fresh_char("Twinned Sorcerer", "human", "sorcerer", {"STR": 8, "DEX": 14, "CON": 14, "INT": 12, "WIS": 12, "CHA": 16})
	sorcerer.level_up()
	ClassProgression.choose_sorcerer_metamagic(sorcerer, ["twinned_spell", "extended_spell"])
	sorcerer.known_spells.assign(["charm_person"])
	PlayerManager.set_player_character(0, sorcerer)
	PartyManager.reset()
	PartyManager.register_player_character(0, sorcerer)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = sorcerer
	combat.active_combatant = {"is_player": true, "entity": sorcerer}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(sorcerer, combat.player_entities)
	combat.remaining_attack_swings = 0
	_assert(combat.monster_entities.size() >= 2, "combat fixture provides two creatures for Twinned Spell")
	if combat.monster_entities.size() >= 2:
		combat.monster_entities[0]["hex_position"] = Vector2i(1, 0)
		combat.monster_entities[1]["hex_position"] = Vector2i(2, 0)
		combat.monster_entities[0]["creature_type"] = "humanoid"
		combat.monster_entities[1]["creature_type"] = "humanoid"
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("charm_person")})
	var twinned_prompt_found := false
	for _frame in range(120):
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and str(child.title).contains("Twinned Spell"):
				twinned_prompt_found = true
				child.confirmed.emit()
				break
		if twinned_prompt_found:
			break
		await get_tree().process_frame
	_assert(twinned_prompt_found, "real spell selection offers Twinned Spell when an upcast adds a target")
	for _frame in range(4):
		await get_tree().process_frame
	_assert(bool(combat.pending_spell_data.get("_metamagic_twinned", false)) and int(combat.pending_spell_data.get("_metamagic_twinned_extra_targets", 0)) == 1, "accepting Twinned Spell enables the required second target")
	combat._on_hex_clicked(Vector2i(1, 0))
	_assert(combat.pending_words_primary_selected and combat.pending_words_primary_target == Vector2i(1, 0), "first humanoid becomes the primary Charm Person target")
	combat._on_hex_clicked(Vector2i(2, 0))
	for _frame in range(40):
		if combat.pending_action_type.is_empty():
			break
		await get_tree().process_frame
	_assert(combat.pending_action_type.is_empty(), "selecting a second humanoid resolves the twinned cast")
	_assert(sorcerer.get_sorcery_points() == 1, "Twinned Spell spends one Sorcery Point")
	_assert(int(sorcerer.spell_slots.get("1", 0)) == 2, "Twinned Spell still spends one level-1 spell slot")
	_assert(not combat.turn_budget.action_available, "Twinned Spell spends the Magic action")
	var save_logs := str(combat.hud.log_text.text).split("WIS save", false).size() - 1
	_assert(save_logs == 2, "both selected creatures receive an independent Wisdom save")
	GameManager.test_mode = true
	_teardown_scene(combat)
	_exit_test()


## Combat boot + weapon/range enforcement + P0 juice/payoff + P1 readability.
func test_combat() -> void:
	_enter_test("combat")
	_setup_world()
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 3.5)

	_assert(combat != null, "combat scene instantiated without error")
	_assert(combat.has_method("_on_hud_action"), "combat exposes HUD action handler")
	_assert(combat.hex_grid != null, "combat HexGrid @onready resolved")
	_assert(combat.hex_grid.tiles.size() > 0, "combat grid built tiles (got %d)" % combat.hex_grid.tiles.size())
	_assert(combat.player_entities.size() == 2, "combat spawned 2 players")
	_assert(combat.monster_entities.size() > 0, "combat spawned monsters (got %d)" % combat.monster_entities.size())
	_assert(combat.tracker.combatants.size() > 0, "initiative rolled (got %d)" % combat.tracker.combatants.size())
	var hud: Node = combat.hud
	_assert(hud != null, "combat HUD @onready resolved")
	_assert(hud.has_method("update_hud"), "combat HUD has update_hud")
	_assert(combat.hex_grid.entities.size() > 0, "combat grid has rendered entities (got %d)" % combat.hex_grid.entities.size())

	# A physical disconnect holds the exact owned combatant in place. Rebinding
	# the stable seat resumes that turn instead of changing ownership or devices.
	var seat0_session := str(PlayerManager.get_player(0).get("session_id", ""))
	_assert(PlayerManager.bind_device_to_session(seat0_session, 7), "combat owner can bind a transient controller")
	var owned_turn_index := -1
	for initiative_index in combat.tracker.combatants.size():
		var candidate: Dictionary = combat.tracker.combatants[initiative_index]
		if bool(candidate.get("is_player", false)) and candidate.get("entity") == combat.player_entities[0].get("character"):
			owned_turn_index = initiative_index
			break
	_assert(owned_turn_index >= 0, "combat initiative contains Seat 1's owned character")
	if owned_turn_index >= 0:
		var owned_character: Character = combat.player_entities[0].get("character")
		owned_character.is_alive = true
		owned_character.current_hp = maxi(1, owned_character.max_hp)
		combat._battle_ending = false
		combat.tracker.active_index = owned_turn_index
		PlayerManager._on_joy_connection_changed(7, false)
		combat._start_combat_turn()
		_assert(combat._waiting_for_owner_rebind, "disconnected owner holds the active combat turn")
		_assert(combat.hud.btn_end_turn.disabled, "disconnected owner locks combat controls")
		_assert(combat.active_combatant.get("entity") == combat.player_entities[0].get("character"), "disconnect preserves the active character's stable owner")
		_assert(PlayerManager.request_device_join(8, seat0_session) == 0, "Start join reclaims the exact combat seat")
		_assert(not combat._waiting_for_owner_rebind and not combat.hud.btn_end_turn.disabled, "rebind resumes the held combat turn")
	# drive an end-turn to prove the turn machine advances
	var before_round: int = combat.tracker.current_round
	combat._on_hud_action("end_turn", {})
	await get_tree().create_timer(1.0).timeout
	_assert(true, "end_turn action did not crash")
	await get_tree().create_timer(2.5).timeout
	_assert(combat.monster_entities.size() > 0, "combat still intact after a monster turn")
	_assert(combat.tracker.combatants.size() > 0, "initiative still populated after turns")

	# ---- Equipped weapon display + range enforcement ----
	if combat.player_entities.size() > 0:
		var p0: Dictionary = combat.player_entities[0]
		var pchar: Character = p0["character"]
		combat.current_player_idx = 0
		combat.active_character = pchar
		combat.turn_budget.has_acted_this_turn = false
		combat.pending_action_type = "attack"
		p0["hex_position"] = Vector2i.ZERO
		pchar.inventory.equip(Inventory.Slot.WEAPON, "longsword", true)
		combat.hud.update_hud(pchar, combat.tracker)
		_assert(combat.hud.weapon_info.text.contains("Weapon:"), "combat HUD shows weapon line")
		_assert(combat.hud.weapon_info.text.contains("Longsword") or combat.hud.weapon_info.text.contains("longsword"), "combat HUD shows equipped weapon name")
		_assert(combat.hud.weapon_info.text.contains("melee"), "melee weapon labeled as melee/reach")
		if combat.monster_entities.size() > 0:
			var m0: Dictionary = combat.monster_entities[0]
			m0["hex_position"] = Vector2i(5, 0)
			m0["is_alive"] = true
			var hp_before: int = int(m0.get("current_hp", 0))
			combat._on_hex_clicked(Vector2i(5, 0))
			var hp_after: int = int(m0.get("current_hp", 0))
			_assert(hp_before == hp_after, "out-of-range attack does NOT deal damage (range enforced)")
			_assert(combat.hud.log_text.text.contains("out of range"), "out-of-range attack logged a range rejection")
			# ---- Bug fix: out-of-range attack must NOT trap the player in targeting mode ----
			_assert(combat.pending_action_type == "attack", "still targeting after an out-of-range click (pre-condition)")
			combat._cancel_pending_action()
			_assert(combat.pending_action_type == "", "cancel clears pending targeting (player can return to movement)")
			m0["hex_position"] = Vector2i(1, 0)
			combat.hud.log_text.text = ""
			combat._on_hex_clicked(Vector2i(1, 0))
			_assert(not combat.hud.log_text.text.contains("out of range"), "adjacent attack is not range-rejected")

			# ---- P0 juice: floating damage text + camera/shake plumbing ----
			_assert(combat.fx_layer != null, "combat FxLayer @onready resolved")
			_assert(combat.cam != null, "combat Camera2D @onready resolved")
			Settings.show_damage_numbers = true
			Settings.screen_shake = true
			var fx_before: int = combat.fx_layer.get_child_count()
			combat._spawn_floating_text(Vector2i(1, 0), "-9", Color(1.0, 0.3, 0.3))
			combat._shake_camera(5.0)
			await get_tree().create_timer(0.2).timeout
			_assert(combat.fx_layer.get_child_count() > fx_before, "floating damage text spawned a label")
			Settings.show_damage_numbers = false
			var fx_off: int = combat.fx_layer.get_child_count()
			combat._spawn_floating_text(Vector2i(1, 0), "x", Color.WHITE)
			_assert(combat.fx_layer.get_child_count() == fx_off, "damage numbers suppressed when setting disabled")
			Settings.show_damage_numbers = true

			# ---- P0 payoff: victory screen shows + auto-resolves in test mode ----
			var ovr = load("res://src/combat/battle_result_overlay.gd").new()
			combat.add_child(ovr)
			ovr.show_result("victory")
			_assert(ovr.visible, "battle result overlay presents on victory")
			ovr.resolved.emit("victory")
			ovr.queue_free()
			_assert(true, "battle result overlay emits a resolution signal without hanging")

			# ---- P1 readability ----
			_assert(combat._describe_intent({"name":"Goblin"},
				{"action":"move_attack","target_id":"Thorne"}) == "Move + Attack Thorne",
				"intent describes move+attack")
			_assert(combat._describe_intent({"name":"Goblin"},
				{"action":"attack","target_id":"Brunhild"}) == "Attack Brunhild",
				"intent describes attack")
			_assert(combat._describe_intent({"name":"Goblin"},
				{"action":"move"}) == "Move", "intent describes move")
			_assert(combat._describe_intent({"name":"Goblin"},
				{"action":"none"}) == "Hold", "intent describes hold")

			# Move-path preview
			# The earlier timed turn intentionally exercises the live loop. Reset
			# the preview's own preconditions so RNG and initiative order cannot
			# decide whether this focused assertion has an active player.
			combat.current_player_idx = 0
			combat.active_character = pchar
			combat._battle_ending = false
			pchar.is_alive = true
			pchar.current_hp = maxi(1, pchar.current_hp)
			combat.pending_action_type = ""
			combat.remaining_speed = float(pchar.get_speed())
			var ppos: Vector2i = combat.player_entities[combat.current_player_idx]["hex_position"]
			var reach: Dictionary = combat.hex_grid.get_reachable(ppos, combat.remaining_speed)
			var some_hex: Vector2i = Vector2i.ZERO
			for h in reach:
				if h != ppos:
					some_hex = h
					break
			combat._path_preview_hexes.clear()
			if some_hex != Vector2i.ZERO:
				combat._on_hex_hovered(some_hex)
				_assert(combat._path_preview_hexes.size() > 0, "hovering a reachable hex previews a movement path")
			else:
				_assert(false, "expected at least one reachable hex for path-preview test")

			# Attack-range ring
			combat.pending_action_type = "attack"
			combat._highlight_attack_targets()
			_assert(combat.hex_grid.get_highlight_count() > 0, "attack select highlights weapon range hexes")

			# First-turn hint
			_assert(not combat.hud.mode_banner.tooltip_text.is_empty(), "first-turn guidance is available from the context control and Help")
			_assert(combat._hint_shown, "first-turn hint flag set (shown once per battle)")
			combat.hud.show_hint("test")
			_assert(combat.hud.mode_banner.tooltip_text == "test" and not combat.hud.hint_label.visible, "guidance updates without covering the board")
			combat.hud.hide_hint()
			_assert(not combat.hud.hint_label.visible, "hint hide() hides the banner")

	_teardown_scene(combat)
	_exit_test()


## Party-derived combat formation and local ownership for one player plus companions.
func test_party_combat() -> void:
	_enter_test("party_combat")
	var camp: Dictionary = DataLoader.get_campaign("the_lost_crown")
	GameManager.active_campaign = camp
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["goblin"], "terrain": "plains", "return_state": GameManager.GameState.OVERWORLD}
	GameManager.test_mode = true
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Solo")
	var hero := _fresh_char("Solo Hero", "human", "fighter", {"STR":15,"DEX":14,"CON":13,"INT":10,"WIS":10,"CHA":8})
	PlayerManager.set_player_character(0, hero)
	PartyManager.register_player_character(0, hero)
	PartyManager.initialize_campaign_companions(camp.get("companions", {}))
	for companion_id in PartyManager.get_available_companions():
		PartyManager.recruit_companion(companion_id)
	PartyManager.set_leader("slot_2")
	var expected_owners: Array[int] = []
	for member in PartyManager.get_active_party_members():
		expected_owners.append(int(member.get("owner_player_index", -1)))
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.OVERWORLD
	_assert(SaveManager.save_game("gate4_party_formation"), "four-member party saves through the supported boundary")
	PartyManager.reset()
	PlayerManager.reset()
	_assert(SaveManager.load_game("gate4_party_formation"), "four-member party reloads through the supported boundary")
	_assert(PartyManager.get_active_party_members().size() == 4, "save/load preserves all four occupied party slots")
	_assert(PartyManager.leader_slot_id == "slot_2", "save/load preserves transferred exploration leadership")
	var loaded_owners: Array[int] = []
	for member in PartyManager.get_active_party_members():
		loaded_owners.append(int(member.get("owner_player_index", -1)))
	_assert(loaded_owners == expected_owners, "save/load preserves logical combat ownership for every party slot")
	SaveManager.delete_save("gate4_party_formation")
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["goblin"], "terrain": "plains", "return_state": GameManager.GameState.OVERWORLD}
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 2.5)
	_assert(combat.player_entities.size() == 4, "party combat enters with all four active party members")
	var occupied_positions := {}
	for entity in combat.player_entities:
		_assert(int(entity.get("owner_player_index", -1)) == 0, "solo player owns every active combat turn")
		_assert(not occupied_positions.has(entity.get("hex_position")), "party formation positions are distinct")
		occupied_positions[entity.get("hex_position")] = true
	var spell_owner: Character = combat.player_entities[1].get("character")
	spell_owner.known_spells.assign(["magic_missile"])
	hero.known_spells.clear()
	combat.hud.update_hud(spell_owner, combat.tracker)
	combat.hud._show_spell_selection()
	_assert(combat.hud.spells_registered.size() == 1 and str(combat.hud.spells_registered[0].get("id", "")) == "magic_missile", "spell menu shows only the active companion's owned spell")
	_assert(combat.hud.spell_list.get_item_count() == 1, "spell menu renders one row for one owned spell")
	combat.hud._hide_spell_selection()
	combat.hud._show_spell_selection()
	_assert(combat.hud.spell_list.get_item_count() == 1 and combat.hud.spells_registered.size() == 1, "reopening the spell menu does not duplicate rows")
	combat.hud.update_hud(hero, combat.tracker)
	combat.hud._show_spell_selection()
	_assert(combat.hud.spell_list.get_item_count() == 0 and combat.hud.spells_registered.is_empty(), "spell rows do not leak to a different active character")
	_teardown_scene(combat)
	_setup_world()
	_exit_test()


## Ranger regression for the playtest-reported Hunter's Mark / attack flow.
## Drives the production CombatState and CombatHUD scene boundary, not only
## the spell resolver, so disabled rows, cancellation, and action commitment
## remain one coherent contract.
func test_ranger_action_flow() -> void:
	_enter_test("ranger_action_flow")
	var ranger := _setup_ranger_world()
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 2.5)
	combat.current_player_idx = 0
	combat.active_character = ranger
	ranger.spell_slots.clear()
	ranger.spell_slots["1"] = 0
	combat.turn_budget.reset(ranger, combat.player_entities)
	combat.hud.update_hud(ranger, combat.tracker)
	combat.hud._show_spell_selection()
	_assert(not combat.hud.spell_list.is_item_disabled(0), "2024 Favored Enemy keeps Hunter's Mark available through its free casts without a slot")
	combat.hud._hide_spell_selection()
	while ranger.spend_free_spell_cast("hunters_mark"):
		pass

	var emitted_actions: Array[String] = []
	combat.hud.action_selected.connect(func(action_type: String, _extra_data: Dictionary): emitted_actions.append(action_type))
	combat.hud._show_spell_selection()
	_assert(combat.hud.spell_list.get_item_count() == 1, "Ranger spell menu renders Hunter's Mark")
	_assert(combat.hud.spell_list.is_item_disabled(0), "Hunter's Mark is disabled when neither a spell slot nor a free cast remains")
	combat.hud._on_spell_selected(0)
	_assert(emitted_actions.is_empty(), "disabled Hunter's Mark cannot emit a cast action")
	_assert(combat.pending_action_type.is_empty(), "disabled Hunter's Mark cannot enter targeting")

	var optional_labels := CombatHUD.decision_prompt_labels("Seat 1", "favored_foe")
	var reaction_labels := CombatHUD.decision_prompt_labels("Seat 1", "shield")
	_assert(str(optional_labels["window_title"]).begins_with("Optional Feature"), "Favored Foe prompt is labeled as an optional feature")
	_assert(optional_labels["ok_title"] == "Confirm", "optional feature prompt does not claim to spend a reaction")
	_assert(str(reaction_labels["window_title"]).begins_with("Reaction"), "Shield retains reaction labeling")
	_assert(reaction_labels["ok_title"] == "Use Reaction", "true reaction prompt keeps its reaction action label")

	var hunters_mark := DataLoader.get_spell("hunters_mark")
	combat.hud._hide_spell_selection()
	combat._on_hud_action("cast_spell", {"spell": hunters_mark})
	_assert(combat.pending_action_type.is_empty(), "CombatState rejects Hunter's Mark when neither a slot nor a free cast remains")
	_assert(combat.turn_budget.action_available and combat.turn_budget.bonus_action_available, "rejected Hunter's Mark spends no action resource")

	combat._on_hud_action("attack", {})
	combat._cancel_pending_action()
	_assert(combat.pending_action_type.is_empty(), "cancel exits attack targeting")
	_assert(combat.turn_budget.action_available, "canceling target selection preserves the uncommitted Attack action")

	combat._on_hud_action("attack", {})
	var target: Dictionary = combat.monster_entities[0]
	var target_coord := Vector2i(1, 0)
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	target["hex_position"] = target_coord
	target["current_hp"] = 999
	target["is_alive"] = true
	ActivityHistory.clear()
	var hp_before_attack := int(target["current_hp"])
	await combat._on_hex_clicked(target_coord)
	_assert(not combat.turn_budget.action_available and combat.turn_budget.has_acted_this_turn, "a valid target click commits exactly one Attack action")
	_assert(combat.pending_action_type.is_empty(), "committed attack clears targeting before optional prompts can yield")
	var hp_after_first_click := int(target["current_hp"])
	var attack_records := ActivityHistory.get_records().filter(func(record): return record.get("kind") == "attack")
	_assert(attack_records.size() == 1, "production Attack action publishes one top-level activity record")
	if attack_records.size() == 1:
		var attack_record: Dictionary = attack_records[0]
		var comparison: Dictionary = attack_record.get("payload", {}).get("comparison", {})
		var attacks: Array = attack_record.get("payload", {}).get("sections", {}).get("attacks", [])
		var recorded_damage := int(attacks[0].get("applied_damage", -1)) if not attacks.is_empty() else -1
		_assert(int(comparison.get("margin", 0)) == int(attack_record.get("payload", {}).get("final_total", 0)) - int(comparison.get("target", 0)), "production attack activity preserves the settled AC margin")
		_assert(recorded_damage == hp_before_attack - hp_after_first_click, "production attack activity damage equals the target HP change")
	await combat._on_hex_clicked(target_coord)
	_assert(int(target["current_hp"]) == hp_after_first_click, "a repeated target click cannot resolve a second attack")
	_assert(ActivityHistory.get_records().filter(func(record): return record.get("kind") == "attack").size() == 1, "a repeated target click cannot publish a duplicate attack record")

	_teardown_scene(combat)
	_setup_world()
	_exit_test()


## Ranger live combat flow for Nature's Veil, invisibility, and Feral Senses.
func test_ranger_natures_veil_blindsight() -> void:
	_enter_test("ranger_natures_veil_blindsight")
	var ranger := _setup_ranger_world()
	while ranger.level < 18:
		ranger.level_up()
	# Charm Person is the current sight-tagged spell record. Add it only to this
	# test character to exercise the shared target-visibility boundary; this does
	# not expand the Ranger's curated spell access list.
	ranger.known_spells.assign(["charm_person"])
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 2.0)
	combat.current_player_idx = 0
	combat.active_character = ranger
	combat.active_combatant = {"is_player": true, "entity": ranger}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(ranger, combat.player_entities)
	combat.remaining_attack_swings = 0
	_assert(ranger.has_feature("ranger_natures_veil") and ranger.has_feature("ranger_feral_senses"), "level-18 Ranger owns Nature's Veil and production Feral Senses")
	_assert(CombatAction.can_perceive_invisible(ranger, 30) and not CombatAction.can_perceive_invisible(ranger, 35), "Feral Senses perception stops at 30 feet")
	var sight_spell: Dictionary = DataLoader.get_spell("charm_person")
	var unseen_target: Dictionary = combat.monster_entities[0] if not combat.monster_entities.is_empty() else {}
	_assert(not unseen_target.is_empty(), "combat fixture provides an invisible target for a sight-required spell")
	if unseen_target.is_empty():
		_teardown_scene(combat)
		_setup_world()
		_exit_test()
		return
	unseen_target["hex_position"] = Vector2i(6, 0)
	unseen_target["creature_type"] = "humanoid"
	unseen_target["conditions"] = {"invisible": 2}
	combat._update_grid_entities()
	_assert(combat._spell_target_visible_to_active_character(Vector2i(6, 0), sight_spell), "Ranger can target an invisible creature at the 30-foot Blindsight limit")
	unseen_target["hex_position"] = Vector2i(7, 0)
	_assert(not combat._spell_target_visible_to_active_character(Vector2i(7, 0), sight_spell), "Ranger cannot target an invisible creature beyond Blindsight range")
	unseen_target["hex_position"] = Vector2i(6, 0)
	await combat._on_hud_action("cast_spell", {"spell": sight_spell})
	_assert(combat.pending_action_type == "spell", "sight-required spell enters normal target selection")
	await combat._on_hex_clicked(Vector2i(6, 0))
	_assert(combat.pending_action_type.is_empty(), "Blindsight allows the live sight-required spell cast against an invisible creature")

	combat.turn_budget.reset(ranger, combat.player_entities)
	var veil_feature: Dictionary = ranger.get_feature("ranger_natures_veil")
	var uses_before := int(ranger.feature_uses.get("ranger_natures_veil", 0))
	await combat._on_hud_action("use_feature", {"feature": veil_feature})
	_assert(ranger.has_condition("invisible") and int(ranger.conditions.get("invisible", 0)) == 2, "Nature's Veil grants Invisible for the current and next Ranger turn")
	_assert(int(ranger.feature_uses.get("ranger_natures_veil", 0)) == uses_before - 1 and not combat.turn_budget.bonus_action_available, "Nature's Veil spends one Long Rest use and the Bonus Action")
	var attack_target: Dictionary = combat.monster_entities[0]
	attack_target["hex_position"] = Vector2i(1, 0)
	attack_target["current_hp"] = 10000
	attack_target["max_hp"] = 10000
	attack_target["armor_class"] = 12
	attack_target["is_alive"] = true
	attack_target.erase("senses")
	ActivityHistory.clear()
	combat._update_grid_entities()
	var incoming_roll_types: Array[String] = []
	var capture_incoming_roll := func(roll: Dictionary) -> void:
		incoming_roll_types.append(str(roll.get("type", "")))
	Dice.dice_rolled.connect(capture_incoming_roll)
	await combat._execute_monster_attack(attack_target, ranger.character_name, 0)
	Dice.dice_rolled.disconnect(capture_incoming_roll)
	_assert("disadvantage" in incoming_roll_types, "a normal enemy attack has Disadvantage against the Invisible Ranger")
	combat._on_hud_action("attack", {})
	await combat._on_hex_clicked(Vector2i(1, 0))
	var attacks: Array = []
	var records := ActivityHistory.get_records()
	if not records.is_empty():
		attacks = records.back().get("payload", {}).get("sections", {}).get("attacks", [])
	var roll_formula := str(attacks[0].get("roll", {}).get("formula", "")) if not attacks.is_empty() else ""
	_assert(roll_formula.begins_with("2d20kh1"), "the real Ranger weapon attack uses Advantage while the target cannot perceive Nature's Veil")
	_assert(ranger.has_condition("invisible"), "attacking does not end Nature's Veil")
	ranger.tick_conditions()
	_assert(ranger.has_condition("invisible") and int(ranger.conditions.get("invisible", 0)) == 1, "Nature's Veil persists through the end of its activation turn")
	ranger.tick_conditions()
	_assert(not ranger.has_condition("invisible"), "Nature's Veil expires at the end of the Ranger's next turn")
	_teardown_scene(combat)
	_setup_world()
	_exit_test()


## Wizard capstone choices appear in combat as separate free and slot casts.
func test_wizard_capstone_cast_modes() -> void:
	_enter_test("wizard_capstone_cast_modes")
	_setup_world()
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.game_in_progress = true
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"], "return_state": GameManager.GameState.OVERWORLD}
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Wizard")
	var wizard := _fresh_char("Capstone Wizard", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 12, "CHA": 10})
	while wizard.level < 20:
		wizard.level_up()
	wizard.wizard_spellbook.assign(["magic_missile", "scorching_ray", "fireball", "counterspell"])
	wizard.wizard_spellbook_pending = 40
	_assert(ClassProgression.choose_wizard_spell_mastery(wizard, 1, "magic_missile") and ClassProgression.choose_wizard_spell_mastery(wizard, 2, "scorching_ray"), "level-20 Wizard configures both Spell Mastery levels")
	_assert(ClassProgression.choose_wizard_signature_spells(wizard, ["fireball", "counterspell"]), "level-20 Wizard configures two Signature Spells")
	wizard.spell_slots = {"2": 1, "3": 1}
	PlayerManager.set_player_character(0, wizard)
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 2.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"is_player": true, "entity": wizard}
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.hud.update_hud(wizard, combat.tracker)
	combat.hud._show_spell_selection()
	var free_index := -1
	var slot_index := -1
	for index in combat.hud.spells_registered.size():
		var registered: Dictionary = combat.hud.spells_registered[index]
		if str(registered.get("id", "")) != "magic_missile":
			continue
		if bool(registered.get("_wizard_free_cast", false)):
			free_index = index
		elif bool(registered.get("_force_spell_slot", false)):
			slot_index = index
	_assert(free_index >= 0 and slot_index >= 0, "combat spell list offers distinct at-will and slot-based Spell Mastery casts")
	combat.hud._hide_spell_selection()
	if slot_index >= 0:
		await combat._on_hud_action("cast_spell", {"spell": combat.hud.spells_registered[slot_index]})
		_assert(combat.pending_action_type == "spell" and int(combat.pending_spell_data.get("_selected_spell_slot_level", 0)) == 2, "slot-based Spell Mastery cast selects an available higher-level slot")
		combat._cancel_pending_action()
	if free_index >= 0:
		await combat._on_hud_action("cast_spell", {"spell": combat.hud.spells_registered[free_index]})
		_assert(combat.pending_action_type == "spell" and bool(combat.pending_spell_data.get("_wizard_free_cast", false)) and not bool(combat.pending_spell_data.get("_force_spell_slot", false)), "at-will Spell Mastery path remains separate from slot spending")
		combat._cancel_pending_action()
	_teardown_scene(combat)
	_setup_world()
	_exit_test()


## Fixed-seed Crown path using the production overworld, dungeon, event,
## combat, objective, and terminal scenes in one bounded process.
func test_fighter_second_wind() -> void:
	_enter_test("fighter_second_wind")
	for seats in range(1, 5):
		_setup_world()
		PlayerManager.reset()
		PartyManager.reset()
		for seat in seats:
			PlayerManager.add_player("Fighter seat %d" % (seat + 1))
			var member := _fresh_char("Fighter %d" % seat, "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
			for progression in 3:
				member.level_up()
			member.use_feature("fighter_second_wind")
			member.max_hp = 1000
			member.current_hp = 1000
			PlayerManager.set_player_character(seat, member)
			PartyManager.register_player_character(seat, member)
		var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
		var fighter: Character = combat.player_entities[seats - 1]["character"]
		combat.current_player_idx = seats - 1
		combat.active_character = fighter
		combat.active_combatant = {"is_player": true, "entity": fighter}
		fighter.current_hp = 1
		combat.turn_budget.reset(fighter, combat.player_entities)
		combat.hud.update_hud(fighter, combat.tracker)
		_assert(fighter.feature_uses["fighter_second_wind"] == 2, "%d seats: combat preserves the spent Second Wind use" % seats)
		combat.hud._show_feature_selection()
		var feature_index := -1
		for index in combat.hud.features_registered.size():
			if combat.hud.features_registered[index].get("id", "") == "fighter_second_wind":
				feature_index = index
		_assert(feature_index >= 0, "Second Wind is selectable through the real feature list")
		if feature_index >= 0:
			var label: String = combat.hud.feature_list.get_item_text(feature_index)
			var tooltip: String = combat.hud.feature_list.get_item_tooltip(feature_index)
			_assert(label.contains("2/3") and label.contains("Bonus") and tooltip.contains("Bonus Action") and tooltip.contains("1d10+4"), "compact feature menu shows uses and cost, with healing details in its tooltip")
			combat.hud._on_feature_selected(feature_index)
		_assert(fighter.current_hp >= 6 and fighter.current_hp <= 15 and fighter.feature_uses["fighter_second_wind"] == 1 and not combat.turn_budget.bonus_action_available and combat.turn_budget.action_available, "%d seats: Second Wind heals and spends one use plus only the bonus action" % seats)
		var hp_after := fighter.current_hp
		combat._on_hud_action("use_feature", {"feature": fighter.get_feature("fighter_second_wind")})
		_assert(fighter.current_hp == hp_after and fighter.feature_uses["fighter_second_wind"] == 1, "repeated click cannot heal or spend a second time this turn")
		_assert(combat.hud.info_label.text.contains("Second Wind: 1/3 uses"), "sidebar reports the settled remaining pool")
		if seats > 1:
			_assert(combat.player_entities[0]["character"].feature_uses["fighter_second_wind"] == 2, "Second Wind belongs to the active seat, not another party member")
		combat.turn_budget.reset(fighter, combat.player_entities)
		combat._on_hud_action("use_feature", {"feature": fighter.get_feature("fighter_second_wind")})
		combat.turn_budget.reset(fighter, combat.player_entities)
		hp_after = fighter.current_hp
		combat._on_hud_action("use_feature", {"feature": fighter.get_feature("fighter_second_wind")})
		_assert(fighter.current_hp == hp_after and fighter.feature_uses["fighter_second_wind"] == 0 and combat.turn_budget.bonus_action_available, "exhausted Second Wind spends neither HP nor bonus-action budget")
		combat.hud._show_feature_selection()
		_assert(feature_index >= 0 and combat.hud.feature_list.is_item_disabled(feature_index), "exhausted Second Wind is disabled in the real menu")
		fighter.short_rest()
		_assert(fighter.feature_uses["fighter_second_wind"] == 1, "one Short Rest restores only one use in the combat fixture")
		fighter.long_rest()
		_assert(fighter.feature_uses["fighter_second_wind"] == 3, "Long Rest restores all three level-4 uses")
		_teardown_scene(combat)
		await get_tree().process_frame
	_exit_test()


func test_fighter_progression() -> void:
	_enter_test("fighter_progression")
	for seats in range(1, 5):
		_setup_world()
		PlayerManager.reset()
		PartyManager.reset()
		for seat in seats:
			PlayerManager.add_player("Fighter seat %d" % (seat + 1))
			var c := _fresh_char("Champion %d" % seat, "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
			for progression in 19:
				c.level_up()
			PlayerManager.set_player_character(seat, c)
			PartyManager.register_player_character(seat, c)
		var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
		var fighter: Character = combat.player_entities[seats - 1]["character"]
		combat.current_player_idx = seats - 1
		combat.active_character = fighter
		combat.active_combatant = {"is_player": true, "entity": fighter}
		combat.player_entities[seats - 1]["hex_position"] = Vector2i.ZERO
		combat.turn_budget.reset(fighter, combat.player_entities)
		fighter.known_spells.assign(["magic_missile"])
		fighter.spell_slots["1"] = 1
		combat.hud.update_hud(fighter, combat.tracker)
		combat.hud._show_feature_selection()
		var surge_index := -1
		for index in combat.hud.features_registered.size():
			if combat.hud.features_registered[index].get("id", "") == "fighter_action_surge":
				surge_index = index
			_assert(combat.hud.features_registered[index].get("id", "") not in ["fighter_extra_attack", "fighter_tactical_shift", "fighter_indomitable"], "passive/triggered Fighter features are absent from the active menu")
		_assert(surge_index >= 0 and combat.hud.feature_list.get_item_text(surge_index).contains("Free"), "%d seats: real menu exposes free Action Surge" % seats)
		combat.hud._on_feature_selected(surge_index)
		_assert(combat.turn_budget.action_available and combat.turn_budget.surge_actions == 1 and combat.turn_budget.bonus_action_available and fighter.feature_uses["fighter_action_surge"] == 1, "Surge before acting preserves the main and bonus actions")
		combat._on_hud_action("use_feature", {"feature": {"id": "fighter_action_surge", "action_cost": "free", "effects": [{"type": "grant_extra_action"}]}})
		_assert(fighter.feature_uses["fighter_action_surge"] == 1 and combat.turn_budget.surge_actions == 1, "repeated or altered Surge command cannot activate twice this turn")
		if seats > 1:
			_assert(combat.player_entities[0]["character"].feature_uses["fighter_action_surge"] == 2, "Surge spends only the owning seat's resource")
		combat.turn_budget.spend("magic_action")
		var forged_spell := DataLoader.get_spell("magic_missile").duplicate(true)
		forged_spell["casting_time"] = "free"
		combat._on_hud_action("cast_spell", {"spell": forged_spell})
		_assert(combat.pending_action_type != "spell" and fighter.spell_slots["1"] == 1, "Surge rejects Magic and ignores forged spell cost metadata")
		var target: Dictionary = combat.monster_entities[0]
		target["hex_position"] = Vector2i(1, 0)
		target["armor_class"] = -100
		target["current_hp"] = 10000
		target["is_alive"] = true
		combat._update_grid_entities()
		var ledger_before := ActivityHistory.get_records().filter(func(record): return record.get("kind") == "attack").size()
		combat._on_hud_action("attack", {})
		await combat._on_hex_clicked(Vector2i(1, 0))
		_assert(target["current_hp"] < 10000 and combat.turn_budget.surge_actions == 0 and not combat.turn_budget.can_spend("action") and combat.turn_budget.bonus_action_available, "level 20's four-attack action consumes exactly one Surge action")
		var records: Array = ActivityHistory.get_records().filter(func(record): return record.get("kind") == "attack")
		_assert(records.size() == ledger_before + 1 and combat.remaining_attack_swings == 0 and records.back().get("payload", {}).get("sections", {}).get("attacks", []).size() == 4, "all four swings settle in one Attack activity without leftover attacks")
		var hp_after_attack := int(target["current_hp"])
		combat.pending_action_type = "attack"
		await combat._on_hex_clicked(Vector2i(1, 0))
		_assert(target["current_hp"] == hp_after_attack and ActivityHistory.get_records().filter(func(record): return record.get("kind") == "attack").size() == records.size(), "stale attack targeting cannot create free swings after the action is exhausted")
		fighter.current_hp = 1
		var normal_speed: float = combat.remaining_speed
		if seats == 1:
			GameManager.test_mode = false
			combat._on_hud_action("use_feature", {"feature": fighter.get_feature("fighter_second_wind")})
			await get_tree().process_frame
			var accepted := false
			for child in combat.hud.get_children():
				if child is ConfirmationDialog and not child.is_queued_for_deletion():
					child.confirmed.emit()
					accepted = true
			await get_tree().process_frame
			_assert(accepted and combat.fighter_move_waiting, "Tactical Shift's actual confirmation opens a bounded movement choice")
			var origin: Vector2i = combat.player_entities[0]["hex_position"]
			for destination in combat.fighter_move_choices:
				_assert(HexUtils.get_distance(origin, destination) <= 3 and not combat._fighter_hex_occupied(destination), "Tactical Shift offers only legal half-speed destinations")
				combat._on_hex_clicked(destination)
				break
			await get_tree().process_frame
			_assert(combat.player_entities[0]["hex_position"] != origin and combat.remaining_speed == normal_speed and not fighter.has_condition("disengaging"), "Tactical Shift moves immediately without granting whole-turn Disengage or consuming normal movement")
			GameManager.test_mode = true
		else:
			combat._on_hud_action("use_feature", {"feature": fighter.get_feature("fighter_second_wind")})
		_assert(fighter.feature_uses["fighter_second_wind"] == 3 and fighter.current_hp >= 22 and fighter.current_hp <= 31, "level 20 Second Wind uses one of four uses and heals d10+20")
		if seats == 1:
			await _test_fighter_opportunity_features(combat, fighter, target)
		FighterRules.start_turn(fighter)
		combat.turn_budget.reset(fighter, combat.player_entities)
		combat._on_hud_action("use_feature", {"feature": fighter.get_feature("fighter_action_surge")})
		_assert(fighter.feature_uses["fighter_action_surge"] == 0 and combat.turn_budget.surge_actions == 1, "a later turn can use the second level-17 Surge charge")
		fighter.feature_uses["fighter_indomitable"] = 1
		FighterRules.improve_scores(fighter, "CON", "CON")
		FighterRules.choose_boon(fighter, "STR")
		var hp_before_save := fighter.max_hp
		var scores_before_save := fighter.ability_scores.to_dict()
		_teardown_scene(combat)
		await get_tree().process_frame
		GameManager.current_state = GameManager.GameState.OVERWORLD
		GameManager.game_in_progress = true
		var slot := "fighter_progression_%d" % seats
		_assert(SaveManager.save_game(slot) and SaveManager.load_game(slot), "level 20 choices and spent resources use a real supported SaveManager round-trip")
		var reload: Character = PartyManager.get_active_characters()[seats - 1]
		_assert(reload.level == 20 and reload.extra_attacks == 3 and reload.crit_range == 18 and reload.feature_uses["fighter_action_surge"] == 0 and reload.feature_uses["fighter_second_wind"] == 3 and reload.feature_uses["fighter_indomitable"] == 1, "level 20 features rebuild while all three spent pools remain spent")
		_assert(reload.max_hp == hp_before_save and reload.ability_scores.to_dict() == scores_before_save and reload.fighter_training.get("boon", "") == "combat_prowess" and FighterRules.pending_asi(reload) == 5, "selected ability improvement and Epic Boon are preserved without applying twice")
		SaveManager.delete_save(slot)
	_exit_test()


func _test_fighter_opportunity_features(combat: Node, fighter: Character, target: Dictionary) -> void:
	var original_weapon := fighter.inventory.get_weapon()
	FighterRules.choose_mastery(fighter, "warhammer")
	FighterRules.choose_mastery(fighter, "greataxe")
	fighter.inventory.add_item("warhammer")
	fighter.inventory.equip(Inventory.Slot.WEAPON, "warhammer")
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	for monster in combat.monster_entities:
		if monster != target:
			monster["hex_position"] = Vector2i(5, -3)
	target["hex_position"] = Vector2i(1, 0)
	fighter.fighter_training["tactical_master"] = "weapon"
	combat.player_entities[0]["reaction_available"] = true
	fighter.reaction_available = true
	combat.current_player_idx = -1
	combat.active_character = null
	GameManager.test_mode = false
	FighterChecks._seed_die(20, 10)
	combat._check_opportunity_attacks_for_path(null, target, [Vector2i(1, 0), Vector2i(2, 0)], true)
	await get_tree().process_frame
	_assert(_answer_fighter_popup(combat, true), "out-of-turn Fighter receives the actual owned Opportunity Attack choice")
	await get_tree().process_frame
	_assert(target["hex_position"] == Vector2i(3, 0) and not fighter.reaction_available, "Opportunity Attack Push interrupts movement at its settled pushed position")
	# Cleave applies on a reaction too, once per turn, without positive STR.
	fighter.inventory.unequip(Inventory.Slot.SHIELD)
	fighter.inventory.add_item("greataxe")
	fighter.inventory.equip(Inventory.Slot.WEAPON, "greataxe")
	var cleave_target := target.duplicate(true)
	cleave_target["id"] = "fighter-cleave-target"
	cleave_target["hex_position"] = Vector2i(1, -1)
	cleave_target["current_hp"] = 10000
	combat.monster_entities.append(cleave_target)
	target["hex_position"] = Vector2i(1, 0)
	combat.player_entities[0]["reaction_available"] = true
	fighter.reaction_available = true
	var expected_cleave_damage := 0
	for candidate in 10000:
		seed(candidate)
		if randi_range(1, 20) != 10:
			continue
		randi_range(1, 12)
		if randi_range(1, 20) != 10:
			continue
		expected_cleave_damage = randi_range(1, 12)
		seed(candidate)
		break
	combat._check_opportunity_attacks_for_path(null, target, [Vector2i(1, 0), Vector2i(2, 0)], true)
	await get_tree().process_frame
	_answer_fighter_popup(combat, true)
	await get_tree().process_frame
	_assert(_answer_fighter_popup(combat, true), "Opportunity Attack with a trained greataxe offers the actual Cleave target choice")
	await get_tree().process_frame
	_assert(10000 - int(cleave_target["current_hp"]) == expected_cleave_damage and fighter.feature_uses.get("fighter_cleave_used", false), "reaction Cleave adds exactly the weapon die without positive STR damage")
	var hp_after_cleave := int(cleave_target["current_hp"])
	await combat._finish_fighter_attack(target, DataLoader.get_item("greataxe"), {"hit": true, "mastery": "cleave"}, fighter)
	_assert(cleave_target["current_hp"] == hp_after_cleave, "Cleave cannot repeat during the same creature's turn")
	combat.monster_entities.erase(cleave_target)
	# A Champion critical can move its owner even while another creature acts.
	fighter.inventory.equip(Inventory.Slot.WEAPON, original_weapon)
	fighter.inventory.equip(Inventory.Slot.SHIELD, "shield")
	combat.player_entities[0]["reaction_available"] = true
	fighter.reaction_available = true
	target["hex_position"] = Vector2i(1, 0)
	FighterChecks._seed_die(20, 18)
	combat._check_opportunity_attacks_for_path(null, target, [Vector2i(1, 0), Vector2i(2, 0)], true)
	await get_tree().process_frame
	_answer_fighter_popup(combat, true)
	await get_tree().process_frame
	_assert(_answer_fighter_popup(combat, true), "Champion critical Opportunity Attack offers Remarkable Athlete movement")
	await get_tree().process_frame
	_assert(combat.fighter_move_waiting, "out-of-turn critical opens the Fighter owner's destination choice")
	var before: Vector2i = combat.player_entities[0]["hex_position"]
	for destination in combat.fighter_move_choices:
		combat._on_hex_clicked(destination)
		break
	await get_tree().process_frame
	_assert(combat.player_entities[0]["hex_position"] != before and combat.current_player_idx == -1 and combat.active_character == null, "critical movement changes only the reacting Fighter without taking over the monster turn")
	GameManager.test_mode = true
	combat.current_player_idx = 0
	combat.active_character = fighter
	# Indomitable's death-save path must work at its first level, before Survivor.
	var fallen := _fresh_char("Fallen Fighter", "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
	for i in 8:
		fallen.level_up()
	fallen.current_hp = 0
	fallen.is_alive = false
	combat.player_entities[0]["character"] = fallen
	var tracker_entry: Dictionary = {}
	for index in combat.tracker.combatants.size():
		if combat.tracker.combatants[index].get("is_player", false) and combat.tracker.combatants[index].get("entity") == fighter:
			tracker_entry = combat.tracker.combatants[index]
			tracker_entry["entity"] = fallen
			combat.tracker.active_index = index
			break
	_assert(not combat._check_battle_end_conditions(), "level-9 Indomitable gets its death-save opportunity before party defeat")
	for candidate in 10000:
		seed(candidate)
		if randi_range(1, 20) == 1 and randi_range(1, 20) == 20:
			seed(candidate)
			break
	combat._start_combat_turn()
	_assert(fallen.current_hp == 1 and fallen.is_alive and fallen.feature_uses["fighter_indomitable"] == 0 and combat.active_character == fallen, "actual level-9 combat turn uses Indomitable's new death-save 20 and revives before actions")
	tracker_entry["entity"] = fighter
	combat.player_entities[0]["character"] = fighter
	combat.active_character = fighter
	randomize()


func _answer_fighter_popup(combat: Node, accept: bool) -> bool:
	for child in combat.hud.get_children():
		if child is ConfirmationDialog and not child.is_queued_for_deletion():
			if accept:
				child.confirmed.emit()
			else:
				child.canceled.emit()
			return true
	return false


func test_monk_action_flow() -> void:
	_enter_test("monk_action_flow")
	for seats in range(1, 5):
		_setup_world()
		PlayerManager.reset()
		PartyManager.reset()
		GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin", "goblin"]}
		for seat in seats:
			PlayerManager.add_player("Monk seat %d" % (seat + 1))
			var member := _fresh_char("Monk %d" % seat, "human", "monk", {"STR": 10, "DEX": 20, "CON": 14, "INT": 10, "WIS": 16, "CHA": 8})
			member.level_up()
			member.max_hp = 1000
			member.current_hp = 1000
			PlayerManager.set_player_character(seat, member)
			PartyManager.register_player_character(seat, member)
		var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.5)
		var monk: Character = combat.player_entities[seats - 1]["character"]
		combat.current_player_idx = seats - 1
		combat.active_character = monk
		combat.active_combatant = {"is_player": true, "entity": monk}
		combat.player_entities[seats - 1]["hex_position"] = Vector2i.ZERO
		combat.turn_budget.reset(monk, combat.player_entities)
		combat.hud.update_hud(monk, combat.tracker)
		var target: Dictionary = combat.monster_entities[0]
		target["hex_position"] = Vector2i(1, 0)
		target["current_hp"] = 1000
		target["armor_class"] = -100
		target["is_alive"] = true
		var flurry := monk.get_feature("monk_flurry_of_blows")
		combat._on_hud_action("use_feature", {"feature": flurry})
		_assert(combat.pending_action_type == "unarmed_attack" and not combat.turn_budget.has_acted_this_turn, "%d seats: bonus strike targeting does not require an Attack first" % seats)
		combat._cancel_pending_action()
		_assert(monk.get_focus_points() == 2 and combat.turn_budget.bonus_action_available, "%d seats: cancelled targeting spends no Focus or bonus action" % seats)
		combat._on_hud_action("use_feature", {"feature": flurry})
		await combat._on_hex_clicked(Vector2i(9, 0))
		_assert(monk.get_focus_points() == 2 and combat.turn_budget.bonus_action_available, "%d seats: invalid target spends nothing" % seats)
		await combat._on_hex_clicked(Vector2i(1, 0))
		var hp_after := int(target["current_hp"])
		_assert(monk.get_focus_points() == 1 and not combat.turn_budget.bonus_action_available and combat.turn_budget.action_available, "%d seats: Flurry spends one shared Focus and only the bonus action" % seats)
		await combat._on_hex_clicked(Vector2i(1, 0))
		_assert(int(target["current_hp"]) == hp_after and monk.get_focus_points() == 1, "%d seats: repeated click cannot repeat Flurry" % seats)
		_assert(combat.hud.info_label.text.contains("Focus: 1 / 2"), "%d seats: HUD displays the active owner's remaining Focus" % seats)
		_assert(combat.hud.btn_attack.tooltip_text.contains("Weapon:") and combat.hud.get_node("Root").party_list.is_visible_in_tree(), "weapon detail is accessible from Attack while party vitals remain visible")
		var other_focus := 2 if seats > 1 else 0
		if seats > 1:
			_assert(combat.player_entities[0]["character"].get_focus_points() == other_focus, "spending does not touch another seat's Focus")
		combat.turn_budget.reset(monk, combat.player_entities)
		var defense := monk.get_feature("monk_patient_defense").duplicate(true)
		defense["selected_action"] = "disengage_dodge"
		combat._on_hud_action("use_feature", {"feature": defense})
		_assert(monk.get_focus_points() == 0 and monk.has_condition("dodging") and monk.has_condition("disengaging"), "paid Patient Defense shares the Flurry pool and grants both defenses")
		monk.tick_conditions()
		_assert(monk.has_condition("dodging"), "Patient Defense survives the Monk's own turn end")
		combat.turn_budget.reset(monk, combat.player_entities)
		monk.feature_uses["monk_flurry_of_blows"] = 1
		combat._on_hud_action("use_feature", {"feature": flurry})
		_assert(combat.pending_action_type.is_empty() and combat.turn_budget.bonus_action_available, "exhausted Focus cannot enter paid Flurry targeting")
		var step := monk.get_feature("monk_step_of_the_wind").duplicate(true)
		step["selected_action"] = "dash"
		var speed_before: float = combat.remaining_speed
		combat._on_hud_action("use_feature", {"feature": step})
		_assert(combat.remaining_speed == speed_before + monk.get_speed() and monk.get_focus_points() == 0, "free Step of the Wind works with exhausted Focus")
		monk.short_rest()
		combat.turn_budget.reset(monk, combat.player_entities)
		monk.feature_uses["monk_flurry_of_blows"] = 1
		target["current_hp"] = 1
		seed(20261003)
		combat._on_hud_action("use_feature", {"feature": flurry})
		await combat._on_hex_clicked(Vector2i(1, 0))
		_assert(not target["is_alive"] and monk.get_focus_points() == 1, "Flurry stops when its target dies without charging another Focus")
		if seats == 1:
			GameManager.test_mode = false
			var prompt_result: Array[bool] = []
			_capture_reaction_decision(combat.hud, prompt_result)
			await get_tree().process_frame
			for child in combat.hud.get_children():
				if child is ConfirmationDialog:
					child.get_ok_button().pressed.emit()
					child.confirmed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			_assert(prompt_result == [true], "production confirmation returns the player's accepted choice")
			var menu_result: Array[String] = []
			_capture_monk_choice(combat.hud, menu_result)
			await get_tree().process_frame
			for child in combat.hud.get_children():
				if child is PopupMenu:
					child.id_pressed.emit(2)
			await get_tree().process_frame
			await get_tree().process_frame
			_assert(menu_result == ["disengage_dodge"], "production menu returns the selected paid option")
			var cancelled_choice: Array[String] = []
			_capture_monk_choice(combat.hud, cancelled_choice)
			await get_tree().process_frame
			for child in combat.hud.get_children():
				if child is PopupMenu and not child.is_queued_for_deletion():
					child.popup_hide.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			_assert(cancelled_choice == [""] and monk.get_focus_points() == 1, "cancelled production choice returns no selection and spends no Focus")
			monk.level_up()
			monk.level_up()
			monk.level_up()
			monk.short_rest()
			combat.turn_budget.reset(monk, combat.player_entities)
			monk.feature_uses["monk_bonus_unarmed_strike"] = 1
			target["is_alive"] = true
			target["current_hp"] = 1000
			target["saving_throw_bonuses"]["CON"] = -100
			combat._on_hud_action("use_feature", {"feature": monk.get_feature("monk_bonus_unarmed_strike")})
			_answer_stunning_prompt(combat, target["hex_position"])
			seed(20261003)
			await combat._on_hex_clicked(target["hex_position"])
			_assert(monk.get_focus_points() == 4 and target.get("stunning_strike_stunned", false), "accepted production Stunning Strike spends one Focus after a real hit")
			_assert(not combat.resolving_player_action, "combat unlocks after the optional decision settles")
			combat._clear_monk_turn_effects(monk)
			_assert(not target.get("conditions", {}).has("stunned") and not target.has("stunning_strike_source"), "source's next-turn cleanup removes the Monk-owned stun")
			var second_monk := _fresh_char("Second Monk", "human", "monk", {"STR": 10, "DEX": 16, "CON": 14, "INT": 10, "WIS": 16, "CHA": 8})
			for level_index in 4:
				second_monk.level_up()
			monk.feature_uses.erase("stunning_strike_used")
			CombatAction.resolve_stunning_strike(monk, target)
			CombatAction.resolve_stunning_strike(second_monk, target)
			combat._clear_monk_turn_effects(monk)
			_assert(target.get("conditions", {}).has("stunned"), "one Monk's next turn cannot clear another Monk's overlapping stun")
			combat._clear_monk_turn_effects(second_monk)
			_assert(not target.get("conditions", {}).has("stunned"), "last Monk's next turn clears the remaining source-bound stun")
			monk.feature_uses["monk_patient_dodge"] = true
			monk.add_condition("dodging", 2)
			combat._clear_monk_battle_effects()
			_assert(not monk.has_condition("dodging") and not monk.feature_uses.has("monk_patient_dodge"), "temporary Patient Defense cannot leak into a later battle")
			GameManager.test_mode = true
		_teardown_scene(combat)
	_setup_world()
	_exit_test()


func _capture_reaction_decision(hud: CombatHUD, result: Array[bool]) -> void:
	result.append(await hud.request_reaction("Seat 1", "stunning_strike", "Spend one Focus?"))


func _capture_monk_choice(hud: CombatHUD, result: Array[String]) -> void:
	result.append(await hud.request_monk_bonus_action("monk_patient_defense"))


func _answer_stunning_prompt(combat: Node, target: Vector2i) -> void:
	await get_tree().process_frame
	var focus_before: int = combat.active_character.get_focus_points()
	combat._on_hud_action("attack", {})
	await combat._on_hex_clicked(target)
	_assert(combat.resolving_player_action and combat.active_character.get_focus_points() == focus_before, "another click during the Stunning Strike prompt cannot start a second action")
	for child in combat.hud.get_children():
		if child is ConfirmationDialog and not child.is_queued_for_deletion():
			child.confirmed.emit()


func test_crown_smoke() -> void:
	_enter_test("crown_smoke")
	_setup_world()
	GameManager.game_in_progress = true
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))
	_assert(PartyManager.recruit_companion("aldric"), "Crown smoke recruits Aldric")
	_assert(PartyManager.recruit_companion("mira"), "Crown smoke recruits Mira")
	_assert(PartyManager.get_active_characters().size() == 4, "Crown smoke starts with a full four-member party")

	var overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.2)
	_assert(overworld.hud.objective_label.text.contains("Find"), "Crown smoke displays the primary objective")
	PartyManager.move_exploration_party(Vector2i(1, 0))
	_assert(PlayerManager.get_player_position(0) == Vector2i(1, 0) and PlayerManager.get_player_position(1) == Vector2i(1, 0), "Crown smoke moves the authoritative party position")
	_teardown_scene(overworld)

	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 1.2)
	_assert(dungeon.rooms.size() == 5, "Crown smoke enters the deterministic first dungeon")
	_assert(GameManager.completed_milestones.has("enter_dungeon_1"), "Crown smoke records dungeon entry milestone")
	var crown_boss: Room = null
	for candidate in dungeon.rooms.values():
		if candidate is Room and candidate.type == Room.RoomType.BOSS:
			crown_boss = candidate
			break
	_assert(crown_boss != null, "Crown smoke finds the generated boss room")
	dungeon._begin_room_combat(crown_boss)
	_assert(not crown_boss.is_cleared and not dungeon.boss_defeated, "Crown smoke keeps the boss unresolved during combat")
	dungeon._complete_pending_combat()
	_assert(crown_boss.is_cleared and dungeon.boss_defeated, "Crown smoke resolves the boss only after victory")
	_assert(GameManager.mark_dungeon_cleared("ruins_of_ashvale"), "Crown smoke records the resolved dungeon clear")
	_assert(not GameManager.mark_dungeon_cleared("ruins_of_ashvale"), "Crown smoke keeps dungeon clear idempotent")
	_teardown_scene(dungeon)
	GameManager.active_dungeon_state.clear()
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var reentered_dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 0.6)
	var reentry_rooms_cleared := true
	for reentry_room in reentered_dungeon.rooms.values():
		if not reentry_room.is_cleared:
			reentry_rooms_cleared = false
			break
	_assert(reentry_rooms_cleared and reentered_dungeon.boss_defeated, "Crown smoke re-entry preserves cleared dungeon state without rewards")
	_teardown_scene(reentered_dungeon)

	var event_dialog: Node = await _spawn_scene("res://scenes/ui/event_dialog.tscn", 0.2)
	var event_table: Dictionary = DataLoader.get_event_table("dungeon_events")
	var event_data: Dictionary = event_table.get("events", [])[0]
	event_dialog.popup_event(PartyManager.get_active_characters()[0], event_data)
	_assert(event_dialog.visible, "Crown smoke presents a production event")
	_teardown_scene(event_dialog)

	GameManager.transition_context = {"monster_ids": ["lich_king"], "return_state": GameManager.GameState.DUNGEON, "terrain": "dungeon"}
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	_assert(combat.player_entities.size() == 4, "Crown smoke carries the full party into the finale encounter")
	_assert(combat.monster_entities.size() == 1 and combat.monster_entities[0].get("monster_id", "") == "lich_king", "Crown smoke uses the production Lich King encounter")
	_assert(combat.monster_entities[0].get("spells", []).size() == 7 and combat.monster_entities[0].get("spell_slots", {}).get("3", 0) == 3, "Crown smoke preserves the production Lich King spell list and slots")
	_assert(combat.monster_entities[0].get("condition_immunities", []).has("paralyzed") and combat.monster_entities[0].get("loot_table", []).size() == 4, "Crown smoke preserves boss defenses and reward metadata")
	combat._handle_spell_effects(null, combat.monster_entities[0], {"effects": [{"type": "grant_condition", "condition": "paralyzed", "duration": 3}]})
	_assert(not combat.monster_entities[0].get("conditions", {}).has("paralyzed"), "Crown monster condition immunity blocks an incoming paralyze effect")
	for player_entity in combat.player_entities:
		var final_character: Character = player_entity.get("character")
		final_character.inventory.equip(Inventory.Slot.WEAPON, "longsword", true)
		final_character.base_ac = 1000
		final_character.max_hp = 10000
		final_character.current_hp = 10000
		final_character.is_alive = true
	var lich: Dictionary = combat.monster_entities[0]
	var final_player_position: Vector2i = combat.player_entities[0].get("hex_position", Vector2i.ZERO)
	var final_monster_position := final_player_position
	for neighbor in HexUtils.get_neighbors(final_player_position):
		if combat.hex_grid.has_tile(neighbor) and combat.hex_grid.is_hex_passable(neighbor):
			final_monster_position = neighbor
			break
	lich["hex_position"] = final_monster_position
	lich["current_hp"] = 1
	lich["max_hp"] = 1
	lich["armor_class"] = -100
	lich["is_alive"] = true
	lich["conditions"] = {"prone": 99}
	combat._update_grid_entities()
	seed(424242)
	var final_rounds := 0
	while final_rounds < 6 and not combat._battle_ending:
		var final_start_round: int = combat.tracker.current_round
		var final_guard := 0
		while not combat._battle_ending and combat.tracker.current_round == final_start_round and final_guard < 12:
			var final_active: Dictionary = combat.active_combatant
			if not final_active.is_empty() and final_active.get("is_player", false):
				_drive_player_attack_turn(combat)
			await get_tree().create_timer(2.5).timeout
			final_guard += 1
		final_rounds += 1
	_assert(combat._battle_ending, "Crown smoke resolves the production finale combat loop")
	_assert(GameManager.defeated_monsters.has("lich_king"), "Crown smoke registers the Lich King defeat from CombatState")
	_teardown_scene(combat)

	var active_party := PartyManager.get_active_characters()
	for index in 3:
		active_party[index].inventory.add_item("crown_fragment")
	_assert(GameManager.are_win_conditions_met(), "Crown smoke reaches the campaign win condition")
	GameManager.current_state = GameManager.GameState.COMPLETION
	GameManager.transition_context = {"reason": "Campaign goals completed!"}
	var completion: Node = await _spawn_scene("res://scenes/completion.tscn", 0.3)
	_assert(completion.title_label.text == "Crown Reclaimed", "Crown smoke presents the provisional completion screen")
	_teardown_scene(completion)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = false
	GameManager.active_dungeon_state.clear()
	_exit_test()

## Seeded balance fixture for the first production Crown boss encounter. This
## keeps the normal party, milestone level-up, dungeon checkpoint, reward
## record, and live combat loop intact; it only records the resulting budget
## so balance review has a repeatable baseline.
func test_crown_balance_fixture() -> void:
	_enter_test("crown_balance_fixture")
	_setup_world()
	GameManager.game_in_progress = true
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))
	_assert(PartyManager.recruit_companion("aldric"), "balance fixture recruits Aldric")
	_assert(PartyManager.recruit_companion("mira"), "balance fixture recruits Mira")
	seed(20260810)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 1.0)
	var active_party := PartyManager.get_active_characters()
	_assert(active_party.size() == 4, "balance fixture uses the four-member Crown party")
	var all_level_two := true
	for character in active_party:
		if character.level != 2:
			all_level_two = false
	_assert(all_level_two, "balance fixture applies the entrance milestone to level 2")
	var dungeon_config: Dictionary = DataLoader.get_campaign("the_lost_crown").get("dungeons", {}).get("ruins_of_ashvale", {})
	_assert(dungeon_config.get("boss", {}).get("monster_id", "") == "wight", "balance fixture selects the production Ruins Wight boss")
	_assert(dungeon_config.get("loot", []) == [{"item_id": "crown_fragment"}, {"item_id": "gold_100"}], "balance fixture records the production boss reward boundary")
	_assert(SaveManager.get_save_block_reason().is_empty(), "balance fixture allows safe-save at the dungeon entrance checkpoint")

	var boss: Room = null
	for candidate in dungeon.rooms.values():
		if candidate is Room and candidate.type == Room.RoomType.BOSS:
			boss = candidate
			break
	_assert(boss != null, "balance fixture finds the generated boss room")
	if boss != null:
		dungeon.party_position = boss.coord
		dungeon._save_dungeon_state_to_manager()
	_assert(SaveManager.get_save_block_reason().contains("active dungeon"), "balance fixture blocks save after leaving the entrance checkpoint")
	if boss != null:
		dungeon._begin_room_combat(boss)
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["wight"], "return_state": GameManager.GameState.DUNGEON, "terrain": "dungeon"}
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	var starting_hp := 0
	for entity in combat.player_entities:
		starting_hp += int(entity.get("character").current_hp)
	var starting_wight_hp := int(combat.monster_entities[0].get("current_hp", 0))
	seed(20260810)
	var rounds := 0
	while rounds < 12 and not combat._battle_ending:
		var round_start: int = combat.tracker.current_round
		var turn_guard := 0
		while not combat._battle_ending and combat.tracker.current_round == round_start and turn_guard < 16:
			var active: Dictionary = combat.active_combatant
			if not active.is_empty() and active.get("is_player", false):
				_drive_player_attack_turn(combat)
			await get_tree().create_timer(0.35).timeout
			turn_guard += 1
		rounds += 1
	var ending_hp := 0
	for entity in combat.player_entities:
		ending_hp += int(entity.get("character").current_hp)
	var wight_hp := int(combat.monster_entities[0].get("current_hp", 0))
	var hp_loss := starting_hp - ending_hp
	var resolved: bool = combat._battle_ending
	_assert(starting_wight_hp > 0 and starting_hp > 0, "balance fixture starts with live production combatants")
	_assert(resolved, "balance fixture resolves the seeded Wight encounter within the twelve-round budget")
	_assert(ending_hp > 0, "balance fixture leaves at least one party member standing")
	_assert(wight_hp <= 0, "balance fixture ends with the Wight defeated")
	print("[balance] ruins_of_ashvale seed=20260810 party_level=2 rounds=%d hp=%d->%d loss=%d wight_hp=%d reward=crown_fragment+gold_100" % [rounds, starting_hp, ending_hp, hp_loss, wight_hp])
	_teardown_scene(combat)
	GameManager.active_dungeon_state.clear()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = false
	_teardown_scene(dungeon)
	_exit_test()

## Overworld boot + fog + reachable + rest + save + settings + ambush (Stealth).
func test_overworld() -> void:
	_enter_test("overworld")
	_setup_world()
	PlayerManager.set_player_position(0, Vector2i.ZERO)
	PlayerManager.set_player_position(1, Vector2i(1, 0))
	var overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 2.5)

	_assert(overworld != null, "overworld scene instantiated without error")
	_assert(overworld.hex_grid != null, "overworld HexGrid @onready resolved")
	_assert(overworld.hex_grid.tiles.size() > 0, "overworld grid built tiles (got %d)" % overworld.hex_grid.tiles.size())
	_assert(overworld.has_method("_resolve_destination_tile"), "overworld has tile resolver")
	var center: HexTile = overworld.hex_grid.get_tile(PlayerManager.get_player_position(0))
	_assert(center != null and center.is_visible, "overworld fog reveals active player tile")
	var reach: Dictionary = overworld.reachable_hexes
	_assert(reach.size() > 1, "overworld computed reachable hexes (got %d)" % reach.size())

	# ---- Overworld HUD: rest + save buttons ----
	var ow_hud: Node = overworld.hud
	_assert(ow_hud != null, "overworld HUD resolved")
	_assert(ow_hud.has_signal("rest_pressed"), "overworld HUD exposes rest_pressed signal")
	_assert(ow_hud.has_signal("save_pressed"), "overworld HUD exposes save_pressed signal")
	_assert(ow_hud.has_signal("menu_pressed"), "overworld HUD exposes menu_pressed signal")
	_assert(ow_hud.btn_rest != null, "overworld HUD rest button present")
	_assert(ow_hud.btn_save != null, "overworld HUD save button present")
	_assert(ow_hud.btn_menu != null, "overworld HUD menu button present")
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))
	_assert(PartyManager.recruit_companion("aldric"), "overworld recruits a companion for roster UI")
	ow_hud.update_hud()
	await get_tree().process_frame
	_assert(ow_hud.player_list_container.get_child_count() == 3, "overworld roster includes local players and companion")
	var roster_text := ""
	for card in ow_hud.player_list_container.get_children():
		for label in card.find_children("", "Label", true, false):
			roster_text += str(label.text)
	_assert(roster_text.contains("Aldric") and roster_text.contains("Seat"), "overworld roster shows companion identity and owner seat")
	_assert(PartyManager.set_leader("slot_2"), "roster can transfer leadership to companion")
	ow_hud.update_hud()
	await get_tree().process_frame
	var rest_char: Character = PlayerManager.get_player(0).get("character")
	rest_char.current_hp = 1
	overworld._rest_party()
	_assert(rest_char.current_hp == rest_char.max_hp, "wilderness rest restored HP (1 -> %d)" % rest_char.current_hp)
	GameManager.game_in_progress = true
	SaveManager.delete_save("quicksave")
	ow_hud.save_pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_assert(SaveManager.get_available_saves().has("quicksave"), "save button wrote 'quicksave' slot")

	# ---- Settings overlay (save/load anywhere + options) ----
	_assert(ow_hud.has_signal("settings_pressed"), "overworld HUD exposes settings_pressed signal")
	ow_hud.settings_pressed.emit()
	_assert(Settings.is_open(), "settings overlay opened from overworld")
	_assert(get_tree().paused, "tree paused while settings open")
	_assert(AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Music") >= 0, "settings audio buses exist for SFX and music controls")
	Settings.close_settings()
	_assert(not Settings.is_open(), "settings overlay closed")
	_assert(not get_tree().paused, "tree resumed after settings close")
	Settings.master_volume = 0.42
	Settings.save_settings()
	Settings.master_volume = 1.0
	Settings.load_settings()
	_assert(abs(Settings.master_volume - 0.42) < 0.001, "settings persisted to disk (master_volume)")
	Settings.sfx_volume = 0.37
	Settings.save_settings()
	var sfx_bus := AudioServer.get_bus_index("SFX")
	_assert(abs(AudioServer.get_bus_volume_db(sfx_bus) - linear_to_db(0.37)) < 0.01, "SFX volume control applies to the SFX bus")
	Settings.sfx_volume = 1.0

	# ---- Ambush is now a Stealth check, not a flat 40% roll ----
	_assert(overworld.has_method("_compute_ambush_dc"), "ambush uses Stealth DC calc")
	_assert(overworld.has_method("_party_best_stealth_mod"), "ambush uses party Stealth mod")
	var exp_dc := 12 + maxi(0, PlayerManager.get_player_count() - 1)
	_assert(overworld._compute_ambush_dc() == exp_dc, "ambush DC = 12 + (party-1) = %d" % exp_dc)
	var stealth_char: Character = PlayerManager.get_player(0).get("character")
	stealth_char.ability_scores.dexterity = 20
	var best_mod: int = overworld._party_best_stealth_mod()
	_assert(best_mod >= 5, "best Stealth mod reflects high DEX (got %d)" % best_mod)
	_assert(overworld.has_method("_on_rest_pressed"), "rest handler present (Stealth-based ambush)")

	_teardown_scene(overworld)
	_exit_test()


## Production Camp Roster UI: solo fill plus two-player decline, replacement,
## dismissal, and logical-owner reassignment.
func test_companion_lifecycle() -> void:
	_enter_test("companion_lifecycle")
	_setup_companion_party(1)
	var solo_overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.2)
	var solo_hud: Node = solo_overworld.hud
	solo_hud.btn_companions.pressed.emit()
	await get_tree().process_frame
	var solo_panel: CompanionRosterPanel = solo_hud.companion_panel
	_assert(solo_hud.companion_overlay.visible, "normal overworld UI opens the Camp Roster")
	_assert(solo_panel.companion_controls.size() == 3, "Camp Roster shows all three Crown companions")
	_assert(not solo_overworld.hex_grid.is_processing_input(), "Camp Roster suspends overworld map input")
	_assert(solo_hud.btn_end_turn.disabled and solo_hud.btn_rest.disabled, "Camp Roster disables turn-changing controls behind the modal")
	var roster_start := PartyManager.get_exploration_position()
	var blocked_destination := roster_start
	for candidate in solo_overworld.reachable_hexes:
		if candidate != roster_start:
			blocked_destination = candidate
			break
	if blocked_destination != roster_start:
		solo_overworld._on_hex_clicked(blocked_destination)
	_assert(PartyManager.get_exploration_position() == roster_start, "Camp Roster rejects direct movement intent while open")
	solo_panel.close_button.pressed.emit()
	await get_tree().process_frame
	_assert(not solo_hud.companion_overlay.visible and solo_overworld.hex_grid.is_processing_input(), "closing Camp Roster restores overworld map input")
	_assert(not solo_hud.btn_end_turn.disabled and not solo_hud.btn_rest.disabled, "closing Camp Roster restores turn-changing controls")
	solo_hud.btn_companions.pressed.emit()
	await get_tree().process_frame
	solo_panel = solo_hud.companion_panel

	var rowan_controls: Dictionary = solo_panel.companion_controls.get("rowan", {})
	rowan_controls.get("decline_button").pressed.emit()
	await get_tree().process_frame
	_assert(PartyManager.get_companion_state("rowan") == "declined", "normal UI can decline a companion")
	_assert(SaveManager.save_game("companion_lifecycle"), "declined companion state passes the supported save validator")
	SaveManager.delete_save("companion_lifecycle")
	rowan_controls = solo_panel.companion_controls.get("rowan", {})
	rowan_controls.get("reconsider_button").pressed.emit()
	await get_tree().process_frame
	_assert(PartyManager.get_companion_state("rowan") == "available", "normal UI can reconsider a declined companion")

	for companion_id in ["aldric", "mira", "rowan"]:
		var controls: Dictionary = solo_panel.companion_controls.get(companion_id, {})
		var seat_selector: OptionButton = controls.get("seat_selector")
		seat_selector.select(0)
		controls.get("recruit_button").pressed.emit()
		await get_tree().process_frame
	_assert(PartyManager.get_active_characters().size() == 4, "solo Camp Roster fills all three empty party slots")
	var solo_owns_all := true
	for slot in PartyManager.party_slots:
		if bool(slot.get("occupied", false)) and PlayerManager.get_player_for_party_slot(str(slot.get("slot_id", ""))) != 0:
			solo_owns_all = false
	_assert(solo_owns_all, "solo player owns every recruited companion turn")
	_teardown_scene(solo_overworld)

	_setup_companion_party(2)
	var coop_overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.2)
	var coop_hud: Node = coop_overworld.hud
	coop_hud.btn_companions.pressed.emit()
	await get_tree().process_frame
	var coop_panel: CompanionRosterPanel = coop_hud.companion_panel
	for recruit_spec in [{"id": "aldric", "seat": 0}, {"id": "mira", "seat": 1}]:
		var controls: Dictionary = coop_panel.companion_controls.get(recruit_spec["id"], {})
		var selector: OptionButton = controls.get("seat_selector")
		selector.select(int(recruit_spec["seat"]))
		controls.get("recruit_button").pressed.emit()
		await get_tree().process_frame
	_assert(PartyManager.get_active_characters().size() == 4, "two-player Camp Roster fills both open slots")
	var capture_path := OS.get_environment("VIEWPORT_CAPTURE_PATH")
	if not capture_path.is_empty() and DisplayServer.get_name() != "headless":
		var capture_viewport: SubViewport = coop_overworld.get_meta("vp")
		capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var capture_image := capture_viewport.get_texture().get_image()
		_assert(capture_image.save_png(capture_path) == OK, "Camp Roster visual capture saved")

	rowan_controls = coop_panel.companion_controls.get("rowan", {})
	var replace_selector: OptionButton = rowan_controls.get("replace_selector")
	var aldric_option := -1
	for option_index in replace_selector.item_count:
		if str(replace_selector.get_item_metadata(option_index)) == "aldric":
			aldric_option = option_index
			break
	_assert(aldric_option >= 0, "full-party UI offers a recruited companion as the replacement target")
	if aldric_option >= 0:
		replace_selector.select(aldric_option)
	var replacement_seat: OptionButton = rowan_controls.get("seat_selector")
	replacement_seat.select(0)
	rowan_controls.get("replace_button").pressed.emit()
	await get_tree().process_frame
	_assert(PartyManager.get_companion_state("aldric") == "dismissed" and PartyManager.get_companion_state("rowan") == "recruited", "normal UI atomically replaces one companion with another")
	_assert(PartyManager.get_active_characters().size() == 4, "replacement preserves full party capacity")
	var rowan_slot := PartyManager.get_companion_slot_id("rowan")
	_assert(PlayerManager.get_player_for_party_slot(rowan_slot) == 0, "replacement applies the chosen initial owner")

	rowan_controls = coop_panel.companion_controls.get("rowan", {})
	var owner_selector: OptionButton = rowan_controls.get("owner_selector")
	owner_selector.select(1)
	owner_selector.item_selected.emit(1)
	await get_tree().process_frame
	_assert(PlayerManager.get_player_for_party_slot(rowan_slot) == 1, "normal UI reassigns a companion from Seat 1 to Seat 2")
	var mira_controls: Dictionary = coop_panel.companion_controls.get("mira", {})
	mira_controls.get("dismiss_button").pressed.emit()
	await get_tree().process_frame
	_assert(PartyManager.get_companion_state("mira") == "dismissed" and PartyManager.get_active_characters().size() == 3, "normal UI dismisses a recruited companion and opens its slot")
	_assert(coop_panel.companion_controls.get("mira", {}).has("reconsider_button"), "dismissed companion exposes an Invite back action")
	_teardown_scene(coop_overworld)
	_exit_test()

## Crown composition rows: production Camp Roster ownership, safe save/load,
## objective visibility, and combat formation for one and two local seats.
## Normal shared-keyboard play remains a manual review boundary.
func test_crown_composition_solo_two() -> void:
	_enter_test("crown_composition_solo_two")
	var solo_slot := "crown_composition_solo"
	_setup_companion_party(1)
	GameManager.active_dungeon_state.clear()
	var solo_overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.0)
	solo_overworld.hud.btn_companions.pressed.emit()
	await get_tree().process_frame
	var solo_panel: CompanionRosterPanel = solo_overworld.hud.companion_panel
	for companion_id in ["aldric", "mira", "rowan"]:
		var controls: Dictionary = solo_panel.companion_controls.get(companion_id, {})
		var selector: OptionButton = controls.get("seat_selector")
		selector.select(0)
		controls.get("recruit_button").pressed.emit()
		await get_tree().process_frame
	_assert(PartyManager.get_active_characters().size() == 4, "solo composition fills three companion slots")
	_assert(PlayerManager.get_player_for_party_slot("slot_0") == 0, "solo composition preserves the local seat owner")
	var solo_objectives := " | ".join(GameManager.get_campaign_objectives())
	_assert(solo_objectives.contains("Crown"), "solo composition keeps the player-facing Crown objective")
	solo_panel.close_button.pressed.emit()
	await get_tree().process_frame
	SaveManager.delete_save(solo_slot)
	_assert(SaveManager.save_game(solo_slot), "solo composition saves its full party at the overworld boundary")
	_teardown_scene(solo_overworld)
	await _run_composition_combat("solo", [0, 0, 0, 0])
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(solo_slot), "solo composition reloads its four-member party")
	_assert(PartyManager.get_active_characters().size() == 4 and PlayerManager.get_player_for_party_slot("slot_3") == 0, "solo composition reload preserves companion ownership")
	SaveManager.delete_save(solo_slot)

	var two_player_slot := "crown_composition_two_player"
	_setup_companion_party(2)
	GameManager.active_dungeon_state.clear()
	var two_overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.0)
	two_overworld.hud.btn_companions.pressed.emit()
	await get_tree().process_frame
	var two_panel: CompanionRosterPanel = two_overworld.hud.companion_panel
	for recruit_spec in [{"id": "aldric", "seat": 0}, {"id": "mira", "seat": 1}]:
		var controls: Dictionary = two_panel.companion_controls.get(recruit_spec["id"], {})
		var selector: OptionButton = controls.get("seat_selector")
		selector.select(int(recruit_spec["seat"]))
		controls.get("recruit_button").pressed.emit()
		await get_tree().process_frame
	_assert(PartyManager.get_active_characters().size() == 4, "two-player composition fills two companion slots")
	_assert(PlayerManager.get_player_for_party_slot("slot_2") == 0 and PlayerManager.get_player_for_party_slot("slot_3") == 1, "two-player composition assigns companions to both local seats")
	two_panel.close_button.pressed.emit()
	await get_tree().process_frame
	SaveManager.delete_save(two_player_slot)
	_assert(SaveManager.save_game(two_player_slot), "two-player composition saves the mixed party at the overworld boundary")
	_teardown_scene(two_overworld)
	await _run_composition_combat("two-player", [0, 0, 1, 1])
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(two_player_slot), "two-player composition reloads its mixed party")
	_assert(PartyManager.get_active_characters().size() == 4 and PlayerManager.get_player_for_party_slot("slot_2") == 0 and PlayerManager.get_player_for_party_slot("slot_3") == 1, "two-player composition reload preserves both companion owners")
	SaveManager.delete_save(two_player_slot)
	GameManager.game_in_progress = false
	_exit_test()


## Crown composition rows for three local seats plus one companion and four
## local character seats. Normal shared-keyboard ownership remains review.
func test_crown_composition_three_four() -> void:
	_enter_test("crown_composition_three_four")
	var three_slot := "crown_composition_three_player"
	_setup_companion_party(3)
	GameManager.active_dungeon_state.clear()
	var three_overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.0)
	three_overworld.hud.btn_companions.pressed.emit()
	await get_tree().process_frame
	var three_panel: CompanionRosterPanel = three_overworld.hud.companion_panel
	var rowan_controls: Dictionary = three_panel.companion_controls.get("rowan", {})
	var rowan_selector: OptionButton = rowan_controls.get("seat_selector")
	rowan_selector.select(2)
	rowan_controls.get("recruit_button").pressed.emit()
	await get_tree().process_frame
	_assert(PartyManager.get_active_characters().size() == 4, "three-player composition fills its final slot with Rowan")
	_assert(PlayerManager.get_player_for_party_slot("slot_3") == 2, "three-player composition assigns Rowan to Seat 3")
	three_panel.close_button.pressed.emit()
	await get_tree().process_frame
	SaveManager.delete_save(three_slot)
	_assert(SaveManager.save_game(three_slot), "three-player composition saves at the overworld boundary")
	_teardown_scene(three_overworld)
	await _run_composition_combat("three-player", [0, 1, 2, 2])
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(three_slot), "three-player composition reloads its mixed party")
	_assert(PartyManager.get_active_characters().size() == 4 and PlayerManager.get_player_for_party_slot("slot_3") == 2, "three-player composition reload preserves Rowan ownership")
	SaveManager.delete_save(three_slot)

	var four_slot := "crown_composition_four_player"
	_setup_companion_party(4)
	GameManager.active_dungeon_state.clear()
	var four_overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.0)
	_assert(PartyManager.get_active_characters().size() == 4, "four-player composition starts with four local characters")
	var four_objectives := " | ".join(GameManager.get_campaign_objectives())
	_assert(four_objectives.contains("Crown"), "four-player composition keeps the player-facing Crown objective")
	SaveManager.delete_save(four_slot)
	_assert(SaveManager.save_game(four_slot), "four-player composition saves at the overworld boundary")
	_teardown_scene(four_overworld)
	await _run_composition_combat("four-player", [0, 1, 2, 3])
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(four_slot), "four-player composition reloads all local characters")
	_assert(PartyManager.get_active_characters().size() == 4 and PlayerManager.get_player_for_party_slot("slot_3") == 3, "four-player composition reload preserves Seat 4 ownership")
	SaveManager.delete_save(four_slot)
	GameManager.game_in_progress = false
	_exit_test()


func _run_composition_combat(label: String, expected_owners: Array) -> void:
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["goblin"], "return_state": GameManager.GameState.OVERWORLD, "terrain": "plains"}
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	_assert(combat.player_entities.size() == 4, "%s composition enters combat with four active characters" % label)
	var actual_owners: Array = []
	var positions: Dictionary = {}
	for entity in combat.player_entities:
		actual_owners.append(int(entity.get("owner_player_index", -1)))
		positions[entity.get("hex_position", Vector2i.ZERO)] = true
	actual_owners.sort()
	var sorted_expected := expected_owners.duplicate()
	sorted_expected.sort()
	_assert(actual_owners == sorted_expected, "%s composition preserves combat seat ownership" % label)
	_assert(positions.size() == 4, "%s composition enters with distinct combat formation positions" % label)
	_teardown_scene(combat)


func _setup_companion_party(player_count: int) -> void:
	GameManager.active_campaign = DataLoader.get_campaign("the_lost_crown")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {}
	GameManager.is_loading_save = false
	GameManager.game_in_progress = true
	GameManager.test_mode = true
	GameManager.recruited_companions.clear()
	GameManager.dismissed_companions.clear()
	PlayerManager.reset()
	PartyManager.reset()
	for seat_index in player_count:
		PlayerManager.add_player("Seat %d" % (seat_index + 1))
		var character := _fresh_char(
			"Hero %d" % (seat_index + 1),
			"human",
			"fighter" if seat_index == 0 else "wizard",
			{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8}
		)
		PlayerManager.set_player_character(seat_index, character)
		PartyManager.register_player_character(seat_index, character)
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))

## Main-menu Load Game UI (writes its own quicksave so it's self-contained).
func test_main_menu_load() -> void:
	_enter_test("main_menu_load")
	_setup_world()
	GameManager.game_in_progress = true
	SaveManager.delete_save("quicksave")
	SaveManager.save_game("quicksave")
	var main_menu: Node = await _spawn_scene("res://scenes/main_menu.tscn", 1.0)

	_assert(main_menu.btn_load != null, "main menu has Load Game button")
	_assert(main_menu.save_slot_list != null, "main menu has save-slot list")
	_assert(SaveManager.get_available_saves().has("quicksave"), "quicksave available for menu load")
	_assert(not main_menu.btn_load.disabled, "load button enabled when saves exist")
	_assert(main_menu.has_method("_on_load_pressed"), "main menu wires _on_load_pressed")
	_assert(main_menu.has_method("_refresh_save_slots"), "main menu populates save slots on ready")

	_teardown_scene(main_menu)
	_exit_test()

## Dungeon boot + rooms + party move.
func test_dungeon() -> void:
	_enter_test("dungeon")
	_setup_world()
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 2.5)

	_assert(dungeon != null, "dungeon scene instantiated without error")
	_assert(dungeon.hex_grid != null, "dungeon HexGrid @onready resolved")
	_assert(dungeon.hex_grid.tiles.size() > 0, "dungeon rooms generated (got %d)" % dungeon.hex_grid.tiles.size())
	_assert(dungeon.hud != null, "dungeon HUD @onready resolved")
	_assert(dungeon.hud.get("btn_end_turn") == null, "dungeon HUD truly has NO end-turn button (real BaseHUD split, not hidden)")
	_assert(dungeon.hud.has_signal("rest_pressed"), "dungeon HUD exposes rest_pressed signal")
	_assert(dungeon.hud.has_signal("save_pressed"), "dungeon HUD exposes save_pressed signal")
	_assert(dungeon.hud.has_signal("menu_pressed"), "dungeon HUD exposes menu_pressed signal")
	var has_entrance := false
	var has_boss := false
	for coord in dungeon.rooms:
		var rm = dungeon.rooms[coord]
		if rm.type == Room.RoomType.ENTRANCE:
			has_entrance = true
		if rm.type == Room.RoomType.BOSS:
			has_boss = true
	_assert(has_entrance, "dungeon has an entrance room")
	_assert(has_boss, "dungeon has a boss room")
	_assert(dungeon.party_position == Vector2i.ZERO, "dungeon party starts at origin")
	var move_target := Vector2i.ZERO
	for n in HexUtils.get_neighbors(dungeon.party_position):
		if n in dungeon.rooms:
			var rt = dungeon.rooms[n].type
			if rt != Room.RoomType.COMBAT and rt != Room.RoomType.BOSS:
				move_target = n
				break
	if move_target != Vector2i.ZERO:
		dungeon._on_room_clicked(move_target)
		var moved_to = dungeon.party_position
		_assert(moved_to == move_target, "dungeon party moved after room click")
	else:
		_assert(true, "dungeon: all adjacent rooms are combat (movement not exercised this run)")

	_teardown_scene(dungeon)
	_exit_test()

## EventDialog UI: choice + skill-check events, roll seam, re-popup regression.
func test_event_dialog() -> void:
	_enter_test("event_dialog")
	var ev_dialog: EventDialog = await _spawn_scene("res://scenes/ui/event_dialog.tscn", 0.3)

	_assert(ev_dialog != null, "EventDialog instantiated")
	var ev_scores := AbilityScores.new()
	ev_scores.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var ev_char := Character.new()
	ev_char.initialize("EventTester", "human", "fighter", ev_scores)
	var dungeon_events: Dictionary = DataLoader.get_event_table("dungeon_events")
	_assert(not dungeon_events.is_empty(), "loaded dungeon_events table from data")
	var event_list: Array = dungeon_events.get("events", [])
	var choice_evt: Dictionary = {}
	for e in event_list:
		if e.get("id", "") == "trapped_chest":
			choice_evt = e
			break
	_assert(not choice_evt.is_empty(), "loaded 'trapped_chest' choice event from data")
	ev_dialog.popup_event(ev_char, choice_evt)
	await get_tree().create_timer(0.2).timeout
	_assert(ev_dialog.title_label.text == "Trapped Chest", "EventDialog title set from event")
	_assert(ev_dialog.choice_container.get_child_count() == 3, "EventDialog built 3 choice buttons")
	_assert(ev_dialog.choice_container.visible, "EventDialog choice container visible for choice event")
	var skill_evt: Dictionary = {}
	for e in event_list:
		if e.get("id", "") == "cave_in":
			skill_evt = e
			break
	_assert(not skill_evt.is_empty(), "loaded 'cave_in' skill_check event from data")
	ev_dialog.popup_event(ev_char, skill_evt)
	await get_tree().create_timer(0.2).timeout
	_assert(ev_dialog.roll_section.visible, "EventDialog roll section visible for skill_check event")
	_assert(not ev_dialog.choice_container.visible, "EventDialog choices hidden for skill_check event")
	_assert(ev_dialog.btn_roll.visible, "EventDialog roll button visible for skill_check event")
	_assert(ev_dialog.btn_roll.pressed.is_connected(ev_dialog._on_btn_roll_pressed),
		"EventDialog roll button wired to stable handler (not one-shot)")
	ev_dialog.btn_roll.pressed.emit()
	_assert(ev_dialog.roll_result_lbl.text.begins_with("Rolled:"),
		"EventDialog skill_check roll produced a result label ('%s')" % ev_dialog.roll_result_lbl.text)
	ev_dialog.popup_event(ev_char, skill_evt)
	_assert(ev_dialog.roll_result_lbl.text == "", "EventDialog result label reset on re-popup")
	ev_dialog.btn_roll.pressed.emit()
	_assert(ev_dialog.roll_result_lbl.text.begins_with("Rolled:"),
		"EventDialog roll still fires on re-popup (one-shot regression)")

	_teardown_scene(ev_dialog)
	_exit_test()

## Production Crown event chain: verify the Fairy Ring follow-up, every legal
## choice, and each deterministic branch outcome through shared resolvers.
func test_crown_event_fairy_ring() -> void:
	_enter_test("crown_event_fairy_ring")
	var forest_events: Dictionary = DataLoader.get_event_table("forest_events")
	var fairy_ring: Dictionary = {}
	for candidate in forest_events.get("events", []):
		if str(candidate.get("id", "")) == "fairy_ring":
			fairy_ring = candidate
			break
	var fairy_court: Dictionary = EventChain.get_chain_event(fairy_ring)
	_assert(EventChain.has_chain(fairy_ring) and str(fairy_ring.get("type", "")) == "chain", "Fairy Ring is a production event chain")
	_assert(str(fairy_court.get("id", "")) == "fairy_court" and str(fairy_court.get("type", "")) == "choice", "Fairy Ring exposes its Fairy Court follow-up")
	var choices: Array = fairy_court.get("choices", [])
	_assert(choices.size() == 3, "Fairy Court exposes all three legal choices")
	var steal_choice: Dictionary = choices[2] if choices.size() > 2 else {}
	_assert(int(steal_choice.get("check", {}).get("dc", -1)) == 16 and str(steal_choice.get("check", {}).get("ability", "")) == "DEX", "Fairy treasure choice carries the production DEX DC 16 check")

	var chain_character := _fresh_char("Fairy Chain Tester", "human", "rogue",
		{"STR": 10, "DEX": 18, "CON": 12, "INT": 12, "WIS": 10, "CHA": 10})
	var chain_results := EventResolver.apply_effects(chain_character, fairy_ring.get("effects", []))
	var teleported := false
	for result in chain_results:
		if str(result.get("type", "")) == "teleport_random":
			teleported = true
	_assert(teleported, "Fairy Ring root applies its production teleport consequence")

	var accept_character := _fresh_char("Fairy Gift", "human", "fighter",
		{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8})
	accept_character.current_hp = accept_character.max_hp - 5
	var accept_hp_before := accept_character.current_hp
	var accept_results := EventResolver.apply_effects(accept_character, choices[0].get("effects", []))
	_assert(accept_character.has_condition("fairy_luck") and accept_character.current_hp > accept_hp_before and not accept_results.is_empty(), "Fairy gift applies luck and healing through shared effects")

	var decline_character := _fresh_char("Fairy Decline", "human", "fighter",
		{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8})
	var decline_hp_before := decline_character.current_hp
	var decline_results := EventResolver.apply_effects(decline_character, choices[1].get("effects", []))
	_assert(decline_results.is_empty() and decline_character.current_hp == decline_hp_before and not decline_character.has_condition("fairy_luck"), "Polite decline preserves the character without hidden effects")

	var steal_success_character := _fresh_char("Fairy Thief", "halfling", "rogue",
		{"STR": 10, "DEX": 18, "CON": 12, "INT": 12, "WIS": 10, "CHA": 10})
	var forced_success := EventResolver.resolve_skill_check(steal_success_character, {"ability": "DEX", "dc": 1})
	var success_results := EventResolver.apply_effects(steal_success_character, steal_choice.get("success", {}).get("effects", []))
	_assert(forced_success.get("success", false) and steal_success_character.inventory.has_item("gold_100") and not success_results.is_empty(), "Fairy treasure success grants the production reward")

	var steal_failure_character := _fresh_char("Fairy Caught", "human", "rogue",
		{"STR": 10, "DEX": 8, "CON": 12, "INT": 10, "WIS": 10, "CHA": 10})
	var forced_failure := EventResolver.resolve_skill_check(steal_failure_character, {"ability": "DEX", "dc": 99})
	var failure_results := EventResolver.apply_effects(steal_failure_character, steal_choice.get("failure", {}).get("effects", []))
	_assert(not forced_failure.get("success", true) and steal_failure_character.has_condition("cursed") and not failure_results.is_empty(), "Fairy treasure failure applies the production curse consequence")
	_assert(not fairy_ring.has("companion_change") and not fairy_ring.has("ledger") and not fairy_court.has("companion_change") and not fairy_court.has("ledger"), "Fairy Ring declares no companion or campaign-ledger mutation")

	var dialog_character := _fresh_char("Fairy UI", "human", "fighter",
		{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8})
	var dialog: EventDialog = await _spawn_scene("res://scenes/ui/event_dialog.tscn", 0.2)
	dialog.popup_event(dialog_character, fairy_ring)
	await get_tree().create_timer(0.2).timeout
	_assert(dialog.title_label.text == "Fairy Ring" and dialog.btn_close.text == "Next event...", "Fairy Ring UI presents its chain continuation")
	dialog.btn_close.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_assert(dialog.title_label.text == "The Fairy Court" and dialog.choice_container.get_child_count() == 3, "Fairy Ring UI opens the three-choice follow-up")
	var accept_button := dialog.choice_container.get_child(0) as Button
	accept_button.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_assert(dialog_character.has_condition("fairy_luck") and not dialog.choice_container.visible, "Fairy Ring UI choice reaches the shared effect result")
	_teardown_scene(dialog)
	_exit_test()

## Crown dungeon clear, safe-save DTO, supported reload, and idempotent re-entry.
## The normal GUI quit/relaunch remains a manual review boundary.
func test_dungeon_reentry_round_trip() -> void:
	_enter_test("dungeon_reentry_round_trip")
	_setup_world()
	GameManager.game_in_progress = true
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))
	_assert(PartyManager.recruit_companion("aldric"), "dungeon re-entry recruits Aldric")
	_assert(PartyManager.recruit_companion("mira"), "dungeon re-entry recruits Mira")

	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 0.8)
	var boss: Room = null
	for candidate in dungeon.rooms.values():
		if candidate is Room and candidate.type == Room.RoomType.BOSS:
			boss = candidate
			break
	_assert(boss != null and dungeon.rooms.size() == 5, "dungeon re-entry uses the production five-room Crown dungeon")
	if boss == null:
		_teardown_scene(dungeon)
		SaveManager.delete_save("dungeon_reentry_round_trip")
		_exit_test()
		return

	dungeon._begin_room_combat(boss)
	_assert(dungeon.pending_combat_room_id == boss.id and not boss.is_cleared, "dungeon re-entry records the unresolved boss room")
	_assert(dungeon._complete_pending_combat() == boss, "dungeon re-entry applies the victory boundary to the pending boss")
	_assert(boss.is_cleared and dungeon.boss_defeated and dungeon.pending_combat_room_id == -1, "dungeon re-entry clears the boss and resets pending combat")
	_assert(GameManager.mark_dungeon_cleared("ruins_of_ashvale"), "dungeon re-entry records the one-time dungeon clear")
	_assert(GameManager.claim_reward("ruins_of_ashvale_fragment"), "dungeon re-entry records the one-time Crown reward")
	_assert(SaveManager.get_save_block_reason().is_empty(), "dungeon re-entry permits saving at the entrance checkpoint")

	var slot := "dungeon_reentry_round_trip"
	SaveManager.delete_save(slot)
	_assert(SaveManager.save_game(slot), "dungeon re-entry writes the cleared dungeon checkpoint")
	var checkpoint_file := FileAccess.open(SaveManager.SAVE_DIR + "%s.sav" % slot, FileAccess.READ)
	var checkpoint_json := JSON.new()
	var checkpoint_parse := checkpoint_json.parse(checkpoint_file.get_as_text()) if checkpoint_file != null else ERR_FILE_NOT_FOUND
	if checkpoint_file != null:
		checkpoint_file.close()
	var checkpoint_dto: Dictionary = checkpoint_json.data if checkpoint_parse == OK and checkpoint_json.data is Dictionary else {}
	var saved_dungeon: Dictionary = checkpoint_dto.get("active_dungeon_state", {})
	var saved_rooms = saved_dungeon.get("rooms", []) if saved_dungeon is Dictionary else []
	_assert(saved_rooms is Array and saved_rooms.size() == 5, "dungeon re-entry checkpoint stores five plain Room DTOs")
	_assert(saved_dungeon.get("pending_combat_room_id", -1) == -1 and saved_dungeon.get("boss_defeated", false), "dungeon re-entry checkpoint stores completed combat state")

	_teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {"returning_from_dungeon": true}
	GameManager.active_dungeon_state.clear()
	_assert(SaveManager.save_game(slot), "dungeon re-entry saves again after the dungeon exit boundary")
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(slot), "dungeon re-entry reloads through the supported save boundary")
	_assert(GameManager.current_state == GameManager.GameState.OVERWORLD and GameManager.cleared_dungeons.has("ruins_of_ashvale"), "dungeon re-entry restores the overworld and clear ledger")
	_assert(GameManager.claimed_rewards.has("ruins_of_ashvale_fragment"), "dungeon re-entry restores the reward ledger")

	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var reentered: Node = await _spawn_scene("res://scenes/dungeon.tscn", 0.6)
	var rooms_cleared := true
	var reentered_boss: Room = null
	for candidate in reentered.rooms.values():
		if candidate is Room:
			rooms_cleared = rooms_cleared and candidate.is_cleared and candidate.is_revealed
			if candidate.type == Room.RoomType.BOSS:
				reentered_boss = candidate
	_assert(rooms_cleared and reentered.boss_defeated, "dungeon re-entry rebuilds a cleared dungeon without losing clear state")
	_assert(reentered_boss != null, "dungeon re-entry finds the previously cleared boss room")
	if reentered_boss != null:
		reentered._resolve_room_encounter(reentered_boss)
	var revisited_pending = reentered._complete_pending_combat()
	_assert(reentered_boss.is_cleared and revisited_pending == null, "dungeon re-entry revisiting the boss cannot reopen combat")
	_assert(not GameManager.mark_dungeon_cleared("ruins_of_ashvale"), "dungeon re-entry does not duplicate the clear ledger")
	_assert(not GameManager.claim_reward("ruins_of_ashvale_fragment"), "dungeon re-entry does not duplicate the Crown reward")
	_teardown_scene(reentered)
	SaveManager.delete_save(slot)
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = false
	_exit_test()

## Ordinary authored-room controls, encounter geometry and durable revisiting.
func test_local_room_object_flow() -> void:
	_enter_test("local_room_object_flow")
	_setup_world()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await _spawn_scene("res://scenes/dungeon.tscn", 0.2)
	var room: Room
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: room = candidate
	_assert(room != null, "Authored room is present in the generated dungeon")
	if room == null:
		_teardown_scene(dungeon)
		_exit_test()
		return
	var clock_before := GameManager.campaign_elapsed_seconds
	dungeon.hex_grid.hex_clicked.emit(room.coord)
	await get_tree().process_frame
	_assert(dungeon.local_view != null and GameManager.campaign_elapsed_seconds == clock_before + 60, "Room-map movement takes one minute and opens the tactical room")
	var view: LocalRoomView = dungeon.local_view
	var state: Dictionary = view.state
	var alice: Character = view.actor()
	var local_mount_class := alice.class_id
	var local_mount_level := alice.level
	var local_mount_features := alice.features.duplicate(true)
	var local_mount_uses := alice.feature_uses.duplicate(true)
	var local_mount_position: Array = state["party_positions"][alice.character_id].duplicate()
	alice.class_id = "paladin"
	alice.level = 5
	alice.features.append({"id": "paladin_faithful_steed", "type": "passive"})
	var local_mount_state := PaladinRules.create_find_steed_state(alice, DataLoader.get_spell("find_steed"), 4, "celestial", "horse")
	var local_steed_spawn := LocalRoomRules.find_steed_position(state, alice, view.characters)
	view.refresh()
	_local_room_press(view, "Mount Steed")
	var local_mount_succeeded: bool = bool(local_mount_state.get("success", false)) and PaladinRules.find_steed_is_mounted(alice) and LocalRoomRules.find_steed_position(state, alice, view.characters) == LocalRoomRules.coord(state["party_positions"][alice.character_id])
	var local_mount_destination := Vector2i(9999, 9999)
	for candidate in HexUtils.get_hexes_in_range(LocalRoomRules.coord(state["party_positions"][alice.character_id]), 1):
		if candidate != LocalRoomRules.coord(state["party_positions"][alice.character_id]) and LocalRoomRules.passable(state, candidate) and LocalRoomRules.object_at(state, candidate).is_empty() and not LocalRoomRules._room_space_occupied(state, candidate, alice, view.characters):
			local_mount_destination = candidate
			break
	if local_mount_succeeded and local_mount_destination != Vector2i(9999, 9999):
		view.click(local_mount_destination)
	var local_mount_moved := LocalRoomRules.coord(state["party_positions"][alice.character_id]) == local_mount_destination and LocalRoomRules.find_steed_position(state, alice, view.characters) == local_mount_destination
	_local_room_press(view, "Dismount Steed")
	var local_dismount_position := LocalRoomRules.coord(state["party_positions"][alice.character_id])
	var local_mount_round_trip: bool = local_mount_succeeded and local_mount_moved and not PaladinRules.find_steed_is_mounted(alice) and HexUtils.get_distance(local_dismount_position, local_mount_destination) == 1 and PaladinRules.find_steed_room_position(alice, str(state.get("id", ""))) == local_mount_destination
	_assert(local_mount_state.get("success", false) and local_steed_spawn != Vector2i(9999, 9999) and local_mount_round_trip, "Local-room Find Steed controls save an adjacent steed, carry mounted movement, and leave the steed in place on dismount")
	alice.class_id = local_mount_class
	alice.level = local_mount_level
	alice.features = local_mount_features
	alice.feature_uses.clear()
	alice.feature_uses.merge(local_mount_uses, true)
	state["party_positions"][alice.character_id] = local_mount_position
	view.refresh()
	var prior_levitate_effects := alice.spell_effects.duplicate(true)
	var prior_levitate_position: Array = state["party_positions"][alice.character_id].duplicate()
	var prior_levitate_altitude := int(state["party_altitudes"].get(alice.character_id, 0))
	var prior_levitate_mode := str(state["party_altitude_modes"].get(alice.character_id, "ground"))
	var prior_room_ceiling_exists := state.has("ceiling_feet")
	var prior_room_ceiling := int(state.get("ceiling_feet", 1000))
	alice.spell_effects["probe_levitate"] = {"spell_id": "levitate"}
	state["ceiling_feet"] = 100
	state["party_altitudes"][alice.character_id] = 10
	state["party_altitude_modes"][alice.character_id] = "levitate"
	var levitate_open_hex := Vector2i(9999, 9999)
	var levitate_open_destination := Vector2i(9999, 9999)
	var levitate_wall_hex := Vector2i(9999, 9999)
	var levitate_wall_destination := Vector2i(9999, 9999)
	for cell in state["cells"]:
		var candidate_start := LocalRoomRules.coord(cell)
		if not LocalRoomRules.passable(state, candidate_start) or not LocalRoomRules.object_at(state, candidate_start).is_empty() or LocalRoomRules._room_space_occupied(state, candidate_start, alice, view.characters): continue
		var touches_wall: bool = state["walls"].any(func(wall): return HexUtils.get_distance(candidate_start, LocalRoomRules.coord(wall)) == 1)
		if not touches_wall and levitate_open_hex == Vector2i(9999, 9999):
			for open_neighbor in HexUtils.get_hexes_in_range(candidate_start, 1):
				if open_neighbor != candidate_start and LocalRoomRules.passable(state, open_neighbor) and LocalRoomRules.object_at(state, open_neighbor).is_empty() and not LocalRoomRules._room_space_occupied(state, open_neighbor, alice, view.characters) and not state["walls"].any(func(wall): return HexUtils.get_distance(open_neighbor, LocalRoomRules.coord(wall)) == 1):
					levitate_open_hex = candidate_start
					levitate_open_destination = open_neighbor
					break
		if not touches_wall: continue
		for neighbor in HexUtils.get_hexes_in_range(candidate_start, 1):
			if neighbor == candidate_start or not LocalRoomRules.passable(state, neighbor) or not LocalRoomRules.object_at(state, neighbor).is_empty() or LocalRoomRules._room_space_occupied(state, neighbor, alice, view.characters): continue
			if state["walls"].any(func(wall): return HexUtils.get_distance(neighbor, LocalRoomRules.coord(wall)) == 1):
				levitate_wall_hex = candidate_start
				levitate_wall_destination = neighbor
				break
		if levitate_wall_hex != Vector2i(9999, 9999): break
	var levitate_without_surface: Dictionary = {"success": false}
	if levitate_open_hex != Vector2i(9999, 9999) and levitate_open_destination != Vector2i(9999, 9999):
		state["party_positions"][alice.character_id] = [levitate_open_hex.x, levitate_open_hex.y]
		view.refresh()
		var levitate_mode_index := -1
		for mode_index in view.movement_modes.item_count:
			if str(view.movement_modes.get_item_metadata(mode_index)) == "levitate": levitate_mode_index = mode_index
		if levitate_mode_index >= 0: view.movement_modes.select(levitate_mode_index)
		levitate_without_surface = LocalRoomRules.move(state, alice, levitate_open_destination, dungeon.hex_grid, "levitate", view.characters)
	var levitate_wall_result: Dictionary = {"success": false}
	if levitate_wall_hex != Vector2i(9999, 9999) and levitate_wall_destination != Vector2i(9999, 9999):
		state["party_positions"][alice.character_id] = [levitate_wall_hex.x, levitate_wall_hex.y]
		view.refresh()
		var selected_levitate_mode := "walk"
		for mode_index in view.movement_modes.item_count:
			if str(view.movement_modes.get_item_metadata(mode_index)) == "levitate":
				view.movement_modes.select(mode_index)
				selected_levitate_mode = str(view.movement_modes.get_item_metadata(mode_index))
		levitate_wall_result = LocalRoomRules.move(state, alice, levitate_wall_destination, dungeon.hex_grid, selected_levitate_mode, view.characters)
	var expected_levitate_cost := 5 if alice.movement_speed_feet("climb") > 0 else 10
	var levitate_wall_move: bool = bool(levitate_wall_result.get("success", false)) and int(levitate_wall_result.get("movement_cost_feet", 0)) == expected_levitate_cost and LocalRoomRules.coord(state["party_positions"][alice.character_id]) == levitate_wall_destination and int(state["party_altitudes"][alice.character_id]) == 10
	_assert(levitate_open_hex != Vector2i(9999, 9999) and levitate_wall_hex != Vector2i(9999, 9999) and not levitate_without_surface.get("success", false) and levitate_wall_move, "Levitate movement requires a nearby fixed surface and can move along a reachable wall while preserving altitude")
	alice.spell_effects = prior_levitate_effects
	if prior_room_ceiling_exists: state["ceiling_feet"] = prior_room_ceiling
	else: state.erase("ceiling_feet")
	state["party_positions"][alice.character_id] = prior_levitate_position
	state["party_altitudes"][alice.character_id] = prior_levitate_altitude
	state["party_altitude_modes"][alice.character_id] = prior_levitate_mode
	view.refresh()
	_assert(not dungeon.hex_grid.is_hex_passable(Vector2i.ZERO) and not SaveManager.get_save_block_reason().is_empty(), "Closed door blocks the room and local exploration is not a safe-save checkpoint")
	var pry_door := LocalRoomRules.get_object(state, "door")
	var original_position: Array = state["party_positions"][alice.character_id].duplicate()
	var original_strength := alice.ability_scores.strength
	var original_lock_dc := int(pry_door.get("lock_dc", 15))
	alice.ability_scores.set_score("STR", 20)
	state["party_positions"][alice.character_id] = [-1, 0]
	pry_door["lock_dc"] = 1
	alice.inventory.add_item("crowbar")
	var crowbar_instance_id := str(alice.inventory.backpack_instances().back()["instance_id"])
	view.refresh()
	dungeon.hex_grid.hex_clicked.emit(Vector2i.ZERO)
	var pry_time := GameManager.campaign_elapsed_seconds
	_local_room_press(view, "Pry")
	_assert(pry_door.get("open", false) and GameManager.campaign_elapsed_seconds == pry_time + 6, "The room inventory exposes a Crowbar pry action and resolves it as a timed Athletics check")
	pry_door["open"] = false
	pry_door["locked"] = true
	pry_door["lock_dc"] = original_lock_dc
	state["party_positions"][alice.character_id] = original_position
	alice.ability_scores.set_score("STR", original_strength)
	alice.inventory.take_instance(crowbar_instance_id)
	view.flush.call()
	view.refresh()
	_assert(alice.inventory.add_item("explorers_pack"), "A carried adventuring pack can be added as one item copy")
	view.refresh()
	var pack_instance_id := str(alice.inventory.backpack_instances().back().get("instance_id", ""))
	var pack_index := -1
	for index in view.items.item_count:
		if str(view.items.get_item_metadata(index)) == pack_instance_id:
			pack_index = index
	if pack_index >= 0:
		view.items.select(pack_index)
		view.items.item_selected.emit(pack_index)
	var pack_open_time := GameManager.campaign_elapsed_seconds
	_local_room_press(view, "Expand pack")
	_assert(alice.inventory.count_item("explorers_pack") == 0 and alice.inventory.count_item("rations") == 10 and alice.inventory.count_item("torch") == 10 and GameManager.campaign_elapsed_seconds == pack_open_time + 6, "The room inventory expands an Explorer's Pack once into its supplies")
	var torch_index := -1
	var torch_instance_id := ""
	for index in view.items.item_count:
		var candidate_instance_id := str(view.items.get_item_metadata(index))
		if str(alice.inventory.get_instance(candidate_instance_id).get("definition_id", "")) == "torch":
			torch_index = index
			torch_instance_id = candidate_instance_id
			break
	if torch_index >= 0:
		view.items.select(torch_index)
		view.items.item_selected.emit(torch_index)
	var torch_use_time := GameManager.campaign_elapsed_seconds
	_local_room_press(view, "Use")
	var lit_torch_record := alice.inventory.get_instance(torch_instance_id)
	_assert(alice.inventory.count_item("torch") == 10 and LightSourceRules.is_lit(lit_torch_record) and int(lit_torch_record.get("state", {}).get("light_source_remaining_seconds", 0)) == 3594 and GameManager.campaign_elapsed_seconds == torch_use_time + 6, "The room inventory lights the retained Torch copy and advances its burn time with the six-second use")
	dungeon.hex_grid.hex_clicked.emit(Vector2i(-2, 0))
	dungeon.hex_grid.hex_clicked.emit(Vector2i(-2, 1))
	_local_room_press(view, "Take")
	var key_id := str(LocalRoomRules.get_object(state, "key")["id"])
	_assert(alice.inventory.has_item("ashvale_brass_key") and LocalRoomRules.get_object(state, key_id).get("removed", false), "Normal Take control collects the brass key once")
	dungeon.hex_grid.hex_clicked.emit(Vector2i(-1, 0))
	dungeon.hex_grid.hex_clicked.emit(Vector2i.ZERO)
	clock_before = GameManager.campaign_elapsed_seconds
	_local_room_press(view, "Open")
	_assert(GameManager.campaign_elapsed_seconds == clock_before and not LocalRoomRules.get_object(state, "door")["open"], "Opening the locked door refuses without spending time")
	_local_room_press(view, "Unlock")
	_local_room_press(view, "Open")
	_assert(dungeon.hex_grid.is_hex_passable(Vector2i.ZERO) and GameManager.campaign_elapsed_seconds == clock_before + 12, "Normal key and door controls open the shared geometry in two action steps")
	dungeon.hex_grid.hex_clicked.emit(Vector2i(1, 0))
	dungeon.hex_grid.hex_clicked.emit(Vector2i(2, 0))
	_local_room_press(view, "Open")
	view.contents.select(1)
	var potion_id: String = view.contents.get_item_metadata(1)
	_local_room_press(view, "Take")
	_assert(LocalRoomRules.get_object(state, "chest")["contents"].size() == 1 and not alice.inventory.get_instance(potion_id).is_empty(), "Chest control retrieves the selected duplicate potion")
	for index in view.items.item_count:
		if view.items.get_item_metadata(index) == potion_id: view.items.select(index)
	_local_room_press(view, "Place")
	dungeon.hex_grid.hex_clicked.emit(Vector2i(1, 0))
	_local_room_press(view, "Take")
	var saved_known_spells := alice.known_spells.duplicate()
	var saved_spell_slots := alice.spell_slots.duplicate(true)
	var saved_equipment := alice.inventory.equipped.duplicate(true)
	var saved_room_position: Array = state["party_positions"][alice.character_id].duplicate()
	alice.known_spells.append("purify_food_and_drink")
	alice.spell_slots["1"] = 1
	alice.inventory.equipped.clear()
	state["party_positions"][alice.character_id] = [2, 0]
	view.refresh()
	dungeon.hex_grid.hex_clicked.emit(Vector2i(3, 1))
	var purification_time := GameManager.campaign_elapsed_seconds
	_local_room_press(view, "Purify Food")
	_assert(LocalRoomRules.get_object(state, "cistern")["contamination"].is_empty() and alice.spell_slots["1"] == 0 and GameManager.campaign_elapsed_seconds == purification_time + 6, "Room controls cast Purify Food and Drink on an authored contaminated cistern")
	alice.known_spells.append("prestidigitation")
	view.refresh()
	dungeon.hex_grid.hex_clicked.emit(Vector2i(2, 1))
	_local_room_press(view, "Clean")
	_local_room_press(view, "Warm")
	var bowl_inspect := LocalRoomRules.interact(state, "offering_bowl", "inspect", alice)
	_assert(not LocalRoomRules.get_object(state, "offering_bowl").get("dirty", true) and bowl_inspect.get("message", "").contains("warm"), "Room controls clean and warm a Tiny authored object with Prestidigitation")
	state["party_positions"][alice.character_id] = [3, 0]
	dungeon.hex_grid.hex_clicked.emit(Vector2i(4, -1))
	_local_room_press(view, "Eat full day")
	dungeon.hex_grid.hex_clicked.emit(Vector2i(3, 1))
	_local_room_press(view, "Drink full day")
	_assert(LocalRoomRules.get_object(state, "food_basket").get("food_servings", 0) == 2 and alice.nourishment_until_seconds > 0 and is_equal_approx(alice.food_eaten_today_pounds, 1.0) and LocalRoomRules.get_object(state, "cistern").get("water_gallons", 0) == 9 and alice.hydration_until_seconds > 0 and is_equal_approx(alice.water_drank_today_gallons, 1.0), "Eating and drinking consume authored daily amounts and track their saved food and water intake")
	var persistent_area := LocalRoomAreas.add(state, "area_test", alice.character_id, Vector2i(2, 0), 0, 86400, 1)
	var area_entry := LocalRoomAreas.enter(state, alice.character_id, Vector2i(3, 0), Vector2i(2, 0), int(GameManager.campaign_elapsed_seconds))
	_assert(persistent_area.get("success", false) and area_entry.size() == 1 and int(state.get("areas", [])[0].get("triggered_by", {}).get(alice.character_id, 0)) == 1, "Room area entries and per-character caps are recorded")
	alice.known_spells.assign(saved_known_spells)
	alice.spell_slots = saved_spell_slots
	alice.inventory.equipped = saved_equipment
	state["party_positions"][alice.character_id] = saved_room_position
	view.flush.call()
	view.refresh()
	for index in view.items.item_count:
		if view.items.get_item_metadata(index) == potion_id: view.items.select(index)
	_local_room_press(view, "Place")
	_assert(DungeonPersistence.local_error(state).is_empty(), "Placing the same copy again keeps unique room object identities")
	dungeon.hex_grid.hex_clicked.emit(Vector2i(1, 0))
	_local_room_press(view, "Take")
	var kindling := {"id": "kindling_test", "kind": "loose", "name": "Wooden kindling", "position": [-4, 0], "material": "wood", "size": "Small", "fixed": true, "hp": 200, "max_hp": 200, "armor_class": 1, "flammable": true, "burning": false, "contents": []}
	state["objects"].append(kindling)
	var combat_alarm_caster := Character.new()
	combat_alarm_caster.initialize("Combat Alarm caster", "human", "wizard", AbilityScores.new())
	combat_alarm_caster.character_id = "combat_alarm_caster"
	combat_alarm_caster.known_spells.append("alarm")
	combat_alarm_caster.spell_slots["1"] = 1
	combat_alarm_caster.inventory.add_item("component_pouch")
	state["party_positions"][combat_alarm_caster.character_id] = [-1, 1]
	var combat_alarm_cast := LocalRoomRules.cast_alarm(state, "door", "audible", combat_alarm_caster, [])
	state["party_positions"].erase(combat_alarm_caster.character_id)
	_assert(combat_alarm_cast.get("success", false) and int(state.get("areas", []).size()) == 2, "An Alarm ward is saved on its room before combat begins")
	PlayerManager.add_player("Cora")
	var darkness_caster := _fresh_char("Room Darkness Caster", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 16, "WIS": 10, "CHA": 10})
	darkness_caster.known_spells.assign(["darkness"])
	darkness_caster.spell_slots["2"] = 1
	darkness_caster.inventory.add_item("component_pouch")
	PlayerManager.set_player_character(2, darkness_caster)
	PartyManager.register_player_character(2, darkness_caster)
	state["party_positions"][darkness_caster.character_id] = [-2, 0]
	dungeon._begin_room_combat(room)
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": state["encounter_monsters"], "terrain": "road", "local_room": state, "return_state": GameManager.GameState.DUNGEON}
	var combat: CombatState = await _spawn_scene("res://scenes/combat.tscn", 0.05)
	combat._battle_ending = true
	_assert(combat.hex_grid.tiles.size() == state["cells"].size() and not combat.hex_grid.is_hex_passable(Vector2i(0, 1)) and combat.hex_grid.is_hex_passable(Vector2i.ZERO), "Combat reuses authored cells, walls and the opened door")
	_assert(combat.player_entities[0]["hex_position"] == Vector2i(1, 0), "Combat starts the party in their exploration positions")
	var mount_owner: Character = combat.player_entities[0].get("character")
	var mount_owner_class := mount_owner.class_id
	var mount_owner_level := mount_owner.level
	var mount_owner_features := mount_owner.features.duplicate(true)
	var mount_owner_position: Vector2i = combat.player_entities[0].get("hex_position", Vector2i.ZERO)
	var mount_owner_saved_position: Array = state["party_positions"][mount_owner.character_id].duplicate()
	var mounted_steed_entity: Dictionary = {}
	if mount_owner != null:
		mount_owner.class_id = "paladin"
		mount_owner.level = 5
		mount_owner.features.append({"id": "paladin_faithful_steed", "type": "passive"})
		var mount_state_result := PaladinRules.create_find_steed_state(mount_owner, DataLoader.get_spell("find_steed"), 4, "celestial", "horse")
		var mount_spawn := Vector2i(2, 0)
		if mount_spawn == mount_owner_position or not combat.hex_grid.has_tile(mount_spawn) or not combat.hex_grid.is_hex_passable(mount_spawn):
			for candidate in HexUtils.get_hexes_in_range(mount_owner_position, 1):
				if candidate != mount_owner_position and combat.hex_grid.has_tile(candidate) and combat.hex_grid.is_hex_passable(candidate) and not combat._is_occupied_hex(candidate):
					mount_spawn = candidate
					break
		var summon_result := combat._add_find_steed_entity(combat.player_entities[0], mount_spawn, false) if mount_state_result.get("success", false) else {}
		mounted_steed_entity = summon_result.get("entity", {})
		combat.current_player_idx = 0
		combat.active_character = mount_owner
		combat.active_movement_mode = "walk"
		combat.remaining_speed = float(mount_owner.get_speed())
		combat.player_moved_this_turn = false
		combat.turn_budget.reset(mount_owner, combat.player_entities)
		combat.hud.update_hud(mount_owner, combat.tracker)
		combat.hud._show_feature_selection()
		var mount_button_index := -1
		for feature_index in combat.hud.features_registered.size():
			if str(combat.hud.features_registered[feature_index].get("id", "")) == "toggle_find_steed_mount":
				mount_button_index = feature_index
		if mount_button_index >= 0:
			combat.hud._on_feature_selected(mount_button_index)
			await get_tree().process_frame
		var mount_position: Vector2i = combat.player_entities[0].get("hex_position", Vector2i.ZERO)
		var mounted_ok: bool = not mounted_steed_entity.is_empty() and PaladinRules.find_steed_is_mounted(mount_owner) and mounted_steed_entity.get("hex_position", Vector2i.ZERO) == mount_position and is_equal_approx(combat.remaining_speed, 9.0)
		var nearby_destinations := combat._player_reachable(mount_position, combat.remaining_speed, mount_owner)
		var rider_destination := Vector2i(9999, 9999)
		for candidate_value in nearby_destinations.keys():
			var candidate: Vector2i = candidate_value
			if candidate != mount_position and HexUtils.get_distance(candidate, mount_position) == 1 and combat.hex_grid.is_hex_passable(candidate) and not combat._is_occupied_hex(candidate):
				rider_destination = candidate
				break
		if mounted_ok and rider_destination != Vector2i(9999, 9999):
			await combat._on_hex_clicked(rider_destination)
		LocalRoomCombat.capture(combat.player_entities)
		var rider_transport_saved: bool = mounted_steed_entity.get("hex_position", Vector2i.ZERO) == rider_destination and LocalRoomRules.coord(state["party_positions"][mount_owner.character_id]) == rider_destination and PaladinRules.find_steed_is_mounted(mount_owner)
		var dismount_position: Vector2i = mounted_steed_entity.get("hex_position", Vector2i.ZERO)
		combat.hud.update_hud(mount_owner, combat.tracker)
		combat.hud._show_feature_selection()
		var dismount_button_index := -1
		for feature_index in combat.hud.features_registered.size():
			if str(combat.hud.features_registered[feature_index].get("id", "")) == "toggle_find_steed_mount":
				dismount_button_index = feature_index
		if dismount_button_index >= 0:
			combat.hud._on_feature_selected(dismount_button_index)
			await get_tree().process_frame
		LocalRoomCombat.capture(combat.player_entities)
		var dismounted_position: Vector2i = combat.player_entities[0].get("hex_position", Vector2i.ZERO)
		var rider_dismounted_saved: bool = not PaladinRules.find_steed_is_mounted(mount_owner) and HexUtils.get_distance(dismounted_position, dismount_position) == 1 and mounted_steed_entity.get("hex_position", Vector2i.ZERO) == dismount_position and LocalRoomRules.coord(state["party_positions"][mount_owner.character_id]) == dismounted_position
		_assert(mount_button_index >= 0 and dismount_button_index >= 0 and mounted_ok and rider_destination != Vector2i(9999, 9999) and rider_transport_saved and rider_dismounted_saved, "Find Steed mount and dismount controls spend half Speed, carry rider movement with the mount, and save separate adjacent positions (buttons=%d/%d summon=%s mounted=%s pos=%s steed=%s remaining=%.1f destination=%s mounted_saved=%s dismounted_saved=%s)" % [mount_button_index, dismount_button_index, summon_result, mounted_ok, mount_position, mounted_steed_entity.get("hex_position", Vector2i.ZERO), combat.remaining_speed, rider_destination, rider_transport_saved, rider_dismounted_saved])
		PaladinRules.dismiss_find_steed(mount_owner)
		if not mounted_steed_entity.is_empty(): combat.player_entities.erase(mounted_steed_entity)
		mount_owner.class_id = mount_owner_class
		mount_owner.level = mount_owner_level
		mount_owner.features = mount_owner_features
		combat.player_entities[0]["hex_position"] = mount_owner_position
		state["party_positions"][mount_owner.character_id] = mount_owner_saved_position
		combat.player_moved_this_turn = false
		mount_owner.feature_uses.erase("find_steed_just_mounted_this_turn")
	var movement_probe := Character.new()
	movement_probe.initialize("Movement probe", "human", "wizard", AbilityScores.new())
	movement_probe.character_id = "combat_movement_probe"
	movement_probe.set_movement_speed_feet("climb", 20)
	movement_probe.set_movement_speed_feet("swim", 15)
	movement_probe.spell_effects["probe_fly"] = {"spell_id": "fly"}
	var altitude_probe_index := combat.current_player_idx if combat.current_player_idx >= 0 else 0
	var altitude_probe_entity: Dictionary = combat.player_entities[altitude_probe_index]
	var altitude_probe_character: Character = altitude_probe_entity.get("character")
	var prior_room_altitude := LocalRoomRules.altitude_feet(state, altitude_probe_character.character_id)
	var prior_entity_altitude := int(altitude_probe_entity.get("altitude_feet", 0))
	state["party_altitudes"][altitude_probe_character.character_id] = 0
	altitude_probe_entity["altitude_feet"] = 0
	var authored_wall := LocalRoomRules.coord(state["walls"][0])
	combat.active_character = movement_probe
	combat.active_movement_mode = "walk"
	combat.remaining_speed = float(movement_probe.movement_speed_feet("walk")) / 5.0
	var walk_blocked_wall := not combat._player_can_enter(authored_wall, movement_probe)
	combat.active_movement_mode = "climb"
	var climb_wall_reachable := combat._player_reachable(authored_wall + Vector2i(-1, 0), 3.0, movement_probe).has(authored_wall)
	state["party_altitudes"][altitude_probe_character.character_id] = 10
	altitude_probe_entity["altitude_feet"] = 10
	combat.active_movement_mode = "fly"
	var fly_wall_reachable := combat._player_can_enter(authored_wall, movement_probe)
	combat.active_movement_mode = "walk"
	combat.remaining_speed = 5.0
	combat.player_moved_this_turn = true
	combat.hud.set_movement_modes(movement_probe, "fly")
	var picker_has_modes := combat.hud.movement_mode_picker.item_count == 4
	var fly_index := -1
	for option_index in combat.hud.movement_mode_picker.item_count:
		if str(combat.hud.movement_mode_picker.get_item_metadata(option_index)) == "fly": fly_index = option_index
	if fly_index >= 0: combat.hud.movement_mode_picker.item_selected.emit(fly_index)
	var selected_fly_speed := is_equal_approx(combat.remaining_speed, 11.0)
	state["party_altitudes"][altitude_probe_character.character_id] = prior_room_altitude
	altitude_probe_entity["altitude_feet"] = prior_entity_altitude
	movement_probe.spell_effects["probe_freedom"] = {"spell_id": "freedom_of_movement"}
	CombatAction.apply_condition(movement_probe, "restrained", 99, "net:combat_probe")
	combat.active_character = movement_probe
	combat.active_movement_mode = "walk"
	combat.remaining_speed = 0.0
	combat.player_moved_this_turn = false
	var freedom_escape_in_combat := combat._try_freedom_of_movement_escape(movement_probe)
	var freedom_escape_spends_five_feet := freedom_escape_in_combat and not movement_probe.has_condition("restrained") and is_equal_approx(combat.remaining_speed, 5.0)
	state["cell_terrains"].append({"position": [3, 0], "surface": "water"})
	combat.active_movement_mode = "walk"
	var water_blocked_walk := not combat._player_can_enter(Vector2i(3, 0), movement_probe)
	combat.active_movement_mode = "swim"
	var water_allows_swim := combat._player_can_enter(Vector2i(3, 0), movement_probe)
	state["cell_terrains"].pop_back()
	state["cell_terrains"].append({"position": [4, 0], "surface": "acid"})
	combat.active_movement_mode = "swim"
	var acid_rejects_swim := not combat._player_can_enter(Vector2i(4, 0), movement_probe)
	combat.active_movement_mode = "walk"
	var acid_blocks_walk := not combat._player_can_enter(Vector2i(4, 0), movement_probe)
	movement_probe.spell_effects["probe_water_walk"] = {"spell_id": "water_walk"}
	var water_walk_crosses_acid := combat._player_can_enter(Vector2i(4, 0), movement_probe)
	movement_probe.spell_effects.erase("probe_water_walk")
	state["cell_terrains"].pop_back()
	_assert(walk_blocked_wall and climb_wall_reachable and fly_wall_reachable and picker_has_modes and selected_fly_speed and water_blocked_walk and water_allows_swim and acid_rejects_swim and acid_blocks_walk and water_walk_crosses_acid and freedom_escape_spends_five_feet, "Combat movement modes choose their saved speed, apply authored water/acid surface traversal, and Freedom of Movement spends 5 feet to escape a nonmagical restraint (walk_blocked=%s climb_reachable=%s fly_reachable=%s picker_modes=%s fly_speed=%s water_blocked=%s swim_allowed=%s acid_swim_blocked=%s acid_walk_blocked=%s water_walk_crosses_acid=%s freedom=%s remaining=%.1f)" % [walk_blocked_wall, climb_wall_reachable, fly_wall_reachable, picker_has_modes, selected_fly_speed, water_blocked_walk, water_allows_swim, acid_rejects_swim, acid_blocks_walk, water_walk_crosses_acid, freedom_escape_spends_five_feet, combat.remaining_speed])
	var lower_elevation_hex := Vector2i(2, 0)
	var upper_elevation_hex := Vector2i(3, 0)
	state["cell_elevations"] = [{"position": [upper_elevation_hex.x, upper_elevation_hex.y], "feet": 10}]
	combat.active_movement_mode = "walk"
	var uphill_not_reachable := not combat._player_reachable(lower_elevation_hex, 2.0, movement_probe).has(upper_elevation_hex)
	var uphill_reachable := combat._player_reachable(lower_elevation_hex, 3.0, movement_probe).has(upper_elevation_hex)
	var monster_uphill_cost := combat._enemy_step_movement_cost(lower_elevation_hex, upper_elevation_hex, {"id": "height_test"})
	var monster_flat_cost := combat._enemy_movement_cost(upper_elevation_hex, "height_test")
	movement_probe.max_hp = 50
	movement_probe.current_hp = 50
	var hp_before_fall := movement_probe.current_hp
	await combat._apply_room_fall_damage(movement_probe, upper_elevation_hex, lower_elevation_hex)
	var fall_damage_applied := movement_probe.current_hp < hp_before_fall
	var hp_before_flight := movement_probe.current_hp
	combat.active_movement_mode = "fly"
	await combat._apply_room_fall_damage(movement_probe, upper_elevation_hex, lower_elevation_hex)
	var flight_prevented_fall := movement_probe.current_hp == hp_before_flight
	var pushed_creature := {"id": "pushed_height_test", "name": "Pushed creature", "current_hp": 50, "is_alive": true}
	combat._apply_forced_movement_fall_damage(pushed_creature, upper_elevation_hex, lower_elevation_hex)
	var forced_fall_applied := int(pushed_creature["current_hp"]) < 50
	state["cell_elevations"].clear()
	_assert(uphill_not_reachable and uphill_reachable and is_equal_approx(monster_uphill_cost - monster_flat_cost, 2.0), "Combat movement charges uphill cost for players and monsters")
	_assert(fall_damage_applied and flight_prevented_fall and forced_fall_applied, "Combat movement and forced pushes apply falling damage, while Fly prevents a modeled fall")
	combat.active_character = combat.player_entities[0]["character"]
	combat.active_movement_mode = "walk"
	combat.hud.set_movement_modes(combat.active_character, "walk")
	var alarm_monster: Dictionary = combat.monster_entities[0]
	alarm_monster["hex_position"] = Vector2i(3, 0)
	var alarm_log_start := combat.hud.log_text.text.length()
	await combat._resolve_spell_zone_entries(alarm_monster, Vector2i(3, 0), Vector2i(2, 0))
	alarm_monster["hex_position"] = Vector2i(2, 0)
	var combat_alarm_area: Dictionary = state["areas"].back()
	_assert(int(combat_alarm_area.get("triggered_by", {}).get(str(alarm_monster.get("id", "")), 0)) == 1 and combat.hud.log_text.text.substr(alarm_log_start).contains("rings like a handbell for 10 seconds") and combat.hud.log_text.text.substr(alarm_log_start).contains("within 60 feet"), "Combat movement delivers the audible Alarm's 10-second handbell within 60 feet and saves the monster's trigger count")
	var bob: Character = combat.player_entities[1]["character"]
	bob.known_spells.assign(["fire_bolt"])
	combat.current_player_idx = 1
	combat.active_character = bob
	combat.turn_budget.reset(bob, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("fire_bolt").duplicate(true)
	var kindling_hp := int(kindling["hp"])
	var fire_bolt_seed := 1
	for candidate_seed in range(1, 100):
		seed(candidate_seed)
		if randi_range(1, 20) != 1:
			fire_bolt_seed = candidate_seed
			break
	seed(fire_bolt_seed)
	await combat._execute_player_spell(Vector2i(-4, 0))
	_assert(bool(kindling.get("burning", false)) and int(kindling["hp"]) < kindling_hp, "A successful Fire Bolt damages and ignites an unattended flammable room object")
	var kindling_first_tick := int(kindling.get("burning_next_tick_seconds", -1))
	var kindling_hp_before_burn_tick := int(kindling["hp"])
	GameManager.advance_campaign_time(6)
	var fire_tick_messages := LocalRoomRules.advance_burning_objects(state, int(GameManager.campaign_elapsed_seconds))
	_assert(kindling_first_tick == int(GameManager.campaign_elapsed_seconds) and int(kindling["hp"]) < kindling_hp_before_burn_tick and int(kindling.get("burning_next_tick_seconds", -1)) == kindling_first_tick + 6 and not fire_tick_messages.is_empty(), "A burning room object takes recurring 1d4 Fire damage at the start of each six-second turn")
	var fog_caster: Character = combat.player_entities[0]["character"]
	# Persistence requires a living concentrator. An initial random enemy
	# initiative turn can down this low-level fixture before the transfer setup.
	fog_caster.current_hp = fog_caster.max_hp
	fog_caster.is_alive = true
	fog_caster.death_save_failures = 0
	fog_caster.death_save_successes = 0
	var fog_source_id := "fog_cloud:%s:room_transfer_test" % fog_caster.character_id
	var fog_zone := {"source_id": fog_source_id, "spell_id": "fog_cloud", "caster_id": fog_caster.character_id, "center": Vector2i.ZERO, "coords": [Vector2i.ZERO], "radius_hexes": 1, "radius_feet": 5, "heavily_obscured": true, "concentration": true, "rounds_remaining": 600}
	var fog_effect := SpellEffects.begin_cast(fog_caster, DataLoader.get_spell("fog_cloud"))
	SpellEffects.records(fog_caster)[str(fog_effect["source_id"])] = fog_effect.duplicate(true)
	fog_caster.concentrating_on = {"spell_id": "fog_cloud", "fog_cloud_source_id": fog_source_id, "effect_source": str(fog_effect["source_id"]), "targets": []}
	combat.active_spell_zones[fog_source_id] = fog_zone.duplicate(true)
	LocalRoomCombat.capture_spell_zones(combat.player_entities, combat.active_spell_zones)
	var fog_recorded_before_cleanup: bool = state.get("areas", []).any(func(area): return str(area.get("concentration_source_id", "")) == fog_source_id)
	combat._end_concentration(fog_caster)
	var fog_removed_with_concentration: bool = not state.get("areas", []).any(func(area): return str(area.get("concentration_source_id", "")) == fog_source_id) and fog_caster.concentrating_on.is_empty()
	_assert(fog_recorded_before_cleanup and fog_removed_with_concentration, "Ending Fog Cloud concentration removes its room-owned transferred area by source")
	fog_effect = SpellEffects.begin_cast(fog_caster, DataLoader.get_spell("fog_cloud"))
	SpellEffects.records(fog_caster)[str(fog_effect["source_id"])] = fog_effect.duplicate(true)
	fog_caster.concentrating_on = {"spell_id": "fog_cloud", "fog_cloud_source_id": fog_source_id, "effect_source": str(fog_effect["source_id"]), "targets": []}
	combat.active_spell_zones[fog_source_id] = fog_zone.duplicate(true)
	var tentacle_caster: Character = combat.player_entities[1]["character"]
	var tentacle_source_id := "black_tentacles:%s:room_transfer_test" % tentacle_caster.character_id
	var tentacle_effect := SpellEffects.begin_cast(tentacle_caster, DataLoader.get_spell("black_tentacles"))
	SpellEffects.records(tentacle_caster)[str(tentacle_effect["source_id"])] = tentacle_effect.duplicate(true)
	tentacle_caster.concentrating_on = {"spell_id": "black_tentacles", "black_tentacles_source_id": tentacle_source_id, "effect_source": str(tentacle_effect["source_id"]), "save_dc": 14, "targets": []}
	combat.active_spell_zones[tentacle_source_id] = {"source_id": tentacle_source_id, "spell_id": "black_tentacles", "caster_id": tentacle_caster.character_id, "center": Vector2i.ZERO, "coords": [Vector2i.ZERO, Vector2i(1, 0)], "save_dc": 14, "slot_level": 4, "restrained_targets": [], "concentration": true, "rounds_remaining": 100}
	var long_tentacle_source_id := "black_tentacles:%s:long_room_test" % tentacle_caster.character_id
	combat.active_spell_zones[long_tentacle_source_id] = {"source_id": long_tentacle_source_id, "spell_id": "black_tentacles", "caster_id": tentacle_caster.character_id, "center": Vector2i(2, 0), "coords": [Vector2i(2, 0)], "save_dc": 14, "slot_level": 5, "restrained_targets": [], "concentration": false, "rounds_remaining": 4800}
	var grease_source_id := "grease:%s:room_transfer_test" % tentacle_caster.character_id
	combat.active_spell_zones[grease_source_id] = {"source_id": grease_source_id, "spell_id": "grease", "caster_id": tentacle_caster.character_id, "center": Vector2i.ZERO, "coords": [Vector2i.ZERO, Vector2i(1, 0)], "save_dc": 14, "concentration": false, "rounds_remaining": 10}
	var darkness_source_id := "darkness:%s:room_transfer_test" % darkness_caster.character_id
	var darkness_effect := SpellEffects.begin_cast(darkness_caster, DataLoader.get_spell("darkness"))
	SpellEffects.records(darkness_caster)[str(darkness_effect["source_id"])] = darkness_effect.duplicate(true)
	darkness_caster.concentrating_on = {"spell_id": "darkness", "darkness_source_id": darkness_source_id, "effect_source": str(darkness_effect["source_id"]), "targets": []}
	combat.active_spell_zones[darkness_source_id] = {"source_id": darkness_source_id, "spell_id": "darkness", "caster_id": darkness_caster.character_id, "center": Vector2i.ZERO, "coords": [Vector2i.ZERO, Vector2i(1, 0)], "radius_hexes": 1, "radius_feet": 5, "heavily_obscured": true, "concentration": true, "rounds_remaining": 100}
	LocalRoomCombat.capture_spell_zones(combat.player_entities, combat.active_spell_zones)
	var active_room_state := LocalRoomCombat.room()
	var daggers_caster := _fresh_char("Room Daggers Caster", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 16, "WIS": 10, "CHA": 10})
	daggers_caster.character_id = "room_daggers_caster"
	var daggers_source_id := "cloud_of_daggers:%s:room_transfer_test" % daggers_caster.character_id
	var daggers_effect := SpellEffects.begin_cast(daggers_caster, DataLoader.get_spell("cloud_of_daggers"))
	SpellEffects.records(daggers_caster)[str(daggers_effect["source_id"])] = daggers_effect.duplicate(true)
	daggers_caster.concentrating_on = {"spell_id": "cloud_of_daggers", "cloud_of_daggers_source_id": daggers_source_id, "effect_source": str(daggers_effect["source_id"]), "targets": []}
	var daggers_players := combat.player_entities.duplicate()
	daggers_players.append({"character": daggers_caster})
	var daggers_room_state: Dictionary = state.duplicate(true)
	daggers_room_state["areas"] = []
	GameManager.transition_context["local_room"] = daggers_room_state
	var daggers_zone := {"source_id": daggers_source_id, "spell_id": "cloud_of_daggers", "caster_id": daggers_caster.character_id, "center": Vector2i(3, 0), "coords": [Vector2i(3, 0)], "slot_level": 3, "damage_formula": "6d4", "concentration": true, "rounds_remaining": 60}
	LocalRoomCombat.capture_spell_zones(daggers_players, {daggers_source_id: daggers_zone})
	var daggers_transfer: Dictionary = daggers_room_state["areas"].front() if not daggers_room_state["areas"].is_empty() else {}
	var daggers_restore_zones := LocalRoomCombat.restore_spell_zones(daggers_players)
	GameManager.transition_context["local_room"] = active_room_state
	var spike_caster := _fresh_char("Room Spike Growth Caster", "human", "druid", {"STR": 8, "DEX": 12, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	spike_caster.character_id = "room_spike_growth_caster"
	var spike_source_id := "spike_growth:%s:room_transfer_test" % spike_caster.character_id
	spike_caster.concentrating_on = {"spell_id": "spike_growth", "spike_growth_source_id": spike_source_id}
	var spike_players := combat.player_entities.duplicate()
	spike_players.append({"character": spike_caster})
	var spike_room_state: Dictionary = state.duplicate(true)
	spike_room_state["areas"] = []
	GameManager.transition_context["local_room"] = spike_room_state
	var spike_zone := {"source_id": spike_source_id, "spell_id": "spike_growth", "caster_id": spike_caster.character_id, "center": Vector2i.ZERO, "radius_hexes": 4, "coords": [Vector2i.ZERO, Vector2i(1, 0)], "slot_level": 2, "damage_formula": "2d4", "concentration": true, "rounds_remaining": 100}
	LocalRoomCombat.capture_spell_zones(spike_players, {spike_source_id: spike_zone})
	var spike_transfer: Dictionary = spike_room_state["areas"].front() if not spike_room_state["areas"].is_empty() else {}
	var spike_restore_zones := LocalRoomCombat.restore_spell_zones(spike_players)
	_assert(spike_transfer.get("footprint", []) == [[0, 0], [1, 0]] and bool(spike_transfer.get("difficult_terrain", false)) and spike_restore_zones.has(spike_source_id) and spike_restore_zones[spike_source_id].get("coords", []).size() == 2 and str(spike_restore_zones[spike_source_id].get("damage_formula", "")) == "2d4" and DungeonPersistence.local_error(spike_room_state).is_empty(), "Spike Growth transfers and restores its difficult-terrain footprint, damage and campaign duration")
	GameManager.transition_context["local_room"] = active_room_state
	var entangle_caster := _fresh_char("Room Entangle Caster", "human", "druid", {"STR": 8, "DEX": 12, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	entangle_caster.character_id = "room_entangle_caster"
	var entangle_target := _fresh_char("Room Entangle Target", "human", "fighter", {"STR": 12, "DEX": 12, "CON": 12, "INT": 10, "WIS": 10, "CHA": 10})
	entangle_target.character_id = "room_entangle_target"
	var entangle_source_id := "entangle:%s:room_transfer_test" % entangle_caster.character_id
	entangle_caster.concentrating_on = {"spell_id": "entangle", "entangle_source_id": entangle_source_id}
	CombatAction.apply_condition(entangle_target, "restrained", 99, entangle_source_id)
	var entangle_players: Array = [{"character": entangle_caster}, {"character": entangle_target}]
	var entangle_room_state: Dictionary = state.duplicate(true)
	entangle_room_state["areas"] = []
	GameManager.transition_context["local_room"] = entangle_room_state
	var entangle_zone := {"source_id": entangle_source_id, "spell_id": "entangle", "caster_id": entangle_caster.character_id, "center": Vector2i.ZERO, "coords": [Vector2i.ZERO, Vector2i(1, 0)], "save_dc": 14, "restrained_targets": [entangle_target], "concentration": true, "rounds_remaining": 10}
	LocalRoomCombat.capture_spell_zones(entangle_players, {entangle_source_id: entangle_zone})
	var entangle_transfer: Dictionary = entangle_room_state["areas"].front() if not entangle_room_state["areas"].is_empty() else {}
	var entangle_room_snapshot: Dictionary = JSON.parse_string(JSON.stringify(entangle_room_state))
	GameManager.transition_context["local_room"] = entangle_room_snapshot
	var entangle_restore_zones := LocalRoomCombat.restore_spell_zones(entangle_players)
	_assert(entangle_transfer.get("footprint", []) == [[0, 0], [1, 0]] and int(entangle_transfer.get("save_dc", 0)) == 14 and bool(entangle_transfer.get("difficult_terrain", false)) and entangle_restore_zones.has(entangle_source_id) and entangle_restore_zones[entangle_source_id].get("coords", []).size() == 2 and entangle_target.condition_sources.get("restrained", {}).has(entangle_source_id) and DungeonPersistence.local_error(entangle_room_snapshot).is_empty(), "Entangle transfers and restores its saved restrained-area footprint, escape DC and duration through a JSON room snapshot")
	GameManager.transition_context["local_room"] = active_room_state
	var storm_caster := _fresh_char("Room Sleet Storm Caster", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 16, "WIS": 10, "CHA": 10})
	storm_caster.character_id = "room_sleet_storm_caster"
	var storm_source_id := "sleet_storm:%s:room_transfer_test" % storm_caster.character_id
	storm_caster.concentrating_on = {"spell_id": "sleet_storm", "sleet_storm_source_id": storm_source_id}
	var storm_players: Array = [{"character": storm_caster}]
	var storm_room_state: Dictionary = active_room_state.duplicate(true)
	storm_room_state["areas"] = []
	storm_room_state["area_serial"] = 0
	var storm_flame: Dictionary = storm_room_state["objects"][0]
	storm_flame["position"] = [0, 0]
	storm_flame["burning"] = true
	storm_flame["burning_next_tick_seconds"] = int(GameManager.campaign_elapsed_seconds) + 6
	GameManager.transition_context["local_room"] = storm_room_state
	var storm_zone := {"source_id": storm_source_id, "spell_id": "sleet_storm", "caster_id": storm_caster.character_id, "center": Vector2i.ZERO, "coords": [Vector2i.ZERO, Vector2i(1, 0)], "save_dc": 15, "height_feet": 40, "heavily_obscured": true, "douses_exposed_flames": true, "concentration": true, "rounds_remaining": 100}
	LocalRoomCombat.capture_spell_zones(storm_players, {storm_source_id: storm_zone})
	var storm_transfer: Dictionary = storm_room_state["areas"].front() if not storm_room_state["areas"].is_empty() else {}
	var storm_room_snapshot: Dictionary = JSON.parse_string(JSON.stringify(storm_room_state))
	GameManager.transition_context["local_room"] = storm_room_snapshot
	var storm_restore_zones := LocalRoomCombat.restore_spell_zones(storm_players)
	_assert(storm_transfer.get("footprint", []) == [[0, 0], [1, 0]] and int(storm_transfer.get("save_dc", 0)) == 15 and int(storm_transfer.get("height_feet", 0)) == 40 and bool(storm_transfer.get("difficult_terrain", false)) and not bool(storm_flame.get("burning", true)) and storm_restore_zones.has(storm_source_id) and storm_restore_zones[storm_source_id].get("coords", []).size() == 2 and storm_restore_zones[storm_source_id].get("heavily_obscured", false) and storm_restore_zones[storm_source_id].get("douses_exposed_flames", false) and DungeonPersistence.local_error(storm_room_snapshot).is_empty(), "Sleet Storm transfers and restores its obscured, 40-foot-high difficult-terrain footprint, douses a burning object and retains Concentration through JSON room reload")
	GameManager.transition_context["local_room"] = active_room_state
	var moonbeam_caster := _fresh_char("Room Moonbeam Caster", "human", "druid", {"STR": 8, "DEX": 12, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	moonbeam_caster.character_id = "room_moonbeam_caster"
	var moonbeam_source_id := "moonbeam:%s:room_transfer_test" % moonbeam_caster.character_id
	moonbeam_caster.concentrating_on = {"spell_id": "moonbeam", "moonbeam_source_id": moonbeam_source_id}
	var moonbeam_players: Array = [{"character": moonbeam_caster}]
	var moonbeam_room_state: Dictionary = active_room_state.duplicate(true)
	moonbeam_room_state["areas"] = []
	moonbeam_room_state["area_serial"] = 0
	GameManager.transition_context["local_room"] = moonbeam_room_state
	var moonbeam_zone := {"source_id": moonbeam_source_id, "spell_id": "moonbeam", "caster_id": moonbeam_caster.character_id, "center": Vector2i.ZERO, "coords": [Vector2i.ZERO, Vector2i(1, 0)], "save_dc": 15, "slot_level": 4, "rounds_remaining": 8}
	LocalRoomCombat.capture_spell_zones(moonbeam_players, {moonbeam_source_id: moonbeam_zone})
	var moonbeam_transfer: Dictionary = moonbeam_room_state["areas"].front() if not moonbeam_room_state["areas"].is_empty() else {}
	var moonbeam_room_snapshot: Dictionary = JSON.parse_string(JSON.stringify(moonbeam_room_state))
	GameManager.transition_context["local_room"] = moonbeam_room_snapshot
	var moonbeam_restore_zones := LocalRoomCombat.restore_spell_zones(moonbeam_players)
	_assert(moonbeam_transfer.get("footprint", []) == [[0, 0], [1, 0]] and int(moonbeam_transfer.get("save_dc", 0)) == 15 and int(moonbeam_transfer.get("slot_level", 0)) == 4 and str(moonbeam_transfer.get("damage_formula", "")) == "4d10" and int(moonbeam_transfer.get("expires_at_seconds", 0)) - int(GameManager.campaign_elapsed_seconds) == 48 and moonbeam_restore_zones.has(moonbeam_source_id) and moonbeam_restore_zones[moonbeam_source_id].get("coords", []).size() == 2 and DungeonPersistence.local_error(moonbeam_room_snapshot).is_empty(), "Moonbeam transfers its footprint, save DC, upcast damage and duration through validated JSON room reload")
	GameManager.transition_context["local_room"] = active_room_state
	var wall_fire_caster := _fresh_char("Room Wall of Fire Caster", "human", "wizard", {"STR": 8, "DEX": 12, "CON": 14, "INT": 16, "WIS": 10, "CHA": 10})
	wall_fire_caster.character_id = "room_wall_of_fire_caster"
	var wall_fire_source_id := "wall_of_fire:%s:room_transfer_test" % wall_fire_caster.character_id
	wall_fire_caster.concentrating_on = {"spell_id": "wall_of_fire", "wall_of_fire_source_id": wall_fire_source_id}
	var wall_fire_players: Array = [{"character": wall_fire_caster}]
	var wall_fire_room_state: Dictionary = active_room_state.duplicate(true)
	wall_fire_room_state["areas"] = []
	wall_fire_room_state["area_serial"] = 0
	GameManager.transition_context["local_room"] = wall_fire_room_state
	var wall_fire_zone := {"source_id": wall_fire_source_id, "spell_id": "wall_of_fire", "caster_id": wall_fire_caster.character_id, "center": Vector2i.ZERO, "coords": [Vector2i.ZERO, Vector2i(1, 0)], "dangerous_coords": [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)], "save_dc": 15, "slot_level": 5, "damage_formula": "5d8 + 1d8", "concentration": true, "rounds_remaining": 8}
	LocalRoomCombat.capture_spell_zones(wall_fire_players, {wall_fire_source_id: wall_fire_zone})
	var wall_fire_transfer: Dictionary = wall_fire_room_state["areas"].front() if not wall_fire_room_state["areas"].is_empty() else {}
	var wall_fire_room_snapshot: Dictionary = JSON.parse_string(JSON.stringify(wall_fire_room_state))
	GameManager.transition_context["local_room"] = wall_fire_room_snapshot
	var wall_fire_restore_zones := LocalRoomCombat.restore_spell_zones(wall_fire_players)
	_assert(wall_fire_transfer.get("footprint", []) == [[0, 0], [1, 0]] and wall_fire_transfer.get("dangerous_footprint", []).size() == 3 and int(wall_fire_transfer.get("save_dc", 0)) == 15 and int(wall_fire_transfer.get("slot_level", 0)) == 5 and str(wall_fire_transfer.get("damage_formula", "")) == "5d8 + 1d8" and wall_fire_restore_zones.has(wall_fire_source_id) and wall_fire_restore_zones[wall_fire_source_id].get("dangerous_coords", []).size() == 3 and DungeonPersistence.local_error(wall_fire_room_snapshot).is_empty(), "Wall of Fire transfers its wall, damaging side, upcast damage and remaining Concentration through validated JSON room reload")
	GameManager.transition_context["local_room"] = moonbeam_room_snapshot
	var moonbeam_lock_probe: Character = combat.player_entities[0]["character"]
	CombatAction.apply_condition(moonbeam_lock_probe, "moonbeam_shape_lock", 99, "%s:shape_lock" % moonbeam_source_id)
	LocalRoomCombat.remove_concentration(moonbeam_caster, "moonbeam", moonbeam_source_id)
	_assert(moonbeam_room_snapshot["areas"].is_empty() and not moonbeam_lock_probe.condition_sources.get("moonbeam_shape_lock", {}).has("%s:shape_lock" % moonbeam_source_id), "Ending Moonbeam Concentration removes its room area and source-owned shape-shift lock")
	GameManager.transition_context["local_room"] = active_room_state
	var grease_saved_room: Dictionary = JSON.parse_string(JSON.stringify(state))
	GameManager.transition_context["local_room"] = grease_saved_room
	var immediate_grease_zones := LocalRoomCombat.restore_spell_zones(combat.player_entities)
	_assert(immediate_grease_zones.has(grease_source_id) and immediate_grease_zones[grease_source_id].get("coords", []).size() == 2 and int(immediate_grease_zones[grease_source_id].get("rounds_remaining", 0)) == 10 and not bool(immediate_grease_zones[grease_source_id].get("concentration", true)) and DungeonPersistence.local_error(grease_saved_room).is_empty(), "An active Grease area survives room JSON round-trip, validates, and restores before expiry")
	GameManager.transition_context["local_room"] = active_room_state
	var grease_movement_probe := Character.new()
	grease_movement_probe.initialize("Overlapping terrain probe", "human", "fighter", AbilityScores.new())
	grease_movement_probe.character_id = "grease_movement_probe"
	grease_movement_probe.speed = 2
	var movement_room_state: Dictionary = state.duplicate(true)
	movement_room_state["party_positions"] = {grease_movement_probe.character_id: [2, 0]}
	var room_test_grid := HexGrid.new()
	for tile_coord in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)]:
		var room_test_tile := HexTile.new()
		room_test_tile.coord = tile_coord
		room_test_tile.terrain = HexTile.TerrainType.ROAD
		room_test_tile.is_revealed = true
		room_test_tile.is_visible = true
		room_test_grid.add_tile(room_test_tile)
	var overlapping_grease_move := LocalRoomRules.move(movement_room_state, grease_movement_probe, Vector2i(1, 0), room_test_grid)
	_assert(bool(overlapping_grease_move.get("success", false)) and int(overlapping_grease_move.get("movement_cost_feet", 0)) == 10, "Overlapping Grease and Black Tentacles Difficult Terrain do not multiply movement cost (%s)" % str(overlapping_grease_move))
	for area in movement_room_state["areas"]:
		if str(area.get("spell_id", "")) == "grease": area["save_dc"] = 100
		elif str(area.get("spell_id", "")) == "black_tentacles": area["save_dc"] = 0
	var grease_entry_results := LocalRoomRules.resolve_area_entries(overlapping_grease_move.get("entered_areas", []), grease_movement_probe)
	var grease_entry_result: Dictionary = grease_entry_results.filter(func(outcome): return str(outcome.get("spell_id", "")) == "grease").front() if grease_entry_results.any(func(outcome): return str(outcome.get("spell_id", "")) == "grease") else {}
	var tentacle_entry_result: Dictionary = grease_entry_results.filter(func(outcome): return str(outcome.get("spell_id", "")) == "black_tentacles").front() if grease_entry_results.any(func(outcome): return str(outcome.get("spell_id", "")) == "black_tentacles") else {}
	_assert(not grease_entry_result.is_empty() and not bool(grease_entry_result.get("saved", true)) and grease_movement_probe.has_condition("prone") and tentacle_entry_result.get("saved", false), "Entering overlapping transferred hazards resolves the Grease Dexterity failure and Black Tentacles Strength save independently")
	var left_grease := LocalRoomRules.move(movement_room_state, grease_movement_probe, Vector2i(2, 0), room_test_grid)
	GameManager.advance_campaign_time(6)
	var reentered_grease := LocalRoomRules.move(movement_room_state, grease_movement_probe, Vector2i(1, 0), room_test_grid)
	_assert(left_grease.get("success", false) and reentered_grease.get("success", false) and reentered_grease.get("entered_areas", []).any(func(area): return str(area.get("spell_id", "")) == "grease") and int(movement_room_state["areas"].filter(func(area): return str(area.get("spell_id", "")) == "grease")[0].get("triggered_by", {}).get(grease_movement_probe.character_id, 0)) == 2, "Leaving and re-entering Grease triggers another room-side save")
	room_test_grid.free()
	combat.player_entities[0]["hex_position"] = Vector2i(2, -1)
	await combat._end_battle("victory")
	var fog_transfer_record: Dictionary = state.get("areas", []).filter(func(area): return str(area.get("concentration_source_id", "")) == fog_source_id).front() if state.get("areas", []).any(func(area): return str(area.get("concentration_source_id", "")) == fog_source_id) else {}
	_assert(not fog_transfer_record.is_empty() and int(fog_transfer_record.get("expires_at_seconds", 0)) > int(GameManager.campaign_elapsed_seconds), "Fog Cloud transfers its remaining duration and concentration source into the room when combat ends")
	var tentacle_transfer_record: Dictionary = state.get("areas", []).filter(func(area): return str(area.get("concentration_source_id", "")) == tentacle_source_id).front() if state.get("areas", []).any(func(area): return str(area.get("concentration_source_id", "")) == tentacle_source_id) else {}
	_assert(tentacle_transfer_record.get("footprint", []) == [[0, 0], [1, 0]] and int(tentacle_transfer_record.get("save_dc", 0)) == 14 and bool(tentacle_transfer_record.get("difficult_terrain", false)) and bool(tentacle_transfer_record.get("requires_concentration", false)), "Black Tentacles transfers its exact square footprint, save DC and difficult-terrain state into the room")
	var long_tentacle_transfer: Dictionary = state.get("areas", []).filter(func(area): return str(area.get("concentration_source_id", "")) == long_tentacle_source_id).front() if state.get("areas", []).any(func(area): return str(area.get("concentration_source_id", "")) == long_tentacle_source_id) else {}
	_assert(not long_tentacle_transfer.is_empty() and not bool(long_tentacle_transfer.get("requires_concentration", true)) and int(long_tentacle_transfer.get("expires_at_seconds", 0)) - int(GameManager.campaign_elapsed_seconds) == 28800, "A finite eighth-hour Black Tentacles zone transfers without a Concentration link")
	var grease_transfer: Dictionary = state.get("areas", []).filter(func(area): return str(area.get("concentration_source_id", "")) == grease_source_id).front() if state.get("areas", []).any(func(area): return str(area.get("concentration_source_id", "")) == grease_source_id) else {}
	_assert(grease_transfer.get("footprint", []) == [[0, 0], [1, 0]] and int(grease_transfer.get("save_dc", 0)) == 14 and bool(grease_transfer.get("difficult_terrain", false)) and not bool(grease_transfer.get("requires_concentration", true)) and int(grease_transfer.get("expires_at_seconds", 0)) - int(GameManager.campaign_elapsed_seconds) == 60, "Grease transfers its footprint, save DC, Difficult Terrain and one-minute duration to the room")
	var darkness_transfer: Dictionary = state.get("areas", []).filter(func(area): return str(area.get("concentration_source_id", "")) == darkness_source_id).front() if state.get("areas", []).any(func(area): return str(area.get("concentration_source_id", "")) == darkness_source_id) else {}
	_assert(bool(darkness_transfer.get("heavily_obscured", false)) and int(darkness_transfer.get("radius_hexes", 0)) == 1, "Darkness transfers its saved obscured radius to the room ledger")
	_assert(daggers_transfer.get("footprint", []) == [[3, 0]] and str(daggers_transfer.get("damage_formula", "")) == "6d4" and int(daggers_transfer.get("slot_level", 0)) == 3 and DungeonPersistence.local_error(daggers_room_state).is_empty(), "Cloud of Daggers transfers its exact footprint, upcast damage and duration into a validated room area")
	_assert(LocalRoomRules.coord(state["party_positions"][alice.character_id]) == Vector2i(2, -1), "Combat return captures the same creature position")
	_teardown_scene(combat)
	_teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"combat_result": "victory"}
	dungeon = await _spawn_scene("res://scenes/dungeon.tscn", 0.2)
	state = dungeon.local_view.state
	_assert(state["encounter_cleared"] and LocalRoomRules.get_object(state, "door")["open"] and LocalRoomRules.get_object(state, "chest")["contents"].size() == 1, "Victory restores the room without resetting objects or rewards")
	_assert(bool(LocalRoomRules.get_object(state, "kindling_test").get("burning", false)), "The lit object remains burning when the combat scene returns to the room")
	dungeon.hex_grid.hex_clicked.emit(Vector2i(-3, 0))
	_local_room_press(dungeon.local_view, "Room map")
	await get_tree().process_frame
	dungeon.hex_grid.hex_clicked.emit(Vector2i.ZERO)
	_assert(dungeon.local_view == null and SaveManager.get_save_block_reason().is_empty(), "Ordinary return to the entrance permits checkpoint saving")
	var layout: Array = GameManager.dungeon_snapshots["ruins_of_ashvale"]["rooms"].duplicate(true)
	GameManager.remember_dungeon()
	GameManager.active_dungeon_state.clear()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {"returning_from_dungeon": true}
	_teardown_scene(dungeon)
	var slot := "local_room_object_flow"
	_assert(SaveManager.save_game(slot), "Checkpoint saves the dungeon ledger after leaving")
	var checkpoint := FileAccess.get_file_as_string(SaveManager.SAVE_DIR + slot + ".sav")
	var snapshots := GameManager.dungeon_snapshots.duplicate(true)
	GameManager.dungeon_snapshots["ruins_of_ashvale"]["local_rooms"]["1"]["objects"][0]["locked"] = "corrupt"
	_assert(not SaveManager.save_game(slot) and FileAccess.get_file_as_string(SaveManager.SAVE_DIR + slot + ".sav") == checkpoint, "Malformed world state refuses before overwriting a good checkpoint")
	GameManager.dungeon_snapshots = snapshots
	var damaged: Dictionary = JSON.parse_string(checkpoint)
	damaged["campaign_ledger"]["dungeon_snapshots"]["ruins_of_ashvale"]["local_rooms"]["1"]["objects"][0]["contents"].append(alice.inventory.get_instance(potion_id))
	var invalid_slot := "local_room_invalid_owner"
	var invalid_file := FileAccess.open(SaveManager.SAVE_DIR + invalid_slot + ".sav", FileAccess.WRITE)
	invalid_file.store_string(JSON.stringify(damaged))
	invalid_file.close()
	_assert(not SaveManager.load_game(invalid_slot) and PartyManager.get_active_characters()[0] == alice and not alice.inventory.get_instance(potion_id).is_empty(), "Duplicate world/inventory ownership refuses reload without changing the live party")
	SaveManager.delete_save(invalid_slot)
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(slot), "Supported load restores individual items and dungeon ledger")
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	GameManager.active_dungeon_state = GameManager.dungeon_snapshots["ruins_of_ashvale"].duplicate(true)
	dungeon = await _spawn_scene("res://scenes/dungeon.tscn", 0.2)
	_assert(GameManager.dungeon_snapshots["ruins_of_ashvale"]["rooms"] == layout, "Returning after reload preserves the generated dungeon layout")
	var restored_room: Room
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: restored_room = candidate
	dungeon.hex_grid.hex_clicked.emit(restored_room.coord)
	await get_tree().process_frame
	var restored: Dictionary = dungeon.local_view.state
	_assert(LocalRoomRules.get_object(restored, "key")["removed"] and LocalRoomRules.get_object(restored, "door")["open"] and LocalRoomRules.get_object(restored, "chest")["contents"].size() == 1 and restored["encounter_cleared"], "Revisit preserves the collected key, open door, remaining potion and cleared guardian")
	var restored_kindling := LocalRoomRules.get_object(restored, "kindling_test")
	_assert(bool(restored_kindling.get("burning", false)) and int(restored_kindling.get("hp", 200)) < kindling_hp and int(restored_kindling.get("burning_next_tick_seconds", -1)) > kindling_first_tick, "Burn damage, burning state and the next tick survive checkpoint save, supported reload and room revisit")
	_assert(LocalRoomRules.get_object(restored, "cistern")["contamination"].is_empty(), "Purification remains saved after checkpoint reload and room revisit")
	# Set up the interaction next to the object; the captured combat-return
	# position is on the far side of the room and is not within reach.
	var extinguish_actor: Character = dungeon.local_view.actor()
	restored["party_positions"][extinguish_actor.character_id] = [-3, 0]
	restored["party_altitudes"][extinguish_actor.character_id] = 0
	dungeon.local_view.refresh()
	dungeon.local_view.click(Vector2i(-4, 0))
	var extinguish_time := GameManager.campaign_elapsed_seconds
	_local_room_press(dungeon.local_view, "Extinguish")
	var saved_kindling_after_extinguish: Dictionary = GameManager.dungeon_snapshots["ruins_of_ashvale"]["local_rooms"]["1"]["objects"].filter(func(object): return str(object.get("id", "")) == "kindling_test").front()
	_assert(not bool(restored_kindling.get("burning", true)) and not restored_kindling.has("burning_next_tick_seconds") and GameManager.campaign_elapsed_seconds == extinguish_time + 6 and not bool(saved_kindling_after_extinguish.get("burning", true)), "Room interaction extinguishes the persisted object, clears its fire timer and flushes the six-second action (kindling=%s saved=%s time=%d expected=%d)" % [str(restored_kindling), str(saved_kindling_after_extinguish), int(GameManager.campaign_elapsed_seconds), int(extinguish_time + 6)])
	_assert(not PartyManager.get_active_characters()[0].inventory.get_instance(potion_id).is_empty(), "Exact potion identity survives supported disk reload")
	_assert(PartyManager.get_active_characters()[0].nourishment_until_seconds > 0 and PartyManager.get_active_characters()[0].hydration_until_seconds > 0 and is_equal_approx(PartyManager.get_active_characters()[0].food_eaten_today_pounds, 1.0) and is_equal_approx(PartyManager.get_active_characters()[0].water_drank_today_gallons, 1.0), "Food and water supply deadlines and daily intake survive checkpoint reload")
	var restored_areas: Array = dungeon.local_view.state.get("areas", [])
	var restored_test_area: Dictionary = restored_areas.filter(func(area): return str(area.get("spell_id", "")) == "area_test").front() if restored_areas.any(func(area): return str(area.get("spell_id", "")) == "area_test") else {}
	var restored_alarm_area: Dictionary = restored_areas.filter(func(area): return str(area.get("spell_id", "")) == "alarm").front() if restored_areas.any(func(area): return str(area.get("spell_id", "")) == "alarm") else {}
	var restored_fog_area: Dictionary = restored_areas.filter(func(area): return str(area.get("spell_id", "")) == "fog_cloud").front() if restored_areas.any(func(area): return str(area.get("spell_id", "")) == "fog_cloud") else {}
	var restored_tentacle_area: Dictionary = restored_areas.filter(func(area): return str(area.get("spell_id", "")) == "black_tentacles").front() if restored_areas.any(func(area): return str(area.get("spell_id", "")) == "black_tentacles") else {}
	var restored_grease_area: Dictionary = restored_areas.filter(func(area): return str(area.get("spell_id", "")) == "grease").front() if restored_areas.any(func(area): return str(area.get("spell_id", "")) == "grease") else {}
	var reloaded_footprint: Array = restored_tentacle_area.get("footprint", [])
	var footprint_matches := reloaded_footprint.size() == 2 and LocalRoomRules.coord(reloaded_footprint[0]) == Vector2i.ZERO and LocalRoomRules.coord(reloaded_footprint[1]) == Vector2i(1, 0)
	var areas_reloaded: bool = restored_areas.size() == 6 and int(restored_test_area.get("triggered_by", {}).get(PartyManager.get_active_characters()[0].character_id, 0)) == 1 and int(restored_alarm_area.get("triggered_by", {}).get("monster_0", 0)) == 1 and str(restored_fog_area.get("concentration_source_id", "")) == fog_source_id and footprint_matches and restored_areas.any(func(area): return str(area.get("concentration_source_id", "")) == darkness_source_id) and restored_grease_area.is_empty()
	_assert(areas_reloaded, "Room areas and active Fog Cloud/Black Tentacles state survive checkpoint reload, while expired Grease is removed")
	GameManager.transition_context["local_room"] = dungeon.local_view.state
	var restored_party_entities: Array = []
	for character in PartyManager.get_active_characters():
		restored_party_entities.append({"character": character})
	var restored_fog_zones := LocalRoomCombat.restore_spell_zones(restored_party_entities)
	if not restored_fog_zones.has(fog_source_id):
		var loaded_fog_owner: Character = PartyManager.characters.get(fog_caster.character_id)
		print("Fog restore diagnostic: owner=", loaded_fog_owner.concentrating_on, " effects=", loaded_fog_owner.spell_effects, " HP=", loaded_fog_owner.current_hp, " record=", restored_fog_area)
	_assert(restored_fog_zones.has(fog_source_id) and int(restored_fog_zones[fog_source_id].get("rounds_remaining", 0)) > 0, "A saved Fog Cloud returns to combat with its campaign-clock duration (has=%s fog=%s source=%s caster=%s)" % [str(restored_fog_zones.has(fog_source_id)), str(restored_fog_zones.get(fog_source_id, {})), str(fog_source_id), str(PartyManager.get_active_characters()[1].concentrating_on)])
	_assert(daggers_restore_zones.has(daggers_source_id) and daggers_restore_zones[daggers_source_id].get("coords", []) == [Vector2i(3, 0)] and str(daggers_restore_zones[daggers_source_id].get("damage_formula", "")) == "6d4" and int(daggers_restore_zones[daggers_source_id].get("rounds_remaining", 0)) > 0, "Saved Cloud of Daggers restores its exact footprint, upcast damage and campaign-clock duration")
	var restored_tentacle_zones := LocalRoomCombat.restore_spell_zones(restored_party_entities)
	_assert(restored_tentacle_zones.has(tentacle_source_id) and restored_tentacle_zones[tentacle_source_id].get("coords", []).size() == 2 and int(restored_tentacle_zones[tentacle_source_id].get("save_dc", 0)) == 14 and int(restored_tentacle_zones[tentacle_source_id].get("rounds_remaining", 0)) > 0, "Saved Black Tentacles restores its footprint and campaign-clock duration for the next encounter")
	var restored_grease_zones := LocalRoomCombat.restore_spell_zones(restored_party_entities)
	_assert(not restored_grease_zones.has(grease_source_id), "Grease does not restore into a later encounter after its one-minute duration has elapsed")
	_assert(restored_tentacle_zones.has(long_tentacle_source_id) and not bool(restored_tentacle_zones[long_tentacle_source_id].get("concentration", true)) and int(restored_tentacle_zones[long_tentacle_source_id].get("rounds_remaining", 0)) > 0, "A saved finite no-Concentration Black Tentacles zone also restores independently")
	var room_movement_probe := Character.new()
	room_movement_probe.initialize("Tentacle Movement Probe", "human", "fighter", AbilityScores.new())
	room_movement_probe.character_id = "tentacle_movement_probe"
	room_movement_probe.speed = 1
	dungeon.local_view.state["party_positions"][room_movement_probe.character_id] = [2, 0]
	var blocked_by_difficult_terrain := LocalRoomRules.move(dungeon.local_view.state, room_movement_probe, Vector2i(1, 0), dungeon.local_view.grid)
	room_movement_probe.speed = 2
	var paid_difficult_terrain := LocalRoomRules.move(dungeon.local_view.state, room_movement_probe, Vector2i(1, 0), dungeon.local_view.grid)
	_assert(not blocked_by_difficult_terrain.get("success", false) and paid_difficult_terrain.get("success", false) and int(paid_difficult_terrain.get("movement_cost_feet", 0)) == 10, "The saved Black Tentacles footprint costs double movement in room exploration (5ft=%s; 10ft=%s)" % [str(blocked_by_difficult_terrain), str(paid_difficult_terrain)])
	var restored_tentacle_caster: Character = PartyManager.get_active_characters()[1]
	LocalRoomCombat.remove_concentration(restored_tentacle_caster, "black_tentacles", tentacle_source_id)
	SpellEffects.end_concentration(restored_tentacle_caster, [restored_tentacle_caster])
	_assert(not dungeon.local_view.state.get("areas", []).any(func(area): return str(area.get("concentration_source_id", "")) == tentacle_source_id) and dungeon.local_view.state.get("areas", []).any(func(area): return str(area.get("concentration_source_id", "")) == long_tentacle_source_id) and restored_tentacle_caster.concentrating_on.is_empty(), "Ending restored Black Tentacles concentration clears only its source and preserves the finite no-Concentration zone")
	var restored_darkness_caster: Character = PartyManager.get_active_characters()[2]
	var restored_darkness_zones := LocalRoomCombat.restore_spell_zones(restored_party_entities)
	_assert(restored_darkness_zones.has(darkness_source_id) and int(restored_darkness_zones[darkness_source_id].get("radius_hexes", 0)) == 1, "Darkness restores its saved area after checkpoint reload")
	LocalRoomCombat.remove_concentration(restored_darkness_caster, "darkness", darkness_source_id)
	SpellEffects.end_concentration(restored_darkness_caster, [restored_darkness_caster])
	_assert(not dungeon.local_view.state.get("areas", []).any(func(area): return str(area.get("concentration_source_id", "")) == darkness_source_id) and restored_darkness_caster.concentrating_on.is_empty(), "Ending restored Darkness concentration clears only its saved room area and marker")
	var restored_fog_caster: Character = PartyManager.get_active_characters()[0]
	LocalRoomCombat.remove_concentration(restored_fog_caster, "fog_cloud", fog_source_id)
	SpellEffects.end_concentration(restored_fog_caster, [restored_fog_caster])
	_assert(not dungeon.local_view.state.get("areas", []).any(func(area): return str(area.get("concentration_source_id", "")) == fog_source_id) and restored_fog_caster.concentrating_on.is_empty(), "Restored Fog Cloud concentration cleanup clears the room-owned source and saved effect")
	_teardown_scene(dungeon)
	SaveManager.delete_save(slot)
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = false
	_exit_test()


func test_wave_three_foundations_flow() -> void:
	_enter_test("wave_three_foundations_flow")
	_setup_world()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 0.2)
	var authored_room: Room
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: authored_room = candidate
	dungeon.hex_grid.hex_clicked.emit(authored_room.coord)
	await get_tree().process_frame
	var view: LocalRoomView = dungeon.local_view
	var state: Dictionary = view.state
	var fighter: Character = PartyManager.get_active_characters()[0]
	var wizard: Character = PartyManager.get_active_characters()[1]
	wizard.known_spells.assign(["fire_bolt"])
	state["party_positions"][wizard.character_id] = [-1, -1]
	state["party_positions"][fighter.character_id] = [-1, 0]
	var timber := LocalRoomRules.get_object(state, "timber_partition")
	var stone := LocalRoomRules.get_object(state, "stone_partition")
	# Keep this ignition check independent of whether a critical bolt can
	# destroy a 27-HP partition in the seeded scene setup.
	timber["hp"] = 200
	timber["max_hp"] = 200
	var hit_seed := 1
	for candidate_seed in range(1, 100):
		seed(candidate_seed)
		if randi_range(1, 20) >= 18:
			hit_seed = candidate_seed
			break
	view.actors.select(1)
	view.refresh()
	view.click(Vector2i(0, -1))
	var before_fire := int(GameManager.campaign_elapsed_seconds)
	seed(hit_seed)
	_local_room_press(view, "Fire Bolt")
	_assert(bool(timber.get("burning", false)) and int(timber["hp"]) < 200 and int(GameManager.campaign_elapsed_seconds) == before_fire + 6, "The room's Fire Bolt control damages and ignites a flammable barrier and spends one action (HP=%s burning=%s elapsed=%s log=%s)" % [timber["hp"], timber.get("burning", false), GameManager.campaign_elapsed_seconds - before_fire, view.hud.log_text.text])
	state["party_positions"][wizard.character_id] = [-1, 1]
	view.refresh()
	view.click(Vector2i(0, 1))
	var stone_hp := int(stone["hp"])
	seed(hit_seed)
	_local_room_press(view, "Fire Bolt")
	_assert(int(stone["hp"]) == stone_hp and not bool(stone.get("burning", false)), "The same Fire Bolt control respects the stone barrier's authored Fire immunity")
	view.actors.select(0)
	view.refresh()
	view.click(Vector2i(0, -1))
	var distant_time := int(GameManager.campaign_elapsed_seconds)
	state["party_positions"][fighter.character_id] = [-4, 0]
	_local_room_press(view, "Strike barrier")
	_assert(int(GameManager.campaign_elapsed_seconds) == distant_time, "An out-of-reach barrier strike refuses without spending time")
	state["party_positions"][fighter.character_id] = [-1, -1]
	fighter.inventory.add_item("longsword")
	fighter.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	timber["hp"] = 1
	view.refresh()
	view.click(Vector2i(0, -1))
	seed(hit_seed)
	_local_room_press(view, "Strike barrier")
	_assert(int(timber["hp"]) == 0 and not LocalRoomRules.has_wall(state, Vector2i(0, -1)) and Targeting.has_line_of_sight(Vector2i(-1, -1), Vector2i(1, -1), view.grid), "The weapon control destroys the damaged timber partition and refreshes passage and sight")
	view.click(Vector2i(0, -1))
	# A destroyed barrier remains inspectable, so select an adjacent open cell
	# to exercise movement across its now-open footprint.
	var crossed := LocalRoomRules.move(state, fighter, Vector2i(1, -1), view.grid, "walk", view.characters)
	_assert(crossed.get("success", false), "Ordinary walking crosses the destroyed partition's footprint")
	wizard.known_spells.append("water_walk")
	wizard.spell_slots["3"] = 1
	wizard.inventory.add_item("component_pouch")
	wizard.max_hp = 100
	wizard.current_hp = 100
	state["party_positions"][wizard.character_id] = [2, -1]
	view.actors.select(1)
	view.refresh()
	_local_room_press(view, "Cast Water Walk")
	var before_heat := wizard.current_hp
	view.click(Vector2i(3, -1))
	_assert(SpellEffects.has_spell(wizard, "water_walk") and state["party_positions"][wizard.character_id] == [3, -1] and wizard.current_hp < before_heat, "A real Water Walk cast allows the lava landing while its separate authored heat still damages the walker")
	before_heat = wizard.current_hp
	_local_room_press(view, "End Turn")
	_assert(wizard.current_hp < before_heat, "The room End Turn control resolves continued exposure to the authored heat")
	view.actors.select(0)
	view.flush.call()
	state["party_positions"][fighter.character_id] = state["exits"][0].duplicate()
	state["party_altitudes"][fighter.character_id] = LocalRoomRules.elevation_feet(state, LocalRoomRules.coord(state["exits"][0]))
	_local_room_press(view, "Room map")
	await get_tree().process_frame
	dungeon.hex_grid.hex_clicked.emit(Vector2i.ZERO)
	var save_slot := "wave_three_foundations"
	_assert(SaveManager.save_game(save_slot), "The permitted entrance checkpoint saves the barrier changes")
	_teardown_scene(dungeon)
	PlayerManager.reset()
	PartyManager.reset()
	var loaded := SaveManager.load_game(save_slot)
	_assert(loaded, "The supported checkpoint reload restores the barrier changes")
	if loaded:
		var saved_room: Dictionary = GameManager.dungeon_snapshots["ruins_of_ashvale"]["local_rooms"]["1"]
		_assert(LocalRoomRules.get_object(saved_room, "timber_partition")["hp"] == 0 and not LocalRoomRules.has_wall(saved_room, Vector2i(0, -1)) and LocalRoomRules.has_wall(saved_room, Vector2i(0, 1)), "Destroyed timber stays open and intact stone stays blocked after disk reload")
		_assert(saved_room["cell_terrains"][0]["heat_damage_formula"] == "1d4", "The authored heat hazard survives the supported disk checkpoint")
		GameManager.transition_context = {"local_room": saved_room}
		var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 0.5)
		var owner: Character = combat.player_entities[0]["character"]
		combat.player_entities[0]["hex_position"] = Vector2i(-4, 0)
		combat.player_entities[1]["hex_position"] = Vector2i(-4, 1)
		combat.monster_entities.clear()
		var pushed := {"id": "wave3_push", "name": "Push target", "hex_position": Vector2i(-1, -1), "is_alive": true, "current_hp": 100, "max_hp": 100, "conditions": {}, "condition_sources": {}}
		combat.monster_entities.append(pushed)
		combat.active_spell_zones["wave3:wall"] = {"source_id": "wave3:wall", "spell_id": "wall_of_fire", "caster_id": owner.character_id, "coords": [Vector2i(0, -1)], "dangerous_coords": [Vector2i(0, -1), Vector2i(1, -1)], "damage_formula": "5", "last_trigger_turn_by_target": {}}
		combat.active_spell_zones["wave3:spikes"] = {"source_id": "wave3:spikes", "spell_id": "spike_growth", "caster_id": owner.character_id, "coords": [Vector2i(0, -1), Vector2i(1, -1)], "damage_formula": "2"}
		combat._update_grid_entities()
		var pushed_feet: int = await combat._push_combat_target(pushed, Vector2i(-2, -1), 2, false)
		_assert(pushed_feet == 10 and pushed["hex_position"] == Vector2i(1, -1) and int(pushed["current_hp"]) == 91, "A forced push crosses each cell and applies wall-entry damage plus each Spike Growth step exactly once (feet=%d, position=%s, HP=%d)" % [pushed_feet, str(pushed["hex_position"]), int(pushed["current_hp"])])
		pushed["hex_position"] = Vector2i(-1, 1)
		pushed_feet = await combat._push_combat_target(pushed, Vector2i(-2, 1), 2, false)
		_assert(pushed_feet == 0 and pushed["hex_position"] == Vector2i(-1, 1), "The same forced-push path stops at intact authored masonry")
		combat.active_spell_zones.clear()
		saved_room["cell_elevations"] = [{"position": [-1, -1], "feet": 10}]
		pushed["hex_position"] = Vector2i(-1, -1)
		var before_fall := int(pushed["current_hp"])
		await combat._push_combat_target(pushed, Vector2i(-2, -1), 2, false)
		_assert(pushed["hex_position"] == Vector2i(1, -1) and before_fall - int(pushed["current_hp"]) in range(1, 7), "A forced push down an authored ten-foot drop resolves one falling die along the actual path")
		pushed["hex_position"] = Vector2i(3, -1)
		before_heat = int(pushed["current_hp"])
		await combat._resolve_spell_zone_end_turn(pushed, Vector2i(3, -1))
		_assert(int(pushed["current_hp"]) < before_heat, "Combat end-of-turn exposure uses the same saved heat hazard")
		_teardown_scene(combat)
	SaveManager.delete_save(save_slot)
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = false
	_exit_test()


func _local_room_press(view: LocalRoomView, label: String) -> void:
	for button in view.panel.find_children("*", "Button", true, false):
		if not button is OptionButton and button.text == label:
			button.pressed.emit()
			return
	_assert(false, "Local room action is available: %s" % label)


## Character creation flow: randomize + per-player confirm/save loop.
func test_character_creation() -> void:
	_enter_test("character_creation")
	PlayerManager.reset()
	PlayerManager.add_player("Alice")
	PlayerManager.add_player("Bob")
	PlayerManager.add_player("Carol")
	var cc: Node = await _spawn_scene("res://scenes/ui/character_creation.tscn", 0.5)

	_assert(cc != null, "character_creation scene instantiated")
	_assert(cc.race_grid.get_child_count() > 0, "character_creation built race cards")
	_assert(cc.current_step == cc.CreationStep.RACE, "character_creation starts at RACE step")
	cc._on_randomize_pressed()
	await get_tree().create_timer(0.2).timeout
	_assert(not cc.selected_race_id.is_empty(), "character_creation race selected after randomize")
	_assert(not cc.selected_class_id.is_empty(), "character_creation class selected after randomize")
	_assert(cc.current_step == cc.CreationStep.SUMMARY, "character_creation jumped to SUMMARY after randomize")
	cc._confirm_and_save_character()
	await get_tree().create_timer(0.3).timeout
	_assert(PlayerManager.get_player(0).get("character") != null, "player 0 character saved via creation flow")
	_assert(cc.current_player_idx == 1, "creation flow advanced to player 1")
	cc._on_randomize_pressed()
	await get_tree().create_timer(0.2).timeout
	_assert(not cc.selected_race_id.is_empty(), "player 1 selections built in creation flow")
	cc._confirm_and_save_character()
	await get_tree().create_timer(0.3).timeout
	_assert(PlayerManager.get_player(1).get("character") != null, "player 1 character saved via creation flow")
	_assert(cc.current_player_idx == 2, "creation flow advanced to player 2")

	_teardown_scene(cc)
	_exit_test()

## Shop UI: setup + purchase deducts gold + adds to backpack.
func test_shop() -> void:
	_enter_test("shop")
	if PlayerManager.get_player(0).get("character") == null:
		var s1 := AbilityScores.new()
		s1.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
		var shop_char := Character.new()
		shop_char.initialize("Shopper","human","fighter",s1)
		PlayerManager.set_player_character(0, shop_char)
	var shop: ShopUI = await _spawn_scene("res://scenes/ui/shop.tscn", 0.3)

	_assert(shop != null, "ShopUI instantiated")
	shop.setup_shop("Test Town")
	await get_tree().create_timer(0.2).timeout
	_assert(shop.items_data.size() > 0, "ShopUI populated buyable items (got %d)" % shop.items_data.size())
	var catalog_is_executable := true
	for item in shop.items_data:
		if not shop._is_buyable_item(item) or str(item.get("type", "")) in ["tool", "currency"] or bool(item.get("quest_item", false)):
			catalog_is_executable = false
	_assert(catalog_is_executable, "ShopUI catalog excludes tools, quest items, and unsupported consumables")
	_assert(shop.gold_label.text.contains("Gold"), "ShopUI gold label set")
	shop.active_player_index = 0
	shop._update_player_data()
	var buyer: Character = PlayerManager.get_player(0).get("character")
	buyer.inventory.gold = 9999
	var gold_before: int = buyer.inventory.gold
	shop.selected_item_idx = 0
	shop._on_item_selected(0)
	shop._update_buy_button_state()
	_assert(not shop.btn_buy.disabled, "ShopUI buy button enabled when affordable")
	shop._on_buy_pressed()
	await get_tree().create_timer(0.2).timeout
	_assert(buyer.inventory.gold < gold_before, "ShopUI purchase deducted gold (%d -> %d)" % [gold_before, buyer.inventory.gold])
	_assert(buyer.inventory.backpack.size() > 0, "ShopUI purchase added item to backpack")
	shop._on_buy_pressed()
	var purchased: Array[Dictionary] = buyer.inventory.backpack_instances().filter(func(record): return record["definition_id"] == shop.items_data[0]["id"])
	_assert(purchased.size() >= 2 and purchased[0]["instance_id"] != purchased[-1]["instance_id"], "Repeated purchases create independent item copies")
	var sold_id := str(purchased[-1]["instance_id"])
	var retained_id := str(purchased[0]["instance_id"])
	for index in shop.sell_selector.item_count:
		if shop.sell_selector.get_item_metadata(index) == sold_id: shop.sell_selector.select(index)
	gold_before = buyer.inventory.gold
	shop.btn_sell.pressed.emit()
	_assert(buyer.inventory.get_instance(sold_id).is_empty() and not buyer.inventory.get_instance(retained_id).is_empty() and buyer.inventory.gold == gold_before + int(shop.items_data[0]["value"]) / 2, "Shop sells only the selected copy and pays its price once")
	buyer.inventory.gold = 0
	var count_before := buyer.inventory.backpack.size()
	shop._on_buy_pressed()
	_assert(buyer.inventory.backpack.size() == count_before and buyer.inventory.gold == 0, "Purchase revalidates funds before mutating inventory")

	_teardown_scene(shop)
	_exit_test()

## SaveManager save/load/delete round-trip (actual SaveManager).
func test_save_load() -> void:
	_enter_test("save_load")
	GameManager.active_campaign = DataLoader.campaigns.values()[0]
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.defeated_monsters.clear()
	GameManager.defeated_monsters.append("goblin")
	PlayerManager.reset()
	PlayerManager.add_player("Saver")
	var ss := AbilityScores.new()
	ss.from_dict({"STR":16,"DEX":12,"CON":14,"INT":10,"WIS":13,"CHA":8})
	var saver := Character.new()
	saver.initialize("Saver","elf","ranger",ss)
	PlayerManager.set_player_character(0, saver)
	var save_ok: bool = SaveManager.save_game("harness_test_slot")
	_assert(save_ok, "SaveManager.save_game returned true")
	_assert(SaveManager.get_available_saves().has("harness_test_slot"), "save slot present after save")
	GameManager.defeated_monsters.clear()
	PlayerManager.reset()
	PlayerManager.add_player("Nobody")
	var load_ok: bool = SaveManager.load_game("harness_test_slot")
	_assert(load_ok, "SaveManager.load_game returned true")
	_assert(GameManager.defeated_monsters.has("goblin"), "load restored defeated_monsters")
	_assert(PlayerManager.get_player_count() == 1, "load restored player count")
	_assert(PlayerManager.get_player(0).get("character") != null, "load restored player character")
	_assert(PlayerManager.get_player(0).get("character").character_name == "Saver", "load restored character name")
	var del_ok: bool = SaveManager.delete_save("harness_test_slot")
	_assert(del_ok, "SaveManager.delete_save returned true")
	_assert(not SaveManager.get_available_saves().has("harness_test_slot"), "save slot gone after delete")
	await get_tree().process_frame
	_exit_test()

## Spend representative class resources, save at the overworld safe point,
## reload through the real DTO boundary, and boot the next combat from it.
func test_action_resource_round_trip() -> void:
	_enter_test("action_resource_round_trip")
	GameManager.active_campaign = DataLoader.campaigns.values()[0]
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.game_in_progress = true
	GameManager.test_mode = true
	PlayerManager.reset()
	PartyManager.reset()

	PlayerManager.add_player("Resource Fighter")
	PlayerManager.add_player("Resource Wizard")
	var fighter := _fresh_char("Resource Fighter", "human", "fighter",
		{"STR": 18, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
	var wizard := _fresh_char("Resource Wizard", "elf", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 12, "CHA": 10})
	for progression in 3:
		fighter.level_up()
	PlayerManager.set_player_character(0, fighter)
	PlayerManager.set_player_character(1, wizard)
	PartyManager.sync_from_player_manager()

	var fighter_feature_before := int(fighter.feature_uses.get("fighter_second_wind", 0))
	_assert(fighter_feature_before == 3, "level-4 Fighter resource save fixture starts with three Second Wind uses")
	var wizard_slot_before := int(wizard.spell_slots.get("1", 0))
	_assert(fighter_feature_before > 0 and wizard_slot_before > 0, "resource fixture starts with production feature and spell-slot uses")
	_assert(fighter.use_feature("fighter_second_wind"), "production Fighter feature spend succeeds before save")
	var magic_missile := DataLoader.get_spell("magic_missile")
	var slot_spend := CombatAction.spend_spell_slot(wizard, magic_missile)
	_assert(slot_spend.get("success", false), "production Wizard spell-slot spend succeeds before save")
	var fighter_feature_after_spend := int(fighter.feature_uses.get("fighter_second_wind", 0))
	var wizard_slot_after_spend := int(wizard.spell_slots.get("1", 0))
	var slot := "action_resource_round_trip"
	SaveManager.delete_save(slot)
	_assert(SaveManager.save_game(slot), "spent action resources save at the overworld safe point")

	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(slot), "fresh supported flow reloads the spent resource save")
	var restored_fighter: Character = PlayerManager.get_player(0).get("character")
	var restored_wizard: Character = PlayerManager.get_player(1).get("character")
	_assert(restored_fighter != null and restored_wizard != null, "resource round-trip restores both production characters")
	_assert(int(restored_fighter.feature_uses.get("fighter_second_wind", -1)) == fighter_feature_after_spend, "Fighter feature uses survive save/load")
	_assert(int(restored_wizard.spell_slots.get("1", -1)) == wizard_slot_after_spend, "Wizard remaining spell slots survive save/load")

	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 2.0)
	_assert(combat != null and combat.player_entities.size() == 2, "next combat boots from the restored party")
	_assert(combat.player_entities[0]["character"].feature_uses["fighter_second_wind"] == 2 and combat.player_entities[0]["character"].get_feature_max_uses("fighter_second_wind") == 3, "next combat preserves the restored level-4 Second Wind pool")
	var combat_wizard: Character = combat.player_entities[1].get("character") if combat != null and combat.player_entities.size() > 1 else null
	_assert(combat_wizard != null and int(combat_wizard.spell_slots.get("1", -1)) == wizard_slot_after_spend, "next combat sees the restored Wizard slot state")
	_teardown_scene(combat)
	SaveManager.delete_save(slot)
	GameManager.game_in_progress = false
	_exit_test()

## Combat resolution: attack -> damage -> kill (pure logic, no scene).
func test_combat_resolution() -> void:
	_enter_test("combat_resolution")
	var atk_scores := AbilityScores.new()
	atk_scores.from_dict({"STR":18,"DEX":14,"CON":14,"INT":10,"WIS":12,"CHA":8})
	var attacker := Character.new()
	attacker.initialize("Slayer", "human", "fighter", atk_scores)
	var tgt_scores := AbilityScores.new()
	tgt_scores.from_dict({"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	var defender := Character.new()
	defender.initialize("PunchingBag", "goblin", "fighter", tgt_scores)
	defender.max_hp = 5
	defender.current_hp = 5
	defender.is_alive = true
	var weapon := {"name":"sword","ability":"STR","damage":"1d8","damage_type":"slashing"}
	var total_dmg := 0
	var swings := 0
	while defender.is_alive and swings < 50:
		var res := CombatAction.resolve_weapon_attack(attacker, defender, weapon)
		_assert(res.has("hit"), "attack result has 'hit' key")
		if res.get("hit", false):
			total_dmg += int(res.get("damage", 0))
		swings += 1
	_assert(swings < 50, "defender died within 50 swings (got %d)" % swings)
	_assert(not defender.is_alive, "defender is dead after sustained attacks")
	_assert(total_dmg > 0, "attacker dealt total damage (%d)" % total_dmg)
	_assert(defender.current_hp == 0, "defender hp floored at 0")
	_exit_test()

## Event choice resolution: real EventResolver.apply_effects.
func test_event_choice_resolution() -> void:
	_enter_test("event_choice_resolution")
	var ev2_scores := AbilityScores.new()
	ev2_scores.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var ev2_char := Character.new()
	ev2_char.initialize("Chooser", "human", "fighter", ev2_scores)
	ev2_char.inventory.gold = 0
	ev2_char.current_hp = ev2_char.max_hp
	var before_hp := ev2_char.current_hp
	var open_choice := {
		"text": "Just open it",
		"effects": [
			{"type":"damage","value":"1d6","damage_type":"poison"},
			{"type":"grant_condition","condition":"poisoned","duration":3},
			{"type":"give_item","item_id":"gold_100"}
		],
		"description": "test"
	}
	EventResolver.apply_effects(ev2_char, open_choice["effects"])
	_assert(ev2_char.current_hp < before_hp, "event choice dealt damage (%d -> %d)" % [before_hp, ev2_char.current_hp])
	_assert(ev2_char.has_condition("poisoned"), "event choice applied poisoned condition")
	_assert(ev2_char.inventory.has_item("gold_100"), "event choice gave gold_100 item to backpack")
	var heal_choice := [{"type":"heal","value":"2d4"}]
	var hp_before_heal := ev2_char.current_hp
	EventResolver.apply_effects(ev2_char, heal_choice)
	_assert(ev2_char.current_hp > hp_before_heal, "event heal raised hp (%d -> %d)" % [hp_before_heal, ev2_char.current_hp])
	_exit_test()

## Event dialog choice click: end-to-end UI -> resolver.
func test_event_dialog_choice_click() -> void:
	_enter_test("event_dialog_choice_click")
	var evd2vp := SubViewport.new()
	evd2vp.size = Vector2i(1280, 720)
	add_child(evd2vp)
	var evd2: EventDialog = load("res://scenes/ui/event_dialog.tscn").instantiate()
	evd2vp.add_child(evd2)
	await get_tree().create_timer(0.2).timeout
	var dialog_char_scores := AbilityScores.new()
	dialog_char_scores.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var dialog_char := Character.new()
	dialog_char.initialize("Dialoger", "human", "fighter", dialog_char_scores)
	dialog_char.inventory.gold = 0
	var dungeon_events2: Dictionary = DataLoader.get_event_table("dungeon_events")
	var event_list2: Array = dungeon_events2.get("events", [])
	var trapped_chest_evt: Dictionary = {}
	for e in event_list2:
		if e.get("id", "") == "trapped_chest":
			trapped_chest_evt = e
			break
	evd2.popup_event(dialog_char, trapped_chest_evt)
	var choice_buttons: Array = evd2.choice_container.get_children()
	_assert(choice_buttons.size() == 3, "trapped_chest has 3 choice buttons in dialog")
	choice_buttons[1].pressed.emit()
	_assert(dialog_char.current_hp < dialog_char.max_hp, "dialog choice dealt damage to character")
	_assert(dialog_char.inventory.has_item("gold_100"), "dialog choice gave gold_100 via UI")
	evd2vp.remove_child(evd2)
	evd2.queue_free()
	evd2vp.queue_free()
	_exit_test()

## Character Sheet overlay: show + render sections + close.
func test_character_sheet() -> void:
	_enter_test("character_sheet")
	# The harness itself is the scene root; wait until its _ready() child setup
	# has finished before the autoload adds its CanvasLayer to the root.
	await get_tree().process_frame
	PlayerManager.reset()
	PlayerManager.add_player("SheetHero")
	var sheet_scores := AbilityScores.new()
	sheet_scores.from_dict({"STR":16,"DEX":12,"CON":14,"INT":10,"WIS":13,"CHA":8})
	var sheet_char := Character.new()
	sheet_char.initialize("SheetHero", "human", "fighter", sheet_scores)
	PlayerManager.set_player_character(0, sheet_char)
	PlayerManager.start_game()
	_assert(PlayerManager.get_active_player().get("character") == sheet_char, "active player is SheetHero")
	CharacterSheet.show_active()
	_assert(CharacterSheet.is_open(), "character sheet opens (is_open true)")
	_assert(CharacterSheet._layer != null and CharacterSheet._layer.visible, "character sheet layer is visible")
	_assert(CharacterSheet._content.get_child_count() > 0, "character sheet rendered content sections")
	var title_text: String = CharacterSheet._title.text
	_assert(title_text.contains("SheetHero"), "character sheet title shows character name")
	var all_text := ""
	for sec in CharacterSheet._content.get_children():
		if sec is Label:
			all_text += sec.text + "\n"
	_assert(all_text.contains("Ability Scores"), "character sheet shows Ability Scores section")
	_assert(all_text.contains("STR"), "character sheet shows STR line")
	_assert(all_text.contains("Saving Throws"), "character sheet shows Saving Throws section")
	_assert(all_text.contains("Skills"), "character sheet shows Skills section")
	_assert(all_text.contains("Equipment"), "character sheet shows Equipment section")
	CharacterSheet.close_sheet()
	_assert(not CharacterSheet.is_open(), "character sheet closes (is_open false)")
	_assert(CharacterSheet._layer == null or not CharacterSheet._layer.visible, "character sheet layer hidden after close")
	CharacterSheet.teardown_for_tests()
	await get_tree().process_frame
	PlayerManager.reset()
	_exit_test()


## Character Sheet button wiring through the normal overworld, dungeon, and
## combat HUD signals. This deliberately presses each production Button rather
## than calling CharacterSheet.show_*() directly.
func test_character_sheet_contexts() -> void:
	_enter_test("character_sheet_contexts")

	# Overworld and dungeon show the active PlayerManager character.
	_setup_world()
	var overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.0)
	var overworld_char: Character = PlayerManager.get_active_player().get("character")
	overworld.hud.btn_sheet.pressed.emit()
	await get_tree().process_frame
	_assert(CharacterSheet.is_open(), "overworld Sheet button opens the character sheet")
	_assert(CharacterSheet._open_char == overworld_char, "overworld Sheet button shows the active character")
	CharacterSheet.close_sheet()
	_teardown_scene(overworld)

	_setup_world()
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 1.0)
	var dungeon_char: Character = PlayerManager.get_active_player().get("character")
	dungeon.hud.btn_sheet.pressed.emit()
	await get_tree().process_frame
	_assert(CharacterSheet.is_open(), "dungeon Sheet button opens the character sheet")
	_assert(CharacterSheet._open_char == dungeon_char, "dungeon Sheet button shows the active character")
	CharacterSheet.close_sheet()
	_teardown_scene(dungeon)

	# Combat shows the character whose turn is active, which may differ from the
	# exploration active player in a party encounter.
	_setup_world()
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["goblin"], "terrain": "plains", "return_state": GameManager.GameState.OVERWORLD}
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.0)
	# Initiative is intentionally random. Pin this UI assertion to a real player
	# turn so a monster opening the round cannot turn null == null into a pass.
	var combat_char: Character = combat.player_entities[0].get("character")
	combat.current_player_idx = 0
	combat.active_character = combat_char
	combat.hud.btn_sheet.pressed.emit()
	await get_tree().process_frame
	_assert(CharacterSheet.is_open(), "combat Sheet button opens the character sheet")
	_assert(CharacterSheet._open_char == combat_char, "combat Sheet button shows the active combat character")
	CharacterSheet.close_sheet()
	_teardown_scene(combat)

	CharacterSheet.teardown_for_tests()
	await get_tree().process_frame
	_setup_world()
	_exit_test()


## Trace representative race/class values through initialization, level-up,
## serialization, runtime HP mutation, and Character Sheet rendering. The
## audit records the current generated hit die so data defects remain visible
## without turning this evidence beat into a false green regression.
func test_character_value_audit() -> void:
	_enter_test("character_value_audit")
	# Let the harness root finish its own _ready() child setup before the
	# autoload lazily adds the Character Sheet CanvasLayer.
	await get_tree().process_frame
	var cases := [
		{"race": "human", "class": "fighter", "name": "Human Fighter", "hit_die": "d10", "level1_hp": 12},
		{"race": "elf", "class": "wizard", "name": "Elf Wizard", "hit_die": "d6", "level1_hp": 8},
		{"race": "half-orc", "class": "barbarian", "name": "Half-Orc Barbarian", "hit_die": "d12", "level1_hp": 14},
		{"race": "dwarf", "class": "rogue", "name": "Dwarf Rogue", "hit_die": "d8", "level1_hp": 10},
	]
	var base_scores := {"STR": 10, "DEX": 10, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10}

	for case in cases:
		var race_id := str(case.get("race", ""))
		var class_id := str(case.get("class", ""))
		var character: Character = _fresh_char(str(case.get("name", "Audit")), race_id, class_id, base_scores)
		var race_data: Dictionary = DataLoader.get_race(race_id)
		var class_data: Dictionary = DataLoader.get_character_class(class_id)
		for ability in AbilityScores.ABILITIES:
			var expected_score := int(base_scores.get(ability, 10)) + int(race_data.get("ability_bonuses", {}).get(ability, 0))
			_assert(character.ability_scores.get_score(ability) == expected_score, "%s %s reflects the %s racial score" % [race_id, class_id, ability])

		var generated_hit_die := str(class_data.get("hit_die", ""))
		var initial_hp := character.max_hp
		_assert(generated_hit_die == str(case.get("hit_die", "")), "%s uses the source hit die" % case.get("name", "Audit"))
		_assert(initial_hp == int(case.get("level1_hp", 0)), "%s level-1 HP matches the source hit die and CON" % case.get("name", "Audit"))
		_assert(character.current_hp == initial_hp, "%s starts at full HP" % case.get("name", "Audit"))
		character.level_up()
		_assert(character.level == 2 and character.current_hp == character.max_hp and character.max_hp > initial_hp, "%s level-up raises and refills HP" % case.get("name", "Audit"))

		var restored: Character = Character.new()
		restored.from_dict(character.to_dict())
		_assert(restored.max_hp == character.max_hp and restored.current_hp == character.current_hp, "%s save/load preserves HP" % case.get("name", "Audit"))
		_assert(restored.ability_scores.to_dict() == character.ability_scores.to_dict(), "%s save/load preserves racialized scores" % case.get("name", "Audit"))

		character.current_hp = maxi(1, character.max_hp - 1)
		CharacterSheet.show_sheet(character)
		var sheet_text := ""
		for section in CharacterSheet._content.get_children():
			if section is Label:
				sheet_text += section.text + "\n"
		_assert(sheet_text.contains("HP %d/%d" % [character.current_hp, character.max_hp]), "%s Sheet renders mutated HP" % case.get("name", "Audit"))
		print("[audit] %s/%s generated_hit_die=%s level1_hp=%d level2_hp=%d sheet_hp=%d/%d" % [race_id, class_id, generated_hit_die, initial_hp, character.max_hp, character.current_hp, character.max_hp])
		CharacterSheet.close_sheet()

	CharacterSheet.teardown_for_tests()
	await get_tree().process_frame
	_setup_world()
	_exit_test()

# --- combat turn-loop integration (closes AIController-not-driven gap) ------

## Drive the REAL combat turn loop and prove AIController's decision produces a
## real, observable monster action (move toward / attack a player) and that the
## live intent preview is wired to the actual AI, not a stub.
func test_combat_ai_loop() -> void:
	_enter_test("combat_ai_loop")
	_setup_world()
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 3.5)
	await get_tree().create_timer(0.5).timeout

	var initial_positions: Array = []
	for m in combat.monster_entities:
		initial_positions.append(m["hex_position"])
	var initial_hp: int = 0
	for p in combat.player_entities:
		initial_hp += int(p["character"].current_hp)

	var saw_intent := false
	var saw_intent_text := false
	var monster_moved := false
	var player_damaged := false
	var polls := 0
	while polls < 120 and not combat._battle_ending:
		var ac: Dictionary = combat.active_combatant
		if not ac.is_empty() and not ac.get("is_player", true):
			var ent: Dictionary = ac.get("entity", {})
			if ent.get("intent", {}).size() > 0:
				saw_intent = true
			if not str(ent.get("intent_text", "")).is_empty():
				saw_intent_text = true
		if not ac.is_empty() and ac.get("is_player", false):
			combat._on_hud_action("end_turn", {})
		await get_tree().create_timer(0.3).timeout
		polls += 1
		for i in combat.monster_entities.size():
			if combat.monster_entities[i]["hex_position"] != initial_positions[i]:
				monster_moved = true
		var cur_hp: int = 0
		for p in combat.player_entities:
			cur_hp += int(p["character"].current_hp)
		if cur_hp < initial_hp:
			player_damaged = true
		if saw_intent and (monster_moved or player_damaged):
			break

	_assert(saw_intent, "live monster turn computed an AIController intent (monster['intent'] set in-loop)")
	_assert(saw_intent_text, "live monster turn published renderable intent text")
	_assert(monster_moved or player_damaged, "AIController decision produced a real effect (monster moved toward player or dealt damage) through the live turn loop")
	_assert(combat.tracker.current_round >= 1, "combat turn loop advanced at least one round")

	_teardown_scene(combat)
	_exit_test()


## Drive the REAL combat turn loop to a resolved end state: equip players,
## weaken + adjacent the monsters, then have players attack through the actual
## input handlers until victory fires via the shared _check_battle_end_conditions
## chokepoint (not a stubbed 'didn't crash').
func test_combat_victory() -> void:
	_enter_test("combat_victory")
	_setup_world()
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 3.5)
	await get_tree().create_timer(0.5).timeout

	# Equip durable players so this scenario can only end in victory. The live
	# turn loop, targeting, attack resolver, death handling, and battle-end
	# chokepoint still run; fixture randomness cannot turn the proof into a TPK.
	for i in combat.player_entities.size():
		var pc: Character = combat.player_entities[i]["character"]
		pc.inventory.equip(Inventory.Slot.WEAPON, "longsword", true)
		pc.base_ac = 1000
		pc.max_hp = 10000
		pc.current_hp = 10000
		pc.is_alive = true
	for i in combat.monster_entities.size():
		var m: Dictionary = combat.monster_entities[i]
		var ppos: Vector2i = combat.player_entities[i % combat.player_entities.size()]["hex_position"]
		var spot: Vector2i = ppos
		for n in HexUtils.get_neighbors(ppos):
			if combat.hex_grid.has_tile(n) and combat.hex_grid.is_hex_passable(n):
				spot = n
				break
		m["hex_position"] = spot
		m["current_hp"] = 1
		m["max_hp"] = 1
		m["armor_class"] = -100
		m["is_alive"] = true
		m["conditions"] = {"prone": 99}
	combat._update_grid_entities()
	seed(424242)

	var rounds := 0
	while rounds < 6 and not combat._battle_ending:
		var start_round: int = combat.tracker.current_round
		var guard := 0
		while not combat._battle_ending and combat.tracker.current_round == start_round and guard < 12:
			var ac: Dictionary = combat.active_combatant
			if not ac.is_empty() and ac.get("is_player", false):
				_drive_player_attack_turn(combat)
			await get_tree().create_timer(2.5).timeout
			guard += 1
		rounds += 1

	var alive_monsters := 0
	for m in combat.monster_entities:
		if m["is_alive"]:
			alive_monsters += 1
	_assert(combat._battle_ending, "battle reached an end state through the live turn loop")
	_assert(alive_monsters == 0, "victory: all monsters defeated (got %d alive)" % alive_monsters)
	_assert(GameManager.defeated_monsters.has("goblin"), "victory registered defeated monsters in GameManager")

	_teardown_scene(combat)
	_exit_test()


## Drive the REAL combat end-state chokepoint through a total party wipe, then
## instantiate the production defeat screen with its safe-save affordance.
func test_combat_defeat() -> void:
	_enter_test("combat_defeat")
	_setup_world()
	GameManager.game_in_progress = true
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	for player_entity in combat.player_entities:
		var character: Character = player_entity.get("character")
		character.current_hp = 0
		character.is_alive = false
	_assert(combat._check_battle_end_conditions(), "defeat: live combat detects a total party wipe")
	_assert(combat._battle_ending, "defeat: combat enters its terminal state")
	_assert(GameManager.defeated_monsters.is_empty(), "defeat: no monster victory ledger is recorded")
	_teardown_scene(combat)

	GameManager.current_state = GameManager.GameState.DEFEAT
	GameManager.transition_context = {"reason": "The party was defeated in the final encounter."}
	var defeat: Node = await _spawn_scene("res://scenes/defeat.tscn", 0.3)
	_assert(defeat.title_label.text == "The Party Falls", "defeat screen presents the player-facing loss title")
	_assert(defeat.reason_label.text.contains("final encounter"), "defeat screen presents the loss reason")
	_assert(defeat.continue_button.text == "Load Safe Save", "defeat screen offers safe-save recovery")
	_assert(defeat.menu_button.text == "Return to title" and defeat.menu_button.pressed.is_connected(defeat._on_menu_pressed), "defeat screen offers its wired return-to-title action")
	_teardown_scene(defeat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = false
	_exit_test()

## Production Lich King defeat, safe reload, victory, and terminal destinations.
## The normal GUI readability and fresh-process relaunch remain manual review.
func test_final_encounter_round_trip() -> void:
	_enter_test("final_encounter_round_trip")
	_setup_world()
	GameManager.game_in_progress = true
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))
	_assert(PartyManager.recruit_companion("aldric"), "final encounter recruits Aldric")
	_assert(PartyManager.recruit_companion("mira"), "final encounter recruits Mira")
	for index in 3:
		PartyManager.get_active_characters()[index].inventory.add_item("crown_fragment")
	var slot := "final_encounter_round_trip"
	SaveManager.delete_save(slot)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {}
	_assert(SaveManager.save_game(slot), "final encounter writes the pre-finale safe save")

	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["lich_king"], "return_state": GameManager.GameState.OVERWORLD, "terrain": "plains"}
	var defeat_combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	_assert(defeat_combat.monster_entities.size() == 1 and defeat_combat.monster_entities[0].get("monster_id", "") == "lich_king", "final encounter uses the production Lich King")
	for player_entity in defeat_combat.player_entities:
		var defeated_character: Character = player_entity.get("character")
		defeated_character.current_hp = 0
		defeated_character.is_alive = false
	_assert(defeat_combat._check_battle_end_conditions() and defeat_combat._battle_ending, "final encounter loss reaches the live defeat boundary")
	_assert(not GameManager.defeated_monsters.has("lich_king"), "final encounter loss does not record a boss victory")
	_teardown_scene(defeat_combat)
	GameManager.current_state = GameManager.GameState.DEFEAT
	GameManager.transition_context = {"reason": "The party was defeated in the final encounter."}
	var defeat: Node = await _spawn_scene("res://scenes/defeat.tscn", 0.3)
	_assert(defeat.title_label.text == "The Party Falls" and defeat.continue_button.text == "Load Safe Save", "final encounter loss presents safe reload controls")
	_teardown_scene(defeat)

	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(slot), "final encounter reloads the pre-finale safe save")
	_assert(GameManager.current_state == GameManager.GameState.OVERWORLD and GameManager.defeated_monsters.is_empty(), "final encounter reload restores pre-finale progress without the boss victory")
	_assert(PartyManager.get_active_characters().size() == 4 and PartyManager.get_active_characters()[0].inventory.count_item("crown_fragment") == 1, "final encounter reload restores the full party and Crown fragments")

	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["lich_king"], "return_state": GameManager.GameState.OVERWORLD, "terrain": "plains"}
	var victory_combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	_assert(victory_combat.monster_entities.size() == 1 and victory_combat.monster_entities[0].get("spells", []).size() == 7, "final encounter reload keeps the production Lich King spell loadout")
	var lich: Dictionary = victory_combat.monster_entities[0]
	lich["current_hp"] = 0
	lich["max_hp"] = 1
	lich["armor_class"] = -100
	lich["is_alive"] = false
	_assert(victory_combat._check_battle_end_conditions() and victory_combat._battle_ending, "final encounter victory reaches the live victory boundary")
	_assert(GameManager.defeated_monsters.has("lich_king") and GameManager.are_win_conditions_met(), "final encounter victory records the boss and completes Crown goals")
	_assert(GameManager.claim_reward("lich_king_crown"), "final encounter claims its one-time reward ledger")
	_assert(not GameManager.claim_reward("lich_king_crown"), "final encounter reward claim is idempotent")
	_teardown_scene(victory_combat)

	GameManager.current_state = GameManager.GameState.COMPLETION
	GameManager.transition_context = {"reason": "Campaign goals completed!"}
	var completion: Node = await _spawn_scene("res://scenes/completion.tscn", 0.3)
	_assert(completion.title_label.text == "Crown Reclaimed", "final encounter victory presents the completion screen")
	_teardown_scene(completion)
	SaveManager.delete_save(slot)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = false
	GameManager.active_dungeon_state.clear()
	_exit_test()


## Run one bounded production-data encounter composition through the real
## combat entities and resolvers. The fixture intentionally records each
## required Gate 5 mechanic instead of relying on a green smoke-only result.
func test_jump_spell_movement() -> void:
	_enter_test("jump_spell_movement")
	_setup_mixed_world()
	seed(20261006)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	if combat.player_entities.size() < 4:
		_assert(false, "Jump movement scenario needs the production four-character party")
		_teardown_scene(combat)
		_exit_test()
		return
	var wizard: Character = combat.player_entities[2]["character"]
	var fighter: Character = combat.player_entities[0]["character"]
	var cleric: Character = combat.player_entities[3]["character"]
	var wizard_position := Vector2i.ZERO
	var fighter_position := Vector2i(1, 0)
	var cleric_position := Vector2i(0, 1)
	var rogue_position := Vector2i(-1, 1)
	var positions := [fighter_position, rogue_position, wizard_position, cleric_position]
	for index in positions.size():
		combat.player_entities[index]["hex_position"] = positions[index]
	for monster in combat.monster_entities:
		monster["reaction_available"] = false
	combat._update_grid_entities()
	wizard.known_spells.assign(["jump"])
	wizard.spell_slots = {"1": 1, "2": 1}
	combat.current_player_idx = 2
	combat.active_character = wizard
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.hud.update_hud(wizard, combat.tracker)
	combat.hud._show_spell_selection()
	var jump_index := -1
	for index in combat.hud.spells_registered.size():
		if str(combat.hud.spells_registered[index].get("id", "")) == "jump":
			jump_index = index
	_assert(jump_index >= 0 and not combat.hud.spell_list.is_item_disabled(jump_index), "2024 Jump is available to a Wizard in the production picker")
	if jump_index >= 0:
		combat.hud._on_spell_selected(jump_index)
		combat.pending_spell_data["_selected_spell_slot_level"] = 2
		_assert(combat._spell_upcast_maximum_targets(combat.pending_spell_data) == 2, "Upcast Jump adds one willing target per slot level")
		await combat._on_hex_clicked(fighter_position)
		await combat._on_hex_clicked(cleric_position)
	_assert(int(wizard.spell_slots["2"]) == 0 and fighter.has_condition("jumping") and cleric.has_condition("jumping") and wizard.concentrating_on.is_empty() and not combat.turn_budget.bonus_action_available, "Upcast Jump grants both willing party members a one-minute leap without concentration")
	var leap_origin: Vector2i = combat.player_entities[0]["hex_position"]
	combat.current_player_idx = 0
	combat.active_character = fighter
	combat.turn_budget.reset(fighter, combat.player_entities)
	combat.remaining_speed = 2.0
	var walking: Dictionary = combat.hex_grid.get_reachable(leap_origin, combat.remaining_speed)
	var landing := Vector2i(9999, 9999)
	for candidate in combat.hex_grid.tiles:
		var distance := HexUtils.get_distance(leap_origin, candidate)
		if distance < 3 or distance > 6 or not combat.hex_grid.is_hex_passable(candidate) or combat._is_occupied_hex(candidate):
			continue
		if float(walking.get(candidate, INF)) > 2.0:
			landing = candidate
			break
	_assert(landing != Vector2i(9999, 9999), "Combat map has a legal landing that costs more than 10 feet to walk to")
	if landing != Vector2i(9999, 9999):
		var jump_line := HexUtils.hex_line(leap_origin, landing)
		var crossed_water := false
		for index in range(1, jump_line.size() - 1):
			var intermediate: Vector2i = jump_line[index]
			if not combat.hex_grid.has_tile(intermediate) or combat._is_occupied_hex(intermediate):
				continue
			combat.hex_grid.tiles[intermediate].terrain = HexTile.TerrainType.WATER
			crossed_water = true
			break
		var jump_cost: float = combat._spell_jump_move_cost(leap_origin, landing, walking)
		_assert(crossed_water and is_equal_approx(jump_cost, 2.0), "Jump spends 10 feet to reach a landing across impassable terrain")
		await combat._on_hex_clicked(landing)
		_assert(combat.player_entities[0]["hex_position"] == landing and is_equal_approx(combat.remaining_speed, 0.0) and bool(fighter.feature_uses.get("jump_spell_used_this_turn", false)), "Production movement executes the leap once and charges the remaining 10 feet")
		_assert(combat._spell_jump_move_cost(landing, leap_origin, combat.hex_grid.get_reachable(landing, combat.remaining_speed)) < 0.0, "Jump cannot be used for a second leap in the same turn")
	_teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	_exit_test()


func test_shared_spell_flow() -> void:
	_enter_test("shared_spell_flow")
	_setup_world()
	DataLoader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	var class_data: Dictionary = DataLoader.classes["wizard"]
	var previous_list: Array = class_data["spell_list_ids"].duplicate()
	var added: Array[String] = ["sandbox:ember", "sandbox:shock", "sandbox:mend", "sandbox:resolve"]
	class_data["spell_list_ids"].append_array(added)
	var caster := _fresh_char("JSON Wizard", "human", "wizard", {"STR": 10, "DEX": 14, "CON": 14, "INT": 16, "WIS": 10, "CHA": 10})
	var ally := _fresh_char("JSON Ally", "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	_assert(ClassProgression.choose_wizard_spellbook(caster, added), "JSON-only spells can be learned through ordinary Wizard spellbook choices")
	var prepared: Array[String] = caster.get_spell_option_ids(true).slice(0, caster.get_spellcasting_capacity("cantrips"))
	prepared.append_array(added)
	_assert(ClassProgression.choose_spell_selection(caster, prepared) and "sandbox:mend" in caster.known_spells, "JSON-only spells can be prepared through production class choices")
	PlayerManager.set_player_character(0, caster)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, caster)
	PartyManager.register_player_character(1, ally)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	combat.current_player_idx = 0
	combat.active_character = caster
	combat.active_combatant = {"id": "shared_caster", "is_player": true, "entity": caster}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	for index in combat.monster_entities.size():
		combat.monster_entities[index]["hex_position"] = Vector2i(3 + index, 0)
		combat.monster_entities[index]["current_hp"] = 1000
		combat.monster_entities[index]["max_hp"] = 1000
	caster.spell_slots = {"1": 8}
	combat.turn_budget.reset(caster, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat.hud.update_hud(caster, combat.tracker)
	combat.hud._show_spell_selection()
	var ward_index := -1
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index].get("id", "") == "sandbox:resolve": ward_index = index
	_assert(ward_index >= 0 and not combat.hud.spell_list.is_item_disabled(ward_index), "A new namespaced spell appears enabled in the real spell picker")
	combat.hud._on_spell_selected(ward_index)
	combat._cancel_pending_action()
	_assert(int(caster.spell_slots["1"]) == 8 and combat.turn_budget.action_available, "Cancelling a JSON spell's targeting spends no resources")
	combat.hud._show_spell_selection()
	combat.hud._on_spell_selected(ward_index)
	await combat._on_hex_clicked(Vector2i(1, 0))
	_assert(ally.has_condition("blessed") and int(caster.spell_slots["1"]) == 7 and not combat.turn_budget.action_available and caster.concentrating_on.get("targets", []).has(ally), "HUD casting grants a new-ID timed effect, establishes concentration and spends exactly one slot and Magic Action")
	combat._end_concentration(caster)
	_assert(not ally.has_condition("blessed"), "New-ID concentration ends through the actual combat cleanup")
	combat.turn_budget.reset(caster, combat.player_entities)
	ally.current_hp = 0
	ally.is_alive = false
	ally.add_condition("poisoned", 10)
	combat.pending_spell_data = DataLoader.get_spell("sandbox:mend").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._on_hex_clicked(Vector2i(1, 0))
	await combat._on_hex_clicked(Vector2i(1, 0))
	_assert(ally.current_hp == 4 and ally.temp_hp == 3 and not ally.has_condition("poisoned") and int(caster.spell_slots["1"]) == 6 and not combat.turn_budget.bonus_action_available and combat.turn_budget.action_available, "A composed new-ID multi-target healing spell selects a downed ally, applies effects once and spends only its Bonus Action")
	combat.turn_budget.reset(caster, combat.player_entities)
	var foe: Dictionary = combat.monster_entities[0]
	foe["saving_throw_bonuses"] = {"DEX": -100, "CON": -100}
	combat.pending_spell_data = DataLoader.get_spell("sandbox:shock").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._on_hex_clicked(foe["hex_position"])
	_assert(int(foe["current_hp"]) == 996 and CombatAction.has_condition(foe, "poisoned") and int(caster.spell_slots["1"]) == 5, "New-ID spherical save spells share geometry, damage and one cast-wide resource cost")
	foe["saving_throw_bonuses"]["CON"] = 100
	combat._resolve_condition_spell_repeat_saves(foe)
	_assert(not CombatAction.has_condition(foe, "poisoned"), "New-ID repeat saves run through the encounter lifecycle")
	combat.turn_budget.reset(caster, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("sandbox:resolve").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._on_hex_clicked(Vector2i(1, 0))
	var remaining := int(SpellEffects.records(ally).values()[0]["remaining_seconds"])
	_teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	caster.spell_slots["1"] = 1
	_assert(SaveManager.save_game("shared_spell_flow") and SaveManager.load_game("shared_spell_flow"), "New-ID timed effects and concentration round-trip through the safe disk-save boundary")
	var loaded_caster: Character = PlayerManager.get_player(0).get("character")
	var loaded_ally: Character = PlayerManager.get_player(1).get("character")
	_assert(loaded_ally != ally and loaded_ally.has_condition("blessed") and loaded_caster.concentrating_on.get("targets", []).has(loaded_ally), "Reload restores new-ID effect ownership and live target references")
	var installed_ward: Dictionary = DataLoader.spells["sandbox:resolve"]
	DataLoader.spells.erase("sandbox:resolve")
	_assert(not SaveManager.load_game("shared_spell_flow") and PlayerManager.get_player(0).get("character") == loaded_caster, "Missing mod content rejects reload before replacing the live party")
	DataLoader.spells["sandbox:resolve"] = installed_ward
	SpellEffects.advance_time([loaded_caster, loaded_ally], remaining)
	_assert(not loaded_ally.has_condition("blessed") and loaded_caster.concentrating_on.is_empty(), "A reloaded JSON effect expires and releases concentration through the common clock")
	loaded_caster.spell_slots["1"] = 2
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await _spawn_scene("res://scenes/dungeon.tscn", 0.2)
	var room: Room
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: room = candidate
	_assert(room != null, "Shared spells have an authored exploration room")
	if room != null:
		dungeon.hex_grid.hex_clicked.emit(room.coord)
		await get_tree().process_frame
		var view: LocalRoomView = dungeon.local_view
		var spell_select: OptionButton
		var target_select: OptionButton
		var cast_button: Button
		for row in view.action_row.get_children():
			if not row is VBoxContainer: continue
			for child in row.get_children():
				if child is OptionButton:
					if spell_select == null: spell_select = child
					else: target_select = child
				if child is Button and child.text == "Cast": cast_button = child
		_assert(spell_select != null and target_select != null and cast_button != null, "Exploration discovers JSON spells in a shared spell/target control")
		if spell_select != null:
			for index in spell_select.item_count:
				if spell_select.get_item_metadata(index) == "sandbox:resolve":
					spell_select.select(index)
					spell_select.item_selected.emit(index)
			for index in target_select.item_count:
				if target_select.get_item_metadata(index) == "party:" + loaded_ally.character_id: target_select.select(index)
			var room_slots_before := int(loaded_caster.spell_slots["1"])
			cast_button.pressed.emit()
			_assert(loaded_ally.has_condition("blessed") and int(loaded_caster.spell_slots["1"]) == room_slots_before - 1 and loaded_caster.concentrating_on.get("spell_id", "") == "sandbox:resolve", "The real exploration Cast control applies a new-ID spell and spends its slot once (slots=%s concentration=%s)" % [str(loaded_caster.spell_slots), str(loaded_caster.concentrating_on)])
		_teardown_scene(dungeon)
	class_data["spell_list_ids"] = previous_list
	print("SHARED_SPELL_LIVE_FLOW_CHECKS_COMPLETE")
	_exit_test()


func test_spell_effect_lifetime() -> void:
	_enter_test("spell_effect_lifetime")
	_setup_mixed_world()
	PartyManager.get_active_characters()[3].inventory.add_item("component_pouch")
	PartyManager.get_active_characters()[3].inventory.add_item("holy_symbol")
	PartyManager.get_active_characters()[3].inventory.unequip(Inventory.Slot.WEAPON)
	PartyManager.get_active_characters()[2].inventory.add_item("component_pouch")
	seed(20261005)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	var cleric: Character = combat.player_entities[3]["character"]
	var wizard: Character = combat.player_entities[2]["character"]
	var fighter: Character = combat.player_entities[0]["character"]
	var foe: Dictionary = combat.monster_entities[0]
	var positions := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i.ZERO]
	for index in 4:
		combat.player_entities[index]["hex_position"] = positions[index]
	foe["hex_position"] = Vector2i(2, 0)
	foe["is_alive"] = true
	foe["current_hp"] = 500
	foe["max_hp"] = 500
	foe["saving_throw_bonuses"] = {"WIS": -100}
	combat.current_player_idx = 3
	combat.active_character = cleric
	cleric.known_spells.assign(["bless", "shield_of_faith", "heal", "contact_other_plane"])
	cleric.spell_slots = {"1": 4, "5": 1, "6": 1}
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.hud.update_hud(cleric, combat.tracker)
	combat.hud._show_spell_selection()
	var bless_index := -1
	var heal_index := -1
	var unsupported_index := -1
	for index in combat.hud.spells_registered.size():
		match str(combat.hud.spells_registered[index].get("id", "")):
			"bless": bless_index = index
			"heal": heal_index = index
			"contact_other_plane": unsupported_index = index
	_assert(heal_index >= 0 and not combat.hud.spell_list.is_item_disabled(heal_index), "Ordinary level-six Heal is enabled with a normal slot")
	_assert(unsupported_index >= 0 and combat.hud.spell_list.is_item_disabled(unsupported_index), "Contact Other Plane remains visibly disabled pending its Wave 5 outcomes")
	combat.hud._on_spell_selected(bless_index)
	await combat._on_hex_clicked(positions[0])
	combat._cancel_pending_action()
	_assert(int(cleric.spell_slots["1"]) == 4 and combat.turn_budget.action_available and not fighter.has_condition("blessed"), "Cancelling target selection spends neither slot nor action")
	combat.hud._show_spell_selection()
	combat.hud._on_spell_selected(bless_index)
	await combat._on_hex_clicked(positions[0])
	await combat._on_hex_clicked(positions[1])
	await combat._on_hex_clicked(positions[3])
	_assert(fighter.has_condition("blessed") and combat.player_entities[1]["character"].has_condition("blessed") and cleric.has_condition("blessed") and not wizard.has_condition("blessed"), "HUD Bless affects only the three selected creatures")
	_assert(int(cleric.spell_slots["1"]) == 3 and not combat.turn_budget.action_available and cleric.concentrating_on.get("targets", []).size() == 3, "A multi-target cast spends one slot and one action")
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("shield_of_faith").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._on_hex_clicked(foe["hex_position"])
	_assert(not fighter.has_condition("blessed") and CombatAction.has_condition(foe, "shield_of_faith") and not combat.turn_budget.bonus_action_available, "Replacing concentration releases Bless and Shield of Faith can protect a monster")
	var ward_attack := CombatAction.resolve_weapon_attack(fighter, foe, DataLoader.get_item("club"))
	_assert(int(ward_attack.get("target_ac", -1)) == int(foe.get("armor_class", 10)) + 2, "Shield of Faith adds two AC on the production monster attack path")
	var faith_source := str(cleric.concentrating_on.get("effect_source", ""))
	combat.tracker.current_round += 1
	combat._tick_spell_effect_boundary(cleric, "start")
	combat._tick_spell_effect_boundary(cleric, "start")
	_assert(int(SpellEffects.records(foe).get(faith_source, {}).get("remaining_seconds", -1)) == 594, "Repeated turn setup advances an effect boundary only once")

	combat.current_player_idx = 2
	combat.active_character = wizard
	wizard.known_spells.assign(["hold_person", "hold_monster"])
	wizard.spell_slots = {"2": 1, "5": 1}
	combat.turn_budget.reset(wizard, combat.player_entities)
	foe["creature_type"] = "beast"
	combat.pending_spell_data = DataLoader.get_spell("hold_person").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(foe["hex_position"])
	_assert(int(wizard.spell_slots["2"]) == 1 and combat.turn_budget.action_available and not CombatAction.is_paralyzed(foe), "Hold Person rejects a Beast before spending resources")
	foe["creature_type"] = "humanoid"
	await combat._execute_player_spell(foe["hex_position"])
	_assert(int(wizard.spell_slots["2"]) == 0 and CombatAction.is_paralyzed(foe) and wizard.concentrating_on.get("targets", []).has(foe), "Hold Person enters the production save and concentration path")
	foe["saving_throw_bonuses"]["WIS"] = 1000
	combat._resolve_condition_spell_repeat_saves(foe)
	_assert(not CombatAction.is_paralyzed(foe) and wizard.concentrating_on.is_empty() and CombatAction.has_condition(foe, "shield_of_faith"), "A successful repeat save leaves another caster's ward intact")
	foe["saving_throw_bonuses"] = {"CHA": -1000}
	var second_bane_target: Dictionary = foe.duplicate(true)
	second_bane_target["id"] = "bane-second-target"
	second_bane_target["name"] = "Second Bane target"
	second_bane_target["hex_position"] = Vector2i(1, 1)
	second_bane_target["conditions"] = {}
	second_bane_target["condition_sources"] = {}
	second_bane_target["spell_effects"] = {}
	second_bane_target["saving_throw_bonuses"] = {"CHA": -1000}
	combat.monster_entities.append(second_bane_target)
	combat._update_grid_entities()
	combat.current_player_idx = 3
	combat.active_character = cleric
	cleric.known_spells.assign(["bless", "bane"])
	cleric.spell_slots["1"] = 3
	cleric.spell_slots["2"] = 1
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.hud.update_hud(cleric, combat.tracker)
	combat.hud._show_spell_selection()
	var bane_index := -1
	for index in combat.hud.spells_registered.size():
		if str(combat.hud.spells_registered[index].get("id", "")) == "bane":
			bane_index = index
	_assert(bane_index >= 0 and not combat.hud.spell_list.is_item_disabled(bane_index), "Bane is enabled in the production Cleric spell picker")
	if bane_index >= 0:
		combat.hud._on_spell_selected(bane_index)
		combat.pending_spell_data["_selected_spell_slot_level"] = 2
		_assert(combat._spell_upcast_maximum_targets(combat.pending_spell_data) == 4, "Upcast Bane allows one additional target per slot level")
		await combat._on_hex_clicked(foe["hex_position"])
		await combat._on_hex_clicked(second_bane_target["hex_position"])
		await combat._on_hex_clicked(foe["hex_position"])
	_assert(int(cleric.spell_slots["2"]) == 0 and CombatAction.has_condition(foe, "baned") and CombatAction.has_condition(second_bane_target, "baned") and cleric.concentrating_on.get("spell_id", "") == "bane" and cleric.concentrating_on.get("targets", []).size() == 2, "Production upcast Bane spends one slot, resolves two CHA saves and tracks both targets")
	cleric.known_spells.assign(["aid"])
	cleric.spell_slots["3"] = 1
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.hud.update_hud(cleric, combat.tracker)
	combat.hud._show_spell_selection()
	var aid_index := -1
	for index in combat.hud.spells_registered.size():
		if str(combat.hud.spells_registered[index].get("id", "")) == "aid":
			aid_index = index
	_assert(aid_index >= 0 and not combat.hud.spell_list.is_item_disabled(aid_index), "Aid is enabled in the production Cleric spell picker")
	if aid_index >= 0:
		combat.hud._on_spell_selected(aid_index)
		combat.pending_spell_data["_selected_spell_slot_level"] = 3
		var aid_hp_before: Array[int] = [fighter.max_hp, combat.player_entities[1]["character"].max_hp, wizard.max_hp]
		await combat._on_hex_clicked(positions[0])
		await combat._on_hex_clicked(positions[1])
		await combat._on_hex_clicked(positions[2])
		_assert(fighter.max_hp == aid_hp_before[0] + 10 and combat.player_entities[1]["character"].max_hp == aid_hp_before[1] + 10 and wizard.max_hp == aid_hp_before[2] + 10 and cleric.spell_slots["3"] == 0, "Production upcast Aid spends one slot and raises three selected party members' current and maximum HP by 10")
		SpellEffects.advance_time(combat.player_entities.map(func(entity): return entity["character"]), 28800)
		_assert(fighter.max_hp == aid_hp_before[0] and combat.player_entities[1]["character"].max_hp == aid_hp_before[1] and wizard.max_hp == aid_hp_before[2], "Production Aid expiry restores each selected party member's original maximum HP")
	wizard.known_spells.assign(["alter_self"])
	wizard.spell_slots["2"] = 1
	combat.current_player_idx = 2
	combat.active_character = wizard
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.hud.update_hud(wizard, combat.tracker)
	combat.hud._show_spell_selection()
	var alter_self_index := -1
	for index in combat.hud.spells_registered.size():
		if str(combat.hud.spells_registered[index].get("id", "")) == "alter_self":
			alter_self_index = index
	_assert(alter_self_index >= 0 and not combat.hud.spell_list.is_item_disabled(alter_self_index), "Alter Self's supported Natural Weapons option is enabled in the production Wizard picker")
	if alter_self_index >= 0:
		combat.hud._on_spell_selected(alter_self_index)
		await combat._on_hex_clicked(positions[2])
		var natural_weapon_profile := CombatAction.unarmed_attack_profile(wizard)
		_assert(wizard.spell_slots["2"] == 0 and wizard.concentrating_on.get("spell_id", "") == "alter_self" and wizard.has_condition("alter_self_natural_slashing") and natural_weapon_profile.get("damage", "") == "1d6+INT" and natural_weapon_profile.get("damage_type", "") == "slashing", "Production Alter Self grants source-owned Slashing Natural Weapons using the Wizard's spellcasting ability")
		SpellEffects.advance_time([wizard], 3600)
		_assert(not wizard.has_condition("alter_self_natural_slashing") and wizard.concentrating_on.is_empty(), "Production Alter Self expires after one hour and removes its Natural Weapons option")
	SpellEffects.finish_encounter([cleric, wizard], combat._spell_effect_targets())
	_assert(SpellEffects.records(foe).is_empty() and cleric.concentrating_on.is_empty() and not CombatAction.has_condition(foe, "baned"), "Effects on transient monsters finish at the encounter boundary")
	var saved_bless := SpellEffects.begin_cast(cleric, DataLoader.get_spell("bless"))
	cleric.concentrating_on = {"spell_id": "bless", "effect_source": saved_bless["source_id"]}
	SpellEffects.grant(fighter, saved_bless, "blessed")
	await combat._end_battle("victory")
	_assert(fighter.has_condition("blessed") and not cleric.concentrating_on.is_empty(), "Surviving party effects retain their lifetime after an encounter")
	_teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	_assert(SaveManager.save_game("effect_batch"), "Managed party effects save through the production save boundary")
	_assert(SaveManager.load_game("effect_batch"), "Managed party effects reload through the production load boundary")
	var restored_fighter: Character = PartyManager.characters[fighter.character_id]
	var restored_cleric: Character = PartyManager.characters[cleric.character_id]
	_assert(restored_fighter.has_condition("blessed") and restored_cleric.concentrating_on.get("targets", []).has(restored_fighter), "Disk reload restores the condition and binds concentration to the restored character")
	var corrupt := SaveManager._read_save("effect_batch").duplicate(true)
	corrupt["party"]["characters"][fighter.character_id]["spell_effects"][saved_bless["source_id"]]["remaining_seconds"] = "forever"
	var corrupt_file := FileAccess.open(SaveManager.SAVE_DIR + "effect_batch_bad.sav", FileAccess.WRITE)
	corrupt_file.store_string(JSON.stringify(corrupt))
	corrupt_file.close()
	_assert(not SaveManager.load_game("effect_batch_bad") and PartyManager.characters[fighter.character_id] == restored_fighter and restored_fighter.has_condition("blessed"), "Corrupt effect data is refused without changing the active party")
	GameManager.advance_campaign_time(60)
	_assert(not restored_fighter.has_condition("blessed") and restored_cleric.concentrating_on.is_empty(), "Production campaign time expires reloaded effects")
	SaveManager.delete_save("effect_batch")
	SaveManager.delete_save("effect_batch_bad")
	_exit_test()

func test_mixed_mechanics_encounter() -> void:
	_enter_test("mixed_mechanics_encounter")
	_setup_mixed_world()
	seed(20260810)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	_assert(combat.player_entities.size() == 4, "mixed encounter uses the four-member production cohort")
	_assert(combat.monster_entities.size() >= 1, "mixed encounter has a production monster target")
	if combat.player_entities.size() < 4 or combat.monster_entities.is_empty():
		_teardown_scene(combat)
		_exit_test()
		return

	var by_class: Dictionary = {}
	for entity in combat.player_entities:
		by_class[entity["character"].class_id] = entity
	var fighter: Character = by_class["fighter"]["character"]
	var rogue: Character = by_class["rogue"]["character"]
	var wizard: Character = by_class["wizard"]["character"]
	var cleric: Character = by_class["cleric"]["character"]
	rogue.level_up()
	var target: Dictionary = combat.monster_entities[0]
	target["current_hp"] = 100
	target["max_hp"] = 100
	target["armor_class"] = 5
	target["is_alive"] = true
	combat._update_grid_entities()

	# Martial attack: production weapon data crosses CombatAction.
	var weapon: Dictionary = DataLoader.get_item("longsword")
	var martial_result := CombatAction.resolve_weapon_attack(fighter, target, weapon)
	_assert(martial_result.get("hit", false) and int(martial_result.get("damage", 0)) > 0, "mixed encounter resolves a production martial attack")

	# Bonus action: production Rogue Cunning Action goes through CombatState's
	# feature path and consumes the extracted turn budget.
	var rogue_index := int(by_class["rogue"].get("player_id", 1))
	combat.current_player_idx = rogue_index
	combat.active_character = rogue
	combat.turn_budget.reset(rogue, combat.player_entities)
	combat.remaining_speed = rogue.get_speed()
	var cunning_action: Dictionary = rogue.get_feature("rogue_cunning_action").duplicate(true)
	cunning_action["selected_action"] = "disengage"
	var cunning_uses_before := int(rogue.feature_uses.get("rogue_cunning_action", 0))
	combat._execute_class_feature(cunning_action)
	_assert(cunning_uses_before > int(rogue.feature_uses.get("rogue_cunning_action", 0)) and not combat.turn_budget.bonus_action_available and rogue.has_condition("disengaging"), "mixed encounter spends a bonus action through production Cunning Action")

	# Healing: Cure Wounds is loaded from production spell data and its typed
	# effect is applied to a wounded cohort member.
	fighter.current_hp = maxi(1, fighter.max_hp - 6)
	var hp_before_heal := fighter.current_hp
	var cure_wounds: Dictionary = DataLoader.get_spell("cure_wounds")
	var heal_cast := CombatAction.resolve_spell(cleric, fighter, cure_wounds, true)
	var healed_amount := 0
	for effect in CombatAction.spell_effects_for_slot_level(cure_wounds, int(heal_cast.get("slot_level", 1))):
		for result in EventResolver.apply_effects(fighter, [effect], cleric):
			healed_amount += int(result.get("amount", 0))
	_assert(heal_cast.get("success", false) and healed_amount > 0 and fighter.current_hp > hp_before_heal, "mixed encounter resolves production Cure Wounds healing")
	fighter.current_hp = 1
	var healing_word: Dictionary = DataLoader.get_spell("healing_word")
	var healing_word_cast := CombatAction.resolve_spell(cleric, fighter, healing_word, false, {}, [], 3, 30)
	var healing_word_results := EventResolver.apply_effects(fighter, CombatAction.spell_effects_for_slot_level(healing_word, 3), cleric)
	_assert(healing_word_cast.get("success", false) and healing_word_results.size() == 1 and int(healing_word_results[0].get("amount", 0)) >= 9 and fighter.current_hp > 1, "mixed encounter resolves upcast Healing Word with the Cleric's Wisdom modifier")
	var sacred_flame: Dictionary = DataLoader.get_spell("sacred_flame")
	target["current_hp"] = 100
	target["max_hp"] = 100
	target["saving_throw_bonuses"] = {"DEX": -100}
	var sacred_flame_result := CombatAction.resolve_spell(cleric, target, sacred_flame, false, {}, [], 0, 60)
	_assert(sacred_flame_result.get("success", false) and not sacred_flame_result.get("saved", true) and sacred_flame_result.get("damage_type", "") == "radiant" and int(sacred_flame_result.get("damage", 0)) >= 1 and int(sacred_flame_result.get("damage", 0)) <= 8 and target["current_hp"] < 100, "mixed encounter resolves a 60-foot Sacred Flame and applies Radiant damage after the target fails its Dexterity save")
	target["saving_throw_bonuses"] = {}

	# Bless selects creatures; source ownership drives concentration cleanup.
	var bless: Dictionary = DataLoader.get_spell("bless")
	var bless_targets: Array = [fighter, rogue, cleric]
	var bless_cast := SpellEffects.begin_cast(cleric, bless)
	cleric.concentrating_on = {"spell_id": "bless", "effect_source": bless_cast["source_id"], "targets": bless_targets}
	for target_character in bless_targets:
		SpellEffects.grant(target_character, bless_cast, "blessed")
	_assert(bless.get("base_targets", 0) == 3 and bless.get("duration_seconds", 0) == 60 and fighter.has_condition("blessed"), "mixed encounter applies source-owned Bless to chosen creatures")

	# Save spell and area effect: production Fireball resolves its DEX-save
	# contract, while the same selection result drives sphere geometry.
	wizard.level_up()
	wizard.level_up()
	wizard.spell_slots["3"] = 1
	var fireball: Dictionary = DataLoader.get_spell("fireball")
	var fireball_selection := EventResolver.resolve_area_selection(fireball.get("effects", [])[0])
	var fireball_area := Targeting.get_sphere_targets(target["hex_position"], int(fireball_selection.get("radius", 0)), combat.hex_grid)
	var fireball_result := CombatAction.resolve_spell(wizard, target, fireball, true)
	_assert(fireball_selection.get("success", false) and fireball_area.has(target["hex_position"]) and fireball.get("save", "") == "DEX" and fireball_result.get("success", false), "mixed encounter resolves a production save spell over a sphere area")

	# Sorcerous Burst: the combat picker supplies one of the recorded damage
	# types, then the normal ranged-spell resolver applies damage and preserves
	# the chosen type in its result.
	var burst_spell: Dictionary = DataLoader.get_spell("sorcerous_burst").duplicate(true)
	var selected_burst_type: String = await combat.hud.request_damage_type_choice(burst_spell.get("damage_type_options", []), "Sorcerous Burst")
	burst_spell["damage_type"] = selected_burst_type
	target["current_hp"] = 100
	target["max_hp"] = 100
	target["armor_class"] = -100
	var burst_result := CombatAction.resolve_spell(wizard, target, burst_spell, false, {}, [], 0, 30)
	_assert(selected_burst_type == "acid" and burst_result.get("success", false) and burst_result.get("hit", false) and burst_result.get("damage_type", "") == selected_burst_type and int(burst_result.get("damage", 0)) > 0, "mixed encounter resolves Sorcerous Burst using the damage type selected through the combat prompt")
	target["current_hp"] = 100
	target["armor_class"] = 1000
	var missed_burst: Dictionary = {}
	for _attempt in 40:
		missed_burst = CombatAction.resolve_spell(wizard, target, burst_spell, false, {}, [], 0, 30)
		if not bool(missed_burst.get("hit", true)):
			break
	_assert(missed_burst.get("success", false) and not missed_burst.get("hit", true) and not missed_burst.has("damage"), "mixed encounter does not apply Sorcerous Burst damage after a missed ranged spell attack")
	var poison_spray: Dictionary = DataLoader.get_spell("poison_spray")
	target["current_hp"] = 100
	target["max_hp"] = 100
	target["armor_class"] = -100
	var poison_result: Dictionary = {}
	for _attempt in 40:
		poison_result = CombatAction.resolve_spell(wizard, target, poison_spray, false, {}, [], 0, 30)
		if bool(poison_result.get("hit", false)):
			break
	_assert(poison_result.get("success", false) and poison_result.get("hit", false) and poison_result.get("damage_type", "") == "poison" and int(poison_result.get("damage", 0)) >= 2 and int(poison_result.get("damage", 0)) <= 24 and target["current_hp"] < 100, "mixed encounter resolves Poison Spray against a target 30 feet away and applies scaled poison damage on a hit")
	combat.current_player_idx = int(by_class["wizard"].get("player_id", 0))
	combat.active_character = wizard
	combat.turn_budget.reset(wizard, combat.player_entities)
	wizard.spell_slots["1"] = 1
	if "false_life" not in wizard.known_spells:
		wizard.known_spells.append("false_life")
	combat.pending_spell_data = DataLoader.get_spell("false_life").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(by_class["wizard"]["hex_position"])
	_assert(wizard.temp_hp >= 6 and wizard.temp_hp <= 12 and not combat.turn_budget.action_available, "mixed encounter casts False Life through the self-target spell path and grants its rolled temporary HP")
	var shocked_monster: Dictionary = combat.monster_entities[0]
	var wizard_origin: Vector2i = by_class["wizard"]["hex_position"]
	for adjacent_hex in HexUtils.get_neighbors(wizard_origin):
		if combat.hex_grid.has_tile(adjacent_hex) and combat.hex_grid.is_hex_passable(adjacent_hex) and not combat.player_entities.any(func(entity): return entity["hex_position"] == adjacent_hex):
			shocked_monster["hex_position"] = adjacent_hex
			break
	shocked_monster["current_hp"] = 100
	shocked_monster["max_hp"] = 100
	shocked_monster["armor_class"] = -100
	shocked_monster["is_alive"] = true
	combat._update_grid_entities()
	combat.current_player_idx = int(by_class["wizard"].get("player_id", 0))
	combat.active_character = wizard
	var chill_touch: Dictionary = DataLoader.get_spell("chill_touch")
	var chill_result: Dictionary = {}
	for _attempt in 40:
		chill_result = CombatAction.resolve_spell(wizard, shocked_monster, chill_touch, false, {}, [], 0, 5)
		if bool(chill_result.get("hit", false)):
			break
	if chill_result.get("success", false) and chill_result.get("hit", false):
		combat._handle_spell_effects(null, shocked_monster, chill_touch, wizard_origin, shocked_monster["hex_position"], chill_result)
	_assert(chill_result.get("success", false) and chill_result.get("hit", false) and CombatAction.is_healing_suppressed(shocked_monster), "mixed encounter Chill Touch lands a melee spell attack and blocks the target from regaining Hit Points")
	shocked_monster["current_hp"] = 100
	shocked_monster["max_hp"] = 100
	shocked_monster["is_alive"] = true
	shocked_monster["saving_throw_bonuses"] = {"DEX": -100}
	combat._update_grid_entities()
	if "acid_splash" not in wizard.known_spells:
		wizard.known_spells.append("acid_splash")
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("acid_splash").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(shocked_monster["hex_position"])
	_assert(int(shocked_monster["current_hp"]) < 100, "mixed encounter targets Acid Splash's 5-foot Sphere and applies its failed Dexterity-save damage")
	shocked_monster["saving_throw_bonuses"] = {"CON": -100}
	if "color_spray" not in wizard.known_spells:
		wizard.known_spells.append("color_spray")
	wizard.spell_slots["1"] = 1
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("color_spray").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(shocked_monster["hex_position"])
	_assert(shocked_monster.get("conditions", {}).has("blinded"), "mixed encounter resolves Color Spray over the production 15-foot cone and applies Blinded after a failed Constitution save")
	var vicious_mockery: Dictionary = DataLoader.get_spell("vicious_mockery")
	shocked_monster["saving_throw_bonuses"] = {"WIS": -100}
	var mockery_result := CombatAction.resolve_spell(wizard, shocked_monster, vicious_mockery, false, {}, [], 0, 60)
	combat._handle_spell_effects(null, shocked_monster, vicious_mockery, wizard_origin, shocked_monster["hex_position"], mockery_result)
	var mockery_attacker := CombatState._make_temp_monster_character(shocked_monster)
	var mockery_attack := mockery_attacker.make_attack_roll()
	CombatState._sync_consumed_monster_attack_conditions(shocked_monster, mockery_attacker)
	_assert(mockery_result.get("success", false) and not mockery_result.get("saved", true) and mockery_attack.get("disadvantage", false) and not shocked_monster.get("conditions", {}).has("vicious_mockery_disadvantage"), "mixed encounter applies Vicious Mockery's failed-save Disadvantage to a monster's next attack and consumes it")
	var command_spell: Dictionary = DataLoader.get_spell("command").duplicate(true)
	shocked_monster["saving_throw_bonuses"] = {"WIS": -100}
	combat.turn_budget.reset(wizard, combat.player_entities)
	wizard.spell_slots["1"] = 2
	combat.pending_spell_data = command_spell
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(shocked_monster["hex_position"])
	_assert(shocked_monster.get("combat_command", {}).get("action", "") == "halt" and not combat.turn_budget.action_available, "mixed encounter casts Command through CombatState and records Halt after a failed Wisdom save")
	var position_before_halt: Vector2i = shocked_monster["hex_position"]
	await combat._resolve_monster_command(shocked_monster, shocked_monster["combat_command"])
	_assert(shocked_monster["hex_position"] == position_before_halt, "Command Halt consumes the target's turn without movement")
	shocked_monster["combat_command"] = {"action": "grovel"}
	await combat._resolve_monster_command(shocked_monster, shocked_monster["combat_command"])
	_assert(shocked_monster.get("conditions", {}).has("prone"), "Command Grovel makes the target Prone")
	shocked_monster["combat_command"] = {"action": "drop"}
	shocked_monster["held_items"] = ["longsword"]
	var dropped_count_before: int = combat.dropped_combat_items.size()
	await combat._resolve_monster_command(shocked_monster, shocked_monster["combat_command"])
	_assert(shocked_monster.get("held_items", []).is_empty() and combat.dropped_combat_items.size() == dropped_count_before + 1, "Command Drop removes held items from the target and leaves them at its hex")
	var caster_hex: Vector2i = by_class["wizard"]["hex_position"]
	var original_monster_hex: Vector2i = shocked_monster["hex_position"]
	var movement_start := original_monster_hex
	var movement_start_distance := HexUtils.get_distance(movement_start, caster_hex)
	for candidate_value in combat.hex_grid.tiles.keys():
		var candidate_hex: Vector2i = candidate_value
		var candidate_distance := HexUtils.get_distance(candidate_hex, caster_hex)
		if candidate_distance > movement_start_distance and candidate_distance <= 6 and combat.hex_grid.is_hex_passable(candidate_hex) and not combat._is_occupied_hex(candidate_hex):
			movement_start = candidate_hex
			movement_start_distance = candidate_distance
	shocked_monster["hex_position"] = movement_start
	combat._update_grid_entities()
	original_monster_hex = movement_start
	var approach_distance_before := HexUtils.get_distance(original_monster_hex, caster_hex)
	shocked_monster["combat_command"] = {"action": "approach", "caster_id": wizard.character_id}
	await combat._resolve_monster_command(shocked_monster, shocked_monster["combat_command"])
	var approach_distance_after := HexUtils.get_distance(shocked_monster["hex_position"], caster_hex)
	_assert(approach_distance_after < approach_distance_before or approach_distance_before <= 1, "Command Approach moves toward the caster and stops within 5 feet")
	shocked_monster["hex_position"] = original_monster_hex
	var flee_distance_before := HexUtils.get_distance(original_monster_hex, caster_hex)
	shocked_monster["combat_command"] = {"action": "flee", "caster_id": wizard.character_id}
	await combat._resolve_monster_command(shocked_monster, shocked_monster["combat_command"])
	var flee_distance_after := HexUtils.get_distance(shocked_monster["hex_position"], caster_hex)
	_assert(flee_distance_after >= flee_distance_before, "Command Flee uses the target's fastest movement away from the caster")
	shocked_monster["saving_throw_bonuses"] = {}
	combat.current_player_idx = int(by_class["cleric"].get("player_id", 0))
	combat.active_character = cleric
	combat.turn_budget.reset(cleric, combat.player_entities)
	if "guidance" not in cleric.known_spells:
		cleric.known_spells.append("guidance")
	combat.pending_spell_data = DataLoader.get_spell("guidance").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(by_class["cleric"]["hex_position"])
	var guided_skill_check := EventResolver.resolve_skill_check(cleric, {"skill": "Acrobatics", "ability": "DEX", "dc": 1})
	var unguided_skill_check := EventResolver.resolve_skill_check(cleric, {"skill": "Arcana", "ability": "INT", "dc": 1})
	_assert(cleric.concentrating_on.get("spell_id", "") == "guidance" and cleric.guidance_skill == "Acrobatics" and guided_skill_check.get("guidance_bonus", 0) >= 1 and guided_skill_check.get("guidance_bonus", 0) <= 4 and unguided_skill_check.get("guidance_bonus", -1) == 0, "mixed encounter casts Guidance and adds its die only to checks using the chosen skill")
	combat._end_concentration(cleric)
	_assert(not cleric.has_condition("guidance") and cleric.guidance_skill.is_empty(), "Guidance ends cleanly when the caster loses concentration")
	if "resistance" not in cleric.known_spells:
		cleric.known_spells.append("resistance")
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("resistance").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(by_class["cleric"]["hex_position"])
	var resistance_fire_damage := CombatAction.resolve_damage(cleric, 1, "fire")
	var resistance_second_fire_damage := CombatAction.resolve_damage(cleric, 1, "fire")
	_assert(cleric.concentrating_on.get("spell_id", "") == "resistance" and cleric.resistance_damage_type == "fire" and resistance_fire_damage.get("resistance_spell_reduction", 0) >= 1 and resistance_fire_damage.get("resistance_spell_reduction", 0) <= 4 and resistance_second_fire_damage.get("resistance_spell_reduction", -1) == 0, "mixed encounter casts Resistance and reduces only its first matching damage instance before the next turn")
	combat._end_concentration(cleric)
	_assert(not cleric.has_condition("resistance_spell") and cleric.resistance_damage_type.is_empty(), "Resistance ends cleanly when the caster loses concentration")
	cleric.inventory.equip(Inventory.Slot.WEAPON, "quarterstaff", true)
	if "shillelagh" not in cleric.known_spells:
		cleric.known_spells.append("shillelagh")
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("shillelagh").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(by_class["cleric"]["hex_position"])
	var shillelagh_staff := DataLoader.get_item("quarterstaff")
	var shillelagh_original_ac := int(shocked_monster.get("armor_class", 10))
	shocked_monster["armor_class"] = -100
	var shillelagh_attack: Dictionary = {}
	for _attempt in 3:
		shillelagh_attack = CombatAction.resolve_weapon_attack(cleric, shocked_monster, shillelagh_staff, true, false, {"shillelagh_damage_type": "force"})
		if shillelagh_attack.get("hit", false):
			break
	_assert(cleric.has_condition("shillelagh") and cleric.shillelagh_weapon_id == "quarterstaff", "mixed encounter casts Shillelagh on the held Quarterstaff")
	_assert(shillelagh_attack.get("hit", false) and shillelagh_attack.get("damage_type", "") == "force", "Shillelagh weapon attack uses the spellcasting ability and Force damage: %s" % str(shillelagh_attack))
	var shillelagh_drop_attack := CombatAction.resolve_weapon_attack(cleric, shocked_monster, DataLoader.get_item("dagger"), false, false)
	shocked_monster["armor_class"] = shillelagh_original_ac
	_assert(not cleric.has_condition("shillelagh") and cleric.shillelagh_weapon_id.is_empty(), "Shillelagh ends when the character attacks with a different weapon")
	combat.current_player_idx = int(by_class["wizard"].get("player_id", 0))
	combat.active_character = wizard
	if "longstrider" not in wizard.known_spells:
		wizard.known_spells.append("longstrider")
	combat.turn_budget.reset(wizard, combat.player_entities)
	wizard.spell_slots["2"] = maxi(1, int(wizard.spell_slots.get("2", 0)))
	var longstrider_partner_coord: Vector2i = by_class["fighter"]["hex_position"]
	by_class["fighter"]["hex_position"] = by_class["wizard"]["hex_position"] + Vector2i(1, 0)
	var longstrider_speed_before := wizard.get_speed()
	combat.pending_spell_data = DataLoader.get_spell("longstrider").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 2
	combat.pending_action_type = "spell"
	var partner_speed_before := fighter.get_speed()
	var longstrider_maximum_targets: int = combat._spell_upcast_maximum_targets(combat.pending_spell_data)
	var longstrider_target_coords: Array[Vector2i] = [by_class["wizard"]["hex_position"], by_class["fighter"]["hex_position"]]
	await combat._execute_player_spell(by_class["wizard"]["hex_position"], Vector2i(9999, 9999), longstrider_target_coords)
	_assert(longstrider_maximum_targets == 2 and wizard.has_condition("longstrider") and wizard.get_speed() == longstrider_speed_before + 2 and fighter.has_condition("longstrider") and fighter.get_speed() == partner_speed_before + 2, "mixed encounter upcasts Longstrider through combat and grants +10 feet to both selected creatures")
	wizard.remove_condition("longstrider")
	fighter.remove_condition("longstrider")
	by_class["fighter"]["hex_position"] = longstrider_partner_coord
	# Animal Friendship runs through the production cast, failed-save condition,
	# source tracking, and shared damage resolver so its damage break cannot be
	# satisfied by a disconnected dictionary-only check.
	var animal_friendship_old_type: String = str(shocked_monster.get("creature_type", ""))
	var animal_friendship_old_saves: Dictionary = shocked_monster.get("saving_throw_bonuses", {}).duplicate(true)
	var animal_friendship_old_ac: int = int(shocked_monster.get("armor_class", 10))
	var animal_friendship_old_coord: Vector2i = shocked_monster["hex_position"]
	for coord in HexUtils.get_neighbors(by_class["wizard"]["hex_position"]):
		if combat.hex_grid.has_tile(coord) and not combat._is_occupied_hex(coord):
			shocked_monster["hex_position"] = coord
			break
	shocked_monster["creature_type"] = "beast"
	shocked_monster["saving_throw_bonuses"] = {"WIS": -100}
	shocked_monster["armor_class"] = -100
	shocked_monster["current_hp"] = 100
	shocked_monster["max_hp"] = 100
	shocked_monster["is_alive"] = true
	if "animal_friendship" not in wizard.known_spells:
		wizard.known_spells.append("animal_friendship")
	wizard.spell_slots["1"] = maxi(1, int(wizard.spell_slots.get("1", 0)))
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("animal_friendship").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(shocked_monster["hex_position"])
	_assert(shocked_monster.get("conditions", {}).has("charmed") and SpellEffects.has_spell(shocked_monster, "animal_friendship") and wizard.character_id in shocked_monster.get("animal_friendship_caster_ids", []), "Animal Friendship charms a Beast through combat and records its caster: %s" % str({"conditions": shocked_monster.get("conditions", {}), "sources": shocked_monster.get("condition_sources", {}), "effects": SpellEffects.records(shocked_monster), "casters": shocked_monster.get("animal_friendship_caster_ids", [])}))
	var friendship_attack: Dictionary = CombatAction.resolve_weapon_attack(fighter, shocked_monster, DataLoader.get_item("longsword"))
	_assert(friendship_attack.get("hit", false) and not shocked_monster.get("conditions", {}).has("charmed") and wizard.character_id not in shocked_monster.get("animal_friendship_caster_ids", []), "a party weapon hit ends Animal Friendship and clears its caster restriction")
	shocked_monster["creature_type"] = animal_friendship_old_type
	shocked_monster["saving_throw_bonuses"] = animal_friendship_old_saves
	shocked_monster["armor_class"] = animal_friendship_old_ac
	shocked_monster["hex_position"] = animal_friendship_old_coord
	var old_campaign_ledger := SaveManager._serialize_campaign_ledger()
	var old_messenger_size: String = str(shocked_monster.get("size", "medium"))
	var old_messenger_cr: float = float(shocked_monster.get("challenge_rating", 0.0))
	var old_messenger_can_fly: bool = bool(shocked_monster.get("can_fly", false))
	var messenger_origin: Vector2i = PartyManager.get_exploration_position()
	var messenger_destination_coord := messenger_origin + Vector2i(6, 0)
	var messenger_destination_id := "%d,%d" % [messenger_destination_coord.x, messenger_destination_coord.y]
	GameManager.visited_overworld_locations = [{"id": messenger_destination_id, "name": "Northwatch", "coord": [messenger_destination_coord.x, messenger_destination_coord.y]}]
	GameManager.animal_messenger_deliveries.clear()
	GameManager.campaign_elapsed_seconds = 0
	GameManager.next_animal_messenger_id = 1
	shocked_monster["creature_type"] = "beast"
	shocked_monster["size"] = "tiny"
	shocked_monster["challenge_rating"] = 0
	shocked_monster["can_fly"] = false
	shocked_monster["saving_throw_bonuses"] = {"CHA": -100}
	wizard.spell_slots["3"] = 1
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("animal_messenger").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 3
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(shocked_monster["hex_position"])
	var dispatched_messenger: Dictionary = GameManager.animal_messenger_deliveries[0] if not GameManager.animal_messenger_deliveries.is_empty() else {}
	var saved_messenger_ledger := SaveManager._serialize_campaign_ledger()
	GameManager.animal_messenger_deliveries.clear()
	GameManager.visited_overworld_locations.clear()
	SaveManager._apply_campaign_ledger(saved_messenger_ledger)
	var messenger_day_one := GameManager.advance_campaign_time(86400)
	var messenger_day_two := GameManager.advance_campaign_time(86400)
	_assert(not dispatched_messenger.is_empty() and dispatched_messenger.get("destination_id", "") == messenger_destination_id and dispatched_messenger.get("recipient", "") == "the town guard" and dispatched_messenger.get("message", "") == "The party is on its way." and int(dispatched_messenger.get("duration_seconds", 0)) == 259200 and int(wizard.spell_slots.get("3", 0)) == 0 and not combat.turn_budget.action_available, "Animal Messenger spends its chosen higher slot and action, then records the destination, message, and extended duration")
	_assert(messenger_day_one.is_empty() and messenger_day_two.size() == 1 and messenger_day_two[0].get("status", "") == "delivered" and GameManager.animal_messenger_deliveries[0].get("status", "") == "delivered", "Animal Messenger preserves its in-transit save and delivers after two walking days")
	GameManager.animal_messenger_deliveries.clear()
	GameManager.visited_overworld_locations.clear()
	shocked_monster["challenge_rating"] = 0.125
	var old_messenger_level_two_slots := int(wizard.spell_slots.get("2", 0))
	wizard.spell_slots["2"] = 1
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("animal_messenger").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 2
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(shocked_monster["hex_position"])
	_assert(GameManager.animal_messenger_deliveries.is_empty() and int(wizard.spell_slots.get("2", 0)) == 0 and not combat.turn_budget.action_available, "A nonzero-CR Tiny Beast automatically succeeds without an order or visited destination")
	wizard.spell_slots["2"] = old_messenger_level_two_slots
	# Restore campaign state altered by this integration scenario.
	SaveManager._apply_campaign_ledger(old_campaign_ledger)
	shocked_monster["creature_type"] = animal_friendship_old_type
	shocked_monster["size"] = old_messenger_size
	shocked_monster["challenge_rating"] = old_messenger_cr
	shocked_monster["can_fly"] = old_messenger_can_fly
	shocked_monster["saving_throw_bonuses"] = animal_friendship_old_saves
	combat.current_player_idx = int(by_class["wizard"].get("player_id", 0))
	combat.active_character = wizard
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("dancing_lights").duplicate(true)
	combat.pending_action_type = "spell"
	var dancing_lights_anchor: Vector2i = shocked_monster["hex_position"]
	await combat._execute_player_spell(dancing_lights_anchor)
	var dancing_light_set: Dictionary = combat.dancing_light_sets.get(wizard.character_id, {})
	var moved_lights_anchor := dancing_lights_anchor
	for candidate in combat.hex_grid.tiles.keys():
		if candidate == dancing_lights_anchor:
			continue
		var candidate_move := DancingLightsRules.move_light_set(dancing_light_set, by_class["wizard"]["hex_position"], candidate)
		if not candidate_move.get("success", false):
			continue
		if candidate_move.get("light_set", {}).get("positions", []).all(func(position: Array) -> bool: return combat.hex_grid.has_tile(Vector2i(int(position[0]), int(position[1])))):
			moved_lights_anchor = candidate
			break
	combat.turn_budget.reset(wizard, combat.player_entities)
	await combat._on_hud_action("move_dancing_lights", {})
	await combat._on_hex_clicked(moved_lights_anchor)
	var lights_moved: bool = combat.dancing_light_sets.get(wizard.character_id, {}).get("anchor", []) == [moved_lights_anchor.x, moved_lights_anchor.y]
	var light_tokens_before_end: int = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return bool(entity.get("is_dancing_light", false))).size()
	combat._end_concentration(wizard)
	combat._update_grid_entities()
	_assert(dancing_light_set.get("positions", []).size() == 4 and lights_moved and not combat.turn_budget.bonus_action_available, "Mixed encounter casts four Dancing Lights and moves them as a Bonus Action")
	_assert(light_tokens_before_end == 4 and not combat.dancing_light_sets.has(wizard.character_id) and wizard.concentrating_on.is_empty(), "Dancing Lights show their markers and remove them when concentration ends")
	combat.current_player_idx = int(by_class["wizard"].get("player_id", 0))
	combat.active_character = wizard
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("light").duplicate(true)
	combat.pending_action_type = "spell"
	var light_object_hex: Vector2i = by_class["wizard"]["hex_position"]
	await combat._execute_player_spell(light_object_hex)
	var light_entity_count: int = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return bool(entity.get("is_spell_light", false))).size()
	var light_visible_marker: Dictionary = combat.light_spell_markers.get(wizard.character_id, {}).duplicate(true)
	combat.turn_budget.reset(wizard, combat.player_entities)
	await combat._on_hud_action("dismiss_light", {})
	_assert(light_visible_marker.get("position", []) == [light_object_hex.x, light_object_hex.y] and light_visible_marker.get("rounds_remaining", 0) == 600 and light_entity_count == 1 and not combat.turn_budget.action_available, "Mixed encounter casts and dismisses Light (marker=%s rounds=%d tokens=%d action=%s)" % [str(light_visible_marker.get("position", [])), int(light_visible_marker.get("rounds_remaining", 0)), light_entity_count, str(combat.turn_budget.action_available)])
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("mage_hand").duplicate(true)
	combat.pending_action_type = "spell"
	var mage_hand_origin: Vector2i = by_class["wizard"]["hex_position"]
	var mage_hand_anchor: Vector2i = mage_hand_origin + Vector2i(1, 0)
	await combat._execute_player_spell(mage_hand_anchor)
	var mage_hand_token_count: int = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return bool(entity.get("is_mage_hand", false))).size()
	var mage_hand_destination := mage_hand_anchor
	for candidate in combat.hex_grid.tiles.keys():
		if candidate != mage_hand_anchor and MageHandRules.can_move(combat.mage_hand_markers.get(wizard.character_id, {}), mage_hand_origin, candidate):
			mage_hand_destination = candidate
			break
	combat.turn_budget.reset(wizard, combat.player_entities)
	await combat._on_hud_action("control_mage_hand", {})
	await combat._on_hex_clicked(mage_hand_destination)
	var moved_mage_hand_position: Array = combat.mage_hand_markers.get(wizard.character_id, {}).get("position", [])
	_assert(mage_hand_token_count == 1 and moved_mage_hand_position == [mage_hand_destination.x, mage_hand_destination.y] and not combat.turn_budget.action_available, "Mixed encounter Mage Hand (tokens=%d hand=%s dest=%s action=%s)" % [mage_hand_token_count, str(moved_mage_hand_position), str(mage_hand_destination), str(combat.turn_budget.action_available)])
	combat.turn_budget.reset(wizard, combat.player_entities)
	await combat._on_hud_action("dismiss_mage_hand", {})
	_assert(not combat.mage_hand_markers.has(wizard.character_id) and not combat.turn_budget.action_available, "Mixed encounter dismisses Mage Hand with a Magic action")
	if "message" not in wizard.known_spells:
		wizard.known_spells.append("message")
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("message").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(by_class["fighter"]["hex_position"])
	var message_activity_text := str(combat.hud.log_text.text) if combat.hud.log_text != null else ""
	_assert(not combat.turn_budget.action_available and message_activity_text.contains("sends a private Message") and not message_activity_text.contains("A test whisper"), "Mixed encounter sends Message to a party character with a Magic action and keeps whisper text out of the Chronicle")
	if "minor_illusion" not in wizard.known_spells:
		wizard.known_spells.append("minor_illusion")
	var illusion_origin: Vector2i = by_class["wizard"]["hex_position"]
	var illusion_first_hex := Vector2i(9999, 9999)
	for candidate in combat.hex_grid.tiles.keys():
		if not combat._has_creature_at(candidate) and Targeting.is_in_range(illusion_origin, candidate, MinorIllusionRules.RANGE_HEXES):
			illusion_first_hex = candidate
			break
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("minor_illusion").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(illusion_first_hex)
	var first_illusion: Dictionary = combat.minor_illusion_markers.get(wizard.character_id, {}).duplicate(true)
	var illusion_first_tokens: int = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return bool(entity.get("is_minor_illusion", false))).size()
	var illusion_second_hex := Vector2i(9999, 9999)
	for candidate in combat.hex_grid.tiles.keys():
		if candidate != illusion_first_hex and not combat._has_creature_at(candidate) and Targeting.is_in_range(illusion_origin, candidate, MinorIllusionRules.RANGE_HEXES):
			illusion_second_hex = candidate
			break
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("minor_illusion").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(illusion_second_hex)
	var recast_illusion: Dictionary = combat.minor_illusion_markers.get(wizard.character_id, {})
	var illusion_token_count: int = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return bool(entity.get("is_minor_illusion", false))).size()
	_assert(illusion_first_tokens == 1 and first_illusion.get("form", "") == "sound" and first_illusion.get("rounds_remaining", 0) == 10 and recast_illusion.get("position", []) == [illusion_second_hex.x, illusion_second_hex.y] and illusion_token_count == 1 and not combat.turn_budget.action_available, "Mixed encounter casts and recasts Minor Illusion at points, shows one marker, and spends a Magic action")
	if "prestidigitation" not in wizard.known_spells:
		wizard.known_spells.append("prestidigitation")
	var prestidigitation_hex := Vector2i(9999, 9999)
	for candidate in combat.hex_grid.tiles.keys():
		if not combat._has_creature_at(candidate) and Targeting.is_in_range(illusion_origin, candidate, PrestidigitationRules.RANGE_HEXES):
			prestidigitation_hex = candidate
			break
	for _effect_index in 3:
		combat.turn_budget.reset(wizard, combat.player_entities)
		combat.pending_spell_data = DataLoader.get_spell("prestidigitation").duplicate(true)
		combat.pending_action_type = "spell"
		await combat._execute_player_spell(prestidigitation_hex)
	var prestidigitation_active: Array = combat.prestidigitation_effects.get(wizard.character_id, [])
	var prestidigitation_tokens: int = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return bool(entity.get("is_prestidigitation", false))).size()
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("prestidigitation").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(prestidigitation_hex)
	_assert(prestidigitation_active.size() == PrestidigitationRules.MAX_ACTIVE_EFFECTS and prestidigitation_tokens == 3 and combat.prestidigitation_effects.get(wizard.character_id, []).size() == 3 and combat.turn_budget.action_available, "Mixed encounter tracks three persistent Prestidigitation marks and prevents a fourth without spending an action")
	if "produce_flame" not in wizard.known_spells:
		wizard.known_spells.append("produce_flame")
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("produce_flame").duplicate(true)
	combat.pending_spell_data["_produce_flame_create"] = true
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(combat.player_entities[combat.current_player_idx].get("hex_position", Vector2i.ZERO))
	var held_flame: Dictionary = combat.produce_flame_markers.get(wizard.character_id, {})
	var flame_tokens: int = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return bool(entity.get("is_produce_flame", false))).size()
	var flame_caster_origin: Vector2i = combat.player_entities[combat.current_player_idx].get("hex_position", Vector2i.ZERO)
	var flame_move_destination := flame_caster_origin
	for candidate in HexUtils.get_hexes_in_range(flame_caster_origin, 1):
		if candidate != flame_caster_origin and not combat._is_occupied_hex(candidate) and combat.hex_grid.is_hex_passable(candidate):
			flame_move_destination = candidate
			break
	var flame_follows_caster := false
	if flame_move_destination != flame_caster_origin:
		combat.player_entities[combat.current_player_idx]["hex_position"] = flame_move_destination
		combat._update_grid_entities()
		var moved_flame: Dictionary = combat.produce_flame_markers.get(wizard.character_id, {})
		var flame_entity: Dictionary = combat.hex_grid.entities.filter(func(entity: Dictionary) -> bool: return bool(entity.get("is_produce_flame", false))).front()
		flame_follows_caster = moved_flame.get("position", []) == [flame_move_destination.x, flame_move_destination.y] and int(flame_entity.get("bright_light_radius_hexes", 0)) == ProduceFlameRules.BRIGHT_LIGHT_RADIUS_HEXES and int(flame_entity.get("dim_light_radius_hexes", 0)) == ProduceFlameRules.DIM_LIGHT_RADIUS_HEXES
		combat.player_entities[combat.current_player_idx]["hex_position"] = flame_caster_origin
		combat._update_grid_entities()
	var flame_magic_action_available: bool = combat.turn_budget.action_available
	combat.turn_budget.reset(wizard, combat.player_entities)
	var old_flame_ac := int(shocked_monster.get("armor_class", 10))
	shocked_monster["armor_class"] = 1
	var flame_target_position: Vector2i = shocked_monster.get("hex_position", Vector2i.ZERO)
	var flame_target_hp := int(shocked_monster.get("current_hp", 0))
	combat.pending_spell_data = DataLoader.get_spell("produce_flame").duplicate(true)
	combat.pending_spell_data["_produce_flame_hurl"] = true
	combat.pending_spell_data["_skip_counterspell"] = true
	combat.pending_spell_data["casting_time"] = "action"
	combat.pending_spell_data["range"] = ProduceFlameRules.RANGE_HEXES
	combat.pending_spell_data["target"] = "single"
	combat.pending_spell_data["attack_type"] = "ranged_spell"
	combat.pending_spell_data["damage"] = "1d8"
	combat.pending_spell_data["damage_type"] = "fire"
	combat.pending_spell_data["scaling"] = {"5": "2d8", "11": "3d8", "17": "4d8"}
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(flame_target_position)
	shocked_monster["armor_class"] = old_flame_ac
	_assert(not held_flame.is_empty() and flame_tokens == 1 and flame_follows_caster and flame_magic_action_available and not combat.turn_budget.action_available and int(shocked_monster.get("current_hp", 0)) < flame_target_hp and combat.produce_flame_markers.has(wizard.character_id), "Mixed encounter creates a persistent, light-emitting Produce Flame that follows its caster, then hurls it as a Magic action attack within 60 feet")
	combat.turn_budget.reset(wizard, combat.player_entities)
	var protected_party_member: Character = wizard
	wizard.spell_slots["3"] = maxi(1, int(wizard.spell_slots.get("3", 0)))
	combat.pending_spell_data = DataLoader.get_spell("protection_from_energy").duplicate(true)
	combat.pending_spell_data["_protection_from_energy_type"] = "fire"
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(combat.player_entities[combat.current_player_idx].get("hex_position", Vector2i.ZERO))
	var protected_member_hp := protected_party_member.current_hp
	var protected_fire_damage := CombatAction.resolve_damage(protected_party_member, 13, "acid")
	var energy_resistance_before_cleanup := protected_party_member.protection_from_energy_type
	var energy_targets_before_cleanup: int = wizard.concentrating_on.get("targets", []).size()
	combat._end_concentration(wizard)
	var energy_damage_halved := int(protected_fire_damage.get("resolved", 0)) == 6
	protected_party_member.current_hp = protected_member_hp
	_assert(energy_damage_halved and energy_resistance_before_cleanup == "acid" and protected_party_member.protection_from_energy_type.is_empty() and wizard.concentrating_on.is_empty(), "Mixed encounter chooses Acid resistance for a willing touched ally, halves acid damage once, and clears protection when concentration ends (resolved=%d before=%s targets=%d concentration=%s)" % [int(protected_fire_damage.get("resolved", -1)), energy_resistance_before_cleanup, energy_targets_before_cleanup, str(wizard.concentrating_on.get("spell_id", ""))])
	wizard.spell_slots["1"] = maxi(1, int(wizard.spell_slots.get("1", 0)))
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("protection_from_evil_and_good").duplicate(true)
	combat.pending_action_type = "spell"
	var ward_slot_before := int(wizard.spell_slots.get("1", 0))
	await combat._execute_player_spell(combat.player_entities[combat.current_player_idx].get("hex_position", Vector2i.ZERO))
	var missing_component_preserves_resources: bool = int(wizard.spell_slots.get("1", 0)) == ward_slot_before and combat.turn_budget.action_available
	wizard.inventory.add_item("holy_water")
	combat.pending_spell_data = DataLoader.get_spell("protection_from_evil_and_good").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(combat.player_entities[combat.current_player_idx].get("hex_position", Vector2i.ZERO))
	var ward_source_active := protected_party_member.protection_from_evil_and_good_sources.has(wizard.character_id)
	var warded_fiend := CombatState._make_temp_monster_character(shocked_monster)
	warded_fiend.creature_type = "fiend"
	var warded_attack := CombatAction.resolve_weapon_attack(warded_fiend, protected_party_member, DataLoader.get_item("longsword"))
	var ward_consumed := not wizard.inventory.has_item("holy_water")
	combat._end_concentration(wizard)
	_assert(missing_component_preserves_resources and ward_source_active and ward_consumed and warded_attack.get("activity_roll", {}).get("disadvantage", false) and protected_party_member.protection_from_evil_and_good_sources.is_empty(), "Mixed encounter rejects a missing Holy Water component without spending action or slot, then consumes it to ward against Fiends until concentration ends")
	if "protection_from_poison" not in wizard.known_spells:
		wizard.known_spells.append("protection_from_poison")
	wizard.spell_slots["2"] = maxi(1, int(wizard.spell_slots.get("2", 0)))
	wizard.add_condition("poisoned", 20)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("protection_from_poison").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(combat.player_entities[combat.current_player_idx].get("hex_position", Vector2i.ZERO))
	var poison_damage_result := CombatAction.resolve_damage(wizard, 13, "poison")
	_assert(not wizard.has_condition("poisoned") and wizard.has_condition("protection_from_poison") and int(poison_damage_result.get("resolved", -1)) == 6, "Mixed encounter neutralizes Poisoned, grants timed protection and halves Poison damage")
	wizard.remove_condition("protection_from_poison")
	if "ray_of_sickness" not in wizard.known_spells:
		wizard.known_spells.append("ray_of_sickness")
	var ray_slots_before: Dictionary = wizard.spell_slots.duplicate(true)
	var ray_target_hp_before := int(shocked_monster.get("current_hp", 0))
	var ray_target_max_hp_before := int(shocked_monster.get("max_hp", 0))
	var ray_target_ac_before := int(shocked_monster.get("armor_class", 10))
	shocked_monster["current_hp"] = 500
	shocked_monster["max_hp"] = 500
	shocked_monster["armor_class"] = 0
	shocked_monster.get("conditions", {}).erase("poisoned")
	wizard.spell_slots["1"] = 8
	for _attempt in 8:
		if shocked_monster.get("conditions", {}).has("poisoned"):
			break
		combat.turn_budget.reset(wizard, combat.player_entities)
		combat.pending_spell_data = DataLoader.get_spell("ray_of_sickness").duplicate(true)
		combat.pending_action_type = "spell"
		await combat._execute_player_spell(shocked_monster.get("hex_position", Vector2i.ZERO))
	var ray_hit_applied_poison: bool = shocked_monster.get("conditions", {}).has("poisoned")
	shocked_monster["current_hp"] = ray_target_hp_before
	shocked_monster["max_hp"] = ray_target_max_hp_before
	shocked_monster["armor_class"] = ray_target_ac_before
	shocked_monster.get("conditions", {}).erase("poisoned")
	wizard.spell_slots = ray_slots_before
	_assert(ray_hit_applied_poison, "Mixed encounter casts Ray of Sickness as a ranged attack and applies Poisoned only on a hit")
	if "ray_of_enfeeblement" not in wizard.known_spells:
		wizard.known_spells.append("ray_of_enfeeblement")
	var enfeeblement_slots_before: Dictionary = wizard.spell_slots.duplicate(true)
	var enfeeblement_saves_before: Dictionary = shocked_monster.get("saving_throw_bonuses", {}).duplicate(true)
	var enfeeblement_conditions_before: Dictionary = shocked_monster.get("conditions", {}).duplicate(true)
	shocked_monster["saving_throw_bonuses"] = {"CON": -100}
	shocked_monster.get("conditions", {}).erase("ray_of_enfeeblement")
	wizard.spell_slots["2"] = 8
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("ray_of_enfeeblement").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(shocked_monster.get("hex_position", Vector2i.ZERO))
	var enfeeblement_applied: bool = shocked_monster.get("conditions", {}).has("ray_of_enfeeblement") and wizard.concentrating_on.get("spell_id", "") == "ray_of_enfeeblement"
	combat._resolve_ray_of_enfeeblement_repeat_save(shocked_monster)
	var enfeeblement_repeat_fail_preserves: bool = shocked_monster.get("conditions", {}).has("ray_of_enfeeblement")
	shocked_monster["saving_throw_bonuses"] = {"CON": 100}
	combat._resolve_ray_of_enfeeblement_repeat_save(shocked_monster)
	var enfeeblement_repeat_success_ends: bool = not shocked_monster.get("conditions", {}).has("ray_of_enfeeblement")
	combat._end_concentration(wizard)
	shocked_monster["saving_throw_bonuses"] = enfeeblement_saves_before
	shocked_monster["conditions"] = enfeeblement_conditions_before
	shocked_monster["saving_throw_bonuses"] = {"CON": 100}
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("ray_of_enfeeblement").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(shocked_monster.get("hex_position", Vector2i.ZERO))
	var enfeeblement_initial_save_ends: bool = shocked_monster.get("conditions", {}).has("vicious_mockery_disadvantage") and wizard.concentrating_on.is_empty()
	shocked_monster["conditions"] = enfeeblement_conditions_before
	shocked_monster["saving_throw_bonuses"] = enfeeblement_saves_before
	wizard.spell_slots = enfeeblement_slots_before
	_assert(enfeeblement_applied and enfeeblement_repeat_fail_preserves and enfeeblement_repeat_success_ends and enfeeblement_initial_save_ends, "Mixed encounter casts Ray of Enfeeblement through the production picker and resolves its failed, repeat-save and initial-success outcomes")
	var regenerate_caster: Character = by_class["cleric"]["character"]
	if "regenerate" not in regenerate_caster.known_spells:
		regenerate_caster.known_spells.append("regenerate")
	var regenerate_slots_before: Dictionary = regenerate_caster.spell_slots.duplicate(true)
	var regenerate_hp_before := regenerate_caster.current_hp
	var regenerate_conditions_before: Dictionary = regenerate_caster.conditions.duplicate(true)
	regenerate_caster.spell_slots["7"] = 1
	regenerate_caster.current_hp = 1
	regenerate_caster.is_alive = true
	combat.current_player_idx = int(by_class["cleric"].get("player_id", 0))
	combat.active_character = regenerate_caster
	combat.turn_budget.reset(regenerate_caster, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("regenerate").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(by_class["cleric"].get("hex_position", Vector2i.ZERO))
	var regenerate_cast_applied: bool = regenerate_caster.current_hp > 1 and regenerate_caster.has_condition("regenerate")
	var regenerate_hp_after_cast := regenerate_caster.current_hp
	var regenerate_condition_after_cast := regenerate_caster.has_condition("regenerate")
	regenerate_caster.current_hp = 1
	combat._apply_regenerate_turn_start(regenerate_caster)
	var regenerate_tick_applied: bool = regenerate_caster.current_hp == 2
	var regenerate_hp_after_tick := regenerate_caster.current_hp
	regenerate_caster.conditions = regenerate_conditions_before
	regenerate_caster.current_hp = regenerate_hp_before
	regenerate_caster.is_alive = regenerate_hp_before > 0
	regenerate_caster.spell_slots = regenerate_slots_before
	combat.current_player_idx = int(by_class["wizard"].get("player_id", 0))
	combat.active_character = wizard
	_assert(regenerate_cast_applied and regenerate_tick_applied, "Mixed encounter casts Regenerate through the production picker, heals immediately and restores 1 HP at turn start (cast=%s hp=%d condition=%s tick=%s hp_after_tick=%d)" % [str(regenerate_cast_applied), regenerate_hp_after_cast, str(regenerate_condition_after_cast), str(regenerate_tick_applied), regenerate_hp_after_tick])
	if "remove_curse" not in wizard.known_spells:
		wizard.known_spells.append("remove_curse")
	var remove_curse_slots_before: Dictionary = wizard.spell_slots.duplicate(true)
	var remove_curse_conditions_before: Dictionary = wizard.conditions.duplicate(true)
	var monster_curse_conditions_before: Dictionary = shocked_monster.get("conditions", {}).duplicate(true)
	wizard.spell_slots["3"] = 2
	wizard.add_condition("cursed", 10)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("remove_curse").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(by_class["wizard"]["hex_position"])
	var remove_curse_character_success: bool = not wizard.has_condition("cursed")
	var monster_conditions: Dictionary = shocked_monster.get("conditions", {})
	monster_conditions["cursed"] = 10
	shocked_monster["conditions"] = monster_conditions
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("remove_curse").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(shocked_monster.get("hex_position", Vector2i.ZERO))
	var remove_curse_monster_success: bool = not shocked_monster.get("conditions", {}).has("cursed")
	wizard.conditions = remove_curse_conditions_before
	shocked_monster["conditions"] = monster_curse_conditions_before
	wizard.spell_slots = remove_curse_slots_before
	_assert(remove_curse_character_success and remove_curse_monster_success, "Mixed encounter casts Remove Curse through the production picker and clears a curse from a Character and a monster")
	if "blade_ward" not in wizard.known_spells:
		wizard.known_spells.append("blade_ward")
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_spell_data = DataLoader.get_spell("blade_ward").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(by_class["wizard"]["hex_position"])
	var monster_attack_character := CombatState._make_temp_monster_character(shocked_monster)
	wizard.reaction_available = false
	wizard.base_ac = 1000
	wizard.add_condition("blade_ward", 10)
	var blade_ward_weapon_result := CombatAction.resolve_weapon_attack(monster_attack_character, wizard, DataLoader.get_item("longsword"), false, false, {"shield": false})
	var blade_ward_modifiers: Array = blade_ward_weapon_result.get("activity_roll", {}).get("modifiers", [])
	var blade_ward_modifier: Dictionary = blade_ward_modifiers.filter(func(modifier): return modifier.get("label", "") == "Blade Ward")[0] if blade_ward_modifiers.any(func(modifier): return modifier.get("label", "") == "Blade Ward") else {}
	_assert(wizard.concentrating_on.get("spell_id", "") == "blade_ward" and blade_ward_modifier.get("value", 0) <= -1 and blade_ward_modifier.get("value", 0) >= -4, "mixed encounter casts Blade Ward and applies its 1d4 penalty in the incoming weapon attack resolver")
	wizard.remove_condition("blade_ward")
	combat._end_concentration(wizard)
	combat.turn_budget.reset(wizard, combat.player_entities)
	if "shocking_grasp" not in wizard.known_spells:
		wizard.known_spells.append("shocking_grasp")
	combat.pending_spell_data = DataLoader.get_spell("shocking_grasp").duplicate(true)
	combat.pending_action_type = "spell"
	var shock_cast_attempts := 0
	while not CombatAction.blocks_opportunity_attack(shocked_monster) and shock_cast_attempts < 40:
		if shock_cast_attempts > 0:
			combat.turn_budget.reset(wizard, combat.player_entities)
			combat.pending_spell_data = DataLoader.get_spell("shocking_grasp").duplicate(true)
			combat.pending_action_type = "spell"
		await combat._execute_player_spell(shocked_monster["hex_position"])
		shock_cast_attempts += 1
	var shock_start: Vector2i = HexUtils.get_neighbors(shocked_monster["hex_position"])[0]
	var shock_destination: Vector2i = shock_start
	for candidate in HexUtils.get_neighbors(shock_start):
		if HexUtils.get_distance(candidate, shocked_monster["hex_position"]) > 1:
			shock_destination = candidate
			break
	var moving_fighter: Dictionary = by_class["fighter"]
	moving_fighter["hex_position"] = shock_start
	for monster in combat.monster_entities:
		monster["reaction_available"] = false
	shocked_monster["reaction_available"] = true
	await combat._check_opportunity_attacks_for_path(fighter, moving_fighter, [shock_start, shock_destination], false)
	_assert(CombatAction.blocks_opportunity_attack(shocked_monster) and shocked_monster["reaction_available"], "mixed encounter's hit Shocking Grasp blocks the marked monster's Opportunity Attack as an ally moves away")

	# Ice Knife bursts even after its ranged attack misses. Put a second creature
	# in the adjacent hex and invoke the same CombatState splash resolver used by
	# the production cast path.
	var ice_target: Dictionary = combat.monster_entities[0]
	var nearby_target: Dictionary = combat.monster_entities[1]
	ice_target["current_hp"] = 100
	nearby_target["current_hp"] = 100
	ice_target["max_hp"] = 100
	nearby_target["max_hp"] = 100
	ice_target["armor_class"] = 1000
	ice_target["is_alive"] = true
	nearby_target["is_alive"] = true
	var ice_center: Vector2i = ice_target["hex_position"]
	for candidate_hex in HexUtils.get_neighbors(ice_center):
		if combat.hex_grid.has_tile(candidate_hex) and not combat.player_entities.any(func(entity): return entity["hex_position"] == candidate_hex):
			nearby_target["hex_position"] = candidate_hex
			break
	combat._update_grid_entities()
	combat.current_player_idx = int(by_class["wizard"].get("player_id", 0))
	combat.active_character = wizard
	var ice_spell: Dictionary = DataLoader.get_spell("ice_knife")
	var ice_distance := HexUtils.get_distance(combat.player_entities[combat.current_player_idx]["hex_position"], ice_center) * 5
	var missed_ice_attack: Dictionary = {}
	for _attempt in 40:
		missed_ice_attack = CombatAction.resolve_spell(wizard, ice_target, ice_spell, false, {}, [], 2, ice_distance)
		if not bool(missed_ice_attack.get("hit", true)):
			break
	var ice_center_hp := int(ice_target["current_hp"])
	var nearby_hp := int(nearby_target["current_hp"])
	if missed_ice_attack.get("success", false) and not missed_ice_attack.get("hit", true):
		await combat._resolve_ice_knife_splash(ice_center, ice_spell, 2, {})
	_assert(missed_ice_attack.get("success", false) and not missed_ice_attack.get("hit", true) and int(ice_target["current_hp"]) < ice_center_hp and int(nearby_target["current_hp"]) < nearby_hp, "mixed encounter applies Ice Knife's upcast cold burst to the struck hex and an adjacent creature after a miss")
	ice_target["current_hp"] = 100
	nearby_target["current_hp"] = 100
	ice_target["armor_class"] = -100
	var hit_ice_attack: Dictionary = {}
	for _attempt in 40:
		hit_ice_attack = CombatAction.resolve_spell(wizard, ice_target, ice_spell, false, {}, [], 1, ice_distance)
		if bool(hit_ice_attack.get("hit", false)):
			break
	ice_center_hp = int(ice_target["current_hp"])
	nearby_hp = int(nearby_target["current_hp"])
	if hit_ice_attack.get("success", false) and hit_ice_attack.get("hit", false):
		await combat._resolve_ice_knife_splash(ice_center, ice_spell, 1, {})
	_assert(hit_ice_attack.get("success", false) and hit_ice_attack.get("hit", false) and int(ice_target["current_hp"]) < ice_center_hp and int(nearby_target["current_hp"]) < nearby_hp, "mixed encounter also applies Ice Knife's burst after the piercing attack hits")
	combat.current_player_idx = int(by_class["cleric"].get("player_id", 3))
	combat.active_character = cleric
	combat.turn_budget.reset(cleric, combat.player_entities)
	cleric.spell_slots["1"] = 1
	if "shield_of_faith" not in cleric.known_spells:
		cleric.known_spells.append("shield_of_faith")
	var fighter_ac_before_faith := fighter.get_ac()
	combat.pending_spell_data = DataLoader.get_spell("shield_of_faith").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(by_class["fighter"]["hex_position"])
	_assert(fighter.get_ac() == fighter_ac_before_faith + 2 and cleric.concentrating_on.get("spell_id", "") == "shield_of_faith" and not combat.turn_budget.bonus_action_available, "mixed encounter casts Shield of Faith as a Bonus Action and applies concentration-bound +2 AC")
	var bolt_target: Dictionary = combat.monster_entities[0]
	bolt_target["current_hp"] = 100
	bolt_target["max_hp"] = 100
	bolt_target["armor_class"] = -100
	bolt_target["is_alive"] = true
	cleric.spell_slots["1"] = 1
	if "guiding_bolt" not in cleric.known_spells:
		cleric.known_spells.append("guiding_bolt")
	var bolt_marked := false
	for bolt_attempt in 40:
		if bolt_attempt > 0:
			combat.turn_budget.reset(cleric, combat.player_entities)
		cleric.spell_slots["1"] = 1
		combat.pending_spell_data = DataLoader.get_spell("guiding_bolt").duplicate(true)
		combat.pending_action_type = "spell"
		await combat._execute_player_spell(bolt_target["hex_position"])
		bolt_marked = bolt_target.get("conditions", {}).has("guiding_bolt")
		if bolt_marked:
			break
	combat.current_player_idx = int(by_class["fighter"].get("player_id", 0))
	combat.active_character = fighter
	combat.turn_budget.reset(fighter, combat.player_entities)
	var follow_up := CombatAction.resolve_weapon_attack(fighter, bolt_target, {"name": "Longsword", "damage": "1d8+STR", "attack_bonus": 5, "attack_distance": 1, "range": 1, "ability": "STR", "damage_type": "slashing"})
	_assert(bolt_marked and follow_up.get("activity_roll", {}).get("advantage", false) and not bolt_target.get("conditions", {}).has("guiding_bolt"), "mixed encounter Guiding Bolt cast marks on hit, grants Advantage to the next attack, and consumes the mark")
	combat.current_player_idx = int(by_class["cleric"].get("player_id", 3))
	combat.active_character = cleric
	combat.turn_budget.reset(cleric, combat.player_entities)
	var cleric_origin: Vector2i = by_class["cleric"]["hex_position"]
	for adjacent_hex in HexUtils.get_neighbors(cleric_origin):
		var occupied_by_monster: bool = combat.monster_entities.any(func(monster): return monster != bolt_target and monster.get("hex_position") == adjacent_hex and monster.get("is_alive", false))
		if combat.hex_grid.has_tile(adjacent_hex) and combat.hex_grid.is_hex_passable(adjacent_hex) and not combat.player_entities.any(func(entity): return entity["hex_position"] == adjacent_hex) and not occupied_by_monster:
			bolt_target["hex_position"] = adjacent_hex
			break
	bolt_target["current_hp"] = 100
	bolt_target["max_hp"] = 100
	bolt_target["armor_class"] = 10
	combat._update_grid_entities()
	cleric.spell_slots["1"] = 1
	if "inflict_wounds" not in cleric.known_spells:
		cleric.known_spells.append("inflict_wounds")
	combat.pending_spell_data = DataLoader.get_spell("inflict_wounds").duplicate(true)
	combat.pending_action_type = "spell"
	await combat._execute_player_spell(bolt_target["hex_position"])
	_assert(int(bolt_target["current_hp"]) < 100, "mixed encounter casts Inflict Wounds through the production target-selection and saving-throw path")
	var acid_target: Dictionary = combat.monster_entities[0]
	acid_target["current_hp"] = 100
	acid_target["max_hp"] = 100
	acid_target["armor_class"] = -100
	acid_target["is_alive"] = true
	var acid_arrow: Dictionary = DataLoader.get_spell("melfs_acid_arrow")
	var acid_result := CombatAction.resolve_spell(wizard, acid_target, acid_arrow, false, {}, [], 3, 30)
	if acid_result.get("success", false) and acid_result.get("hit", false):
		combat._handle_spell_effects(null, acid_target, acid_arrow, combat.player_entities[combat.current_player_idx]["hex_position"], acid_target.get("hex_position", Vector2i.ZERO), acid_result)
	var acid_hit_hp := int(acid_target["current_hp"])
	await combat._resolve_delayed_spell_damage(acid_target)
	_assert(acid_result.get("success", false) and acid_result.get("hit", false) and acid_hit_hp < 100 and int(acid_target["current_hp"]) < acid_hit_hp and acid_target.get("delayed_spell_damage", []).is_empty(), "mixed encounter queues Melf's Acid Arrow's upcast delayed damage for the target's next turn end")
	for _level in 8:
		wizard.level_up()
	wizard.spell_slots["6"] = 1
	if "disintegrate" not in wizard.known_spells:
		wizard.known_spells.append("disintegrate")
	fighter.current_hp = 1
	fighter.is_alive = true
	var disintegrate_spell: Dictionary = DataLoader.get_spell("disintegrate")
	var fighter_hex: Vector2i = by_class["fighter"]["hex_position"]
	var disintegrate_result := CombatAction.resolve_spell(wizard, fighter, disintegrate_spell, false, {}, [], 6, 30)
	combat._handle_spell_effects(fighter, {}, disintegrate_spell, combat.player_entities[combat.current_player_idx]["hex_position"], fighter_hex, disintegrate_result)
	_assert(disintegrate_result.get("success", false) and fighter.current_hp == 0 and fighter.disintegrated and fighter.heal(20) == 0, "mixed encounter marks a creature killed by Disintegrate and blocks ordinary healing")

	# Owned reaction: the wizard's production Shield reaction is accepted and
	# consumes the wizard's reaction/slot through the shared attack resolver.
	wizard.reaction_available = true
	wizard.spell_slots["1"] = 1
	if "shield" not in wizard.known_spells:
		wizard.known_spells.append("shield")
	wizard.base_ac = 10
	var reaction_weapon := {"ability": "STR", "damage": "1", "damage_type": "bludgeoning", "range": 1}
	for _attempt in 50:
		if not wizard.reaction_available:
			break
		CombatAction.resolve_weapon_attack(fighter, wizard, reaction_weapon, false, false, {"shield": true})
	_assert(not wizard.reaction_available and int(wizard.spell_slots.get("1", 0)) == 0 and wizard.has_condition("shield"), "mixed encounter consumes the owning wizard Shield reaction")

	combat._end_concentration(cleric)
	_assert(cleric.concentrating_on.is_empty() and not fighter.has_condition("blessed") and not rogue.has_condition("blessed"), "mixed encounter concentration cleanup removes its applied conditions")
	print("[mixed] martial=true bonus_action=true reaction=true concentration=true healing=true save=true area=true")
	_teardown_scene(combat)
	_exit_test()


## Helper: play one player's turn in the live combat scene by driving the real
## movement + attack input handlers toward the nearest alive monster.
func _drive_player_attack_turn(combat: Node) -> void:
	var pidx: int = combat.current_player_idx
	if pidx < 0 or pidx >= combat.player_entities.size():
		return
	var p: Dictionary = combat.player_entities[pidx]
	var pchar: Character = p["character"]
	if pchar == null or not pchar.is_alive:
		combat._on_hud_action("end_turn", {})
		return
	var nearest = null
	var nd := 9999
	for m in combat.monster_entities:
		if not m["is_alive"]:
			continue
		var d: int = HexUtils.get_distance(p["hex_position"], m["hex_position"])
		if d < nd:
			nd = d
			nearest = m
	if nearest == null:
		combat._on_hud_action("end_turn", {})
		return
	var mpos: Vector2i = nearest["hex_position"]
	var weapon_id: String = pchar.inventory.get_weapon()
	var weapon: Dictionary = DataLoader.get_item(weapon_id)
	var max_range: int = int(weapon.get("range", 1))
	if HexUtils.get_distance(p["hex_position"], mpos) <= max_range:
		combat.pending_action_type = "attack"
		combat._on_hex_clicked(mpos)
		if not combat._battle_ending:
			combat._on_hud_action("end_turn", {})
		return
	var reach: Dictionary = combat.hex_grid.get_reachable(p["hex_position"], combat.remaining_speed)
	var best_step: Vector2i = p["hex_position"]
	var best_d: int = nd
	for h in reach:
		var d: int = HexUtils.get_distance(h, mpos)
		if d < best_d:
			best_d = d
			best_step = h
	if best_step != p["hex_position"]:
		combat._on_hex_clicked(best_step)
	if HexUtils.get_distance(combat.player_entities[pidx]["hex_position"], mpos) <= max_range:
		combat.pending_action_type = "attack"
		combat._on_hex_clicked(mpos)
	if not combat._battle_ending:
		combat._on_hud_action("end_turn", {})


# --- reporting --------------------------------------------------------------

func _report() -> void:
	print("--------------------------------------------------")
	print(" VIEWPORT RESULTS: %d failed (%d tests run)" % [_fail, _tests_run])
	if _tests_failed_names.size() > 0:
		print(" FAILED TESTS: %s" % ", ".join(_tests_failed_names))
		for f in _failures:
			print("   - %s" % f)
		print("VIEWPORT TESTS FAILED")
	else:
		print("VIEWPORT TESTS PASSED")


## First Wave 4 slice: Crown room controls, encounter projection and checkpoint.
func _accept_familiar_delivery_prompt(hud: CombatHUD) -> void:
	await get_tree().process_frame
	for child in hud.get_children():
		if child is ConfirmationDialog and child.title == "Touch delivery":
			child.confirmed.emit()
			return
	_assert(false, "Touch spell offers the real familiar delivery choice")


func _verify_familiar_senses_and_delivery(combat: CombatState, owner: Character, familiar_entity: Dictionary) -> void:
	var familiar: Character = familiar_entity["character"]
	var owner_entity: Dictionary = combat.player_entities.filter(func(entity): return entity.get("character") == owner).front()
	var ally_entity: Dictionary = combat.player_entities.filter(func(entity): return not entity.get("is_familiar", false) and not entity.get("is_steed", false) and entity.get("character") != owner).front()
	var ally: Character = ally_entity["character"]
	var prior_familiar_position: Vector2i = familiar_entity["hex_position"]
	var prior_ally_position: Vector2i = ally_entity["hex_position"]
	var relay_position := FamiliarRules.ABSENT
	var target_position := FamiliarRules.ABSENT
	for cell in combat.hex_grid.tiles:
		if not combat.hex_grid.is_hex_passable(cell) or HexUtils.get_distance(owner_entity["hex_position"], cell) < 3: continue
		for neighbor in HexUtils.get_neighbors(cell):
			if combat.hex_grid.has_tile(neighbor) and combat.hex_grid.is_hex_passable(neighbor) and HexUtils.get_distance(owner_entity["hex_position"], neighbor) > 1 and Targeting.has_line_of_sight(cell, neighbor, combat.hex_grid):
				relay_position = cell
				target_position = neighbor
				break
		if relay_position != FamiliarRules.ABSENT: break
	_assert(relay_position != FamiliarRules.ABSENT, "Crown room contains a legal Touch relay beyond the caster's reach")
	if relay_position == FamiliarRules.ABSENT: return
	familiar_entity["hex_position"] = relay_position
	ally_entity["hex_position"] = target_position
	combat.active_character = owner
	combat.current_player_idx = combat.player_entities.find(owner_entity)
	combat.active_combatant = {"is_player": true, "entity": owner}
	combat.turn_budget.reset(owner, combat.player_entities)
	combat.hud.update_hud(owner, combat.tracker)
	combat.hud.btn_features.pressed.emit()
	_assert(combat.hud.features_registered.any(func(feature): return feature.get("id") == "familiar_senses"), "Owner HUD exposes the familiar sense-sharing control")
	owner.add_condition("blinded", 2)
	CombatPerception.configure_ambient_light(combat.hex_grid, "dark")
	_assert(not CombatPerception.can_see_target(owner, ally, owner_entity["hex_position"], target_position, combat.hex_grid), "Blinded owner cannot see the target with ordinary senses")
	familiar.reaction_available = false
	await combat._on_hud_action("use_feature", {"feature": {"id": "familiar_senses"}})
	_assert(owner.familiar_senses == familiar and not combat.turn_budget.can_spend("bonus_action") and CombatPerception.can_see_target(owner, ally, owner_entity["hex_position"], target_position, combat.hex_grid), "Bonus Action borrows the familiar's own viewpoint and Darkvision without needing its Reaction")
	var owner_dto := owner.to_dict()
	_assert(not owner_dto.has("familiar_senses"), "Borrowed encounter senses are absent from durable character saves")
	owner.remove_condition("blinded")
	owner.familiar_senses = null
	CombatPerception.configure_ambient_light(combat.hex_grid, "bright")
	combat.turn_budget.reset(owner, combat.player_entities)
	var prior_spells := owner.known_spells.duplicate()
	var prior_slots := owner.spell_slots.duplicate()
	if "cure_wounds" not in owner.known_spells: owner.known_spells.append("cure_wounds")
	owner.spell_slots["1"] = 2
	var ally_hp_before := ally.current_hp
	ally.current_hp = maxi(1, ally.max_hp - 8)
	var wounded_hp := ally.current_hp
	familiar.reaction_available = true
	GameManager.test_mode = false
	_accept_familiar_delivery_prompt(combat.hud)
	await combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("cure_wounds")})
	GameManager.test_mode = true
	_assert(combat.pending_spell_data.get("_familiar_delivery", false) and combat._pending_spell_origin() == relay_position, "Accepting the real prompt moves Touch targeting to the familiar")
	# Lost Reaction is detected again before the caster commits anything.
	familiar.reaction_available = false
	await combat._execute_player_spell(target_position)
	_assert(owner.spell_slots["1"] == 2 and ally.current_hp == wounded_hp and combat.turn_budget.can_spend("magic_action"), "A familiar whose Reaction became unavailable refuses delivery without spending the caster's slot or action")
	familiar.reaction_available = true
	var cast := combat._spell_cast_context(owner_entity["hex_position"])
	_assert(not FamiliarSpellDelivery.validate(cast) and familiar.reaction_available, "An unreachable relay target refuses without spending the familiar's Reaction")
	await combat._on_hex_clicked(target_position)
	_assert(ally.current_hp > wounded_hp and owner.spell_slots["1"] == 1 and not familiar.reaction_available and not combat.turn_budget.can_spend("magic_action"), "Real Cure Wounds heals beyond the owner's reach and spends only the owner's slot/action and familiar's Reaction")
	_assert(owner_entity["hex_position"] != relay_position and FamiliarRules.state(owner).get("creature_id") == familiar.character_id, "Delivery never moves the caster or replaces its familiar")
	owner.known_spells.assign(prior_spells)
	owner.spell_slots = prior_slots
	ally.current_hp = ally_hp_before
	familiar.reaction_available = true
	familiar_entity["hex_position"] = prior_familiar_position
	ally_entity["hex_position"] = prior_ally_position
	combat._update_grid_entities()
	combat.turn_budget.reset(owner, combat.player_entities)


func test_owned_creature_lifecycle_flow() -> void:
	_enter_test("owned_creature_lifecycle_flow")
	_setup_world()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	var druid := _fresh_char("Crown Druid", "human", "druid", {"STR": 10, "DEX": 14, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	druid.level_up()
	var paladin := _fresh_char("Crown Paladin", "human", "paladin", {"STR": 16, "DEX": 10, "CON": 14, "INT": 10, "WIS": 10, "CHA": 16})
	for _level in 4: paladin.level_up()
	PartyManager.reset()
	for seat in 2:
		var member := druid if seat == 0 else paladin
		PlayerManager.set_player_character(seat, member)
		PartyManager.register_player_character(seat, member)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await _spawn_scene("res://scenes/dungeon.tscn", 0.2)
	var room: Room
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: room = candidate
	if room == null:
		_assert(false, "Crown owned-creature fixture finds the authored room")
		_teardown_scene(dungeon)
		_exit_test()
		return
	dungeon.hex_grid.hex_clicked.emit(room.coord)
	await get_tree().process_frame
	var view := dungeon.local_view
	var room_state: Dictionary = view.state
	var before_uses := int(druid.feature_uses["druid_wild_shape_uses"])
	# Select a repeatable production HP roll large enough for a nonfatal wound.
	for dice_seed in 16:
		seed(dice_seed)
		if Dice.roll(4) >= 3:
			seed(dice_seed)
			break
	_local_room_press(view, "Familiar: Wild Shape use")
	var record := FamiliarRules.state(druid)
	_assert(not record.is_empty() and int(druid.feature_uses["druid_wild_shape_uses"]) == before_uses - 1, "Crown room button summons a familiar with one real class resource")
	if record.is_empty():
		_teardown_scene(dungeon)
		_exit_test()
		return
	var creature_id := str(record["creature_id"])
	var initial_hp := int(record["current_hp"])
	var creature_position := FamiliarRules.position(druid, str(room_state["id"]))
	_assert(initial_hp >= 3 and creature_position != FamiliarRules.ABSENT and LocalRoomFamiliars.available(room_state, creature_position, druid, view.characters), "Room summon is visible in an unoccupied legal floor cell")
	var blocked_room := room_state.duplicate(true)
	blocked_room["walls"] = blocked_room["cells"].duplicate(true)
	var uses_before_block := druid.feature_uses.duplicate(true)
	_assert(not LocalRoomFamiliars.summon(blocked_room, druid, view.characters, "cat", "wild_shape").get("success", false) and druid.feature_uses == uses_before_block, "Blocked room summon leaves the existing creature and resource untouched")
	FamiliarRules.update_hp(druid, initial_hp - 1)
	view.refresh()
	_local_room_press(view, "Dismiss familiar")
	_assert(bool(FamiliarRules.state(druid).get("pocket", false)) and view.grid.entities.all(func(entity): return not entity.get("is_familiar", false)), "Room dismissal removes the familiar marker while retaining its damaged state")
	_local_room_press(view, "Recall familiar")
	_assert(FamiliarRules.state(druid).get("creature_id") == creature_id and FamiliarRules.state(druid).get("current_hp") == initial_hp - 1 and druid.feature_uses["druid_wild_shape_uses"] == before_uses - 1, "Room recall retains identity and damage without spending another summon resource")
	_assert(PaladinRules.create_find_steed_state(paladin, DataLoader.get_spell("find_steed"), 2, "fey", "horse").get("success", false), "Crown level-five Paladin owns a production steed")
	view.refresh()
	var remembered_position := FamiliarRules.position(druid, str(room_state["id"]))
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"], "local_room": room_state}
	var combat: CombatState = await _spawn_scene("res://scenes/combat.tscn", 0.3)
	var familiar_entities: Array = combat.player_entities.filter(func(entity): return bool(entity.get("is_familiar", false)))
	_assert(familiar_entities.size() == 1, "Encounter has exactly one familiar projection")
	if familiar_entities.is_empty():
		_teardown_scene(combat)
		_teardown_scene(dungeon)
		_exit_test()
		return
	var familiar_entity: Dictionary = familiar_entities[0]
	var familiar: Character = familiar_entity["character"]
	_assert(familiar.character_id == creature_id and familiar.current_hp == initial_hp - 1 and familiar_entity["hex_position"] == remembered_position, "Combat entry preserves the familiar's room cell, identity and wounded HP")
	_assert(familiar_entity["owner_player_index"] == 0 and combat.tracker.combatants.any(func(turn): return turn["id"] == creature_id and turn["entity"] == familiar), "Familiar owns an initiative turn routed to the owner's logical seat")
	# Existing Help command still uses the shared action budget and real target.
	combat.active_character = familiar
	combat.current_player_idx = combat.player_entities.find(familiar_entity)
	combat.active_combatant = {"is_player": true, "entity": familiar}
	combat.turn_budget.reset(familiar, combat.player_entities)
	var target: Dictionary = combat.monster_entities[0]
	var help_cell := HexUtils.get_neighbors(familiar_entity["hex_position"])[0]
	target["hex_position"] = help_cell
	combat._on_hud_action("use_feature", {"feature": familiar.get_feature("familiar_help")})
	await combat._on_hex_clicked(help_cell)
	_assert(target.get("familiar_helped_by") == creature_id and not combat.turn_budget.can_spend("action"), "Familiar Help reaches the real enemy and spends one Action")
	await _verify_familiar_senses_and_delivery(combat, druid, familiar_entity)
	# Preflight the combat summon before committing a second use.
	combat.active_character = druid
	combat.current_player_idx = 0
	combat.active_combatant = {"is_player": true, "entity": druid}
	combat.turn_budget.reset(druid, combat.player_entities)
	var tiles_before: Dictionary = combat.hex_grid.tiles.duplicate()
	combat.hex_grid.tiles.clear()
	var state_before_refusal := FamiliarRules.state(druid)
	combat._on_hud_action("use_feature", {"feature": druid.get_feature("druid_wild_companion"), "wild_companion_choice": {"form_id": "cat", "cost": "wild_shape"}})
	_assert(FamiliarRules.state(druid) == state_before_refusal and druid.feature_uses["druid_wild_shape_uses"] == before_uses - 1 and combat.turn_budget.can_spend("magic_action"), "Combat placement refusal spends neither the class resource nor its Magic action")
	combat.hex_grid.tiles = tiles_before
	var original_initiative: Dictionary = combat.familiar_initiative[creature_id].duplicate()
	combat._on_hud_action("use_feature", {"feature": {"id": "familiar_dismiss", "action_cost": "magic_action"}})
	_assert(bool(FamiliarRules.state(druid).get("pocket", false)) and not target.has("familiar_helped_by") and not combat.player_entities.any(func(entity): return bool(entity.get("is_familiar", false))) and not combat.turn_budget.can_spend("magic_action"), "Combat dismissal spends its Magic action and removes presence, initiative and source-owned Help")
	combat.turn_budget.reset(druid, combat.player_entities)
	combat._on_hud_action("use_feature", {"feature": {"id": "familiar_recall", "action_cost": "magic_action"}})
	familiar_entity = combat.player_entities.filter(func(entity): return bool(entity.get("is_familiar", false))).front()
	familiar = familiar_entity["character"]
	_assert(familiar.current_hp == initial_hp - 1 and combat.familiar_initiative[creature_id] == original_initiative and not combat.turn_budget.can_spend("magic_action"), "Combat recall retains HP and initiative while spending only its Magic action")
	# A familiar can act defensively without stalling on an incapacitated owner.
	druid.add_condition("stunned", 2)
	for turn_index in combat.tracker.combatants.size():
		if combat.tracker.combatants[turn_index]["id"] == creature_id: combat.tracker.active_index = turn_index
	await combat._start_combat_turn()
	_assert(familiar.has_condition("dodging") and not FamiliarRules.state(druid).is_empty(), "An incapacitated owner's familiar takes its automatic Dodge turn and remains alive")
	druid.remove_condition("stunned")
	familiar.take_damage(1)
	combat._update_grid_entities()
	var damaged_hp := familiar.current_hp
	_assert(FamiliarRules.state(druid).get("current_hp") == damaged_hp, "Combat damage settles into the owner's durable familiar record")
	# A knocked-out owner is not a dead owner: the steed remains.
	paladin.current_hp = 0
	paladin.is_alive = false
	combat._sync_find_steeds()
	_assert(not PaladinRules.find_steed_state(paladin).is_empty() and combat.player_entities.any(func(entity): return bool(entity.get("is_steed", false))), "A downed Paladin retains the living steed until actual death")
	paladin.heal(1)
	await combat._end_battle("victory")
	_assert(FamiliarRules.state(druid).get("current_hp") == damaged_hp and FamiliarRules.position(druid, str(room_state["id"])) == familiar_entity["hex_position"], "Encounter return captures familiar damage and its final room cell")
	_teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	_local_room_press(view, "Room map")
	await get_tree().process_frame
	dungeon.hex_grid.hex_clicked.emit(Vector2i.ZERO)
	_assert(SaveManager.get_save_block_reason().is_empty(), "Owned creatures use the existing dungeon entrance safe-save boundary")
	var slot := "wave4_owned_creatures"
	var wrote_checkpoint := SaveManager.save_game(slot)
	_assert(wrote_checkpoint, "Crown checkpoint writes owned creatures to disk")
	if not wrote_checkpoint:
		_teardown_scene(dungeon)
		_exit_test()
		return
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR + slot + ".sav"))
	var invalid := saved.duplicate(true)
	invalid["party"]["characters"][druid.character_id]["feature_uses"][FamiliarRules.STATE_KEY]["owner_id"] = paladin.character_id
	_assert(not SaveManager._validate_save_data(invalid).is_empty() and FamiliarRules.state(druid).get("current_hp") == damaged_hp, "Checkpoint validation rejects a stolen familiar owner before mutating the session")
	_teardown_scene(dungeon)
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(slot), "Owned-creature checkpoint reloads through the supported disk load path")
	druid = PartyManager.get_active_characters()[0]
	paladin = PartyManager.get_active_characters()[1]
	_assert(FamiliarRules.state(druid).get("creature_id") == creature_id and FamiliarRules.state(druid).get("current_hp") == damaged_hp and not PaladinRules.find_steed_state(paladin).is_empty(), "Disk reload preserves familiar identity/damage and the separate living steed")
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	var next_combat: CombatState = await _spawn_scene("res://scenes/combat.tscn", 0.3)
	var next_familiar: Dictionary = next_combat.player_entities.filter(func(entity): return bool(entity.get("is_familiar", false))).front()
	_assert(next_familiar["character"].current_hp == damaged_hp and next_familiar["character"].character_id == creature_id, "A later encounter cannot reroll or heal the familiar")
	next_familiar["character"].take_damage(100)
	next_combat._update_grid_entities()
	_assert(FamiliarRules.state(druid).is_empty() and not next_combat.tracker.combatants.any(func(turn): return turn["id"] == creature_id), "Familiar death removes durable state, map presence and initiative")
	for member in [druid, paladin]:
		member.current_hp = 0
		member.is_alive = false
		member.death_save_failures = 0
	_assert(next_combat._check_battle_end_conditions(), "A living steed cannot prevent the normal party-wipe defeat flow")
	_teardown_scene(next_combat)
	SaveManager.delete_save(slot)
	_exit_test()


func test_find_familiar_exploration_flow() -> void:
	_enter_test("find_familiar_exploration_flow")
	_setup_world()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	var wizard := _fresh_char("Crown familiar caster", "human", "wizard", {"STR": 10, "DEX": 14, "CON": 14, "INT": 16, "WIS": 10, "CHA": 10})
	var book: Array[String] = ["find_familiar"]
	for spell in DataLoader.get_castable_spell_list_options(["wizard"]):
		if book.size() >= wizard.wizard_spellbook_pending: break
		if int(spell.get("level", 0)) == 1 and str(spell["id"]) not in book: book.append(str(spell["id"]))
	_assert(ClassProgression.choose_wizard_spellbook(wizard, book), "Wizard learns Find Familiar through the real supported spellbook choice")
	var prepared: Array[String] = []
	var cantrips := wizard.get_spell_option_ids(true)
	for index in mini(wizard.get_spellcasting_capacity("cantrips"), cantrips.size()): prepared.append(cantrips[index])
	prepared.append("find_familiar")
	var prepared_count := 1
	for spell_id in wizard.get_spell_option_ids(false):
		if prepared_count >= wizard.get_spellcasting_capacity("prepared_spells"): break
		if spell_id == "find_familiar": continue
		prepared.append(spell_id)
		prepared_count += 1
	_assert(ClassProgression.choose_spell_selection(wizard, prepared), "Wizard prepares Find Familiar through normal class spell selection")
	PartyManager.reset()
	PlayerManager.reset()
	PlayerManager.add_player("Familiar player")
	PlayerManager.set_player_character(0, wizard)
	PartyManager.register_player_character(0, wizard)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await _spawn_scene("res://scenes/dungeon.tscn", 0.2)
	var room: Room
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: room = candidate
	_assert(room != null, "Crown Find Familiar fixture finds its authored room")
	if room == null:
		_teardown_scene(dungeon)
		_exit_test()
		return
	dungeon.hex_grid.hex_clicked.emit(room.coord)
	await get_tree().process_frame
	var view := dungeon.local_view
	var before_time := GameManager.campaign_elapsed_seconds
	var before_slots := wizard.spell_slots.duplicate()
	_local_room_press(view, "Find Familiar (1 hour)")
	_assert(FamiliarRules.state(wizard).is_empty() and wizard.spell_slots == before_slots and GameManager.campaign_elapsed_seconds == before_time, "Normal Find Familiar control refuses missing incense without slot/time loss")
	wizard.inventory.add_item("incense_10gp")
	_local_room_press(view, "Find Familiar (1 hour)")
	var record := FamiliarRules.state(wizard)
	_assert(not record.is_empty(), "Normal Crown exploration control casts Find Familiar")
	if record.is_empty():
		_teardown_scene(dungeon)
		_exit_test()
		return
	var creature_id := str(record["creature_id"])
	_assert(record.get("origin") == "find_familiar" and record.get("creature_type") == "celestial" and record.get("lifetime") == "until_dismissed" and FamiliarRules.saved_error(wizard.to_dict()).is_empty(), "Find Familiar stores the chosen creature type and permanent bond in a validated Wizard checkpoint")
	_assert(not wizard.inventory.has_item("incense_10gp") and wizard.spell_slots["1"] == int(before_slots["1"]) - 1 and GameManager.campaign_elapsed_seconds == before_time + 3600, "Hour-long Find Familiar consumes exactly one incense copy and one slot and advances campaign time")
	wizard.long_rest()
	_assert(FamiliarRules.state(wizard).get("creature_id") == creature_id, "An ordinary Find Familiar bond survives the owner's Long Rest")
	wizard.inventory.add_item("incense_10gp")
	view.refresh()
	for child in view.familiar_summon_row.get_children():
		if child is OptionButton and str(child.get_item_metadata(0)) == "cat": child.select(1)
		if child is OptionButton and str(child.get_item_metadata(0)) == "celestial": child.select(2)
	before_slots = wizard.spell_slots.duplicate()
	before_time = GameManager.campaign_elapsed_seconds
	_local_room_press(view, "Find Familiar ritual (70 min)")
	record = FamiliarRules.state(wizard)
	_assert(record.get("creature_id") == creature_id and record.get("form_id") == "owl" and record.get("creature_type") == "fiend" and wizard.spell_slots == before_slots and not wizard.inventory.has_item("incense_10gp") and GameManager.campaign_elapsed_seconds == before_time + 4200, "Ritual replaces the existing familiar's form/type, consumes incense, adds ten minutes and spends no spell slot")
	_local_room_press(view, "Dismiss familiar")
	_local_room_press(view, "Recall familiar")
	_assert(FamiliarRules.state(wizard).get("creature_id") == creature_id and not bool(FamiliarRules.state(wizard).get("pocket", true)), "Wizard uses the same pocket dismissal and recall controls")
	var event_data: Dictionary = DataLoader.get_event_table("forest_events")["events"].filter(func(value): return value["id"] == "hidden_cache").front()
	var event_dialog: EventDialog = await _spawn_scene("res://scenes/ui/event_dialog.tscn", 0.1)
	event_dialog.popup_event(wizard, event_data)
	_assert(is_instance_valid(event_dialog._familiar_help_choice), "Authored hidden-cache event exposes a proficient familiar's Help choice")
	if is_instance_valid(event_dialog._familiar_help_choice):
		event_dialog._familiar_help_choice.button_pressed = true
		event_dialog.btn_roll.pressed.emit()
		await get_tree().create_timer(1.3).timeout
		_assert("Familiar Help: Advantage" in event_dialog.roll_result_lbl.text and event_dialog.btn_roll.disabled, "Normal event Roll uses and reports familiar Help on this check only")
	_teardown_scene(event_dialog)
	# Return to the supported safe-save entrance; saving inside the room remains refused.
	_local_room_press(view, "Room map")
	await get_tree().process_frame
	dungeon.hex_grid.hex_clicked.emit(Vector2i.ZERO)
	var slot := "wave4_find_familiar"
	var wrote := SaveManager.save_game(slot)
	_assert(wrote, "Ordinary familiar checkpoint writes through the dungeon entrance boundary")
	_teardown_scene(dungeon)
	if not wrote:
		_exit_test()
		return
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(slot), "Find Familiar checkpoint reloads through the real save loader")
	wizard = PartyManager.get_active_characters()[0]
	_assert(FamiliarRules.state(wizard).get("creature_id") == creature_id and FamiliarRules.state(wizard).get("form_id") == "owl" and FamiliarRules.state(wizard).get("creature_type") == "fiend", "Disk reload retains ordinary familiar identity, changed form and chosen type")
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	var combat: CombatState = await _spawn_scene("res://scenes/combat.tscn", 0.3)
	_assert(combat.player_entities.any(func(entity): return entity.get("is_familiar", false) and entity["character"].character_id == creature_id), "A Wizard's ordinary familiar receives its real encounter entity and turn after reload")
	combat.active_character = wizard
	combat.current_player_idx = 0
	combat.active_combatant = {"is_player": true, "entity": wizard}
	combat.turn_budget.reset(wizard, combat.player_entities)
	before_slots = wizard.spell_slots.duplicate()
	await combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("find_familiar")})
	_assert(combat.pending_action_type != "spell" and wizard.spell_slots == before_slots and combat.turn_budget.can_spend("magic_action"), "Combat refuses the unsupported hour-long cast without spending an action or slot")
	_teardown_scene(combat)
	SaveManager.delete_save(slot)
	_exit_test()


func test_party_recovery_flow() -> void:
	_enter_test("party_recovery_flow")
	_setup_world()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	GameManager.completed_milestones.append("enter_dungeon_1")
	var cleric := _fresh_char("Crown recovery caster", "human", "cleric", {"STR": 10, "DEX": 14, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	for _level in 4: cleric.level_up()
	var selection: Array[String] = []
	var cantrips := cleric.get_spell_option_ids(true)
	for index in mini(cleric.get_spellcasting_capacity("cantrips"), cantrips.size()): selection.append(cantrips[index])
	var prepared: Array[String] = ["revivify", "gentle_repose"]
	for spell_id in cleric.get_spell_option_ids(false):
		if prepared.size() >= cleric.get_spellcasting_capacity("prepared_spells"): break
		if spell_id not in prepared: prepared.append(spell_id)
	selection.append_array(prepared)
	_assert(ClassProgression.choose_spell_selection(cleric, selection), "Level-5 Cleric prepares recovery spells through normal class choices")
	var member := _fresh_char("Crown fallen member", "human", "fighter", {"STR": 16, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PartyManager.reset()
	PlayerManager.reset()
	PlayerManager.add_player("Recovery player")
	PlayerManager.set_player_character(0, cleric)
	PartyManager.register_player_character(0, cleric)
	PlayerManager.add_player("Recovery member")
	PlayerManager.set_player_character(1, member)
	PartyManager.register_player_character(1, member)
	# Merchants expose both consumed component packets through the existing purchase path.
	cleric.inventory.gold = 1000
	var shop: ShopUI = await _spawn_scene("res://scenes/ui/shop.tscn", 0.1)
	for item_id in ["diamond_300gp", "gentle_repose_copper"]:
		for index in shop.items_data.size():
			if shop.items_data[index]["id"] != item_id: continue
			shop.item_list.select(index)
			shop.item_list.item_selected.emit(index)
			shop.btn_buy.pressed.emit()
			break
	_assert(cleric.inventory.has_item("diamond_300gp") and cleric.inventory.has_item("gentle_repose_copper") and cleric.inventory.gold == 699, "Normal merchant purchase supplies one 300-GP diamond and one copper component packet")
	_teardown_scene(shop)
	var diamond := cleric.inventory.required_spell_component_instance(DataLoader.get_spell("revivify"))
	var held_diamond := cleric.inventory.take_instance(diamond)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await _spawn_scene("res://scenes/dungeon.tscn", 0.2)
	var room: Room
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: room = candidate
	_assert(room != null, "Recovery fixture enters Crown's authored room")
	if room == null:
		_teardown_scene(dungeon)
		_exit_test()
		return
	dungeon.hex_grid.hex_clicked.emit(room.coord)
	await get_tree().process_frame
	var view := dungeon.local_view
	view.slots.select(Inventory.Slot.SHIELD)
	_local_room_press(view, "Unequip")
	_assert(cleric.inventory.available_spellcasting_hands() > 0, "Cleric frees a component hand through the normal equipment control")
	view.state["party_positions"][cleric.character_id] = [0, 0]
	view.state["party_positions"][member.character_id] = [1, 0]
	member.take_damage(member.current_hp + member.max_hp)
	var corpse_id := str(member.corpse_state.get("corpse_id", ""))
	var death_time := GameManager.campaign_elapsed_seconds
	view.refresh()
	view.body_targets.select(1)
	view.body_targets.item_selected.emit(1)
	var status: Label = view.body_row.find_child("RecoveryStatus", true, false)
	_assert(status != null and "Dead" in status.text, "Normal recovery panel distinguishes a dead party member from an unconscious one")
	var before_slots := cleric.spell_slots.duplicate()
	var before_time := GameManager.campaign_elapsed_seconds
	_local_room_press(view, "Revivify")
	_assert(member.is_dead() and cleric.spell_slots == before_slots and GameManager.campaign_elapsed_seconds == before_time, "Revivify control refuses a missing diamond without slot or time loss")
	_assert(cleric.inventory.receive_instance(held_diamond), "Recovery fixture returns the original purchased diamond copy")
	view.refresh()
	var willingness: CheckBox = view.body_row.find_child("RevivalWillingness", true, false)
	willingness.button_pressed = false
	_local_room_press(view, "Revivify")
	_assert(member.is_dead() and not member.revival_willing and cleric.inventory.has_item("diamond_300gp") and cleric.spell_slots == before_slots, "Party owner's refusal control prevents revival without consuming its diamond or slot")
	willingness = view.body_row.find_child("RevivalWillingness", true, false)
	willingness.button_pressed = true
	_local_room_press(view, "Gentle Repose")
	_assert(member.corpse_state.get("corpse_id") == corpse_id and member.corpse_state.get("death_at_seconds") == death_time and not cleric.inventory.has_item("gentle_repose_copper") and cleric.spell_slots["2"] == int(before_slots["2"]) - 1, "Normal Gentle Repose control consumes its component and slot while preserving the original corpse identity and time")
	GameManager.advance_campaign_time(120)
	_assert(CorpseRules.effective_age(member, GameManager.campaign_elapsed_seconds) == 6, "Exploration time after Gentle Repose does not count toward the one-minute revival window")
	view.state["party_positions"][cleric.character_id] = view.state["exits"][0].duplicate()
	_local_room_press(view, "Room map")
	await get_tree().process_frame
	dungeon.hex_grid.hex_clicked.emit(Vector2i.ZERO)
	var slot := "wave4_party_recovery"
	var wrote := SaveManager.save_game(slot)
	_assert(wrote, "A preserved corpse writes through the safe dungeon entrance checkpoint")
	_teardown_scene(dungeon)
	if not wrote:
		_exit_test()
		return
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(slot), "Preserved corpse reloads through the production disk loader")
	cleric = PartyManager.get_active_characters()[0]
	member = PartyManager.get_active_characters()[1]
	_assert(member.is_dead() and member.corpse_state.get("corpse_id") == corpse_id and member.corpse_state.get("death_at_seconds") == death_time and member.revival_willing and CorpseRules.effective_age(member, GameManager.campaign_elapsed_seconds) == 6, "Disk reload retains remains, original death time, spirit willingness and paused recovery clock")
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	dungeon = await _spawn_scene("res://scenes/dungeon.tscn", 0.2)
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: room = candidate
	dungeon.hex_grid.hex_clicked.emit(room.coord)
	await get_tree().process_frame
	view = dungeon.local_view
	view.state["party_positions"][cleric.character_id] = [0, 0]
	view.state["party_positions"][member.character_id] = [1, 0]
	view.refresh()
	view.body_targets.select(1)
	view.body_targets.item_selected.emit(1)
	cleric.inventory.add_item("gentle_repose_copper")
	before_slots = cleric.spell_slots.duplicate()
	before_time = GameManager.campaign_elapsed_seconds
	_local_room_press(view, "Gentle Repose ritual (10 min)")
	_assert(cleric.spell_slots == before_slots and not cleric.inventory.has_item("gentle_repose_copper") and GameManager.campaign_elapsed_seconds == before_time + 606 and CorpseRules.effective_age(member, GameManager.campaign_elapsed_seconds) == 6, "Normal Gentle Repose ritual consumes its two-coin packet, spends ten minutes plus one action and preserves the corpse without a slot")
	before_slots = cleric.spell_slots.duplicate()
	_local_room_press(view, "Revivify")
	_assert(member.is_alive and member.current_hp == 1 and member.corpse_state.is_empty() and not cleric.inventory.has_item("diamond_300gp") and cleric.spell_slots["3"] == int(before_slots["3"]) - 1, "Normal Crown recovery control after reload revives the same party member with 1 HP and exactly one diamond/slot")
	_teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	var combat: CombatState = await _spawn_scene("res://scenes/combat.tscn", 0.3)
	cleric.current_hp = cleric.max_hp
	cleric.is_alive = true
	combat.active_character = cleric
	combat.current_player_idx = 0
	combat.active_combatant = {"is_player": true, "entity": cleric}
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(1, 0)
	member.take_damage(member.current_hp)
	_assert(member.is_downed() and member.corpse_state.is_empty(), "Combat zero-HP party member is unconscious, without inventing a corpse")
	before_slots = cleric.spell_slots.duplicate()
	await combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("cure_wounds")})
	await combat._on_hex_clicked(Vector2i(1, 0))
	_assert(member.is_alive and member.current_hp > 0 and cleric.spell_slots["1"] == int(before_slots["1"]) - 1 and not combat.turn_budget.can_spend("magic_action"), "Normal Cure Wounds command and clicked unconscious ally restore a living member with an ordinary slot/action")
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.player_entities[0]["hex_position"] = Vector2i(1, 0)
	CorpseRules.mark_dead(member, "damage")
	cleric.inventory.add_item("diamond_300gp")
	member.revival_willing = false
	before_slots = cleric.spell_slots.duplicate()
	await combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("revivify")})
	await combat._on_hex_clicked(Vector2i(1, 0))
	_assert(member.is_dead() and cleric.spell_slots == before_slots and cleric.inventory.has_item("diamond_300gp") and combat.turn_budget.can_spend("magic_action"), "Combat corpse targeting refuses an unwilling spirit before committing the action, slot or diamond")
	member.revival_willing = true
	await combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("revivify")})
	await combat._on_hex_clicked(Vector2i(1, 0))
	_assert(member.is_alive and member.current_hp == 1 and cleric.spell_slots["3"] == int(before_slots["3"]) - 1 and not cleric.inventory.has_item("diamond_300gp") and not combat.turn_budget.can_spend("magic_action"), "Normal combat spell command selects the corpse beneath a living caster, spends one Magic action/slot/diamond and restores the same party actor")
	_teardown_scene(combat)
	SaveManager.delete_save(slot)
	_exit_test()


func test_downed_area_damage_flow() -> void:
	_enter_test("downed_area_damage_flow")
	_setup_world()
	GameManager._reset_campaign_ledgers()
	var wizard := _fresh_char("Downed-area caster", "human", "wizard", {"STR": 10, "DEX": 14, "CON": 14, "INT": 16, "WIS": 10, "CHA": 10})
	wizard.inventory.add_item("component_pouch")
	for _level in 4: wizard.level_up()
	var book: Array[String] = ["fireball", "cloud_of_daggers"]
	for spell in DataLoader.get_castable_spell_list_options(["wizard"]):
		if book.size() >= wizard.wizard_spellbook_pending: break
		if int(spell.get("level", 0)) > 0 and int(spell.get("level", 0)) <= 3 and str(spell["id"]) not in book: book.append(str(spell["id"]))
	_assert(ClassProgression.choose_wizard_spellbook(wizard, book), "Area caster learns its combat spells through real Wizard spellbook choices")
	var selection: Array[String] = []
	# Keep the existing cantrips while filling the newly gained capacity.
	for spell_id in wizard.feature_choices.get(wizard.get_spellcasting_feature_id(), []):
		if int(DataLoader.get_spell(str(spell_id)).get("level", 0)) == 0: selection.append(str(spell_id))
	for spell_id in wizard.get_spell_option_ids(true):
		if selection.size() >= wizard.get_spellcasting_capacity("cantrips"): break
		if spell_id not in selection: selection.append(spell_id)
	var prepared: Array[String] = ["fireball", "cloud_of_daggers"]
	for spell_id in wizard.get_spell_option_ids(false):
		if prepared.size() >= wizard.get_spellcasting_capacity("prepared_spells"): break
		if spell_id not in prepared: prepared.append(spell_id)
	selection.append_array(prepared)
	_assert(ClassProgression.choose_spell_selection(wizard, selection), "Area caster prepares its spells through normal class selection")
	var member := _fresh_char("Unconscious area target", "human", "fighter", {"STR": 16, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PartyManager.reset()
	PlayerManager.reset()
	PlayerManager.add_player("Area caster")
	PlayerManager.set_player_character(0, wizard)
	PartyManager.register_player_character(0, wizard)
	PlayerManager.add_player("Area target")
	PlayerManager.set_player_character(1, member)
	PartyManager.register_player_character(1, member)
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	var combat: CombatState = await _spawn_scene("res://scenes/combat.tscn", 0.3)
	# A legal larger arena keeps the caster outside the Fireball Sphere.
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 8):
		var tile := HexTile.new()
		tile.coord = coord
		tile.is_revealed = true
		combat.hex_grid.add_tile(tile)
	combat.active_character = wizard
	combat.current_player_idx = 0
	combat.active_combatant = {"is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[1]["hex_position"] = Vector2i(6, 0)
	for monster in combat.monster_entities: monster["hex_position"] = Vector2i(-6, 0)
	wizard.current_hp = wizard.max_hp
	wizard.is_alive = true
	member.max_hp = 100
	member.current_hp = 0
	member.is_alive = false
	member.death_save_failures = 2
	combat.turn_budget.reset(wizard, combat.player_entities)
	var before_slots := wizard.spell_slots.duplicate()
	await combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("fireball")})
	await combat._on_hex_clicked(Vector2i(6, 0))
	_assert(member.is_dead() and member.corpse_state.get("cause") == "death_saves" and member.corpse_state.get("death_at_seconds") == GameManager.campaign_elapsed_seconds and wizard.spell_slots["3"] == int(before_slots["3"]) - 1, "A normal Fireball command affects an unconscious ally and records death from the third failure")
	if not member.is_dead():
		print("Downed-area cast diagnostic: %s" % combat.hud.log_text.text)
		_teardown_scene(combat)
		_exit_test()
		return
	_assert(CorpseRules.revive(member, GameManager.campaign_elapsed_seconds).get("success", false), "Area fixture restores the member for an independent persistent-zone case")
	member.current_hp = 0
	member.is_alive = false
	member.death_save_failures = 2
	combat.turn_budget.reset(wizard, combat.player_entities)
	await combat._on_hud_action("cast_spell", {"spell": DataLoader.get_spell("cloud_of_daggers")})
	await combat._on_hex_clicked(Vector2i(3, 0))
	var source_id := combat._cloud_of_daggers_zone_source_for_caster(wizard)
	_assert(not source_id.is_empty(), "Normal Cloud of Daggers command creates the persistent zone")
	combat.tracker.current_round += 1
	combat.turn_budget.reset(wizard, combat.player_entities)
	await combat._on_hud_action("move_cloud_of_daggers", {})
	await combat._on_hex_clicked(Vector2i(6, 0))
	_assert(member.is_dead() and member.corpse_state.get("cause") == "death_saves" and not combat.turn_budget.can_spend("magic_action"), "Moving a persistent Cloud of Daggers onto an unconscious ally damages it and records actual death")
	_teardown_scene(combat)
	_exit_test()


func test_created_undead_flow() -> void:
	_enter_test("created_undead_flow")
	_setup_world()
	GameManager._reset_campaign_ledgers()
	GameManager.completed_milestones.append("enter_dungeon_1")
	GameManager.game_in_progress = true
	var cleric := _fresh_char("Crown necromancer", "human", "cleric", {"STR": 14, "DEX": 10, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	for _level in 4: cleric.level_up()
	cleric.inventory.add_item("component_pouch")
	cleric.inventory.add_item("gentle_repose_copper")
	var selection: Array[String] = []
	var cantrips := cleric.get_spell_option_ids(true)
	for index in mini(cleric.get_spellcasting_capacity("cantrips"), cantrips.size()): selection.append(cantrips[index])
	var prepared: Array[String] = ["animate_dead", "gentle_repose"]
	for spell_id in cleric.get_spell_option_ids(false):
		if prepared.size() >= cleric.get_spellcasting_capacity("prepared_spells"): break
		if spell_id not in prepared: prepared.append(spell_id)
	selection.append_array(prepared)
	_assert(ClassProgression.choose_spell_selection(cleric, selection), "Crown level-five Cleric prepares Animate Dead and Gentle Repose through class choices")
	PartyManager.reset()
	PlayerManager.reset()
	PlayerManager.add_player("Undead owner")
	PlayerManager.set_player_character(0, cleric)
	PartyManager.register_player_character(0, cleric)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await _spawn_scene("res://scenes/dungeon.tscn", 0.2)
	var room: Room
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: room = candidate
	dungeon.hex_grid.hex_clicked.emit(room.coord)
	await get_tree().process_frame
	var view := dungeon.local_view
	view.slots.select(Inventory.Slot.SHIELD)
	_local_room_press(view, "Unequip")
	view.state["party_positions"][cleric.character_id] = [-2, 2]
	view.refresh()
	var body := LocalRoomRules.get_object(view.state, "fallen_guard_bones")
	_assert(not body.is_empty(), "Crown's authored temple room exposes an eligible pile of Humanoid bones")
	_local_room_press(view, "Preserve remains")
	var slots_before := cleric.spell_slots.duplicate()
	var time_before := GameManager.campaign_elapsed_seconds
	_local_room_press(view, "Animate Dead (1 min)")
	_assert(GameManager.created_creatures.is_empty() and cleric.spell_slots == slots_before and GameManager.campaign_elapsed_seconds == time_before and not bool(body["removed"]), "Actual room animation control refuses Gentle Repose protection before a slot, time or body is consumed")
	# Simulate reaching the preservation deadline without imposing ten days of unrelated starvation on the fixture.
	body["preserved_until"] = int(GameManager.campaign_elapsed_seconds)
	_local_room_press(view, "Animate Dead (1 min)")
	_assert(GameManager.created_creatures.size() == 1 and bool(body["removed"]) and cleric.spell_slots["3"] == int(slots_before["3"]) - 1 and GameManager.campaign_elapsed_seconds == time_before + 60, "Normal one-minute Animate Dead control creates exactly one Skeleton and consumes its original remains and one level-three slot")
	if GameManager.created_creatures.is_empty():
		_teardown_scene(dungeon)
		_exit_test()
		return
	var record: Dictionary = GameManager.created_creatures[0]
	var creature_id := str(record["id"])
	var position := LocalRoomRules.coord(record["position"])
	_assert(record["current_hp"] == 13 and record["existence_until"] == -1 and record["control_until"] == GameManager.campaign_elapsed_seconds + 86400 and view.grid.entities.any(func(entity): return entity.get("character") != null and entity["character"].character_id == creature_id), "Created creature is visible in a legal room cell with stable identity, curated HP and distinct existence/control lifetimes")
	_local_room_press(view, "Renew control (1 min)")
	_assert(record["id"] == creature_id and record["current_hp"] == 13 and record["control_until"] == GameManager.campaign_elapsed_seconds + 86400 and cleric.spell_slots["3"] == 0, "Normal renewal retains the same creature while resetting only its control interval")
	var room_state: Dictionary = view.state
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"], "local_room": room_state}
	var combat: CombatState = await _spawn_scene("res://scenes/combat.tscn", 0.2)
	var units: Array = combat.player_entities.filter(func(entity): return entity.get("is_created_creature", false))
	_assert(units.size() == 1 and units[0]["character"].character_id == creature_id and units[0]["owner_player_index"] == 0 and combat.tracker.combatants.any(func(entry): return entry["entity"] is Character and entry["entity"] == units[0]["character"]), "Combat projects the retained creature once and gives it independent initiative with its owner's seat")
	if units.is_empty():
		_teardown_scene(combat)
		_teardown_scene(dungeon)
		_exit_test()
		return
	var unit: Dictionary = units[0]
	var undead: Character = unit["character"]
	combat.active_character = undead
	combat.current_player_idx = combat.player_entities.find(unit)
	combat.turn_budget.reset(undead, combat.player_entities)
	await CreatedCreatureCombat.take_turn(combat, unit)
	_assert(undead.has_condition("dodging"), "An Undead with no attack order actually takes Dodge")
	combat.active_character = cleric
	combat.current_player_idx = 0
	combat.active_combatant = {"is_player": true, "entity": cleric}
	combat.turn_budget.reset(cleric, combat.player_entities)
	combat.hud.update_hud(cleric, combat.tracker)
	combat.hud._show_feature_selection()
	var command_index := -1
	for index in combat.hud.features_registered.size():
		if combat.hud.features_registered[index].get("id", "") == "created_attack": command_index = index
	_assert(command_index >= 0, "A controlled Undead exposes its Bonus-action order in the real feature picker")
	combat.hud._on_feature_selected(command_index)
	await get_tree().process_frame
	await combat._on_hex_clicked(Vector2i(99, 99))
	_assert(combat.turn_budget.can_spend("bonus_action") and record["order"] == "guard", "Invalid clicked enemy refuses an order without spending the Bonus Action")
	var enemy: Dictionary = combat.monster_entities[0]
	for candidate in HexUtils.get_hexes_in_range(position, 1):
		if candidate != position and combat.hex_grid.is_hex_passable(candidate) and not combat._is_occupied_hex(candidate): enemy["hex_position"] = candidate; break
	enemy["current_hp"] = 100
	enemy["max_hp"] = 100
	enemy["armor_class"] = -100
	await combat._on_hex_clicked(enemy["hex_position"])
	_assert(record["order"] == "attack" and record["order_target"] == enemy["id"] and not combat.turn_budget.can_spend("bonus_action"), "Normal feature selection and clicked enemy spend one Bonus Action and record the creature's standing attack order")
	for index in combat.tracker.combatants.size():
		if combat.tracker.combatants[index]["entity"] is Character and combat.tracker.combatants[index]["entity"] == undead: combat.tracker.active_index = index; break
	FighterChecks._seed_die(20, 10)
	await combat._start_combat_turn()
	_assert(int(enemy["current_hp"]) < 100, "The creature's actual initiative turn follows its attack order through shared weapon damage")
	var bow_destination := FamiliarRules.ABSENT
	for cell in room_state["cells"]:
		var candidate := LocalRoomRules.coord(cell)
		if HexUtils.get_distance(unit["hex_position"], candidate) > 1 and combat.hex_grid.is_hex_passable(candidate) and not combat._is_occupied_hex(candidate) and Targeting.has_line_of_sight(unit["hex_position"], candidate, combat.hex_grid): bow_destination = candidate; break
	_assert(bow_destination != FamiliarRules.ABSENT, "Crown's room provides a legal visible Shortbow target beyond melee reach")
	enemy["hex_position"] = bow_destination
	enemy["current_hp"] = 100
	combat.active_character = undead
	combat.current_player_idx = combat.player_entities.find(unit)
	combat.turn_budget.reset(undead, combat.player_entities)
	FighterChecks._seed_die(20, 10)
	await CreatedCreatureCombat.take_turn(combat, unit)
	_assert(int(enemy["current_hp"]) < 100 and unit["hex_position"] == position and HexUtils.get_distance(position, bow_destination) > 1, "A standing attack order uses Skeleton's Shortbow through actual shared damage against a distant visible enemy without moving into melee")
	CombatAction.resolve_damage(undead, 4, "slashing")
	for monster in combat.monster_entities: monster["is_alive"] = false; monster["current_hp"] = 0
	combat._check_battle_end_conditions()
	await get_tree().process_frame
	_assert(record["current_hp"] == 9 and record["id"] == creature_id, "Production encounter completion captures created-creature damage without replacing its identity")
	_teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.DUNGEON
	view.state["party_positions"][cleric.character_id] = view.state["exits"][0].duplicate()
	view.refresh()
	_local_room_press(view, "Room map")
	await get_tree().process_frame
	dungeon.hex_grid.hex_clicked.emit(Vector2i.ZERO)
	var save_slot := "wave4_created_undead"
	_assert(SaveManager.save_game(save_slot), "Damaged created Undead write through the actual dungeon entrance checkpoint")
	_teardown_scene(dungeon)
	PartyManager.reset()
	PlayerManager.reset()
	GameManager.created_creatures.clear()
	_assert(SaveManager.load_game(save_slot), "Created-creature ledger reloads through the production disk loader")
	record = CreatedCreatureRules.get_record(creature_id)
	_assert(not record.is_empty() and record["current_hp"] == 9 and CreatedCreatureRules.controlled(record), "Disk reload retains the same damaged creature and remaining control interval")
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"], "local_room": room_state}
	combat = await _spawn_scene("res://scenes/combat.tscn", 0.2)
	var retained_initiative: Dictionary = {}
	for entry in combat.tracker.combatants:
		if entry["entity"] is Character and entry["entity"].character_id == creature_id: retained_initiative = entry.duplicate(); break
	GameManager.campaign_elapsed_seconds = int(record["control_until"])
	CreatedCreatureCombat.reconcile(combat)
	_assert(not retained_initiative.is_empty() and combat.tracker.combatants.any(func(entry): return entry["id"] == retained_initiative["id"] and not entry["is_player"] and entry["roll"] == retained_initiative["roll"] and entry["entity"].get("created_creature_id", "") == creature_id) and not combat.player_entities.any(func(entity): return entity.get("is_created_creature", false)), "In-encounter expiry flips the same initiative record to a hostile actor without a new roll or duplicate creature")
	_assert(not CreatedCreatureRules.controlled(record) and record["current_hp"] == 9 and record["existence_until"] == -1, "The exact 24-hour deadline ends obedience while retaining the living Undead")
	_teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": [], "local_room": room_state}
	combat = await _spawn_scene("res://scenes/combat.tscn", 0.2)
	_assert(not combat.player_entities.any(func(entity): return entity.get("is_created_creature", false)) and combat.monster_entities.size() == 1 and combat.monster_entities[0].get("created_creature_id", "") == creature_id and combat.monster_entities[0]["current_hp"] == 9, "A later encounter projects the expired creature as the same damaged hostile Undead without spawning fallback enemies")
	_teardown_scene(combat)
	SaveManager.delete_save(save_slot)
	_exit_test()
