## Scoped actual attack/cast profiles (S-126).
##
## Source-owned `attack_profile` features replace or add to the fields of one
## actual weapon attack or spell save DC. The catalog record is never mutated:
## weapon data is already a per-attack copy and spell DCs are computed values.
## Replacements from the first qualifying source win; additive fields sum;
## fields no source names are inherited unchanged. No content ID is branched on.
class_name AttackProfileRules
extends RefCounted

const ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const REPLACE_KEYS := ["ability", "damage_die", "damage_type", "damage_type_choices", "attack_bonus", "save_dc", "range_feet", "school", "casting_time"]
const ADD_KEYS := ["attack_bonus", "damage_bonus", "save_dc", "range_feet"]
## S-140 (Batch 085): fields a spell-scoped profile may change on one invocation.
const SPELL_REPLACE_KEYS := ["save_dc", "range_feet", "school", "casting_time"]
const SPELL_ADD_KEYS := ["save_dc", "range_feet"]
## Batch 085 bound: only Verbal and Somatic may be removed; Material stays
## (costly/consumed materials and focus rules are not transformed here).
const REMOVABLE_COMPONENTS := ["V", "S"]
## Batch 085 bound: timing may become an Action or Bonus Action; reaction or
## long casting times are not produced or transformed.
const CAST_TIMINGS := ["action", "bonus_action"]
const CAST_PROFILE_KEY := "_cast_profile"
const SCOPE_KEYS := ["kind", "ids", "properties_all", "schools", "permission_sources", "melee"]
const RULE_KEYS := ["id", "name", "type", "description", "enabled", "level", "rules_status", "source", "notes", "srd_page", "source_instance_id", "scope", "required_condition", "replace", "add", "remove", "choice_window", "choice_duration"]
## S-127: a damage-type choice names the window where it is offered. There is
## no default: data must say "activation" (before the attack is committed) or
## "hit" (after a final hit, before damage is rolled).
const CHOICE_WINDOWS := ["activation", "hit"]
## Batch 077 (#39 follow-up): how long one answer lasts. "attack" asks again
## on every swing and the pick applies to that one attack only; "attack_action"
## carries the pick to the remaining swings of the same Attack action. Brandon:
## "Carry it across the Attack action only when the feature says it lasts that
## long." A rule that omits the key is read as "attack" (the ruling's base case,
## never a carry); any other value is refused.
const CHOICE_DURATIONS := ["attack", "attack_action"]
const DECISION_KEY := "attack_profile_damage_type"
const ALLOW_KEY := "allow_attack_profile_choice"
static var _requests := {}
static var _serial := 0

