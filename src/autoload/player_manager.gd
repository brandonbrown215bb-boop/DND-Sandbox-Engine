## Player Manager
## Autoloaded singleton that manages the player roster, turn order,
## and active player state for hot-seat local multiplayer.
extends Node

## Emitted when the active player changes.
signal active_player_changed(player_index: int)

## Emitted when a new round begins (all players have taken a turn).
signal round_started(round_number: int)

## Emitted when a player is added.
signal player_added(player_index: int)

## Maximum number of players.
const MAX_PLAYERS := 4

## Minimum number of players.
const MIN_PLAYERS := 2

## Player data: array of dictionaries, each containing:
##   - "name": String
##   - "character": Character (null until creation)
##   - "color": Color
##   - "hex_position": Vector2i
var players: Array[Dictionary] = []

## Index of the player whose turn it currently is.
var active_player_index: int = 0

## Current round number (incremented each time all players complete a turn).
var current_round: int = 1

## Index of the first player this round (rotates each round).
var first_player_index: int = 0

## Player colors for identification.
const PLAYER_COLORS := [
	Color(0.30, 0.60, 0.95),  # Blue
	Color(0.90, 0.35, 0.35),  # Red
	Color(0.35, 0.80, 0.40),  # Green
	Color(0.90, 0.70, 0.20),  # Gold
]

## Player default names.
const PLAYER_NAMES := ["Player 1", "Player 2", "Player 3", "Player 4"]


## Add a new player to the roster.
func add_player(player_name: String = "") -> int:
	if players.size() >= MAX_PLAYERS:
		push_warning("[PlayerManager] Cannot add player: maximum %d reached" % MAX_PLAYERS)
		return -1

	var index := players.size()
	var player := {
		"name": player_name if not player_name.is_empty() else PLAYER_NAMES[index],
		"character": null,
		"color": PLAYER_COLORS[index],
		"hex_position": Vector2i.ZERO,
		"is_alive": true,
	}
	players.append(player)
	player_added.emit(index)
	return index


## Remove a player by index.
func remove_player(index: int) -> void:
	if index >= 0 and index < players.size():
		players.remove_at(index)


## Get the active player's data dictionary.
func get_active_player() -> Dictionary:
	if active_player_index >= 0 and active_player_index < players.size():
		return players[active_player_index]
	return {}


## Get a player's data by index.
func get_player(index: int) -> Dictionary:
	if index >= 0 and index < players.size():
		return players[index]
	return {}


## Get the number of players.
func get_player_count() -> int:
	return players.size()


## Set the character for a player (after character creation).
func set_player_character(player_index: int, character) -> void:
	if player_index >= 0 and player_index < players.size():
		players[player_index]["character"] = character


## Set a player's position on the hex grid.
func set_player_position(player_index: int, coord: Vector2i) -> void:
	if player_index >= 0 and player_index < players.size():
		players[player_index]["hex_position"] = coord


## Get a player's hex position.
func get_player_position(player_index: int) -> Vector2i:
	if player_index >= 0 and player_index < players.size():
		return players[player_index]["hex_position"]
	return Vector2i.ZERO


## Check if a player is alive (based on their character status if created).
func is_player_alive(player: Dictionary) -> bool:
	var character = player.get("character")
	if character != null:
		return character.is_alive
	return player.get("is_alive", true)


## Check if the entire party is wiped (all players with characters are dead).
func is_party_wiped() -> bool:
	if players.is_empty():
		return false
	for player in players:
		if is_player_alive(player):
			return false
	return true


## Advance to the next player's turn. Returns true if a new round started.
func next_turn() -> bool:
	var alive_count := _count_alive_players()
	if alive_count == 0:
		return false

	# Find the next alive player
	var attempts := 0
	while attempts < MAX_PLAYERS:
		active_player_index = (active_player_index + 1) % players.size()
		if is_player_alive(players[active_player_index]):
			break
		attempts += 1

	# Check if we've completed a full round
	var new_round := active_player_index == first_player_index
	if new_round:
		current_round += 1
		# Rotate first player
		first_player_index = (first_player_index + 1) % players.size()
		# Ensure first player is alive
		while not is_player_alive(players[first_player_index]):
			first_player_index = (first_player_index + 1) % players.size()
		round_started.emit(current_round)

	active_player_changed.emit(active_player_index)
	return new_round


## Start the first turn of the game.
func start_game() -> void:
	if players.is_empty():
		push_warning("[PlayerManager] Cannot start game with no players")
		return

	current_round = 1
	first_player_index = 0
	active_player_index = 0
	active_player_changed.emit(active_player_index)
	round_started.emit(current_round)


## Reset all player data for a new game.
func reset() -> void:
	players.clear()
	active_player_index = 0
	current_round = 1
	first_player_index = 0


## Get all players at a specific hex position.
func get_players_at(coord: Vector2i) -> Array[int]:
	var result: Array[int] = []
	for i in players.size():
		if players[i]["hex_position"] == coord:
			result.append(i)
	return result


## Count alive players.
func _count_alive_players() -> int:
	var count := 0
	for player in players:
		if is_player_alive(player):
			count += 1
	return count


## Serialize all player manager state to an Array.
func serialize() -> Array:
	var data: Array = []
	for player in players:
		var p_data := {
			"name": player.get("name", ""),
			"color": player.get("color", Color.WHITE).to_html(),
			"hex_position": [player.get("hex_position", Vector2i.ZERO).x, player.get("hex_position", Vector2i.ZERO).y],
			"is_alive": player.get("is_alive", true),
			"character": player.get("character").to_dict() if player.get("character") != null else null
		}
		data.append(p_data)
	return data


## Deserialize all player manager state from an Array.
func deserialize(data: Array) -> void:
	players.clear()
	for p_dict in data:
		var character = null
		var char_data = p_dict.get("character")
		if char_data != null:
			character = Character.new()
			character.from_dict(char_data)
		
		var hex_pos_arr: Array = p_dict.get("hex_position", [0, 0])
		var player := {
			"name": p_dict.get("name", ""),
			"color": Color.from_string(p_dict.get("color", "ffffff"), Color.WHITE),
			"hex_position": Vector2i(hex_pos_arr[0], hex_pos_arr[1]),
			"is_alive": p_dict.get("is_alive", true),
			"character": character
		}
		players.append(player)

