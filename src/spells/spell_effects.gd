## Bounded lifetime/ownership for the first shared condition-spell batch.
## Existing class conditions and other spell handlers keep their current paths.
class_name SpellEffects
extends RefCounted

const MANAGED_SPELLS := ["bless", "bane", "jump", "fly", "levitate", "spider_climb", "freedom_of_movement", "water_walk", "aid", "alter_self", "barkskin", "mage_armor", "hold_monster", "ray_of_sickness", "animal_friendship", "charm_person", "charm_monster", "power_word_stun", "blindness/deafness", "sunburst", "beacon_of_hope", "divine_favor", "death_ward", "sanctuary", "heroism", "magic_weapon", "enhance_ability", "faerie_fire", "invisibility", "darkvision", "see_invisibility", "true_seeing", "detect_magic", "blur", "detect_evil_and_good", "detect_poison_and_disease", "identify", "goodberry"]
const PERSISTED_AREA_MARKER_SPELLS := ["fog_cloud", "darkness", "black_tentacles", "antilife_shell", "spike_growth", "entangle", "cloud_of_daggers", "sleet_storm", "moonbeam", "wall_of_fire", "animate_objects"]
static var _source_end_events: Array[Dictionary] = []
static var _repeat_save_turn_locks: Dictionary = {}
static var _repeat_save_turn_serial := -1

static func manages(spell: Dictionary) -> bool:
	if spell.has("execution"):
		return SharedSpell.manages(spell)
	return str(spell.get("id", "")) in MANAGED_SPELLS

static func caster_id(caster: Character) -> String:
	return caster.character_id if not caster.character_id.is_empty() else "runtime_%d" % caster.get_instance_id()

static func is_spell_source(source_id: String) -> bool:
	if source_id.begins_with("spell:"):
		return true
	var spell_id := source_id.get_slice(":", 0)
	return not spell_id.is_empty() and not DataLoader.get_spell(spell_id).is_empty()

static func parse_duration_seconds(spell_or_duration) -> int:
	if spell_or_duration is Dictionary:
		if spell_or_duration.has("duration_seconds"):
			return int(spell_or_duration["duration_seconds"])
		return parse_duration_seconds(spell_or_duration.get("duration", 60))
	if spell_or_duration is int or spell_or_duration is float:
		return int(spell_or_duration)
	if not spell_or_duration is String:
		return 60
	var text: String = spell_or_duration.to_lower().strip_edges()
	if text.begins_with("concentration, up to "):
		text = text.trim_prefix("concentration, up to ").strip_edges()
	elif text.begins_with("concentration, "):
		text = text.trim_prefix("concentration, ").strip_edges()
	elif text.begins_with("up to "):
		text = text.trim_prefix("up to ").strip_edges()
	if text == "instantaneous":
		return 0
	if text.begins_with("until dispelled") or text == "special":
		return -1
	if text == "instantaneous or up to 1 hour":
		return 3600
	var parts := text.split(" ")
	if parts.size() >= 2:
		var count := int(parts[0])
		var unit := parts[1]
		if unit.begins_with("round"):
			return count * 6
		elif unit.begins_with("minute"):
			return count * 60
		elif unit.begins_with("hour"):
			return count * 3600
		elif unit.begins_with("day"):
			return count * 86400
	return 60


