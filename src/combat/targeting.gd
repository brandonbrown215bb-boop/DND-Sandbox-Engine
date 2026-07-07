## Combat Targeting Utility
## Calculates ranges, line-of-sight, and AoE boundaries (cones, lines, spheres) on a hex grid.
class_name Targeting
extends RefCounted


## Check if a target coordinate is within range of the attacker.
static func is_in_range(attacker_coord: Vector2i, target_coord: Vector2i, max_range: int) -> bool:
	var dist := HexUtils.get_distance(attacker_coord, target_coord)
	return dist <= max_range


## Retrieve all targets in a sphere AoE around a center hex.
static func get_sphere_targets(center: Vector2i, radius: int, hex_grid: HexGrid) -> Array[Vector2i]:
	var affected_hexes := HexUtils.get_hexes_in_range(center, radius)
	var targets: Array[Vector2i] = []
	for hex in affected_hexes:
		if hex_grid.has_tile(hex):
			targets.append(hex)
	return targets


## Retrieve all targets in a cone projecting from origin toward direction.
## We approximate a pointy-top cone on hexes.
static func get_cone_targets(origin: Vector2i, target_hex: Vector2i, cone_size: int, hex_grid: HexGrid) -> Array[Vector2i]:
	if origin == target_hex:
		return [origin]

	# Find closest directional vector
	var diff := target_hex - origin
	var target_dir := -1
	var min_dist := 999
	
	for i in 6:
		var dir_vector: Vector2i = HexUtils.DIRECTIONS[i]
		var dist := HexUtils.get_distance(origin + dir_vector, target_hex)
		if dist < min_dist:
			min_dist = dist
			target_dir = i

	var targets: Array[Vector2i] = []
	if target_dir == -1: return targets

	# Generate cone hexes in that direction
	# Direction left and direction right of our target direction
	var dir_left := (target_dir + 5) % 6
	var dir_right := (target_dir + 1) % 6
	
	# Sweep cone size range steps
	for step in range(1, cone_size + 1):
		# Start at the central ray step
		var center_ray = origin + HexUtils.DIRECTIONS[target_dir] * step
		if hex_grid.has_tile(center_ray):
			targets.append(center_ray)
		
		# Sweep out side width
		for side in range(1, step):
			var left_branch = center_ray + HexUtils.DIRECTIONS[dir_left] * side
			var right_branch = center_ray + HexUtils.DIRECTIONS[dir_right] * side
			if hex_grid.has_tile(left_branch):
				targets.append(left_branch)
			if hex_grid.has_tile(right_branch):
				targets.append(right_branch)

	return targets
