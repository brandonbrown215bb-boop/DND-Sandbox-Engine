## Source-end reason aftermath (S-086).
##
## A shared spell may declare `end_aftermath`: entries keyed by exact end
## reasons. SpellEffects.remove already emits exactly one final end event per
## source; this module fires only the follow-ups whose declared reasons match
## that one event's reason, once, on the recipient that held the source.
## Distinct reasons are never conflated (expiry is not dismissal).
class_name SourceEndAftermathRules
extends RefCounted

const EFFECT_TYPES := ["damage", "condition"]

static func validate(value: Variant) -> String:
	if not value is Array or value.is_empty() or value.size() > 8: return "end_aftermath must be an array of 1-8 entries"
	var ids := {}
	for entry in value:
		if not entry is Dictionary or str(entry.get("id", "")).is_empty() or ids.has(str(entry.id)): return "end_aftermath entries need unique ids"
		ids[str(entry.id)] = true
		var reasons: Variant = entry.get("reasons", null)
		if not reasons is Array or reasons.is_empty() or reasons.any(func(r): return not r is String or str(r).is_empty() or str(r).length() > 40): return "end_aftermath reasons are invalid"
		var effects: Variant = entry.get("effects", null)
		if not effects is Array or effects.is_empty() or effects.size() > 4: return "end_aftermath effects are invalid"
		for effect in effects:
			if not effect is Dictionary or str(effect.get("type", "")) not in EFFECT_TYPES: return "end_aftermath effect type is invalid"
			if effect.type == "damage" and (not _int(effect.get("amount", null), 1, 1000) or str(effect.get("damage_type", "")) not in DataLoader.VALID_DAMAGE_TYPES): return "end_aftermath damage is invalid"
			if effect.type == "condition" and (str(effect.get("condition", "")).is_empty() or not _int(effect.get("rounds", null), 1, 100)): return "end_aftermath condition is invalid"
	return ""

## Fire matching follow-ups for one final end event. Returns receipts.
static func fire(target, record: Dictionary, event: Dictionary) -> Array:
	var receipts: Array = []
	var entries: Variant = record.get("end_aftermath", [])
	if not entries is Array or entries.is_empty() or not validate(entries).is_empty(): return receipts
	var reason := str(event.get("end_reason", ""))
	for entry in entries:
		if reason not in entry.reasons: continue
		var receipt := {"aftermath_id": str(entry.id), "source_id": str(event.get("source_id", "")), "end_reason": reason, "origin_id": _id(target), "location": target.get("hex_position", null) if target is Dictionary else null, "effects": []}
		for effect in entry.effects:
			match str(effect.type):
				"damage":
					var settled := CombatAction.resolve_damage(target, int(effect.amount), str(effect.damage_type), {"damage_source_instance_id": str(event.get("source_id", "")), "damage_source_actor_id": str(record.get("caster_id", ""))})
					receipt.effects.append({"type": "damage", "resolved": int(settled.get("resolved", 0)), "hp_loss": int(settled.get("hp_loss", 0))})
				"condition":
					_add_condition(target, str(effect.condition), int(effect.rounds))
					receipt.effects.append({"type": "condition", "condition": str(effect.condition), "rounds": int(effect.rounds)})
		receipts.append(receipt)
	return receipts

static func _add_condition(target, condition: String, rounds: int) -> void:
	if target is Character: target.add_condition(condition, rounds)
	elif target is Dictionary:
		var conditions: Dictionary = target.get("conditions", {})
		conditions[condition] = rounds
		target["conditions"] = conditions

static func _id(target) -> String:
	return target.character_id if target is Character else str(target.get("id", "")) if target is Dictionary else ""

static func _int(v: Variant, lo: int, hi: int) -> bool:
	return (v is int or v is float) and float(v) == floor(float(v)) and int(v) >= lo and int(v) <= hi
