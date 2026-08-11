## Party Manager
## Stable party membership and local ownership, separate from character data.
extends Node

signal party_changed
signal leader_changed(slot_id: String)

const MAX_PARTY_SIZE := 4
const FORMATION_POSITIONS: Array[Vector2i] = [
	Vector2i(-3, 0),
	Vector2i(-3, 1),
	Vector2i(-3, -1),
	Vector2i(-2, 0),
]

var characters: Dictionary = {} # character_id -> Character
var party_slots: Array[Dictionary] = []
var companion_roster: Dictionary = {} # companion_id -> {state, character_id}
var leader_slot_id: String = "slot_0"


func _ready() -> void:
	_reset_slots()


func reset() -> void:
	characters.clear()
	companion_roster.clear()
	leader_slot_id = "slot_0"
	_reset_slots()


func initialize_campaign_companions(companion_data: Dictionary) -> void:
	for companion_id in companion_data:
		if companion_roster.has(companion_id):
			continue
		var record: Dictionary = companion_data[companion_id]
		create_companion(
			str(companion_id),
			str(record.get("name", companion_id)),
			str(record.get("race_id", "human")),
			str(record.get("class_id", "fighter")),
			record.get("ability_scores", {})
		)


func get_available_companions() -> Array[String]:
	var result: Array[String] = []
	for companion_id in companion_roster:
		if str(companion_roster[companion_id].get("state", "")) == "available":
			result.append(str(companion_id))
	result.sort()
	return result


func get_companion_ids() -> Array[String]:
	var result: Array[String] = []
	for companion_id in companion_roster:
		result.append(str(companion_id))
	result.sort()
	return result


func get_recruited_companions() -> Array[String]:
	var result: Array[String] = []
	for companion_id in companion_roster:
		if str(companion_roster[companion_id].get("state", "")) == "recruited":
			result.append(str(companion_id))
	result.sort()
	return result


func get_companion_state(companion_id: String) -> String:
	if not companion_roster.has(companion_id):
		return ""
	return str(companion_roster[companion_id].get("state", ""))


func get_companion_character(companion_id: String) -> Character:
	if not companion_roster.has(companion_id):
		return null
	var character_id := str(companion_roster[companion_id].get("character_id", ""))
	return characters.get(character_id) as Character


func get_companion_slot_id(companion_id: String) -> String:
	if not companion_roster.has(companion_id):
		return ""
	var character_id := str(companion_roster[companion_id].get("character_id", ""))
	for slot in party_slots:
		if str(slot.get("character_id", "")) == character_id and bool(slot.get("occupied", false)):
			return str(slot.get("slot_id", ""))
	return ""


func get_empty_slot_count() -> int:
	var count := 0
	for slot in party_slots:
		if not bool(slot.get("occupied", false)):
			count += 1
	return count


## Compatibility bridge for older saves and isolated harnesses that construct
## PlayerManager directly. Production creation uses register_player_character.
func sync_from_player_manager() -> void:
	reset()
	for index in PlayerManager.get_player_count():
		var character: Character = PlayerManager.get_player(index).get("character")
		if character != null:
			register_player_character(index, character)


func _reset_slots() -> void:
	party_slots.clear()
	for index in MAX_PARTY_SIZE:
		party_slots.append({"slot_id": "slot_%d" % index, "character_id": "", "is_companion": false, "occupied": false})


func register_player_character(seat_index: int, character: Character) -> bool:
	if character == null or seat_index < 0 or seat_index >= PlayerManager.get_player_count():
		return false
	var slot_id := "slot_%d" % seat_index
	var slot := _get_slot(slot_id)
	if slot.is_empty() or bool(slot.get("occupied", false)):
		return false
	_ensure_character_id(character, "player_%d" % seat_index)
	characters[character.character_id] = character
	slot["character_id"] = character.character_id
	slot["occupied"] = true
	slot["is_companion"] = false
	PlayerManager.assign_party_slot(seat_index, slot_id)
	party_changed.emit()
	return true


func create_companion(companion_id: String, companion_name: String, race_id: String, class_id: String, scores: Dictionary) -> Character:
	if companion_id.is_empty() or companion_roster.has(companion_id):
		return null
	var character := Character.new()
	var ability_scores := AbilityScores.new()
	ability_scores.from_dict(scores)
	character.initialize(companion_name, race_id, class_id, ability_scores)
	_ensure_character_id(character, companion_id)
	companion_roster[companion_id] = {"state": "available", "character_id": character.character_id}
	characters[character.character_id] = character
	return character


