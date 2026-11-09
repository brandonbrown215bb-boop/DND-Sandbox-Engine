## CXM-04 production flow: the Background step at creation (SRD 5.2.1 p.83)
## across three seats (manual, corrected, Random), a real save, forged DTOs on
## both save routes, and a fresh-process reload probe.
class_name BackgroundCreationControls
extends RefCounted

const SLOT := "background_creation"
const IDS := "user://background_creation_ids.txt"

static func _pick(h: Node, selector: OptionButton, value: Variant) -> void:
	for index in selector.item_count:
		if selector.get_item_metadata(index) == value:
			selector.select(index)
			selector.item_selected.emit(index)
			return
	h._assert(false, "Background option is available: %s" % str(value))

static func _node(creation: Node, node_name: String) -> Node:
	return creation._background_list.find_child(node_name, true, false)

static func _expected(c: Character) -> Dictionary:
	return {"id": c.character_id, "background_id": c.background_id, "choices": c.background_choices, "scores": c.ability_scores.to_dict(), "gold": c.inventory.gold, "backpack": c.inventory.backpack.size(), "feat": c.origin_feat, "skills": c.skill_proficiencies, "tools": c.tool_proficiency_sources}

static func run(h: Node) -> void:
	h._enter_test("background_creation_flow")
	h._setup_world()
	PlayerManager.reset()
	PartyManager.reset()
	for seat in ["Soldier seat", "Fighter seat", "Random seat"]: PlayerManager.add_player(seat)
	GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
	var creation: Node = await h._spawn_scene("res://scenes/ui/character_creation.tscn", 0.2)

	# Seat 1: every step through the real buttons. Human Wizard Soldier, +2 STR / +1 CON, kit.
	for button in creation.race_grid.get_children():
		if button.get_meta("choice_id") == "human": button.pressed.emit()
	creation.btn_next.pressed.emit()
	for button in creation.class_grid.get_children():
		if button.get_meta("choice_id") == "wizard": button.pressed.emit()
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	h._assert(creation.current_step == creation.CreationStep.BACKGROUND and creation.btn_next.disabled and _node(creation, "Background_sage") != null, "CXM-04 the Background step follows Class and blocks Next until one is chosen")
	_node(creation, "Background_soldier").pressed.emit()
	await h.get_tree().process_frame
	h._assert(creation.btn_next.disabled and _node(creation, "BackgroundAbilities").item_count == 8 and _node(creation, "BackgroundTool1") != null, "CXM-04 Soldier offers the seven ability spreads and a Gaming Set picker, and still blocks Next")
	_pick(h, _node(creation, "BackgroundAbilities"), {"STR": 2, "CON": 1})
	h._assert(creation.btn_next.disabled, "CXM-04 Next stays disabled until the Gaming Set is chosen")
	_pick(h, _node(creation, "BackgroundTool1"), "dragonchess_set")
	h._assert(not creation.btn_next.disabled, "CXM-04 a full Soldier choice enables Next")
	creation.btn_next.pressed.emit()
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	h._assert(creation.current_step == creation.CreationStep.EQUIPMENT and creation.equip_list.get_node_or_null("BackgroundOriginFeat") != null and creation.equip_list.get_node_or_null("OriginFeatPicker") == null and creation.equip_list.get_node("BackgroundGear").text.contains("Dragonchess") and creation.equip_list.get_node("BackgroundGear").text.contains("14 GP"), "CXM-04 the equipment step shows the fixed Origin feat and the background kit, with no feat picker")
	h._select_creation_choice(creation.equip_list.get_node("WizardSkill1"), "Arcana")
	h._select_creation_choice(creation.equip_list.get_node("WizardSkill2"), "Investigation")
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	h._assert(creation.current_step == creation.CreationStep.SUMMARY and creation.summary_stats_label.text.contains("(+2 Background)") and not creation.summary_stats_label.text.contains("Species)") and creation.summary_stats_label.text.contains("Background: Soldier") and creation.summary_equip_label.text.contains("Soldier background:"), "CXM-04 the review shows background increases, not species bonuses, and the background kit")
	for _i in 3: creation.btn_back.pressed.emit()
	await h.get_tree().process_frame
	var kept: OptionButton = _node(creation, "BackgroundAbilities")
	h._assert(creation.current_step == creation.CreationStep.BACKGROUND and kept.get_item_metadata(kept.selected) == {"STR": 2, "CON": 1} and creation.background_choices.tools == ["dragonchess_set"] and not creation.btn_next.disabled, "CXM-04 Back keeps the background and its picks")
	for _i in 3: creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var soldier: Character = PlayerManager.get_player(0).get("character")
	h._assert(soldier != null and soldier.background_id == "soldier" and soldier.ability_scores.get_permanent_score("STR") == 12 and soldier.ability_scores.get_permanent_score("CON") == 11 and soldier.ability_scores.get_permanent_score("DEX") == 10 and soldier.origin_feat == "savage_attacker" and "Athletics" in soldier.skill_proficiencies and soldier.tool_proficiency_sources.get("dragonchess_set", []) == ["background:soldier"] and BackgroundChecks.carried(soldier, "dragonchess_set") == 1 and BackgroundChecks.carried(soldier, "arrows") == 20 and soldier.inventory.gold == 5 + 14, "CXM-04 Confirm grants the Soldier increases once (no human +1s), feat, skills, matching Gaming Set, kit and GP")

	# Seat 2: the seat reset, a class skill the background takes over, +1/+1/+1 with 50 GP, and a stale Confirm.
	h._assert(creation.current_player_idx == 1 and creation.current_step == creation.CreationStep.RACE and creation.selected_background_id.is_empty() and creation.background_choices.abilities.is_empty(), "CXM-04 the next seat starts with no background")
	creation.selected_name = "CXM04 Fighter"
	creation.selected_race_id = "human"
	creation.selected_class_id = "fighter"
	creation.current_step = creation.CreationStep.BACKGROUND
	creation._update_step_ui()
	await h.get_tree().process_frame
	h._assert(creation._class_choices().skills == ["Athletics", "Perception"], "CXM-04 the Fighter starts with its preset class skills")
	_node(creation, "Background_soldier").pressed.emit()
	await h.get_tree().process_frame
	_pick(h, _node(creation, "BackgroundAbilities"), {"STR": 1, "DEX": 1, "CON": 1})
	_pick(h, _node(creation, "BackgroundTool1"), "dice_set")
	var equipment: OptionButton = _node(creation, "BackgroundEquipment")
	equipment.select(1)
	equipment.item_selected.emit(1)
	creation.btn_next.pressed.emit()
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var first_skill: OptionButton = creation.equip_list.get_node("FighterSkill1")
	var athletics_disabled := false
	for i in first_skill.item_count:
		if str(first_skill.get_item_metadata(i)) == "Athletics": athletics_disabled = first_skill.is_item_disabled(i)
	h._assert(creation.class_creation_choices.skills == ["", "Perception"] and athletics_disabled and creation.btn_next.disabled and creation.equip_list.get_node("BackgroundGear").text.ends_with("50 GP"), "CXM-04 Soldier clears and disables the Fighter's Athletics pick, and the 50 GP option lists no kit")
	h._select_creation_choice(first_skill, "History")
	h._assert(not creation.btn_next.disabled, "CXM-04 a replacement class skill enables Next")
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	creation.background_choices["abilities"] = {"STR": 2, "DEX": 2}
	creation._confirm_and_save_character()
	await h.get_tree().process_frame
	h._assert(PlayerManager.get_player(1).get("character") == null and creation.current_player_idx == 1, "CXM-04 a stale Confirm with an illegal spread creates nothing")
	creation.background_choices["abilities"] = {"STR": 1, "DEX": 1, "CON": 1}
	creation.current_step = creation.CreationStep.SUMMARY
	creation._update_step_ui()
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var fighter: Character = PlayerManager.get_player(1).get("character")
	h._assert(fighter != null and fighter.ability_scores.get_permanent_score("STR") == 11 and fighter.ability_scores.get_permanent_score("INT") == 10 and fighter.inventory.gold == 4 + 50 and BackgroundChecks.carried(fighter, "spear") == 0 and fighter.skill_proficiencies.count("Athletics") == 1 and fighter.creation_choices.skills == ["History", "Perception"], "CXM-04 +1/+1/+1 with 50 GP adds no kit and the background owns Athletics")

	# Seat 3: Random always lands on a legal background.
	var random_ok := true
	for _i in 12:
		creation.btn_rand.pressed.emit()
		await h.get_tree().process_frame
		if creation.selected_background_id.is_empty() or not creation._creation_choice_error().is_empty() or creation.btn_next.disabled: random_ok = false
	h._assert(random_ok and creation.current_step == creation.CreationStep.SUMMARY, "CXM-04 Random picks a legal background, spread, tool and option every time (%s)" % creation._creation_choice_error())
	var random_background: String = creation.selected_background_id
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var random: Character = PlayerManager.get_player(2).get("character")
	h._assert(random != null and random.background_id == random_background and random.origin_feat == str(DataLoader.get_background(random_background).origin_feat) and BackgroundRules.saved_error(random.to_dict()).is_empty(), "CXM-04 the Random character holds its background")
	h._teardown_scene(creation)
	if soldier == null or fighter == null or random == null:
		h._exit_test()
		return

	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	h._assert(SaveManager.save_game(SLOT), "CXM-04 the three-background party saves through the disk boundary")
	var forged: Dictionary = SaveManager._read_save(SLOT)
	forged["party"]["characters"][soldier.character_id]["background_choices"]["abilities"] = {"STR": 2, "DEX": 2}
	h._assert(not SaveManager._validate_save_data(forged).is_empty(), "CXM-04 a forged spread on the party record is refused")
	forged = SaveManager._read_save(SLOT)
	forged["players"][0]["character"]["tool_proficiency_sources"].erase("dragonchess_set")
	h._assert(not SaveManager._validate_save_data(forged).is_empty(), "CXM-04 a stripped background tool source on the player record is refused")
	forged = SaveManager._read_save(SLOT)
	forged["players"][1]["character"]["origin_feat"] = ""
	h._assert(not SaveManager._validate_save_data(forged).is_empty(), "CXM-04 a background without its Origin feat is refused")
	var f := FileAccess.open(IDS, FileAccess.WRITE)
	f.store_string(JSON.stringify([_expected(soldier), _expected(fighter), _expected(random)]))
	f.close()
	h._exit_test()

static func reload(h: Node) -> void:
	h._enter_test("background_creation_reload")
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(IDS))
	h._assert(expected is Array and expected.size() == 3 and SaveManager.load_game(SLOT), "CXM-04 fresh process loads the background save")
	if not expected is Array or expected.size() != 3:
		h._exit_test()
		return
	for round_trip in 2:
		var same := true
		for want in expected:
			var c: Character = PartyManager.characters.get(want.id, null)
			if c == null or JSON.stringify(JSON.parse_string(JSON.stringify(_expected(c)))) != JSON.stringify(want): same = false
		h._assert(same, "CXM-04 reload %d keeps each background, scores, GP, items and sources without a second grant" % (round_trip + 1))
		if round_trip == 0: h._assert(SaveManager.save_game(SLOT) and SaveManager.load_game(SLOT), "CXM-04 fresh process saves and loads again")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	h._exit_test()
