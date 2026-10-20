## S-163: a reversible retained-stat projection of an actual actor into a
## declared form. The exact cast's source record on the actor owns the
## projection. Physical scores and speed are set from the form while the
## originals are kept on the record; AC, size and (unless retained) creature
## type are read live from the selected form. Hit Points are always the
## actor's own: the form grants Temporary Hit Points instead. Spell slots and
## feature uses are never touched, so reversion restores the same actor
## without reacquiring or refilling anything.
class_name ActorProjectionRules
extends RefCounted

const FORM_KEYS := ["id", "name", "creature_type", "size", "speed", "ability_scores", "ac", "temp_hp", "attack"]
const ATTACK_KEYS := ["name", "damage", "damage_type", "range", "bonus"]
## "hp" is mandatory: a projection never replaces the actor's own Hit Points.
const RETAIN := ["hp", "creature_type", "mental_scores", "features", "spellcasting"]
const EFFECT_KEYS := ["type", "forms", "retain", "equipment"]
## S-164 legal equipment policies a projection may declare.
const EQUIPMENT := ["merged", "worn", "dropped"]
const RECORD_KEYS := ["form_id", "level", "original", "granted_temp_hp", "suppressed_features", "equipment"]
const MENTAL := ["INT", "WIS", "CHA"]

static func form_error(f: Variant) -> String:
	if not f is Dictionary: return "projection form must be an object"
	for key in f:
		if str(key) not in FORM_KEYS: return "projection form has unknown field '%s'" % key
	if str(f.get("id", "")).is_empty() or str(f.get("name", "")).is_empty(): return "projection form requires id and name"
	if str(f.get("creature_type", "")) not in CreatedActorRules.CREATURE_TYPES or str(f.get("size", "")) not in CreatedActorRules.SIZES: return "projection form requires a creature type and size"
	if not CreatedActorRules._int(f.get("speed"), 0, 24): return "projection form speed must be 0-24 hexes"
	var scores: Variant = f.get("ability_scores")
	if not scores is Dictionary or scores.size() != 6 or CreatedActorRules.ABILITIES.any(func(a): return not CreatedActorRules._int(scores.get(a), 1, 30)): return "projection form requires six ability scores 1-30"
	for pair in [["ac", 5, 25, 3], ["temp_hp", 0, 300, 50]]:
		var e := CreatedActorRules._formula_error(f.get(pair[0]), pair[1], pair[2], pair[3], pair[0])
		if not e.is_empty(): return "projection form " + e
	var attack: Variant = f.get("attack")
	if not attack is Dictionary or attack.size() != ATTACK_KEYS.size() or attack.keys().any(func(k): return str(k) not in ATTACK_KEYS) or str(attack.get("name", "")).is_empty() or not RegEx.create_from_string("^[1-9]d(4|6|8|10|12)$").search(str(attack.get("damage", ""))) or str(attack.get("damage_type", "")) not in CreatedActorRules.DAMAGE_TYPES or not CreatedActorRules._int(attack.get("range"), 1, 24) or not CreatedActorRules._int(attack.get("bonus"), -5, 20):
		return "projection form attack requires name, damage NdX, damage_type, range and bonus"
	return ""

static func effect_error(effect: Dictionary) -> String:
	for key in effect:
		if str(key) not in EFFECT_KEYS: return "Actor projection effects accept only type, forms, retain and equipment."
	if effect.has("equipment"):
		var eq: Variant = effect.equipment
		if not eq is Array or eq.is_empty() or eq.any(func(v): return not v is String or v not in EQUIPMENT) or eq.size() != _unique(eq).size(): return "actor projection equipment must list legal policies from %s" % str(EQUIPMENT)
	var forms: Variant = effect.get("forms")
	if not forms is Array or forms.is_empty() or forms.size() > 6: return "actor projection requires one to six forms"
	var ids: Array = []
	for f in forms:
		var e := form_error(f)
		if not e.is_empty(): return e
		if str(f.id) in ids: return "actor projection form ids must be unique"
		ids.append(str(f.id))
	var retain: Variant = effect.get("retain")
	if not retain is Array or "hp" not in retain or retain.any(func(r): return not r is String or r not in RETAIN) or retain.size() != _unique(retain).size(): return "actor projection retain must list hp and only %s" % str(RETAIN)
	return ""