static func begin_cast(caster: Character, spell: Dictionary, cast_facts: Dictionary = {}) -> Dictionary:
	caster.spell_cast_serial += 1
	var owner := caster_id(caster)
	var spell_id := str(spell.get("id", ""))
	var duration := parse_duration_seconds(spell)
	if spell_id == "power_word_stun":
		duration = -1
	elif spell_id == "identify":
		duration = int(spell.get("cast_time_seconds", 60))
	var expiry_phase := "target_end" if spell_id == "sunburst" else "start"
	var record := {"source_id": "spell:%s:%d" % [owner, caster.spell_cast_serial], "caster_id": owner, "spell_id": spell_id, "remaining_seconds": duration, "expiry_phase": expiry_phase, "save_dc": SpellPermissionRules.save_dc(caster, spell), "concentration": bool(spell.get("concentration", false)), "end_on_target_damage": bool(spell.get("end_on_target_damage", spell.get("end_on_party_damage", false))), "end_on_any_damage": bool(spell.get("end_on_any_damage", false)), "conditions": []}
	if SharedSpell.uses(spell) and spell.has("repeat_save"):
		var schedule := str(spell.get("repeat_save_schedule", "target_turn_end"))
		record["repeat_save_schedule"] = schedule
		record["repeat_save_attempts"] = 0
		record["repeat_save_dc_adjustment"] = 0
		record["repeat_save_stage_index"] = 0
		record["repeat_save_stage_successes"] = 0
		record["repeat_save_context"] = spell.get("save_context", {}).duplicate(true)
		record["repeat_save_purpose"] = str(spell.get("save_context", {}).get("purpose_id", "repeat_save"))
		if schedule == "elapsed_seconds":
			record["repeat_save_next_at_seconds"] = int(GameManager.campaign_elapsed_seconds) + int(spell.get("repeat_save_interval_seconds", 1))
		if spell.has("repeat_save_stages"): record["repeat_save_stages"] = spell["repeat_save_stages"].duplicate(true)
		if spell.has("repeat_save_dc_progression"): record["repeat_save_dc_progression"] = spell["repeat_save_dc_progression"].duplicate(true)
	var rules: Variant = spell.get("source_end_rules", [])
	if rules is Array and not rules.is_empty():
		record["source_end_rules"] = rules.duplicate(true)
		if rules.any(func(rule): return rule is Dictionary and rule.has("damage_budget")):
			record["damage_budget_total"] = 0
	var aftermath: Variant = spell.get("end_aftermath", [])
	if aftermath is Array and not aftermath.is_empty(): record["end_aftermath"] = aftermath.duplicate(true)
	if spell.has("_duration_slot_level"): record["duration_slot_level"] = int(spell["_duration_slot_level"])
	if bool(spell.get("_until_dispelled", false)):
		record["remaining_seconds"] = -1
		record["until_dispelled"] = true
	if not cast_facts.is_empty(): record["cast_facts"] = cast_facts.duplicate(true)
	return record

static func records(target) -> Dictionary:
	return target.spell_effects if target is Character else target.get("spell_effects", {})

static func grant(target, cast: Dictionary, condition: String, expiry_phase: String = "start", seconds: int = -1) -> void:
	if target == null or condition.is_empty():
		return
	var source := str(cast["source_id"])
	var previous: Dictionary = records(target).get(source, {})
	var record: Dictionary = previous.duplicate(true) if not previous.is_empty() else cast.duplicate(true)
	record["recipient_id"] = caster_id(target) if target is Character else str(target.get("id", "")) if target is Dictionary else ""
	record["expiry_phase"] = expiry_phase
	if seconds >= 0:
		record["remaining_seconds"] = seconds
	var grants: Array = record.get("conditions", [])
	if condition not in grants:
		grants.append(condition)
	record["conditions"] = grants
	# Applying a condition can synchronously refresh combat and reconcile sources
	# (including when the recipient was already unconscious). Publish the source
	# first so that refresh sees its exact grant instead of empty Concentration.
	var all_records := records(target)
	all_records[source] = record
	if target is Dictionary:
		target["spell_effects"] = all_records
	CombatAction.apply_condition(target, condition, -1 if bool(record.get("until_dispelled", false)) else maxi(1, int(ceil(float(record["remaining_seconds"]) / 6.0))), source)
	if not has_grant(target, source, condition) or not CombatAction.has_condition(target, condition):
		if has_grant(target, source, condition):
			CombatAction.remove_condition_source(target, source, [condition])
		# Refusal must leave no speculative timer or discard an existing sibling.
		# A callback may have legitimately removed/replaced this source; retain that
		# decision rather than restoring it after concentration has ended.
		if is_same(records(target).get(source), record):
			if previous.is_empty(): records(target).erase(source)
			else: records(target)[source] = previous

static func grant_aid(target: Character, cast: Dictionary, amount: int) -> bool:
	return SpellEffectBenefits.grant_aid(target, cast, amount)




static func grant_barkskin(target, cast: Dictionary, ac_floor: int = 17) -> bool:
	return SpellEffectBenefits.grant_barkskin(target, cast, ac_floor)




static func grant_beacon_of_hope(target, cast: Dictionary) -> bool:
	return SpellEffectBenefits.grant_beacon_of_hope(target, cast)




static func grant_divine_favor(caster: Character, cast: Dictionary) -> bool:
	return SpellEffectBenefits.grant_divine_favor(caster, cast)




static func grant_death_ward(target, cast: Dictionary) -> bool:
	return SpellEffectBenefits.grant_death_ward(target, cast)




static func grant_goodberries(caster: Character, cast: Dictionary, count: int) -> bool:
	return SpellEffectBenefits.grant_goodberries(caster, cast, count)




