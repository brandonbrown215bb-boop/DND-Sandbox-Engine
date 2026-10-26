## Source-owned Hit Point maximum changes (S-130).
##
## Each exact source instance owns one entry recording what it requested and
## what it actually applied after the floor clamp. Removing a source reverts only
## its own applied delta, so equivalent sources (same rule, different instance)
## never revoke one another. Content declares kind, amount, accumulation,
## periodic growth and cure events; no rule ID is branched on.
class_name MaxHpSourceRules
extends RefCounted

const KINDS := ["increase", "reduction"]
const EVENTS := ["short_rest_completed", "long_rest_completed", "turn_started"]
const ENTRY_KEYS := ["rule_id", "kind", "requested", "applied", "accumulate", "floor", "cure_on", "periodic", "raise_current", "zero_limit", "combine"]
## Batch 071 (S-130): how equivalent sources (same rule id, different exact
## instances) combine. Content declares it; absent keeps the legacy "sum".
const COMBINE := ["sum", "highest"]
## S-131: a zero-limit reduction may drive the maximum to 0, which is death.
const ZERO_LIMIT_KEYS := ["cause", "remains"]
const ZERO_LIMIT_REMAINS := ["intact", "dust", "bones"]

static func validate_rule(rule: Variant) -> String:
	if not rule is Dictionary: return "max_hp_source rule must be an object"
	if str(rule.get("id", "")).is_empty(): return "max_hp_source needs id"
	if str(rule.get("kind", "")) not in KINDS: return "max_hp_source kind must be increase or reduction"
	var amount: Variant = rule.get("amount", null)
	if not (amount is String and amount == "damage_dealt") and not _int(amount, 0, 1000): return "max_hp_source amount must be 0..1000 or damage_dealt"
	for key in ["accumulate", "raise_current"]:
		if rule.has(key) and not rule[key] is bool: return "max_hp_source %s must be boolean" % key
	if rule.has("floor") and not _int(rule["floor"], 1, 1000): return "max_hp_source floor must be 1..1000"
	if rule.has("combine") and str(rule["combine"]) not in COMBINE: return "max_hp_source combine must be sum or highest"
	for key in rule:
		if str(key) not in ["id", "kind", "amount", "accumulate", "raise_current", "floor", "cure_on", "zero_limit", "periodic", "combine"]: return "max_hp_source has unknown field '%s'" % str(key)
	if rule.has("cure_on") and (not rule["cure_on"] is Array or rule["cure_on"].any(func(e): return not e is String or e not in EVENTS)): return "max_hp_source cure_on events are invalid"
	if rule.has("zero_limit"):
		var z: Variant = rule["zero_limit"]
		if str(rule.kind) != "reduction" or rule.has("floor"): return "max_hp_source zero_limit applies only to floorless reductions"
		if not z is Dictionary or z.size() != 2 or not z.get("cause", "") is String or str(z.get("cause", "")).is_empty() or str(z.cause).length() > 80 or str(z.get("remains", "")) not in ZERO_LIMIT_REMAINS: return "max_hp_source zero_limit requires cause and remains"
	if rule.has("periodic"):
		var p: Variant = rule["periodic"]
		if not p is Dictionary or str(p.get("event", "")) not in EVENTS or not _int(p.get("amount", null), 1, 1000): return "max_hp_source periodic is invalid"
		if str(rule.kind) != "reduction": return "max_hp_source periodic applies only to reductions"
	return ""

## Apply (or re-apply) one exact source. Returns a receipt.
## Batch 071: `actor` is a Character or a monster combatant Dictionary.
static func apply(actor, rule: Dictionary, source_instance_id: String, amount: int = -1) -> Dictionary:
	if not (actor is Character or actor is Dictionary) or source_instance_id.is_empty() or not validate_rule(rule).is_empty(): return {"applied": false, "reason": "invalid"}
	if actor is Dictionary and not bool(actor.get("is_alive", true)): return {"applied": false, "reason": "target_dead", "source_instance_id": source_instance_id}
	var requested := amount if amount >= 0 else (int(rule.amount) if not rule.amount is String else 0)
	if str(rule.kind) == "reduction" and not _aura(actor).is_empty():
		return {"applied": false, "reason": "maximum_protected", "source_instance_id": source_instance_id}
	var entry: Dictionary = sources(actor).get(source_instance_id, {})
	var total := requested
	if not entry.is_empty() and bool(rule.get("accumulate", false)): total += int(entry.requested)
	elif not entry.is_empty(): total = maxi(int(entry.requested), requested)
	if entry.is_empty():
		entry = {"rule_id": str(rule.id), "kind": str(rule.kind), "requested": 0, "applied": 0, "accumulate": bool(rule.get("accumulate", false)), "floor": 0 if rule.has("zero_limit") else int(rule.get("floor", 1)), "cure_on": rule.get("cure_on", []).duplicate(), "periodic": {}, "raise_current": bool(rule.get("raise_current", false))}
		if rule.has("periodic"): entry.periodic = {"event": str(rule.periodic.event), "amount": int(rule.periodic.amount)}
		if rule.has("zero_limit"): entry["zero_limit"] = rule.zero_limit.duplicate(true)
		if rule.has("combine"): entry["combine"] = str(rule.combine)
	return _settle(actor, source_instance_id, entry, total)

