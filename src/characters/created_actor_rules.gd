## S-154: a parameterized actor created from a declared template by an exact
## cast. The cast's source record on the owner owns the actor's lifetime; AC,
## maximum HP and count derive from the template and paid level above the
## spell's base level, attack/DC are read live from the owner, and current HP
## is tracked separately. Forbidden creation features are never copied.
class_name CreatedActorRules
extends RefCounted

const TEMPLATE_KEYS := ["id", "name", "creature_type", "size", "speed", "ability_scores", "ac", "max_hp", "count", "attack", "features", "command"]
const CREATURE_TYPES := ["aberration", "beast", "celestial", "construct", "dragon", "elemental", "fey", "fiend", "giant", "humanoid", "monstrosity", "ooze", "plant", "undead"]
const SIZES := ["tiny", "small", "medium", "large", "huge", "gargantuan"]
const DAMAGE_TYPES := ["acid", "bludgeoning", "cold", "fire", "force", "lightning", "necrotic", "piercing", "poison", "psychic", "radiant", "slashing", "thunder"]
const ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
## A created actor never inherits the means to create, upgrade or cast.
const FORBIDDEN_FEATURE_TYPES := ["create_actor", "mode_choice", "rule_upgrade", "resource", "zero_hp_replacement", "spellcasting"]
const RECORD_KEYS := ["level", "actors", "template_id", "control_until"]

static var _live := {}

