## Validation and normalization for the versioned player-facing activity DTO.
## Records crossing the persistence boundary contain only JSON-safe values.
class_name ActivityRecord
extends RefCounted

const SCHEMA_VERSION := 1
const CATEGORIES := ["roll", "combat", "world", "system"]
const VISIBILITY_PUBLIC := "public"


static func prepare(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _failure("record is not an object")
	var raw: Dictionary = value
	var schema_version := int(raw.get("schema_version", 0))
	if schema_version > SCHEMA_VERSION:
		return _failure("unsupported future schema version %d" % schema_version, true)
	if schema_version != SCHEMA_VERSION:
		return _failure("unsupported schema version %d" % schema_version)

	var record_id := str(raw.get("id", "")).strip_edges()
	var sequence := int(raw.get("sequence", 0))
	var category := str(raw.get("category", ""))
	var kind := str(raw.get("kind", "")).strip_edges()
	var title := str(raw.get("title", "")).strip_edges()
	var summary := str(raw.get("summary", "")).strip_edges()
	var visibility := str(raw.get("visibility", ""))
	if record_id.is_empty():
		return _failure("record id is missing")
	if sequence <= 0:
		return _failure("record sequence must be positive")
	if category not in CATEGORIES:
		return _failure("record category is invalid")
	if kind.is_empty() or title.is_empty() or summary.is_empty():
		return _failure("record kind, title, and summary are required")
	if visibility != VISIBILITY_PUBLIC:
		return _failure("record visibility is unsupported")
	if not raw.get("targets", []) is Array:
		return _failure("record targets must be an array")
	if not raw.get("payload", {}) is Dictionary:
		return _failure("record payload must be an object")

	var targets: Array = []
	for target_value in raw.get("targets", []):
		var target_result := _prepare_reference(target_value, "target")
		if not bool(target_result.get("ok", false)):
			return target_result
		targets.append(target_result.get("value", {}))

	var payload: Dictionary = raw.get("payload", {})
	if not _is_json_safe(payload):
		return _failure("record payload contains a non-JSON value")
	if category == "roll":
		var roll_error := _validate_roll_payload(payload)
		if not roll_error.is_empty():
			return _failure(roll_error)

	var normalized := {
		"schema_version": SCHEMA_VERSION,
		"id": record_id,
		"sequence": sequence,
		"category": category,
		"kind": kind,
		"targets": targets,
		"title": title,
		"summary": summary,
		"payload": payload.duplicate(true),
		"visibility": VISIBILITY_PUBLIC,
	}
	for optional_key in ["actor", "outcome", "campaign_time", "scene_context"]:
		if not raw.has(optional_key):
			continue
		var optional_value = raw[optional_key]
		if optional_key == "actor":
			var actor_result := _prepare_reference(optional_value, "actor")
			if not bool(actor_result.get("ok", false)):
				return actor_result
			normalized[optional_key] = actor_result.get("value", {})
		elif not optional_value is Dictionary or not _is_json_safe(optional_value):
			return _failure("record %s must be a JSON-safe object" % optional_key)
		else:
			normalized[optional_key] = optional_value.duplicate(true)
	return {"ok": true, "record": normalized, "error": "", "unsupported_future": false}


static func _prepare_reference(value: Variant, label: String) -> Dictionary:
	if not value is Dictionary:
		return _failure("record %s reference is not an object" % label)
	var reference: Dictionary = value
	if not _is_json_safe(reference):
		return _failure("record %s reference contains a non-JSON value" % label)
	var reference_id := str(reference.get("id", "")).strip_edges()
	var display_name := str(reference.get("name", "")).strip_edges()
	if reference_id.is_empty() and display_name.is_empty():
		return _failure("record %s reference has no id or display name" % label)
	var normalized := {"name": display_name}
	if not reference_id.is_empty():
		normalized["id"] = reference_id
	return {"ok": true, "value": normalized, "error": "", "unsupported_future": false}


static func _validate_roll_payload(payload: Dictionary) -> String:
	if str(payload.get("formula", "")).strip_edges().is_empty():
		return "roll payload formula is required"
	if not payload.get("dice_terms", []) is Array:
		return "roll payload dice_terms must be an array"
	if payload.get("dice_terms", []).is_empty():
		return "roll payload needs at least one dice term"
	if not payload.get("modifiers", []) is Array:
		return "roll payload modifiers must be an array"
	if not _is_number(payload.get("natural_total")) or not _is_number(payload.get("final_total")):
		return "roll payload totals must be numeric"
	for term_value in payload.get("dice_terms", []):
		if not term_value is Dictionary:
			return "roll dice term is not an object"
		var term: Dictionary = term_value
		var results = term.get("results", [])
		var kept = term.get("kept", [])
		if int(term.get("count", 0)) <= 0 or int(term.get("sides", 0)) <= 1:
			return "roll dice term count or sides is invalid"
		if str(term.get("label", "")).strip_edges().is_empty():
			return "roll dice term label is required"
		if not results is Array or not kept is Array or results.size() != kept.size() or results.size() != int(term.get("count", 0)):
			return "roll dice count, results, and kept flags must match"
		for result in results:
			if not _is_number(result):
				return "roll die result must be numeric"
		for kept_flag in kept:
			if not kept_flag is bool:
				return "roll kept flag must be boolean"
		if not _is_number(term.get("subtotal")):
			return "roll dice subtotal must be numeric"
	for modifier_value in payload.get("modifiers", []):
		if not modifier_value is Dictionary:
			return "roll modifier is not an object"
		if str(modifier_value.get("label", "")).strip_edges().is_empty() or not _is_number(modifier_value.get("value")):
			return "roll modifier needs a label and numeric value"
	if payload.has("comparison"):
		if not payload["comparison"] is Dictionary or not _is_json_safe(payload["comparison"]):
			return "roll comparison must be a JSON-safe object"
		var comparison: Dictionary = payload["comparison"]
		if str(comparison.get("kind", "")).is_empty() or not _is_number(comparison.get("target")) or not _is_number(comparison.get("margin")) or str(comparison.get("result", "")).is_empty():
			return "roll comparison needs kind, target, margin, and result"
	if payload.has("sections") and not _is_json_safe(payload["sections"]):
		return "roll sections contain a non-JSON value"
	return ""


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _is_json_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for entry in value:
				if not _is_json_safe(entry):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING or not _is_json_safe(value[key]):
					return false
			return true
		_:
			return false


static func _failure(error: String, unsupported_future: bool = false) -> Dictionary:
	return {"ok": false, "record": {}, "error": error, "unsupported_future": unsupported_future}
