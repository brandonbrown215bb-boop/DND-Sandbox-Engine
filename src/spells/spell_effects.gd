## Bounded lifetime/ownership for the first shared condition-spell batch.
## Existing class conditions and other spell handlers keep their current paths.
class_name SpellEffects
extends RefCounted

const MANAGED_SPELLS := ["bless", "bane", "jump", "fly", "levitate", "spider_climb", "freedom_of_movement", "water_walk", "aid", "alter_self", "barkskin", "mage_armor", "hold_monster", "ray_of_sickness", "ray_of_enfeeblement", "animal_friendship", "charm_person", "charm_monster", "power_word_stun", "sleep", "blindness/deafness", "sunburst", "beacon_of_hope", "divine_favor", "death_ward", "sanctuary", "heroism", "magic_weapon", "enhance_ability", "faerie_fire", "invisibility", "darkvision", "see_invisibility", "true_seeing", "detect_magic", "blur", "detect_evil_and_good", "detect_poison_and_disease", "identify", "goodberry"]
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

static func begin_cast(caster: Character, spell: Dictionary, cast_facts: Dictionary = {}) -> Dictionary:
	caster.spell_cast_serial += 1
	var owner := caster_id(caster)
	var spell_id := str(spell.get("id", ""))
	var duration := int(spell.get("duration_seconds", 60))
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
	if rules is Array and not rules.is_empty(): record["source_end_rules"] = rules.duplicate(true)
	var aftermath: Variant = spell.get("end_aftermath", [])
	if aftermath is Array and not aftermath.is_empty(): record["end_aftermath"] = aftermath.duplicate(true)
	if not cast_facts.is_empty(): record["cast_facts"] = cast_facts.duplicate(true)
	return record

static func records(target) -> Dictionary:
	return target.spell_effects if target is Character else target.get("spell_effects", {})

static func grant(target, cast: Dictionary, condition: String, expiry_phase: String = "start", seconds: int = -1) -> void:
	if target == null or condition.is_empty():
		return
	var source := str(cast["source_id"])
	var record: Dictionary = records(target).get(source, cast.duplicate(true))
	record["recipient_id"] = caster_id(target) if target is Character else str(target.get("id", "")) if target is Dictionary else ""
	record["expiry_phase"] = expiry_phase
	if seconds >= 0:
		record["remaining_seconds"] = seconds
	var grants: Array = record.get("conditions", [])
	if condition not in grants:
		grants.append(condition)
	record["conditions"] = grants
	CombatAction.apply_condition(target, condition, maxi(1, int(ceil(float(record["remaining_seconds"]) / 6.0))), source)
	# An immune target must not acquire a timer or become a concentration target.
	if not has_grant(target, source, condition):
		return
	if not CombatAction.has_condition(target, condition):
		CombatAction.remove_condition_source(target, source, [condition])
		return
	var all_records := records(target)
	all_records[source] = record
	if target is Dictionary:
		target["spell_effects"] = all_records

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
	var all_records := records(target)
	if not all_records.has(source):
		return {}
	var record: Dictionary = all_records[source].duplicate(true)
	CombatAction.remove_condition_source(target, source, record.get("conditions", []))
	var aid_bonus := maxi(0, int(record.get("aid_hp_bonus", 0)))
	if aid_bonus > 0 and target is Character:
		target.max_hp = maxi(1, target.max_hp - aid_bonus)
		target.current_hp = mini(target.current_hp, target.max_hp)
	var projection_receipt := ActorProjectionRules.revert(target, record) if record.has("projection") else {}
	all_records.erase(source)
	var event := {"source_id": source, "spell_id": str(record.get("spell_id", "")), "caster_id": str(record.get("caster_id", "")), "end_reason": end_reason, "cause": cause.duplicate(true), "record": record}
	if not projection_receipt.is_empty(): event["projection"] = projection_receipt
	if target is Dictionary:
		target["spell_effects"] = all_records
		if not has_spell(target, "animal_friendship"):
			target.erase("animal_friendship_caster_ids")
	# S-086: the one final end event fires only its reason-matched follow-ups.
	event["aftermath"] = SourceEndAftermathRules.fire(target, record, event)
	_source_end_events.append(event.duplicate(true))
	while _source_end_events.size() > 128: _source_end_events.pop_front()
	return event

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
		remove(target, source, "expired", {"remaining_before": int(record["remaining_seconds"]), "elapsed_seconds": seconds})
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

static func repeat_save_due(target, source: String, schedule: String, now_seconds: int = -1) -> bool:
	if repeat_save_schedule(target, source) != schedule: return false
	var record: Dictionary = records(target).get(source, {})
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
		var margin := total - dc
		var route := "stay"
		if saved and margin >= int(stage.get("minimum_margin", 0)):
			var qualified := int(record.get("repeat_save_stage_successes", 0)) + 1
			record["repeat_save_stage_successes"] = qualified
			if qualified >= int(stage.get("successes_required", 1)): route = "advance"
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
		for target in targets:
			for source in records(target):
				var record: Dictionary = records(target)[source]
				var remaining := int(record.get("remaining_seconds", -1))
				if remaining > 0: boundary = mini(boundary, cursor + remaining)
				if repeat_save_schedule(target, str(source)) == "elapsed_seconds":
					var next_at := int(record.get("repeat_save_next_at_seconds", final_seconds))
					if next_at > cursor: boundary = mini(boundary, next_at)
		GameManager.campaign_elapsed_seconds = boundary
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
	for actor in casters:
		FeatureModeRules.advance_time(actor, elapsed_seconds)

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
	for target in targets:
		remove(target, source, "concentration_ended", {"caster_id": caster_id(caster)})
	caster.concentrating_on.clear()
	return true

## Rebuild live references from stable source IDs; only this batch is managed.
static func prune(target) -> void:
	for source in records(target).keys():
		var record: Dictionary = records(target)[source]
		if record.has("source_benefits") or record.has("damage_link") or record.has("damage_response") or record.has("created_actors") or record.has("projection"):
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
			if bool(record["concentration"]) and (owner == null or str(owner.concentrating_on.get("effect_source", "")) != source):
				remove(target, str(source))
	for caster: Character in casters:
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
			if records(target).has(source):
				held.append(target)
		if held.is_empty():
			end_concentration(caster, targets)
		else:
			caster.concentrating_on["targets"] = held

## Monsters have no persistent campaign identity. Their effects end with the
## encounter; surviving party effects keep their seconds and stable caster ID.
static func finish_encounter(casters: Array, targets: Array) -> void:
	for target in targets:
		if target is Dictionary:
			for source in records(target).keys():
				remove(target, str(source))
	var party_targets: Array = targets.filter(func(target): return target is Character)
	reconcile(casters, party_targets)

static func saved_concentration(caster: Character) -> Dictionary:
	return SpellEffectPersistence.saved_concentration(caster)



static func saved_state_error(dto: Dictionary) -> String:
	return SpellEffectPersistence.saved_state_error(dto)



static func saved_party_error(characters: Dictionary) -> String:
	return SpellEffectPersistence.saved_party_error(characters)