static func goodberry_count(caster: Character) -> int:
	return SpellEffectBenefits.goodberry_count(caster)




static func goodberry_count_for_party(casters: Array) -> int:
	return SpellEffectBenefits.goodberry_count_for_party(casters)




static func consume_goodberry_from_party(casters: Array) -> bool:
	return SpellEffectBenefits.consume_goodberry_from_party(casters)




static func grant_sanctuary(target, cast: Dictionary) -> bool:
	return SpellEffectBenefits.grant_sanctuary(target, cast)




static func grant_heroism(target: Character, cast: Dictionary, temporary_hp: int) -> bool:
	return SpellEffectBenefits.grant_heroism(target, cast, temporary_hp)




static func apply_turn_start(target) -> void:
	SpellEffectBenefits.apply_turn_start(target)




static func grant_enhance_ability(target, cast: Dictionary, ability: String) -> bool:
	return SpellEffectBenefits.grant_enhance_ability(target, cast, ability)




static func has_enhance_ability_advantage(target, ability: String) -> bool:
	return SpellEffectBenefits.has_enhance_ability_advantage(target, ability)




static func grant_magic_weapon(target: Character, cast: Dictionary, weapon_id: String, bonus: int) -> bool:
	return SpellEffectBenefits.grant_magic_weapon(target, cast, weapon_id, bonus)




static func magic_weapon_bonus(target, weapon_id: String) -> int:
	return SpellEffectBenefits.magic_weapon_bonus(target, weapon_id)




static func consume_spell(target, spell_id: String, end_reason: String = "consumed", cause: Dictionary = {}) -> void:
	for source in records(target).keys().duplicate():
		if str(records(target)[source].get("spell_id", "")) == spell_id:
			remove(target, str(source), end_reason, cause)


static func maximize_healing(target, rolled_amount: int, maximum_amount: int) -> int:
	return SpellEffectBenefits.maximize_healing(target, rolled_amount, maximum_amount)




static func effective_ac(target, base_ac: int) -> int:
	return SpellEffectBenefits.effective_ac(target, base_ac)




static func end_mage_armor_if_armored(target) -> void:
	SpellEffectBenefits.end_mage_armor_if_armored(target)



static func has_grant(target, source: String, condition: String) -> bool:
	var sources: Dictionary = target.condition_sources if target is Character else target.get("condition_sources", {})
	return sources.get(condition, {}).has(source)

static func remove(target, source: String, end_reason: String = "source_removed", cause: Dictionary = {}) -> Dictionary:
	if target is Character:
		TetherRules.end_source(target, source, end_reason, cause)
		TetherRules.end_victim_source(target, source)
	var all_records := records(target)
	if not all_records.has(source):
		return {}
	var record: Dictionary = all_records[source].duplicate(true)
	record["source_id"] = source
	var event := LocatedSourceEndRules.capture(target, record, end_reason, cause)
	if target is Character and record.has("created_actors"):
		CreatedActorRules.end_source(target, record, end_reason, cause)
	CombatAction.remove_condition_source(target, source, record.get("conditions", []))
	if record.has("max_hp_source"): event["max_hp_source"] = MaxHpSourceRules.remove(target, source, end_reason)
	var aid_bonus := maxi(0, int(record.get("aid_hp_bonus", 0)))
	if aid_bonus > 0 and target is Character:
		target.max_hp = maxi(1, target.max_hp - aid_bonus)
		target.current_hp = mini(target.current_hp, target.max_hp)
	var projection_receipt := ActorProjectionRules.revert(target, record) if record.has("projection") else {}
	all_records.erase(source)
	if not projection_receipt.is_empty(): event["projection"] = projection_receipt
	if target is Dictionary:
		target["spell_effects"] = all_records
		if not has_spell(target, "animal_friendship"):
			target.erase("animal_friendship_caster_ids")
	# S-086: the one final end event fires only its reason-matched follow-ups.
	finish_source_end(target, event)
	return event

## Shared final-event publication for spell removal and supported mode endings.
static func finish_source_end(target, event: Dictionary) -> void:
	event["aftermath"] = SourceEndAftermathRules.fire(target, event.record, event)
	LocatedSourceEndRules.enqueue(event)
	_source_end_events.append(event.duplicate(true))
	while _source_end_events.size() > 128: _source_end_events.pop_front()

static func source_end_events() -> Array[Dictionary]:
	return _source_end_events.duplicate(true)