func recruit_companion(companion_id: String, seat_index: int = 0) -> bool:
	if not companion_roster.has(companion_id):
		return false
	var record: Dictionary = companion_roster[companion_id]
	if str(record.get("state", "")) == "recruited":
		return false
	var slot := _first_empty_slot()
	if slot.is_empty():
		return false
	var character_id := str(record.get("character_id", ""))
	if not characters.has(character_id):
		return false
	slot["character_id"] = character_id
	slot["occupied"] = true
	slot["is_companion"] = true
	record["state"] = "recruited"
	companion_roster[companion_id] = record
	if seat_index < 0 or seat_index >= PlayerManager.get_player_count():
		seat_index = PlayerManager.active_player_index
	PlayerManager.assign_party_slot(seat_index, slot.get("slot_id", ""))
	_append_unique(GameManager.recruited_companions, companion_id)
	party_changed.emit()
	return true


func decline_companion(companion_id: String) -> bool:
	if not companion_roster.has(companion_id):
		return false
	var record: Dictionary = companion_roster[companion_id]
	if str(record.get("state", "")) != "available":
		return false
	record["state"] = "declined"
	companion_roster[companion_id] = record
	party_changed.emit()
	return true


func reconsider_companion(companion_id: String) -> bool:
	if not companion_roster.has(companion_id):
		return false
	var record: Dictionary = companion_roster[companion_id]
	if str(record.get("state", "")) not in ["declined", "dismissed"]:
		return false
	record["state"] = "available"
	companion_roster[companion_id] = record
	party_changed.emit()
	return true


## Replace one recruited companion without creating an intermediate over-capacity
## state. The incoming companion inherits the outgoing slot, and defaults to the
## same logical owner unless the caller chooses another joined seat.
func replace_companion(outgoing_id: String, incoming_id: String, seat_index: int = -1) -> bool:
	if outgoing_id == incoming_id or not companion_roster.has(outgoing_id) or not companion_roster.has(incoming_id):
		return false
	var outgoing: Dictionary = companion_roster[outgoing_id]
	var incoming: Dictionary = companion_roster[incoming_id]
	if str(outgoing.get("state", "")) != "recruited" or str(incoming.get("state", "")) == "recruited":
		return false
	var slot_id := get_companion_slot_id(outgoing_id)
	var slot := _get_slot(slot_id)
	var incoming_character_id := str(incoming.get("character_id", ""))
	if slot.is_empty() or not characters.has(incoming_character_id):
		return false
	var previous_owner := PlayerManager.get_player_for_party_slot(slot_id)
	if seat_index < 0 or seat_index >= PlayerManager.get_player_count():
		seat_index = previous_owner
	if seat_index < 0 or seat_index >= PlayerManager.get_player_count():
		return false
	for player_index in PlayerManager.get_player_count():
		PlayerManager.unassign_party_slot(player_index, slot_id)
	slot["character_id"] = incoming_character_id
	slot["occupied"] = true
	slot["is_companion"] = true
	PlayerManager.assign_party_slot(seat_index, slot_id)
	outgoing["state"] = "dismissed"
	incoming["state"] = "recruited"
	companion_roster[outgoing_id] = outgoing
	companion_roster[incoming_id] = incoming
	_append_unique(GameManager.dismissed_companions, outgoing_id)
	_append_unique(GameManager.recruited_companions, incoming_id)
	party_changed.emit()
	return true


func dismiss_companion(companion_id: String) -> bool:
	if not companion_roster.has(companion_id):
		return false
	var record: Dictionary = companion_roster[companion_id]
	if str(record.get("state", "")) != "recruited":
		return false
	var character_id := str(record.get("character_id", ""))
	for slot in party_slots:
		if slot.get("character_id", "") == character_id:
			var owner := PlayerManager.get_player_for_party_slot(slot.get("slot_id", ""))
			if owner >= 0:
				PlayerManager.unassign_party_slot(owner, slot.get("slot_id", ""))
			slot["character_id"] = ""
			slot["occupied"] = false
			slot["is_companion"] = false
			record["state"] = "dismissed"
			companion_roster[companion_id] = record
			_append_unique(GameManager.dismissed_companions, companion_id)
			_ensure_valid_leader()
			party_changed.emit()
			return true
	return false


func set_leader(slot_id: String) -> bool:
	var slot := _get_slot(slot_id)
	if slot.is_empty() or not bool(slot.get("occupied", false)):
		return false
	leader_slot_id = slot_id
	leader_changed.emit(slot_id)
	party_changed.emit()
	return true


func assign_slot_to_seat(slot_id: String, seat_index: int) -> bool:
	var slot := _get_slot(slot_id)
	if slot.is_empty() or not bool(slot.get("is_companion", false)) or seat_index < 0 or seat_index >= PlayerManager.get_player_count():
		return false
	for player_index in PlayerManager.get_player_count():
		PlayerManager.unassign_party_slot(player_index, slot_id)
	PlayerManager.assign_party_slot(seat_index, slot_id)
	party_changed.emit()
	return true


