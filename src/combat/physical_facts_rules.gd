## Bounded production rules for Batch 030:
## S-032 (Physical size, mass, material, thickness, and equipment/worn/carried/fixed facts)
## S-033 (Plane, location, and available-space facts without entity creation/movement side effects)
## S-179 (Walking/climbing/swimming/flying/hover speeds, surface/hand requirements, terrain costs, refusal spending 0 distance)
class_name PhysicalFactsRules
extends RefCounted

const VALID_SIZES := ["tiny", "small", "medium", "large", "huge", "gargantuan"]
const SIZE_RANKS := {
	"tiny": 1,
	"small": 2,
	"medium": 3,
	"large": 4,
	"huge": 5,
	"gargantuan": 6
}
const SIZE_MIN_CLEARANCE_FEET := {
	"tiny": 2,
	"small": 4,
	"medium": 6,
	"large": 10,
	"huge": 15,
	"gargantuan": 20
}

const VALID_MODES := ["walk", "climb", "swim", "fly"]
const VALID_EQUIPMENT_STATUSES := ["loose", "worn", "carried", "fixed", "not_fixed", "not_worn_or_carried", "unattended"]
const DEFAULT_PLANE := "material"

# =========================================================================
# S-032: Physical Facts Representation and Queries
# =========================================================================

static func get_size(target) -> String:
	if target == null:
		return ""
	if target is Character:
		var base_sz: String = str(target.get_creature_size()).to_lower().strip_edges()
		if target.has_condition("enlarge"):
			var rank := int(SIZE_RANKS.get(base_sz, 3))
			for sz in SIZE_RANKS:
				if SIZE_RANKS[sz] == mini(6, rank + 1):
					return sz
		elif target.has_condition("reduce"):
			var rank := int(SIZE_RANKS.get(base_sz, 3))
			for sz in SIZE_RANKS:
				if SIZE_RANKS[sz] == maxi(1, rank - 1):
					return sz
		return base_sz if base_sz in VALID_SIZES else ""
	if target is Dictionary:
		var obj: Dictionary = target.get("world_object", target) if target.get("world_object") is Dictionary else target
		if obj.has("size") and not str(obj["size"]).is_empty():
			var s := str(obj["size"]).to_lower().strip_edges()
			if s in VALID_SIZES:
				return s
		if obj.has("definition_id"):
			var item := DataLoader.get_item(str(obj["definition_id"]))
			if item.has("size") and not str(item["size"]).is_empty():
				var s := str(item["size"]).to_lower().strip_edges()
				if s in VALID_SIZES:
					return s
		if obj.has("item_id"):
			var item2 := DataLoader.get_item(str(obj["item_id"]))
			if item2.has("size") and not str(item2["size"]).is_empty():
				var s := str(item2["size"]).to_lower().strip_edges()
				if s in VALID_SIZES:
					return s
	return ""


static func get_mass_lb(target) -> Variant:
	if target == null:
		return null
	if target is Character:
		if target.has_meta("mass_lb"):
			return _known_measure(target.get_meta("mass_lb"))
		if target.feature_uses.has("mass_lb"):
			return _known_measure(target.feature_uses["mass_lb"])
		var race_data := DataLoader.get_race(target.race_id)
		return _known_measure(race_data.get("mass_lb", null))
	if target is Dictionary:
		var obj: Dictionary = target.get("world_object", target) if target.get("world_object") is Dictionary else target
		if obj.has("weight_lb") and obj["weight_lb"] != null:
			return _known_measure(obj["weight_lb"])
		if obj.has("weight") and obj["weight"] != null:
			return _known_measure(obj["weight"])
		if obj.has("mass_lb") and obj["mass_lb"] != null:
			return _known_measure(obj["mass_lb"])
		if obj.has("definition_id"):
			var item := DataLoader.get_item(str(obj["definition_id"]))
			if item.has("weight") and item["weight"] != null:
				return _known_measure(item["weight"])
		if obj.has("item_id"):
			var item2 := DataLoader.get_item(str(obj["item_id"]))
			if item2.has("weight") and item2["weight"] != null:
				return _known_measure(item2["weight"])
	return null


static func _known_measure(value) -> Variant:
	if (value is int or value is float) and is_finite(float(value)) and float(value) >= 0:
		return float(value)
	return null


