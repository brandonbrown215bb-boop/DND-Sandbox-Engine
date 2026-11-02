## G4 production flow for Skilled (SRD 5.2.1 p.87): Origin pick at creation, a
## repeat at a level-4 Ability Score Improvement on the sheet, real save, and a
## fresh-process reload probe that consumes the checkpoint.
class_name SkilledFeatControls
extends RefCounted

const SLOT := "skilled_feat_creation"
const IDS := "user://skilled_feat_creation_ids.txt"
const ORIGIN_PICKS := ["Insight", "Stealth", "thieves_tools"]
const MONK_SKILLS := ["Athletics", "Acrobatics"]

static func run(h: Node) -> void:
	h._enter_test("skilled_feat_creation_flow")
	h._setup_world()
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Skilled seat")
	GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
	var creation: Node = await h._spawn_scene("res://scenes/ui/character_creation.tscn", 0.2)
	creation.selected_name = "G4 Skilled Monk"
	creation.selected_race_id = "human"
	creation.selected_class_id = "monk"
	creation.class_creation_choices = {}
	creation.current_step = creation.CreationStep.EQUIPMENT
	creation._update_step_ui()
	await h.get_tree().process_frame
	h._select_creation_choice(creation.equip_list.get_node("MonkSkill1"), MONK_SKILLS[0])
	h._select_creation_choice(creation.equip_list.get_node("MonkSkill2"), MONK_SKILLS[1])
	h._select_creation_choice(creation.equip_list.get_node("MonkTool1"), "flute")
	var picker: OptionButton = creation.equip_list.get_node_or_null("OriginFeatPicker")
	h._assert(picker != null and str(picker.get_item_metadata(picker.selected)) == "" and not creation.btn_next.disabled, "G4 creation offers Origin feats with no feat preselected")
	if picker == null:
		h._exit_test()
		return
	h._select_creation_choice(picker, "skilled")
	await h.get_tree().process_frame
	h._assert(creation.equip_list.get_node_or_null("OriginFeatProficiency3") != null and creation.btn_next.disabled, "G4 choosing Skilled shows three pickers and blocks Next until they are filled")
	var first: OptionButton = creation.equip_list.get_node("OriginFeatProficiency1")
	var class_skill_disabled := false
	for i in first.item_count:
		if str(first.get_item_metadata(i)) == MONK_SKILLS[0]: class_skill_disabled = first.is_item_disabled(i)
	h._assert(class_skill_disabled, "G4 a skill the class already grants cannot be picked again")
	for i in 3:
		h._select_creation_choice(creation.equip_list.get_node("OriginFeatProficiency%d" % (i + 1)), ORIGIN_PICKS[i])
	h._select_creation_choice(creation.equip_list.get_node("OriginFeatProficiency2"), ORIGIN_PICKS[0])
	h._assert(creation.btn_next.disabled, "G4 a duplicate Skilled pick keeps Next disabled")
	h._select_creation_choice(creation.equip_list.get_node("OriginFeatProficiency2"), ORIGIN_PICKS[1])
	h._assert(not creation.btn_next.disabled, "G4 three distinct picks enable Next")
	creation.btn_next.pressed.emit()
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var c: Character = PlayerManager.get_player(0).get("character")
	h._assert(c != null and c.origin_feat == "skilled" and c.skill_proficiencies.count("Insight") == 1 and c.skill_proficiencies.count("Stealth") == 1 and c.tool_proficiency_sources.get("thieves_tools", []) == ["feat:skilled@origin"] and c.tool_proficiency_sources.get("flute", []) == ["class_choice:monk"] and c.inventory.count_item("thieves_tools") == 0, "G4 Confirm grants the Skilled picks once, owned by the Origin instance, with no item")
	h._teardown_scene(creation)
	if c == null:
		h._exit_test()
		return
	while c.level < 4: c.level_up()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var pending := ClassProgression.pending_improvements(c)
	CharacterSheet.show_sheet(c)
	await h.get_tree().process_frame
	var level_picker: OptionButton = null
	var take: Button = null
	for node in CharacterSheet._content.find_children("LevelFeatPicker", "OptionButton", true, false): level_picker = node
	for node in CharacterSheet._content.find_children("LevelFeatTake", "Button", true, false): take = node
	var skilled_index := -1
	if level_picker != null:
		for i in level_picker.item_count:
			if str(level_picker.get_item_metadata(i)) == "skilled": skilled_index = i
	h._assert(take != null and skilled_index >= 0 and pending.size() == 1, "G4 the level-4 sheet offers Skilled again (Repeatable)")
	if take != null and skilled_index >= 0:
		level_picker.select(skilled_index)
		level_picker.item_selected.emit(skilled_index)
		take.pressed.emit()
		await h.get_tree().process_frame
		h._assert(ClassProgression.pending_improvements(c) == pending and c.feat_proficiency_choices.size() == 1, "G4 Take with empty picks is refused and the improvement stays pending")
		var values := ["Perception", "Stealth", "lute"]
		for i in 3:
			for node in CharacterSheet._content.find_children("LevelFeatProficiency%d" % (i + 1), "OptionButton", true, false):
				for j in node.item_count:
					if str(node.get_item_metadata(j)) == values[i]: node.select(j)
		take.pressed.emit()
		await h.get_tree().process_frame
		h._assert(ClassProgression.pending_improvements(c) == pending and "Perception" not in c.skill_proficiencies, "G4 a repeat that re-picks an owned skill (Stealth) is refused without partial grants")
		CharacterSheet.close_sheet()
		CharacterSheet.show_sheet(c)
		await h.get_tree().process_frame
		for node in CharacterSheet._content.find_children("LevelFeatPicker", "OptionButton", true, false): level_picker = node
		for node in CharacterSheet._content.find_children("LevelFeatTake", "Button", true, false): take = node
		for i in level_picker.item_count:
			if str(level_picker.get_item_metadata(i)) == "skilled": skilled_index = i
		level_picker.select(skilled_index)
		level_picker.item_selected.emit(skilled_index)
		values = ["Perception", "History", "lute"]
		for i in 3:
			for node in CharacterSheet._content.find_children("LevelFeatProficiency%d" % (i + 1), "OptionButton", true, false):
				for j in node.item_count:
					if str(node.get_item_metadata(j)) == values[i]: node.select(j)
		take.pressed.emit()
		await h.get_tree().process_frame
	var asi := str(pending[0]) if not pending.is_empty() else ""
	h._assert(ClassProgression.pending_improvements(c).is_empty() and c.feat_proficiency_choices.get(asi, {}).get("skills", []) == ["Perception", "History"] and c.tool_proficiency_sources.get("lute", []) == ["feat:skilled@" + asi], "G4 Take feat instead records the second Skilled as its own instance (%s)" % asi)
	CharacterSheet.close_sheet()
	h._assert(SaveManager.save_game(SLOT), "G4 two-instance Skilled party saves through the disk boundary")
	var tampered: Dictionary = SaveManager._read_save(SLOT)
	tampered["party"]["characters"][c.character_id]["feat_proficiency_choices"].erase(asi)
	h._assert(not SaveManager._validate_save_data(tampered).is_empty(), "G4 a save missing one Skilled instance's picks is refused")
	tampered = SaveManager._read_save(SLOT)
	tampered["players"][0]["character"]["tool_proficiency_sources"]["lute"] = ["feat:skilled@origin"]
	h._assert(not SaveManager._validate_save_data(tampered).is_empty(), "G4 a save that moves a pick to the other instance is refused")
	var f := FileAccess.open(IDS, FileAccess.WRITE)
	f.store_string("|".join([c.character_id, asi, JSON.stringify(c.skill_proficiencies), JSON.stringify(c.tool_proficiency_sources)]))
	f.close()
	h._exit_test()


static func reload(h: Node) -> void:
	h._enter_test("skilled_feat_creation_reload")
	var p := FileAccess.get_file_as_string(IDS).strip_edges().split("|")
	h._assert(p.size() == 4 and SaveManager.load_game(SLOT), "G4 fresh process loads the Skilled save")
	if p.size() != 4:
		h._exit_test()
		return
	var c: Character = PartyManager.characters.get(p[0], null)
	h._assert(c != null and JSON.stringify(c.skill_proficiencies) == p[2] and JSON.stringify(c.tool_proficiency_sources) == p[3] and c.feat_proficiency_choices.size() == 2 and c.feat_proficiency_choices[p[1]].tools == ["lute"] and ClassProgression.pending_improvements(c).is_empty(), "G4 fresh process keeps both Skilled instances and owners without replay")
	h._assert(SaveManager.save_game(SLOT) and SaveManager.load_game(SLOT), "G4 fresh process saves and loads again")
	var again: Character = PartyManager.characters.get(p[0], null)
	h._assert(again != null and JSON.stringify(again.skill_proficiencies) == p[2] and JSON.stringify(again.tool_proficiency_sources) == p[3], "G4 second round trip is unchanged")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	h._exit_test()
