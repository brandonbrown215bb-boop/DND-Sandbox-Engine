## Fog of War System
## Manages visibility ranges and fog of war mapping based on player positions.
class_name FogOfWar
extends RefCounted

## Default vision radius (in hexes).
const DEFAULT_VISION_RADIUS := 2


## Recalculate visibility for the entire grid based on player positions.
## Updates `is_visible` and `is_revealed` properties on HexGrid tiles.
static func update_visibility(hex_grid: HexGrid) -> void:
	if hex_grid == null: return

	# Reset current visibility first
	hex_grid.reset_visibility()

	# Retrieve all player positions
	var player_count := PlayerManager.get_player_count()
	for i in player_count:
		var pos := PlayerManager.get_player_position(i)
		var player_data := PlayerManager.get_player(i)
		var char_data: Character = player_data.get("character")
		
		# Darkvision extends exploration sight to the spell's 150-foot range.
		var vision_radius := DEFAULT_VISION_RADIUS
		if char_data != null:
			if SpellEffects.has_spell(char_data, "darkvision"):
				vision_radius = 30
			if char_data.inventory != null:
				for light_record in char_data.inventory.owned_instances():
					vision_radius = maxi(vision_radius, LightSourceRules.dim_radius_hexes(light_record))
			if (char_data.darkvision or char_data.darkvision_feet > 0) and not SpellEffects.has_spell(char_data, "darkvision"):
				vision_radius += 1
			if char_data.has_condition("fairy_luck"):
				vision_radius += 1

		# Reveal all hexes in vision range
		var visible_hexes := HexUtils.get_hexes_in_range(pos, vision_radius)
		for coord in visible_hexes:
			if hex_grid.has_tile(coord):
				var tile := hex_grid.get_tile(coord)
				tile.is_revealed = true
				tile.is_visible = true

	# Force a redraw of the grid
	hex_grid.queue_redraw()