static func validate_rule(rule: Dictionary) -> String:
	if str(rule.get("source_instance_id", "")).is_empty(): return "attack_profile needs source_instance_id"
	var scope: Variant = rule.get("scope", null)
	if not scope is Dictionary or str(scope.get("kind", "")) not in ["weapon", "spell"]: return "attack_profile scope.kind must be weapon or spell"
	# Reviewer (Batch 085): an unknown scope key (e.g. "school" for "schools") would
	# silently widen the scope to every spell; an unknown operation would be dropped.
	for key in scope:
		if str(key) not in SCOPE_KEYS: return "attack_profile scope.%s is not a supported scope key" % str(key)
	for key in rule:
		if str(key) not in RULE_KEYS and not str(key).begins_with("_"): return "attack_profile %s is not a supported field" % str(key)
	for key in ["ids", "properties_all", "schools", "permission_sources"]:
		if scope.has(key) and (not scope[key] is Array or scope[key].any(func(v): return not v is String)): return "attack_profile scope.%s must be strings" % key
	if scope.has("melee") and not scope["melee"] is bool: return "attack_profile scope.melee must be boolean"
	if rule.has("required_condition") and (not rule["required_condition"] is String or str(rule["required_condition"]).is_empty()): return "attack_profile required_condition is invalid"
	var replace: Variant = rule.get("replace", {})
	var add: Variant = rule.get("add", {})
	var remove: Variant = rule.get("remove", {})
	if not replace is Dictionary or not add is Dictionary or not remove is Dictionary or (replace.is_empty() and add.is_empty() and remove.is_empty()): return "attack_profile needs replace, add or remove fields"
	if not remove.is_empty():
		if str(scope.kind) != "spell": return "attack_profile remove is only for spell profiles"
		if remove.keys().any(func(k): return str(k) != "components"): return "attack_profile remove supports only components"
		if not remove.components is Array or remove.components.is_empty() or remove.components.any(func(c): return str(c) not in REMOVABLE_COMPONENTS): return "attack_profile remove.components must list V or S"
	if scope.has("permission_sources") and str(scope.kind) != "spell": return "attack_profile permission_sources is only for spell profiles"
	if replace.has("range_feet") and not _range(replace.range_feet): return "attack_profile replace.range_feet must be a positive multiple of 5"
	if add.has("range_feet") and not (_range(add.range_feet) and int(add.range_feet) > 0): return "attack_profile add.range_feet must be a positive multiple of 5"
	if replace.has("school") and str(replace.school) not in DataLoader.VALID_SPELL_SCHOOLS: return "attack_profile school is invalid"
	if replace.has("casting_time") and str(replace.casting_time) not in CAST_TIMINGS: return "attack_profile casting_time must be action or bonus_action"
	for key in replace:
		if str(key) not in REPLACE_KEYS: return "attack_profile cannot replace %s" % str(key)
	for key in add:
		if str(key) not in ADD_KEYS or not (_int(add[key]) or (str(key) == "range_feet" and _range(add[key]))): return "attack_profile add.%s must be a supported integer" % str(key)
	if replace.has("ability") and str(replace.ability) not in ABILITIES: return "attack_profile ability is invalid"
	if replace.has("damage_die") and not RegEx.create_from_string("^[1-9][0-9]?d(4|6|8|10|12)$").search(str(replace.damage_die)): return "attack_profile damage_die is invalid"
	if replace.has("damage_type") and str(replace.damage_type) not in DataLoader.VALID_DAMAGE_TYPES: return "attack_profile damage_type is invalid"
	if replace.has("damage_type_choices") and (not replace.damage_type_choices is Array or replace.damage_type_choices.is_empty() or replace.damage_type_choices.any(func(t): return str(t) not in DataLoader.VALID_DAMAGE_TYPES)): return "attack_profile damage_type_choices are invalid"
	if replace.has("damage_type_choices") and str(rule.get("choice_window", "")) not in CHOICE_WINDOWS: return "attack_profile damage_type_choices need choice_window activation or hit"
	if rule.has("choice_window") and not replace.has("damage_type_choices"): return "attack_profile choice_window needs damage_type_choices"
	if rule.has("choice_duration") and not replace.has("damage_type_choices"): return "attack_profile choice_duration needs damage_type_choices"
	if rule.has("choice_duration") and str(rule.choice_duration) not in CHOICE_DURATIONS: return "attack_profile choice_duration must be attack or attack_action"
	if replace.has("damage_type_choices") and replace.has("damage_type"): return "attack_profile cannot replace both damage_type and damage_type_choices"
	for key in ["attack_bonus", "save_dc"]:
		if replace.has(key) and not _int(replace[key]): return "attack_profile replace.%s must be an integer" % key
	if str(scope.kind) == "spell" and (replace.keys().any(func(k): return str(k) not in SPELL_REPLACE_KEYS) or add.keys().any(func(k): return str(k) not in SPELL_ADD_KEYS)): return "spell attack_profile supports only save_dc, range_feet, school and casting_time"
	if str(scope.kind) == "weapon" and (replace.keys().any(func(k): return str(k) in ["save_dc", "range_feet", "school", "casting_time"]) or add.has("save_dc") or add.has("range_feet")): return "weapon attack_profile cannot change spell fields"
	return ""

static func rules(actor: Character, kind: String) -> Array:
	var out: Array = []
	if actor == null: return out
	for feature in actor.features:
		if feature is Dictionary and str(feature.get("type", "")) == "attack_profile" and str(feature.get("scope", {}).get("kind", "")) == kind and validate_rule(feature).is_empty():
			var condition := str(feature.get("required_condition", ""))
			if condition.is_empty() or actor.has_condition(condition): out.append(feature)
	return out

