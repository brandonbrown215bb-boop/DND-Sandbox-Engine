## Character
## Core character data class for player characters and NPCs.
## Integrates ability scores, class features, inventory, and combat stats.
class_name Character
extends RefCounted

## Character identity.
var character_name: String = ""
var race_id: String = ""
var class_id: String = ""

## Level and experience.
var level: int = 1
var xp: int = 0

## Ability scores.
var ability_scores: AbilityScores = AbilityScores.new()

## Hit points.
var max_hp: int = 10
var current_hp: int = 10
var temp_hp: int = 0

## Armor class (calculated from equipment + DEX).
var base_ac: int = 10

## Movement speed in hex tiles per turn.
var speed: int = 6

## Proficiency bonus (scales with level).
var proficiency_bonus: int = 2

## Proficiencies.
var saving_throw_proficiencies: Array[String] = []
var skill_proficiencies: Array[String] = []
var weapon_proficiencies: Array[String] = []
var armor_proficiencies: Array[String] = []

## Unlocked class features (list of feature dictionaries from class JSON).
var features: Array[Dictionary] = []

## Spell slots: level -> remaining uses. (e.g., {1: 2, 2: 1})
var spell_slots: Dictionary = {}

## Currently concentrating spell info: {"spell_id": String, "targets": Array}
var concentrating_on: Dictionary = {}

## Reaction tracking: available or spent this round.
var reaction_available: bool = true

## Known spells: array of spell IDs.
var known_spells: Array[String] = []

## Active conditions (e.g., "blessed", "poisoned"): condition_name -> remaining_turns.
var conditions: Dictionary = {}

## Inventory.
var inventory: Inventory = Inventory.new()

## Per-combat/per-rest resource tracking for features.
## feature_id -> remaining uses
var feature_uses: Dictionary = {}

## Whether this character is alive.
var is_alive: bool = true

## Critical hit range (normally 20, Fighter's Improved Critical lowers to 19).
var crit_range: int = 20

## Extra attacks per Attack action (normally 0, Extra Attack gives 1).
var extra_attacks: int = 0


## Initialize a character from race and class data.
func initialize(p_name: String, p_race_id: String, p_class_id: String, scores: AbilityScores) -> void:
	character_name = p_name
	race_id = p_race_id
	class_id = p_class_id
	ability_scores = scores
	level = 1

	var race_data := DataLoader.get_race(race_id)
	var class_data := DataLoader.get_character_class(class_id)

	# Apply racial bonuses
	ability_scores.apply_racial_bonuses(race_data)

	# Apply racial traits
	speed = int(race_data.get("speed", 6))
	var racial_proficiencies: Array = race_data.get("proficiencies", [])
	for prof in racial_proficiencies:
		if prof not in skill_proficiencies:
			skill_proficiencies.append(str(prof))

	# Apply class base stats
	saving_throw_proficiencies.assign(class_data.get("saving_throw_proficiencies", []))
	weapon_proficiencies.assign(class_data.get("weapon_proficiencies", []))
	armor_proficiencies.assign(class_data.get("armor_proficiencies", []))

	# Starting equipment
	var starting_equipment: Array = class_data.get("starting_equipment", [])
	inventory.add_starting_equipment(starting_equipment)

	# Calculate initial HP: hit die max + CON modifier
	var hit_die_sides := _parse_hit_die(class_data.get("hit_die", "d8"))
	max_hp = hit_die_sides + ability_scores.get_ability_modifier("CON")
	max_hp = maxi(max_hp, 1)
	current_hp = max_hp

	# Unlock level 1 features
	_unlock_features_for_level(1)

	# Calculate AC
	_recalculate_ac()


## Level up this character (milestone-based).
func level_up() -> void:
	level += 1
	proficiency_bonus = 2 + int(floor(float(level - 1) / 4.0))

	var class_data := DataLoader.get_character_class(class_id)
	var hit_die_sides := _parse_hit_die(class_data.get("hit_die", "d8"))

	# HP increase: roll hit die (or average) + CON modifier
	var hp_roll := Dice.roll(hit_die_sides)
	var con_mod := ability_scores.get_ability_modifier("CON")
	var hp_gain := maxi(hp_roll + con_mod, 1)
	max_hp += hp_gain
	current_hp = max_hp  # Full heal on level up

	# Unlock new features
	_unlock_features_for_level(level)

	# Update spell slots if caster
	_update_spell_slots()

	print("[Character] %s leveled up to %d! (+%d HP, now %d)" % [character_name, level, hp_gain, max_hp])


## Unlock class features for a specific level.
func _unlock_features_for_level(lvl: int) -> void:
	var class_data := DataLoader.get_character_class(class_id)
	var features_by_level: Dictionary = class_data.get("features_by_level", {})

	var level_key := str(lvl)
	if level_key in features_by_level:
		var level_features: Array = features_by_level[level_key]
		for feature in level_features:
			features.append(feature)
			_apply_passive_feature(feature)
			# Initialize uses for active features
			if feature.get("type", "") == "active":
				var uses: int = feature.get("uses", 1)
				feature_uses[feature["id"]] = uses


