## Cleric Channel Divinity effects that share saving throws, target damage, and
## the class's Channel Divinity pool with other combat features.
class_name ClericRules
extends RefCounted

static func resolve_divine_spark(cleric: Character, target, mode: String, damage_type: String = "radiant") -> Dictionary:
	if cleric == null or target == null or mode not in ["heal", "harm"]:
		return {"success": false, "message": "Divine Spark needs another creature and a valid choice."}
	if target is Character and target == cleric:
		return {"success": false, "message": "Divine Spark must target another creature."}
	if not can_receive_spark(target):
		return {"success": false, "message": "Divine Spark needs a living target."}
	var dice_count := 1
	if cleric.level >= 18:
		dice_count = 4
	elif cleric.level >= 13:
		dice_count = 3
	elif cleric.level >= 7:
		dice_count = 2
	var wisdom_modifier := cleric.ability_scores.get_ability_modifier("WIS")
	var amount := maxi(0, Dice.parse_dice_string("%dd8+WIS" % dice_count, {"WIS": wisdom_modifier}, cleric))
	var target_name := _target_name(target)
	if mode == "heal":
		var healed: int = 0
		if target is Character:
			healed = target.heal(amount)
		if target is Dictionary:
			var missing := maxi(0, int(target.get("max_hp", 0)) - int(target.get("current_hp", 0)))
			healed = 0 if CombatAction.is_healing_suppressed(target) else mini(amount, missing)
			target["current_hp"] = int(target.get("current_hp", 0)) + healed
			target["is_alive"] = int(target["current_hp"]) > 0
		return {"success": true, "healing": healed, "message": "%s restores %d Hit Points to %s with Divine Spark." % [cleric.character_name, healed, target_name]}
	if damage_type not in ["radiant", "necrotic"]:
		return {"success": false, "message": "Divine Spark damage must be Radiant or Necrotic."}
	var dc := cleric.get_spell_save_dc()
	var save_total := _saving_throw_total(target, "CON")
	var saved := save_total >= dc
	var damage := int(floor(float(amount) / 2.0)) if saved else amount
	var actual := _apply_damage(target, damage, damage_type)
	if actual > 0:
		clear_turning_after_damage(target)
	return {"success": true, "damage": actual, "saved": saved, "save_total": save_total, "save_dc": dc, "damage_type": damage_type, "message": "%s %s a DC %d Constitution save and takes %d %s damage from Divine Spark." % [target_name, "succeeds on" if saved else "fails", dc, actual, damage_type.capitalize()]}


static func resolve_turn_undead(cleric: Character, monsters: Array[Dictionary], origin: Vector2i, selected_ids: Array = [], use_sear: bool = true) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if cleric == null:
		return results
	var dc := cleric.get_spell_save_dc()
	var sear_dice := maxi(1, cleric.ability_scores.get_ability_modifier("WIS")) if cleric.has_feature("cleric_sear_undead") and use_sear else 0
	var source_id := "turn_undead:%s" % cleric.character_id
	var sear_damage := Dice.parse_dice_string("%dd8" % sear_dice, {}, cleric) if sear_dice > 0 else 0
	for target in monsters:
		if not target.get("is_alive", false) or str(target.get("creature_type", "")).to_lower() != "undead":
			continue
		if HexUtils.get_distance(origin, target.get("hex_position", Vector2i.ZERO)) > 6:
			continue
		if not selected_ids.is_empty() and str(target.get("id", "")) not in selected_ids:
			continue
		var target_name := _target_name(target)
		var save_total := _saving_throw_total(target, "WIS")
		var saved := save_total >= dc
		var damage := 0
		if not saved:
			CombatAction.apply_condition(target, "frightened", 10, source_id)
			CombatAction.apply_condition(target, "incapacitated", 10, source_id)
			if CombatAction.has_condition_source(target, source_id):
				var casters: Dictionary = target.get("turn_undead_casters", {})
				casters[source_id] = cleric.character_id
				target["turn_undead_casters"] = casters
				target["turn_undead_origin"] = origin
			if sear_damage > 0:
				# Sear Undead's own damage does not end the turning it just applied.
				damage = int(CombatAction.resolve_damage(target, sear_damage, "radiant", {}, false, true)["damage"])
		results.append({
			"target_id": str(target.get("id", target.get("monster_id", ""))),
			"saved": saved,
			"damage": damage,
			"save_total": save_total,
			"save_dc": dc,
			"message": "%s %s a DC %d Wisdom save%s." % [target_name, "succeeds on" if saved else "fails", dc, " and is turned" + (" for %d Radiant damage" % damage if damage > 0 else "") if not saved else ""]
		})
	return results


static func _is_living_target(target) -> bool:
	if target is Character:
		return target.is_alive or target.death_save_failures < 3
	if target is Dictionary:
		return bool(target.get("is_alive", true))
	return false


static func _target_name(target) -> String:
	return str(target.character_name) if target is Character else str(target.get("name", "Creature"))


static func _saving_throw_total(target, ability: String) -> int:
	if target is Character:
		return target.make_saving_throw(ability)
	if target is Dictionary:
		return BarbarianRules.roll_monster_save(target, ability)
	return -1000