static func clear_source_end_events() -> void:
	_source_end_events.clear()

## Evaluate source-owned termination rules against a canonical completed event.
## A matching event ends each source at most once; unrelated records are retained.
static func publish_event(target, event: Dictionary) -> Array[Dictionary]:
	var ended: Array[Dictionary] = []
	if target == null or str(event.get("type", "")).is_empty(): return ended
	if str(event.get("type", "")) == "cast" and not bool(event.get("completed", false)): return ended
	if event.get("type", "") == "movement" and event.get("from") != event.get("to"):
		CombatPerception.invalidate_hidden_location(target)
	var canonical_event := event.duplicate(true)
	canonical_event["subject_id"] = caster_id(target) if target is Character else str(target.get("id", "")) if target is Dictionary else ""
	for source in records(target).keys().duplicate():
		var record: Dictionary = records(target).get(source, {})
		var matching := _matching_end_rule(record, canonical_event)
		if matching.is_empty(): continue
		var reason := str(event.get("type", "event"))
		var end_event := remove(target, str(source), reason, canonical_event)
		if not end_event.is_empty(): ended.append(end_event)
	return ended


## Count final damage for the exact source record. The settled hit remains full;
## reaching the authored cap ends the source after that hit.
static func damage_budget_cap(definition: Dictionary) -> int:
	var rules: Variant = definition.get("source_end_rules", [])
	if not rules is Array: return 0
	for rule in rules:
		if rule is Dictionary and str(rule.get("event", "")) == "damage" and rule.has("damage_budget"): return int(rule.damage_budget)
	return 0

## A retained budget can acquire another payload without resetting its counter.
static func can_add_budget_payload(actor: Character, cast: Dictionary, payload: String) -> bool:
	var record: Dictionary = actor.spell_effects.get(str(cast.get("source_id", "")), {})
	return record.has("damage_budget_total") and not record.has(payload) and record.get("caster_id") == cast.get("caster_id") and record.get("spell_id") == cast.get("spell_id")

static func payload_record(actor: Character, cast: Dictionary) -> Dictionary:
	return actor.spell_effects.get(str(cast.get("source_id", "")), cast).duplicate(true)

static func start_damage_budget(caster: Character, cast: Dictionary) -> void:
	if damage_budget_cap(cast) <= 0: return
	var source := str(cast.get("source_id", ""))
	if not source.is_empty() and not caster.spell_effects.has(source): caster.spell_effects[source] = cast.duplicate(true)

static func record_damage_budget(source, source_instance_id: String, amount: int, target_actor_id: String = "", recipients: Array = []) -> Array[Dictionary]:
	var ended: Array[Dictionary] = []
	if source == null or source_instance_id.is_empty() or amount <= 0: return ended
	var record: Dictionary = records(source).get(source_instance_id, {})
	if record.is_empty(): return ended
	var cap := 0
	for rule in record.get("source_end_rules", []):
		if rule is Dictionary and str(rule.get("event", "")) == "damage" and rule.has("damage_budget"):
			cap = int(rule.get("damage_budget", 0))
			break
	if cap <= 0: return ended
	record["damage_budget_total"] = int(record.get("damage_budget_total", 0)) + amount
	if source is Dictionary: source["spell_effects"] = records(source)
	if int(record["damage_budget_total"]) >= cap:
		var event := remove(source, source_instance_id, "damage_budget", {"source_instance_id": source_instance_id, "target_actor_id": target_actor_id, "damage_budget_total": int(record["damage_budget_total"]), "damage_budget_cap": cap})
		if not event.is_empty(): ended.append(event)
		var linked := recipients.duplicate()
		linked.append_array(PartyManager.characters.values())
		if source is Character:
			linked.append_array(source.concentrating_on.get("targets", []))
			if str(source.concentrating_on.get("effect_source", "")) == source_instance_id: source.concentrating_on.clear()
		for recipient in linked:
			if recipient != null and not is_same(recipient, source): remove(recipient, source_instance_id, "damage_budget", {"source_instance_id": source_instance_id})
	return ended