## Apply effects of passive features.
func _apply_passive_feature(feature: Dictionary) -> void:
	if feature.get("type", "") != "passive":
		return

	var effects: Array = feature.get("effects", [])
	for effect in effects:
		var effect_type: String = effect.get("type", "")
		match effect_type:
			"modify_crit_range":
				crit_range = int(effect.get("value", 20))
			"extra_attack":
				extra_attacks += int(effect.get("count", 1))


## Update spell slots based on class and level.
func _update_spell_slots() -> void:
	var class_data := DataLoader.get_character_class(class_id)
	var slot_table: Dictionary = class_data.get("spell_slots_by_level", {})
	spell_slots = {}
	for lvl_key in slot_table:
		var lvl_data = slot_table[lvl_key]
		# Data format: { "1": [2], "2": [3], ... } — first element is the slot count.
		var count: int = lvl_data[0] if (typeof(lvl_data) == TYPE_ARRAY and lvl_data.size() > 0) else int(lvl_data)
		spell_slots[str(lvl_key)] = count


## Parse a hit die string like "d10" into the number of sides.
func _parse_hit_die(hit_die: String) -> int:
	if hit_die.begins_with("d") or hit_die.begins_with("D"):
		return hit_die.substr(1).to_int()
	return 8  # Default to d8


## Recalculate armor class from equipment and DEX.
func _recalculate_ac() -> void:
	var dex_mod := ability_scores.get_ability_modifier("DEX")
	var armor_id := inventory.get_armor()

	if armor_id.is_empty():
		# No armor: AC = 10 + DEX
		base_ac = 10 + dex_mod
	else:
		var armor_data := DataLoader.get_item(armor_id)
		var armor_type: String = armor_data.get("armor_type", "light")
		var armor_ac: int = int(armor_data.get("ac", 10))

		match armor_type:
			"light":
				base_ac = armor_ac + dex_mod
			"medium":
				base_ac = armor_ac + mini(dex_mod, 2)
			"heavy":
				base_ac = armor_ac  # No DEX bonus

	# Shield bonus
	var shield_ac: int = 0
	var shield_id := inventory.get_equipped(Inventory.Slot.SHIELD)
	if not shield_id.is_empty():
		var shield_data := DataLoader.get_item(shield_id)
		shield_ac = int(shield_data.get("ac_bonus", 2))

	base_ac += shield_ac


## Get effective AC (base + conditions/buffs).
func get_ac() -> int:
	var ac := base_ac
	
	# Mage Armor sets base AC to 13 + DEX (if not wearing heavier armor)
	if has_condition("mage_armor"):
		var armor_id := inventory.get_armor()
		if armor_id.is_empty():
			var dex_mod := ability_scores.get_ability_modifier("DEX")
			var shield_ac: int = 0
			var shield_id := inventory.get_equipped(Inventory.Slot.SHIELD)
			if not shield_id.is_empty():
				var shield_data := DataLoader.get_item(shield_id)
				shield_ac = int(shield_data.get("ac_bonus", 2))
			ac = 13 + dex_mod + shield_ac

	# Shield spell grants +5 AC
	if has_condition("shield"):
		ac += 5

	# Apply feature modifiers
	if "defense_style" in _get_active_feature_ids():
		ac += 1
	return ac


## Take damage. Returns actual damage dealt after temp HP absorption.
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0

	# Absorb with temp HP first
	if temp_hp > 0:
		if temp_hp >= amount:
			temp_hp -= amount
			return 0
		else:
			amount -= temp_hp
			temp_hp = 0

	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		is_alive = false

	return amount


## Heal HP.
func heal(amount: int) -> int:
	var actual := mini(amount, max_hp - current_hp)
	current_hp += actual
	if current_hp > 0:
		is_alive = true
	return actual


## Check if this character has proficiency in a saving throw.
func is_proficient_in_save(ability: String) -> bool:
	return ability.to_upper() in saving_throw_proficiencies


## Make a saving throw. Returns the total roll.
func make_saving_throw(ability: String, advantage: bool = false, disadvantage: bool = false) -> int:
	var roll: int
	if advantage and not disadvantage:
		roll = Dice.roll_with_advantage(20)
	elif disadvantage and not advantage:
		roll = Dice.roll_with_disadvantage(20)
	else:
		roll = Dice.roll(20)

	var mod := ability_scores.get_ability_modifier(ability)
	if is_proficient_in_save(ability):
		mod += proficiency_bonus

	var total := roll + mod
	if has_condition("blessed"):
		total += Dice.roll(4)
		
	return total


## Make an attack roll. Returns {"roll": int, "is_crit": bool, "is_miss": bool}.
func make_attack_roll(ability: String = "STR", advantage: bool = false, disadvantage: bool = false) -> Dictionary:
	if has_condition("blinded") or has_condition("poisoned"):
		disadvantage = true

	var natural_roll: int
	if advantage and not disadvantage:
		natural_roll = Dice.roll_with_advantage(20)
	elif disadvantage and not advantage:
		natural_roll = Dice.roll_with_disadvantage(20)
	else:
		natural_roll = Dice.roll(20)

	var mod := ability_scores.get_ability_modifier(ability) + proficiency_bonus
	var is_crit := natural_roll >= crit_range
	var is_miss := natural_roll == 1

	var total := natural_roll + mod
	if has_condition("blessed"):
		total += Dice.roll(4)

	return {
		"natural": natural_roll,
		"total": total,
		"modifier": mod,
		"is_crit": is_crit,
		"is_miss": is_miss,
	}