static func _weapon_qualifies(rule: Dictionary, weapon: Dictionary) -> bool:
	var scope: Dictionary = rule.scope
	if scope.has("ids") and str(weapon.get("id", "")) not in scope.ids: return false
	for p in scope.get("properties_all", []):
		if p not in weapon.get("properties", []): return false
	if scope.has("melee"):
		var melee: bool = int(weapon.get("range", 1)) <= 1 and "ranged" not in weapon.get("properties", [])
		if melee != bool(scope.melee): return false
	return true

## Returns the transformed per-attack copy; the input is not mutated.
static func apply_weapon(attacker: Character, weapon_data: Dictionary, decisions: Dictionary = {}) -> Dictionary:
	var profile := weapon_data.duplicate(true)
	var applied: Array = []
	var replaced := {}
	var attack_add := 0
	var damage_add := 0
	for rule in rules(attacker, "weapon"):
		if not _weapon_qualifies(rule, weapon_data): continue
		applied.append(str(rule.source_instance_id))
		for key in rule.get("replace", {}):
			if not replaced.has(key): replaced[key] = rule.replace[key]
		attack_add += int(rule.get("add", {}).get("attack_bonus", 0))
		damage_add += int(rule.get("add", {}).get("damage_bonus", 0))
	if applied.is_empty(): return profile
	if replaced.has("ability"):
		var old := str(profile.get("ability", "STR"))
		profile["ability"] = str(replaced.ability)
		profile["damage"] = str(profile.get("damage", "1")).replace(old, str(replaced.ability))
	if replaced.has("damage_die"):
		var formula := str(profile.get("damage", "1"))
		var head := formula.split("+")[0].strip_edges()
		profile["damage"] = str(replaced.damage_die) + formula.substr(formula.find(head) + head.length()) if "d" in head else str(replaced.damage_die) + "+" + formula
	if replaced.has("damage_type_choices"):
		var chosen := str(decisions.get("attack_profile_damage_type", ""))
		if chosen in replaced.damage_type_choices: profile["damage_type"] = chosen
		else: chosen = ""
	elif replaced.has("damage_type"):
		profile["damage_type"] = str(replaced.damage_type)
	if replaced.has("attack_bonus"): profile["attack_bonus_override"] = int(replaced.attack_bonus)
	if attack_add != 0:
		var base := int(profile.get("attack_bonus_override", attacker.ability_scores.get_ability_modifier(str(profile.get("ability", "STR"))) + attacker.proficiency_bonus))
		profile["attack_bonus_override"] = base + attack_add
	if damage_add != 0: profile["damage"] = str(profile.get("damage", "1")) + ("+%d" % damage_add if damage_add > 0 else "%d" % damage_add)
	profile["_attack_profile"] = {"sources": applied, "replaced": replaced.keys(), "attack_add": attack_add, "damage_add": damage_add}
	if replaced.has("damage_type_choices"): profile["_attack_profile"]["damage_type_choice"] = str(decisions.get(DECISION_KEY, "")) if str(decisions.get(DECISION_KEY, "")) in replaced.damage_type_choices else ""
	return profile

## S-127: the winning damage-type choice for this actor and weapon, if any:
## {"source_instance_id", "name", "window", "options"}. The first qualifying
## source that replaces the type wins, exactly as apply_weapon resolves it.
static func damage_type_choice(attacker: Character, weapon_data: Dictionary) -> Dictionary:
	for rule in rules(attacker, "weapon"):
		if not _weapon_qualifies(rule, weapon_data): continue
		var replace: Dictionary = rule.get("replace", {})
		if replace.has("damage_type"): return {}
		if replace.has("damage_type_choices"):
			return {"source_instance_id": str(rule.source_instance_id), "name": str(rule.get("name", rule.get("id", "Attack profile"))), "window": str(rule.choice_window), "duration": str(rule.get("choice_duration", "attack")), "options": replace.damage_type_choices.duplicate()}
	return {}

