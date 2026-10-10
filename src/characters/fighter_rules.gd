## SRD 5.2.1 Fighter training and progression. Character owns saved choices;
## combat owns positions, prompts and the turn budget.
class_name FighterRules
extends RefCounted

const STYLES := ["defense", "archery", "great_weapon_fighting", "two_weapon_fighting"]
const ASI_LEVELS := [4, 6, 8, 12, 14, 16]
const MASTERIES := {
	"club": "slow", "dagger": "nick", "greatclub": "push", "handaxe": "vex",
	"javelin": "slow", "light_hammer": "nick", "mace": "sap", "quarterstaff": "topple",
	"sickle": "nick", "spear": "sap", "dart": "vex", "light_crossbow": "slow",
	"shortbow": "vex", "sling": "slow", "battleaxe": "topple", "flail": "sap",
	"glaive": "graze", "greataxe": "cleave", "greatsword": "graze", "halberd": "cleave",
	"lance": "topple", "longsword": "sap", "maul": "topple", "morningstar": "sap",
	"pike": "push", "rapier": "vex", "scimitar": "nick", "shortsword": "vex",
	"trident": "topple", "warhammer": "push", "war_pick": "sap", "whip": "slow",
	"blowgun": "vex", "hand_crossbow": "vex", "heavy_crossbow": "push", "longbow": "slow",
}

static func mastery_capacity(level: int) -> int:
	return 6 if level >= 16 else (5 if level >= 10 else (4 if level >= 4 else 3))

static func saved_training_error(dto: Dictionary) -> String:
	if dto.get("class_id", "") != "fighter" or not dto.has("fighter_training"):
		return ""
	var training: Variant = dto["fighter_training"]
	if not training is Dictionary:
		return "Fighter training is not an object"
	if training.is_empty():
		return ""
	var level := int(dto.get("level", 1))
	for field in ["styles", "masteries", "skills"]:
		if not training.get(field, []) is Array:
			return "Fighter %s is not an array" % field
		var seen := []
		for value in training.get(field, []):
			if not value is String or value in seen:
				return "Fighter %s contains invalid or duplicate choices" % field
			seen.append(value)
			if field == "styles" and value not in STYLES:
				return "Unknown Fighter fighting style"
			if field == "masteries" and value not in available_weapons():
				return "Unknown Fighter mastery weapon"
			if field == "skills" and value not in DataLoader.get_character_class("fighter").get("skill_choices", {}).get("from", []):
				return "Unknown Fighter skill"
	var subclass_id := str(dto.get("subclass_id", "champion" if level >= 3 else ""))
	if training.get("styles", []).size() > (2 if level >= 7 and subclass_id == "champion" else 1) or training.get("masteries", []).size() > mastery_capacity(level) or training.get("skills", []).size() != 2:
		return "Fighter training exceeds level capacity"
	for field in ["asi_spent", "mastery_swaps"]:
		var value: Variant = training.get(field, 0)
		if not (value is int or value is float) or float(value) != float(int(value)) or int(value) < 0:
			return "Invalid Fighter training count"
	var earned := 0
	for threshold in ASI_LEVELS:
		if level >= threshold:
			earned += 1
	# New saves validate exact base/subclass entitlements in ClassProgression.
	# Only older aggregate-only saves depend on the original Fighter level table.
	if (not dto.has("feature_choices") and int(training.get("asi_spent", 0)) > earned) or int(training.get("mastery_swaps", 0)) > 3:
		return "Fighter training count exceeds entitlement"
	if training.get("boon", "") not in ["", "combat_prowess", "irresistible_offense"] or (not str(training.get("boon", "")).is_empty() and level < 19):
		return "Invalid Fighter Epic Boon"
	if training.has("boon_ability") and (not training["boon_ability"] is String or training["boon_ability"] not in AbilityScores.ABILITIES or str(training.get("boon", "")).is_empty()):
		return "Invalid Fighter Epic Boon ability"
	for field in ["creation", "style_swap", "auto_indomitable", "auto_inspiration", "auto_peerless", "inspiration_any_die"]:
		if training.has(field) and not training[field] is bool:
			return "Invalid Fighter preference"
	if training.get("tactical_master", "weapon") not in ["weapon", "push", "sap", "slow"]:
		return "Invalid Tactical Master choice"
	return ""

static func initialize_training(c: Character) -> void:
	if c.class_id != "fighter":
		return
	if c.fighter_training.is_empty():
		c.fighter_training = {"styles": ["defense"], "masteries": ["longsword", "greatsword", "longbow"], "asi_spent": 0, "boon": "", "style_swap": true, "mastery_swaps": 3, "auto_indomitable": true, "auto_inspiration": false, "auto_peerless": true, "creation": true, "skills": ["Athletics", "Perception"]}
	for field in ["asi_spent", "mastery_swaps"]:
		c.fighter_training[field] = int(c.fighter_training.get(field, 0))

