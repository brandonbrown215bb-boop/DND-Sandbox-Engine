## Campaign delivery state for Animal Messenger.
class_name AnimalMessengerRules
extends RefCounted

const MILES_PER_OVERWORLD_HEX := 5.0
const MAX_SAVED_DELIVERIES := 100


static func validate_order(order: Dictionary, visited_locations: Array[Dictionary]) -> Dictionary:
	var destination_id := str(order.get("destination_id", ""))
	var destination_found := visited_locations.any(func(location: Dictionary) -> bool: return str(location.get("id", "")) == destination_id)
	if not destination_found:
		return {"success": false, "message": "Choose a location the party has already visited."}
	var recipient := str(order.get("recipient", "")).strip_edges()
	if recipient.is_empty() or recipient.length() > 120:
		return {"success": false, "message": "Enter a recipient description of 1 to 120 characters."}
	var message := _normalize_message(str(order.get("message", "")))
	if message.is_empty() or message.split(" ", false).size() > 25:
		return {"success": false, "message": "Enter a message of 1 to 25 words."}
	return {"success": true, "destination_id": destination_id, "recipient": recipient, "message": message}


static func create_delivery(delivery_id: String, caster_id: String, caster_name: String, origin: Vector2i, destination: Dictionary, recipient: String, message: String, duration_seconds: int, can_fly: bool, miles_per_hex: float = MILES_PER_OVERWORLD_HEX) -> Dictionary:
	var destination_coord: Array = destination.get("coord", [])
	var speed := 50.0 if can_fly else 25.0
	return {
		"id": delivery_id,
		"caster_id": caster_id,
		"caster_name": caster_name,
		"origin": [origin.x, origin.y],
		"destination_id": str(destination.get("id", "")),
		"destination_name": str(destination.get("name", "")),
		"destination": destination_coord.duplicate(),
		"recipient": recipient,
		"message": _normalize_message(message),
		"travel_miles_per_24_hours": speed,
		"miles_per_hex": maxf(0.1, miles_per_hex),
		"duration_seconds": maxi(1, duration_seconds),
		"elapsed_seconds": 0,
		"travelled_miles": 0.0,
		"status": "in_transit",
	}


static func advance_deliveries(deliveries: Array[Dictionary], elapsed_seconds: int) -> Dictionary:
	if elapsed_seconds <= 0:
		return {"deliveries": deliveries.duplicate(true), "notifications": []}
	var updated: Array[Dictionary] = []
	var notifications: Array[Dictionary] = []
	for delivery_value in deliveries:
		var delivery := delivery_value.duplicate(true)
		if str(delivery.get("status", "")) == "in_transit":
			var duration := maxi(1, int(delivery.get("duration_seconds", 1)))
			var previous_elapsed := clampi(int(delivery.get("elapsed_seconds", 0)), 0, duration)
			var remaining := duration - previous_elapsed
			var active_delta := mini(elapsed_seconds, remaining)
			var new_elapsed := previous_elapsed + active_delta
			var speed := maxf(0.0, float(delivery.get("travel_miles_per_24_hours", 25.0)))
			var travelled := float(delivery.get("travelled_miles", 0.0)) + speed * float(active_delta) / 86400.0
			var distance := _route_distance_miles(delivery.get("origin", []), delivery.get("destination", []), float(delivery.get("miles_per_hex", MILES_PER_OVERWORLD_HEX)))
			delivery["elapsed_seconds"] = new_elapsed
			delivery["travelled_miles"] = travelled
			if travelled + 0.0001 >= distance:
				delivery["status"] = "delivered"
				notifications.append({"status": "delivered", "delivery": delivery.duplicate(true)})
			elif new_elapsed >= duration:
				delivery["status"] = "returned"
				notifications.append({"status": "returned", "delivery": delivery.duplicate(true)})
		updated.append(delivery)
	return {"deliveries": updated, "notifications": notifications}


static func validate_saved_deliveries(value: Variant) -> String:
	if not value is Array or value.size() > MAX_SAVED_DELIVERIES:
		return "animal messenger ledger is not a bounded array"
	var ids: Dictionary = {}
	for delivery in value:
		if not delivery is Dictionary:
			return "animal messenger record is not an object"
		var delivery_id := str(delivery.get("id", ""))
		if delivery_id.is_empty() or ids.has(delivery_id):
			return "animal messenger record has a missing or duplicate ID"
		ids[delivery_id] = true
		if str(delivery.get("status", "")) not in ["in_transit", "delivered", "returned"]:
			return "animal messenger record has an invalid status"
		if str(delivery.get("recipient", "")).strip_edges().is_empty() or str(delivery.get("message", "")).split(" ", false).size() > 25:
			return "animal messenger message is invalid"
		if delivery.get("origin", null) is not Array or delivery.get("destination", null) is not Array:
			return "animal messenger coordinates are invalid"
		if delivery["origin"].size() != 2 or delivery["destination"].size() != 2:
			return "animal messenger coordinates are invalid"
		if not _coordinate_array_is_valid(delivery["origin"]) or not _coordinate_array_is_valid(delivery["destination"]):
			return "animal messenger coordinates are invalid"
		var duration := int(delivery.get("duration_seconds", 0))
		var elapsed := int(delivery.get("elapsed_seconds", -1))
		var speed := float(delivery.get("travel_miles_per_24_hours", 0.0))
		var miles_per_hex := float(delivery.get("miles_per_hex", MILES_PER_OVERWORLD_HEX))
		var travelled := float(delivery.get("travelled_miles", -1.0))
		if duration <= 0 or elapsed < 0 or elapsed > duration or speed not in [25.0, 50.0] or miles_per_hex <= 0.0 or miles_per_hex > 100.0 or travelled < 0.0:
			return "animal messenger travel data is invalid"
	return ""


static func _route_distance_miles(origin: Variant, destination: Variant, miles_per_hex: float) -> float:
	if not _coordinate_array_is_valid(origin) or not _coordinate_array_is_valid(destination):
		return INF
	var dq := int(origin[0]) - int(destination[0])
	var dr := int(origin[1]) - int(destination[1])
	var hex_distance := (absi(dq) + absi(dr) + absi(dq + dr)) / 2.0
	return hex_distance * miles_per_hex


static func _coordinate_array_is_valid(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	return value[0] is int and value[1] is int and absi(int(value[0])) <= 10000 and absi(int(value[1])) <= 10000


static func _normalize_message(value: String) -> String:
	return " ".join(value.replace("\r", " ").replace("\n", " ").replace("\t", " ").split(" ", false))