static func _int(v: Variant, lo: int, hi: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floorf(float(v)) and int(v) >= lo and int(v) <= hi

static func _formula_error(v: Variant, base_lo: int, base_hi: int, per_hi: int, label: String) -> String:
	if not v is Dictionary or not _int(v.get("base"), base_lo, base_hi) or not _int(v.get("per_level", 0), 0, per_hi): return "%s requires base %d-%d and per_level 0-%d" % [label, base_lo, base_hi, per_hi]
	for key in v:
		if str(key) not in ["base", "per_level", "max"]: return "%s has unknown field" % label
	if v.has("max") and (not _int(v.max, base_lo, base_hi * 4) or int(v.max) < int(v.base)): return "%s max is invalid" % label
	return ""

static func template_error(t: Variant) -> String:
	if not t is Dictionary: return "create_actor template must be an object"
	for key in t:
		if str(key) not in TEMPLATE_KEYS: return "create_actor template has unknown field '%s'" % key
	if str(t.get("id", "")).is_empty() or str(t.get("name", "")).is_empty(): return "create_actor template requires id and name"
	if str(t.get("creature_type", "")) not in CREATURE_TYPES or str(t.get("size", "")) not in SIZES: return "create_actor template requires a creature type and size"
	if not _int(t.get("speed"), 0, 24): return "create_actor template speed must be 0-24 hexes"
	var scores: Variant = t.get("ability_scores")
	if not scores is Dictionary or scores.size() != 6 or ABILITIES.any(func(a): return not _int(scores.get(a), 1, 30)): return "create_actor template requires six ability scores 1-30"
	for pair in [["ac", 5, 25, 3], ["max_hp", 1, 300, 50], ["count", 1, 4, 2]]:
		var e := _formula_error(t.get(pair[0]), pair[1], pair[2], pair[3], pair[0])
		if not e.is_empty(): return "create_actor template " + e
	var attack: Variant = t.get("attack")
	if not attack is Dictionary or attack.size() != 4 or str(attack.get("name", "")).is_empty() or not RegEx.create_from_string("^[1-9]d(4|6|8|10|12)$").search(str(attack.get("damage", ""))) or str(attack.get("damage_type", "")) not in DAMAGE_TYPES or not _int(attack.get("range"), 1, 24):
		return "create_actor template attack requires name, damage NdX, damage_type and range"
	if t.has("command"):
		var command_error := CreatedCommandRules.policy_error(t.command) # Batch 055: S-156.
		if not command_error.is_empty(): return "create_actor template " + command_error
	var features: Variant = t.get("features", [])
	if not features is Array or features.size() > 8 or features.any(func(f): return not f is Dictionary or str(f.get("id", "")).is_empty()): return "create_actor template features must be up to eight records with ids"
	return ""

static func value(formula: Dictionary, level: int) -> int:
	var v := int(formula.base) + int(formula.get("per_level", 0)) * maxi(0, level)
	return mini(v, int(formula.max)) if formula.has("max") else v

static func _effect(spell: Dictionary) -> Dictionary:
	for effect in spell.get("effects", []):
		if effect is Dictionary and effect.get("type", "") == "create_actor": return effect
	return {}

## S-155 (Batch 054/058): the declared template plus any number of authored options.
static func templates(effect: Dictionary) -> Array:
	var out: Array = [effect.get("template", {})]
	out.append_array(effect.get("options", []))
	return out

static func options_error(effect: Dictionary) -> String:
	var options: Variant = effect.get("options", [])
	# Batch 058: no inherent cap; the data lists every creature the effect can create.
	if not options is Array: return "create_actor options must be an array of templates"
	var seen := {}
	for t in templates(effect):
		var e := template_error(t)
		if not e.is_empty(): return e
		if seen.has(str(t.id)): return "create_actor template ids must be unique"
		seen[str(t.id)] = true
	if effect.has("count_choice") and not effect.count_choice is bool: return "create_actor count_choice must be a boolean"
	return mix_error(effect)

## Batch 058 S-155: `mix` lets one cast create any combination of the declared
## templates (e.g. Animate Dead skeletons and/or zombies) up to a shared total.
static func mix_error(effect: Dictionary) -> String:
	if not effect.has("mix"): return ""
	var mix: Variant = effect.mix
	if not mix is Dictionary or mix.size() != 1 or not mix.has("count"): return "create_actor mix accepts only count"
	var e := _formula_error(mix.count, 1, 4, 2, "mix count")
	if not e.is_empty(): return "create_actor " + e
	var all := templates(effect)
	if all.size() < 2: return "create_actor mix requires at least two templates"
	for t in all:
		# One reservation size and one command policy per cast keep placement and control shared.
		if str(t.size) != str(all[0].size): return "create_actor mix templates must share one size"
		if CreatedCommandRules.shared_policy(t) != CreatedCommandRules.shared_policy(all[0]): return "create_actor mix templates must share one command policy" # Batch 061: free == none.
	return ""

static func is_mixed(effect: Dictionary) -> bool:
	return effect.get("mix") is Dictionary

## Refusal reason for a chosen mix ({template_id: n}); "" when permitted.
static func mix_choice_error(effect: Dictionary, mix: Variant, level: int) -> String:
	if not mix is Dictionary or mix.is_empty(): return "mix_not_permitted"
	var ids := templates(effect).map(func(t): return str(t.id))
	var total := 0
	for id in mix:
		if str(id) not in ids or not _int(mix[id], 0, 64): return "mix_not_permitted"
		total += int(mix[id])
	return "" if total in creation_counts(effect, {}, level) else "count_not_permitted"

## The template a cast chose (default: the declared template). {} when not permitted.
static func _template(spell: Dictionary, template_id: String = "") -> Dictionary:
	var effect := _effect(spell)
	if effect.is_empty(): return {}
	for t in templates(effect):
		if template_id.is_empty() or str(t.get("id", "")) == template_id: return t
	return {}

## Permitted counts for this template and level: exactly the formula, or 1..formula when declared.
static func counts(effect: Dictionary, template: Dictionary, level: int) -> Array:
	var maximum := value(effect.mix.count if is_mixed(effect) else template.count, level)
	return range(1, maximum + 1) if bool(effect.get("count_choice", false)) else [maximum]

## Material-limited casts may produce fewer than the fixed maximum. Saves
## retain that actual count, without needing the now-consumed bodies.
static func creation_counts(effect: Dictionary, template: Dictionary, level: int) -> Array:
	var permitted := counts(effect, template, level)
	return range(1, int(permitted[-1]) + 1) if not MaterialTargetRules.spec(effect).is_empty() else permitted

static func _forbidden(feature: Dictionary) -> bool:
	if str(feature.get("type", "")) in FORBIDDEN_FEATURE_TYPES or feature.has("spellcasting"): return true
	for effect in feature.get("effects", []) + feature.get("passive_effects", []):
		if effect is Dictionary and str(effect.get("type", "")) in FORBIDDEN_FEATURE_TYPES: return true
	return false

## Called by the shared create_actor effect on the self-cast owner.
static func create(owner: Character, cast: Dictionary, template: Dictionary, slot_level: int, spell: Dictionary, chosen_count: int = -1, chosen_mix: Dictionary = {}) -> Dictionary:
	var source := str(cast.get("source_id", ""))
	if owner == null or source.is_empty() or owner.spell_effects.has(source) or cast.get("caster_id", "") != owner.character_id or not template_error(template).is_empty(): return {"created": false}
	if spell.is_empty(): spell = DataLoader.get_spell(str(cast.get("spell_id", "")))
	# S-155: only a declared template or option may be created.
	if _template(spell, str(template.get("id", ""))).is_empty(): return {"created": false, "reason": "not_permitted"}
	var level := maxi(0, slot_level - int(spell.get("level", 0)))
	if is_mixed(_effect(spell)): return _create_mixed(owner, cast, slot_level, spell, level, chosen_mix, source)
	var allowed := creation_counts(_effect(spell), template, level)
	var count: int = allowed[-1] if chosen_count < 0 else chosen_count
	if count not in allowed: return {"created": false, "reason": "count_not_permitted"}
	var maximum := value(template.max_hp, level)
	var record := cast.duplicate(true)
	record["created_actors"] = {"level": level, "actors": []}
	if str(template.id) != str(_template(spell).id): record.created_actors["template_id"] = str(template.id)
	var command := CreatedCommandRules.policy(template)
	if command.has("control_seconds"): record.created_actors["control_until"] = int(GameManager.campaign_elapsed_seconds) + int(command.control_seconds)
	for i in count:
		record.created_actors.actors.append({"actor_id": "%s:actor:%d" % [source, i + 1], "current_hp": maximum})
	owner.spell_effects[source] = record
	var made := actors(owner).filter(func(a): return a.get_meta("created_source_id", "") == source)
	return {"created": true, "source_id": source, "level": level, "count": count, "max_hp": maximum, "ac": value(template.ac, level), "actor_ids": made.map(func(a): return a.character_id), "excluded_features": template.get("features", []).filter(func(f): return _forbidden(f)).map(func(f): return str(f.id))}

## Batch 058: one cast, several declared kinds. Each actor entry names its template.
static func _create_mixed(owner: Character, cast: Dictionary, _slot_level: int, spell: Dictionary, level: int, mix: Dictionary, source: String) -> Dictionary:
	var effect := _effect(spell)
	var reason := mix_choice_error(effect, mix, level)
	if not reason.is_empty(): return {"created": false, "reason": reason}
	var record := cast.duplicate(true)
	record["created_actors"] = {"level": level, "actors": []}
	var first := templates(effect)[0] as Dictionary
	var command := CreatedCommandRules.policy(first)
	if command.has("control_seconds"): record.created_actors["control_until"] = int(GameManager.campaign_elapsed_seconds) + int(command.control_seconds)
	var made_kinds := {}
	for t in templates(effect):
		for _n in int(mix.get(str(t.id), 0)):
			var i: int = record.created_actors.actors.size()
			record.created_actors.actors.append({"actor_id": "%s:actor:%d" % [source, i + 1], "current_hp": value(t.max_hp, level), "template_id": str(t.id)})
		if int(mix.get(str(t.id), 0)) > 0: made_kinds[str(t.id)] = int(mix[str(t.id)])
	owner.spell_effects[source] = record
	var made := actors(owner).filter(func(a): return a.get_meta("created_source_id", "") == source)
	return {"created": true, "source_id": source, "level": level, "count": made.size(), "mix": made_kinds, "actor_ids": made.map(func(a): return a.character_id)}

## Live actors whose source still exists; ended sources take their actors away.
static func actors(owner: Character) -> Array:
	var out: Array = []
	if owner == null: return out
	for source in owner.spell_effects:
		var record: Dictionary = owner.spell_effects[source]
		if not record.has("created_actors"): continue
		var spell := DataLoader.get_spell(str(record.get("spell_id", "")))
		var template := _template(spell, str(record.created_actors.get("template_id", "")))
		if template.is_empty(): continue
		for entry in record.created_actors.actors:
			var id := str(entry.actor_id)
			var kind := _template(spell, str(entry.template_id)) if entry.has("template_id") else template # Batch 058 mixed casts.
			if kind.is_empty(): continue
			# Review R1: a reloaded owner is a new object; rebuild from its saved record, never a stale cache.
			if not _live.has(id) or _live[id].get_meta("created_owner_instance", 0) != owner.get_instance_id(): _live[id] = _build(owner, str(source), kind, int(record.created_actors.level), entry, spell)
			out.append(_live[id])
	for id in _live.keys():
		var a: Character = _live[id]
		if a.get_meta("created_owner_id", "") == owner.character_id and not owner.spell_effects.has(a.get_meta("created_source_id", "")): _live.erase(id)
	return out

static func _build(owner: Character, source: String, template: Dictionary, level: int, entry: Dictionary, spell: Dictionary) -> Character:
	var a := instance(template, level, entry)
	a.set_meta("created_owner_id", owner.character_id)
	a.set_meta("created_source_id", source)
	a.set_meta("created_spell_id", str(spell.get("id", "")))
	a.set_meta("created_template_id", str(template.get("id", "")))
	a.set_meta("created_owner_instance", owner.get_instance_id())
	return a

## A plain actor from a validated template at a paid level (shared by S-120).
static func instance(template: Dictionary, level: int, entry: Dictionary) -> Character:
	var a := Character.new()
	a.character_id = str(entry.actor_id)
	a.character_name = "%s %s" % [str(template.name), str(entry.actor_id).get_slice(":", str(entry.actor_id).get_slice_count(":") - 1)]
	a.class_id = "created_actor"
	a.creature_type = str(template.creature_type)
	a.ability_scores.from_dict(template.ability_scores)
	a.base_ac = value(template.ac, level)
	a.max_hp = value(template.max_hp, level)
	a.current_hp = clampi(int(entry.current_hp), 0, a.max_hp)
	a.is_alive = a.current_hp > 0
	a.speed = int(template.speed)
	a.feature_uses["creature_size"] = str(template.size)
	for feature in template.get("features", []):
		if not _forbidden(feature): a.features.append(feature.duplicate(true))
	return a

static func owner_of(actor: Character) -> String:
	return str(actor.get_meta("created_owner_id", "")) if actor != null else ""

## Owner-linked attack: bonus and DC are read live from the owner's casting.
static func attack_profile(owner: Character, actor: Character) -> Dictionary:
	var spell := DataLoader.get_spell(str(actor.get_meta("created_spell_id", "")))
	var attack: Dictionary = _template(spell, str(actor.get_meta("created_template_id", ""))).get("attack", {})
	var dc := SpellPermissionRules.save_dc(owner, spell)
	return {"id": "created_actor_attack", "name": str(attack.get("name", "")), "type": "weapon", "weapon_type": "simple", "ability": "STR", "attack_bonus_override": dc - 8, "damage": str(attack.get("damage", "1d4")), "damage_type": str(attack.get("damage_type", "force")), "range": int(attack.get("range", 1)), "long_range": int(attack.get("range", 1)), "properties": [], "save_dc": dc}

## Write live current HP back to the owning records before saving.
static func sync(owner: Character) -> void:
	for source in owner.spell_effects:
		var record: Dictionary = owner.spell_effects[source]
		if not record.has("created_actors"): continue
		for entry in record.created_actors.actors:
			if _live.has(str(entry.actor_id)): entry.current_hp = maxi(0, int(_live[str(entry.actor_id)].current_hp))

static func saved_record_error(dto: Dictionary, record: Dictionary) -> String:
	var data: Variant = record.get("created_actors")
	var spell := DataLoader.get_spell(str(record.get("spell_id", "")))
	if not data is Dictionary or (data.has("template_id") and (not data.template_id is String or str(data.template_id).is_empty())): return "invalid saved created actors"
	var template := _template(spell, str(data.get("template_id", "")))
	if template.is_empty() or not template_error(template).is_empty(): return "invalid saved created actors"
	for key in data:
		if str(key) not in RECORD_KEYS: return "invalid saved created actors"
	var source := str(record.get("source_id", ""))
	if record.get("caster_id", "") != dto.get("character_id", "") or not source.begins_with("spell:%s:" % str(dto.get("character_id", ""))) or record.get("concentration") != spell.get("concentration", false) or record.get("conditions", []) != []: return "invalid saved created actor source"
	if not _int(data.get("level"), 0, 9) or not data.get("actors") is Array: return "invalid saved created actors"
	var level := int(data.level)
	var mixed := is_mixed(_effect(spell))
	if mixed and data.has("template_id"): return "invalid saved created actors"
	if data.actors.size() not in creation_counts(_effect(spell), template, level): return "saved created actor count differs from its template"
	var control_error := CreatedCommandRules.saved_error(template, data)
	if not control_error.is_empty(): return control_error
	var maximum := value(template.max_hp, level)
	for i in data.actors.size():
		var e: Variant = data.actors[i]
		# Batch 058: entries of a mixed cast name their declared template; others never do (legacy shape).
		if not e is Dictionary or e.size() != (3 if mixed else 2) or (mixed and not e.get("template_id") is String): return "invalid saved created actor"
		var kind := _template(spell, str(e.template_id)) if mixed else template
		if kind.is_empty() or (mixed and str(e.template_id).is_empty()): return "invalid saved created actor"
		if str(e.get("actor_id", "")) != "%s:actor:%d" % [source, i + 1] or not _int(e.get("current_hp"), 0, value(kind.max_hp, level)): return "invalid saved created actor"
	return ""

## Combat host: owned living actors join the owner's side; ended ones leave.
## Batch 053 S-122: each arrival takes a legal, distinct destination: the
## confirmed pick when it is still legal, otherwise the nearest legal space in
## the authored range. With no legal space the actor does not enter (never overlaps).
static func attach(state: Node, owner: Character, origin: Vector2i, picks: Array = []) -> Array:
	var joined: Array = []
	var live := actors(owner)
	for entity in state.player_entities.duplicate():
		if entity.get("character") is Character and entity.character.has_meta("projected_item_id"): continue
		if entity.get("is_created_actor", false) and entity.get("created_owner_id", "") == owner.character_id and not live.has(entity.character):
			state.player_entities.erase(entity)
			state.tracker.remove_combatant(entity.character.character_id)
	var pending: Array = picks.duplicate()
	for a in live:
		if not a.is_alive or state.player_entities.any(func(e): return e.get("combat_id", "") == a.character_id): continue
		var record: Dictionary = owner.spell_effects.get(str(a.get_meta("created_source_id", "")), {})
		var spell := DataLoader.get_spell(str(record.get("spell_id", "")))
		var effect := {}
		for e in spell.get("effects", []):
			if e is Dictionary and e.get("type", "") == "create_actor": effect = e
		var policy := PlacementRules.policy(effect)
		var size := PhysicalFactsRules.get_size(a)
		var hex := Vector2i(9999, 9999)
		while not pending.is_empty() and hex == Vector2i(9999, 9999):
			var pick: Vector2i = pending.pop_front()
			if PlacementRules.legal_error(state, origin, pick, size, int(policy.range_hexes)).is_empty(): hex = pick
		if hex == Vector2i(9999, 9999):
			var nearest := PlacementRules.reserve(state, origin, size, int(policy.range_hexes), 1)
			if nearest.is_empty(): continue
			hex = nearest[0]
		state.player_entities.append({"name": a.character_name, "display_name": a.character_name, "character": a, "combat_id": a.character_id, "owner_player_index": -1, "hex_position": hex, "is_created_actor": true, "created_owner_id": owner.character_id, "reaction_available": true, "color": Color(0.5, 0.7, 0.9)})
		CreatedCommandRules.join_initiative(state, owner, a) # Batch 056 S-157.
		joined.append(a.character_id)
	state._update_grid_entities()
	return joined
