## Overworld Map Generator
## Populates a HexGrid node using active campaign data or falls back to procedural generation.
class_name OverworldMap
extends Node2D

@export var hex_grid_path: NodePath
@onready var hex_grid: HexGrid = get_node_or_null(hex_grid_path)


## Load and generate the overworld map from campaign JSON.
func generate_map() -> void:
	if hex_grid == null and get_parent() != null:
		hex_grid = get_parent().get_node_or_null("HexGrid") as HexGrid

	if hex_grid == null:
		push_error("[OverworldMap] HexGrid reference is missing!")
		return

	var campaign: Dictionary = GameManager.active_campaign
	if campaign.is_empty():
		push_warning("[OverworldMap] No active campaign. Generating procedural test map...")
		hex_grid.generate_procedural(12, 10)
	else:
		var map_data: Dictionary = campaign.get("map", {})
		var tiles_data: Array = map_data.get("tiles", [])
		
		if tiles_data.is_empty():
			push_warning("[OverworldMap] Campaign map tiles list is empty! Fallback to procedural.")
			hex_grid.generate_procedural(12, 10)
		else:
			# Load the grid with coordinates and terrain properties from JSON
			hex_grid.load_from_data(tiles_data)
			print("[OverworldMap] Successfully loaded %d tiles from campaign %s" % [tiles_data.size(), campaign.get("name", "")])
	
	var is_returning: bool = GameManager.transition_context.get("returning_from_dungeon", false) or GameManager.is_loading_save
	if not is_returning:
		_setup_player_start_positions()
	else:
		# Reveal around players
		for i in PlayerManager.get_player_count():
			var pos := PlayerManager.get_player_position(i)
			hex_grid.reveal_radius(pos, 2)


## Set starting positions for all players based on the map's start tiles.
func _setup_player_start_positions() -> void:
	var start_tiles := hex_grid.get_start_tiles()
	var start_coord := Vector2i.ZERO

	if not start_tiles.is_empty():
		start_coord = start_tiles[0].coord
	else:
		# Fallback to find any town or plains tile
		for coord in hex_grid.tiles:
			var tile: HexTile = hex_grid.tiles[coord]
			if tile.terrain == HexTile.TerrainType.TOWN or tile.terrain == HexTile.TerrainType.PLAINS:
				start_coord = coord
				break

	# Place all players at the start coordinate
	var player_count := PlayerManager.get_player_count()
	for i in player_count:
		PlayerManager.set_player_position(i, start_coord)
		print("[OverworldMap] Placed Player %d at start tile: %s" % [i + 1, start_coord])
		
	# Reveal starting area (radius 2)
	hex_grid.reveal_radius(start_coord, 2)