static func _matching_end_rule(record: Dictionary, event: Dictionary) -> Dictionary:
	var rules: Variant = record.get("source_end_rules", [])
	if not rules is Array: return {}
	for rule in rules:
		if not rule is Dictionary or str(rule.get("event", "")) != str(event.get("type", "")): continue
		if event.has("range_source_id") and str(event.get("range_source_id", "")) != str(record.get("source_id", "")): continue
		var actor_scope := str(rule.get("actor", "any"))
		var actor_id := str(event.get("actor_id", ""))
		if actor_scope == "caster" and actor_id != str(record.get("caster_id", "")): continue
		if actor_scope == "recipient" and actor_id != str(event.get("subject_id", "")): continue
		if rule.has("school") and str(rule.get("school", "")) != str(event.get("school", "")): continue
		if rule.has("spell_id") and str(rule.get("spell_id", "")) != str(event.get("spell_id", "")): continue
		if rule.has("action") and str(rule.get("action", "")) != str(event.get("action", "")): continue
		if rule.has("status") and str(rule.get("status", "")) != str(event.get("status", "")): continue
		if rule.has("equipment") and str(rule.get("equipment", "")) != str(event.get("equipment", "")): continue
		if rule.has("state") and str(rule.get("state", "")) != str(event.get("state", "")): continue
		if rule.has("paid_slot_level") and int(rule.get("paid_slot_level", -1)) != int(event.get("paid_slot_level", -1)): continue
		if rule.has("maximum_range_feet") and (not event.has("distance_feet") or int(event.get("distance_feet", -1)) <= int(rule.get("maximum_range_feet", -1))): continue
		if rule.has("damage_budget") and int(record.get("damage_budget_total", 0)) < int(rule.get("damage_budget", 0)): continue
		var except_source := str(rule.get("except_source_id", ""))
		if except_source == "this_source": except_source = str(record.get("source_id", ""))
		if str(event.get("type", "")) == "damage" and not except_source.is_empty() and except_source == str(event.get("source_instance_id", "")): continue
		return rule
	return {}

static func _has_end_rule_for_event(record: Dictionary, event_type: String) -> bool:
	var rules: Variant = record.get("source_end_rules", [])
	if not rules is Array: return false
	for rule in rules:
		if rule is Dictionary and str(rule.get("event", "")) == event_type: return true
	return false

static func has_spell(target, spell_id: String) -> bool:
	for record in records(target).values():
		if str(record.get("spell_id", "")) == spell_id:
			return true
	return false

static func _advance(target, source: String, seconds: int) -> void:
	var record: Dictionary = records(target)[source]
	if int(record.get("remaining_seconds", 0)) < 0:
		return # Repeat-save spells can persist until their own rules end the grant.
	var remaining := int(record["remaining_seconds"]) - seconds
	if remaining <= 0:
		var before := int(record["remaining_seconds"])
		record["remaining_seconds"] = 0
		remove(target, source, "expired", {"remaining_before": before, "elapsed_seconds": seconds})
		return
	record["remaining_seconds"] = remaining
	var sources: Dictionary = target.condition_sources if target is Character else target.get("condition_sources", {})
	var conditions: Dictionary = target.conditions if target is Character else target.get("conditions", {})
	for condition in record["conditions"]:
		if not has_grant(target, source, str(condition)):
			continue
		sources[condition][source] = maxi(1, int(ceil(float(remaining) / 6.0)))
		conditions[condition] = int(sources[condition].values().max())

static func repeat_save_schedule(target, source: String) -> String:
	var record: Dictionary = records(target).get(source, {})
	var spell := DataLoader.get_spell(str(record.get("spell_id", "")))
	if not SharedSpell.uses(spell) or not spell.has("repeat_save"): return ""
	return str(record.get("repeat_save_schedule", spell.get("repeat_save_schedule", "target_turn_end")))

## A final repeat-save stage (e.g. a second failure's lasting condition) asks for no more saves.
static func repeat_save_stage_final(target, source: String) -> bool:
	var record: Dictionary = records(target).get(source, {})
	var stages: Array = record.get("repeat_save_stages", [])
	return not stages.is_empty() and bool(stages[clampi(int(record.get("repeat_save_stage_index", 0)), 0, stages.size() - 1)].get("final", false))

static func repeat_save_due(target, source: String, schedule: String, now_seconds: int = -1) -> bool:
	if repeat_save_schedule(target, source) != schedule: return false
	var record: Dictionary = records(target).get(source, {})
	if repeat_save_stage_final(target, source): return false
	if schedule == "target_turn_end": return true
	if schedule == "elapsed_seconds": return now_seconds >= 0 and now_seconds >= int(record.get("repeat_save_next_at_seconds", 2147483647))
	return false

