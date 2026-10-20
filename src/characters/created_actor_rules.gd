## S-154: a parameterized actor created from a declared template by an exact
## cast. The cast's source record on the owner owns the actor's lifetime; AC,
## maximum HP and count derive from the template and paid level above the
## spell's base level, attack/DC are read live from the owner, and current HP
## is tracked separately. Forbidden creation features are never copied.
class_name CreatedActorRules
extends RefCounted

const TEMPLATE_KEYS := ["id", "name", "creature_type", "size", "speed", "ability_scores", "ac", "max_hp", "count", "attack", "features"]
const CREATURE_TYPES := ["aberration", "beast", "celestial", "construct", "dragon", "elemental", "fey", "fiend", "giant", "humanoid", "monstrosity", "ooze", "plant", "undead"]
const SIZES := ["tiny", "small", "medium", "large", "huge", "gargantuan"]
const DAMAGE_TYPES := ["acid", "bludgeoning", "cold", "fire", "force", "lightning", "necrotic", "piercing", "poison", "psychic", "radiant", "slashing", "thunder"]
const ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
## A created actor never inherits the means to create, upgrade or cast.
const FORBIDDEN_FEATURE_TYPES := ["create_actor", "mode_choice", "rule_upgrade", "resource", "zero_hp_replacement", "spellcasting"]
const RECORD_KEYS := ["level", "actors"]

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
	var features: Variant = t.get("features", [])
	if not features is Array or features.size() > 8 or features.any(func(f): return not f is Dictionary or str(f.get("id", "")).is_empty()): return "create_actor template features must be up to eight records with ids"
	return ""

static func value(formula: Dictionary, level: int) -> int:
	var v := int(formula.base) + int(formula.get("per_level", 0)) * maxi(0, level)
	return mini(v, int(formula.max)) if formula.has("max") else v

static func _template(spell: Dictionary) -> Dictionary:
	for effect in spell.get("effects", []):
		if effect is Dictionary and effect.get("type", "") == "create_actor": return effect.get("template", {})
	return {}

static func _forbidden(feature: Dictionary) -> bool:
	if str(feature.get("type", "")) in FORBIDDEN_FEATURE_TYPES or feature.has("spellcasting"): return true
	for effect in feature.get("effects", []) + feature.get("passive_effects", []):
		if effect is Dictionary and str(effect.get("type", "")) in FORBIDDEN_FEATURE_TYPES: return true
	return false

## Called by the shared create_actor effect on the self-cast owner.
static func create(owner: Character, cast: Dictionary, template: Dictionary, slot_level: int, spell: Dictionary) -> Dictionary:
	var source := str(cast.get("source_id", ""))
	if owner == null or source.is_empty() or owner.spell_effects.has(source) or cast.get("caster_id", "") != owner.character_id or not template_error(template).is_empty(): return {"created": false}
	if spell.is_empty(): spell = DataLoader.get_spell(str(cast.get("spell_id", "")))
	var level := maxi(0, slot_level - int(spell.get("level", 0)))
	var count := value(template.count, level)
	var maximum := value(template.max_hp, level)
	var record := cast.duplicate(true)
	record["created_actors"] = {"level": level, "actors": []}
	for i in count:
		record.created_actors.actors.append({"actor_id": "%s:actor:%d" % [source, i + 1], "current_hp": maximum})
	owner.spell_effects[source] = record
	var made := actors(owner).filter(func(a): return a.get_meta("created_source_id", "") == source)
	return {"created": true, "source_id": source, "level": level, "count": count, "max_hp": maximum, "ac": value(template.ac, level), "actor_ids": made.map(func(a): return a.character_id), "excluded_features": template.get("features", []).filter(func(f): return _forbidden(f)).map(func(f): return str(f.id))}

## Live actors whose source still exists; ended sources take their actors away.
static func actors(owner: Character) -> Array:
	var out: Array = []
	if owner == null: return out
	for source in owner.spell_effects:
		var record: Dictionary = owner.spell_effects[source]
		if not record.has("created_actors"): continue
		var spell := DataLoader.get_spell(str(record.get("spell_id", "")))
		var template := _template(spell)
		if template.is_empty(): continue
		for entry in record.created_actors.actors:
			var id := str(entry.actor_id)
			# Review R1: a reloaded owner is a new object; rebuild from its saved record, never a stale cache.
			if not _live.has(id) or _live[id].get_meta("created_owner_instance", 0) != owner.get_instance_id(): _live[id] = _build(owner, str(source), template, int(record.created_actors.level), entry, spell)
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
	var attack: Dictionary = _template(spell).get("attack", {})
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
	var template := _template(spell)
	if not data is Dictionary or template.is_empty() or not template_error(template).is_empty(): return "invalid saved created actors"
	for key in data:
		if str(key) not in RECORD_KEYS: return "invalid saved created actors"
	var source := str(record.get("source_id", ""))
	if record.get("caster_id", "") != dto.get("character_id", "") or not source.begins_with("spell:%s:" % str(dto.get("character_id", ""))) or record.get("concentration") != spell.get("concentration", false) or record.get("conditions", []) != []: return "invalid saved created actor source"
	if not _int(data.get("level"), 0, 9) or not data.get("actors") is Array: return "invalid saved created actors"
	var level := int(data.level)
	if data.actors.size() != value(template.count, level): return "saved created actor count differs from its template"
	var maximum := value(template.max_hp, level)
	for i in data.actors.size():
		var e: Variant = data.actors[i]
		if not e is Dictionary or e.size() != 2 or str(e.get("actor_id", "")) != "%s:actor:%d" % [source, i + 1] or not _int(e.get("current_hp"), 0, maximum): return "invalid saved created actor"
	return ""

## Combat host: owned living actors join the owner's side; ended ones leave.
static func attach(state: Node, owner: Character, origin: Vector2i) -> Array:
	var joined: Array = []
	var live := actors(owner)
	for entity in state.player_entities.duplicate():
		if entity.get("is_created_actor", false) and entity.get("created_owner_id", "") == owner.character_id and not live.has(entity.character):
			state.player_entities.erase(entity)
			state.tracker.remove_combatant(entity.character.character_id)
	var offset := 1
	for a in live:
		if not a.is_alive or state.player_entities.any(func(e): return e.get("combat_id", "") == a.character_id): continue
		state.player_entities.append({"name": a.character_name, "display_name": a.character_name, "character": a, "combat_id": a.character_id, "owner_player_index": -1, "hex_position": origin + Vector2i(0, offset), "is_created_actor": true, "created_owner_id": owner.character_id, "reaction_available": true, "color": Color(0.5, 0.7, 0.9)})
		offset += 1
		joined.append(a.character_id)
	state._update_grid_entities()
	return joined