static func _apply_damage(target, amount: int, damage_type: String) -> int:
	return int(CombatAction.resolve_damage(target, amount, damage_type)["damage"])


static func _apply_target_condition(target, condition: String, duration: int) -> void:
	CombatAction.apply_condition(target, condition, duration)


static func clear_turning_after_damage(target) -> void:
	if not target is Dictionary:
		return
	PaladinRules.clear_abjure_foes_after_damage(target)
	for condition in ["frightened", "incapacitated"]:
		for source in target.get("condition_sources", {}).get(condition, {}).keys():
			if str(source) == "turn_undead" or str(source).begins_with("turn_undead:"):
				CombatAction.remove_condition_source(target, source, ["frightened", "incapacitated"])
	target.erase("turn_undead_origin")
	target.erase("turn_undead_casters")


## Turning is combat-local. Each caster owns only its grants; movement follows
## the caster's current position, and loss of that caster releases those grants.
static func reconcile_turning(monsters: Array[Dictionary], players: Array[Dictionary]) -> void:
	for monster in monsters:
		var casters: Dictionary = monster.get("turn_undead_casters", {})
		for source in casters.keys():
			var owner: Dictionary = {}
			for player in players:
				var character: Character = player.get("character")
				if character != null and character.character_id == casters[source]:
					owner = player
					break
			var character: Character = owner.get("character")
			if character == null or not character.is_alive or CombatAction.is_incapacitated(character) or not CombatAction.has_condition_source(monster, source):
				CombatAction.remove_condition_source(monster, source, ["frightened", "incapacitated"])
				casters.erase(source)
			else:
				monster["turn_undead_origin"] = owner.get("hex_position", Vector2i.ZERO)
		if casters.is_empty() and monster.has("turn_undead_casters"):
			monster.erase("turn_undead_casters")
			monster.erase("turn_undead_origin")


static func can_receive_spark(target) -> bool:
	return _is_living_target(target) and (not target is Character or not target.disintegrated)


static func channel_divinity_error(cleric: Character) -> String:
	if cleric == null or not cleric.is_alive or CombatAction.is_incapacitated(cleric):
		return "Channel Divinity requires a conscious Cleric able to act."
	if not cleric.inventory.has_item("holy_symbol"):
		return "Channel Divinity requires a Holy Symbol."
	if int(cleric.feature_uses.get("cleric_channel_divinity", 0)) <= 0:
		return "No Channel Divinity uses remain."
	return ""


static func saved_state_error(dto: Dictionary) -> String:
	var uses: Variant = dto.get("feature_uses", {})
	if not uses is Dictionary:
		return "Feature uses are not an object"
	if not uses.has("cleric_divine_intervention_recovery_rests"):
		return ""
	var rests: Variant = uses["cleric_divine_intervention_recovery_rests"]
	if not rests is int and not rests is float:
		return "Divine Intervention cooldown must be a number"
	if not is_finite(float(rests)) or float(rests) != floor(float(rests)) or rests < 0 or rests > 8 or str(dto.get("class_id", "")) != "cleric" or int(dto.get("level", 1)) < 20:
		return "Divine Intervention cooldown is invalid"
	if rests > 0 and uses.get("cleric_divine_intervention", 0) != 0:
		return "Divine Intervention cannot be available during its cooldown"
	return ""

static func divine_intervention_spell_options(cleric: Character) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if cleric == null or not cleric.has_feature("cleric_divine_intervention"):
		return options
	var class_data := DataLoader.get_character_class(cleric.class_id)
	for spell_id in class_data.get("spell_list_ids", []):
		var spell := DataLoader.get_spell(str(spell_id))
		if not SpellSupport.is_available(spell) or int(spell.get("level", 99)) > 5 or str(spell.get("casting_time", "action")) == "reaction":
			continue
		options.append(spell)
	if cleric.has_feature("cleric_greater_divine_intervention"):
		options.append({"id": "wish", "name": "Wish", "level": 9, "casting_time": "action", "target": "single", "description": "Duplicate a cataloged spell of level 8 or lower."})
	return options


static func wish_duplication_spell_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for spell in DataLoader.get_all_spells():
		# These spells currently resolve only through Paladin-owned state/actions.
		if str(spell.get("id", "")) in ["find_steed", "divine_smite"]:
			continue
		if SpellSupport.is_available(spell) and int(spell.get("level", 99)) <= 8 and str(spell.get("casting_time", "action")) != "reaction":
			options.append(spell)
	options.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.get("level", 0)) == int(b.get("level", 0)):
			return str(a.get("name", "")) < str(b.get("name", ""))
		return int(a.get("level", 0)) < int(b.get("level", 0)))
	return options


static func apply_greater_intervention_cooldown(cleric: Character, spell_id: String) -> int:
	if cleric == null or spell_id != "wish" or not cleric.has_feature("cleric_greater_divine_intervention"):
		return 0
	var rests := Dice.parse_dice_string("2d4")
	cleric.feature_uses["cleric_divine_intervention_recovery_rests"] = rests
	cleric.feature_uses["cleric_divine_intervention"] = 0
	return rests


