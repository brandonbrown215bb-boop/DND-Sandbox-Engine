## Bounded production checks for Batch 030:
## S-032 (Physical size, mass, material, thickness, and equipment facts)
## S-033 (Plane, location, and available-space facts)
## S-179 (Speed/mode, terrain/surface costs, refusal spending no distance)
class_name Batch030Checks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_030/items/items.json", "item")
	DataLoader._load_json_file("res://data/fixtures/batch_030/spells/catapult_loose_object.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_030/spells/shatter_metal_crystal.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_030/spells/planar_space_step.json", "spell")


static func _make_character(name: String, race: String = "human", class_id: String = "fighter") -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 16, "DEX": 14, "CON": 14, "INT": 10, "WIS": 12, "CHA": 10})
	var ch := Character.new()
	ch.initialize(name, race, class_id, scores)
	ch.character_id = name.to_lower().replace(" ", "_")
	ch.max_hp = 30
	ch.current_hp = 30
	return ch


static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "030 fixtures load through ordinary validation without errors")

	# =========================================================================
	# S-032: Physical Facts (Size, Mass, Material, Thickness, Equipment Status)
	# =========================================================================
	var human_pc := _make_character("Human Fighter", "human", "fighter")
	var halfling_pc := _make_character("Halfling Rogue", "halfling", "rogue")

	# Size queries
	check.call(PhysicalFactsRules.get_size(human_pc) == "medium", "032 Character size queries race medium")
	check.call(PhysicalFactsRules.get_size(halfling_pc) == "small", "032 Character size queries race small")
	human_pc.add_condition("enlarge", 10)
	check.call(PhysicalFactsRules.get_size(human_pc) == "large", "032 Enlarge condition scales size to large")
	human_pc.remove_condition("enlarge")
	human_pc.add_condition("reduce", 10)
	check.call(PhysicalFactsRules.get_size(human_pc) == "small", "032 Reduce condition scales size to small")
	human_pc.remove_condition("reduce")

	var goblin_monster := {"id": "m1", "name": "Goblin", "size": "small", "creature_type": "humanoid", "is_alive": true}
	var ogre_monster := {"id": "m2", "name": "Ogre", "size": "large", "creature_type": "giant", "is_alive": true}
	check.call(PhysicalFactsRules.get_size(goblin_monster) == "small", "032 Monster size queries small")
	check.call(PhysicalFactsRules.get_size(ogre_monster) == "large", "032 Monster size queries large")

	var pebble_item := {"definition_id": "fixture:030_iron_pebble", "kind": "loose"}
	var anvil_item := {"definition_id": "fixture:030_iron_anvil", "kind": "loose"}
	var unknown_item := {"definition_id": "fixture:030_unknown_gadget"}
	check.call(PhysicalFactsRules.get_size(pebble_item) == "tiny", "032 Object size queries tiny definition")
	check.call(PhysicalFactsRules.get_size(anvil_item) == "medium", "032 Object size queries medium definition")
	check.call(PhysicalFactsRules.get_size(unknown_item) == "", "032 Unmodeled object size returns empty unknown")

	# Mass / weight queries
	check.call(PhysicalFactsRules.get_mass_lb(human_pc) == null, "032 Unmodeled human mass remains unknown")
	check.call(PhysicalFactsRules.get_mass_lb(halfling_pc) == null, "032 Unmodeled halfling mass remains unknown")
	check.call(is_equal_approx(float(PhysicalFactsRules.get_mass_lb(pebble_item)), 1.0), "032 Object mass queries pebble 1.0 lb")
	check.call(is_equal_approx(float(PhysicalFactsRules.get_mass_lb(anvil_item)), 200.0), "032 Object mass queries anvil 200.0 lbs")
	check.call(PhysicalFactsRules.get_mass_lb(unknown_item) == null, "032 Unmodeled object mass returns null unknown")

	# Material queries
	check.call(PhysicalFactsRules.get_material(human_pc) == "", "032 Unmodeled Character material remains unknown")
	var construct_monster := {"id": "m3", "name": "Iron Golem", "creature_type": "construct", "is_alive": true}
	var skeleton_monster := {"id": "m4", "name": "Skeleton", "creature_type": "undead", "is_alive": true}
	check.call(PhysicalFactsRules.get_material(construct_monster) == "", "032 Construct type does not invent metal composition")
	check.call(PhysicalFactsRules.get_material(skeleton_monster) == "", "032 Creature name does not supply a material rule")
	check.call(PhysicalFactsRules.get_material(pebble_item) == "iron", "032 Object material queries iron")
	var vial_item := {"definition_id": "fixture:030_glass_vial", "kind": "loose"}
	check.call(PhysicalFactsRules.get_material(vial_item) == "glass", "032 Object material queries glass")
	check.call(PhysicalFactsRules.get_material(unknown_item) == "", "032 Unmodeled object material returns empty unknown")

	# Thickness queries
	var thin_door := {"thickness_inches": 2.0}
	var thick_wall := {"thickness_inches": 12.0}
	check.call(is_equal_approx(float(PhysicalFactsRules.get_thickness_inches(thin_door)), 2.0), "032 Thickness queries door 2 inches")
	check.call(is_equal_approx(float(PhysicalFactsRules.get_thickness_inches(thick_wall)), 12.0), "032 Thickness queries wall 12 inches")
	check.call(PhysicalFactsRules.get_thickness_inches(unknown_item) == null, "032 Unmodeled object thickness returns null unknown")

	# Equipment status queries
	var loose_pebble := CombatObjectRules.make_dropped_item({"instance_id": "p1", "definition_id": "fixture:030_iron_pebble", "state": {}}, Vector2i(1, 0), "")
	var fixed_anvil := {"name": "Forge Anvil", "definition_id": "fixture:030_iron_anvil", "fixed": true, "hp": 50, "max_hp": 50}
	var worn_armor := {"name": "Plate Armor", "worn": true, "worn_by": human_pc.character_id}
	var carried_potion := {"name": "Healing Potion", "carried": true, "carried_by": human_pc.character_id}

	var status_loose := PhysicalFactsRules.get_equipment_status(loose_pebble)
	check.call(status_loose.loose and not status_loose.worn and not status_loose.carried and not status_loose.fixed, "032 Dropped pebble status is loose")

	var status_fixed := PhysicalFactsRules.get_equipment_status(fixed_anvil)
	check.call(status_fixed.fixed and not status_fixed.loose, "032 Fixed anvil status is fixed and not loose")

	var status_worn := PhysicalFactsRules.get_equipment_status(worn_armor)
	check.call(status_worn.worn and not status_worn.loose, "032 Worn armor status is worn and not loose")

	var status_carried := PhysicalFactsRules.get_equipment_status(carried_potion)
	check.call(status_carried.carried and not status_carried.loose, "032 Carried potion status is carried and not loose")

	var status_unknown := PhysicalFactsRules.get_equipment_status(unknown_item)
	check.call(status_unknown.unknown, "032 Unmodeled object status reports unknown")

	# Refusal of eligible-only actions on unknown facts
	var catapult_filter: Dictionary = DataLoader.get_spell("fixture:030_catapult_loose_object").get("physical_requirements", {})
	var shatter_filter: Dictionary = DataLoader.get_spell("fixture:030_shatter_metal_crystal").get("physical_requirements", {})

	# Unknown gadget has unknown mass, unknown material, unknown status
	var eval_catapult_unknown := PhysicalFactsRules.evaluate_physical_eligibility(unknown_item, catapult_filter)
	check.call(not eval_catapult_unknown.eligible, "032 Catapult refuses object with unknown mass/status")
	check.call("unknown" in eval_catapult_unknown.reason.to_lower(), "032 Ineligibility reason explicitly states unknown property")

	var eval_shatter_unknown := PhysicalFactsRules.evaluate_physical_eligibility(unknown_item, shatter_filter)
	check.call(not eval_shatter_unknown.eligible, "032 Shatter refuses object with unknown material")
	check.call("unknown" in eval_shatter_unknown.reason.to_lower(), "032 Shatter ineligibility reason explicitly states unknown material")

	# Catapult on known loose 1 lb pebble: ELIGIBLE
	var eval_pebble := PhysicalFactsRules.evaluate_physical_eligibility(loose_pebble, catapult_filter)
	check.call(eval_pebble.eligible, "032 Catapult accepts loose pebble under 5 lbs")

	# Catapult on 200 lb fixed anvil: INELIGIBLE (exceeds mass and is fixed)
	var eval_anvil := PhysicalFactsRules.evaluate_physical_eligibility(fixed_anvil, catapult_filter)
	check.call(not eval_anvil.eligible, "032 Catapult refuses fixed 200 lb anvil")

	# Shatter on metal/glass objects:
	check.call(PhysicalFactsRules.evaluate_physical_eligibility(loose_pebble, shatter_filter).eligible, "032 Shatter accepts iron pebble")
	check.call(PhysicalFactsRules.evaluate_physical_eligibility(vial_item, shatter_filter).eligible, "032 Shatter accepts glass vial")
	var wooden_object := {"material": "wood", "size": "small"}
	check.call(not PhysicalFactsRules.evaluate_physical_eligibility(wooden_object, shatter_filter).eligible, "032 Shatter refuses wooden object")

	# =========================================================================
	# S-033: Plane, Location, and Available-Space Facts
	# =========================================================================
	check.call(PhysicalFactsRules.get_plane(human_pc) == "material", "033 Character default plane is material")
	var ethereal_traveler := _make_character("Ethereal Monk", "human", "monk")
	ethereal_traveler.feature_uses["plane"] = "ethereal"
	check.call(PhysicalFactsRules.get_plane(ethereal_traveler) == "ethereal", "033 Represented ethereal plane queried accurately")

	var grid := HexGrid.new()
	for c in HexUtils.get_hexes_in_range(Vector2i.ZERO, 5):
		var t := HexTile.new()
		t.coord = c
		grid.add_tile(t)
	var initial_tile_count: int = grid.tiles.size()

	# Query available space on material plane
	var space_ctx := {
		"plane": "material",
		"players": [{"character": human_pc, "hex_position": Vector2i(0, 0)}],
		"monsters": [{"id": "m1", "name": "Goblin", "hex_position": Vector2i(1, 0), "is_alive": true, "size": "small"}]
	}

	# Empty hex (2, 0) is available for medium body
	var eval_open := PhysicalFactsRules.is_space_available(grid, Vector2i(2, 0), "medium", "material", space_ctx)
	check.call(eval_open.available, "033 Empty hex on material plane has available space")

	# Hex outside grid is unavailable
	var eval_outside := PhysicalFactsRules.is_space_available(grid, Vector2i(99, 99), "medium", "material", space_ctx)
	check.call(not eval_outside.available, "033 Space outside grid is refused")

	# Plane mismatch: query requesting ethereal space when combat is material plane
	var eval_plane_mismatch := PhysicalFactsRules.is_space_available(grid, Vector2i(2, 0), "medium", "ethereal", space_ctx)
	check.call(not eval_plane_mismatch.available, "033 Space on different plane is refused")

	# Occupied hex (1, 0) by Goblin: unavailable for Medium body
	var eval_occupied := PhysicalFactsRules.is_space_available(grid, Vector2i(1, 0), "medium", "material", space_ctx)
	check.call(not eval_occupied.available, "033 Occupied hex is refused for medium body")

	# Occupied hex (1, 0) by Goblin: AVAILABLE for Tiny body (Tiny can share space)
	var eval_tiny := PhysicalFactsRules.is_space_available(grid, Vector2i(1, 0), "tiny", "material", space_ctx)
	check.call(not eval_tiny.available, "033 Tiny body cannot end in another creature space")

	# Vertical clearance check
	var low_ceiling_room := {
		"ceiling_feet": 8,
		"cell_elevations": [{"position": [2, 1], "feet": 0}],
		"cell_ceilings": [{"position": [2, 1], "feet": 8}]
	}
	var clearance_ctx := space_ctx.duplicate()
	clearance_ctx["room"] = low_ceiling_room
	# Large body needs at least 10 ft clearance
	var eval_large_clearance := PhysicalFactsRules.is_space_available(grid, Vector2i(2, 1), "large", "material", clearance_ctx)
	check.call(not eval_large_clearance.available, "033 Large body refused in 8 ft low-ceiling room")
	check.call("clearance" in eval_large_clearance.reason.to_lower(), "033 Reason mentions insufficient clearance")

	# Medium body needs 6 ft clearance -> fits in 8 ft room
	var eval_medium_clearance := PhysicalFactsRules.is_space_available(grid, Vector2i(2, 1), "medium", "material", clearance_ctx)
	check.call(eval_medium_clearance.available, "033 Medium body fits in 8 ft ceiling room")

	# Fixed object blocking hex
	var blocked_ctx := space_ctx.duplicate()
	blocked_ctx["objects"] = [{"name": "Stone Column", "position": [3, 0], "fixed": true, "hp": 100}]
	var eval_blocked := PhysicalFactsRules.is_space_available(grid, Vector2i(3, 0), "medium", "material", blocked_ctx)
	check.call(not eval_blocked.available, "033 Fixed object blocks space availability")

	# Verify side-effect-free: querying space does not modify grid or entities
	check.call(grid.tiles.size() == initial_tile_count, "033 Querying space did not create or remove tiles")
	check.call(space_ctx.players.size() == 1, "033 Querying space did not alter player list")

	# =========================================================================
	# S-179: Speed/mode and Terrain/Surface Costs
	# =========================================================================
	# Speeds and modes
	check.call(PhysicalFactsRules.get_speed_for_mode(human_pc, "walk") == 30, "179 Character walking speed is 30 ft (6 hexes)")
	check.call(PhysicalFactsRules.get_speed_for_mode(human_pc, "fly") == 0, "179 Character has 0 default fly speed")
	human_pc.set_movement_speed_feet("climb", 20)
	check.call(PhysicalFactsRules.get_speed_for_mode(human_pc, "climb") == 20, "179 Character declared climbing speed is 20 ft")

	var aerial_beast := {"id": "m5", "name": "Giant Eagle", "speed": 2, "fly_speed_feet": 80, "hover": false}
	check.call(PhysicalFactsRules.get_speed_for_mode(aerial_beast, "fly") == 80, "179 Aerial beast fly speed is 80 ft")
	check.call(not PhysicalFactsRules.has_hover(aerial_beast), "179 Giant eagle does not have hover")

	var floating_specter := {"id": "m6", "name": "Specter", "speed": 6, "fly_speed_feet": 30, "hover": true}
	check.call(PhysicalFactsRules.has_hover(floating_specter), "179 Specter has declared hover")

	# Free hands queries on Character
	human_pc.inventory.equipped.clear()
	check.call(PhysicalFactsRules.get_free_hands(human_pc) == 2, "179 Unarmed character has 2 free hands")

	human_pc.inventory.equipped[Inventory.Slot.WEAPON] = "greatsword" # two_handed
	check.call(PhysicalFactsRules.get_free_hands(human_pc) == 0, "179 Character with greatsword has 0 free hands")

	human_pc.inventory.equipped[Inventory.Slot.WEAPON] = "longsword" # one-handed
	check.call(PhysicalFactsRules.get_free_hands(human_pc) == 1, "179 Character with 1H longsword has 1 free hand")

	human_pc.inventory.equipped[Inventory.Slot.SHIELD] = "shield"
	check.call(PhysicalFactsRules.get_free_hands(human_pc) == 0, "179 Character with sword and shield has 0 free hands")

	# Surface and hand requirements
	# Climbing with 0 free hands without Spider Climb -> REFUSED
	var climb_req_busy := PhysicalFactsRules.check_surface_and_hand_requirements(human_pc, "climb", "ground")
	check.call(not climb_req_busy.allowed, "179 Climbing refused when holding sword and shield (0 free hands)")
	check.call("hand" in climb_req_busy.reason.to_lower(), "179 Refusal reason mentions free hands")

	# Climbing unarmed (2 free hands) -> ALLOWED
	human_pc.inventory.equipped.clear()
	var climb_req_free := PhysicalFactsRules.check_surface_and_hand_requirements(human_pc, "climb", "ground")
	check.call(climb_req_free.allowed, "179 Climbing allowed with 2 free hands")

	# Climbing with greatsword (0 hands) BUT Spider Climb active -> ALLOWED
	human_pc.inventory.equipped[Inventory.Slot.WEAPON] = "greatsword"
	human_pc.add_condition("spider_climb", 60)
	var climb_req_spider := PhysicalFactsRules.check_surface_and_hand_requirements(human_pc, "climb", "ground")
	check.call(climb_req_spider.allowed, "179 Spider Climb allows climbing with 0 free hands")

	# Inverted ceiling climbing requires Spider Climb
	var ceiling_spider := PhysicalFactsRules.check_surface_and_hand_requirements(human_pc, "climb", "ceiling")
	check.call(ceiling_spider.allowed, "179 Spider Climb allows inverted ceiling climbing")
	human_pc.remove_condition("spider_climb")
	var ceiling_no_spider := PhysicalFactsRules.check_surface_and_hand_requirements(human_pc, "climb", "ceiling")
	check.call(not ceiling_no_spider.allowed, "179 Inverted ceiling climbing refused without Spider Climb")

	# Sheer / slippery wall
	human_pc.set_movement_speed_feet("climb", 0)
	var sheer_no_speed := PhysicalFactsRules.check_surface_and_hand_requirements(human_pc, "climb", "sheer")
	check.call(not sheer_no_speed.allowed, "179 Sheer surface refused without climb speed or spider climb")
	human_pc.inventory.equipped.clear()
	human_pc.set_movement_speed_feet("climb", 20)
	var sheer_with_speed := PhysicalFactsRules.check_surface_and_hand_requirements(human_pc, "climb", "sheer")
	check.call(sheer_with_speed.allowed, "179 Sheer surface permitted with climb speed")

	# Walking on liquid (water)
	var walk_water_no_spell := PhysicalFactsRules.check_surface_and_hand_requirements(human_pc, "walk", "water")
	check.call(not walk_water_no_spell.allowed, "179 Walking on liquid refused without Water Walk")
	human_pc.add_condition("water_walk", 60)
	var walk_water_spell := PhysicalFactsRules.check_surface_and_hand_requirements(human_pc, "walk", "water")
	check.call(walk_water_spell.allowed, "179 Walking on liquid permitted with Water Walk")
	human_pc.remove_condition("water_walk")

	# Flying requirements
	var fly_no_speed := PhysicalFactsRules.check_surface_and_hand_requirements(human_pc, "fly", "ground")
	check.call(not fly_no_speed.allowed, "179 Flying refused when creature has 0 flying speed")
	human_pc.add_condition("fly", 60)
	var fly_with_spell := PhysicalFactsRules.check_surface_and_hand_requirements(human_pc, "fly", "ground")
	check.call(fly_with_spell.allowed, "179 Flying allowed with Fly speed")
	human_pc.add_condition("prone", 1)
	var fly_prone := PhysicalFactsRules.check_surface_and_hand_requirements(human_pc, "fly", "ground")
	check.call(not fly_prone.allowed, "179 Prone creature without hover cannot fly")
	human_pc.remove_condition("prone")
	human_pc.remove_condition("fly")

	# Terrain & mode cost calculations
	# Walking normal: 5 ft
	var cost_walk_normal := PhysicalFactsRules.calculate_movement_step_cost(human_pc, "walk", "normal")
	check.call(cost_walk_normal.cost_feet == 5, "179 Walking in normal terrain costs 5 ft (1 hex)")

	# Walking difficult terrain: 10 ft (+5 ft extra)
	var cost_walk_diff := PhysicalFactsRules.calculate_movement_step_cost(human_pc, "walk", "difficult")
	check.call(cost_walk_diff.cost_feet == 10, "179 Walking in difficult terrain costs 10 ft (2 hexes)")

	# Climbing without climb speed: 10 ft (2x cost)
	human_pc.set_movement_speed_feet("climb", 0)
	var cost_climb_no_speed := PhysicalFactsRules.calculate_movement_step_cost(human_pc, "climb", "normal")
	check.call(cost_climb_no_speed.cost_feet == 10, "179 Climbing without climb speed costs 10 ft (2x)")

	# Climbing with climb speed: 5 ft (1x cost)
	human_pc.set_movement_speed_feet("climb", 20)
	var cost_climb_speed := PhysicalFactsRules.calculate_movement_step_cost(human_pc, "climb", "normal")
	check.call(cost_climb_speed.cost_feet == 5, "179 Climbing with declared climb speed costs 5 ft (1x)")

	# Climbing without climb speed in difficult terrain: 15 ft (3x cost = 10 ft mode + 5 ft terrain)
	human_pc.set_movement_speed_feet("climb", 0)
	var cost_climb_diff := PhysicalFactsRules.calculate_movement_step_cost(human_pc, "climb", "difficult")
	check.call(cost_climb_diff.cost_feet == 15, "179 Climbing without speed in difficult terrain costs 15 ft (3x)")

	# Swimming without swim speed: 10 ft (2x)
	var cost_swim_no_speed := PhysicalFactsRules.calculate_movement_step_cost(human_pc, "swim", "normal")
	check.call(cost_swim_no_speed.cost_feet == 10, "179 Swimming without swim speed costs 10 ft (2x)")

	# Swimming with swim speed: 5 ft (1x)
	human_pc.set_movement_speed_feet("swim", 30)
	var cost_swim_speed := PhysicalFactsRules.calculate_movement_step_cost(human_pc, "swim", "normal")
	check.call(cost_swim_speed.cost_feet == 5, "179 Swimming with declared swim speed costs 5 ft (1x)")

	# Flying in normal terrain: 5 ft (1x)
	human_pc.add_condition("fly", 60)
	var cost_fly_normal := PhysicalFactsRules.calculate_movement_step_cost(human_pc, "fly", "normal")
	check.call(cost_fly_normal.cost_feet == 5, "179 Flying in normal terrain costs 5 ft (1x)")

	# Flying over ground difficult terrain: flyer ignores ground terrain -> still 5 ft!
	var cost_fly_diff := PhysicalFactsRules.calculate_movement_step_cost(human_pc, "fly", "difficult")
	check.call(cost_fly_diff.cost_feet == 5, "179 Flying over ground difficult terrain ignores ground cost (5 ft)")
	human_pc.remove_condition("fly")

	# Movement attempt and refusal spending 0 distance
	var initial_budget := 30
	# 1. Refusal for illegal surface (climbing sheer without climb speed)
	human_pc.set_movement_speed_feet("climb", 0)
	var attempt_sheer := PhysicalFactsRules.attempt_movement_step(human_pc, "climb", Vector2i(0, 0), Vector2i(1, 0), initial_budget, grid, "sheer", "normal", space_ctx)
	check.call(not attempt_sheer.success and attempt_sheer.refused, "179 Attempting to climb sheer surface without climb speed is refused")
	check.call(attempt_sheer.spent_distance_feet == 0, "179 Movement refusal spends exactly 0 feet of distance")
	check.call(attempt_sheer.remaining_budget_feet == initial_budget, "179 Movement refusal leaves remaining budget completely untouched")
	check.call(attempt_sheer.unrelated_modes_spent == 0, "179 Movement refusal spends 0 in unrelated modes")
	check.call(attempt_sheer.destination == Vector2i(0, 0), "179 Movement refusal leaves mover at origin")

	# 2. Refusal for insufficient remaining budget (needs 15 ft, has only 10 ft)
	var low_budget := 10
	var attempt_budget := PhysicalFactsRules.attempt_movement_step(human_pc, "climb", Vector2i(0, 0), Vector2i(0, 1), low_budget, grid, "ground", "difficult", space_ctx)
	check.call(not attempt_budget.success and attempt_budget.refused, "179 Move refused when remaining budget is insufficient")
	check.call(attempt_budget.spent_distance_feet == 0, "179 Insufficient budget refusal spends 0 distance")
	check.call(attempt_budget.remaining_budget_feet == low_budget, "179 Insufficient budget refusal retains full existing budget")

	# 3. Refusal for occupied destination
	var attempt_occupied := PhysicalFactsRules.attempt_movement_step(human_pc, "walk", Vector2i(0, 0), Vector2i(1, 0), initial_budget, grid, "ground", "normal", space_ctx)
	check.call(not attempt_occupied.success and attempt_occupied.refused, "179 Move into occupied space is refused")
	check.call(attempt_occupied.spent_distance_feet == 0, "179 Occupied space refusal spends 0 distance")
	check.call(attempt_occupied.remaining_budget_feet == initial_budget, "179 Occupied space refusal retains full budget")

	# 4. Successful move
	var attempt_success := PhysicalFactsRules.attempt_movement_step(human_pc, "walk", Vector2i(0, 0), Vector2i(0, 1), initial_budget, grid, "ground", "normal", space_ctx)
	check.call(attempt_success.success and not attempt_success.refused, "179 Valid move is accepted")
	check.call(attempt_success.spent_distance_feet == 5, "179 Successful normal walk spends 5 ft")
	check.call(attempt_success.remaining_budget_feet == 25, "179 Remaining budget reduced from 30 to 25 ft")
	check.call(attempt_success.destination == Vector2i(0, 1), "179 Destination updated to target hex")

	_review_regressions(check, grid, human_pc)
	grid.free()


