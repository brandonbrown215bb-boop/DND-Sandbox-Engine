class_name Batch051Controls
extends RefCounted
## Batch 051 scenario: the real creation screen's Origin feat picker, the real
## character sheet's "Take feat instead" control, then real save/load.

static func run(h: Node) -> void:
	h._enter_test("batch_051_feat_acquisition_flow")
	h._setup_world()
	Batch051Checks.load_fixtures()
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Feat Owner")
	PlayerManager.add_player("Next seat") # Keep creation on its next seat.
	GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
	var creation: Node = await h._spawn_scene("res://scenes/ui/character_creation.tscn", 0.2)
	creation.selected_name = "Feat Taker"
	creation.selected_race_id = "human"
	creation.selected_class_id = "fighter"
	creation.selected_stats.from_dict({"STR": 15, "DEX": 14, "CON": 13, "INT": 8, "WIS": 12, "CHA": 10})
	creation.current_step = creation.CreationStep.EQUIPMENT
	creation._update_step_ui()
	await h.get_tree().process_frame
	var picker: OptionButton = creation.equip_list.get_node_or_null("OriginFeatPicker")
	var vigil_index := -1
	if picker != null:
		for i in picker.item_count:
			if str(picker.get_item_metadata(i)) == Batch051Checks.VIGIL: vigil_index = i
		var general_offered := false
		for i in picker.item_count:
			general_offered = general_offered or str(picker.get_item_metadata(i)) == Batch051Checks.GRIT
		h._assert(vigil_index >= 0 and not general_offered, "051 actual the creation screen offers Origin feats only")
		picker.select(vigil_index)
		picker.item_selected.emit(vigil_index)
	creation.current_step = creation.CreationStep.SUMMARY
	creation._update_step_ui()
	creation.btn_next.pressed.emit()
	var c: Character = PlayerManager.get_player(0).get("character")
	h._assert(c != null and c.origin_feat == Batch051Checks.VIGIL and c.has_feature(Batch051Checks.WATCH) and int(c.feature_uses.get(Batch051Checks.WATCH, 0)) == 1, "051 actual Confirm creates the character with its chosen Origin feat and rule")
	h._teardown_scene(creation)
	if c == null:
		h._exit_test()
		return
	while c.level < 4: c.level_up()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	CharacterSheet.show_sheet(c)
	await h.get_tree().process_frame
	var feat_picker: OptionButton = null
	var take: Button = null
	for node in CharacterSheet._content.find_children("LevelFeatPicker", "OptionButton", true, false): feat_picker = node
	for node in CharacterSheet._content.find_children("LevelFeatTake", "Button", true, false): take = node
	var offered: Array = []
	if feat_picker != null:
		for i in feat_picker.item_count: offered.append(str(feat_picker.get_item_metadata(i)))
	h._assert(take != null and Batch051Checks.GRIT in offered and Batch051Checks.BRAINY not in offered and Batch051Checks.VIGIL not in offered, "051 actual the level-4 sheet offers qualifying feats in place of the improvement (%s)" % str(offered))
	if take != null:
		feat_picker.select(offered.find(Batch051Checks.GRIT))
		take.pressed.emit()
	await h.get_tree().process_frame
	h._assert(c.has_feature(Batch051Checks.STANCE) and ClassProgression.pending_improvements(c).is_empty() and int(c.feature_uses.get(Batch051Checks.STANCE, 0)) == 3, "051 actual Take feat instead spends the improvement and grants the feat's rule")
	CharacterSheet.close_sheet()
	FeatureModeRules.activate(c, Batch051Checks.STANCE, "brace")
	var modes := c.feature_modes.duplicate(true)
	var slot := "batch_051_feats"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "051 actual real save with both feats (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nc: Character = PartyManager.characters.get(c.character_id, null)
		h._assert(loaded and nc != null and nc != c and nc.origin_feat == Batch051Checks.VIGIL and nc.feature_modes == modes and int(nc.feature_uses[Batch051Checks.STANCE]) == 2 and nc.features.filter(func(f): return str(f.id) == Batch051Checks.STANCE).size() == 1, "051 actual real load keeps both feats, the active stance and its uses exactly once")
		var malformed: Dictionary = SaveManager._read_save(slot).duplicate(true)
		var bad_slot := slot + "_bad_ability"
		var bad_character: Dictionary = malformed.get("party", {}).get("characters", {}).get(c.character_id, {})
		bad_character.ability_scores["STR"] = 10
		bad_character.ability_scores["DEX"] = 10
		var bad_file := FileAccess.open(SaveManager.SAVE_DIR + bad_slot + ".sav", FileAccess.WRITE)
		if bad_file != null:
			bad_file.store_string(JSON.stringify(malformed))
			bad_file.close()
		h._assert(bad_file != null and not SaveManager.load_game(bad_slot) and PartyManager.characters.get(c.character_id) == nc and PlayerManager.get_player(0).get("character") == nc and nc.feature_modes == modes and int(nc.feature_uses[Batch051Checks.STANCE]) == 2, "051 actual unmet saved feat ability prerequisite refuses before replacing the live character, modes or uses")
		SaveManager.delete_save(bad_slot)
		SaveManager.delete_save(slot)
	h._exit_test()
