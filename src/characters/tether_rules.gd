class_name TetherRules
extends RefCounted
## S-168 actor/object restraint relation. A source-owned tether binds the actual
## captor, victim and anchor with a range. The victim's condition is granted under
## the tether's own source, so escaping or breaking it removes only that source's
## restraint; other restraints on the same victim stay.

const CONDITIONS := ["restrained"]
const ESCAPES := {"STR": "Athletics", "DEX": "Acrobatics"}

static func effect_error(effect: Dictionary) -> String:
	if effect.keys().any(func(k): return str(k) not in ["type", "condition", "range_hexes", "escape", "capacity", "on_failed_save"]): return "Tethers accept only condition, range_hexes, escape, capacity and on_failed_save."
	if str(effect.get("condition", "")) not in CONDITIONS: return "Tethers support only the restrained condition."
	var r: Variant = effect.get("range_hexes")
	if not (r is int or r is float) or float(r) != floorf(float(r)) or int(r) < 1 or int(r) > 30: return "Tether range_hexes must be 1-30."
	var esc: Variant = effect.get("escape")
	if not esc is Array or esc.is_empty() or esc.any(func(a): return not a is String or not ESCAPES.has(str(a))): return "Tether escape abilities must be STR and/or DEX."
	var c: Variant = effect.get("capacity", 1)
	if not (c is int or c is float) or float(c) != floorf(float(c)) or int(c) < 1 or int(c) > 4: return "Tether capacity must be 1-4."
	return ""

static func _effect(spell: Dictionary) -> Dictionary:
	for e in spell.get("effects", []):
		if e is Dictionary and e.get("type", "") == "bind_tether": return e
	return {}

## Whether this exact source grants any condition on the target (actor or monster).
static func has_source(target, source: String) -> bool:
	var sources: Variant = target.condition_sources if target is Character else target.get("condition_sources", {}) if target is Dictionary else {}
	if not sources is Dictionary: return false
	for grants in sources.values():
		if grants is Dictionary and grants.has(source): return true
	return false

static func victim_id(target) -> String:
	return str(target.character_id) if target is Character else str(target.get("id", "")) if target is Dictionary else ""

static func held(caster: Character, spell_id: String = "") -> Array:
	prune(caster)
	return caster.tethers.keys().filter(func(s): return spell_id.is_empty() or str(caster.tethers[s].spell_id) == spell_id)

## Refusal before the slot is spent: the captor's declared capacity is full.
static func cast_error(caster, spell: Dictionary) -> String:
	var effect := _effect(spell)
	if effect.is_empty() or not caster is Character: return ""
	if held(caster, str(spell.get("id", ""))).size() >= int(effect.get("capacity", 1)): return "You already hold as many tethers from this spell as it allows."
	return ""

## Shared effect on a failed save: grant the condition under the cast's source and bind the relation.
static func apply(caster: Character, target, cast: Dictionary, effect: Dictionary, spell: Dictionary) -> Dictionary:
	if caster == null or target == null or (target is Character and target == caster) or not effect_error(effect).is_empty(): return {"bound": false, "reason": "invalid tether"}
	var source := str(cast.get("source_id", ""))
	if source.is_empty() or caster.tethers.has(source): return {"bound": false, "reason": "source already bound"}
	var condition := str(effect.condition)
	SpellEffects.grant(target, cast, condition)
	if not has_source(target, source): return {"bound": false, "reason": "The target resists the condition."}
	caster.tethers[source] = {"spell_id": str(spell.get("id", "")), "victim_id": victim_id(target), "victim_kind": "character" if target is Character else "monster", "anchor_id": caster.character_id, "condition": condition, "range_hexes": int(effect.range_hexes), "escape": effect.escape.duplicate(), "dc": int(cast.get("save_dc", 10))}
	return {"bound": true, "source_id": source, "victim_id": victim_id(target)}

## A tether lives only while its concentration source does.
static func prune(caster: Character) -> void:
	if caster == null: return
	for source in caster.tethers.keys():
		if str(caster.concentrating_on.get("effect_source", "")) != str(source): caster.tethers.erase(source)

static func _release(caster: Character, source: String, victim) -> void:
	var t: Dictionary = caster.tethers.get(source, {})
	CombatAction.remove_condition_source(victim, source, [str(t.get("condition", "restrained"))])
	caster.tethers.erase(source)
	var targets: Array = caster.concentrating_on.get("targets", [])
	targets.erase(victim)
	if str(caster.concentrating_on.get("effect_source", "")) == source and targets.is_empty():
		SpellEffects.end_concentration(caster, [caster])