static func curate_weapon(weapon: Dictionary) -> void:
	var id := str(weapon.get("id", ""))
	if id not in MASTERIES:
		return
	var properties: Array = weapon.get("properties", []).duplicate()
	var tags := {
		"light": ["club", "dagger", "handaxe", "light_hammer", "sickle", "scimitar", "shortsword", "hand_crossbow"],
		"finesse": ["dagger", "dart", "rapier", "scimitar", "shortsword", "whip"],
		"versatile": ["quarterstaff", "spear", "battleaxe", "longsword", "trident", "warhammer", "war_pick"],
		"two_handed": ["greatclub", "light_crossbow", "shortbow", "glaive", "greataxe", "greatsword", "halberd", "lance", "maul", "pike", "heavy_crossbow", "longbow"],
		"heavy": ["glaive", "greataxe", "greatsword", "halberd", "lance", "maul", "pike", "heavy_crossbow", "longbow"],
		"reach": ["glaive", "halberd", "lance", "pike", "whip"],
		"ranged": ["dart", "light_crossbow", "shortbow", "sling", "blowgun", "hand_crossbow", "heavy_crossbow", "longbow"],
		"loading": ["light_crossbow", "blowgun", "hand_crossbow", "heavy_crossbow"],
	}
	for property in tags:
		if id in tags[property] and property not in properties:
			properties.append(property)
	weapon["properties"] = properties
	weapon["weapon_type"] = "simple" if id in ["club", "dagger", "greatclub", "handaxe", "javelin", "light_hammer", "mace", "quarterstaff", "sickle", "spear", "dart", "light_crossbow", "shortbow", "sling"] else "martial"
	weapon["mastery"] = MASTERIES[id]
	if "ranged" in properties:
		weapon["ability"] = "DEX"
	elif "reach" in properties:
		weapon["range"] = 2

static func choose_skills(c: Character, first: String, second: String) -> bool:
	var legal: Array = DataLoader.get_character_class("fighter").get("skill_choices", {}).get("from", [])
	if c.class_id != "fighter" or not c.fighter_training.get("creation", false) or first == second or first not in legal or second not in legal:
		return false
	var racial: Array = DataLoader.get_race(c.race_id).get("proficiencies", [])
	for old in c.fighter_training.get("skills", []):
		if old not in racial:
			c.skill_proficiencies.erase(str(old))
	for skill in [first, second]:
		if skill not in c.skill_proficiencies:
			c.skill_proficiencies.append(skill)
	c.fighter_training["skills"] = [first, second]
	return true

static func has_style(c: Character, style: String) -> bool:
	if c == null:
		return false
	if c.class_id == "fighter" and style in c.fighter_training.get("styles", []):
		return true
	for effect in ClassProgression.selected_feature_effects_of_type(c, "fighting_style"):
		if str(effect.get("style", "")) == style:
			return true
	return false

static func choose_style(c: Character, style: String, replace_index: int = -1) -> bool:
	if c.class_id != "fighter" or style not in STYLES:
		return false
	var styles: Array = c.fighter_training.get("styles", []).duplicate()
	if style in styles:
		return false
	if replace_index >= 0:
		if replace_index >= styles.size() or not c.fighter_training.get("style_swap", false):
			return false
		styles[replace_index] = style
		c.fighter_training["style_swap"] = false
	elif styles.size() < (2 if c.has_feature("champion_additional_fighting_style") else 1):
		styles.append(style)
	else:
		return false
	c.fighter_training["styles"] = styles
	return true

static func available_weapons() -> Array[String]:
	var ids: Array[String] = []
	for id in MASTERIES:
		if str(DataLoader.get_item(id).get("type", "")) == "weapon":
			ids.append(id)
	ids.sort()
	return ids

static func eligible_mastery_weapons(c: Character) -> Array[String]:
	var ids := available_weapons()
	if bool(c.get_feature_effect("weapon_mastery").get("melee_only", false)):
		var melee: Array[String] = []
		for id in ids:
			if "ranged" not in DataLoader.get_item(id).get("properties", []):
				melee.append(id)
		return melee
	return ids

static func weapon_mastery_capacity(c: Character) -> int:
	return c.get_weapon_mastery_capacity()