static func _review_regressions(check: Callable, grid: HexGrid, actor: Character) -> void:
	var unknown := CombatObjectRules.make_dropped_item({"instance_id":"unknown-030","definition_id":"fixture:030_unknown_gadget","state":{}}, Vector2i(0, 1), "")
	check.call(PhysicalFactsRules.get_mass_lb(unknown) == null and PhysicalFactsRules.get_size(unknown).is_empty() and PhysicalFactsRules.get_material(unknown).is_empty(), "030 review: actual dropped-copy projection preserves unknown physical facts")
	check.call(not PhysicalFactsRules.evaluate_physical_eligibility(unknown, {"max_mass_lb":5,"reject_unknown":false}).eligible, "030 review: unknown facts cannot opt into eligibility")
	check.call(not PhysicalFactsRules.physical_requirements_error({"reject_unknown":false}).is_empty(), "030 review: unknown-fact bypass rejected at loading")
	check.call(not PhysicalFactsRules.evaluate_physical_eligibility({"weight_lb":"light"}, {"max_mass_lb":5}).eligible, "030 review: malformed mass cannot coerce into a zero-pound target")
	check.call(not PhysicalFactsRules.evaluate_physical_eligibility({"weight_lb":-1}, {"max_mass_lb":5}).eligible, "030 review: negative mass is unknown")
	check.call(not PhysicalFactsRules.evaluate_physical_eligibility({"fixed":false}, {"required_status":"loose"}).eligible, "030 review: fixed false does not invent unworn and uncarried facts")
	check.call(PhysicalFactsRules.evaluate_physical_eligibility({"fixed":false}, {"required_status":"not_fixed"}).eligible, "030 review: a requirement reads only its declared known status")
	check.call(not PhysicalFactsRules.evaluate_physical_eligibility({"material":null}, {"forbidden_materials":["metal"]}).eligible, "030 review: null material cannot pass a forbidden-material filter")
	check.call(PhysicalFactsRules.spatial_requirements_error(JSON.parse_string('{"requires_available_space":true,"clearance_feet":10}')).is_empty(), "030 review: integral JSON clearance loads")
	check.call(not PhysicalFactsRules.physical_requirements_error({"max_mass_lb":NAN}).is_empty(), "030 review: nonfinite requirements refuse")
	check.call(not PhysicalFactsRules.get_location(actor).location_known, "030 review: actor without a represented position has unknown location")
	check.call(PhysicalFactsRules.get_plane(actor, {"plane":"ethereal"}) == "ethereal", "030 review: actor inherits actual host plane")
	check.call(not PhysicalFactsRules.spatial_requirements_error({"same_plane_as_caster":"yes"}).is_empty(), "030 review: malformed spatial flag refuses")
	check.call(not PhysicalFactsRules.spatial_requirements_error({"clearance_feet":15}).is_empty(), "030 review: ignored clearance without a space query refuses loading")
	check.call(not PhysicalFactsRules.evaluate_spatial_eligibility(grid, Vector2i(0, 1), {"plane":"ethereal"}, {"plane":"material"}).eligible, "030 review: plane-only restriction executes")
	actor.feature_uses["plane"] = "ethereal"
	check.call(not PhysicalFactsRules.evaluate_spatial_eligibility(grid, Vector2i(0, 1), {"same_plane_as_caster":true}, {"caster":actor,"plane":"material"}).eligible, "030 review: same-plane restriction executes")
	actor.feature_uses.erase("plane")
	check.call(not PhysicalFactsRules.evaluate_spatial_eligibility(grid, Vector2i(0, 1), {"requires_available_space":true,"clearance_feet":15}, {"room":{"ceiling_feet":10}}).eligible, "030 review: authored clearance overrides default body minimum")
	check.call(not PhysicalFactsRules.is_space_available(null, Vector2i.ZERO).available, "030 review: missing grid cannot claim available space")
	grid.add_entity({"hex_position":Vector2i(0, 1),"character":actor})
	check.call(not PhysicalFactsRules.is_space_available(grid, Vector2i(0, 1)).available, "030 review: grid occupants block placement without optional participant arrays")
	grid.clear_entities()
	var distant := PhysicalFactsRules.attempt_movement_step(actor,"walk",Vector2i.ZERO,Vector2i(3, 0),30,grid)
	check.call(distant.refused and distant.spent_distance_feet == 0, "030 review: a single movement step cannot teleport three hexes for five feet")
