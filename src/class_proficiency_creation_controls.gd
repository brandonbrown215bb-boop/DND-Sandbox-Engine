## G2 production creation flow for class skill/tool proficiency choices, plus a
## fresh-process reload probe that consumes the saved checkpoint.
class_name ClassProficiencyCreationControls
extends RefCounted

const SLOT := "class_proficiency_creation"
const IDS := "user://class_proficiency_creation_ids.txt"


static func run(h: Node) -> void:
	h._enter_test("class_proficiency_creation_flow")
	h._setup_world()
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Monk seat")
	PlayerManager.add_player("Druid seat")
	PlayerManager.add_player("Random seat")
	GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
	var creation: Node = await h._spawn_scene("res://scenes/ui/character_creation.tscn", 0.2)
	await _to_equipment(h, creation, "G2 Monk", "monk")
	h._assert(creation.btn_next.disabled, "Monk creation waits for explicit skills and tool choice")
	for pair in [["MonkSkill1", "Athletics"], ["MonkSkill2", "Stealth"], ["MonkTool1", "flute"]]:
		h._select_creation_choice(creation.equip_list.get_node(pair[0]), pair[1])
	h._select_creation_choice(creation.equip_list.get_node("MonkSkill2"), "Athletics")
	h._assert(creation.btn_next.disabled, "Duplicate Monk skills keep Next disabled")
	h._select_creation_choice(creation.equip_list.get_node("MonkSkill2"), "Stealth")
	h._assert(not creation.btn_next.disabled, "Valid Monk choices enable Next")
	creation.btn_next.pressed.emit()
	h._assert(creation.current_step == creation.CreationStep.SUMMARY and creation.summary_stats_label.text.contains("Flute") and creation.summary_stats_label.text.contains("Athletics, Stealth"), "Monk review shows the chosen tool and skills")
	creation.btn_back.pressed.emit()
	await h.get_tree().process_frame
	h._assert(creation.class_creation_choices.get("tools", []) == ["flute"] and not creation.btn_next.disabled, "Back preserves Monk choices")
	creation.btn_next.pressed.emit()
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var monk: Character = PlayerManager.get_player(0).get("character")
	h._assert(monk != null and monk.tool_proficiency_sources == {"flute": ["class_choice:monk"]} and monk.inventory.count_item("flute") == 0 and monk.skill_proficiencies.has("Stealth"), "Monk Confirm grants the chosen tool proficiency once, without the item")
	h._assert(creation.current_player_idx == 1 and creation.class_creation_choices.is_empty(), "The next seat starts with fresh class choices")
	await _to_equipment(h, creation, "G2 Druid", "druid")
	h._assert(creation.equip_list.get_node_or_null("DruidTool1") == null, "Druid has no tool picker; Herbalism Kit is fixed")
	for pair in [["DruidSkill1", "Medicine"], ["DruidSkill2", "Nature"]]:
		h._select_creation_choice(creation.equip_list.get_node(pair[0]), pair[1])
	creation.btn_next.pressed.emit()
	h._assert(creation.summary_stats_label.text.contains("Herbalism"), "Druid review shows the fixed Herbalism Kit proficiency")
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var druid: Character = PlayerManager.get_player(1).get("character")
	h._assert(druid != null and druid.tool_proficiency_sources == {"herbalism_kit": ["class:druid"]} and druid.skill_proficiencies.has("Nature"), "Druid Confirm grants class-owned Herbalism Kit proficiency")
	creation.classes_data = [DataLoader.get_character_class("rogue")]
	creation.btn_rand.pressed.emit()
	h._assert(creation.current_step == creation.CreationStep.SUMMARY and creation._creation_choice_error().is_empty(), "Random Rogue fills valid distinct skills and reaches review")
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var rogue: Character = PlayerManager.get_player(2).get("character")
	h._assert(rogue != null and rogue.creation_choices.get("skills", []).size() == 4 and rogue.tool_proficiency_sources == {"thieves_tools": ["class:rogue"]}, "Random Rogue Confirm grants the displayed skills and Thieves' Tools")
	h._teardown_scene(creation)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	h._assert(SaveManager.save_game(SLOT), "G2 party saves through the disk boundary")
	var malformed: Dictionary = SaveManager._read_save(SLOT)
	malformed["players"][0]["character"]["tool_proficiency_sources"] = {"flute": ["class_choice:monk"], "lute": ["class_choice:monk"]}
	h._assert(not SaveManager._validate_save_data(malformed).is_empty() and PlayerManager.get_player(0).get("character") == monk, "A stale player tool source is refused before mutation")
	malformed = SaveManager._read_save(SLOT)
	malformed["party"]["characters"][druid.character_id]["tool_proficiency_sources"] = {"herbalism_kit": ["class:rogue"]}
	h._assert(not SaveManager._validate_save_data(malformed).is_empty(), "A party record with another class's source is refused")
	var f := FileAccess.open(IDS, FileAccess.WRITE)
	f.store_string("|".join([monk.character_id, druid.character_id, rogue.character_id, JSON.stringify(monk.inventory.to_dict()), str(rogue.inventory.count_item("thieves_tools"))]))
	f.close()
	h._exit_test()


static func reload(h: Node) -> void:
	h._enter_test("class_proficiency_creation_reload")
	var p := FileAccess.get_file_as_string(IDS).strip_edges().split("|")
	h._assert(p.size() == 5 and SaveManager.load_game(SLOT), "G2 fresh process loads the saved party")
	if p.size() != 5:
		h._exit_test()
		return
	var monk: Character = PartyManager.characters.get(p[0], null)
	var druid: Character = PartyManager.characters.get(p[1], null)
	var rogue: Character = PartyManager.characters.get(p[2], null)
	h._assert(monk != null and monk.tool_proficiencies == ["flute"] and monk.tool_proficiency_sources == {"flute": ["class_choice:monk"]} and JSON.stringify(monk.inventory.to_dict()) == p[3], "Fresh process: Monk choice survives without replaying grants or items")
	h._assert(druid != null and druid.tool_proficiencies == ["herbalism_kit"] and CheckHelpRules.owns(druid, "tool", "herbalism_kit"), "Fresh process: Druid Herbalism proficiency is usable for Help")
	h._assert(rogue != null and rogue.tool_proficiencies == ["thieves_tools"] and rogue.inventory.count_item("thieves_tools") == int(p[4]), "Fresh process: Rogue Thieves' Tools listed once with no extra item")
	if druid != null:
		await h.get_tree().process_frame
		CharacterSheet.show_sheet(druid)
		var text := ""
		for label in CharacterSheet._content.find_children("*", "Label", true, false):
			text += label.text + "\n"
		h._assert(text.contains("Tool Proficiencies") and text.contains("Herbalism"), "Fresh process: the sheet shows Herbalism Kit proficiency")
		CharacterSheet.close_sheet()
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	h._exit_test()


static func _to_equipment(h: Node, creation: Node, name: String, class_id: String) -> void:
	creation.selected_name = name
	creation.selected_race_id = "human"
	creation.selected_class_id = class_id
	creation.class_creation_choices = {}
	creation.current_step = creation.CreationStep.EQUIPMENT
	creation._update_step_ui()
	await h.get_tree().process_frame