static func _unique(values: Array) -> Array:
	var out: Array = []
	for v in values:
		if v not in out: out.append(v)
	return out

static func _effect(spell: Dictionary) -> Dictionary:
	for effect in spell.get("effects", []):
		if effect is Dictionary and effect.get("type", "") == "actor_projection": return effect
	return {}

static func _form(effect: Dictionary, form_id: String) -> Dictionary:
	for f in effect.get("forms", []):
		if str(f.get("id", "")) == form_id: return f
	return {}

## The active projection record (source, record, effect, form) or {}.
static func active(actor) -> Dictionary:
	if not actor is Character: return {}
	for source in actor.spell_effects:
		var record: Dictionary = actor.spell_effects[source]
		if not record.has("projection"): continue
		var effect := _effect(DataLoader.get_spell(str(record.get("spell_id", ""))))
		var form := _form(effect, str(record.projection.get("form_id", "")))
		if not form.is_empty(): return {"source": str(source), "record": record, "effect": effect, "form": form}
	return {}

static func is_projected(actor) -> bool:
	return not active(actor).is_empty()

static func retains(actor, what: String) -> bool:
	var a := active(actor)
	return a.is_empty() or what in a.effect.get("retain", [])

## Review R1: the same refusals apply() makes, checked before any cost is paid.
static func cast_error(caster, spell: Dictionary) -> String:
	var effect := _effect(spell)
	if effect.is_empty() or not caster is Character: return ""
	if is_projected(caster) or DruidRules.is_shaped(caster): return "You are already in another form."
	if effect.get("forms", []).size() != 1 and _form(effect, str(spell.get("_projection_form_id", ""))).is_empty(): return "A declared form must be selected."
	return ""

## Called by the shared actor_projection effect on the self-cast actor.
static func apply(actor: Character, cast: Dictionary, effect: Dictionary, slot_level: int, spell: Dictionary, form_id: String, equipment_policy: String = "") -> Dictionary:
	var source := str(cast.get("source_id", ""))
	if actor == null or source.is_empty() or actor.spell_effects.has(source) or not effect_error(effect).is_empty(): return {"projected": false, "reason": "invalid projection"}
	if is_projected(actor) or DruidRules.is_shaped(actor): return {"projected": false, "reason": "already in another form"}
	if form_id.is_empty() and effect.forms.size() == 1: form_id = str(effect.forms[0].id)
	var form := _form(effect, form_id)
	if form.is_empty(): return {"projected": false, "reason": "a declared form must be selected"}
	var legal: Array = effect.get("equipment", [])
	if equipment_policy.is_empty() and legal.size() == 1: equipment_policy = str(legal[0])
	if not legal.is_empty() and equipment_policy not in legal: return {"projected": false, "reason": "a legal equipment policy must be selected"}
	if legal.is_empty() and not equipment_policy.is_empty(): return {"projected": false, "reason": "this projection declares no equipment policy"}
	if spell.is_empty(): spell = DataLoader.get_spell(str(cast.get("spell_id", "")))
	var level := maxi(0, slot_level - int(spell.get("level", 0)))
	var granted := CreatedActorRules.value(form.temp_hp, level)
	var record := cast.duplicate(true)
	record["projection"] = {"form_id": form_id, "level": level, "original": {"ability_scores": actor.ability_scores.to_dict(), "speed": actor.speed}, "granted_temp_hp": granted, "suppressed_features": []}
	var scores := AbilityScores.new()
	scores.from_dict(form.ability_scores)
	if "mental_scores" in effect.retain:
		for ability in MENTAL: scores.set_score(ability, actor.ability_scores.get_score(ability))
	actor.ability_scores = scores
	actor.speed = int(form.speed)
	actor.temp_hp = maxi(actor.temp_hp, granted)
	if "features" not in effect.retain:
		record.projection.suppressed_features = actor.features.duplicate(true)
		actor.features.clear()
	var equipment_receipt := {}
	if not legal.is_empty():
		record.projection["equipment"] = _route_equipment(actor, equipment_policy)
		equipment_receipt = record.projection.equipment.duplicate(true)
	actor.spell_effects[source] = record
	return {"equipment": equipment_receipt, "projected": true, "source_id": source, "form_id": form_id, "level": level, "temp_hp": granted, "ac": ac(actor), "suppressed_features": record.projection.suppressed_features.size()}

