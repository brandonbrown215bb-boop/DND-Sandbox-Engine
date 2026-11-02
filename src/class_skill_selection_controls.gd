## PR C production creation flow: class skill picks for Barbarian, Fighter,
## Paladin, Ranger, Sorcerer, Warlock and Wizard (SRD 5.2.1 Core Traits), with
## Back, Random, fresh seats and a fresh-process reload probe.
class_name ClassSkillSelectionControls
extends RefCounted

const SLOTS := ["class_skill_selection_a", "class_skill_selection_b"]
const IDS := "user://class_skill_selection_ids.txt"
const IDS_B := "user://class_skill_selection_ids_b.txt"

static func run(h: Node) -> void:
	h._enter_test("class_skill_selection_flow")
	h._setup_world()
	var ids := []
	# Pass A: Barbarian (75 GP), Fighter (changed picks + Back), Ranger, Random Wizard.
	var creation: Node = await _begin(h, ["Barbarian seat", "Fighter seat", "Ranger seat", "Random seat"])
	await _to_equipment(h, creation, "C Barbarian", "barbarian", "human")
	h._assert(creation.btn_next.disabled and creation.equip_list.get_node_or_null("BarbarianStartingEquipment") != null, "Barbarian waits for two class skills and keeps one A/B equipment selector")
	h._select_creation_choice(creation.equip_list.get_node("BarbarianSkill1"), "Athletics")
	h._select_creation_choice(creation.equip_list.get_node("BarbarianSkill2"), "Athletics")
	h._assert(creation.btn_next.disabled, "Duplicate Barbarian skills keep Next disabled")
	h._select_creation_choice(creation.equip_list.get_node("BarbarianSkill2"), "Survival")
	var equipment: OptionButton = creation.equip_list.get_node("BarbarianStartingEquipment")
	equipment.select(1)
	equipment.item_selected.emit(1)
	await h.get_tree().process_frame
	h._assert(creation.class_creation_choices.get("skills", []) == ["Athletics", "Survival"] and not creation.btn_next.disabled, "Barbarian picks survive switching to 75 GP")
	creation.btn_next.pressed.emit()
	h._assert(creation.summary_stats_label.text.contains("Athletics, Survival"), "Barbarian review shows the chosen skills")
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var barbarian: Character = PlayerManager.get_player(0).get("character")
	h._assert(barbarian != null and barbarian.inventory.gold == 75 and barbarian.creation_choices.get("skills", []) == ["Athletics", "Survival"] and barbarian.skill_proficiencies.count("Athletics") == 1, "Barbarian Confirm grants picks once with option B gold")
	h._assert(creation.current_player_idx == 1 and creation.class_creation_choices.is_empty(), "Next seat starts with fresh class choices")
	await _to_equipment(h, creation, "C Fighter", "fighter", "elf")
	h._assert(creation.class_creation_choices.get("skills", []) == ["Athletics", ""] and creation.btn_next.disabled, "Elf Fighter preselects Athletics and leaves species Perception unpicked")
	h._select_creation_choice(creation.equip_list.get_node("FighterSkill1"), "History")
	h._select_creation_choice(creation.equip_list.get_node("FighterSkill2"), "Insight")
	creation.btn_next.pressed.emit()
	creation.btn_back.pressed.emit()
	await h.get_tree().process_frame
	h._assert(creation.class_creation_choices.get("skills", []) == ["History", "Insight"] and not creation.btn_next.disabled, "Back preserves Fighter picks")
	creation.btn_next.pressed.emit()
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var fighter: Character = PlayerManager.get_player(1).get("character")
	h._assert(fighter != null and fighter.fighter_training.get("skills", []) == ["History", "Insight"] and "Athletics" not in fighter.skill_proficiencies and fighter.skill_proficiencies.count("Perception") == 1, "Fighter picks become the two training skills; no extra class skills")
	await _to_equipment(h, creation, "C Ranger", "ranger", "human")
	for pair in [["RangerSkill1", "Nature"], ["RangerSkill2", "Stealth"]]:
		h._select_creation_choice(creation.equip_list.get_node(pair[0]), pair[1])
	h._assert(creation.btn_next.disabled, "Ranger needs a third skill")
	h._select_creation_choice(creation.equip_list.get_node("RangerSkill3"), "Survival")
	creation.btn_next.pressed.emit()
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var ranger: Character = PlayerManager.get_player(2).get("character")
	h._assert(ranger != null and ranger.creation_choices.get("skills", []) == ["Nature", "Stealth", "Survival"], "Ranger Confirm grants three picks")
	var wizard: Character = await _random(h, creation, "wizard", 3)
	await _save(h, creation, SLOTS[0])
	ids.append_array([barbarian.character_id, fighter.character_id, ranger.character_id, wizard.character_id])
	_store(IDS, ids)
	h._exit_test()