static func get_material(target) -> String:
	if target == null:
		return ""
	if target is Character:
		if target.feature_uses.has("material"):
			return _known_material(target.feature_uses["material"])
		return ""
	if target is Dictionary:
		var obj: Dictionary = target.get("world_object", target) if target.get("world_object") is Dictionary else target
		if obj.has("material"):
			return _known_material(obj["material"])
		if obj.has("definition_id"):
			var item := DataLoader.get_item(str(obj["definition_id"]))
			if item.has("material"):
				return _known_material(item["material"])
		if obj.has("item_id"):
			var item2 := DataLoader.get_item(str(obj["item_id"]))
			if item2.has("material"):
				return _known_material(item2["material"])
	return ""


static func _known_material(value) -> String:
	return value.to_lower().strip_edges() if value is String else ""


static func get_thickness_inches(target) -> Variant:
	if target == null:
		return null
	if target is Dictionary:
		var obj: Dictionary = target.get("world_object", target) if target.get("world_object") is Dictionary else target
		if obj.has("thickness_inches") and obj["thickness_inches"] != null:
			return _known_measure(obj["thickness_inches"])
		if obj.has("thickness") and obj["thickness"] != null:
			return _known_measure(obj["thickness"])
		var item := DataLoader.get_item(str(obj.get("definition_id", obj.get("item_id", ""))))
		return _known_measure(item.get("thickness_inches", null))
	return null


static func get_equipment_status(target) -> Dictionary:
	if target == null:
		return {"worn": false, "carried": false, "fixed": false, "loose": false, "unknown": true}
	if target is Character:
		return {
			"worn": false,
			"carried": false,
			"fixed": false,
			"loose": false,
			"unknown": false,
			"is_actor": true
		}
	if target is Dictionary:
		var obj: Dictionary = target.get("world_object", target) if target.get("world_object") is Dictionary else target
		var has_explicit_keys: bool = obj.has("worn") or obj.has("carried") or obj.has("fixed") or obj.has("worn_by") or obj.has("carried_by") or obj.has("is_worn") or obj.has("is_carried")
		if not has_explicit_keys and str(obj.get("kind", "")) != "loose":
			return {
				"worn": false,
				"carried": false,
				"fixed": false,
				"loose": false,
				"unknown": true
			}
		var is_worn: bool = bool(obj.get("worn", obj.get("is_worn", false))) or not str(obj.get("worn_by", "")).is_empty()
		var is_carried: bool = bool(obj.get("carried", obj.get("is_carried", false))) or not str(obj.get("carried_by", "")).is_empty()
		var is_fixed: bool = bool(obj.get("fixed", false))
		var known: Array = []
		for field in ["worn", "carried", "fixed"]:
			if str(obj.get("kind", "")) == "loose" or obj.has(field) or obj.has("is_" + field) or obj.has(field + "_by"): known.append(field)
		var is_loose: bool = known.size() == 3 and not is_worn and not is_carried and not is_fixed
		return {
			"worn": is_worn,
			"carried": is_carried,
			"fixed": is_fixed,
			"loose": is_loose,
			"unknown": known.size() < 3,
			"known": known,
			"worn_by": str(obj.get("worn_by", "")),
			"carried_by": str(obj.get("carried_by", ""))
		}
	return {"worn": false, "carried": false, "fixed": false, "loose": false, "unknown": true}


static func physical_requirements_error(requirements: Variant) -> String:
	if not requirements is Dictionary:
		return "physical_requirements must be a Dictionary."
	if requirements.has("reject_unknown") and (not requirements["reject_unknown"] is bool or requirements["reject_unknown"] != true):
		return "Physical eligibility cannot accept unknown required facts."
	for key in requirements:
		if key not in ["allowed_sizes", "min_size", "max_size", "allowed_materials", "forbidden_materials", "min_mass_lb", "max_mass_lb", "max_thickness_inches", "required_status", "reject_unknown"]:
			return "Unsupported physical_requirements key: %s." % key
	if requirements.has("allowed_sizes"):
		if not requirements["allowed_sizes"] is Array or not requirements["allowed_sizes"].all(func(v): return v is String and str(v).to_lower() in VALID_SIZES):
			return "allowed_sizes must be an array of valid size strings."
	if requirements.has("min_size") and str(requirements["min_size"]).to_lower() not in VALID_SIZES:
		return "min_size must be a valid size string."
	if requirements.has("max_size") and str(requirements["max_size"]).to_lower() not in VALID_SIZES:
		return "max_size must be a valid size string."
	if requirements.has("allowed_materials"):
		if not requirements["allowed_materials"] is Array or not requirements["allowed_materials"].all(func(v): return v is String and not str(v).is_empty()):
			return "allowed_materials must be an array of non-empty strings."
	if requirements.has("forbidden_materials"):
		if not requirements["forbidden_materials"] is Array or not requirements["forbidden_materials"].all(func(v): return v is String and not str(v).is_empty()):
			return "forbidden_materials must be an array of non-empty strings."
	if requirements.has("min_mass_lb"):
		if _known_measure(requirements["min_mass_lb"]) == null:
			return "min_mass_lb must be a non-negative number."
	if requirements.has("max_mass_lb"):
		if _known_measure(requirements["max_mass_lb"]) == null:
			return "max_mass_lb must be a non-negative number."
	if requirements.has("max_thickness_inches"):
		if _known_measure(requirements["max_thickness_inches"]) == null:
			return "max_thickness_inches must be a non-negative number."
	if requirements.has("required_status"):
		if str(requirements["required_status"]).to_lower() not in VALID_EQUIPMENT_STATUSES:
			return "required_status must be a recognized equipment status string."
	return ""


