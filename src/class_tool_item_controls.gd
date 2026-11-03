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
## Real party save written by main 382ca63 (#80 tool items, no Explorer's Packs).
const PRE_PACK_FIXTURE := "res://data/fixtures/tool_items/main_382ca63_party.sav"
const PRE_PACK_SLOT := "class_tool_items_prepack"
const PRE_PACK_PLAYERS_SLOT := "class_tool_items_prepack_players"
const PRE_PACK_IDS := "user://class_tool_items_prepack_ids.txt"
## Real party save written by main de3891d (#81 packs, Druid without focus or Sickle).
const PRE_FOCUS_FIXTURE := "res://data/fixtures/tool_items/main_de3891d_party.sav"
const PRE_FOCUS_SLOT := "class_tool_items_prefocus"
const PRE_FOCUS_PLAYERS_SLOT := "class_tool_items_prefocus_players"
const PRE_FOCUS_IDS := "user://class_tool_items_prefocus_ids.txt"


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
	h._assert(creation.current_step == creation.CreationStep.SUMMARY and not creation.summary_equip_label.text.contains("Herbalism") and not creation.summary_equip_label.text.contains("Sickle") and not creation.summary_equip_label.text.contains("Explorer") and creation.summary_equip_label.text.contains("50 GP") and creation.summary_stats_label.text.contains("Herbalism"), "Druid gold-only review lists no kit but keeps Herbalism proficiency")
	creation.btn_back.pressed.emit()
	await h.get_tree().process_frame
	druid_equipment = creation.equip_list.get_node("DruidStartingEquipment")
	h._assert(druid_equipment.selected == 1, "Back preserves the gold-only choice")
	druid_equipment.select(0)
	druid_equipment.item_selected.emit(0)
	creation.btn_next.pressed.emit()
	h._assert(creation.summary_equip_label.text.count("Herbalism Kit") == 1 and creation.summary_equip_label.text.count("Explorer's Pack") == 1 and creation.summary_equip_label.text.count("Druidic Focus (Quarterstaff)") == 1 and creation.summary_equip_label.text.count("Sickle") == 1 and not creation.summary_equip_label.text.contains("- Quarterstaff") and creation.summary_equip_label.text.contains("9 GP"), "Cancelling gold restores one Druidic Focus (Quarterstaff), Sickle, Herbalism Kit, Explorer's Pack and 9 GP in review")
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var druid: Character = PlayerManager.get_player(0).get("character")
	h._assert(druid != null and ClassToolItemChecks.owned(druid) == ClassToolItemChecks.DRUID_A and druid.inventory.gold == 9 and druid.tool_proficiency_sources == {"herbalism_kit": ["class:druid"]} and druid.creation_choices.get("equipment", "") == "equipment", "Druid Confirm grants one kit copy, 9 GP and separate class-owned proficiency")
	h._assert(druid != null and druid.inventory.get_weapon() == ClassToolItemChecks.FOCUS and druid.inventory.get_equipped(Inventory.Slot.SHIELD) == "shield" and druid.inventory.backpack.count("sickle") == 1 and druid.inventory.has_required_spell_component(DataLoader.get_spell("water_walk"), "druid"), "Druid Confirm holds the focus beside the Shield (legal focus casting) and carries the Sickle")
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
	h._assert(lyre != null and ClassToolItemChecks.owned(lyre) == {"spear": 1, "dagger": 5, "lyre": 1, "explorers_pack": 1} and lyre.tool_proficiency_sources == {"lyre": ["class_choice:monk"]} and lyre.inventory.gold == 11, "Monk Confirm grants exactly one Lyre and its proficiency")
	# Monk 2: Smith's Tools.
	await _to_equipment(h, creation, "Tool Monk Smith", "monk")
	for pair in [["MonkSkill1", "Acrobatics"], ["MonkSkill2", "Insight"], ["MonkTool1", "smiths_tools"]]:
		h._select_creation_choice(creation.equip_list.get_node(pair[0]), pair[1])
	creation.btn_next.pressed.emit()
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var smith: Character = PlayerManager.get_player(2).get("character")
	h._assert(smith != null and ClassToolItemChecks.owned(smith) == {"spear": 1, "dagger": 5, "smiths_tools": 1, "explorers_pack": 1} and smith.tool_proficiency_sources == {"smiths_tools": ["class_choice:monk"]}, "A second Monk tool (Smith's Tools) is granted as its own single item")
	# Random Monk.
	creation.classes_data = [DataLoader.get_character_class("monk")]
	creation.btn_rand.pressed.emit()
	var random_tool := str(creation._class_choices().get("tools", [""])[0])
	h._assert(creation.current_step == creation.CreationStep.SUMMARY and not random_tool.is_empty() and creation.selected_equipment.count(random_tool) == 1, "Random Monk review includes its random tool as one item")
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var rand: Character = PlayerManager.get_player(3).get("character")
	h._assert(rand != null and ClassToolItemChecks.owned(rand) == {"spear": 1, "dagger": 5, random_tool: 1, "explorers_pack": 1} and rand.tool_proficiency_sources == {random_tool: ["class_choice:monk"]}, "Random Monk Confirm grants the displayed tool item once")
	var before := JSON.stringify(smith.inventory.to_dict())
	smith.initialize("Again", "human", "monk", AbilityScores.new(), "equipment", ClassProgression.default_creation_choices("monk", "human"))
	h._assert(JSON.stringify(smith.inventory.to_dict()) == before and smith.character_name == "Tool Monk Smith", "Repeat creation on a confirmed character is refused with no second item")
	var pack_id := ""
	for record in smith.inventory.backpack_instances():
		if str(record.definition_id) == "explorers_pack": pack_id = str(record.instance_id)
	h._assert(smith.inventory.expand_pack_instance(pack_id).get("success", false) and ClassToolItemChecks.owned(smith).get("torch", 0) == 10 and ClassToolItemChecks.owned(smith).get("rations", 0) == 10 and not ClassToolItemChecks.owned(smith).has("explorers_pack"), "The confirmed Monk's Explorer's Pack expands through the pack control before saving")
	h._teardown_scene(creation)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	h._assert(SaveManager.save_game(SLOT), "Tool-item party saves through the disk boundary")
	var players := SaveManager._read_save(SLOT)
	players.erase("party")
	h._assert(SaveManager._validate_save_data(players).is_empty() and _write(PLAYERS_SLOT, JSON.stringify(players)), "Player-only tool-item save validates and is written")
	_seed_old_main(h)
	_seed_pre_pack(h)
	_seed_pre_focus(h)
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
		h._assert(monk != null and druid != null and monk.inventory.count_item("flute") == 0 and druid.inventory.count_item("herbalism_kit") == 0 and not ClassToolItemChecks.owned(druid).has("sickle") and not ClassToolItemChecks.owned(druid).has("explorers_pack") and not ClassToolItemChecks.owned(monk).has("explorers_pack") and monk.tool_proficiencies == ["flute"] and druid.tool_proficiencies == ["herbalism_kit"], "%s: no retroactive tool items; proficiencies kept" % slot)
		h._assert(SaveManager.save_game(slot), "%s: old-main save re-saves" % slot)