static func _settle(actor, id: String, entry: Dictionary, total: int) -> Dictionary:
	var before_max := _max(actor)
	var base := _natural_base(actor)
	var old_applied := int(entry.applied)
	entry.requested = total
	sources(actor)[id] = entry
	_recompute(actor, base)
	var applied := int(entry.applied)
	var change := applied - old_applied
	if change > 0 and bool(entry.raise_current) and _cur(actor) > 0: _set_cur(actor, mini(_cur(actor) + change, _max(actor)))
	var death := _zero_limit_death(actor, id)
	return {"zero_limit_death": death, "applied": true, "source_instance_id": id, "requested": total, "delta": applied, "clamped": absi(applied) < total, "max_hp_before": before_max, "max_hp_after": _max(actor), "current_hp": _cur(actor)}

## Batch 071: shared field access for Character and monster Dictionary records.
static func sources(actor) -> Dictionary:
	if actor is Character: return actor.max_hp_sources
	if not actor.get("max_hp_sources", null) is Dictionary: actor["max_hp_sources"] = {}
	return actor["max_hp_sources"]

static func _aura(actor) -> Array:
	if actor is Character: return actor.aura_of_life_sources
	var aura: Variant = actor.get("aura_of_life_sources", [])
	return aura if aura is Array else []

static func _max(actor) -> int:
	return actor.max_hp if actor is Character else int(actor.get("max_hp", 0))

static func _cur(actor) -> int:
	return actor.current_hp if actor is Character else int(actor.get("current_hp", 0))

static func _set_max(actor, value: int) -> void:
	if actor is Character: actor.max_hp = value
	else: actor["max_hp"] = value

static func _set_cur(actor, value: int) -> void:
	if actor is Character: actor.current_hp = value
	else: actor["current_hp"] = value

## Equivalent "highest" sources: only the largest request per rule id applies
## (SRD: effects of the same name don't combine); the first instance wins ties.
static func _suppressed(actor, id: String) -> bool:
	var all := sources(actor)
	var e: Dictionary = all[id]
	if str(e.get("combine", "sum")) != "highest": return false
	for other in all:
		if other == id: return false
		var o: Dictionary = all[other]
		if str(o.get("combine", "sum")) == "highest" and o.rule_id == e.rule_id and o.kind == e.kind and int(o.requested) >= int(e.requested): return true
	return false

static func _outranked(actor, id: String) -> bool:
	var all := sources(actor)
	var e: Dictionary = all[id]
	if str(e.get("combine", "sum")) != "highest": return false
	for other in all:
		if other == id: continue
		var o: Dictionary = all[other]
		if str(o.get("combine", "sum")) == "highest" and o.rule_id == e.rule_id and o.kind == e.kind and int(o.requested) > int(e.requested): return true
	return false

static func _inactive(actor, id: String) -> bool:
	return _suppressed(actor, id) or _outranked(actor, id)

## Maximum with every source's applied delta removed.
static func _natural_base(actor) -> int:
	var net := 0
	for id in sources(actor): net += int(sources(actor)[id].applied)
	return _max(actor) - net

## Re-derive every source's applied delta from the natural base so clamping by
## one source never leaks into another's removal (review R1). Increases apply in
## full; reductions apply in ownership order up to the strictest floor.
static func _recompute(actor, base: int) -> void:
	var all := sources(actor)
	var increases := 0
	var floor_hp := 1
	for id in all:
		var e: Dictionary = all[id]
		if e.kind == "increase":
			e.applied = 0 if _inactive(actor, id) else int(e.requested)
			increases += int(e.applied)
		elif not _inactive(actor, id): floor_hp = maxi(floor_hp, int(e.floor))
	var room := maxi(0, base + increases - floor_hp)
	for id in all:
		var e: Dictionary = all[id]
		if e.kind != "reduction" or e.has("zero_limit"): continue
		var take := 0 if _inactive(actor, id) else mini(int(e.requested), room)
		e.applied = -take
		room -= take
	# Zero-limit reductions settle last and may take the remaining maximum to 0.
	room += floor_hp
	var zero_limited := false
	for id in all:
		var e: Dictionary = all[id]
		if e.kind != "reduction" or not e.has("zero_limit"): continue
		var take := 0 if _inactive(actor, id) else mini(int(e.requested), room)
		e.applied = -take
		room -= take
		if not _inactive(actor, id): zero_limited = zero_limited or room == 0
	var net := 0
	for id in all: net += int(all[id].applied)
	_set_max(actor, maxi(0 if zero_limited else 1, base + net))
	_set_cur(actor, mini(_cur(actor), _max(actor)))

