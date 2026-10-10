## Hex Art Helper
## Manages texture loading and rendering for hex tiles, tabletop character/monster tokens,
## and glowing tactical highlights under the Modern Dark VTT theme.
class_name HexArt
extends RefCounted

const TERRAIN_SHEET_PATH := "res://assets/tiles/terrain_sheet.jpg"
const TOKENS_SHEET_PATH := "res://assets/tokens/tokens_sheet.jpg"

static var _terrain_texture: Texture2D = null
static var _tokens_texture: Texture2D = null
static var _textures_checked: bool = false

## 3x3 Terrain layout mapping HexTile.TerrainType to (col, row)
const TERRAIN_CELLS := {
	HexTile.TerrainType.PLAINS: Vector2i(0, 0),
	HexTile.TerrainType.FOREST: Vector2i(1, 0),
	HexTile.TerrainType.MOUNTAIN: Vector2i(2, 0),
	HexTile.TerrainType.WATER: Vector2i(0, 1),
	HexTile.TerrainType.TOWN: Vector2i(1, 1),
	HexTile.TerrainType.DUNGEON_ENTRANCE: Vector2i(2, 1),
	HexTile.TerrainType.SWAMP: Vector2i(0, 2),
	HexTile.TerrainType.DESERT: Vector2i(1, 2),
	HexTile.TerrainType.ROAD: Vector2i(2, 2),
}

## 4x4 Token layout mapping class/monster id to (col, row)
const TOKEN_CELLS := {
	# Row 0: Players
	"fighter": Vector2i(0, 0),
	"wizard": Vector2i(1, 0),
	"rogue": Vector2i(2, 0),
	"cleric": Vector2i(3, 0),
	# Row 1: Players
	"monk": Vector2i(0, 1),
	"barbarian": Vector2i(1, 1),
	"ranger": Vector2i(2, 1),
	"paladin": Vector2i(3, 1),
	# Row 2: Monsters
	"goblin": Vector2i(0, 2),
	"goblin_warrior": Vector2i(0, 2),
	"goblin_archer": Vector2i(1, 2),
	"skeleton": Vector2i(2, 2),
	"zombie": Vector2i(3, 2),
	# Row 3: Monsters & Other
	"wolf": Vector2i(0, 3),
	"dire_wolf": Vector2i(0, 3),
	"lich": Vector2i(1, 3),
	"lich_king": Vector2i(1, 3),
	"the_lich_king": Vector2i(1, 3),
	"orc": Vector2i(2, 3),
	"bandit": Vector2i(2, 3),
	"sorcerer": Vector2i(3, 3),
	"warlock": Vector2i(3, 3),
	"druid": Vector2i(2, 1),
	"bard": Vector2i(1, 0),
}


static func _ensure_textures() -> void:
	if _textures_checked:
		return
	_textures_checked = true
	if ResourceLoader.exists(TERRAIN_SHEET_PATH):
		_terrain_texture = load(TERRAIN_SHEET_PATH) as Texture2D
	if ResourceLoader.exists(TOKENS_SHEET_PATH):
		_tokens_texture = load(TOKENS_SHEET_PATH) as Texture2D


## Draw a textured pointy-top hex tile.
## Returns true if rendered with texture; false if caller should fall back to solid polygon.
static func draw_tile(ci: CanvasItem, center: Vector2, size: float, tile: HexTile, points: PackedVector2Array) -> bool:
	_ensure_textures()
	if _terrain_texture == null:
		return false
	
	if not tile.is_revealed:
		# Fog of War: dark atmospheric slate with subtle border
		var fog_color := Color(0.08, 0.08, 0.10, 0.95)
		ci.draw_colored_polygon(points, fog_color)
		var fog_border := Color(0.04, 0.04, 0.05, 0.8)
		for i in 6:
			ci.draw_line(points[i], points[(i + 1) % 6], fog_border, 1.0)
		return true

	var cell: Vector2i = TERRAIN_CELLS.get(tile.terrain, Vector2i(0, 0))
	var col := float(cell.x)
	var row := float(cell.y)
	
	# In 3x3 grid:
	var uv_center := Vector2((col + 0.5) / 3.0, (row + 0.5) / 3.0)
	var uv_radius := (1.0 / 3.0) * 0.47
	
	var uvs := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		uvs.append(uv_center + Vector2(cos(angle), sin(angle)) * uv_radius)
	
	ci.draw_colored_polygon(points, Color.WHITE, uvs, _terrain_texture)
	
	# Crisp beveled border
	var border_color := Color(0.12, 0.12, 0.15, 0.65)
	for i in 6:
		ci.draw_line(points[i], points[(i + 1) % 6], border_color, 1.0)
	
	return true


