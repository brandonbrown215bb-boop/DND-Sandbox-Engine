## Dungeon State Controller
## Manages room-by-room exploration during dungeon crawls, handling events and boss encounters.
class_name DungeonState
extends Node2D

@onready var hex_grid: HexGrid = $HexGrid
@onready var hud: OverworldHUD = $DungeonHUD
@onready var event_dialog_scene := preload("res://scenes/ui/event_dialog.tscn")

var dungeon_id: String = ""
var dungeon_data: Dictionary = {}
var rooms: Dictionary = {} # Vector2i -> Room
var party_position := Vector2i.ZERO
var boss_defeated := false


func _ready() -> void:
	# Connect grid click signals
	hex_grid.hex_clicked.connect(_on_room_clicked)
	hud.btn_end_turn.visible = false # Not turn-based in overworld sense; players move as a single party

	# Center the hex grid in the visible area to the left of the sidebar
	hex_grid.position = Vector2(515, 295)

	# Get active dungeon ID from GameManager context or existing state
	if not GameManager.active_dungeon_state.is_empty():
		dungeon_id = GameManager.active_dungeon_state.get("dungeon_id", "")
	else:
		dungeon_id = GameManager.transition_context.get("dungeon_id", "ruins_of_ashvale")
	
	# Fetch details from active campaign
	var campaign = GameManager.active_campaign
	var dungeons: Dictionary = campaign.get("dungeons", {})
	dungeon_data = dungeons.get(dungeon_id, {})

	if dungeon_data.is_empty():
		push_error("[DungeonState] Dungeon configuration not found for: %s" % dungeon_id)
		GameManager.exit_dungeon()
		return

	# Setup HUD
	hud.clear_logs()
	hud.add_log("[color=purple]Entered Dungeon: %s[/color]" % dungeon_data.get("name", dungeon_id))
	hud.add_log(dungeon_data.get("description", ""))

	var is_restored := false
	if not GameManager.active_dungeon_state.is_empty() and GameManager.active_dungeon_state.get("dungeon_id") == dungeon_id:
		rooms = GameManager.active_dungeon_state.get("rooms", {})
		party_position = GameManager.active_dungeon_state.get("party_position", Vector2i.ZERO)
		boss_defeated = GameManager.active_dungeon_state.get("boss_defeated", false)
		is_restored = true
	else:
		# Trigger Milestone Enter if specified
		var milestone_enter = dungeon_data.get("milestone_enter")
		if milestone_enter != null:
			GameManager.check_milestone(str(milestone_enter))

		# Generate rooms
		rooms = DungeonGenerator.generate_dungeon(dungeon_data)
		party_position = Vector2i.ZERO
		boss_defeated = false
		_save_dungeon_state_to_manager()

	# Map rooms to HexGrid
	_build_tactical_rooms_grid()
	
	# Process combat result if returning from combat
	var combat_result: String = GameManager.transition_context.get("combat_result", "")
	if not combat_result.is_empty():
		GameManager.transition_context["combat_result"] = ""
		_handle_combat_result(combat_result)
	
	_highlight_accessible_rooms()
	hud.update_hud()


func _build_tactical_rooms_grid() -> void:
	hex_grid.tiles.clear()
	for coord in rooms:
		var room: Room = rooms[coord]
		var tile := HexTile.new()
		tile.coord = coord
		
		# Map RoomType to a visual terrain representation
		match room.type:
			Room.RoomType.ENTRANCE:
				tile.terrain = HexTile.TerrainType.TOWN
				tile.location_name = "Entrance"
			Room.RoomType.COMBAT:
				tile.terrain = HexTile.TerrainType.SWAMP
				tile.location_name = "Encounter"
			Room.RoomType.TRAP:
				tile.terrain = HexTile.TerrainType.ROAD
				tile.location_name = "Trap"
			Room.RoomType.LOOT:
				tile.terrain = HexTile.TerrainType.DESERT
				tile.location_name = "Chest"
			Room.RoomType.BOSS:
				tile.terrain = HexTile.TerrainType.DUNGEON_ENTRANCE
				tile.location_name = "Boss Room"
			_:
				tile.terrain = HexTile.TerrainType.PLAINS
				tile.location_name = "Empty Room"

		tile.is_revealed = room.is_revealed or room.is_visited or (coord == Vector2i.ZERO)
		tile.is_visible = true
		hex_grid.add_tile(tile)


func _highlight_accessible_rooms() -> void:
	hex_grid.clear_highlights()
	
	# Can move to any adjacent room that is already generated
	var neighbors := HexUtils.get_neighbors(party_position)
	var highlights := {}
	
	# Draw active player position
	highlights[party_position] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SELECTED]

	for neighbor in neighbors:
		if neighbor in rooms:
			# Reveal adjacent rooms (fog of war lift)
			var room: Room = rooms[neighbor]
			room.is_revealed = true
			hex_grid.reveal_tile(neighbor)
			highlights[neighbor] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.MOVEMENT]

	hex_grid.set_highlights(highlights)
	_save_dungeon_state_to_manager()


func _on_room_clicked(coord: Vector2i) -> void:
	if coord == party_position: return
	
	# Must be neighbor room
	var dist := HexUtils.get_distance(party_position, coord)
	if dist > 1 or coord not in rooms:
		return

	# Move party position
	party_position = coord
	var room: Room = rooms[coord]
	room.is_visited = true

	hud.add_log("Moved to room %s (%s)" % [coord, room.type])
	
	# Update highlights
	_highlight_accessible_rooms()

	# Resolve Room encounter
	_resolve_room_encounter(room)


