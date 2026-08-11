## Normal-path Gate 4 probe.
##
## Runs only when RUN_NORMAL_CREATION_MATRIX=1. The autoload boundary lets the
## probe survive the production scene transitions it is verifying.
extends Node

var failures: Array[String] = []


func _ready() -> void:
	if OS.get_environment("RUN_NORMAL_CREATION_MATRIX") != "1":
		return
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[ok]   %s" % message)
	else:
		failures.append(message)
		print("[FAIL] %s" % message)


func _wait_for_state(expected: GameManager.GameState, timeout_seconds: float = 3.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while GameManager.current_state != expected and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return GameManager.current_state == expected


func _wait_for_scene(scene_name: String, timeout_seconds: float = 3.0) -> Node:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while (get_tree().current_scene == null or get_tree().current_scene.name != scene_name) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return get_tree().current_scene if get_tree().current_scene != null and get_tree().current_scene.name == scene_name else null


func _run() -> void:
	await get_tree().process_frame
	GameManager.test_mode = true

	for player_count in range(1, PlayerManager.MAX_PLAYERS + 1):
		await _run_player_count(player_count)
	await _run_class_equipment_smoke("Fighter", ["chain_mail", "shield", "longsword"])
	await _run_class_equipment_smoke("Barbarian", ["chain_mail", "shield", "longsword"])
	await _run_class_equipment_smoke("Rogue", ["leather_armor", "shield"])
	await _run_class_equipment_smoke("Wizard", ["leather_armor", "dagger"], ["fire_bolt", "magic_missile"])
	await _run_class_equipment_smoke("Warlock", ["leather_armor", "dagger"])
	await _run_class_equipment_smoke("Sorcerer", ["leather_armor", "dagger"])
	await _run_class_equipment_smoke("Cleric", ["leather_armor", "shield"], ["light", "bless", "cure_wounds"])
	await _run_class_equipment_smoke("Paladin", ["chain_mail", "shield", "longsword"])
	await _run_class_equipment_smoke("Ranger", ["leather_armor", "shield", "longbow"])
	await _run_class_equipment_smoke("Artificer", ["leather_armor", "shield", "tinkers_tools"])

	print("--------------------------------------------------")
	if failures.is_empty():
		print("NORMAL CREATION MATRIX PASSED: 1, 2, 3, and 4 players")
		get_tree().quit(0)
	else:
		print("NORMAL CREATION MATRIX FAILED: %d failure(s)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _run_player_count(player_count: int) -> void:
	print("\n[MATRIX] %d local player(s)" % player_count)
	if GameManager.current_state != GameManager.GameState.MAIN_MENU or get_tree().current_scene == null or get_tree().current_scene.name != "MainMenu":
		GameManager.change_state(GameManager.GameState.MAIN_MENU)
		await _wait_for_state(GameManager.GameState.MAIN_MENU)

	var menu: Node = await _wait_for_scene("MainMenu")
	_check(menu != null, "%d-player flow is on the production main menu" % player_count)
	if menu == null:
		return

	_check(menu.selected_campaign_idx == 0, "%d-player menu selects the Crown campaign" % player_count)
	var adjustments := player_count - 2
	if adjustments < 0:
		for _i in range(-adjustments):
			menu.get_node("MarginContainer/HBoxContainer/RightPanel/VBoxContainer/PlayerCountSection/HBoxContainer/BtnMinus").pressed.emit()
	else:
		for _i in range(adjustments):
			menu.get_node("MarginContainer/HBoxContainer/RightPanel/VBoxContainer/PlayerCountSection/HBoxContainer/BtnPlus").pressed.emit()
	_check(menu.selected_player_count == player_count, "menu player-count control selects %d" % player_count)
	_check(menu.player_count_label.text == "%d Players" % player_count, "menu displays %d Players" % player_count)

	menu.start_button.pressed.emit()
	var creation := await _wait_for_scene("CharacterCreation")
	_check(creation != null, "%d-player Start Game enters character creation" % player_count)
	if creation == null:
		return

	for player_index in range(player_count):
		_check(creation.current_player_idx == player_index, "creation reaches player %d of %d" % [player_index + 1, player_count])
		creation.btn_rand.pressed.emit()
		await get_tree().process_frame
		_check(creation.current_step == creation.CreationStep.SUMMARY, "player %d reaches the creation summary" % [player_index + 1])
		creation.btn_next.pressed.emit()
		await get_tree().process_frame

	var overworld := await _wait_for_scene("Overworld")
	_check(overworld != null, "%d-player creation reaches the overworld" % player_count)
	_check(GameManager.current_state == GameManager.GameState.OVERWORLD, "%d-player start state is OVERWORLD" % player_count)
	_check(GameManager.game_in_progress, "%d-player campaign is marked in progress" % player_count)
	_check(PlayerManager.get_player_count() == player_count, "%d-player roster contains exactly %d seats" % [player_count, player_count])
	_check(PartyManager.get_active_characters().size() == player_count, "%d-player party starts with %d player characters" % [player_count, player_count])

	for player_index in range(player_count):
		var player: Dictionary = PlayerManager.get_player(player_index)
		var character = player.get("character")
		var slot_id := "slot_%d" % player_index
		_check(character != null, "seat %d owns a created character" % [player_index + 1])
		_check(slot_id in player.get("assigned_slot_ids", []), "seat %d owns its stable party slot" % [player_index + 1])
		_check(PlayerManager.get_player_for_party_slot(slot_id) == player_index, "stable slot %s reports owner seat %d" % [slot_id, player_index + 1])

	var empty_slots := 0
	for slot in PartyManager.party_slots:
		if str(slot.get("character_id", "")).is_empty():
			empty_slots += 1
	_check(empty_slots == PlayerManager.MAX_PLAYERS - player_count, "%d-player start leaves %d companion slots empty" % [player_count, PlayerManager.MAX_PLAYERS - player_count])

	if player_count < PlayerManager.MAX_PLAYERS:
		GameManager.change_state(GameManager.GameState.MAIN_MENU)
		await _wait_for_state(GameManager.GameState.MAIN_MENU)


func _find_card_button(grid: GridContainer, expected_label: String) -> Button:
	for card in grid.get_children():
		if card.get_child_count() == 0:
			continue
		var card_content := card.get_child(0)
		if card_content.get_child_count() < 3:
			continue
		var title := card_content.get_child(0) as Label
		if title != null and title.text == expected_label:
			return card_content.get_child(2) as Button
	return null


func _run_class_equipment_smoke(target_class: String, expected_equipment: Array[String], expected_spells: Array[String] = []) -> void:
	print("\n[MATRIX] %s starting equipment normal-path smoke" % target_class)
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	await _wait_for_state(GameManager.GameState.MAIN_MENU)
	var fighter_menu: Node = await _wait_for_scene("MainMenu")
	_check(fighter_menu != null, "%s smoke is on the production main menu" % target_class)
	if fighter_menu == null:
		return
	while fighter_menu.selected_player_count > 1:
		fighter_menu.get_node("MarginContainer/HBoxContainer/RightPanel/VBoxContainer/PlayerCountSection/HBoxContainer/BtnMinus").pressed.emit()
	while fighter_menu.selected_player_count < 1:
		fighter_menu.get_node("MarginContainer/HBoxContainer/RightPanel/VBoxContainer/PlayerCountSection/HBoxContainer/BtnPlus").pressed.emit()
	fighter_menu.start_button.pressed.emit()
	var creation: Node = await _wait_for_scene("CharacterCreation")
	_check(creation != null, "%s smoke enters production character creation" % target_class)
	if creation == null:
		return

	var human_button := _find_card_button(creation.race_grid, "Human")
	_check(human_button != null, "%s smoke can select Human through the race UI" % target_class)
	if human_button == null:
		return
	human_button.pressed.emit()
	await get_tree().process_frame
	creation.btn_next.pressed.emit()
	await get_tree().process_frame
	var class_button := _find_card_button(creation.class_grid, target_class)
	_check(class_button != null, "%s smoke can select %s through the class UI" % [target_class, target_class])
	if class_button == null:
		return
	class_button.pressed.emit()
	await get_tree().process_frame
	creation.btn_next.pressed.emit()
	await get_tree().process_frame
	creation.btn_next.pressed.emit()
	await get_tree().process_frame

	_check(creation.selected_equipment == expected_equipment, "%s equipment step shows the production starting gear" % target_class)
	creation.btn_next.pressed.emit()
	await get_tree().process_frame
	_check(creation.summary_class_label.text == target_class, "%s summary retains the selected class" % target_class)
	creation.btn_next.pressed.emit()
	var overworld := await _wait_for_scene("Overworld")
	_check(overworld != null, "%s smoke reaches the overworld through normal creation" % target_class)
	if overworld == null:
		return
	var character: Character = PlayerManager.get_player(0).get("character")
	_check(character != null and character.class_id == target_class.to_lower(), "normal creation saves a %s character" % target_class)
	if character == null:
		return
	if target_class == "Fighter":
		_check(character.inventory.get_armor() == "chain_mail", "normal Fighter equips chain mail")
		_check(character.inventory.get_equipped(Inventory.Slot.SHIELD) == "shield", "normal Fighter equips a shield")
		_check(character.inventory.get_weapon() == "longsword", "normal Fighter equips a longsword")
	elif target_class == "Barbarian":
		_check(character.inventory.get_armor() == "chain_mail", "normal Barbarian equips chain mail")
		_check(character.inventory.get_equipped(Inventory.Slot.SHIELD) == "shield", "normal Barbarian equips a shield")
		_check(character.inventory.get_weapon() == "longsword", "normal Barbarian equips a longsword")
		character.inventory.unequip(Inventory.Slot.BODY)
		character._recalculate_ac()
		var expected_unarmored_ac := 10 + character.ability_scores.get_ability_modifier("DEX") + character.ability_scores.get_ability_modifier("CON") + 2
		_check(character.has_feature("barbarian_unarmored_defense") and character.get_ac() == expected_unarmored_ac, "normal Barbarian uses shield-compatible Unarmored Defense after armor removal")
	elif target_class == "Rogue":
		_check(character.inventory.get_armor() == "leather_armor", "normal Rogue equips leather armor")
		_check(character.inventory.get_equipped(Inventory.Slot.SHIELD) == "shield", "normal Rogue equips a shield")
	elif target_class == "Wizard":
		_check(character.inventory.get_armor() == "leather_armor", "normal Wizard equips leather armor")
		_check(character.inventory.get_weapon() == "dagger", "normal Wizard equips a dagger")
	elif target_class == "Warlock":
		_check(character.inventory.get_armor() == "leather_armor", "normal Warlock equips leather armor")
		_check(character.inventory.get_weapon() == "dagger", "normal Warlock equips a dagger")
		character.level_up()
		_check(character.has_feature("warlock_magical_cunning") and character.get_feature("warlock_magical_cunning").get("type", "") == "active", "normal Warlock gains Magical Cunning at level 2")
	elif target_class == "Sorcerer":
		_check(character.inventory.get_armor() == "leather_armor", "normal Sorcerer equips leather armor")
		_check(character.inventory.get_weapon() == "dagger", "normal Sorcerer equips a dagger")
		var normal_sorcerer_dc := character.get_spell_save_dc()
		character.use_feature("sorcerer_innate_sorcery")
		var innate_effects: Array = character.get_feature("sorcerer_innate_sorcery").get("effects", [])
		EventResolver.apply_effects(character, innate_effects)
		_check(character.has_condition("innate_sorcery") and character.get_spell_save_dc() == normal_sorcerer_dc + 1, "normal Sorcerer activates Innate Sorcery through the shared effect path")
	elif target_class == "Cleric":
		_check(character.inventory.get_armor() == "leather_armor", "normal Cleric equips leather armor")
		_check(character.inventory.get_equipped(Inventory.Slot.SHIELD) == "shield", "normal Cleric equips a shield")
	elif target_class == "Paladin":
		_check(character.inventory.get_armor() == "chain_mail", "normal Paladin equips chain mail")
		_check(character.inventory.get_equipped(Inventory.Slot.SHIELD) == "shield", "normal Paladin equips a shield")
		_check(character.inventory.get_weapon() == "longsword", "normal Paladin equips a longsword")
		character.level_up()
		_check(character.has_feature("paladin_fighting_style") and character.get_ac() == 19, "normal Paladin gains armored Defense Fighting Style AC at level 2")
	elif target_class == "Ranger":
		_check(character.inventory.get_armor() == "leather_armor", "normal Ranger equips leather armor")
		_check(character.inventory.get_equipped(Inventory.Slot.SHIELD) == "shield", "normal Ranger equips a shield")
		_check(character.inventory.get_weapon() == "longbow", "normal Ranger equips a longbow")
		character.level_up()
		_check(character.has_feature("ranger_fighting_style") and character.get_attack_style_bonus(DataLoader.get_item("longbow")) == 2, "normal Ranger gains ranged Archery attack bonus at level 2")
	elif target_class == "Artificer":
		_check(character.inventory.get_armor() == "leather_armor", "normal Artificer equips leather armor")
		_check(character.inventory.get_equipped(Inventory.Slot.SHIELD) == "shield", "normal Artificer equips a shield")
		_check(character.inventory.has_item("tinkers_tools"), "normal Artificer carries Tinker's Tools")
		var bearings_before := character.inventory.count_item("ball_bearings")
		var tinker_result := ClassFeature.execute(character, character.get_feature("artificer_tinker's_magic"))
		_check(tinker_result.get("success", false) and character.inventory.count_item("ball_bearings") == bearings_before + 1, "normal Artificer creates Ball Bearings through Tinker's Magic")
	for spell_id in expected_spells:
		_check(character.known_spells.has(spell_id), "normal %s acquires %s" % [target_class, spell_id])
	if not expected_spells.is_empty():
		_check(int(character.spell_slots.get("1", 0)) > 0, "normal %s receives level-1 spell slots" % target_class)
