## Dungeon State Controller
## Manages room-by-room exploration during dungeon crawls, handling events and boss encounters.
class_name DungeonState
extends Node2D

@onready var hex_grid: HexGrid = $HexGrid
@onready var hud: DungeonHUD = $DungeonHUD
@onready var event_dialog_scene := preload("res://scenes/ui/event_dialog.tscn")

var dungeon_id: String = ""
var dungeon_data: Dictionary = {}
var rooms: Dictionary = {} # Vector2i -> Room
var party_position := Vector2i.ZERO
var boss_defeated := false
## Room whose encounter is currently in combat. It remains uncleared until victory.
var pending_combat_room_id: int = -1


func _ready() -> void:
	# Connect grid click signals
	hex_grid.hex_clicked.connect(_on_room_clicked)

	# Wire the dungeon HUD's system row (Rest/Save/Menu/Settings/Sheet).
	# No End Turn — the dungeon is not turn-based. Real BaseHUD split, not a
	# hidden button (the BtnEndTurn node no longer exists in dungeon.tscn).
	hud.rest_pressed.connect(_on_rest_pressed)
	hud.save_pressed.connect(_on_save_pressed)
	hud.menu_pressed.connect(_on_menu_pressed)
	hud.settings_pressed.connect(_on_settings_pressed)
	hud.sheet_pressed.connect(_on_sheet_pressed)

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
		rooms.clear()
		var saved_rooms = GameManager.active_dungeon_state.get("rooms", [])
		if saved_rooms is Array:
			for room_data in saved_rooms:
				if room_data is Dictionary:
					var restored_room := Room.from_dict(room_data)
					rooms[restored_room.coord] = restored_room
		elif saved_rooms is Dictionary:
			# Scene transitions keep the in-memory active dungeon state between
			# scenes. SaveManager converts this runtime dictionary to Room DTOs
			# before writing disk saves, but a normal combat return must be able to
			# consume the live Room values without dropping the encounter map.
			for room_value in saved_rooms.values():
				if room_value is Room:
					rooms[room_value.coord] = room_value
				elif room_value is Dictionary:
					var restored_room := Room.from_dict(room_value)
					rooms[restored_room.coord] = restored_room
		else:
			rooms = {}
		var saved_position = GameManager.active_dungeon_state.get("party_position", Vector2i.ZERO)
		if saved_position is Array and saved_position.size() >= 2:
			party_position = Vector2i(int(saved_position[0]), int(saved_position[1]))
		elif saved_position is Vector2i:
			party_position = saved_position
		else:
			party_position = Vector2i.ZERO
		boss_defeated = GameManager.active_dungeon_state.get("boss_defeated", false)
		pending_combat_room_id = int(GameManager.active_dungeon_state.get("pending_combat_room_id", -1))
		is_restored = true
	else:
		# Generate rooms
		rooms = DungeonGenerator.generate_dungeon(dungeon_data)
		party_position = Vector2i.ZERO
		var already_cleared := dungeon_id in GameManager.cleared_dungeons
		if already_cleared:
			# A cleared dungeon is still visitable, but its one-time encounters and
			# rewards cannot be replayed after the active state was discarded.
			for room in rooms.values():
				room.is_cleared = true
				room.is_revealed = true
			boss_defeated = true
		else:
			# Trigger Milestone Enter if specified
			var milestone_enter = dungeon_data.get("milestone_enter")
			if milestone_enter != null:
				GameManager.check_milestone(str(milestone_enter))
			boss_defeated = false
		pending_combat_room_id = -1
		_save_dungeon_state_to_manager()
		if already_cleared:
			hud.add_log("[color=yellow]This dungeon has already been cleared. Its rewards cannot be claimed again.[/color]")

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
			_begin_room_combat(room)
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
			var char_data: Character = PartyManager.get_active_characters()[0] if not PartyManager.get_active_characters().is_empty() else PlayerManager.get_active_player().get("character")
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
			_begin_room_combat(room)
			GameManager.enter_combat(room.monster_ids, false, GameManager.GameState.DUNGEON, tile_terrain)

		_:
			room.is_cleared = true
			_save_dungeon_state_to_manager()