func _resolve_room_encounter(room: Room) -> void:
	if room.is_cleared:
		hud.add_log("This room is empty and cleared.")
		return

	var tile_terrain := "plains"
	var current_tile := hex_grid.get_tile(party_position)
	if current_tile != null:
		tile_terrain = current_tile.get_terrain_name()

	match room.type:
		Room.RoomType.COMBAT:
			hud.add_log("[color=red]Monsters spotted! Prepare for battle.[/color]")
			room.is_cleared = true
			_save_dungeon_state_to_manager()
			GameManager.enter_combat(room.monster_ids, false, GameManager.GameState.DUNGEON, tile_terrain)
			
		Room.RoomType.TRAP:
			# Pop up chest event
			var event_table := DataLoader.get_event_table("dungeon_events")
			var event_data: Dictionary = {}
			for ev in event_table.get("events", []):
				if ev["id"] == room.event_id:
					event_data = ev
					break
			
			if not event_data.is_empty():
				_trigger_dungeon_event_ui(event_data, room)
			else:
				room.is_cleared = true
				_save_dungeon_state_to_manager()

		Room.RoomType.LOOT:
			hud.add_log("[color=green]You found a treasure chest![/color]")
			# Grant loot items to the active character
			var char_data: Character = PlayerManager.get_active_player()["character"]
			for item_id in room.loot_item_ids:
				if item_id.begins_with("gold_"):
					var amount: int = item_id.substr(5).to_int()
					char_data.inventory.gold += amount
					hud.add_log("%s received %d gold!" % [char_data.character_name, amount])
				else:
					char_data.inventory.add_item(item_id)
					var item_name: String = DataLoader.get_item(item_id).get("name", item_id)
					hud.add_log("%s received %s!" % [char_data.character_name, item_name])
			room.is_cleared = true
			_save_dungeon_state_to_manager()
			hud.update_hud()

		Room.RoomType.BOSS:
			hud.add_log("[color=purple]Entering the Boss Chamber! The guardian awaits.[/color]")
			room.is_cleared = true
			boss_defeated = true
			_save_dungeon_state_to_manager()
			GameManager.enter_combat(room.monster_ids, false, GameManager.GameState.DUNGEON, tile_terrain)

		_:
			room.is_cleared = true
			_save_dungeon_state_to_manager()


func _trigger_dungeon_event_ui(event_data: Dictionary, room: Room) -> void:
	var dialog: EventDialog = event_dialog_scene.instantiate()
	add_child(dialog)
	dialog.popup_event(PlayerManager.get_active_player()["character"], event_data)
	
	dialog.event_resolved.connect(func(result: Dictionary):
		room.is_cleared = true
		_save_dungeon_state_to_manager()
		hud.add_log(result.get("message", "Trap resolved."))
		hud.update_hud()
		
		# Check if trap triggered combat
		var next_combat: Array = result.get("monsters", [])
		if not next_combat.is_empty():
			var tile_terrain := "plains"
			var current_tile := hex_grid.get_tile(party_position)
			if current_tile != null:
				tile_terrain = current_tile.get_terrain_name()
			GameManager.enter_combat(next_combat, result.get("surprise", false), GameManager.GameState.DUNGEON, tile_terrain)
			return
		
		if PlayerManager.is_party_wiped():
			_handle_defeat()
	)


func _handle_combat_result(combat_result: String) -> void:
	if combat_result == "victory":
		hud.add_log("Victory in battle!")
		if boss_defeated:
			_clear_dungeon_successfully()
	else:
		_handle_defeat()


func _handle_defeat() -> void:
	hud.add_log("[color=red]Party was wiped. Returning to menu...[/color]")
	hex_grid.set_process_input(false)
	await get_tree().create_timer(3.0).timeout
	GameManager.return_to_menu()


func _clear_dungeon_successfully() -> void:
	hud.add_log("[color=green]DUNGEON CLEARED SUCCESSFULLY![/color]")
	
	# Give campaign rewards to the party
	var active_char: Character = PlayerManager.get_active_player()["character"]
	var loot_list: Array = dungeon_data.get("loot", [])
	
	if loot_list.is_empty():
		active_char.inventory.add_item("crown_fragment")
		hud.add_log("%s claimed the Crown Fragment!" % active_char.character_name)
	else:
		for loot_item in loot_list:
			var item_id: String = loot_item.get("item_id", "")
			if not item_id.is_empty():
				if item_id.begins_with("gold_"):
					var amount: int = item_id.substr(5).to_int()
					active_char.inventory.gold += amount
					hud.add_log("%s received %d gold!" % [active_char.character_name, amount])
				else:
					active_char.inventory.add_item(item_id)
					var item_name: String = DataLoader.get_item(item_id).get("name", item_id)
					hud.add_log("%s received %s!" % [active_char.character_name, item_name])

	# Trigger Milestone Clear if specified
	var milestone_clear = dungeon_data.get("milestone_clear")
	if milestone_clear != null:
		GameManager.check_milestone(str(milestone_clear))

	# Return to overworld
	await get_tree().create_timer(3.0).timeout
	GameManager.exit_dungeon()


func _save_dungeon_state_to_manager() -> void:
	GameManager.active_dungeon_state = {
		"dungeon_id": dungeon_id,
		"rooms": rooms,
		"party_position": party_position,
		"boss_defeated": boss_defeated
	}