func get_active_characters() -> Array[Character]:
	var result: Array[Character] = []
	for slot in party_slots:
		var character_id := str(slot.get("character_id", ""))
		if bool(slot.get("occupied", false)) and characters.has(character_id):
			result.append(characters[character_id])
	if result.is_empty():
		for index in PlayerManager.get_player_count():
			var fallback: Character = PlayerManager.get_player(index).get("character")
			if fallback != null:
				result.append(fallback)
	return result


## Return deterministic tactical spawn positions for the active party size.
## The positions are relative to the combat grid and remain a party concern so
## encounters cannot silently invent a second composition.
func get_formation_positions(member_count: int) -> Array[Vector2i]:
	var count := clampi(member_count, 0, MAX_PARTY_SIZE)
	var result: Array[Vector2i] = []
	for index in count:
		result.append(FORMATION_POSITIONS[index])
	return result


func has_valid_formation(member_count: int, positions: Array[Vector2i]) -> bool:
	if member_count < 0 or member_count > MAX_PARTY_SIZE or positions.size() != member_count:
		return false
	var seen: Dictionary = {}
	for position in positions:
		if seen.has(position):
			return false
		seen[position] = true
	return true


## Return active members with stable slot and local-seat ownership metadata.
func get_active_party_members() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in party_slots:
		var character_id := str(slot.get("character_id", ""))
		if not bool(slot.get("occupied", false)) or not characters.has(character_id):
			continue
		var owner := PlayerManager.get_player_for_party_slot(str(slot.get("slot_id", "")))
		result.append({
			"character": characters[character_id],
			"slot_id": str(slot.get("slot_id", "")),
			"owner_player_index": owner,
			"is_companion": bool(slot.get("is_companion", false)),
		})
	if result.is_empty():
		for index in PlayerManager.get_player_count():
			var fallback: Character = PlayerManager.get_player(index).get("character")
			if fallback != null:
				result.append({
					"character": fallback,
					"slot_id": "slot_%d" % index,
					"owner_player_index": index,
					"is_companion": false,
				})
	return result


func get_exploration_position() -> Vector2i:
	var owner := PlayerManager.get_player_for_party_slot(leader_slot_id)
	if owner >= 0:
		return PlayerManager.get_player_position(owner)
	return PlayerManager.get_player_position(PlayerManager.active_player_index)


func move_exploration_party(coord: Vector2i) -> void:
	var moved := false
	for slot in party_slots:
		var owner := PlayerManager.get_player_for_party_slot(slot.get("slot_id", ""))
		if owner >= 0:
			PlayerManager.set_player_position(owner, coord)
			moved = true
	if not moved:
		PlayerManager.set_player_position(PlayerManager.active_player_index, coord)


func serialize() -> Dictionary:
	var saved_characters := {}
	for character_id in characters:
		var character: Character = characters[character_id]
		saved_characters[character_id] = character.to_dict()
	return {
		"leader_slot_id": leader_slot_id,
		"party_slots": party_slots.duplicate(true),
		"companion_roster": companion_roster.duplicate(true),
		"characters": saved_characters,
	}


func deserialize(data: Dictionary) -> void:
	reset()
	leader_slot_id = str(data.get("leader_slot_id", "slot_0"))
	for slot_data in data.get("party_slots", []):
		if slot_data is Dictionary:
			var slot := _get_slot(str(slot_data.get("slot_id", "")))
			if not slot.is_empty():
				slot.merge(slot_data, true)
	for character_id in data.get("characters", {}):
		var character_data = data["characters"][character_id]
		if character_data is Dictionary:
			var character := Character.new()
			character.from_dict(character_data)
			characters[str(character_id)] = character
	companion_roster = data.get("companion_roster", {}).duplicate(true)


func _ensure_character_id(character: Character, fallback: String) -> void:
	if character.character_id.is_empty():
		character.character_id = "%s_%s" % [fallback, character.class_id]


func _get_slot(slot_id: String) -> Dictionary:
	for slot in party_slots:
		if slot.get("slot_id", "") == slot_id:
			return slot
	return {}


func _first_empty_slot() -> Dictionary:
	for slot in party_slots:
		if not bool(slot.get("occupied", false)):
			return slot
	return {}


func _ensure_valid_leader() -> void:
	var current := _get_slot(leader_slot_id)
	if not current.is_empty() and bool(current.get("occupied", false)):
		return
	for slot in party_slots:
		if bool(slot.get("occupied", false)):
			leader_slot_id = str(slot.get("slot_id", "slot_0"))
			leader_changed.emit(leader_slot_id)
			return
	leader_slot_id = "slot_0"


func _append_unique(values: Array[String], value: String) -> void:
	if value not in values:
		values.append(value)
