extends SceneTree

const SLOT := "crown_gate7_fresh_relaunch"

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
	var phase := OS.get_environment("CROWN_RELAUNCH_PHASE")
	if phase == "prepare":
		_prepare()
	elif phase == "recover":
		_recover()
	else:
		_fail("unknown Crown relaunch phase")


func _prepare() -> void:
	save_manager.delete_save(SLOT)
	var fixture_text := FileAccess.get_file_as_string("res://data/fixtures/save_v1_compat.json")
	var fixture_file := FileAccess.open("user://saves/%s.sav" % SLOT, FileAccess.WRITE)
	if fixture_text.is_empty() or fixture_file == null:
		_fail("could not stage the repository Crown save fixture")
		return
	fixture_file.store_string(fixture_text)
	fixture_file.close()
	if not save_manager.load_game(SLOT):
		_fail("repository Crown save fixture did not load")
		return
	game_manager.current_state = 2
	game_manager.transition_context = {}
	game_manager.game_in_progress = true
	game_manager.active_dungeon_state.clear()
	var active_party: Array = party_manager.get_active_characters()
	if active_party.is_empty():
		_fail("repository Crown save fixture did not restore a party")
		return
	var hero = active_party[0]
	party_manager.initialize_campaign_companions(game_manager.active_campaign.get("companions", {}))
	for companion_id in ["aldric", "mira", "rowan"]:
		if not party_manager.recruit_companion(companion_id):
			_fail("could not recruit Crown companion %s" % companion_id)
			return
	if not hero.inventory.has_item("crown_fragment"):
		hero.inventory.add_item("crown_fragment")
	game_manager.completed_milestones.assign(["enter_dungeon_1"])
	game_manager.cleared_dungeons.assign(["ruins_of_ashvale"])
	game_manager.claimed_rewards.assign(["ruins_of_ashvale_fragment"])
	game_manager.defeated_monsters.assign(["wight"])
	if not save_manager.get_save_block_reason().is_empty():
		_fail("Crown overworld safe point was rejected: %s" % save_manager.get_save_block_reason())
		return
	save_manager.delete_save(SLOT)
	if not save_manager.save_game(SLOT):
		_fail("Crown fresh-relaunch save could not be committed")
		return
	print("CROWN FRESH PREPARED: four-member party, objective, ownership, clear, and reward state committed")


func _recover() -> void:
	if not save_manager.load_game(SLOT):
		_fail("fresh Crown process could not load the prepared save")
		return
	var active_party: Array = party_manager.get_active_characters()
	var owner_indices: Array = []
	for slot in party_manager.party_slots:
		if bool(slot.get("occupied", false)):
			owner_indices.append(player_manager.get_player_for_party_slot(str(slot.get("slot_id", ""))))
	var objectives: Array[String] = game_manager.get_campaign_objectives()
	var objective_text := " | ".join(objectives)
	print("CROWN RECOVERED STATE=%d" % int(game_manager.current_state))
	print("CROWN RECOVERED PARTY=%d" % active_party.size())
	print("CROWN RECOVERED OWNERS=%s" % str(owner_indices))
	print("CROWN RECOVERED OBJECTIVES=%s" % objective_text)
	print("CROWN RECOVERED CLEARED=%s" % ",".join(game_manager.cleared_dungeons))
	print("CROWN RECOVERED REWARDS=%s" % ",".join(game_manager.claimed_rewards))
	if game_manager.active_campaign.get("id", "") != "the_lost_crown":
		_fail("Crown campaign did not survive fresh relaunch")
		return
	if int(game_manager.current_state) != 2:
		_fail("Crown safe save did not recover to the overworld")
		return
	if active_party.size() != 4 or owner_indices != [0, 0, 0, 0]:
		_fail("Crown party or companion ownership did not survive fresh relaunch")
		return
	var hero = active_party[0]
	if hero.inventory.count_item("crown_fragment") != 1:
		_fail("Crown quest item did not survive fresh relaunch")
		return
	if not game_manager.cleared_dungeons.has("ruins_of_ashvale") or not game_manager.claimed_rewards.has("ruins_of_ashvale_fragment") or not game_manager.defeated_monsters.has("wight"):
		_fail("Crown progress ledgers did not survive fresh relaunch")
		return
	if objectives.is_empty() or not objective_text.contains("Crown"):
		_fail("Crown objective did not survive fresh relaunch")
		return
	print("CROWN FRESH RELAUNCH PASSED: campaign, party ownership, objective, clear, reward, and available state restored")
	quit()


func _fail(message: String) -> void:
	push_error("[CrownFreshRelaunchProbe] " + message)
	quit(1)
