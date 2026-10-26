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
const REPLACE_KEYS := ["ability", "damage_die", "damage_type", "damage_type_choices", "attack_bonus", "save_dc"]
const ADD_KEYS := ["attack_bonus", "damage_bonus", "save_dc"]
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
	for key in ["ids", "properties_all", "schools"]:
		if scope.has(key) and (not scope[key] is Array or scope[key].any(func(v): return not v is String)): return "attack_profile scope.%s must be strings" % key
	if scope.has("melee") and not scope["melee"] is bool: return "attack_profile scope.melee must be boolean"
	if rule.has("required_condition") and (not rule["required_condition"] is String or str(rule["required_condition"]).is_empty()): return "attack_profile required_condition is invalid"
	var replace: Variant = rule.get("replace", {})
	var add: Variant = rule.get("add", {})
	if not replace is Dictionary or not add is Dictionary or (replace.is_empty() and add.is_empty()): return "attack_profile needs replace or add fields"
	for key in replace:
		if str(key) not in REPLACE_KEYS: return "attack_profile cannot replace %s" % str(key)
	for key in add:
		if str(key) not in ADD_KEYS or not _int(add[key]): return "attack_profile add.%s must be a supported integer" % str(key)
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
	if str(scope.kind) == "spell" and (replace.keys().any(func(k): return k != "save_dc") or add.keys().any(func(k): return k != "save_dc")): return "spell attack_profile supports only save_dc"
	if str(scope.kind) == "weapon" and (replace.has("save_dc") or add.has("save_dc")): return "weapon attack_profile cannot change save_dc"
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
		var scope: Dictionary = rule.scope
		if scope.has("ids") and str(spell.get("id", "")) not in scope.ids: continue
		if scope.has("schools") and str(spell.get("school", "")) not in scope.schools: continue
		if rule.get("replace", {}).has("save_dc") and not replaced:
			dc = int(rule.replace.save_dc)
			replaced = true
		add += int(rule.get("add", {}).get("save_dc", 0))
	return dc + add

static func _int(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floor(float(v)) and absf(float(v)) <= 100
