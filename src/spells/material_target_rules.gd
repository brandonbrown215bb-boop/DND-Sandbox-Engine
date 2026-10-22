class_name MaterialTargetRules
extends RefCounted
## Batch 059 (S-155): a create_actor effect may declare the material targets each
## creature needs (e.g. Animate Dead's corpses or piles of bones). The cast then
## creates at most min(slot count, eligible targets nearby), and each creature
## uses up one target. Data-driven only: no spell or creature ids are read here.

const KEYS := ["tags", "range", "creature_types", "sizes", "kinds"]
const TAGS := ["corpse", "bones"]
const REMAINS_TAG := {"intact": "corpse", "partial": "corpse", "bones": "bones"}
const USED := "transformed_undead" # Existing saved corpse restriction; marks a used body.

static func spec(effect: Dictionary) -> Dictionary:
	return effect.material_targets if effect.get("material_targets") is Dictionary else {}

## Loader check; "" when the key is absent (legacy content unchanged).
static func error(effect: Dictionary) -> String:
	if not effect.has("material_targets"): return ""
	var s: Variant = effect.material_targets
	if not s is Dictionary: return "create_actor material_targets must be an object"
	for key in s:
		if str(key) not in KEYS: return "create_actor material_targets has unknown field '%s'" % key
	var tags: Variant = s.get("tags")
	if not tags is Array or tags.is_empty() or tags.any(func(t): return not t is String or t not in TAGS): return "create_actor material_targets tags must list corpse and/or bones"
	var r: Variant = s.get("range")
	if not (r is int or r is float) or float(r) != floor(float(r)) or int(r) < 0 or int(r) > 24: return "create_actor material_targets range must be 0-24 hexes"
	for pair in [["creature_types", CreatedActorRules.CREATURE_TYPES], ["sizes", CreatedActorRules.SIZES]]:
		if not s.has(pair[0]): continue
		var list: Variant = s[pair[0]]
		if not list is Array or list.is_empty() or list.any(func(x): return not x is String or x not in pair[1]): return "create_actor material_targets %s is invalid" % pair[0]
	if s.has("kinds"):
		var kinds: Variant = s.kinds
		var ids := CreatedActorRules.templates(effect).map(func(t): return str(t.id))
		if not kinds is Dictionary or kinds.is_empty(): return "create_actor material_targets kinds must map template ids to tags"
		for id in kinds:
			if str(id) not in ids or not kinds[id] is String or kinds[id] not in tags: return "create_actor material_targets kinds must map declared templates to declared tags"
	return ""

## Eligible targets near the caster, nearest first: [{ref, tag, distance}].
static func eligible(cast: SpellCastContext, s: Dictionary) -> Array:
	var out: Array = []
	if cast.player_index < 0 or cast.player_index >= cast.players.size(): return out
	var origin: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
	for entry in cast.players + cast.monsters:
		var tag := _tag(entry, s)
		if tag.is_empty(): continue
		var d := HexUtils.get_distance(origin, entry.get("hex_position", Vector2i(9999, 9999)))
		if d <= int(s.range): out.append({"ref": entry, "tag": tag, "distance": d})
	out.sort_custom(func(a, b): return a.distance < b.distance)
	return out

static func _tag(entry: Dictionary, s: Dictionary) -> String:
	var remains := ""
	var kind := ""
	var size := ""
	var c: Variant = entry.get("character")
	if c is Character:
		if not c.is_dead() or USED in c.corpse_state.get("recovery_restrictions", []): return ""
		if CorpseRules.protected_from_undeath(c, int(GameManager.campaign_elapsed_seconds)): return ""
		remains = str(c.corpse_state.get("remains", ""))
		kind = str(c.creature_type)
		size = str(c.get_creature_size())
	else:
		if entry.get("is_alive", true) or bool(entry.get("material_used", false)): return ""
		remains = str(entry.get("remains", "intact"))
		kind = str(entry.get("creature_type", ""))
		size = str(entry.get("size", "medium"))
	if s.has("creature_types") and kind.to_lower() not in s.creature_types: return ""
	if s.has("sizes") and size.to_lower() not in s.sizes: return ""
	var tag: String = REMAINS_TAG.get(remains, "")
	return tag if tag in s.tags else ""

## The cap a cast may use: {"total": n, "kinds": {template_id: n}}; {} when the effect declares none.
static func cap(cast: SpellCastContext, effect: Dictionary) -> Dictionary:
	var s := spec(effect)
	if s.is_empty(): return {}
	var found := eligible(cast, s)
	var out := {"total": found.size(), "kinds": {}}
	for id in s.get("kinds", {}):
		out.kinds[str(id)] = found.filter(func(f): return f.tag == str(s.kinds[id])).size()
	return out

## Refusal for a chosen mix against the cap; "" when within it.
static func mix_cap_error(mix: Dictionary, c: Dictionary) -> String:
	if c.is_empty(): return ""
	var total := 0
	for id in mix:
		total += int(mix[id])
		if c.kinds.has(str(id)) and int(mix[id]) > int(c.kinds[str(id)]): return "not_enough_material"
	return "" if total <= int(c.total) else "not_enough_material"

## After a successful cast: each created creature uses one nearby target (kind's tag first).
static func reservation(cast: SpellCastContext, effect: Dictionary, factory: Dictionary) -> Array:
	var s := spec(effect)
	if s.is_empty(): return []
	var found := eligible(cast, s)
	var mix: Dictionary = factory.get("mix", {}) if factory.get("mix", {}) is Dictionary else {}
	var wanted: Array = []
	if mix.is_empty():
		var kind := str(factory.get("template_id", effect.get("template", {}).get("id", "")))
		for _n in int(factory.get("count", 0)): wanted.append(str(s.get("kinds", {}).get(kind, "")))
	for id in mix:
		for _n in int(mix[id]): wanted.append(str(s.get("kinds", {}).get(id, "")))
	# Review 059 R1: tagged kinds claim their remains before any-tag kinds, so an
	# undeclared kind cannot take the only pile a declared kind needs.
	wanted.sort_custom(func(a, b): return a != null and not str(a).is_empty() and (b == null or str(b).is_empty()))
	var picks: Array = []
	for tag in wanted:
		for f in found:
			if f.has("used") or (tag != null and not str(tag).is_empty() and f.tag != tag): continue
			f["used"] = true
			picks.append(f.ref)
			break
	return picks

static func _consume_refs(picks: Array) -> int:
	var used := 0
	for entry in picks:
		var c: Variant = entry.get("character")
		if c is Character:
			if USED in c.corpse_state.get("recovery_restrictions", []): continue
			c.corpse_state["recovery_restrictions"].append(USED)
		else:
			if bool(entry.get("material_used", false)): continue
			entry["material_used"] = true
		used += 1
	return used

static func consume(cast: SpellCastContext, effect: Dictionary, factory: Dictionary) -> int:
	return _consume_refs(reservation(cast, effect, factory))

## Only an actual created source consumes its reserved remains. A paid no-space
## result or a refused creation has no source, so it cannot destroy any bodies.
static func consume_created(cast: SpellCastContext) -> int:
	var source := str(cast.spell.get("_effect_cast", {}).get("source_id", ""))
	var record: Dictionary = cast.caster.spell_effects.get(source, {})
	var made: Dictionary = record.get("created_actors", {})
	if made.is_empty() or cast.material_targets.size() != made.get("actors", []).size(): return 0
	return _consume_refs(cast.material_targets)