static func claim_target_turn_repeat_save(target, source: String, turn_serial: int) -> bool:
	if not repeat_save_due(target, source, "target_turn_end"): return false
	if turn_serial != _repeat_save_turn_serial:
		_repeat_save_turn_locks.clear()
		_repeat_save_turn_serial = turn_serial
	var recipient_id := caster_id(target) if target is Character else str(target.get("id", "")) if target is Dictionary else ""
	var key := "%s|%s|%d" % [str(source), recipient_id, turn_serial]
	if _repeat_save_turn_locks.has(key): return false
	_repeat_save_turn_locks[key] = true
	return true

static func record_shared_repeat_save(target, source: String, saved: bool, total: int, dc: int) -> Dictionary:
	var all_records := records(target)
	if not all_records.has(source): return {"success": false}
	var record: Dictionary = all_records[source]
	var spell := DataLoader.get_spell(str(record.get("spell_id", "")))
	var attempts := int(record.get("repeat_save_attempts", 0)) + 1
	record["repeat_save_attempts"] = attempts
	var progression: Dictionary = spell.get("repeat_save_dc_progression", {})
	if not progression.is_empty():
		if saved and bool(progression.get("reset_on_success", false)):
			record["repeat_save_dc_adjustment"] = 0
		elif str(progression.get("increase_on", "failure")) == "attempt" or not saved:
			record["repeat_save_dc_adjustment"] = mini(int(progression.get("maximum", 0)), int(record.get("repeat_save_dc_adjustment", 0)) + int(progression.get("amount", 0)))
	var stages: Array = record.get("repeat_save_stages", [])
	if not stages.is_empty():
		var stage_index := clampi(int(record.get("repeat_save_stage_index", 0)), 0, stages.size() - 1)
		var stage: Dictionary = stages[stage_index]
		if bool(stage.get("final", false)): return {"success": false}
		var margin := total - dc
		var route := "stay"
		if saved and margin >= int(stage.get("minimum_margin", 0)):
			var qualified := int(record.get("repeat_save_stage_successes", 0)) + 1
			record["repeat_save_stage_successes"] = qualified
			if qualified >= int(stage.get("successes_required", 1)): route = str(stage.get("on_success", "advance"))
		elif not saved:
			route = str(stage.get("on_failure", "stay"))
			if bool(stage.get("reset_successes_on_failure", false)): record["repeat_save_stage_successes"] = 0
		if route == "end":
			remove(target, source, "repeat_save_stage_ended", {"attempt": attempts, "saved": saved, "total": total, "dc": dc, "stage_index": stage_index})
			return {"success": true, "ended": true, "attempt": attempts, "stage_index": stage_index}
		if route == "advance":
			var old_conditions: Array = record.get("conditions", []).duplicate()
			CombatAction.remove_condition_source(target, source, old_conditions)
			var next_index := stage_index + 1
			if next_index >= stages.size():
				remove(target, source, "repeat_save_stages_completed", {"attempt": attempts, "saved": saved, "total": total, "dc": dc, "stage_index": stage_index})
				return {"success": true, "ended": true, "attempt": attempts, "stage_index": stage_index}
			record["repeat_save_stage_index"] = next_index
			record["repeat_save_stage_successes"] = 0
			record["conditions"] = []
			all_records[source] = record
			grant(target, record, str(stages[next_index]["condition"]))
		if target is Dictionary: target["spell_effects"] = all_records
		return {"success": true, "attempt": attempts, "stage_index": int(record.get("repeat_save_stage_index", 0)), "stage_successes": int(record.get("repeat_save_stage_successes", 0)), "dc_adjustment": int(record.get("repeat_save_dc_adjustment", 0))}
	if saved:
		remove(target, source, "repeat_save_succeeded", {"attempt": attempts, "total": total, "dc": dc})
	return {"success": true, "attempt": attempts, "dc_adjustment": int(record.get("repeat_save_dc_adjustment", 0))}

static func tick_boundary(targets: Array, owner: String, phase: String) -> void:
	for target in targets:
		for source in records(target).keys():
			var record: Dictionary = records(target)[source]
			if str(record["caster_id"]) == owner and str(record["expiry_phase"]) == phase:
				_advance(target, str(source), 6)
			# Recipient-relative expiry ("until the start/end of its next turn").
			elif str(record.get("recipient_id", "")) == owner and str(record["expiry_phase"]) == "recipient_" + phase and records(target).has(source):
				_advance(target, str(source), 6)

