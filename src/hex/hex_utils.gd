## Hex Grid Utility Functions
## Static helper class for axial hex coordinate math.
## Uses axial coordinates (q, r) with cube coordinate (q, r, s where s = -q - r) for algorithms.
## Assumes pointy-top hex orientation.
class_name HexUtils
extends RefCounted

## The six axial direction vectors for pointy-top hexagons.
const DIRECTIONS := [
	Vector2i(1, 0),   # East
	Vector2i(1, -1),  # Northeast
	Vector2i(0, -1),  # Northwest
	Vector2i(-1, 0),  # West
	Vector2i(-1, 1),  # Southwest
	Vector2i(0, 1),   # Southeast
]

## Direction names matching the DIRECTIONS array indices.
enum Direction { EAST = 0, NORTHEAST = 1, NORTHWEST = 2, WEST = 3, SOUTHWEST = 4, SOUTHEAST = 5 }

## Size of a hex in pixels (outer radius — center to vertex).
const HEX_SIZE := 32.0


## Get the cube coordinate s from axial (q, r). s = -q - r.
static func axial_to_cube_s(hex: Vector2i) -> int:
	return -hex.x - hex.y


## Get all 6 neighbor coordinates of a hex.
static func get_neighbors(hex: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir in DIRECTIONS:
		neighbors.append(hex + dir)
	return neighbors


## Get the neighbor in a specific direction.
static func get_neighbor(hex: Vector2i, direction: int) -> Vector2i:
	return hex + DIRECTIONS[direction]


## Calculate the distance between two hexes (in hex steps).
static func get_distance(a: Vector2i, b: Vector2i) -> int:
	var diff := a - b
	# In cube coordinates: max(|dq|, |dr|, |ds|)
	var dq := absi(diff.x)
	var dr := absi(diff.y)
	var ds := absi(axial_to_cube_s(a) - axial_to_cube_s(b))
	return maxi(dq, maxi(dr, ds))


## Get all hexes within a given radius of center (inclusive).
static func get_hexes_in_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			results.append(center + Vector2i(q, r))
	return results


## Get all hexes forming a ring at exactly the given radius from center.
static func get_hex_ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius == 0:
		return [center]

	var results: Array[Vector2i] = []
	var current := center + DIRECTIONS[Direction.SOUTHWEST] * radius  # Start at SW corner

	for i in 6:
		for _j in radius:
			results.append(current)
			current = current + DIRECTIONS[i]

	return results


## Convert axial hex coordinates to pixel position (pointy-top).
static func hex_to_pixel(hex: Vector2i) -> Vector2:
	var x := HEX_SIZE * (sqrt(3.0) * hex.x + sqrt(3.0) / 2.0 * hex.y)
	var y := HEX_SIZE * (3.0 / 2.0 * hex.y)
	return Vector2(x, y)


## Convert pixel position to the nearest axial hex coordinate (pointy-top).
static func pixel_to_hex(pixel: Vector2) -> Vector2i:
	var q := (sqrt(3.0) / 3.0 * pixel.x - 1.0 / 3.0 * pixel.y) / HEX_SIZE
	var r := (2.0 / 3.0 * pixel.y) / HEX_SIZE
	return axial_round(Vector2(q, r))


## Round fractional axial coordinates to the nearest hex.
static func axial_round(frac: Vector2) -> Vector2i:
	var s := -frac.x - frac.y
	var rq := roundf(frac.x)
	var rr := roundf(frac.y)
	var rs := roundf(s)

	var q_diff := absf(rq - frac.x)
	var r_diff := absf(rr - frac.y)
	var s_diff := absf(rs - s)

	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	# else: rs = -rq - rr (but we don't need s for axial)

	return Vector2i(int(rq), int(rr))


## Draw a line between two hexes (returns all hexes along the line).
static func hex_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var dist := get_distance(a, b)
	if dist == 0:
		return [a]

	var results: Array[Vector2i] = []
	var a_pixel := hex_to_pixel(a)
	var b_pixel := hex_to_pixel(b)

	for i in range(dist + 1):
		var t := float(i) / float(dist)
		var lerped := a_pixel.lerp(b_pixel, t)
		# Nudge slightly to avoid landing exactly on edges
		lerped += Vector2(1e-6, 1e-6)
		results.append(pixel_to_hex(lerped))

	return results


## Check line-of-sight between two hexes using a provided blocking function.
## `is_blocked` should be a Callable that takes Vector2i and returns bool.
static func has_line_of_sight(a: Vector2i, b: Vector2i, is_blocked: Callable) -> bool:
	var line := hex_line(a, b)
	# Skip start and end, check intermediate hexes
	for i in range(1, line.size() - 1):
		if is_blocked.call(line[i]):
			return false
	return true


## A* pathfinding on a hex grid.
## `is_passable` should be a Callable: Vector2i -> bool (can we enter this hex?)
## `get_cost` should be a Callable: Vector2i -> float (movement cost to enter)
## Returns an array of hex coordinates forming the path (including start and end),
## or an empty array if no path exists.
static func find_path(start: Vector2i, goal: Vector2i, is_passable: Callable, get_cost: Callable, max_range: int = 100) -> Array[Vector2i]:
	if start == goal:
		return [start]

	# Priority queue: [priority, hex]
	var open_set: Array = [[0.0, start]]
	var came_from: Dictionary = {}  # Vector2i -> Vector2i
	var cost_so_far: Dictionary = {start: 0.0}  # Vector2i -> float

	while not open_set.is_empty():
		# Find lowest priority (simple linear scan — fine for game-sized grids)
		var best_idx := 0
		for i in range(1, open_set.size()):
			if open_set[i][0] < open_set[best_idx][0]:
				best_idx = i
		var current: Vector2i = open_set[best_idx][1]
		open_set.remove_at(best_idx)

		if current == goal:
			# Reconstruct path
			var path: Array[Vector2i] = [current]
			while current in came_from:
				current = came_from[current]
				path.push_front(current)
			return path

		for neighbor in get_neighbors(current):
			if not is_passable.call(neighbor):
				continue

			var new_cost: float = cost_so_far[current] + get_cost.call(neighbor)
			if new_cost > max_range:
				continue

			if neighbor not in cost_so_far or new_cost < cost_so_far[neighbor]:
				cost_so_far[neighbor] = new_cost
				var priority := new_cost + float(get_distance(neighbor, goal))
				open_set.append([priority, neighbor])
				came_from[neighbor] = current

	return []  # No path found


## Get all reachable hexes within a movement budget.
## Returns Dictionary[Vector2i, float] mapping hex -> cost to reach it.
static func get_reachable(start: Vector2i, budget: float, is_passable: Callable, get_cost: Callable) -> Dictionary:
	var reachable: Dictionary = {start: 0.0}
	var frontier: Array = [start]

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()

		for neighbor in get_neighbors(current):
			if not is_passable.call(neighbor):
				continue

			var new_cost: float = reachable[current] + get_cost.call(neighbor)
			if new_cost > budget:
				continue

			if neighbor not in reachable or new_cost < reachable[neighbor]:
				reachable[neighbor] = new_cost
				frontier.append(neighbor)

	return reachable
