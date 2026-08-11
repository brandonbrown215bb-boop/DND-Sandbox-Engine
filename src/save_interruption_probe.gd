## Headless two-phase probe for the real save/backup process boundary.
extends SceneTree

const SLOT := "gate3_interrupt"
var game_manager: Node
var data_loader: Node
var player_manager: Node
var party_manager: Node
var save_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	game_manager = get_root().get_node("GameManager")
	data_loader = get_root().get_node("DataLoader")
	player_manager = get_root().get_node("PlayerManager")
	party_manager = get_root().get_node("PartyManager")
	save_manager = get_root().get_node("SaveManager")
	var phase := OS.get_environment("GATE3_PHASE")
	if phase == "prepare":
		_prepare()
	elif phase == "recover":
		_recover()
	else:
		_fail("unknown phase")


func _prepare() -> void:
	game_manager.test_mode = true
	game_manager.active_campaign = data_loader.get_campaign("the_lost_crown")
	game_manager.current_state = 2
	game_manager.game_in_progress = true
	game_manager.defeated_monsters.assign(["goblin"])
	game_manager.completed_milestones.assign(["enter_dungeon_1"])
	game_manager.cleared_dungeons.clear()
	game_manager.claimed_rewards.clear()
	player_manager.reset()
	party_manager.reset()
	player_manager.add_player("Interruption Tester")
	player_manager.current_round = 1
	player_manager.active_player_index = 0
	save_manager.delete_save(SLOT)
	if not save_manager.save_game(SLOT):
		_fail("initial valid save failed")
	game_manager.defeated_monsters.assign(["goblin", "wight"])
	game_manager.completed_milestones.assign(["enter_dungeon_1", "clear_dungeon_1"])
	player_manager.current_round = 7
	print("PREPARE PASSED: valid primary created")
	if not save_manager.save_game(SLOT):
		_fail("interrupted save did not enter the save path")
	_fail("interruption marker was not consumed by the host")


func _recover() -> void:
	game_manager.test_mode = true
	if not save_manager.load_game(SLOT):
		_fail("fresh process could not recover the save slot")
	var player: Dictionary = player_manager.get_player(0)
	var character = player.get("character") if not player.is_empty() else null
	var recovered_round: int = player_manager.current_round
	var recovered_defeated := ",".join(game_manager.defeated_monsters)
	var recovered_milestones := ",".join(game_manager.completed_milestones)
	print("RECOVERED_ROUND=%d" % recovered_round)
	print("RECOVERED_PLAYER=%s" % str(player.get("name", "")))
	print("RECOVERED_DEFEATED=%s" % recovered_defeated)
	print("RECOVERED_MILESTONES=%s" % recovered_milestones)
	if recovered_round != 1 or recovered_defeated != "goblin" or recovered_milestones != "enter_dungeon_1":
		_fail("recovery loaded the interrupted or mutated state instead of the prior valid backup")
	print("RECOVERY PASSED: prior valid backup restored in a fresh process")
	quit()


func _fail(message: String) -> void:
	push_error("[SaveInterruptionProbe] " + message)
	quit(1)
