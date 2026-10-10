## Combat Targeting Utility
## Calculates ranges, line-of-sight, and AoE boundaries (cones, lines, spheres) on a hex grid.
class_name Targeting
extends RefCounted


## Check if a target coordinate is within range of the attacker.
static func is_in_range(attacker_coord: Vector2i, target_coord: Vector2i, max_range: int) -> bool:
	var dist := HexUtils.get_distance(attacker_coord, target_coord)
	return dist <= max_range


## True when no intermediate grid tile blocks sight between two axial hexes.
static func has_line_of_sight(origin: Vector2i, target: Vector2i, hex_grid: HexGrid) -> bool:
	if origin == target or hex_grid == null:
		return true
	var distance := HexUtils.get_distance(origin, target)
	for step in range(1, distance):
		var fraction := float(step) / float(distance)
		var x := lerpf(float(origin.x), float(target.x), fraction)
		var y := lerpf(float(origin.y), float(target.y), fraction)
		var z := lerpf(float(-origin.x - origin.y), float(-target.x - target.y), fraction)
		var rounded_x := roundi(x)
		var rounded_y := roundi(y)
		var rounded_z := roundi(z)
		var x_error := absf(float(rounded_x) - x)
		var y_error := absf(float(rounded_y) - y)
		var z_error := absf(float(rounded_z) - z)
		if x_error > y_error and x_error > z_error:
			rounded_x = -rounded_y - rounded_z
		elif y_error > z_error:
			rounded_y = -rounded_x - rounded_z
		var tile_coord := Vector2i(rounded_x, rounded_y)
		if hex_grid.has_tile(tile_coord) and bool(hex_grid.get_tile(tile_coord).custom_properties.get("blocks_sight", false)):
			return false
	return true


## Retrieve all targets in a sphere AoE around a center hex.
static func get_sphere_targets(center: Vector2i, radius: int, hex_grid: HexGrid) -> Array[Vector2i]:
	var affected_hexes := HexUtils.get_hexes_in_range(center, radius)
	var targets: Array[Vector2i] = []
	for hex in affected_hexes:
		if hex_grid.has_tile(hex):
			targets.append(hex)
	return targets


## Approximate the SRD 10-foot square on the 5-foot hex grid with the center
## hex and its six neighbors. The grid cannot represent a true square boundary.
static func get_square_targets(center: Vector2i, size_feet: int, hex_grid: HexGrid) -> Array[Vector2i]:
	var radius := 1 if size_feet <= 10 else maxi(1, int(ceil(float(size_feet) / 10.0)))
	return get_sphere_targets(center, radius, hex_grid)


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


## Approximate a directional cube on the pointy-top hex grid. Each of `size`
## forward layers spans three adjacent hexes; the caster stays outside the area.
static func get_cube_targets(origin: Vector2i, target_hex: Vector2i, size: int, hex_grid: HexGrid) -> Array[Vector2i]:
	if origin == target_hex or size < 1:
		return []
	var target_dir := -1
	var min_dist := 999
	for i in 6:
		var dir_vector: Vector2i = HexUtils.DIRECTIONS[i]
		var dist := HexUtils.get_distance(origin + dir_vector, target_hex)
		if dist < min_dist:
			min_dist = dist
			target_dir = i
	if target_dir == -1:
		return []
	var forward: Vector2i = HexUtils.DIRECTIONS[target_dir]
	var left_flank: Vector2i = HexUtils.DIRECTIONS[(target_dir + 2) % 6]
	var right_flank: Vector2i = HexUtils.DIRECTIONS[(target_dir + 4) % 6]
	var targets: Array[Vector2i] = []
	for step in range(1, size + 1):
		var center := origin + forward * step
		for coord in [center, center + left_flank, center + right_flank]:
			if hex_grid.has_tile(coord) and coord not in targets:
				targets.append(coord)
	return targets


## Move a creature in a straight hex direction away from an origin, stopping
## before terrain or occupied spaces block its forced movement.
static func get_pushed_position(start: Vector2i, origin: Vector2i, distance: int, hex_grid: HexGrid, occupied_hexes: Array[Vector2i] = []) -> Vector2i:
	if distance <= 0 or start == origin:
		return start
	var away := HexUtils.hex_to_pixel(start) - HexUtils.hex_to_pixel(origin)
	var direction := Vector2i.ZERO
	var best_dot := -INF
	for neighbor in HexUtils.get_neighbors(start):
		var vector := HexUtils.hex_to_pixel(neighbor) - HexUtils.hex_to_pixel(start)
		var dot := away.normalized().dot(vector.normalized())
		if dot > best_dot:
			best_dot = dot
			direction = neighbor - start
	var pushed_to := start
	for _step in distance:
		var destination := pushed_to + direction
		if not hex_grid.is_hex_passable(destination) or destination in occupied_hexes:
			break
		pushed_to = destination
	return pushed_to