## Use a class feature. Returns false if no uses remaining.
func use_feature(feature_id: String) -> bool:
	if feature_id in feature_uses:
		if feature_uses[feature_id] <= 0:
			return false
		feature_uses[feature_id] -= 1
	return true


## Reset per-combat feature uses.
func reset_combat_features() -> void:
	for feature in features:
		if feature.get("uses_per", "") == "combat":
			feature_uses[feature["id"]] = feature.get("uses", 1)


## Reset per-rest feature uses.
func reset_rest_features() -> void:
	for feature in features:
		var resets_on: String = feature.get("uses_per", "")
		if resets_on in ["combat", "rest"]:
			feature_uses[feature["id"]] = feature.get("uses", 1)
	# Restore spell slots
	_update_spell_slots()


## Add a condition with a duration (in turns).
func add_condition(condition_name: String, duration: int) -> void:
	conditions[condition_name] = duration


## Remove a condition.
func remove_condition(condition_name: String) -> void:
	conditions.erase(condition_name)


## Tick conditions at end of turn (reduce durations, remove expired).
func tick_conditions() -> void:
	var expired: Array[String] = []
	for condition in conditions:
		conditions[condition] -= 1
		if conditions[condition] <= 0:
			expired.append(condition)
	for condition in expired:
		conditions.erase(condition)


## Check if a condition is active.
func has_condition(condition_name: String) -> bool:
	return condition_name in conditions


## Check if the character has a feature by ID.
func has_feature(feature_id: String) -> bool:
	for feature in features:
		if feature.get("id", "") == feature_id:
			return true
	return false


## Get IDs of all active features.
func _get_active_feature_ids() -> Array[String]:
	var ids: Array[String] = []
	for feature in features:
		ids.append(feature.get("id", ""))
	return ids


## Serialize character to dictionary.
func to_dict() -> Dictionary:
	return {
		"name": character_name,
		"race_id": race_id,
		"class_id": class_id,
		"level": level,
		"xp": xp,
		"ability_scores": ability_scores.to_dict(),
		"max_hp": max_hp,
		"current_hp": current_hp,
		"temp_hp": temp_hp,
		"base_ac": base_ac,
		"speed": speed,
		"proficiency_bonus": proficiency_bonus,
		"saving_throw_proficiencies": saving_throw_proficiencies,
		"skill_proficiencies": skill_proficiencies,
		"weapon_proficiencies": weapon_proficiencies,
		"armor_proficiencies": armor_proficiencies,
		"known_spells": known_spells,
		"conditions": conditions.duplicate(),
		"inventory": inventory.to_dict(),
		"feature_uses": feature_uses.duplicate(),
		"is_alive": is_alive,
		"crit_range": crit_range,
		"extra_attacks": extra_attacks,
	}


## Deserialize character from dictionary.
func from_dict(data: Dictionary) -> void:
	character_name = data.get("name", "")
	race_id = data.get("race_id", "")
	class_id = data.get("class_id", "")
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	
	ability_scores = AbilityScores.new()
	ability_scores.from_dict(data.get("ability_scores", {}))
	
	max_hp = int(data.get("max_hp", 10))
	current_hp = int(data.get("current_hp", 10))
	temp_hp = int(data.get("temp_hp", 0))
	base_ac = int(data.get("base_ac", 10))
	speed = int(data.get("speed", 6))
	proficiency_bonus = int(data.get("proficiency_bonus", 2))
	is_alive = bool(data.get("is_alive", true))
	crit_range = int(data.get("crit_range", 20))
	extra_attacks = int(data.get("extra_attacks", 0))

	# Clear and rebuild arrays
	saving_throw_proficiencies.clear()
	for val in data.get("saving_throw_proficiencies", []):
		saving_throw_proficiencies.append(str(val))

	skill_proficiencies.clear()
	for val in data.get("skill_proficiencies", []):
		skill_proficiencies.append(str(val))

	weapon_proficiencies.clear()
	for val in data.get("weapon_proficiencies", []):
		weapon_proficiencies.append(str(val))

	armor_proficiencies.clear()
	for val in data.get("armor_proficiencies", []):
		armor_proficiencies.append(str(val))

	known_spells.clear()
	for val in data.get("known_spells", []):
		known_spells.append(str(val))

	# Clear and rebuild features
	features.clear()
	for l in range(1, level + 1):
		_unlock_features_for_level(l)

	# Overwrite conditions and feature uses with saved state
	conditions = data.get("conditions", {}).duplicate()
	feature_uses = data.get("feature_uses", {}).duplicate()
	
	# Restore inventory
	inventory = Inventory.new()
	inventory.from_dict(data.get("inventory", {}))