## S-131: a maximum of 0 reached through a zero-limit source is death with the
## source's declared remains; there are no Death Saves (not current-HP zero) and
## revival stays refused until the maximum is restored (CorpseRules.target_error).
static func _zero_limit_death(actor, id: String) -> bool:
	var entry: Dictionary = sources(actor).get(id, {})
	if _max(actor) > 0 or not entry.has("zero_limit"): return false
	if actor is Dictionary:
		# Batch 071 (S-131): monster death uses the record's existing aftermath
		# field; an already-dead record never gains a second death or remains.
		if actor.has("zero_hp_aftermath") or not bool(actor.get("is_alive", true)): return false
		actor["current_hp"] = 0
		actor["temp_hp"] = 0
		actor["is_alive"] = false
		actor["zero_hp_aftermath"] = {"outcome": "death", "remains": str(entry.zero_limit.remains), "cause": str(entry.zero_limit.cause), "cause_source": {"policy_id": str(entry.rule_id), "outcome": "death", "source_instance_id": id, "gear": "retained"}}
		return true
	if not actor.corpse_state.is_empty(): return false
	CorpseRules.mark_dead(actor, str(entry.zero_limit.cause), str(entry.zero_limit.remains))
	actor.corpse_state["cause_source"] = {"policy_id": str(entry.rule_id), "outcome": "death", "source_instance_id": id, "gear": "retained"}
	return true

static func zero_limit_source(actor) -> String:
	for id in sources(actor):
		if sources(actor)[id].has("zero_limit") and _max(actor) == 0: return str(id)
	return ""

## Batch 071: a shared spell's cast owns one source on its recipient. The
## spell record carries the link so the spell's end (duration, concentration,
## encounter end) removes exactly this source through SpellEffects.remove.
static func grant_from_cast(target, cast: Dictionary, rule: Dictionary) -> Dictionary:
	var source := str(cast.get("source_id", ""))
	if source.is_empty() or not (target is Character or target is Dictionary): return {"applied": false, "reason": "invalid"}
	var receipt := apply(target, rule, source)
	if not receipt.get("applied", false): return receipt
	var record: Dictionary = SpellEffects.records(target).get(source, cast.duplicate(true))
	# A zero-maximum death keeps its source: the spell ending later never
	# restores the maximum of a body that died from it.
	if not bool(receipt.get("zero_limit_death", false)):
		record["max_hp_source"] = str(rule.id)
		record["recipient_id"] = SpellEffects.caster_id(target) if target is Character else str(target.get("id", ""))
		var all_records := SpellEffects.records(target)
		all_records[source] = record
		if target is Dictionary: target["spell_effects"] = all_records
	return receipt

## Saved spell-record link: the recipient DTO must own the source and the
## loaded definition must declare that rule.
static func saved_link_error(dto: Dictionary, source: String, record: Dictionary) -> String:
	if not record.has("max_hp_source"): return ""
	var owned: Variant = dto.get("max_hp_sources", {})
	var entry: Variant = owned.get(source, null) if owned is Dictionary else null
	if not entry is Dictionary or str(entry.get("rule_id", "")) != str(record.max_hp_source): return "invalid saved maximum-HP source link"
	for effect in DataLoader.get_spell(str(record.get("spell_id", ""))).get("effects", []):
		if effect is Dictionary and str(effect.get("type", "")) == "max_hp_source" and effect.get("rule", {}) is Dictionary and str(effect.rule.get("id", "")) == str(record.max_hp_source): return ""
	return "invalid saved maximum-HP source link"

## Remove one exact source; the others are re-derived from the natural base.
static func remove(actor, source_instance_id: String, cause: String = "removed") -> Dictionary:
	if not (actor is Character or actor is Dictionary) or not sources(actor).has(source_instance_id): return {}
	var before := _max(actor)
	var base := _natural_base(actor)
	sources(actor).erase(source_instance_id)
	_recompute(actor, base)
	return {"removed": true, "source_instance_id": source_instance_id, "cause": cause, "max_hp_before": before, "max_hp_after": _max(actor)}

## Completed rest / turn-start events: cure declared sources, grow periodic ones.
static func on_event(actor, event: String) -> Array:
	var receipts: Array = []
	if not (actor is Character or actor is Dictionary): return receipts
	if actor is Dictionary and not actor.get("max_hp_sources", {}) is Dictionary: return receipts
	for id in sources(actor).keys():
		var entry: Dictionary = sources(actor)[id]
		if event in entry.cure_on:
			receipts.append(remove(actor, id, event))
		elif str(entry.periodic.get("event", "")) == event and _aura(actor).is_empty():
			receipts.append(_settle(actor, id, entry, int(entry.requested) + int(entry.periodic.amount)))
	return receipts