## S-164: merged copies keep their slot with effects suppressed; dropped
## copies leave their slots (cursed copies cannot) and stay unequipped; worn
## copies keep working.
static func _route_equipment(actor: Character, policy: String) -> Dictionary:
	var out := {"policy": policy, "merged": [], "dropped": []}
	actor.inventory.copies.sync(actor.inventory)
	for slot in actor.inventory.copies.equipped.keys():
		var id := str(actor.inventory.copies.equipped[slot])
		if policy == "merged": out.merged.append(id)
		elif policy == "dropped" and not actor.inventory.unequip(slot).is_empty(): out.dropped.append(id)
	actor.inventory.copies.sync(actor.inventory)
	return out

static func equipment_policy(actor) -> String:
	var a := active(actor)
	return "" if a.is_empty() else str(a.record.projection.get("equipment", {}).get("policy", ""))

## True when this exact equipped copy is merged into the active form.
static func merged(actor, instance_id: String) -> bool:
	var a := active(actor)
	return not a.is_empty() and instance_id in a.record.projection.get("equipment", {}).get("merged", [])

## A merged or dropped form cannot don equipment.
static func equip_error(actor) -> String:
	return "" if equipment_policy(actor) in ["", "worn"] else "This form cannot don equipment."

## Revert from the ending record. Hit Points and resources stay as they are.
static func revert(actor, record: Dictionary) -> Dictionary:
	if not actor is Character or not record.get("projection") is Dictionary: return {}
	var p: Dictionary = record.projection
	var scores := AbilityScores.new()
	scores.from_dict(p.original.ability_scores)
	actor.ability_scores = scores
	actor.speed = int(p.original.speed)
	var granted := int(p.get("granted_temp_hp", 0))
	if granted > 0 and actor.temp_hp <= granted: actor.temp_hp = 0
	var present: Array = actor.features.map(func(f): return str(f.get("id", "")))
	var restored := 0
	for f in p.get("suppressed_features", []):
		if f is Dictionary and str(f.get("id", "")) not in present:
			actor.features.append(f.duplicate(true))
			restored += 1
	var receipt := {"reverted": true, "form_id": str(p.form_id), "restored_features": restored, "current_hp": actor.current_hp}
	var eq: Dictionary = p.get("equipment", {})
	if not eq.is_empty():
		var owned: Array = actor.inventory.owned_instances().map(func(c): return str(c.instance_id))
		receipt["equipment_policy"] = str(eq.policy)
		receipt["merged_restored"] = eq.merged.filter(func(id): return id in owned)
		receipt["merged_lost"] = eq.merged.filter(func(id): return id not in owned)
		receipt["dropped"] = eq.dropped.duplicate()
	return receipt

## Reapply live suppression after a reload rebuilt class features.
static func restore(actor: Character) -> void:
	var a := active(actor)
	if a.is_empty() or "features" in a.effect.retain: return
	actor.features.clear()

static func ac(actor) -> int:
	var a := active(actor)
	if a.is_empty(): return -1
	var value: int = CreatedActorRules.value(a.form.ac, int(a.record.projection.level)) + actor.get_modifier("stat", "AC") + actor.inventory.magic_item_saving_bonus(actor.character_id)
	if actor.has_condition("shield"): value += 5
	return value

static func creature_type(actor) -> String:
	var a := active(actor)
	return "" if a.is_empty() or "creature_type" in a.effect.retain else str(a.form.creature_type)

static func size(actor) -> String:
	var a := active(actor)
	return "" if a.is_empty() else str(a.form.size)

static func can_cast_spells(actor) -> bool:
	return retains(actor, "spellcasting")

