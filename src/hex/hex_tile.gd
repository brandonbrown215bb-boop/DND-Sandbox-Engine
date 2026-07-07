## Hex Tile
## Represents a single hexagonal tile on the grid.
## Stores terrain type, fog of war state, occupants, and event data.
class_name HexTile
extends RefCounted

## Terrain type identifiers matching campaign JSON data.
enum TerrainType {
	PLAINS,
	FOREST,
	MOUNTAIN,
	WATER,
	TOWN,
	DUNGEON_ENTRANCE,
	SWAMP,
	DESERT,
	ROAD,
}

## Map string terrain names from JSON to enum values.
const TERRAIN_MAP := {
	"plains": TerrainType.PLAINS,
	"forest": TerrainType.FOREST,
	"mountain": TerrainType.MOUNTAIN,
	"water": TerrainType.WATER,
	"town": TerrainType.TOWN,
	"dungeon_entrance": TerrainType.DUNGEON_ENTRANCE,
	"swamp": TerrainType.SWAMP,
	"desert": TerrainType.DESERT,
	"road": TerrainType.ROAD,
}

## Default movement costs per terrain type.
const MOVEMENT_COSTS := {
	TerrainType.PLAINS: 1.0,
	TerrainType.FOREST: 2.0,
	TerrainType.MOUNTAIN: 3.0,
	TerrainType.WATER: INF,      # Impassable by default
	TerrainType.TOWN: 1.0,
	TerrainType.DUNGEON_ENTRANCE: 1.0,
	TerrainType.SWAMP: 2.0,
	TerrainType.DESERT: 1.5,
	TerrainType.ROAD: 0.5,
}

## Default terrain colors for placeholder rendering.
const TERRAIN_COLORS := {
	TerrainType.PLAINS: Color(0.56, 0.74, 0.34),       # Green
	TerrainType.FOREST: Color(0.18, 0.42, 0.15),       # Dark green
	TerrainType.MOUNTAIN: Color(0.55, 0.50, 0.45),     # Grey-brown
	TerrainType.WATER: Color(0.20, 0.45, 0.75),        # Blue
	TerrainType.TOWN: Color(0.76, 0.65, 0.42),         # Tan
	TerrainType.DUNGEON_ENTRANCE: Color(0.35, 0.15, 0.35), # Dark purple
	TerrainType.SWAMP: Color(0.35, 0.45, 0.25),        # Murky green
	TerrainType.DESERT: Color(0.85, 0.75, 0.50),       # Sand
	TerrainType.ROAD: Color(0.60, 0.55, 0.45),         # Dusty brown
}

## Axial coordinate of this tile on the grid.
var coord: Vector2i = Vector2i.ZERO

## The terrain type of this tile.
var terrain: TerrainType = TerrainType.PLAINS

## The display name of a named location (e.g., town name). Empty for generic tiles.
var location_name: String = ""

## Whether this tile has been revealed (fog of war lifted).
var is_revealed: bool = false

## Whether this tile is currently visible (within a player's vision range).
var is_visible: bool = false

## IDs of entities currently occupying this tile (player characters, NPCs, monsters).
var occupants: Array[String] = []

## The event table ID used for random events on this tile (defaults to terrain-based).
var event_table_id: String = ""

## Optional dungeon ID if this is a dungeon entrance tile.
var dungeon_id: String = ""

## Whether this tile is a starting position for players.
var is_start: bool = false

## Custom properties from campaign JSON (arbitrary key-value pairs for modding).
var custom_properties: Dictionary = {}


## Get the movement cost to enter this tile.
func get_movement_cost() -> float:
	return MOVEMENT_COSTS.get(terrain, 1.0)


## Whether this tile can be walked on.
func is_passable() -> bool:
	return get_movement_cost() < INF


## Get the placeholder color for this terrain type.
func get_color() -> Color:
	return TERRAIN_COLORS.get(terrain, Color.WHITE)


## Get the terrain type name as a string.
func get_terrain_name() -> String:
	for key in TERRAIN_MAP:
		if TERRAIN_MAP[key] == terrain:
			return key
	return "unknown"


## Create a HexTile from campaign JSON data.
static func from_dict(data: Dictionary) -> HexTile:
	var tile := HexTile.new()
	tile.coord = Vector2i(data.get("q", 0), data.get("r", 0))

	var terrain_str: String = data.get("terrain", "plains")
	tile.terrain = TERRAIN_MAP.get(terrain_str, TerrainType.PLAINS)

	tile.location_name = data.get("name", "")
	tile.event_table_id = data.get("event_table", "")
	tile.dungeon_id = data.get("dungeon_id", "")
	tile.is_start = data.get("start", false)

	# Store any unrecognized keys as custom properties
	var known_keys := ["q", "r", "terrain", "name", "event_table", "dungeon_id", "start"]
	for key in data:
		if key not in known_keys:
			tile.custom_properties[key] = data[key]

	return tile


## Serialize this tile back to a Dictionary (for saving/debugging).
func to_dict() -> Dictionary:
	var data := {
		"q": coord.x,
		"r": coord.y,
		"terrain": get_terrain_name(),
	}
	if not location_name.is_empty():
		data["name"] = location_name
	if not event_table_id.is_empty():
		data["event_table"] = event_table_id
	if not dungeon_id.is_empty():
		data["dungeon_id"] = dungeon_id
	if is_start:
		data["start"] = true
	data.merge(custom_properties)
	return data