static func _inventories() -> Dictionary:
	var result := {}
	for p in PlayerManager.get_player_count():
		var c: Character = PlayerManager.get_player(p).get("character")
		if c != null: result[c.character_id] = JSON.stringify(c.inventory.to_dict())
	return result


static func _no_pack() -> bool:
	for p in PlayerManager.get_player_count():
		var c: Character = PlayerManager.get_player(p).get("character")
		if c == null or ClassToolItemChecks.owned(c).has("explorers_pack") or ClassToolItemChecks.owned(c).has("sickle"): return false
	return PlayerManager.get_player_count() == 4


## Main 382ca63 saves: load, save; the fresh process reloads and saves again.
static func _seed_pre_pack(h: Node) -> void:
	var text := FileAccess.get_file_as_string(PRE_PACK_FIXTURE)
	var data: Variant = JSON.parse_string(text)
	h._assert(data is Dictionary and _write(PRE_PACK_SLOT, text), "382ca63 fixture save is copied in")
	if not data is Dictionary: return
	data.erase("party")
	h._assert(_write(PRE_PACK_PLAYERS_SLOT, JSON.stringify(data)), "382ca63 player-only save is derived")
	var seen := {}
	for slot in [PRE_PACK_SLOT, PRE_PACK_PLAYERS_SLOT]:
		h._assert(SaveManager.load_game(slot), "%s: 382ca63 save loads" % slot)
		h._assert(_no_pack(), "%s: no retroactive Explorer's Pack on load" % slot)
		seen = _inventories()
		h._assert(SaveManager.save_game(slot), "%s: 382ca63 save re-saves" % slot)
	var f := FileAccess.open(PRE_PACK_IDS, FileAccess.WRITE)
	f.store_string(JSON.stringify(seen))
	f.close()