static func evaluate_physical_eligibility(target, filter: Dictionary) -> Dictionary:
	var error := physical_requirements_error(filter)
	if not error.is_empty():
		return {"eligible": false, "reason": error}
	if filter.is_empty():
		return {"eligible": true, "reason": ""}

	var reject_unknown := true

	# 1. Size evaluation
	if filter.has("allowed_sizes") or filter.has("min_size") or filter.has("max_size"):
		var actual_size := get_size(target)
		if actual_size.is_empty():
			if reject_unknown:
				return {"eligible": false, "reason": "Target size is unknown."}
		else:
			if filter.has("allowed_sizes"):
				var allowed: Array = filter["allowed_sizes"]
				var allowed_lowered: Array[String] = []
				for s in allowed: allowed_lowered.append(str(s).to_lower())
				if not actual_size in allowed_lowered:
					return {"eligible": false, "reason": "Target size '%s' is not in allowed sizes: %s." % [actual_size, str(allowed)]}
			if filter.has("min_size"):
				var min_rank := int(SIZE_RANKS.get(str(filter["min_size"]).to_lower(), 0))
				var actual_rank := int(SIZE_RANKS.get(actual_size, 0))
				if actual_rank < min_rank:
					return {"eligible": false, "reason": "Target size '%s' is smaller than minimum '%s'." % [actual_size, str(filter["min_size"])]}
			if filter.has("max_size"):
				var max_rank := int(SIZE_RANKS.get(str(filter["max_size"]).to_lower(), 99))
				var actual_rank := int(SIZE_RANKS.get(actual_size, 0))
				if actual_rank > max_rank:
					return {"eligible": false, "reason": "Target size '%s' is larger than maximum '%s'." % [actual_size, str(filter["max_size"])]}

	# 2. Material evaluation
	if filter.has("allowed_materials") or filter.has("forbidden_materials"):
		var actual_material := get_material(target)
		if actual_material.is_empty():
			if reject_unknown:
				return {"eligible": false, "reason": "Target material is unknown."}
		else:
			if filter.has("allowed_materials"):
				var allowed_mat: Array = filter["allowed_materials"]
				var allowed_mat_lowered: Array[String] = []
				for m in allowed_mat: allowed_mat_lowered.append(str(m).to_lower())
				if not actual_material in allowed_mat_lowered:
					return {"eligible": false, "reason": "Target material '%s' is not in allowed materials: %s." % [actual_material, str(allowed_mat)]}
			if filter.has("forbidden_materials"):
				var forbidden: Array = filter["forbidden_materials"]
				var forbidden_lowered: Array[String] = []
				for m in forbidden: forbidden_lowered.append(str(m).to_lower())
				if actual_material in forbidden_lowered:
					return {"eligible": false, "reason": "Target material '%s' is forbidden: %s." % [actual_material, str(forbidden)]}

	# 3. Mass / Weight evaluation
	if filter.has("max_mass_lb") or filter.has("min_mass_lb"):
		var actual_mass = get_mass_lb(target)
		if actual_mass == null:
			if reject_unknown:
				return {"eligible": false, "reason": "Target mass/weight is unknown."}
		else:
			var mass_val := float(actual_mass)
			if filter.has("max_mass_lb") and mass_val > float(filter["max_mass_lb"]):
				return {"eligible": false, "reason": "Target mass %0.1f lbs exceeds maximum %0.1f lbs." % [mass_val, float(filter["max_mass_lb"])]}
			if filter.has("min_mass_lb") and mass_val < float(filter["min_mass_lb"]):
				return {"eligible": false, "reason": "Target mass %0.1f lbs is below minimum %0.1f lbs." % [mass_val, float(filter["min_mass_lb"])]}

	# 4. Thickness evaluation
	if filter.has("max_thickness_inches"):
		var actual_thickness = get_thickness_inches(target)
		if actual_thickness == null:
			if reject_unknown:
				return {"eligible": false, "reason": "Target thickness is unknown."}
		else:
			var thick_val := float(actual_thickness)
			if thick_val > float(filter["max_thickness_inches"]):
				return {"eligible": false, "reason": "Target thickness %0.1f in exceeds maximum %0.1f in." % [thick_val, float(filter["max_thickness_inches"])]}

	# 5. Equipment status evaluation
	if filter.has("required_status"):
		var status_req := str(filter["required_status"]).to_lower()
		var status := get_equipment_status(target)
		var needed: Array = ["worn", "carried", "fixed"] if status_req in ["loose", "unattended"] else ["worn", "carried"] if status_req == "not_worn_or_carried" else ["fixed"] if status_req == "not_fixed" else [status_req]
		var unknown_status := bool(status.get("unknown", false))
		if status.has("known"): unknown_status = not needed.all(func(field): return field in status.known)
		if unknown_status:
			if reject_unknown:
				return {"eligible": false, "reason": "Target equipment status is unknown."}
		elif status_req in ["loose", "unattended"]:
			if not bool(status.get("loose", false)):
				return {"eligible": false, "reason": "Target object is not loose/unattended (worn: %s, carried: %s, fixed: %s)." % [status.worn, status.carried, status.fixed]}
		elif status_req == "not_worn_or_carried":
			if bool(status.get("worn", false)) or bool(status.get("carried", false)):
				return {"eligible": false, "reason": "Target object is being worn or carried."}
		elif status_req == "not_fixed":
			if bool(status.get("fixed", false)):
				return {"eligible": false, "reason": "Target object is fixed in place."}
		elif status_req == "worn":
			if not bool(status.get("worn", false)):
				return {"eligible": false, "reason": "Target object is not worn."}
		elif status_req == "carried":
			if not bool(status.get("carried", false)):
				return {"eligible": false, "reason": "Target object is not carried."}
		elif status_req == "fixed":
			if not bool(status.get("fixed", false)):
				return {"eligible": false, "reason": "Target object is not fixed in place."}

	return {"eligible": true, "reason": ""}


