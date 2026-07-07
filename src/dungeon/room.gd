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
