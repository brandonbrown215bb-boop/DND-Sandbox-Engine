## Event System
## Handles RNG event triggering using weighted random tables.
## Loads event tables from DataLoader and resolves events.
class_name EventSystem
extends RefCounted

## Roll a random event from an event table.
## Returns the event dictionary, or an empty dictionary if no table found.
static func roll_event(table_id: String) -> Dictionary:
	var table := DataLoader.get_event_table(table_id)
	if table.is_empty():
		push_warning("[EventSystem] Event table not found: %s" % table_id)
		return {}

	var events: Array = table.get("events", [])
	if events.is_empty():
		return {}

	# Calculate total weight
	var total_weight := 0
	for event in events:
		total_weight += int(event.get("weight", 1))

	# Roll weighted random
	var roll := randi_range(1, total_weight)
	var cumulative := 0
	for event in events:
		cumulative += int(event.get("weight", 1))
		if roll <= cumulative:
			return event

	# Fallback (shouldn't happen)
	return events[0]


## Get the event table ID for a terrain type from the active campaign.
static func get_table_for_terrain(terrain_name: String) -> String:
	var campaign: Dictionary = GameManager.active_campaign
	var event_tables: Dictionary = campaign.get("map", {}).get("event_tables", {})
	return event_tables.get(terrain_name, "")


## Trigger an event for a hex tile. Returns the event data or empty dict.
static func trigger_event_for_tile(tile: HexTile) -> Dictionary:
	# Use tile's custom event table if set, otherwise look up by terrain
	var table_id := tile.event_table_id
	if table_id.is_empty():
		table_id = get_table_for_terrain(tile.get_terrain_name())

	if table_id.is_empty():
		return {}

	return roll_event(table_id)