static func _no_focus() -> bool:
	for p in PlayerManager.get_player_count():
		var c: Character = PlayerManager.get_player(p).get("character")
		if c == null or ClassToolItemChecks.owned(c).has(ClassToolItemChecks.FOCUS) or ClassToolItemChecks.owned(c).has("sickle"): return false
	return PlayerManager.get_player_count() == 4


## Main de3891d saves: load, save; the fresh process reloads and saves again.
static func _seed_pre_focus(h: Node) -> void:
	var text := FileAccess.get_file_as_string(PRE_FOCUS_FIXTURE)
	var data: Variant = JSON.parse_string(text)
	h._assert(data is Dictionary and _write(PRE_FOCUS_SLOT, text), "de3891d fixture save is copied in")
	if not data is Dictionary: return
	data.erase("party")
	h._assert(_write(PRE_FOCUS_PLAYERS_SLOT, JSON.stringify(data)), "de3891d player-only save is derived")
	var seen := {}
	for slot in [PRE_FOCUS_SLOT, PRE_FOCUS_PLAYERS_SLOT]:
		h._assert(SaveManager.load_game(slot), "%s: de3891d save loads" % slot)
		h._assert(_no_focus(), "%s: no retroactive Druidic Focus or Sickle on load" % slot)
		seen = _inventories()
		h._assert(SaveManager.save_game(slot), "%s: de3891d save re-saves" % slot)
	var f := FileAccess.open(PRE_FOCUS_IDS, FileAccess.WRITE)
	f.store_string(JSON.stringify(seen))
	f.close()


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
		h._assert(monk != null and druid != null and monk.inventory.count_item("flute") == 0 and druid.inventory.count_item("herbalism_kit") == 0 and not ClassToolItemChecks.owned(druid).has("sickle") and not ClassToolItemChecks.owned(druid).has("explorers_pack") and not ClassToolItemChecks.owned(monk).has("explorers_pack") and monk.tool_proficiency_sources == {"flute": ["class_choice:monk"]}, "%s fresh process: still no retroactive items" % slot)
		h._assert(SaveManager.save_game(slot), "%s fresh process: saves again" % slot)
		SaveManager.delete_save(slot)
	var pre: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRE_PACK_IDS))
	for slot in [PRE_PACK_SLOT, PRE_PACK_PLAYERS_SLOT]:
		h._assert(SaveManager.load_game(slot), "%s: fresh process loads the re-saved 382ca63 save" % slot)
		h._assert(_no_pack() and pre is Dictionary and _inventories() == pre, "%s fresh process: exact inventories, still no retroactive pack" % slot)
		h._assert(SaveManager.save_game(slot) and SaveManager.load_game(slot) and _inventories() == pre, "%s fresh process: saves again unchanged" % slot)
		SaveManager.delete_save(slot)
	var pre_focus: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRE_FOCUS_IDS))
	for slot in [PRE_FOCUS_SLOT, PRE_FOCUS_PLAYERS_SLOT]:
		h._assert(SaveManager.load_game(slot), "%s: fresh process loads the re-saved de3891d save" % slot)
		h._assert(_no_focus() and pre_focus is Dictionary and _inventories() == pre_focus, "%s fresh process: exact inventories, still no retroactive focus or Sickle" % slot)
		h._assert(SaveManager.save_game(slot) and SaveManager.load_game(slot) and _inventories() == pre_focus, "%s fresh process: saves again unchanged" % slot)
		SaveManager.delete_save(slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PRE_FOCUS_IDS))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PRE_PACK_IDS))
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