static func attack_profile(actor) -> Dictionary:
	var a := active(actor)
	if a.is_empty(): return {}
	var at: Dictionary = a.form.attack
	return {"id": "projection_attack", "name": str(at.name), "type": "weapon", "weapon_type": "simple", "ability": "STR", "attack_bonus_override": int(at.bonus), "damage": str(at.damage), "damage_type": str(at.damage_type), "range": int(at.range), "long_range": int(at.range), "properties": []}

static func saved_record_error(dto: Dictionary, record: Dictionary) -> String:
	var p: Variant = record.get("projection")
	var effect := _effect(DataLoader.get_spell(str(record.get("spell_id", ""))))
	if not p is Dictionary or effect.is_empty() or not effect_error(effect).is_empty(): return "invalid saved projection"
	for key in p:
		if str(key) not in RECORD_KEYS: return "invalid saved projection"
	var form := _form(effect, str(p.get("form_id", "")))
	if form.is_empty(): return "saved projection form is not declared"
	var source := str(record.get("source_id", ""))
	if record.get("caster_id", "") != dto.get("character_id", "") or not source.begins_with("spell:%s:" % str(dto.get("character_id", ""))) or record.get("conditions", []) != []: return "invalid saved projection source"
	if not CreatedActorRules._int(p.get("level"), 0, 9) or int(p.get("granted_temp_hp", -1)) != CreatedActorRules.value(form.temp_hp, int(p.level)): return "saved projection level differs from its form"
	var original: Variant = p.get("original")
	if not original is Dictionary or original.size() != 2 or not original.get("ability_scores") is Dictionary or original.ability_scores.size() != 6 or CreatedActorRules.ABILITIES.any(func(x): return not CreatedActorRules._int(original.ability_scores.get(x), 1, 30)) or not CreatedActorRules._int(original.get("speed"), 0, 60): return "invalid saved projection original"
	var scores: Variant = dto.get("ability_scores", {})
	for ability in ["STR", "DEX", "CON"]:
		if not scores is Dictionary or int(scores.get(ability, -1)) != int(form.ability_scores[ability]): return "saved actor scores contradict its projection"
	for ability in MENTAL:
		var expected := int(original.ability_scores[ability]) if "mental_scores" in effect.retain else int(form.ability_scores[ability])
		if int(scores.get(ability, -1)) != expected: return "saved actor scores contradict its projection"
	var suppressed: Variant = p.get("suppressed_features")
	if not suppressed is Array or suppressed.size() > 64 or suppressed.any(func(f): return not f is Dictionary or str(f.get("id", "")).is_empty()) or ("features" in effect.retain and not suppressed.is_empty()): return "invalid saved projection features"
	var eq: Variant = p.get("equipment", null)
	var legal: Array = effect.get("equipment", [])
	if legal.is_empty() != (eq == null): return "saved projection equipment contradicts its effect"
	if eq != null:
		if not eq is Dictionary or eq.size() != 3 or str(eq.get("policy", "")) not in legal or not eq.get("merged") is Array or not eq.get("dropped") is Array: return "invalid saved projection equipment"
		if eq.merged.any(func(v): return not v is String) or eq.dropped.any(func(v): return not v is String) or eq.merged.size() > 16 or eq.dropped.size() > 16: return "invalid saved projection equipment"
		if (eq.policy != "merged" and not eq.merged.is_empty()) or (eq.policy != "dropped" and not eq.dropped.is_empty()): return "saved projection equipment contradicts its policy"
		var slots: Array = dto.get("inventory", {}).get("copies", {}).get("equipped", {}).values()
		if eq.dropped.any(func(id): return id in slots): return "saved dropped equipment is still worn"
	return ""

## Projection grants Temporary HP, not a second HP pool; the DTO must hold one projection.
static func saved_state_error(dto: Dictionary) -> String:
	var count := 0
	for record in dto.get("spell_effects", {}).values():
		if record is Dictionary and record.has("projection"): count += 1
	if count > 1: return "saved actor holds more than one projection"
	if count == 1 and dto.get("wild_shape_state", {}) is Dictionary and not dto.get("wild_shape_state", {}).is_empty(): return "saved actor is projected while in Wild Shape"
	return ""
