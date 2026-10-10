## Shared portable-light radius and burn-time rules for exact inventory copies.
class_name LightSourceRules
extends RefCounted

static func is_lit(record: Dictionary) -> bool:
	var state: Dictionary = record.get("state", {})
	return bool(state.get("light_source_lit", false)) and int(state.get("light_source_remaining_seconds", 0)) > 0


static func bright_radius_hexes(record: Dictionary) -> int:
	return _radius_hexes(record, "bright_radius_feet")


static func dim_radius_hexes(record: Dictionary) -> int:
	return _radius_hexes(record, "dim_radius_feet")


static func _radius_hexes(record: Dictionary, radius_key: String) -> int:
	if not is_lit(record):
		return 0
	var item := DataLoader.get_item(str(record.get("definition_id", "")))
	var light_source: Dictionary = item.get("light_source", {})
	var feet := maxi(0, int(light_source.get(radius_key, 0)))
	return int(ceil(float(feet) / 5.0))


static func tick_record(record: Dictionary, elapsed_seconds: int) -> Dictionary:
	var updated := record.duplicate(true)
	var state: Dictionary = updated.get("state", {}).duplicate(true)
	if not bool(state.get("light_source_lit", false)):
		return updated
	var remaining := maxi(0, int(state.get("light_source_remaining_seconds", 0)) - maxi(0, elapsed_seconds))
	state["light_source_remaining_seconds"] = remaining
	if remaining == 0:
		state["light_source_lit"] = false
	updated["state"] = state
	return updated


static func advance_inventory(inventory: Inventory, elapsed_seconds: int) -> void:
	if inventory == null or elapsed_seconds <= 0:
		return
	for record in inventory.owned_instances():
		if is_lit(record):
			inventory.update_instance(tick_record(record, elapsed_seconds))
