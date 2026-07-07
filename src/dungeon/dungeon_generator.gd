## Dungeon Layout Generator
## Generates a sequential grid of room nodes for dungeon crawlers.
class_name DungeonGenerator
extends RefCounted


## Generate rooms based on campaign dungeon configuration.
## Returns a Dictionary[Vector2i, Room] mapping coordinates to Room objects.
static func generate_dungeon(dungeon_data: Dictionary) -> Dictionary:
	var rooms: Dictionary = {}
	var room_count: int = int(dungeon_data.get("room_count", 5))
	var monster_pool: Array = dungeon_data.get("monster_pool", ["goblin"])
	var boss_data: Dictionary = dungeon_data.get("boss", {})

	# Start at (0, 0) as Entrance
	var entrance_coord := Vector2i.ZERO
	var entrance := Room.new()
	entrance.id = 0
	entrance.coord = entrance_coord
	entrance.type = Room.RoomType.ENTRANCE
	entrance.is_visited = true
	entrance.is_cleared = true
	rooms[entrance_coord] = entrance

	# Choose a random direction to build rooms sequentially
	var current_coord := entrance_coord
	var directions := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	directions.shuffle()
	var dir: Vector2i = directions[0]

	# Build intermediate rooms
	for i in range(1, room_count - 1):
		current_coord += dir
		
		var room := Room.new()
		room.id = i
		room.coord = current_coord
		
		# Distribute room types randomly
		var roll := randf()
		if roll < 0.5:
			room.type = Room.RoomType.COMBAT
			# Select 1-3 monsters from pool
			var count := randi_range(1, 3)
			for j in count:
				room.monster_ids.append(monster_pool.pick_random())
		elif roll < 0.7:
			room.type = Room.RoomType.TRAP
			room.event_id = "trapped_chest"
		elif roll < 0.9:
			room.type = Room.RoomType.LOOT
			room.loot_item_ids.append("gold_100")
			if randf() < 0.5:
				room.loot_item_ids.append("potion_healing")
		else:
			room.type = Room.RoomType.EMPTY

		rooms[current_coord] = room

	# Place Boss room at the end
	current_coord += dir
	var boss_room := Room.new()
	boss_room.id = room_count - 1
	boss_room.coord = current_coord
	boss_room.type = Room.RoomType.BOSS
	
	var boss_id: String = boss_data.get("monster_id", "goblin_chief")
	boss_room.monster_ids.append(boss_id)
	
	rooms[current_coord] = boss_room

	print("[DungeonGenerator] Procedurally built dungeon with %d rooms." % rooms.size())
	return rooms