# =========================================================================
# S-033: Plane, Location, and Available-Space Facts
# =========================================================================

static func get_plane(entity_or_context, fallback_context: Dictionary = {}) -> String:
	if entity_or_context == null:
		return str(fallback_context.get("plane", DEFAULT_PLANE)).to_lower().strip_edges()
	if entity_or_context is Character:
		return str(entity_or_context.feature_uses.get("plane", fallback_context.get("plane", DEFAULT_PLANE))).to_lower().strip_edges()
	if entity_or_context is Dictionary:
		if entity_or_context.has("plane") and not str(entity_or_context["plane"]).is_empty():
			return str(entity_or_context["plane"]).to_lower().strip_edges()
		if entity_or_context.has("world_object") and entity_or_context["world_object"] is Dictionary:
			var wo: Dictionary = entity_or_context["world_object"]
			if wo.has("plane") and not str(wo["plane"]).is_empty():
				return str(wo["plane"]).to_lower().strip_edges()
	if fallback_context.has("plane") and not str(fallback_context["plane"]).is_empty():
		return str(fallback_context["plane"]).to_lower().strip_edges()
	return DEFAULT_PLANE


static func get_location(entity, context: Dictionary = {}) -> Dictionary:
	var internal := ContainmentRules.internal_location(entity, context.get("room", {}))
	if not internal.is_empty():
		return {"plane": get_plane(entity, context), "position": null, "location_known": false, "location_kind": "internal", "room_id": internal.room_id, "container_kind": internal.container_kind, "container_id": internal.container_id, "external_location": internal.external_location, "elevation_feet": 0, "altitude_feet": 0}
	var plane := get_plane(entity, context)
	var pos: Variant = null
	var elevation := 0
	var altitude := 0

	if entity is Character:
		if context.has("players"):
			for p in context["players"]:
				if p.get("character") == entity:
					pos = p.get("hex_position", Vector2i.ZERO)
					altitude = int(p.get("altitude_feet", 0))
					break
	elif entity is Dictionary:
		if entity.has("hex_position"):
			pos = entity["hex_position"]
		elif entity.has("position") and entity["position"] is Array and entity["position"].size() >= 2:
			pos = Vector2i(int(entity["position"][0]), int(entity["position"][1]))
		altitude = int(entity.get("altitude_feet", 0))

	var room: Dictionary = context.get("room", {})
	if not room.is_empty() and pos != null:
		elevation = LocalRoomRules.elevation_feet(room, pos)

	return {
		"plane": plane,
		"position": pos,
		"location_known": pos != null,
		"elevation_feet": elevation,
		"altitude_feet": altitude
	}