## Authored magnitude for a source-owned condition (e.g. speed_reduced hexes).
static func set_condition_amount(target, cast: Dictionary, condition: String, amount: int) -> void:
	var source := str(cast.get("source_id", ""))
	if not records(target).has(source) or not has_grant(target, source, condition): return
	var amounts: Dictionary = records(target)[source].get("condition_amounts", {})
	amounts[condition] = amount
	records(target)[source]["condition_amounts"] = amounts

## Sum of live granted magnitudes; sources of the same spell do not stack (largest wins per spell).
static func condition_amount(target, condition: String) -> int:
	if target == null: return 0
	var by_spell := {}
	for source in records(target):
		var record: Dictionary = records(target)[source]
		if not has_grant(target, str(source), condition): continue
		var key := str(record.get("spell_id", source))
		by_spell[key] = maxi(int(by_spell.get(key, 0)), int(record.get("condition_amounts", {}).get(condition, 0)))
	var total := 0
	for value in by_spell.values(): total += int(value)
	return total

## Consume every source of a once-only condition after its triggering roll.
static func consume_condition(target, condition: String) -> void:
	for source in records(target).keys():
		if has_grant(target, str(source), condition):
			CombatAction.remove_condition_source(target, str(source), [condition])
	prune(target)

static func advance_time(targets: Array, elapsed_seconds: int) -> void:
	if elapsed_seconds <= 0:
		return
	var final_seconds := int(GameManager.campaign_elapsed_seconds)
	var cursor := final_seconds - elapsed_seconds
	var casters: Array = targets.filter(func(target): return target is Character)
	GameManager.campaign_elapsed_seconds = cursor
	reconcile(casters, targets)
	# An overdue retained deadline resolves at the start without negative aging.
	resolve_elapsed_repeat_saves(targets, cursor)
	while cursor < final_seconds:
		var boundary := final_seconds
		for actor in casters:
			for mode in actor.feature_modes.values():
				if bool(mode.get("active", false)) and int(mode.get("remaining_seconds", 0)) > 0:
					boundary = mini(boundary, cursor + int(mode.remaining_seconds))
		for target in targets:
			for source in records(target):
				var record: Dictionary = records(target)[source]
				var remaining := int(record.get("remaining_seconds", -1))
				if remaining > 0: boundary = mini(boundary, cursor + remaining)
				if repeat_save_schedule(target, str(source)) == "elapsed_seconds":
					var next_at := int(record.get("repeat_save_next_at_seconds", final_seconds))
					if next_at > cursor: boundary = mini(boundary, next_at)
		GameManager.campaign_elapsed_seconds = boundary
		for actor in casters: FeatureModeRules.advance_time(actor, boundary - cursor)
		for target in targets:
			for source in records(target).keys():
				if records(target).has(source): _advance(target, str(source), boundary - cursor)
		cursor = boundary
		# Expiry wins a tie with a save. All targets age before any due save,
		# so expired save benefits and lost concentration cannot affect it.
		reconcile(casters, targets)
		resolve_elapsed_repeat_saves(targets, cursor)
	GameManager.campaign_elapsed_seconds = final_seconds
	reconcile(casters, targets)

static func resolve_elapsed_repeat_saves(targets: Array, now_seconds: int) -> void:
	for target in targets:
		for source in records(target).keys().duplicate():
			var source_id := str(source)
			if repeat_save_due(target, source_id, "elapsed_seconds", now_seconds):
				var record: Dictionary = records(target).get(source_id, {})
				var spell := DataLoader.get_spell(str(record.get("spell_id", "")))
				var interval := maxi(1, int(spell.get("repeat_save_interval_seconds", 1)))
				while records(target).has(source_id) and int(records(target)[source_id].get("repeat_save_next_at_seconds", 0)) <= now_seconds:
					var next_at := int(records(target)[source_id].get("repeat_save_next_at_seconds", now_seconds))
					var result := CombatAction.resolve_condition_spell_repeat_save(target, source_id)
					if not result.get("success", false): break
					if records(target).has(source_id): records(target)[source_id]["repeat_save_next_at_seconds"] = next_at + interval

static func end_concentration(caster: Character, targets: Array) -> bool:
	AnimatedObjectRules.end_source(caster.character_id, str(caster.concentrating_on.get("effect_source", "")))
	GameManager.clear_room_area_concentration(caster)
	var source := str(caster.concentrating_on.get("effect_source", ""))
	if source.is_empty():
		return false
	if caster.spell_effects.has(source) and not bool(caster.spell_effects[source].get("concentration", true)):
		caster.concentrating_on.clear()
		return true
	var recipients := targets.duplicate()
	for target in caster.concentrating_on.get("targets", []):
		if target not in recipients: recipients.append(target)
	# The caster's own source never needs a strong self-reference in targets.
	remove(caster, source, "concentration_ended", {"caster_id": caster_id(caster)})
	for target in recipients:
		if not target is Character or target != caster: remove(target, source, "concentration_ended", {"caster_id": caster_id(caster)})
	caster.concentrating_on.clear()
	return true