func _trigger_dungeon_event_ui(event_data: Dictionary, room: Room) -> void:
	var dialog: EventDialog = event_dialog_scene.instantiate()
	add_child(dialog)
	dialog.popup_event(PlayerManager.get_active_player()["character"], event_data)
	
	dialog.event_resolved.connect(func(result: Dictionary):
		hud.add_log(result.get("message", "Trap resolved."))
		hud.update_hud()
		
		# Check if trap triggered combat
		var next_combat: Array = result.get("monsters", [])
		if not next_combat.is_empty():
			var tile_terrain := "plains"
			var current_tile := hex_grid.get_tile(party_position)
			if current_tile != null:
				tile_terrain = current_tile.get_terrain_name()
			_begin_room_combat(room)
			GameManager.enter_combat(next_combat, result.get("surprise", false), GameManager.GameState.DUNGEON, tile_terrain)
			return
		
		room.is_cleared = true
		_save_dungeon_state_to_manager()
		if PlayerManager.is_party_wiped():
			_handle_defeat()
	)


func _handle_combat_result(combat_result: String) -> void:
	if combat_result == "victory":
		hud.add_log("Victory in battle!")
		var completed_room := _complete_pending_combat()
		if completed_room != null and completed_room.type == Room.RoomType.BOSS:
			_clear_dungeon_successfully()
	else:
		_handle_defeat()


## Record the room being resolved without consuming the encounter.
## This is written before the scene transition so the authoritative state knows
## which room must be completed when combat returns with a victory result.
func _begin_room_combat(room: Room) -> void:
	pending_combat_room_id = room.id
	_save_dungeon_state_to_manager()


## Apply the only combat result that clears a dungeon room. Defeat leaves the
## pending room intact, so the unresolved encounter cannot be skipped.
func _complete_pending_combat() -> Room:
	if pending_combat_room_id < 0:
		return null
	var completed_room: Room = null
	for room in rooms.values():
		if room is Room and room.id == pending_combat_room_id:
			completed_room = room
			break
	if completed_room == null:
		push_error("[DungeonState] Pending combat room %d was not found." % pending_combat_room_id)
		return null
	completed_room.is_cleared = true
	if completed_room.type == Room.RoomType.BOSS:
		boss_defeated = true
	pending_combat_room_id = -1
	_save_dungeon_state_to_manager()
	return completed_room


func _handle_defeat() -> void:
	hud.add_log("[color=red]Party was wiped. Opening defeat screen...[/color]")
	hex_grid.set_process_input(false)
	GameManager.end_game(false, "The party was defeated in the dungeon.")


func _clear_dungeon_successfully() -> void:
	hud.add_log("[color=green]DUNGEON CLEARED SUCCESSFULLY![/color]")
	if not GameManager.mark_dungeon_cleared(dungeon_id):
		hud.add_log("This dungeon has already been cleared. No duplicate rewards granted.")
		await get_tree().create_timer(1.0).timeout
		GameManager.exit_dungeon()
		return
	
	# Give campaign rewards to the party
	var active_members := PartyManager.get_active_characters()
	var active_char: Character = active_members[0] if not active_members.is_empty() else PlayerManager.get_active_player().get("character")
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


## --- System-row handlers (mirror OverworldState) ---

func _on_rest_pressed() -> void:
	_rest_party()
	hud.add_log("[color=green]The party makes camp and rests. HP, spell slots, and feature uses restored.[/color]")
	hud.update_hud()

func _on_save_pressed() -> void:
	if not GameManager.game_in_progress:
		hud.add_log("[color=orange]Nothing to save yet.[/color]")
		return
	var ok := SaveManager.save_game("quicksave")
	if ok:
		hud.add_log("[color=green]Game saved to 'quicksave'.[/color]")
	else:
		hud.add_log("[color=red]Save failed (see logs).[/color]")

func _on_menu_pressed() -> void:
	hud.add_log("[color=yellow]Returning to main menu...[/color]")
	hex_grid.set_process_input(false)
	GameManager.return_to_menu()

func _on_settings_pressed() -> void:
	Settings.open_settings(self)

func _on_sheet_pressed() -> void:
	CharacterSheet.show_active()

## Heal and restore the whole party (no gold cost). Mirrors ShopUI/OverworldState.
func _rest_party() -> void:
	for char_data in PartyManager.get_active_characters():
		if char_data == null:
			continue
		char_data.long_rest()

func _save_dungeon_state_to_manager() -> void:
	GameManager.active_dungeon_state = {
		"dungeon_id": dungeon_id,
		"rooms": rooms,
		"party_position": party_position,
		"boss_defeated": boss_defeated,
		"pending_combat_room_id": pending_combat_room_id,
		"save_checkpoint": party_position == Vector2i.ZERO,
	}
