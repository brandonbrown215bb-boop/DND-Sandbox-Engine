## Dungeon Room Data Structure
## Represents an individual room in a dungeon crawl layout.
class_name Room
extends RefCounted

## Different types of rooms.
enum RoomType {
	ENTRANCE,
	EMPTY,
	TRAP,
	COMBAT,
	LOOT,
	BOSS,
}

var id: int = 0
var coord: Vector2i = Vector2i.ZERO
var type: RoomType = RoomType.EMPTY
var is_visited: bool = false
var is_cleared: bool = false
var is_revealed: bool = false

# Encounter/Loot details
var monster_ids: Array = []
var loot_item_ids: Array = []
var event_id: String = ""


## Map string name from JSON or generator to RoomType.
static func name_to_type(name_str: String) -> RoomType:
	match name_str.to_upper():
		"ENTRANCE": return RoomType.ENTRANCE
		"TRAP": return RoomType.TRAP
		"COMBAT": return RoomType.COMBAT
		"LOOT": return RoomType.LOOT
		"BOSS": return RoomType.BOSS
		_: return RoomType.EMPTY


## Plain save DTO. Runtime Room objects never cross the save boundary.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"coord": [coord.x, coord.y],
		"type": int(type),
		"is_visited": is_visited,
		"is_cleared": is_cleared,
		"is_revealed": is_revealed,
		"monster_ids": monster_ids.duplicate(),
		"loot_item_ids": loot_item_ids.duplicate(),
		"event_id": event_id,
	}


## Restore a Room from a validated plain save DTO.
static func from_dict(data: Dictionary) -> Room:
	var room := Room.new()
	room.id = int(data.get("id", 0))
	var raw_coord: Array = data.get("coord", [0, 0])
	if raw_coord.size() >= 2:
		room.coord = Vector2i(int(raw_coord[0]), int(raw_coord[1]))
	room.type = int(data.get("type", RoomType.EMPTY))
	room.is_visited = bool(data.get("is_visited", false))
	room.is_cleared = bool(data.get("is_cleared", false))
	room.is_revealed = bool(data.get("is_revealed", false))
	room.monster_ids.assign(data.get("monster_ids", []))
	room.loot_item_ids.assign(data.get("loot_item_ids", []))
	room.event_id = str(data.get("event_id", ""))
	return room