## Rebuild live references from stable source IDs; only this batch is managed.
static func prune(target) -> void:
	for source in records(target).keys():
		var record: Dictionary = records(target)[source]
		if record.has("damage_budget_total") or record.has("source_benefits") or record.has("damage_link") or record.has("damage_response") or record.has("created_actors") or record.has("projection") or record.has("magic_suppression") or record.has("max_hp_source"):
			continue # These exact source records own non-condition behavior.
		if str(record.get("spell_id", "")) in ["beacon_of_hope", "divine_favor", "death_ward", "sanctuary", "heroism", "magic_weapon", "enhance_ability"]:
			continue # This benefit is represented by the source record, not a condition.
		if str(record.get("spell_id", "")) == "identify" and record.has("identify_target"):
			continue # This record tracks concentration during its one-minute casting.
		if str(record.get("spell_id", "")) in PERSISTED_AREA_MARKER_SPELLS and bool(record.get("concentration", false)) and record["conditions"].is_empty():
			continue # The saved source marker owns a transferred area zone.
		if str(record.get("spell_id", "")) == "goodberry" and int(record.get("berries_remaining", 0)) > 0:
			continue # Remaining berries are tracked on their owning spell record.
		if str(record.get("spell_id", "")) == "aid" and int(record.get("aid_hp_bonus", 0)) > 0:
			continue
		record["conditions"] = record["conditions"].filter(func(condition): return has_grant(target, str(source), str(condition)))

		if record["conditions"].is_empty() and not record.has("aid_hp_bonus") and not record.has("ac_floor"):
			remove(target, str(source))

static func reconcile(casters: Array, targets: Array) -> void:
	var owners: Dictionary = {}
	for caster: Character in casters:
		owners[caster_id(caster)] = caster
	for target in targets:
		prune(target)
		for source in records(target).keys():
			var record: Dictionary = records(target)[source]
			var owner: Character = owners.get(str(record["caster_id"]))
			if record.has("damage_budget_total") and owner != null and not owner.spell_effects.has(source):
				remove(target, str(source))
				continue
			if bool(record["concentration"]) and (owner == null or str(owner.concentrating_on.get("effect_source", "")) != source):
				remove(target, str(source))
	for caster: Character in casters:
		TetherRules.prune(caster)
		var source := str(caster.concentrating_on.get("effect_source", ""))
		if source.is_empty():
			continue
		if not caster.is_alive or CombatAction.is_incapacitated(caster):
			end_concentration(caster, targets)
			continue
		var caster_record: Dictionary = records(caster).get(source, {})
		if str(caster_record.get("spell_id", "")) in PERSISTED_AREA_MARKER_SPELLS and caster_record["conditions"].is_empty():
			# The source record belongs to the caster but is not a creature target.
			# Keep Concentration without storing a self-reference in `targets`.
			caster.concentrating_on["targets"] = []
			continue
		var held: Array = []
		for target in targets:
			if target is Character and target == caster: continue
			if records(target).has(source):
				held.append(target)
		if held.is_empty() and not records(caster).has(source):
			end_concentration(caster, targets)
		else:
			caster.concentrating_on["targets"] = held
		TetherRules.reconcile(caster, targets)

## Monsters have no persistent campaign identity. Their effects end with the
## encounter; surviving party effects keep their seconds and stable caster ID.
static func finish_encounter(casters: Array, targets: Array) -> void:
	for target in targets:
		if target is Dictionary:
			for source in records(target).keys():
				remove(target, str(source))
	for caster in casters:
		if caster is Character: TetherRules.reconcile(caster, targets)
	var party_targets: Array = targets.filter(func(target): return target is Character)
	reconcile(casters, party_targets)

static func saved_concentration(caster: Character) -> Dictionary:
	return SpellEffectPersistence.saved_concentration(caster)



static func saved_state_error(dto: Dictionary) -> String:
	return SpellEffectPersistence.saved_state_error(dto)



static func saved_party_error(characters: Dictionary, save_data: Dictionary = {}) -> String:
	return SpellEffectPersistence.saved_party_error(characters, save_data)


