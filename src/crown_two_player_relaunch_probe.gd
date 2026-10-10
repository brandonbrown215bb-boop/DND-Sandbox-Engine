extends SceneTree

const SLOT := "crown_two_player_midgame_relaunch"

var game_manager: Node
var player_manager: Node
var party_manager: Node
var save_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	game_manager = get_root().get_node("GameManager")
	player_manager = get_root().get_node("PlayerManager")
	party_manager = get_root().get_node("PartyManager")
	save_manager = get_root().get_node("SaveManager")
	game_manager.test_mode = true
	var phase := OS.get_environment("CROWN_TWO_PLAYER_PHASE")
	if phase == "prepare":
		_prepare()
	elif phase == "recover":
		_recover()
	else:
		_fail("unknown two-player relaunch phase")


func _prepare() -> void:
	save_manager.delete_save(SLOT)
	var fixture_text := FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json")
	var fixture_json := JSON.new()
	if fixture_json.parse(fixture_text) != OK or not fixture_json.data is Dictionary:
		_fail("repository Crown fixture could not be parsed")
		return
	var save_data: Dictionary = fixture_json.data
	var ally_data := {
		"character_name": "Seat Two Hero",
		"race_id": "elf",
		"class_id": "wizard",
		"level": 3,
		"current_hp": 18,
		"max_hp": 18,
		"ability_scores": {"STR": 8, "DEX": 14, "CON": 12, "INT": 16, "WIS": 12, "CHA": 10}
	}
	var party_data: Dictionary = save_data.get("party", {})
	var party_slots: Array = party_data.get("party_slots", [])
	if party_slots.size() < 4:
		_fail("repository Crown fixture does not expose four party slots")
		return
	party_slots[1] = {"slot_id": "slot_1", "occupied": true, "is_companion": false, "character_id": "fixture_ally"}
	party_data["party_slots"] = party_slots
	var party_characters: Dictionary = party_data.get("characters", {})
	party_characters["fixture_ally"] = ally_data.duplicate(true)
	party_data["characters"] = party_characters
	party_data["leader_slot_id"] = "slot_1"
	save_data["party"] = party_data
	var players: Array = save_data.get("players", [])
	if players.is_empty():
		_fail("repository Crown fixture has no first player")
		return
	players[0]["assigned_slot_ids"] = ["slot_0"]
	players.append({
		"player_id": 1,
		"player_name": "Crown Seat 2",
		"name": "Crown Seat 2",
		"display_name": "Crown Seat 2",
		"session_id": "seat_1",
		"joined": true,
		"input_mode": "shared",
		"assigned_slot_ids": ["slot_1"],
		"hex_position": [0, 0],
		"is_alive": true,
		"character": ally_data.duplicate(true),
	})
	save_data["players"] = players
	save_data["current_state"] = 2
	var fixture_file := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % SLOT, FileAccess.WRITE)
	if fixture_file == null:
		_fail("could not stage two-player Crown save")
		return
	fixture_file.store_string(JSON.stringify(save_data))
	fixture_file.close()
	if not save_manager.load_game(SLOT):
		_fail("two-player Crown fixture did not load")
		return
	game_manager.current_state = 2
	game_manager.game_in_progress = true
	party_manager.initialize_campaign_companions(game_manager.active_campaign.get("companions", {}))
	if not party_manager.recruit_companion("aldric", 0) or not party_manager.recruit_companion("mira", 1):
		_fail("two-player Crown companions could not be assigned")
		return
	party_manager.set_leader("slot_1")
	var active_party: Array = party_manager.get_active_characters()
	if active_party.size() != 4:
		_fail("two-player Crown party did not reach four active members")
		return
	active_party[0].inventory.add_item("crown_fragment")
	active_party[1].inventory.add_item("crown_fragment")
	game_manager.completed_milestones.assign(["enter_dungeon_1", "clear_dungeon_1", "clear_dungeon_2"])
	game_manager.cleared_dungeons.assign(["ruins_of_ashvale", "caverns_of_gloom"])
	game_manager.claimed_rewards.assign(["ruins_of_ashvale_fragment", "caverns_of_gloom_fragment"])
	game_manager.defeated_monsters.assign(["wight", "goblin_chief"])
	game_manager.active_dungeon_state.clear()
	if not save_manager.get_save_block_reason().is_empty() or not save_manager.save_game(SLOT):
		_fail("two-player Crown midgame safe save could not be committed")
		return
	print("CROWN TWO-PLAYER PREPARED: progressed two-seat party, ownership, objectives, rewards, and cleared dungeons committed")


func _recover() -> void:
	if not save_manager.load_game(SLOT):
		_fail("fresh two-player Crown process could not load the progressed save")
		return
	var active_party: Array = party_manager.get_active_characters()
	var owner_indices: Array = []
	for slot in party_manager.party_slots:
		if bool(slot.get("occupied", false)):
			owner_indices.append(player_manager.get_player_for_party_slot(str(slot.get("slot_id", ""))))
	var objectives: Array[String] = game_manager.get_campaign_objectives()
	var objective_text := " | ".join(objectives)
	var fragment_count := 0
	for character in active_party:
		fragment_count += character.inventory.count_item("crown_fragment")
	print("CROWN TWO-PLAYER RECOVERED PLAYERS=%d PARTY=%d OWNERS=%s" % [player_manager.get_player_count(), active_party.size(), str(owner_indices)])
	print("CROWN TWO-PLAYER RECOVERED LEADER=%s" % str(party_manager.leader_slot_id))
	print("CROWN TWO-PLAYER RECOVERED OBJECTIVES=%s" % objective_text)
	print("CROWN TWO-PLAYER RECOVERED CLEARED=%s" % ",".join(game_manager.cleared_dungeons))
	print("CROWN TWO-PLAYER RECOVERED FRAGMENTS=%d" % fragment_count)
	if int(game_manager.current_state) != 2 or player_manager.get_player_count() != 2:
		_fail("two-player Crown process did not recover the overworld session")
		return
	if active_party.size() != 4 or owner_indices != [0, 1, 0, 1] or party_manager.leader_slot_id != "slot_1":
		_fail("two-player Crown ownership or leadership did not survive relaunch")
		return
	if fragment_count != 2 or not game_manager.cleared_dungeons.has("ruins_of_ashvale") or not game_manager.cleared_dungeons.has("caverns_of_gloom"):
		_fail("two-player Crown rewards or cleared dungeon state did not survive relaunch")
		return
	if objectives.is_empty() or not objective_text.contains("Tower"):
		_fail("two-player Crown final pre-finale objective did not survive relaunch")
		return
	print("CROWN TWO-PLAYER RELAUNCH PASSED: ownership, leadership, objectives, rewards, and dungeon state restored")
	quit()


func _fail(message: String) -> void:
	push_error("[CrownTwoPlayerRelaunchProbe] " + message)
	quit(1)