## Saved-DTO validation; absent field keeps legacy saves loading.
static func saved_error(data: Dictionary) -> String:
	var sources: Variant = data.get("max_hp_sources", {})
	if not sources is Dictionary: return "max HP sources are invalid"
	if sources.size() > 64: return "max HP sources are invalid"
	var net := 0
	for id in sources:
		var e: Variant = sources[id]
		if not id is String or str(id).is_empty() or not e is Dictionary: return "max HP source is invalid"
		for key in e:
			if str(key) not in ENTRY_KEYS: return "max HP source has unknown field"
		if str(e.get("kind", "")) not in KINDS or str(e.get("rule_id", "")).is_empty(): return "max HP source kind is invalid"
		if e.has("combine") and str(e.combine) not in COMBINE: return "max HP source combine is invalid"
		var zero: Variant = e.get("zero_limit", null)
		if e.has("zero_limit") and (e.kind != "reduction" or not zero is Dictionary or zero.size() != 2 or str(zero.get("remains", "")) not in ZERO_LIMIT_REMAINS or str(zero.get("cause", "")).is_empty() or int(e.get("floor", -1)) != 0): return "max HP source zero limit is invalid"
		if not _int(e.get("requested", null), 0, 100000) or not _int(e.get("floor", null), 0 if e.has("zero_limit") else 1, 1000): return "max HP source amounts are invalid"
		var applied: Variant = e.get("applied", null)
		if not (applied is int or applied is float) or float(applied) != floor(float(applied)): return "max HP source applied delta is invalid"
		if e.kind == "increase" and int(applied) != int(e.requested) and not (str(e.get("combine", "sum")) == "highest" and int(applied) == 0): return "max HP source increase contradicts its request"
		if e.kind == "reduction" and (int(applied) > 0 or -int(applied) > int(e.requested)): return "max HP source reduction contradicts its request"
		if not e.get("cure_on", null) is Array or e.cure_on.any(func(v): return not v is String or v not in EVENTS): return "max HP source cure events are invalid"
		if not e.get("periodic", null) is Dictionary: return "max HP source periodic is invalid"
		if not e.periodic.is_empty() and (str(e.periodic.get("event", "")) not in EVENTS or not _int(e.periodic.get("amount", null), 1, 1000)): return "max HP source periodic is invalid"
		for key in ["accumulate", "raise_current"]:
			if not e.get(key, null) is bool: return "max HP source flags are invalid"
		net += int(applied)
	if not sources.is_empty() and int(data.get("max_hp", 0)) - net < 1: return "max HP sources exceed the recorded maximum"
	if int(data.get("max_hp", 1)) == 0 and (not sources.values().any(func(e): return e is Dictionary and e.has("zero_limit")) or bool(data.get("is_alive", true)) or (data.get("corpse_state", {}) is Dictionary and data.get("corpse_state", {}).is_empty())): return "a zero maximum requires a zero-limit source and its death"
	return ""

static func restore(actor: Character, data: Dictionary) -> void:
	var sources: Variant = data.get("max_hp_sources", {})
	actor.max_hp_sources = sources.duplicate(true) if sources is Dictionary and saved_error(data).is_empty() else {}
	for id in actor.max_hp_sources:
		for key in ["requested", "applied", "floor"]:
			actor.max_hp_sources[id][key] = int(actor.max_hp_sources[id][key])
		if not actor.max_hp_sources[id].periodic.is_empty(): actor.max_hp_sources[id].periodic.amount = int(actor.max_hp_sources[id].periodic.amount)

static func _int(v: Variant, lo: int, hi: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floor(float(v)) and int(v) >= lo and int(v) <= hi

## Pre-cost refusal for a cast whose shared effects include max_hp_source:
## a dead/settled body or a protected maximum refuses before any slot is paid.
static func cast_error(target, spell: Dictionary) -> String:
	if not (target is Character or target is Dictionary): return ""
	for effect in spell.get("effects", []):
		if not (effect is Dictionary and str(effect.get("type", "")) == "max_hp_source"): continue
		var alive: bool = target.is_alive if target is Character else bool(target.get("is_alive", true)) and not target.has("zero_hp_aftermath")
		if not alive or _max(target) <= 0: return "%s is dead; its Hit Point maximum cannot change." % str(target.get("name") if target is Dictionary else target.character_name)
		if str(effect.get("rule", {}).get("kind", "")) == "reduction" and not _aura(target).is_empty(): return "That creature's Hit Point maximum is protected."
	return ""
