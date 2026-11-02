## Class tool items through real creation controls (SRD 5.2.1 Druid/Monk
## Starting Equipment option A), real saves, and a fresh-process reload probe.
class_name ClassToolItemControls
extends RefCounted

const SLOT := "class_tool_items"
const PLAYERS_SLOT := "class_tool_items_players"
const OLD_SLOT := "class_tool_items_oldmain"
const OLD_PLAYERS_SLOT := "class_tool_items_oldmain_players"
const OLD_FIXTURE := "res://data/fixtures/tool_items/main_897d994_party.sav"
const IDS := "user://class_tool_items_ids.txt"


static func run(h: Node) -> void:
	h._enter_test("class_tool_items_flow")
	h._setup_world()
	PlayerManager.reset()
	PartyManager.reset()
	for seat in ["Druid seat", "Monk lyre seat", "Monk smith seat", "Random seat"]:
		PlayerManager.add_player(seat)
	GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
	var creation: Node = await h._spawn_scene("res://scenes/ui/character_creation.tscn", 0.2)
	# Druid: option B shows no kit, cancel back to A shows one kit.
	await _to_equipment(h, creation, "Tool Druid", "druid")
	for pair in [["DruidSkill1", "Medicine"], ["DruidSkill2", "Nature"]]:
		h._select_creation_choice(creation.equip_list.get_node(pair[0]), pair[1])
	var druid_equipment: OptionButton = creation.equip_list.get_node_or_null("DruidStartingEquipment")
	h._assert(druid_equipment != null and druid_equipment.item_count == 2 and druid_equipment.get_item_text(0).contains("9 GP") and druid_equipment.get_item_text(1) == "50 GP", "Druid offers SRD option A (equipment and 9 GP) or B (50 GP)")
	if druid_equipment == null:
		h._teardown_scene(creation)
		h._exit_test()
		return
	druid_equipment.select(1)
	druid_equipment.item_selected.emit(1)
	creation.btn_next.pressed.emit()
	h._assert(creation.current_step == creation.CreationStep.SUMMARY and not creation.summary_equip_label.text.contains("Herbalism") and creation.summary_equip_label.text.contains("50 GP") and creation.summary_stats_label.text.contains("Herbalism"), "Druid gold-only review lists no kit but keeps Herbalism proficiency")
	creation.btn_back.pressed.emit()
	await h.get_tree().process_frame
	druid_equipment = creation.equip_list.get_node("DruidStartingEquipment")
	h._assert(druid_equipment.selected == 1, "Back preserves the gold-only choice")
	druid_equipment.select(0)
	druid_equipment.item_selected.emit(0)
	creation.btn_next.pressed.emit()
	h._assert(creation.summary_equip_label.text.count("Herbalism Kit") == 1 and creation.summary_equip_label.text.contains("9 GP"), "Cancelling gold restores one Herbalism Kit and 9 GP in review")
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var druid: Character = PlayerManager.get_player(0).get("character")
	h._assert(druid != null and druid.inventory.count_item("herbalism_kit") == 1 and druid.inventory.gold == 9 and druid.tool_proficiency_sources == {"herbalism_kit": ["class:druid"]} and druid.creation_choices.get("equipment", "") == "equipment", "Druid Confirm grants one kit copy, 9 GP and separate class-owned proficiency")
	h._assert(creation.current_player_idx == 1 and creation.class_creation_choices.is_empty(), "Seat reset: the next seat starts with no class or equipment choices")
	# Monk 1: picks Smith's Tools, Back, switches to Lyre.
	await _to_equipment(h, creation, "Tool Monk Lyre", "monk")
	h._assert(creation._class_choices().get("equipment", "") == "equipment" and creation.equip_list.get_node_or_null("MonkStartingEquipment") != null, "Reset seat defaults to option A and shows the Monk equipment choice")
	for pair in [["MonkSkill1", "Athletics"], ["MonkSkill2", "Stealth"], ["MonkTool1", "smiths_tools"]]:
		h._select_creation_choice(creation.equip_list.get_node(pair[0]), pair[1])
	creation.btn_next.pressed.emit()
	h._assert(creation.summary_equip_label.text.contains("Smith") and creation.summary_equip_label.text.contains("11 GP"), "Monk review lists the chosen Smith's Tools item")
	creation.btn_back.pressed.emit()
	await h.get_tree().process_frame
	h._select_creation_choice(creation.equip_list.get_node("MonkTool1"), "lyre")
	creation._class_choices()["equipment"] = "pack"
	creation._check_next_step_validity()
	h._assert(creation.btn_next.disabled or not creation._creation_choice_error().is_empty(), "An unknown equipment option is refused before review")
	creation._confirm_and_save_character()
	h._assert(PlayerManager.get_player(1).get("character") == null, "Confirm with an invalid equipment option grants nothing")
	creation._class_choices()["equipment"] = "equipment"
	creation._build_equipment_ui()
	creation._check_next_step_validity()
	creation.btn_next.pressed.emit()
	h._assert(creation.summary_equip_label.text.contains("Lyre") and not creation.summary_equip_label.text.contains("Smith"), "After Back the review lists only the newly chosen Lyre")
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var lyre: Character = PlayerManager.get_player(1).get("character")
	h._assert(lyre != null and lyre.inventory.count_item("lyre") == 1 and lyre.inventory.count_item("smiths_tools") == 0 and lyre.tool_proficiency_sources == {"lyre": ["class_choice:monk"]} and lyre.inventory.gold == 11, "Monk Confirm grants exactly one Lyre and its proficiency")
	# Monk 2: Smith's Tools.
	await _to_equipment(h, creation, "Tool Monk Smith", "monk")
	for pair in [["MonkSkill1", "Acrobatics"], ["MonkSkill2", "Insight"], ["MonkTool1", "smiths_tools"]]:
		h._select_creation_choice(creation.equip_list.get_node(pair[0]), pair[1])
	creation.btn_next.pressed.emit()
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var smith: Character = PlayerManager.get_player(2).get("character")
	h._assert(smith != null and smith.inventory.count_item("smiths_tools") == 1 and smith.inventory.count_item("lyre") == 0 and smith.tool_proficiency_sources == {"smiths_tools": ["class_choice:monk"]}, "A second Monk tool (Smith's Tools) is granted as its own single item")
	# Random Monk.
	creation.classes_data = [DataLoader.get_character_class("monk")]
	creation.btn_rand.pressed.emit()
	var random_tool := str(creation._class_choices().get("tools", [""])[0])
	h._assert(creation.current_step == creation.CreationStep.SUMMARY and not random_tool.is_empty() and creation.selected_equipment.count(random_tool) == 1, "Random Monk review includes its random tool as one item")
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var rand: Character = PlayerManager.get_player(3).get("character")
	h._assert(rand != null and rand.inventory.count_item(random_tool) == 1 and rand.tool_proficiency_sources == {random_tool: ["class_choice:monk"]}, "Random Monk Confirm grants the displayed tool item once")
	var before := JSON.stringify(smith.inventory.to_dict())
	smith.initialize("Again", "human", "monk", AbilityScores.new(), "equipment", ClassProgression.default_creation_choices("monk", "human"))
	h._assert(JSON.stringify(smith.inventory.to_dict()) == before and smith.character_name == "Tool Monk Smith", "Repeat creation on a confirmed character is refused with no second item")
	h._teardown_scene(creation)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	h._assert(SaveManager.save_game(SLOT), "Tool-item party saves through the disk boundary")
	var players := SaveManager._read_save(SLOT)
	players.erase("party")
	h._assert(SaveManager._validate_save_data(players).is_empty() and _write(PLAYERS_SLOT, JSON.stringify(players)), "Player-only tool-item save validates and is written")
	_seed_old_main(h)
	var f := FileAccess.open(IDS, FileAccess.WRITE)
	var ids := []
	for c in [druid, lyre, smith, rand]:
		ids.append("%s=%s" % [c.character_id, JSON.stringify(c.inventory.to_dict())])
	f.store_string("\n".join(ids))
	f.close()
	h._exit_test()