static func choose_mastery(c: Character, weapon_id: String, replace_index: int = -1) -> bool:
	if not c.has_feature_effect("weapon_mastery") or weapon_id not in eligible_mastery_weapons(c):
		return false
	var choices: Array = c.weapon_masteries.duplicate()
	if weapon_id in choices:
		return false
	if replace_index >= 0:
		var long_rest_swaps := int(c.feature_uses.get("weapon_mastery_swaps", 0))
		# A long-rest allowance takes precedence over the legacy Fighter creation
		# counter. Character.long_rest() mirrors its single allowance into the
		# legacy field, so it must not accidentally expose old creation charges.
		var creation_swaps := int(c.fighter_training.get("mastery_swaps", 0)) if c.class_id == "fighter" and c.fighter_training.get("creation", false) and not c.feature_uses.has("weapon_mastery_swaps") else 0
		if replace_index >= choices.size() or maxi(creation_swaps, long_rest_swaps) <= 0:
			return false
		choices[replace_index] = weapon_id
		if creation_swaps > 0:
			c.fighter_training["mastery_swaps"] = creation_swaps - 1
		else:
			c.feature_uses["weapon_mastery_swaps"] = long_rest_swaps - 1
			if c.class_id == "fighter":
				c.fighter_training["mastery_swaps"] = long_rest_swaps - 1
	elif choices.size() < weapon_mastery_capacity(c):
		choices.append(weapon_id)
	else:
		return false
	c.weapon_masteries.assign(choices)
	if c.class_id == "fighter":
		c.fighter_training["masteries"] = choices.duplicate()
	return true

static func pending_asi(c: Character) -> int:
	return ClassProgression.pending_improvements(c).size() if c.class_id == "fighter" else 0

static func improve_scores(c: Character, first: String, second: String) -> bool:
	return c.class_id == "fighter" and ClassProgression.improve_scores(c, first, second)

static func choose_boon(c: Character, ability: String) -> bool:
	return c.class_id == "fighter" and ClassProgression.choose_epic_boon(c, "fighter_epic_boon", "combat_prowess", ability)

static func _increase_score(c: Character, ability: String, amount: int) -> void:
	ClassProgression.increase_score(c, ability, amount)

static func mastery(c: Character, weapon: Dictionary) -> String:
	var id := str(weapon.get("id", ""))
	var trained: Array = c.weapon_masteries
	# Keep compatibility with the Fighter's pre-existing saved training field,
	# which is still written by its training UI and older integrations.
	if c.class_id == "fighter":
		trained = c.fighter_training.get("masteries", c.weapon_masteries)
	if not c.has_feature_effect("weapon_mastery") or id not in trained:
		return ""
	var selected := str(c.fighter_training.get("tactical_master", "weapon"))
	if c.has_feature("fighter_tactical_master") and selected in ["push", "sap", "slow"]:
		return selected
	return str(MASTERIES.get(id, ""))

static func tactical_mind(c: Character, total: int, dc: int) -> Dictionary:
	if total >= dc or not c.has_feature("fighter_tactical_mind") or int(c.feature_uses.get("fighter_second_wind", 0)) <= 0:
		return {"total": total, "bonus": 0, "spent": false}
	var bonus := Dice.roll(10, c)
	var spent := total + bonus >= dc
	if spent:
		c.use_feature("fighter_second_wind")
	return {"total": total + bonus, "bonus": bonus, "spent": spent}

static func start_turn(c: Character) -> int:
	c.feature_uses.erase("fighter_action_surge_used")
	c.feature_uses.erase("fighter_peerless_used")
	c.feature_uses.erase("epic_boon_combat_prowess_used")
	c.feature_uses.erase("fighter_light_used")
	c.feature_uses.erase("fighter_cleave_used")
	# A miss on the previous turn remains valid until this turn ends.
	c.fighter_studied_previous = c.fighter_studied_targets.duplicate()
	if c.has_feature("champion_heroic_warrior"):
		c.heroic_inspiration = true
	if c.has_feature("champion_survivor") and c.current_hp > 0 and c.current_hp <= c.max_hp / 2:
		return c.heal(maxi(0, 5 + c.ability_scores.get_ability_modifier("CON")))
	return 0

static func end_turn(c: Character) -> void:
	for id in c.fighter_studied_previous:
		c.fighter_studied_targets.erase(id)
	c.fighter_studied_previous.clear()

static func target_key(target: Variant) -> String:
	return str(target.get_instance_id()) if target is Character else str(target.get("id", ""))

static func attack_advantage(c: Character, target: Variant) -> bool:
	var key := target_key(target)
	var advantage := key in c.fighter_studied_targets
	c.fighter_studied_targets.erase(key)
	c.fighter_studied_previous.erase(key)
	return advantage

static func record_miss(c: Character, target: Variant) -> void:
	if c.has_feature("fighter_studied_attacks"):
		var key := target_key(target)
		if key not in c.fighter_studied_targets:
			c.fighter_studied_targets.append(key)

static func peerless_aim(c: Character, hit: bool) -> bool:
	if not hit and ClassProgression.has_epic_boon(c, "combat_prowess") and (c.class_id != "fighter" or c.fighter_training.get("auto_peerless", true)) and not c.feature_uses.get("epic_boon_combat_prowess_used", c.feature_uses.get("fighter_peerless_used", false)):
		c.feature_uses["epic_boon_combat_prowess_used"] = true
		c.feature_uses["fighter_peerless_used"] = true
		return true
	return hit


