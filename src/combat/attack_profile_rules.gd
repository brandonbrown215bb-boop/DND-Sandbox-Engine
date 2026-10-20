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
	elif replaced.has("damage_type"):
		profile["damage_type"] = str(replaced.damage_type)
	if replaced.has("attack_bonus"): profile["attack_bonus_override"] = int(replaced.attack_bonus)
	if attack_add != 0:
		var base := int(profile.get("attack_bonus_override", attacker.ability_scores.get_ability_modifier(str(profile.get("ability", "STR"))) + attacker.proficiency_bonus))
		profile["attack_bonus_override"] = base + attack_add
	if damage_add != 0: profile["damage"] = str(profile.get("damage", "1")) + ("+%d" % damage_add if damage_add > 0 else "%d" % damage_add)
	profile["_attack_profile"] = {"sources": applied, "replaced": replaced.keys(), "attack_add": attack_add, "damage_add": damage_add}
	return profile

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
