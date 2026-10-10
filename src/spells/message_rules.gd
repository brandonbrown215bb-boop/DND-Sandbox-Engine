## Transient local delivery for the Message cantrip.
## Content is never written to the campaign activity log or save data.
class_name MessageRules
extends RefCounted

const RANGE_HEXES := 24 # 120 feet on the combat grid.
const DURATION_ROUNDS := 1


static func create_exchange(caster_id: String, target_id: String, message: String, reply: String = "") -> Dictionary:
	return {
		"caster_id": caster_id,
		"target_id": target_id,
		"message": message.strip_edges(),
		"reply": reply.strip_edges(),
		"rounds_remaining": DURATION_ROUNDS,
	}


static func activity_summary(caster_name: String, target_name: String) -> String:
	return "%s sends a private Message to %s." % [caster_name, target_name]