## Tethers binding this victim, as [{captor, source, tether}].
static func binding(victim, captors: Array) -> Array:
	var id := victim_id(victim)
	var result: Array = []
	for c in captors:
		if not c is Character: continue
		prune(c)
		for source in c.tethers:
			if str(c.tethers[source].victim_id) == id and has_source(victim, str(source)): result.append({"captor": c, "source": str(source), "tether": c.tethers[source]})
	return result

## Escape one exact tether with the victim's best declared check; other restraints remain.
static func escape(victim, captors: Array, roll: int = 0) -> Dictionary:
	var bound := binding(victim, captors)
	if bound.is_empty(): return {"attempted": false, "message": "Nothing tethers you."}
	var entry: Dictionary = bound[0]
	var best := -100
	var used := ""
	for ability in entry.tether.escape:
		var mod := 0
		if victim is Character: mod = victim.ability_scores.get_ability_modifier(str(ability))
		else:
			mod = AbilityScores.get_modifier(int(victim.get("ability_scores", {}).get(str(ability), 10)))
			var skills: Variant = victim.get("skills", {})
			if skills is Dictionary: mod = int(skills.get(ESCAPES[ability], mod))
		if mod > best:
			best = mod
			used = str(ability)
	var dc := int(entry.tether.dc)
	var total := 0
	if victim is Character:
		var check := EventResolver.resolve_skill_check(victim, {"ability": used, "skill": ESCAPES[used], "dc": dc, "use_primal_knowledge": false})
		total = int(check.get("total", 0))
	else: total = (roll if roll > 0 else Dice.roll(20)) + best
	var freed := total >= dc
	if freed: _release(entry.captor, entry.source, victim)
	return {"attempted": true, "success": freed, "total": total, "dc": dc, "ability": used, "source_id": entry.source, "message": "%s %s the tether with %s (%s) (%d vs DC %d)." % [_name(victim), "breaks free of" if freed else "fails to escape", used, ESCAPES[used], total, dc]}

static func _name(target) -> String:
	return target.character_name if target is Character else str(target.get("name", "The creature"))

## Combat: a tether whose victim is beyond its range from the anchor breaks; only that source ends.
static func enforce_range(captors: Array, positions: Dictionary, victims: Dictionary) -> Array:
	var broken: Array = []
	for c in captors:
		if not c is Character: continue
		prune(c)
		for source in c.tethers.keys():
			var t: Dictionary = c.tethers[source]
			if not positions.has(str(t.anchor_id)) or not positions.has(str(t.victim_id)) or not victims.has(str(t.victim_id)): continue
			if HexUtils.get_distance(positions[str(t.anchor_id)], positions[str(t.victim_id)]) > int(t.range_hexes):
				_release(c, str(source), victims[str(t.victim_id)])
				broken.append(str(source))
	return broken

static func restore(actor: Character, data: Dictionary) -> void:
	actor.tethers = data.get("tethers", {}).duplicate(true) if data.get("tethers", {}) is Dictionary else {}

static func saved_error(dto: Dictionary) -> String:
	var tethers: Variant = dto.get("tethers", {})
	if not tethers is Dictionary: return "tethers are invalid"
	for source in tethers:
		var t: Variant = tethers[source]
		if not t is Dictionary or t.keys().size() != 8: return "tether record is malformed"
		var spell := DataLoader.get_spell(str(t.get("spell_id", "")))
		var effect := _effect(spell)
		if effect.is_empty(): return "tether names a spell without a tether"
		if not str(source).begins_with("spell:%s:" % str(dto.get("character_id", ""))) or str(t.get("anchor_id", "")) != str(dto.get("character_id", "")): return "tether has an invalid captor"
		if str(dto.get("spell_concentration", dto.get("concentrating_on", {})).get("effect_source", "")) != str(source): return "tether lacks its concentration source"
		if str(t.get("condition", "")) != str(effect.condition) or int(t.get("range_hexes", -1)) != int(effect.range_hexes) or t.get("escape") != effect.escape or str(t.get("victim_kind", "")) not in ["character", "monster"] or str(t.get("victim_id", "")).is_empty() or str(t.victim_id) == str(dto.get("character_id", "")): return "tether differs from its spell"
		var dc: Variant = t.get("dc")
		if not (dc is int or dc is float) or int(dc) < 1 or int(dc) > 30: return "tether DC is invalid"
	return ""