## Draw an illustrated circular tabletop token for an entity.
## Returns true if rendered with token art; false if caller should fall back to primitive circle.
static func draw_token(ci: CanvasItem, center: Vector2, radius: float, entity: Dictionary) -> bool:
	var emanation_radius := int(entity.get("spell_emanation_radius_hexes", 0))
	if emanation_radius > 0:
		var emanation_color: Color = entity.get("spell_emanation_color", Color(0.6, 0.83, 0.96))
		var emanation_pixels := float(emanation_radius) * HexUtils.HEX_SIZE
		ci.draw_circle(center, emanation_pixels, Color(emanation_color, 0.045))
		ci.draw_arc(center, emanation_pixels, 0.0, TAU, 72, Color(emanation_color, 0.48), 1.5)
	if bool(entity.get("is_dancing_light", false)):
		ci.draw_circle(center, float(entity.get("dim_light_radius_hexes", DancingLightsRules.DIM_LIGHT_RADIUS_HEXES)) * HexUtils.HEX_SIZE, Color(0.42, 0.76, 1.0, 0.045))
		ci.draw_circle(center, radius + 8.0, Color(0.35, 0.75, 1.0, 0.2))
		ci.draw_circle(center, radius + 3.0, Color(0.55, 0.88, 1.0, 0.55))
		ci.draw_circle(center, radius, Color(0.82, 0.96, 1.0))
		ci.draw_circle(center, radius, Color(0.55, 0.86, 1.0), false, 1.5)
		return true
	if bool(entity.get("is_spell_light", false)):
		ci.draw_circle(center, float(entity.get("dim_light_radius_hexes", LightRules.DIM_RADIUS_HEXES)) * HexUtils.HEX_SIZE, Color(1.0, 0.83, 0.36, 0.035))
		ci.draw_circle(center, float(entity.get("bright_light_radius_hexes", LightRules.BRIGHT_RADIUS_HEXES)) * HexUtils.HEX_SIZE, Color(1.0, 0.9, 0.56, 0.07))
		ci.draw_circle(center, radius + 6.0, Color(1.0, 0.76, 0.25, 0.22))
		ci.draw_circle(center, radius, Color(1.0, 0.91, 0.52))
		ci.draw_circle(center, radius, Color(1.0, 0.72, 0.2), false, 1.5)
		return true
	if bool(entity.get("is_physical_light_source", false)):
		var light_color: Color = entity.get("color", Color(1.0, 0.78, 0.36))
		ci.draw_circle(center, float(entity.get("dim_light_radius_hexes", 0)) * HexUtils.HEX_SIZE, Color(light_color, 0.035))
		ci.draw_circle(center, float(entity.get("bright_light_radius_hexes", 0)) * HexUtils.HEX_SIZE, Color(light_color, 0.075))
		ci.draw_circle(center, radius + 5.0, Color(light_color, 0.18))
		ci.draw_circle(center, radius, Color(1.0, 0.9, 0.62))
		ci.draw_circle(center, radius, Color(light_color, 0.75), false, 1.5)
		return true
	if bool(entity.get("is_mage_hand", false)):
		ci.draw_circle(center, radius + 8.0, Color(0.72, 0.52, 1.0, 0.18))
		ci.draw_circle(center, radius + 3.0, Color(0.8, 0.68, 1.0, 0.56))
		ci.draw_circle(center, radius, Color(0.9, 0.84, 1.0))
		ci.draw_circle(center, radius, Color(0.63, 0.42, 1.0), false, 1.5)
		return true
	if bool(entity.get("is_minor_illusion", false)):
		var illusion_color := Color(0.56, 0.66, 1.0) if str(entity.get("form", "")) == "sound" else Color(0.78, 0.57, 1.0)
		ci.draw_circle(center, radius + 7.0, Color(illusion_color, 0.18))
		ci.draw_circle(center, radius + 3.0, Color(illusion_color, 0.54))
		if str(entity.get("form", "")) == "sound":
			ci.draw_arc(center, radius * 0.42, -0.8, 0.8, 12, Color.WHITE, 1.5)
			ci.draw_arc(center, radius * 0.7, -0.65, 0.65, 12, Color.WHITE, 1.2)
		else:
			var diamond := PackedVector2Array([center + Vector2(0, -radius * 0.55), center + Vector2(radius * 0.55, 0), center + Vector2(0, radius * 0.55), center + Vector2(-radius * 0.55, 0)])
			ci.draw_colored_polygon(diamond, Color(0.96, 0.9, 1.0))
		return true
	if bool(entity.get("is_prestidigitation", false)):
		var effect_color := Color(0.94, 0.77, 0.43) if str(entity.get("effect_type", "")) == "magic_mark" else Color(0.54, 0.85, 0.74)
		ci.draw_circle(center, radius + 6.0, Color(effect_color, 0.22))
		ci.draw_circle(center, radius + 2.0, Color(effect_color, 0.62))
		ci.draw_circle(center, radius * 0.35, Color.WHITE)
		return true
	if bool(entity.get("is_produce_flame", false)):
		var flame_color := Color(1.0, 0.43, 0.12)
		ci.draw_circle(center, float(entity.get("dim_light_radius_hexes", ProduceFlameRules.DIM_LIGHT_RADIUS_HEXES)) * HexUtils.HEX_SIZE, Color(flame_color, 0.035))
		ci.draw_circle(center, float(entity.get("bright_light_radius_hexes", ProduceFlameRules.BRIGHT_LIGHT_RADIUS_HEXES)) * HexUtils.HEX_SIZE, Color(1.0, 0.77, 0.32, 0.07))
		ci.draw_circle(center, radius + 8.0, Color(flame_color, 0.20))
		ci.draw_circle(center, radius + 3.0, Color(1.0, 0.74, 0.25, 0.72))
		var flame_shape := PackedVector2Array([center + Vector2(0, -radius * 0.72), center + Vector2(radius * 0.25, -radius * 0.1), center + Vector2(radius * 0.12, radius * 0.42), center + Vector2(-radius * 0.12, radius * 0.42), center + Vector2(-radius * 0.25, -radius * 0.1)])
		ci.draw_colored_polygon(flame_shape, Color(1.0, 0.91, 0.53))
		return true
	_ensure_textures()
	if _tokens_texture == null:
		return false
	
	var is_player: bool = entity.get("is_player", false)
	var token_key := ""
	
	if entity.has("character") and entity["character"] != null:
		var ch = entity["character"]
		token_key = str(ch.class_id).to_lower()
	elif entity.has("player_index"):
		var p_idx: int = entity["player_index"]
		var p_data = PlayerManager.get_player(p_idx)
		if p_data != null and p_data.get("character") != null:
			token_key = str(p_data["character"].class_id).to_lower()
	elif entity.has("monster"):
		var m = entity["monster"]
		var m_id := str(m.get("id", m.get("monster_id", m.get("name", "")))).to_lower()
		token_key = m_id
	
	# Resolve cell in 4x4 atlas
	var cell: Vector2i
	if TOKEN_CELLS.has(token_key):
		cell = TOKEN_CELLS[token_key]
	else:
		if "goblin" in token_key:
			cell = TOKEN_CELLS["goblin"]
		elif "skeleton" in token_key:
			cell = TOKEN_CELLS["skeleton"]
		elif "zombie" in token_key:
			cell = TOKEN_CELLS["zombie"]
		elif "lich" in token_key:
			cell = TOKEN_CELLS["lich_king"]
		elif "wolf" in token_key:
			cell = TOKEN_CELLS["wolf"]
		elif is_player:
			cell = Vector2i(0, 0)
		else:
			cell = Vector2i(0, 2)
	
	var col := float(cell.x)
	var row := float(cell.y)
	
	var uv_center := Vector2((col + 0.5) / 4.0, (row + 0.5) / 4.0)
	var uv_radius := (1.0 / 4.0) * 0.44
	
	# 1. Drop shadow below token
	ci.draw_circle(center + Vector2(0, 2.5), radius + 1.0, Color(0.0, 0.0, 0.0, 0.45))
	
	# 2. 24-point circular polygon for clipped portrait
	var n_verts := 24
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in n_verts:
		var angle := (2.0 * PI / float(n_verts)) * float(i)
		var dir := Vector2(cos(angle), sin(angle))
		points.append(center + dir * (radius - 1.0))
		uvs.append(uv_center + dir * uv_radius)
	
	ci.draw_colored_polygon(points, Color.WHITE, uvs, _tokens_texture)
	
	# 3. Outer metallic bezel ring
	if is_player:
		# Gold / Brass bezel
		ci.draw_circle(center, radius, Color(0.85, 0.70, 0.28, 1.0), false, 2.2)
		ci.draw_circle(center, radius + 1.0, Color(0.25, 0.18, 0.08, 0.8), false, 1.0)
		ci.draw_circle(center, radius - 1.2, Color(0.35, 0.25, 0.12, 0.6), false, 1.0)
	else:
		# Dark Iron / Crimson bezel
		ci.draw_circle(center, radius, Color(0.80, 0.25, 0.22, 1.0), false, 2.2)
		ci.draw_circle(center, radius + 1.0, Color(0.20, 0.05, 0.05, 0.8), false, 1.0)
		ci.draw_circle(center, radius - 1.2, Color(0.30, 0.08, 0.08, 0.6), false, 1.0)
	
	return true


## Draw a glowing reach highlight with translucent fill and runic vertex markers.
static func draw_highlight(ci: CanvasItem, center: Vector2, size: float, color: Color, width: float, points: PackedVector2Array) -> void:
	# Translucent glowing fill
	var fill_color := Color(color.r, color.g, color.b, 0.22)
	ci.draw_colored_polygon(points, fill_color)
	
	# Crisp outline
	for i in 6:
		ci.draw_line(points[i], points[(i + 1) % 6], color, width)
	
	# Runic vertex points
	for i in 6:
		ci.draw_circle(points[i], 2.0, color)
