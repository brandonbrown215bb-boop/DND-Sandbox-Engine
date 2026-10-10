extends SceneTree

const SLOT := "gate3_fresh_relaunch"
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
	game_manager.test_mode = true
	var phase := OS.get_environment("GATE3_PHASE")
	if phase == "prepare":
		_prepare()
	elif phase == "recover":
		_recover()
	else:
		_fail("unknown phase")


func _prepare() -> void:
	save_manager.delete_save(SLOT)
	var fixture_text := FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json")
	if fixture_text.is_empty():
		_fail("repository save fixture is empty")
		return
	var fixture_file := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % SLOT, FileAccess.WRITE)
	if fixture_file == null:
		_fail("could not stage repository save fixture")
		return
	fixture_file.store_string(fixture_text)
	fixture_file.close()
	if not save_manager.load_game(SLOT):
		_fail("repository save fixture did not load")
		return

	var party_characters: Dictionary = party_manager.get("characters")
	var hero = party_characters.get("fixture_hero")
	if hero == null:
		_fail("fixture hero was not reconstructed into the party")
		return
	if not hero.inventory.add_item("potion_healing"):
		_fail("fixture hero inventory could not accept potion_healing")
		return
	hero.inventory.gold = 73
	var players: Array = player_manager.get("players")
	if players.is_empty():
		_fail("fixture did not reconstruct a player seat")
		return
	players[0]["name"] = "Fixture Player"
	player_manager.set("players", players)
	game_manager.defeated_monsters.assign(["goblin"])
	game_manager.completed_milestones.assign(["enter_dungeon_1"])
	game_manager.cleared_dungeons.assign(["ruins_of_ashvale"])
	game_manager.claimed_rewards.assign(["ruins_of_ashvale_fragment"])
	player_manager.current_round = 4
	player_manager.active_player_index = 0
	if not save_manager.save_game(SLOT):
		_fail("prepared fresh-relaunch save could not be committed")
		return
	print("FRESH PREPARED: party, ownership, inventory, ledgers, and objective state committed")
	print("PREPARED_OBJECTIVE=%s" % str(game_manager.get_campaign_objectives()))


func _recover() -> void:
	if not save_manager.load_game(SLOT):
		_fail("fresh process could not load the prepared save")
		return
	var party_characters: Dictionary = party_manager.get("characters")
	var hero = party_characters.get("fixture_hero")
	if hero == null:
		_fail("fresh process did not reconstruct fixture hero")
		return
	var player: Dictionary = player_manager.get_player(0)
	var owner: int = player_manager.get_player_for_party_slot("slot_0")
	var objectives: Array[String] = game_manager.get_campaign_objectives()
	var objective_text := " | ".join(objectives)
	print("RECOVERED_PLAYER=%s" % str(player.get("name", "")))
	print("RECOVERED_OWNER_SLOT_0=%d" % owner)
	print("RECOVERED_ROUND=%d" % int(player_manager.current_round))
	print("RECOVERED_INVENTORY_POTION=%d" % hero.inventory.count_item("potion_healing"))
	print("RECOVERED_INVENTORY_GOLD=%d" % int(hero.inventory.gold))
	print("RECOVERED_DEFEATED=%s" % ",".join(game_manager.defeated_monsters))
	print("RECOVERED_MILESTONES=%s" % ",".join(game_manager.completed_milestones))
	print("RECOVERED_CLEARED_DUNGEONS=%s" % ",".join(game_manager.cleared_dungeons))
	print("RECOVERED_CLAIMED_REWARDS=%s" % ",".join(game_manager.claimed_rewards))
	print("RECOVERED_OBJECTIVES=%s" % objective_text)
	if str(player.get("name", "")) != "Fixture Player":
		_fail("player identity did not survive fresh relaunch")
		return
	if owner != 0:
		_fail("slot_0 ownership did not survive fresh relaunch")
		return
	if int(player_manager.current_round) != 4 or hero.inventory.count_item("potion_healing") != 1 or int(hero.inventory.gold) != 73:
		_fail("inventory or round state did not survive fresh relaunch")
		return
	if game_manager.defeated_monsters != ["goblin"] or game_manager.completed_milestones != ["enter_dungeon_1"]:
		_fail("campaign progress ledgers did not survive fresh relaunch")
		return
	if game_manager.cleared_dungeons != ["ruins_of_ashvale"] or game_manager.claimed_rewards != ["ruins_of_ashvale_fragment"]:
		_fail("dungeon or reward ledgers did not survive fresh relaunch")
		return
	if objectives.is_empty():
		_fail("fresh process did not reconstruct a player-facing next objective")
		return
	print("FRESH RELAUNCH PASSED: party, ownership, inventory, ledgers, and next objective restored")
	quit()


func _fail(message: String) -> void:
	push_error("[FreshRelaunchProbe] " + message)
	quit(1)