## Batch 077: the pick an earlier swing of this Attack action carries to the
## next swing, or "" when the next swing must ask again. Only a rule that
## declares choice_duration "attack_action" carries, only from the same source,
## and only while the carried type is still one of its options.
static func carried_choice(attacker: Character, weapon_data: Dictionary, carried: Dictionary) -> String:
	var current := damage_type_choice(attacker, weapon_data)
	if current.is_empty() or str(current.duration) != "attack_action": return ""
	if str(carried.get("source_instance_id", "")) != str(current.source_instance_id): return ""
	var chosen := str(carried.get("damage_type", ""))
	return chosen if chosen in current.options else ""

## Batch 077: the record a host keeps for the rest of the Attack action, or {}
## when the rule lasts one attack (nothing is kept, so the next swing asks).
static func carry_record(attacker: Character, weapon_data: Dictionary, chosen: String) -> Dictionary:
	var current := damage_type_choice(attacker, weapon_data)
	if chosen.is_empty() or current.is_empty() or str(current.duration) != "attack_action" or chosen not in current.options: return {}
	return {"source_instance_id": str(current.source_instance_id), "damage_type": chosen}

## Re-check a choice made at the activation window just before the attack is
## committed. Returns "" when still offered, else the refusal message.
static func activation_choice_error(attacker: Character, weapon_data: Dictionary, offered: Dictionary, chosen: String) -> String:
	var current := damage_type_choice(attacker, weapon_data)
	if current.is_empty() or str(current.source_instance_id) != str(offered.get("source_instance_id", "")) or str(current.window) != "activation": return "The damage-type choice is no longer offered; nothing was spent."
	if chosen not in current.options: return "%s is no longer an eligible damage type; nothing was spent." % chosen.capitalize()
	return ""

## Called by the weapon resolver once a final hit is known. When the caller
## hosts the choice (ALLOW_KEY) and a hit-window choice is undecided, the hit
## stage is captured and a request is returned instead of rolling damage.
static func hit_window_request(attacker: Character, weapon_data: Dictionary, decisions: Dictionary, stage: Dictionary) -> Dictionary:
	if not bool(decisions.get(ALLOW_KEY, false)) or decisions.has(DECISION_KEY): return {}
	var choice := damage_type_choice(attacker, weapon_data)
	if choice.is_empty() or str(choice.window) != "hit": return {}
	_serial += 1
	var request_id := "attack_profile_choice:%d" % _serial
	_requests[request_id] = {"stage": stage, "choice": choice}
	var attack_result: Dictionary = stage.get("attack_result", {})
	return {"hit": true, "pending": true, "attack_roll": int(attack_result.get("total", 0)), "target_ac": int(stage.get("target_ac", 0)), "attack_profile_choice_request": {"request_id": request_id, "options": choice.options.duplicate(), "source_instance_id": choice.source_instance_id, "name": choice.name}}

## Settle a captured hit with the chosen type. An empty or no-longer-eligible
## choice keeps the inherited type; the hit itself already happened and the
## choice costs nothing. Each request settles once.
static func resume_hit_choice(request: Dictionary, chosen: String) -> Dictionary:
	var request_id := str(request.get("attack_profile_choice_request", {}).get("request_id", ""))
	if not _requests.has(request_id): return {"hit": false, "refused": true, "message": "This damage-type choice was already settled."}
	var record: Dictionary = _requests[request_id]
	_requests.erase(request_id)
	var stage: Dictionary = record.stage
	var weapon_data: Dictionary = stage.weapon_data
	var current := damage_type_choice(stage.attacker, weapon_data)
	var applied := ""
	if not chosen.is_empty() and not current.is_empty() and str(current.source_instance_id) == str(record.choice.source_instance_id) and chosen in current.options:
		weapon_data["damage_type"] = chosen
		applied = chosen
	var profile: Dictionary = weapon_data.get("_attack_profile", {})
	profile["damage_type_choice"] = applied
	weapon_data["_attack_profile"] = profile
	stage.reaction_decisions[DECISION_KEY] = applied
	var settled: Dictionary = CombatAction._settle_weapon_attack_hit(stage)
	settled["attack_profile_damage_type"] = applied
	settled["attack_profile_choice_stale"] = not chosen.is_empty() and applied.is_empty()
	return settled