static func spatial_requirements_error(requirements: Variant) -> String:
	if not requirements is Dictionary:
		return "spatial_requirements must be a Dictionary."
	for key in requirements:
		if key not in ["plane", "requires_available_space", "body_size", "clearance_feet", "same_plane_as_caster"]:
			return "Unsupported spatial_requirements key: %s." % key
	if requirements.has("plane") and (not requirements["plane"] is String or str(requirements["plane"]).is_empty()):
		return "plane must be a non-empty string."
	if requirements.has("body_size") and str(requirements["body_size"]).to_lower() not in VALID_SIZES:
		return "body_size must be a valid size string."
	if requirements.has("clearance_feet") and (_known_measure(requirements["clearance_feet"]) == null or float(requirements["clearance_feet"]) != floorf(float(requirements["clearance_feet"]))):
		return "clearance_feet must be a non-negative integer."
	for key in ["requires_available_space", "same_plane_as_caster"]:
		if requirements.has(key) and not requirements[key] is bool:
			return "%s must be a boolean." % key
	if not bool(requirements.get("requires_available_space", false)) and (requirements.has("body_size") or requirements.has("clearance_feet")):
		return "Body size and clearance require an available-space query."
	return ""


static func evaluate_spatial_eligibility(grid: HexGrid, position: Vector2i, requirements: Dictionary, context: Dictionary = {}) -> Dictionary:
	var error := spatial_requirements_error(requirements)
	if not error.is_empty(): return {"eligible": false, "reason": error}
	var plane := str(context.get("plane", DEFAULT_PLANE)).to_lower().strip_edges()
	if requirements.has("plane") and plane != str(requirements.plane).to_lower().strip_edges():
		return {"eligible": false, "reason": "Destination is on a different plane."}
	if bool(requirements.get("same_plane_as_caster", false)) and get_plane(context.get("caster"), context) != plane:
		return {"eligible": false, "reason": "Destination is not on the caster's plane."}
	if bool(requirements.get("requires_available_space", false)):
		var space_context := context.duplicate()
		space_context["clearance_feet"] = int(requirements.get("clearance_feet", 0))
		var space := is_space_available(grid, position, str(requirements.get("body_size", "medium")), plane, space_context)
		return {"eligible": space.available, "reason": space.reason}
	return {"eligible": true, "reason": ""}