## Pass B runs in its own process: the finished pass A party changes scene.
static func run_b(h: Node) -> void:
	h._enter_test("class_skill_selection_flow_b")
	h._setup_world()
	var creation: Node = await _begin(h, ["Paladin seat", "Sorcerer seat", "Random seat"])
	var made := []
	for spec in [["paladin", ["Insight", "Religion"]], ["sorcerer", ["Arcana", "Deception"]]]:
		await _to_equipment(h, creation, "C " + spec[0], spec[0], "human")
		var label: String = spec[0].capitalize()
		h._assert(creation.btn_next.disabled, "%s waits for class skills" % label)
		for index in spec[1].size():
			h._select_creation_choice(creation.equip_list.get_node("%sSkill%d" % [label, index + 1]), spec[1][index])
		creation.btn_next.pressed.emit()
		creation.btn_next.pressed.emit()
		await h.get_tree().process_frame
		var c: Character = PlayerManager.get_player(made.size()).get("character")
		h._assert(c != null and c.class_id == spec[0] and c.creation_choices.get("skills", []) == spec[1], "%s Confirm grants its picks" % label)
		made.append(c.character_id if c != null else "")
	var warlock: Character = await _random(h, creation, "warlock", 2)
	await _save(h, creation, SLOTS[1])
	_store(IDS_B, made + [warlock.character_id])
	h._exit_test()

static func _store(path: String, ids: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("|".join(ids))
	f.close()

static func _begin(h: Node, seats: Array) -> Node:
	PlayerManager.reset()
	PartyManager.reset()
	for seat in seats:
		PlayerManager.add_player(seat)
	GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
	return await h._spawn_scene("res://scenes/ui/character_creation.tscn", 0.2)

static func _random(h: Node, creation: Node, class_id: String, seat: int) -> Character:
	creation.classes_data = [DataLoader.get_character_class(class_id)]
	creation.btn_rand.pressed.emit()
	var picks: Array = creation.class_creation_choices.get("skills", [])
	var contract: Dictionary = DataLoader.get_character_class(class_id).skill_choices
	h._assert(creation.current_step == creation.CreationStep.SUMMARY and creation._creation_choice_error().is_empty() and picks.size() == int(contract.pick) and picks.all(func(s): return s in contract.from and picks.count(s) == 1), "Random %s fills valid distinct class skills" % class_id)
	creation.btn_next.pressed.emit()
	await h.get_tree().process_frame
	var c: Character = PlayerManager.get_player(seat).get("character")
	h._assert(c != null and c.creation_choices.get("skills", []) == picks and picks.all(func(s): return c.skill_proficiencies.count(s) == 1), "Random %s Confirm grants the displayed picks once" % class_id)
	return c

static func _save(h: Node, creation: Node, slot: String) -> void:
	h._teardown_scene(creation)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	h._assert(SaveManager.save_game(slot), "%s saves through the disk boundary" % slot)

static func reload(h: Node) -> void:
	h._enter_test("class_skill_selection_reload")
	var p := FileAccess.get_file_as_string(IDS).strip_edges().split("|") + FileAccess.get_file_as_string(IDS_B).strip_edges().split("|")
	h._assert(p.size() == 7 and SaveManager.load_game(SLOTS[0]), "Fresh process loads pass A")
	if p.size() != 7:
		h._exit_test()
		return
	var expect := {p[0]: ["Athletics", "Survival"], p[1]: ["History", "Insight"], p[2]: ["Nature", "Stealth", "Survival"]}
	for id in p.slice(0, 4):
		var c: Character = PartyManager.characters.get(id, null)
		var picks: Array = expect.get(id, c.creation_choices.get("skills", []) if c != null else [])
		h._assert(c != null and c.creation_choices.get("skills", []) == picks and picks.all(func(s): return c.skill_proficiencies.count(s) == 1) and ClassProgression.saved_creation_error(c.to_dict()).is_empty(), "Fresh process: %s keeps class picks once" % (c.class_id if c != null else id))
	var fighter: Character = PartyManager.characters.get(p[1], null)
	h._assert(fighter != null and fighter.fighter_training.skills == ["History", "Insight"] and PartyManager.characters[p[0]].inventory.gold == 75, "Fresh process: Fighter training and Barbarian gold unchanged")
	h._assert(SaveManager.save_game(SLOTS[0]), "Pass A saves again")
	h._assert(SaveManager.load_game(SLOTS[1]), "Fresh process loads pass B")
	for id in p.slice(4, 7):
		var c: Character = PartyManager.characters.get(id, null)
		h._assert(c != null and c.creation_choices.get("skills", []).size() == 2 and c.creation_choices.skills.all(func(s): return c.skill_proficiencies.count(s) == 1), "Fresh process: %s keeps class picks once" % (c.class_id if c != null else id))
	h._assert(SaveManager.save_game(SLOTS[1]), "Pass B saves again")
	for slot in SLOTS:
		SaveManager.delete_save(slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS_B))
	h._exit_test()

static func _to_equipment(h: Node, creation: Node, name: String, class_id: String, race_id: String) -> void:
	creation.selected_name = name
	creation.selected_race_id = race_id
	creation.selected_class_id = class_id
	creation.class_creation_choices = {}
	creation.current_step = creation.CreationStep.EQUIPMENT
	creation._update_step_ui()
	await h.get_tree().process_frame