## Computed spell save DC after qualifying scoped profiles.
static func spell_dc(caster: Character, spell: Dictionary, dc: int) -> int:
	var replaced := false
	var add := 0
	for rule in rules(caster, "spell"):
		if not _spell_qualifies(rule, spell): continue
		if rule.get("replace", {}).has("save_dc") and not replaced:
			dc = int(rule.replace.save_dc)
			replaced = true
		add += int(rule.get("add", {}).get("save_dc", 0))
	return dc + add

## Scope is judged on the invocation's inherited (pre-transformation) fields,
## so one source's school change never makes another source qualify.
static func _spell_qualifies(rule: Dictionary, spell: Dictionary) -> bool:
	var scope: Dictionary = rule.scope
	var inherited: Dictionary = spell.get(CAST_PROFILE_KEY, {}).get("inherited", {})
	var school := str(inherited.get("school", spell.get("school", "")))
	if scope.has("ids") and str(spell.get("id", "")) not in scope.ids: return false
	if scope.has("schools") and school not in scope.schools: return false
	if scope.has("permission_sources"):
		var source := ""
		for permission in spell.get("_source_permissions", []):
			if permission is Dictionary and str(permission.get("id", "")) == str(spell.get("_source_permission_id", "")):
				source = str(permission.get("source_id", ""))
		if source.is_empty() or source not in scope.permission_sources: return false
	return true

## S-140 (Batch 085): transform one permissioned invocation's range, components,
## school or casting time. Returns a new copy; the input and the catalog record
## are not changed. Applied once: a copy that already carries `_cast_profile`
## is returned unchanged. The first qualifying source's `replace` of a field
## wins (later conflicting replacements are recorded as ignored); additive
## range sums; removed components union. The transformation itself costs
## nothing, so the invocation's own payment is charged exactly once.
static func apply_cast(caster: Character, spell: Dictionary) -> Dictionary:
	var out := spell.duplicate(true)
	if caster == null or out.has(CAST_PROFILE_KEY) or str(out.get("_source_permission_id", "")).is_empty() or bool(out.get("_magic_item_activation", false)): return out
	var catalog_time := str(out.get("casting_time", "action"))
	var ranged := int(out.get("range", 0)) >= 1 and str(out.get("range_kind", "")) != "touch"
	var profile := {"sources": [], "ignored": [], "inherited": {"range": out.get("range", null), "school": str(out.get("school", "")), "casting_time": catalog_time, "components": out.get("components", []).duplicate()}}
	var replaced := {}
	var add_feet := 0
	var removed: Array = []
	for rule in rules(caster, "spell"):
		if not _spell_qualifies(rule, out): continue
		var replace: Dictionary = rule.get("replace", {})
		var used := false
		for field in ["range_feet", "school", "casting_time"]:
			if not replace.has(field): continue
			if (field == "range_feet" and not ranged) or (field == "casting_time" and catalog_time not in CAST_TIMINGS): continue
			if replaced.has(field):
				profile.ignored.append({"source": str(rule.source_instance_id), "field": field})
				continue
			replaced[field] = replace[field]
			used = true
		if ranged and rule.get("add", {}).has("range_feet"):
			add_feet += int(rule.add.range_feet)
			used = true
		for component in rule.get("remove", {}).get("components", []):
			if str(component) in out.get("components", []):
				used = true
				if str(component) not in removed: removed.append(str(component))
		if used: profile.sources.append(str(rule.source_instance_id))
	if profile.sources.is_empty(): return out
	if replaced.has("range_feet"):
		out["range"] = int(replaced.range_feet) / 5
		out.erase("range_by_character_level_feet")
	if add_feet > 0:
		out["range"] = int(out.get("range", 0)) + add_feet / 5
		var table: Dictionary = out.get("range_by_character_level_feet", {})
		for key in table: table[key] = int(table[key]) + add_feet
	if replaced.has("school"): out["school"] = str(replaced.school)
	if replaced.has("casting_time"): out["casting_time"] = str(replaced.casting_time)
	if not removed.is_empty(): out["components"] = out.get("components", []).filter(func(c): return str(c) not in removed)
	profile["removed_components"] = removed
	out[CAST_PROFILE_KEY] = profile
	return out

static func _range(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floor(float(v)) and int(v) > 0 and int(v) <= 5280 and int(v) % 5 == 0

static func _int(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floor(float(v)) and absf(float(v)) <= 100