## Real saves written by main 897d994 (Monk Flute and Druid without items).
static func _seed_old_main(h: Node) -> void:
	var text := FileAccess.get_file_as_string(OLD_FIXTURE)
	var data: Variant = JSON.parse_string(text)
	h._assert(data is Dictionary and _write(OLD_SLOT, text), "Old-main fixture save is copied in")
	if not data is Dictionary: return
	data.erase("party")
	h._assert(_write(OLD_PLAYERS_SLOT, JSON.stringify(data)), "Old-main player-only save is derived")
	for slot in [OLD_SLOT, OLD_PLAYERS_SLOT]:
		h._assert(SaveManager.load_game(slot), "%s: old-main save loads" % slot)
		var monk: Character = PlayerManager.get_player(0).get("character")
		var druid: Character = PlayerManager.get_player(1).get("character")
		h._assert(monk != null and druid != null and monk.inventory.count_item("flute") == 0 and druid.inventory.count_item("herbalism_kit") == 0 and monk.tool_proficiencies == ["flute"] and druid.tool_proficiencies == ["herbalism_kit"], "%s: no retroactive tool items; proficiencies kept" % slot)
		h._assert(SaveManager.save_game(slot), "%s: old-main save re-saves" % slot)


static func reload(h: Node) -> void:
	h._enter_test("class_tool_items_reload")
	var expected := {}
	for line in FileAccess.get_file_as_string(IDS).strip_edges().split("\n"):
		var parts := line.split("=", false, 1)
		if parts.size() == 2: expected[parts[0]] = parts[1]
	h._assert(expected.size() == 4, "Fresh process reads the tool-item checkpoint")
	for slot in [SLOT, PLAYERS_SLOT]:
		h._assert(SaveManager.load_game(slot), "%s: fresh process loads" % slot)
		for pass_index in 2:
			var matched := 0
			for p in PlayerManager.get_player_count():
				var c: Character = PlayerManager.get_player(p).get("character")
				if c != null and expected.get(c.character_id, "") == JSON.stringify(c.inventory.to_dict()) and c.tool_proficiencies.size() == 1:
					matched += 1
			var party_ok: bool = slot != SLOT or PartyManager.characters.size() >= 4
			h._assert(matched == 4 and party_ok, "%s round %d: every seat keeps its exact items and proficiency, no replay" % [slot, pass_index + 1])
			h._assert(SaveManager.save_game(slot) and SaveManager.load_game(slot), "%s round %d: saves and reloads" % [slot, pass_index + 1])
		SaveManager.delete_save(slot)
	for slot in [OLD_SLOT, OLD_PLAYERS_SLOT]:
		h._assert(SaveManager.load_game(slot), "%s: fresh process loads the re-saved old-main save" % slot)
		var monk: Character = PlayerManager.get_player(0).get("character")
		var druid: Character = PlayerManager.get_player(1).get("character")
		h._assert(monk != null and druid != null and monk.inventory.count_item("flute") == 0 and druid.inventory.count_item("herbalism_kit") == 0 and monk.tool_proficiency_sources == {"flute": ["class_choice:monk"]}, "%s fresh process: still no retroactive items" % slot)
		h._assert(SaveManager.save_game(slot), "%s fresh process: saves again" % slot)
		SaveManager.delete_save(slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	h._exit_test()


static func _write(slot: String, text: String) -> bool:
	var file := FileAccess.open(SaveManager.SAVE_DIR + slot + ".sav", FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_DIR + slot + ".sav.bak"))
	return true


static func _to_equipment(h: Node, creation: Node, name: String, class_id: String) -> void:
	creation.selected_name = name
	creation.selected_race_id = "human"
	creation.selected_class_id = class_id
	creation.class_creation_choices = {}
	creation.current_step = creation.CreationStep.EQUIPMENT
	creation._update_step_ui()
	await h.get_tree().process_frame
