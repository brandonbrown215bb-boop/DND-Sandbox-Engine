## Bounded encounter-only action and attack history for authored shared rules.
## Stores the latest event serial per actor, never an unbounded event journal.
class_name CombatActionHistory
extends RefCounted

var current_round := 0
var current_actor_id := ""
var _event_serial := 0
var _turn_serial := 0
var _turn_start_event_serial := 0
var _turn_starts_by_actor: Dictionary = {}
var _owner_turn_start_events: Dictionary = {}
var _last_action_events: Dictionary = {}
var _last_attack_events: Dictionary = {}
var _damage_totals_by_pair: Dictionary = {}
var _combat_turn_damage_start: Dictionary = {}
var _owner_turn_damage_starts: Dictionary = {}
var _last_damage_events: Dictionary = {}


func reset() -> void:
	current_round = 0
	current_actor_id = ""
	_event_serial = 0
	_turn_serial = 0
	_turn_start_event_serial = 0
	_turn_starts_by_actor.clear()
	_owner_turn_start_events.clear()
	_last_action_events.clear()
	_last_attack_events.clear()
	_damage_totals_by_pair.clear()
	_combat_turn_damage_start.clear()
	_owner_turn_damage_starts.clear()
	_last_damage_events.clear()


func begin_turn(actor, round_number: int) -> void:
	var actor_id := _actor_id(actor)
	if actor_id.is_empty():
		return
	# Owner reconnection can resume _start_combat_turn before setup finished.
	# That is still the same initiative turn and must not move history boundaries.
	if current_actor_id == actor_id and current_round == maxi(1, round_number):
		return
	current_actor_id = actor_id
	current_round = maxi(1, round_number)
	_turn_serial += 1
	var starts := int(_turn_starts_by_actor.get(actor_id, 0)) + 1
	_turn_starts_by_actor[actor_id] = starts
	_turn_start_event_serial = _event_serial
	_owner_turn_start_events[actor_id] = _event_serial
	_combat_turn_damage_start = _copy_damage_totals()
	_owner_turn_damage_starts[actor_id] = _copy_damage_totals()


func record_action(actor) -> void:
	var actor_id := _actor_id(actor)
	if actor_id.is_empty():
		return
	_event_serial += 1
	_last_action_events[actor_id] = _event_serial


## A creature scheduling interval advances combat facts without starting a
## removed owner's turn or resetting that owner's history.
func begin_scheduled_interval(round_number: int) -> void:
	current_actor_id = ""
	current_round = maxi(1, round_number)
	_turn_serial += 1
	_turn_start_event_serial = _event_serial
	_combat_turn_damage_start = _copy_damage_totals()


func record_attack(attacker, target) -> void:
	var target_id := _actor_id(target)
	if target_id.is_empty() or _actor_id(attacker).is_empty():
		return
	_event_serial += 1
	_last_attack_events[target_id] = _event_serial


func record_damage(target, source, source_instance_id: String, receipt: Dictionary) -> void:
	var target_id := _actor_id(target)
	var source_id := _actor_id(source)
	if target_id.is_empty() or source_id.is_empty() or source_instance_id.is_empty():
		return
	var pair_key := _damage_pair_key(target_id, source_id, source_instance_id)
	var totals: Dictionary = _damage_totals_by_pair.get(pair_key, _empty_damage_measures()).duplicate(false)
	for measure in _empty_damage_measures():
		totals[measure] = int(totals.get(measure, 0)) + maxi(0, int(receipt.get(measure, 0)))
	_damage_totals_by_pair[pair_key] = totals
	_event_serial += 1
	_last_damage_events[pair_key] = _event_serial


func damage_measure(target, source, source_instance_id: String, measure: String, boundary: String) -> Dictionary:
	var target_id := _actor_id(target)
	var source_id := _actor_id(source)
	if target_id.is_empty() or source_id.is_empty() or source_instance_id.is_empty() or measure not in _empty_damage_measures():
		return {"available": false}
	var baseline: Dictionary
	match boundary:
		"combat_turn":
			if _turn_serial == 0: return {"available": false}
			baseline = _combat_turn_damage_start
		"owner_turn":
			if not _owner_turn_damage_starts.has(target_id): return {"available": false}
			baseline = _owner_turn_damage_starts[target_id]
		_:
			return {"available": false}
	var pair_key := _damage_pair_key(target_id, source_id, source_instance_id)
	var total: Dictionary = _damage_totals_by_pair.get(pair_key, {})
	var prior: Dictionary = baseline.get(pair_key, {})
	return {"available": true, "value": maxi(0, int(total.get(measure, 0)) - int(prior.get(measure, 0)))}


func _copy_damage_totals() -> Dictionary:
	return _damage_totals_by_pair.duplicate(true)


static func _damage_pair_key(target_id: String, source_id: String, source_instance_id: String) -> String:
	return JSON.stringify([target_id, source_id, source_instance_id])


static func _empty_damage_measures() -> Dictionary:
	return {"raw": 0, "prevented": 0, "absorbed": 0, "resolved": 0, "hp_loss": 0}


func fact(actor, name: String, source = null, source_instance_id: String = "") -> Dictionary:
	var actor_id := _actor_id(actor)
	if actor_id.is_empty():
		return {"available": false}
	match name:
		"target.first_round":
			return {"available": current_round > 0, "value": current_round == 1}
		"target.first_own_turn":
			return {"available": _turn_starts_by_actor.has(actor_id), "value": current_actor_id == actor_id and int(_turn_starts_by_actor.get(actor_id, 0)) == 1}
		"target.acted_since_combat_turn":
			return {"available": _turn_serial > 0, "value": int(_last_action_events.get(actor_id, 0)) > _turn_start_event_serial}
		"target.acted_since_owner_turn":
			return {"available": _owner_turn_start_events.has(actor_id), "value": int(_last_action_events.get(actor_id, 0)) > int(_owner_turn_start_events.get(actor_id, 0))}
		"target.attacked_since_combat_turn":
			return {"available": _turn_serial > 0, "value": int(_last_attack_events.get(actor_id, 0)) > _turn_start_event_serial}
		"target.attacked_since_owner_turn":
			return {"available": _owner_turn_start_events.has(actor_id), "value": int(_last_attack_events.get(actor_id, 0)) > int(_owner_turn_start_events.get(actor_id, 0))}
		"target.damage_raw_since_combat_turn", "target.damage_prevented_since_combat_turn", "target.damage_absorbed_since_combat_turn", "target.damage_resolved_since_combat_turn", "target.damage_hp_loss_since_combat_turn":
			return damage_measure(actor, source, source_instance_id, name.trim_prefix("target.damage_").trim_suffix("_since_combat_turn"), "combat_turn")
		"target.damage_raw_since_owner_turn", "target.damage_prevented_since_owner_turn", "target.damage_absorbed_since_owner_turn", "target.damage_resolved_since_owner_turn", "target.damage_hp_loss_since_owner_turn":
			return damage_measure(actor, source, source_instance_id, name.trim_prefix("target.damage_").trim_suffix("_since_owner_turn"), "owner_turn")
	return {"available": false}


static func _actor_id(actor) -> String:
	if actor is Character:
		return actor.character_id
	if actor is Dictionary:
		return str(actor.get("character_id", actor.get("id", "")))
	return ""


static func actor_id(actor) -> String:
	return _actor_id(actor)
