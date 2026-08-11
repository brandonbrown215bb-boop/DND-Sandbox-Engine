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

## Emitted whenever a stable local seat gains or loses its transient device.
## Physical device IDs are session-local and are never serialized.
signal device_binding_changed(player_index: int, device_id: int, connected: bool)

## Maximum number of players.
const MAX_PLAYERS := 4

## Minimum number of players.
const MIN_PLAYERS := 1

const UNBOUND_DEVICE_ID := -1
const INPUT_MODE_SHARED := "shared"
const INPUT_MODE_CONTROLLER := "controller"

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

## Session-local hint used to return a reconnected controller to the seat it
## previously owned. This deliberately does not cross a save/load boundary.
var _recent_session_by_device: Dictionary = {}

## Player colors for identification.
const PLAYER_COLORS := [
	Color(0.30, 0.60, 0.95),  # Blue
	Color(0.90, 0.35, 0.35),  # Red
	Color(0.35, 0.80, 0.40),  # Green
	Color(0.90, 0.70, 0.20),  # Gold
]

## Player default names.
const PLAYER_NAMES := ["Player 1", "Player 2", "Player 3", "Player 4"]


func _ready() -> void:
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			request_device_join(event.device)


## Add a new player to the roster.
func add_player(player_name: String = "") -> int:
	if players.size() >= MAX_PLAYERS:
		push_warning("[PlayerManager] Cannot add player: maximum %d reached" % MAX_PLAYERS)
		return -1

	var index := players.size()
	var player := {
		"name": player_name if not player_name.is_empty() else PLAYER_NAMES[index],
		"display_name": player_name if not player_name.is_empty() else PLAYER_NAMES[index],
		"session_id": "seat_%d" % index,
		"joined": true,
		"input_mode": INPUT_MODE_SHARED,
		"assigned_slot_ids": [],
		"device_id": UNBOUND_DEVICE_ID,
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


## Mark a seat disconnected without dropping its stable session, character, or
## party assignment. A later reconnect can reclaim the same seat.
func disconnect_player(session_id: String) -> bool:
	var index := _find_session_index(session_id)
	if index < 0:
		return false
	var device_id := int(players[index].get("device_id", UNBOUND_DEVICE_ID))
	if device_id != UNBOUND_DEVICE_ID:
		_recent_session_by_device[device_id] = session_id
	players[index]["joined"] = false
	players[index]["device_id"] = UNBOUND_DEVICE_ID
	device_binding_changed.emit(index, device_id, false)
	return true


## Reconnect a previously known seat. Returns its stable player index, or -1
## when the session was never part of this game.
func reconnect_player(session_id: String, device_id: int = UNBOUND_DEVICE_ID) -> int:
	var index := _find_session_index(session_id)
	if index < 0:
		return -1
	if device_id != UNBOUND_DEVICE_ID:
		return index if bind_device_to_session(session_id, device_id) else -1
	if str(players[index].get("input_mode", INPUT_MODE_SHARED)) == INPUT_MODE_CONTROLLER:
		return -1
	players[index]["joined"] = true
	device_binding_changed.emit(index, UNBOUND_DEVICE_ID, true)
	return index


## Bind one physical controller to one stable local seat. A controller cannot
## silently steal another seat, and rebinding never changes party ownership.
func bind_device_to_session(session_id: String, device_id: int) -> bool:
	if device_id < 0:
		return false
	var index := _find_session_index(session_id)
	if index < 0:
		return false
	var existing_index := get_player_index_for_device(device_id)
	if existing_index >= 0 and existing_index != index:
		return false
	var old_device := int(players[index].get("device_id", UNBOUND_DEVICE_ID))
	if old_device != UNBOUND_DEVICE_ID and old_device != device_id:
		_recent_session_by_device.erase(old_device)
	for remembered_device in _recent_session_by_device.keys():
		if int(remembered_device) != device_id and str(_recent_session_by_device[remembered_device]) == session_id:
			_recent_session_by_device.erase(remembered_device)
	players[index]["input_mode"] = INPUT_MODE_CONTROLLER
	players[index]["device_id"] = device_id
	players[index]["joined"] = true
	_recent_session_by_device[device_id] = session_id
	device_binding_changed.emit(index, device_id, true)
	return true


func get_player_index_for_device(device_id: int) -> int:
	for index in players.size():
		if int(players[index].get("device_id", UNBOUND_DEVICE_ID)) == device_id:
			return index
	return -1


## A controller Start press reclaims its previous session-local seat first,
## then a disconnected controller seat, then the first unbound shared seat.
func request_device_join(device_id: int, preferred_session_id: String = "") -> int:
	if device_id < 0:
		return -1
	var existing_index := get_player_index_for_device(device_id)
	if existing_index >= 0:
		players[existing_index]["joined"] = true
		device_binding_changed.emit(existing_index, device_id, true)
		return existing_index

	var target_session := preferred_session_id
	if target_session.is_empty():
		target_session = str(_recent_session_by_device.get(device_id, ""))
	if not target_session.is_empty() and bind_device_to_session(target_session, device_id):
		return _find_session_index(target_session)

	for index in players.size():
		if not is_player_connected(index) and str(players[index].get("input_mode", INPUT_MODE_SHARED)) == INPUT_MODE_CONTROLLER:
			if bind_device_to_session(str(players[index].get("session_id", "")), device_id):
				return index
	for index in players.size():
		if int(players[index].get("device_id", UNBOUND_DEVICE_ID)) == UNBOUND_DEVICE_ID and str(players[index].get("input_mode", INPUT_MODE_SHARED)) == INPUT_MODE_SHARED:
			if bind_device_to_session(str(players[index].get("session_id", "")), device_id):
				return index
	return -1


func get_input_status(index: int) -> String:
	if index < 0 or index >= players.size():
		return "No seat"
	var player := players[index]
	if str(player.get("input_mode", INPUT_MODE_SHARED)) == INPUT_MODE_SHARED:
		return "Shared controls" if bool(player.get("joined", true)) else "Shared seat disconnected"
	var device_id := int(player.get("device_id", UNBOUND_DEVICE_ID))
	if not bool(player.get("joined", false)) or device_id == UNBOUND_DEVICE_ID:
		return "Press Start to rebind"
	var device_name := Input.get_joy_name(device_id)
	return device_name if not device_name.is_empty() else "Controller %d" % (device_id + 1)


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		var session_id := str(_recent_session_by_device.get(device_id, ""))
		if not session_id.is_empty():
			bind_device_to_session(session_id, device_id)
		return
	var index := get_player_index_for_device(device_id)
	if index >= 0:
		disconnect_player(str(players[index].get("session_id", "")))


func is_player_connected(index: int) -> bool:
	return index >= 0 and index < players.size() and bool(players[index].get("joined", true))


func get_connected_player_indices() -> Array[int]:
	var result: Array[int] = []
	for index in players.size():
		if is_player_connected(index):
			result.append(index)
	return result


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
	var alive_count := _count_connected_alive_players()
	if alive_count == 0:
		return false

	# Find the next alive player
	var attempts := 0
	while attempts < MAX_PLAYERS:
		active_player_index = (active_player_index + 1) % players.size()
		if is_player_connected(active_player_index) and is_player_alive(players[active_player_index]):
			break
		attempts += 1

	# Check if we've completed a full round
	var new_round := active_player_index == first_player_index
	if new_round:
		current_round += 1
		# Rotate first player
		first_player_index = (first_player_index + 1) % players.size()
		# Ensure first player is alive
		while not (is_player_connected(first_player_index) and is_player_alive(players[first_player_index])):
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
	_recent_session_by_device.clear()
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


func _count_connected_alive_players() -> int:
	var count := 0
	for player in players:
		if bool(player.get("joined", true)) and is_player_alive(player):
			count += 1
	return count


func _find_session_index(session_id: String) -> int:
	for index in players.size():
		if str(players[index].get("session_id", "")) == session_id:
			return index
	return -1


## Serialize all player manager state to an Array.
func serialize() -> Array:
	var data: Array = []
	for player in players:
		var p_data := {
			"name": player.get("name", ""),
			"display_name": player.get("display_name", player.get("name", "")),
			"session_id": player.get("session_id", "seat_%d" % data.size()),
			"joined": player.get("joined", true),
			"input_mode": player.get("input_mode", INPUT_MODE_SHARED),
			"assigned_slot_ids": player.get("assigned_slot_ids", []).duplicate(),
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
		var input_mode := str(p_dict.get("input_mode", INPUT_MODE_SHARED))
		var player := {
			"name": p_dict.get("name", ""),
			"display_name": p_dict.get("display_name", p_dict.get("name", "")),
			"session_id": p_dict.get("session_id", "seat_%d" % players.size()),
			# Controller seats must deliberately rebind after load. Stable seat,
			# character, and party ownership survive; physical hardware does not.
			"joined": bool(p_dict.get("joined", true)) if input_mode == INPUT_MODE_SHARED else false,
			"input_mode": input_mode,
			"assigned_slot_ids": p_dict.get("assigned_slot_ids", []).duplicate(),
			"device_id": UNBOUND_DEVICE_ID,
			"color": Color.from_string(p_dict.get("color", "ffffff"), Color.WHITE),
			"hex_position": Vector2i(hex_pos_arr[0], hex_pos_arr[1]),
			"is_alive": p_dict.get("is_alive", true),
			"character": character
		}
		players.append(player)


## Assign a stable party slot to a local seat. Device bindings remain transient.
func assign_party_slot(player_index: int, slot_id: String) -> bool:
	if player_index < 0 or player_index >= players.size() or slot_id.is_empty():
		return false
	var assigned: Array = players[player_index].get("assigned_slot_ids", [])
	if slot_id not in assigned:
		assigned.append(slot_id)
	players[player_index]["assigned_slot_ids"] = assigned
	return true


func unassign_party_slot(player_index: int, slot_id: String) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	var assigned: Array = players[player_index].get("assigned_slot_ids", [])
	assigned.erase(slot_id)
	players[player_index]["assigned_slot_ids"] = assigned


func get_player_for_party_slot(slot_id: String) -> int:
	for index in players.size():
		if slot_id in players[index].get("assigned_slot_ids", []):
			return index
	return -1