static func is_space_available(grid: HexGrid, position: Vector2i, size: String = "medium", plane: String = DEFAULT_PLANE, context: Dictionary = {}) -> Dictionary:
	var clean_size := size.to_lower().strip_edges()
	if not clean_size in VALID_SIZES:
		return {"available": false, "reason": "Body size is unknown."}
	if grid == null:
		return {"available": false, "reason": "Available space is unknown without a grid."}

	# 1. Plane check
	var target_plane := str(context.get("plane", DEFAULT_PLANE)).to_lower().strip_edges()
	if target_plane != plane:
		return {
			"available": false,
			"reason": "Space is on plane '%s', but query requested plane '%s'." % [target_plane, plane],
			"plane": target_plane,
			"position": position,
			"size": clean_size,
			"clearance_feet": 0,
			"required_clearance_feet": SIZE_MIN_CLEARANCE_FEET.get(clean_size, 6)
		}

	# 2. Grid bounds & passability check
	if grid != null:
		if not grid.has_tile(position):
			return {
				"available": false,
				"reason": "Position %s is outside the grid bounds." % str(position),
				"plane": plane,
				"position": position,
				"size": clean_size,
				"clearance_feet": 0,
				"required_clearance_feet": SIZE_MIN_CLEARANCE_FEET.get(clean_size, 6)
			}
		if not grid.is_hex_passable(position):
			return {
				"available": false,
				"reason": "Position %s is impassable terrain or blocked by geometry." % str(position),
				"plane": plane,
				"position": position,
				"size": clean_size,
				"clearance_feet": 0,
				"required_clearance_feet": SIZE_MIN_CLEARANCE_FEET.get(clean_size, 6)
			}

	# 3. Room & Vertical clearance check
	var room: Dictionary = context.get("room", {})
	if not context.has("room"):
		room = LocalRoomCombat.room()

	var elevation := 0
	var ceiling := 1000
	if not room.is_empty():
		elevation = LocalRoomRules.elevation_feet(room, position)
		ceiling = LocalRoomRules.ceiling_feet(room, position)
		if LocalRoomRules.has_wall(room, position):
			return {
				"available": false,
				"reason": "Position %s has a solid room wall." % str(position),
				"plane": plane,
				"position": position,
				"size": clean_size,
				"clearance_feet": 0,
				"required_clearance_feet": SIZE_MIN_CLEARANCE_FEET.get(clean_size, 6)
			}

	var clearance := ceiling - elevation
	var req_clearance: int = int(SIZE_MIN_CLEARANCE_FEET.get(clean_size, 6))
	if context.has("clearance_feet"):
		req_clearance = maxi(req_clearance, int(context["clearance_feet"]))

	if clearance < req_clearance:
		return {
			"available": false,
			"reason": "Insufficient vertical clearance for %s body (needs %d ft, has %d ft)." % [clean_size, req_clearance, clearance],
			"plane": plane,
			"position": position,
			"size": clean_size,
			"clearance_feet": clearance,
			"required_clearance_feet": req_clearance
		}

	# 4. Living occupant check
	var ignore_entity = context.get("ignore_entity", null)
	var occupants: Array = []
	if context.has("players"):
		for p in context["players"]:
			var body = p.get("character")
			if body is Character and not ContainmentRules.relation(room, "character", body.character_id).is_empty(): continue
			if p.get("hex_position", Vector2i.ZERO) == position:
				var ch = p.get("character")
				if ch != null and ch.is_alive:
					var is_ign: bool = (ignore_entity is Object and ch == ignore_entity)
					if not is_ign:
						occupants.append(ch)
	if context.has("monsters"):
		for m in context["monsters"]:
			if m.get("hex_position", Vector2i.ZERO) == position and m.get("is_alive", false):
				var is_ign: bool = (ignore_entity is Dictionary and m == ignore_entity)
				if not is_ign:
					occupants.append(m)
	# The grid is also a production caller's source of occupants; optional lists
	# must not turn an occupied cell into available space.
	for entity in grid.entities:
		if entity.get("hex_position") != position: continue
		var occupant = entity.get("character", entity.get("monster", null))
		if occupant == null or is_same(occupant, ignore_entity): continue
		if occupant is Character and not ContainmentRules.relation(room, "character", occupant.character_id).is_empty(): continue
		if (occupant is Character and occupant.is_alive) or (occupant is Dictionary and occupant.get("is_alive", false)):
			occupants.append(occupant)

	for occ in occupants:
		if occ != null:
			var occ_name: String = occ.character_name if occ is Character else str(occ.get("name", "Creature"))
			return {
				"available": false,
				"reason": "Position %s is occupied by another creature (%s)." % [str(position), occ_name],
				"plane": plane,
				"position": position,
				"size": clean_size,
				"clearance_feet": clearance,
				"required_clearance_feet": req_clearance
			}

	# 5. Blocking world objects
	var objects: Array = []
	if grid != null:
		objects = CombatObjectRules.all_at(grid, position)
	if context.has("objects"):
		for obj in context["objects"]:
			var obj_pos: Vector2i = obj.get("hex_position", Vector2i(-999, -999))
			if obj.has("position") and obj["position"] is Array and obj["position"].size() >= 2:
				obj_pos = Vector2i(int(obj["position"][0]), int(obj["position"][1]))
			if obj_pos == position:
				objects.append(obj)
	for obj in objects:
		if not ContainmentRules.relation(room, "object", str(obj.get("id", ""))).is_empty(): continue
		if bool(obj.get("fixed", false)) or bool(obj.get("blocks_movement", false)) or str(obj.get("kind", "")) == "barrier":
			if not bool(obj.get("removed", false)) and int(obj.get("hp", 1)) > 0:
				var obj_name := str(obj.get("name", "Fixed Object"))
				return {
					"available": false,
					"reason": "Position %s is blocked by a fixed object (%s)." % [str(position), obj_name],
					"plane": plane,
					"position": position,
					"size": clean_size,
					"clearance_feet": clearance,
					"required_clearance_feet": req_clearance
				}

	return {
		"available": true,
		"reason": "",
		"plane": plane,
		"position": position,
		"size": clean_size,
		"clearance_feet": clearance,
		"required_clearance_feet": req_clearance
	}


# =========================================================================
# S-179: Speed, Modes, Surface/Hand Requirements, and Terrain Costs
# =========================================================================

