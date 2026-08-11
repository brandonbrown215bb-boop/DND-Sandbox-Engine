## Campaign-scoped, bounded store for immutable player-facing activity records.
extends Node

signal record_published(record: Dictionary)

const ActivityRecordModel = preload("res://src/activity/activity_record.gd")
const STORE_SCHEMA_VERSION := 1
const CAPACITY := 200

var _records: Array[Dictionary] = []
var _next_sequence := 1
var _diagnostics: Array[String] = []
var _notices: Array[String] = []


func clear() -> void:
	_records.clear()
	_next_sequence = 1
	_diagnostics.clear()
	_notices.clear()


func publish(draft: Dictionary) -> Dictionary:
	var candidate := draft.duplicate(true)
	candidate["schema_version"] = ActivityRecordModel.SCHEMA_VERSION
	candidate["sequence"] = _next_sequence
	candidate["id"] = "activity-%06d" % _next_sequence
	var prepared := ActivityRecordModel.prepare(candidate)
	if not bool(prepared.get("ok", false)):
		var message := "publication rejected: %s" % str(prepared.get("error", "invalid record"))
		_diagnostics.append(message)
		push_warning("[ActivityHistory] %s" % message)
		return {}
	var record: Dictionary = prepared.get("record", {}).duplicate(true)
	_records.append(record)
	_next_sequence += 1
	while _records.size() > CAPACITY:
		_records.pop_front()
	var published := record.duplicate(true)
	record_published.emit(published)
	return published


func get_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in _records:
		result.append(record.duplicate(true))
	return result


func get_next_sequence() -> int:
	return _next_sequence


func get_diagnostics() -> Array[String]:
	return _diagnostics.duplicate()


func get_notices() -> Array[String]:
	return _notices.duplicate()


func serialize() -> Dictionary:
	return {
		"schema_version": STORE_SCHEMA_VERSION,
		"next_sequence": _next_sequence,
		"records": get_records(),
	}


## Parse without mutating the active campaign. SaveManager calls this before
## applying any loaded manager state, preserving its transactional boundary.
func prepare_snapshot(value: Variant) -> Dictionary:
	var prepared_records: Array[Dictionary] = []
	var diagnostics: Array[String] = []
	var notices: Array[String] = []
	if value == null or (value is Dictionary and value.is_empty()):
		return _prepared_snapshot(prepared_records, 1, diagnostics, notices)
	if not value is Dictionary:
		diagnostics.append("activity history is not an object")
		notices.append("Some activity history could not be loaded.")
		return _prepared_snapshot(prepared_records, 1, diagnostics, notices)

	var snapshot: Dictionary = value
	var store_version := int(snapshot.get("schema_version", 0))
	if store_version > STORE_SCHEMA_VERSION:
		diagnostics.append("unsupported future activity store version %d" % store_version)
		notices.append("Activity history was created by a newer game version and was omitted.")
		return _prepared_snapshot(prepared_records, 1, diagnostics, notices)
	if store_version != STORE_SCHEMA_VERSION:
		diagnostics.append("unsupported activity store version %d" % store_version)
		notices.append("Some activity history could not be loaded.")
		return _prepared_snapshot(prepared_records, 1, diagnostics, notices)
	if not snapshot.get("records", []) is Array:
		diagnostics.append("activity records are not an array")
		notices.append("Some activity history could not be loaded.")
		return _prepared_snapshot(prepared_records, 1, diagnostics, notices)

	var seen_ids: Dictionary = {}
	var seen_sequences: Dictionary = {}
	var source_records: Array = snapshot.get("records", [])
	for index in source_records.size():
		var result := ActivityRecordModel.prepare(source_records[index])
		if not bool(result.get("ok", false)):
			diagnostics.append("activity record %d skipped: %s" % [index, str(result.get("error", "invalid record"))])
			if bool(result.get("unsupported_future", false)):
				notices.append("Activity from a newer game version was omitted.")
			continue
		var record: Dictionary = result.get("record", {})
		var record_id := str(record.get("id", ""))
		var sequence := int(record.get("sequence", 0))
		if seen_ids.has(record_id) or seen_sequences.has(sequence):
			diagnostics.append("activity record %d skipped: duplicate id or sequence" % index)
			continue
		seen_ids[record_id] = true
		seen_sequences[sequence] = true
		prepared_records.append(record.duplicate(true))

	prepared_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("sequence", 0)) < int(b.get("sequence", 0)))
	if prepared_records.size() > CAPACITY:
		prepared_records = prepared_records.slice(prepared_records.size() - CAPACITY)
	var highest_sequence := 0
	if not prepared_records.is_empty():
		highest_sequence = int(prepared_records.back().get("sequence", 0))
	var next_sequence := maxi(int(snapshot.get("next_sequence", 1)), highest_sequence + 1)
	if not diagnostics.is_empty() and notices.is_empty():
		notices.append("Some activity history could not be loaded.")
	return _prepared_snapshot(prepared_records, next_sequence, diagnostics, notices)


func apply_prepared_snapshot(snapshot: Dictionary) -> void:
	_records.clear()
	for record_value in snapshot.get("records", []):
		if record_value is Dictionary:
			_records.append(record_value.duplicate(true))
	_next_sequence = maxi(1, int(snapshot.get("next_sequence", 1)))
	_diagnostics.assign(_string_array(snapshot.get("diagnostics", [])))
	_notices.assign(_deduplicated_strings(snapshot.get("notices", [])))
	for diagnostic in _diagnostics:
		push_warning("[ActivityHistory] %s" % diagnostic)


func _prepared_snapshot(records: Array[Dictionary], next_sequence: int, diagnostics: Array[String], notices: Array[String]) -> Dictionary:
	return {
		"records": records,
		"next_sequence": maxi(1, next_sequence),
		"diagnostics": diagnostics,
		"notices": _deduplicated_strings(notices),
	}


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(str(entry))
	return result


func _deduplicated_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for entry in _string_array(value):
		if entry not in result:
			result.append(entry)
	return result