## A visible preselected policy lets Inspiration cover any owned die without
## making synchronous rules resolvers own a popup or a suspended transaction.
static func inspire_die(c: Character, sides: int, value: int) -> int:
	if c != null and c.heroic_inspiration and c.fighter_training.get("inspiration_any_die", false) and value <= sides / 2:
		c.heroic_inspiration = false
		c.fighter_training["inspiration_any_die"] = false
		return randi_range(1, sides)
	return value

static func weapon_damage(c: Character, weapon: Dictionary, detail: Dictionary) -> int:
	var two_hands := c.inventory.get_equipped(Inventory.Slot.SHIELD).is_empty() and c.inventory.get_equipped(Inventory.Slot.OFFHAND).is_empty()
	var properties: Array = weapon.get("properties", [])
	var is_two_handed := "two_handed" in properties or "two-handed" in properties or "versatile" in properties or str(weapon.get("id", "")) in ["greatsword", "greataxe", "maul", "halberd", "glaive", "pike"]
	var gain := 0
	if has_style(c, "great_weapon_fighting") and two_hands and "ranged" not in properties and is_two_handed:
		for term in detail.get("dice_terms", []):
			var rolls: Array = term.get("results", [])
			for i in rolls.size():
				if i < term.get("kept", []).size() and not term["kept"][i]:
					continue
				if rolls[i] < 3:
					gain += 3 - int(rolls[i])
					term["subtotal"] = int(term.get("subtotal", 0)) + 3 - int(rolls[i])
					rolls[i] = 3
	return gain

static func apply_mastery(c: Character, target: Variant, weapon: Dictionary, result: Dictionary) -> void:
	if not target is Dictionary:
		return
	var property := mastery(c, weapon)
	result["mastery"] = property
	if not result.get("hit", false):
		record_miss(c, target)
		if property == "graze":
			var amount := maxi(0, c.ability_scores.get_ability_modifier(str(weapon.get("ability", "STR"))))
			var damage_type := str(weapon.get("damage_type", "slashing"))
			var bypass := ClassProgression.has_epic_boon(c, "irresistible_offense") and damage_type in ["bludgeoning", "piercing", "slashing"]
			var actual := int(CombatAction.resolve_damage(target, amount, damage_type, {}, bypass)["damage"])
			result["damage"] = actual
			result["damage_type"] = damage_type
			result["damage_components"] = [{"label": "Graze", "value": actual, "type": damage_type}]
			result["message"] += " Graze deals %d %s damage." % [actual, damage_type]
		return
	if property == "vex" and int(result.get("damage", 0)) > 0:
		var key := target_key(target)
		if key not in c.fighter_studied_targets:
			c.fighter_studied_targets.append(key)
		c.fighter_studied_previous.erase(key)
	elif property == "sap":
		var sources: Array = target.get("fighter_sap_sources", [])
		if c.get_instance_id() not in sources:
			sources.append(c.get_instance_id())
		target["fighter_sap_sources"] = sources
	elif property == "slow" and int(result.get("damage", 0)) > 0:
		var sources: Array = target.get("fighter_slow_sources", [])
		if c.get_instance_id() not in sources:
			sources.append(c.get_instance_id())
		target["fighter_slow_sources"] = sources
	elif property == "topple":
		var dc := 8 + c.proficiency_bonus + c.ability_scores.get_ability_modifier(str(weapon.get("ability", "STR")))
		var total := BarbarianRules.roll_monster_save(target, "CON", c)
		if total < dc and "prone" not in target.get("condition_immunities", []):
			var conditions: Dictionary = target.get("conditions", {})
			conditions["prone"] = 99
			target["conditions"] = conditions
		result["message"] += " Topple: CON %d vs DC %d." % [total, dc]

static func clear_source_effects(c: Character, monsters: Array) -> void:
	for monster in monsters:
		for field in ["fighter_sap_sources", "fighter_slow_sources"]:
			var sources: Array = monster.get(field, [])
			sources.erase(c.get_instance_id())
			if sources.is_empty():
				monster.erase(field)

static func monster_speed(monster: Dictionary) -> int:
	if monster.get("conditions", {}).has("resilient_sphere") or monster.get("conditions", {}).has("paralyzed") or monster.get("conditions", {}).has("stunned") or monster.get("conditions", {}).has("power_word_stun_speed_zero"):
		return 0
	var speed := maxi(0, int(monster.get("speed", 6)) - (2 if not monster.get("fighter_slow_sources", []).is_empty() else 0))
	return int(floor(float(speed) / 2.0)) if monster.get("fighter_stood_up", false) else speed