static func get_speed_for_mode(actor, mode: String) -> int:
	if actor == null:
		return 0
	var clean_mode := mode.to_lower().strip_edges()
	if actor is Character:
		if clean_mode == "walk":
			return actor.get_speed() * 5
		var spd: int = actor.movement_speed_feet(clean_mode)
		if spd == 0 and clean_mode == "fly" and actor.has_condition("fly"):
			return 60
		if spd == 0 and clean_mode == "climb" and actor.has_condition("spider_climb"):
			return actor.get_speed() * 5
		return spd
	if actor is Dictionary:
		if clean_mode == "walk":
			return int(actor.get("speed", 0)) * 5
		if clean_mode == "fly":
			return int(actor.get("fly_speed_feet", 0))
		if clean_mode == "climb":
			return int(actor.get("climb_speed_feet", 0))
		if clean_mode == "swim":
			return int(actor.get("swim_speed_feet", 0))
	return 0


static func has_hover(actor) -> bool:
	if actor == null:
		return false
	if actor is Character:
		return actor.has_feature("hover") or actor.has_condition("hover") or SpellEffects.has_spell(actor, "levitate")
	if actor is Dictionary:
		return bool(actor.get("hover", false))
	return false


static func get_free_hands(actor) -> int:
	if actor is Character:
		return actor.inventory.available_spellcasting_hands()
	if actor is Dictionary:
		return int(actor.get("free_hands", 2))
	return 2


static func check_surface_and_hand_requirements(actor, mode: String, surface: String, surface_metadata: Dictionary = {}) -> Dictionary:
	var clean_mode := mode.to_lower().strip_edges()
	var clean_surface := surface.to_lower().strip_edges()

	if clean_mode not in VALID_MODES:
		return {"allowed": false, "reason": "Unsupported movement mode '%s'." % mode}

	# 1. Walk requirements
	if clean_mode == "walk":
		if clean_surface in ["water", "acid", "liquid", "lava"] and not (actor is Character and (SpellEffects.has_spell(actor, "water_walk") or actor.has_condition("water_walk"))):
			return {"allowed": false, "reason": "Walking is impossible on liquid surface '%s' without Water Walk." % surface}
		if clean_surface in ["ceiling", "inverted"] and not (actor is Character and (SpellEffects.has_spell(actor, "spider_climb") or actor.has_condition("spider_climb"))):
			return {"allowed": false, "reason": "Walking on an inverted ceiling requires Spider Climb or specialized adhesion."}
		return {"allowed": true, "reason": ""}

	# 2. Swim requirements
	if clean_mode == "swim":
		if clean_surface not in ["water", "acid", "liquid", "swamp_deep"] and not bool(surface_metadata.get("submerged", false)):
			return {"allowed": false, "reason": "Swimming requires a liquid surface or submerged environment (surface is '%s')." % surface}
		return {"allowed": true, "reason": ""}

	# 3. Fly requirements
	if clean_mode == "fly":
		var fly_speed := get_speed_for_mode(actor, "fly")
		if fly_speed <= 0:
			return {"allowed": false, "reason": "Creature has no declared flying speed."}
		if actor is Character:
			if actor.has_condition("restrained") or actor.has_condition("paralyzed") or actor.has_condition("petrified") or actor.has_condition("stunned"):
				return {"allowed": false, "reason": "Incapacitating or restraining condition prevents flying."}
			if actor.has_condition("prone") and not has_hover(actor):
				return {"allowed": false, "reason": "Prone creature without hover cannot fly."}
		return {"allowed": true, "reason": ""}

	# 4. Climb requirements
	if clean_mode == "climb":
		var has_spider_climb: bool = actor is Character and (SpellEffects.has_spell(actor, "spider_climb") or actor.has_condition("spider_climb"))
		if clean_surface in ["ceiling", "inverted"]:
			if not has_spider_climb:
				return {"allowed": false, "reason": "Inverted ceiling climbing requires spider climb or specialized ceiling adhesion."}
			return {"allowed": true, "reason": ""}

		if clean_surface in ["sheer", "slippery", "ice"]:
			var has_climb_speed: bool = get_speed_for_mode(actor, "climb") > 0
			if not has_spider_climb and not has_climb_speed:
				return {"allowed": false, "reason": "Slippery or sheer surface '%s' cannot be climbed without climb speed or magical adhesion." % surface}

		if not has_spider_climb:
			var free_hands: int = get_free_hands(actor)
			var hands_needed: int = 1 if bool(surface_metadata.get("aided", false)) else 2
			if free_hands < hands_needed:
				return {"allowed": false, "reason": "Climbing requires %d free hand(s) (actor currently has %d free hand(s))." % [hands_needed, free_hands]}

		return {"allowed": true, "reason": ""}

	return {"allowed": true, "reason": ""}


static func calculate_movement_step_cost(actor, mode: String, terrain_type: String = "normal", surface: String = "ground", context: Dictionary = {}) -> Dictionary:
	var clean_mode := mode.to_lower().strip_edges()
	var base_feet := 5
	var mode_mult := 1.0
	var terrain_extra_feet := 0

	if clean_mode == "climb":
		var has_climb_speed: bool = get_speed_for_mode(actor, "climb") > 0 or (actor is Character and (SpellEffects.has_spell(actor, "spider_climb") or actor.has_condition("spider_climb")))
		if not has_climb_speed:
			mode_mult = 2.0
	elif clean_mode == "swim":
		var has_swim_speed: bool = get_speed_for_mode(actor, "swim") > 0 or (actor is Character and (SpellEffects.has_spell(actor, "freedom_of_movement") or actor.has_condition("freedom_of_movement")))
		if not has_swim_speed:
			mode_mult = 2.0
	elif clean_mode == "fly":
		mode_mult = 1.0
	elif clean_mode == "walk":
		mode_mult = 1.0

	var is_difficult: bool = (terrain_type.to_lower() == "difficult") or bool(context.get("difficult_terrain", false))
	if is_difficult:
		if clean_mode == "fly" and not bool(context.get("aerial_difficult_terrain", false)):
			terrain_extra_feet = 0
		else:
			terrain_extra_feet = 5

	var total_feet := int(round(base_feet * mode_mult)) + terrain_extra_feet

	return {
		"cost_feet": total_feet,
		"cost_hexes": float(total_feet) / 5.0,
		"base_feet": base_feet,
		"mode_multiplier": mode_mult,
		"terrain_extra_feet": terrain_extra_feet
	}


static func attempt_movement_step(actor, mode: String, from_pos: Vector2i, to_pos: Vector2i, current_budget_feet: int, grid: HexGrid, surface: String = "ground", terrain_type: String = "normal", context: Dictionary = {}) -> Dictionary:
	var available_speed := get_speed_for_mode(actor, mode)
	if mode in ["climb", "swim"] and available_speed <= 0: available_speed = get_speed_for_mode(actor, "walk")
	if HexUtils.get_distance(from_pos, to_pos) != 1 or actor == null or available_speed <= 0:
		return {"success": false, "refused": true, "reason": "Movement needs an adjacent destination and an actor able to move.", "spent_distance_feet": 0, "remaining_budget_feet": current_budget_feet, "unrelated_modes_spent": 0, "destination": from_pos}
	# 1. Available space check (S-033)
	var actor_size := get_size(actor)
	var actor_plane := get_plane(actor, context)
	var space_ctx := context.duplicate()
	space_ctx["ignore_entity"] = actor
	var space_eval := is_space_available(grid, to_pos, actor_size, actor_plane, space_ctx)
	if not space_eval.available:
		return {
			"success": false,
			"refused": true,
			"reason": space_eval.reason,
			"spent_distance_feet": 0,
			"remaining_budget_feet": current_budget_feet,
			"unrelated_modes_spent": 0,
			"destination": from_pos
		}

	# 2. Surface and hand requirement check (S-179, S-032)
	var req_eval := check_surface_and_hand_requirements(actor, mode, surface, context)
	if not req_eval.allowed:
		return {
			"success": false,
			"refused": true,
			"reason": req_eval.reason,
			"spent_distance_feet": 0,
			"remaining_budget_feet": current_budget_feet,
			"unrelated_modes_spent": 0,
			"destination": from_pos
		}

	# 3. Calculate step cost
	var cost_info := calculate_movement_step_cost(actor, mode, terrain_type, surface, context)
	var cost_feet: int = cost_info.cost_feet

	# 4. Budget check
	if cost_feet > current_budget_feet:
		return {
			"success": false,
			"refused": true,
			"reason": "Insufficient movement remaining (%d ft needed, %d ft available)." % [cost_feet, current_budget_feet],
			"spent_distance_feet": 0,
			"remaining_budget_feet": current_budget_feet,
			"unrelated_modes_spent": 0,
			"destination": from_pos
		}

	# 5. Success
	return {
		"success": true,
		"refused": false,
		"reason": "",
		"spent_distance_feet": cost_feet,
		"remaining_budget_feet": current_budget_feet - cost_feet,
		"unrelated_modes_spent": 0,
		"destination": to_pos
	}
