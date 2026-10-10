## The spell-specific state for the persistent 2024 Otherworldly Steed.
## Spell selection, slot spending, combat turns, and damage stay in their shared paths.
class_name PaladinRules
extends RefCounted

const FIND_STEED_STATE_KEY := "paladin_find_steed_state"
const LAY_ON_HANDS_CONDITIONS: Array[String] = ["poisoned", "blinded", "charmed", "deafened", "frightened", "paralyzed", "stunned"]
const RESTORING_TOUCH_CONDITIONS: Array[String] = ["blinded", "charmed", "deafened", "frightened", "paralyzed", "stunned"]
const ABJURE_FOES_MARKER := "paladin_abjure_foes_frightened"
const ABJURE_FOES_CASTER_ID := "paladin_abjure_foes_caster_id"


## Resolve selected monster saves and the damage-ending Frightened condition.
## Range and the Charisma-based target cap are enforced here as well as in UI.
static func resolve_abjure_foes(paladin: Character, targets: Array[Dictionary], origin: Vector2i) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if paladin == null or paladin.class_id != "paladin" or not paladin.has_feature("paladin_abjure_foes"):
		return results
	var feature := paladin.get_feature("paladin_abjure_foes")
	var effect: Dictionary = {}
	for candidate in feature.get("effects", []):
		if candidate.get("type", "") == "abjure_foes":
			effect = candidate
			break
	if effect.is_empty():
		return results
	var target_limit := maxi(1, paladin.ability_scores.get_ability_modifier("CHA"))
	var range_hexes := maxi(0, int(effect.get("range_feet", 60)) / 5)
	var save_dc := paladin.get_spell_save_dc()
	for target in targets:
		if results.size() >= target_limit:
			break
		if not target.get("is_alive", false) or HexUtils.get_distance(origin, target.get("hex_position", Vector2i.ZERO)) > range_hexes:
			continue
		if "frightened" in target.get("condition_immunities", []):
			results.append({"target_id": str(target.get("id", "")), "immune": true, "message": "%s is immune to Frightened." % str(target.get("name", "Creature"))})
			continue
		var save_total := BarbarianRules.roll_monster_save(target, str(effect.get("save", "WIS")))
		var saved := save_total >= save_dc
		if not saved:
			CombatAction.apply_condition(target, str(effect.get("condition", "frightened")), int(effect.get("duration_rounds", 10)), "abjure_foes")
			target[ABJURE_FOES_MARKER] = true
			target[ABJURE_FOES_CASTER_ID] = paladin.character_id
		results.append({
			"target_id": str(target.get("id", "")),
			"saved": saved,
			"save_total": save_total,
			"save_dc": save_dc,
			"duration_rounds": int(effect.get("duration_rounds", 10)) if not saved else 0,
			"message": "%s %s a DC %d Wisdom save%s." % [str(target.get("name", "Creature")), "succeeds on" if saved else "fails", save_dc, " and is Frightened by Abjure Foes" if not saved else ""]
		})
	return results


## Remove Abjure Foes' Frightened condition after the target takes damage.
static func clear_abjure_foes_after_damage(target: Dictionary) -> void:
	if not target.has(ABJURE_FOES_MARKER):
		return
	CombatAction.remove_condition_source(target, "abjure_foes", ["frightened"])
	target.erase(ABJURE_FOES_MARKER)
	target.erase(ABJURE_FOES_CASTER_ID)


## Abjure Foes' frightened creature cannot willingly move closer to its caster.
static func abjure_foes_source_position(target: Dictionary, players: Array[Dictionary]) -> Variant:
	if not target.get(ABJURE_FOES_MARKER, false):
		return null
	var caster_id := str(target.get(ABJURE_FOES_CASTER_ID, ""))
	for player in players:
		var character: Character = player.get("character")
		if character != null and character.character_id == caster_id and character.is_alive:
			return player.get("hex_position", Vector2i.ZERO)
	return null


static func abjure_foes_forbids_movement_closer(target: Dictionary, destination: Vector2i, players: Array[Dictionary]) -> bool:
	var source_position: Variant = abjure_foes_source_position(target, players)
	if source_position == null or not source_position is Vector2i:
		return false
	var origin: Vector2i = target.get("hex_position", Vector2i.ZERO)
	return HexUtils.get_distance(destination, source_position) < HexUtils.get_distance(origin, source_position)


static func create_find_steed_state(caster: Character, spell_data: Dictionary, slot_level: int, creature_type: String, form: String) -> Dictionary:
	if caster == null or caster.class_id != "paladin" or caster.level < 5 or not caster.has_feature("paladin_faithful_steed"):
		return {"success": false, "message": "Faithful Steed is unavailable."}
	if str(spell_data.get("id", "")) != "find_steed":
		return {"success": false, "message": "Find Steed needs its registered spell record."}
	var summon: Dictionary = spell_data.get("summoned_creature", {})
	if str(summon.get("kind", "")) != "otherworldly_steed":
		return {"success": false, "message": "Find Steed has no Otherworldly Steed data."}
	var valid_types: Array = summon.get("creature_types", [])
	var valid_forms: Array = summon.get("forms", [])
	if creature_type not in valid_types or form not in valid_forms:
		return {"success": false, "message": "Choose an eligible steed appearance and creature type."}
	var effective_level := maxi(int(spell_data.get("level", 2)), slot_level)
	var ac_data: Dictionary = summon.get("armor_class", {})
	var hp_data: Dictionary = summon.get("hit_points", {})
	var max_hp := int(hp_data.get("base", 5)) + int(hp_data.get("per_spell_level", 10)) * effective_level
	var state := {
		"creature_type": creature_type,
		"form": form,
		"spell_level": effective_level,
		"armor_class": int(ac_data.get("base", 10)) + int(ac_data.get("per_spell_level", 1)) * effective_level,
		"max_hp": max_hp,
		"current_hp": max_hp,
		"ability_scores": summon.get("ability_scores", {}).duplicate(true),
		"speed_feet": int(summon.get("speed_feet", 60)),
		"fly_speed_feet": int(summon.get("fly_speed_feet", 60)) if effective_level >= int(summon.get("fly_from_spell_level", 4)) else 0,
		"long_rest_ability_used": false,
		"mounted": false,
	}
	caster.feature_uses[FIND_STEED_STATE_KEY] = state.duplicate(true)
	return {"success": true, "state": state, "message": "%s's Otherworldly Steed appears as a %s %s." % [caster.character_name, creature_type.capitalize(), form.capitalize()]}


static func find_steed_state(caster: Character) -> Dictionary:
	if caster == null:
		return {}
	var value: Variant = caster.feature_uses.get(FIND_STEED_STATE_KEY, {})
	return value.duplicate(true) if value is Dictionary else {}


static func update_find_steed_hit_points(caster: Character, current_hp: int) -> void:
	var state := find_steed_state(caster)
	if state.is_empty():
		return
	state["current_hp"] = clampi(current_hp, 0, int(state.get("max_hp", 1)))
	if int(state["current_hp"]) <= 0:
		caster.feature_uses.erase(FIND_STEED_STATE_KEY)
	else:
		caster.feature_uses[FIND_STEED_STATE_KEY] = state


static func set_find_steed_mounted(caster: Character, mounted: bool) -> bool:
	var state := find_steed_state(caster)
	if state.is_empty() or int(state.get("current_hp", 0)) <= 0:
		return false
	state["mounted"] = mounted
	caster.feature_uses[FIND_STEED_STATE_KEY] = state
	return true


static func find_steed_is_mounted(caster: Character) -> bool:
	return bool(find_steed_state(caster).get("mounted", false))


static func find_steed_room_position(caster: Character, room_id: String) -> Vector2i:
	var state := find_steed_state(caster)
	var position: Variant = state.get("local_room_position", null)
	if str(state.get("local_room_id", "")) != room_id or not position is Array or position.size() != 2:
		return Vector2i(9999, 9999)
	return Vector2i(int(position[0]), int(position[1]))


static func set_find_steed_room_position(caster: Character, room_id: String, position: Vector2i) -> bool:
	var state := find_steed_state(caster)
	if state.is_empty() or int(state.get("current_hp", 0)) <= 0:
		return false
	state["local_room_id"] = room_id
	state["local_room_position"] = [position.x, position.y]
	caster.feature_uses[FIND_STEED_STATE_KEY] = state
	return true


static func dismiss_find_steed(caster: Character) -> void:
	if caster != null:
		caster.feature_uses.erase(FIND_STEED_STATE_KEY)


static func saved_steed_error(data: Dictionary) -> String:
	var uses: Variant = data.get("feature_uses", {})
	if not uses is Dictionary: return "character feature state is malformed"
	if not uses.has(FIND_STEED_STATE_KEY): return ""
	var state: Variant = uses[FIND_STEED_STATE_KEY]
	if not state is Dictionary or str(data.get("class_id", "")) != "paladin": return "steed owner or state is invalid"
	var summon: Dictionary = DataLoader.get_spell("find_steed").get("summoned_creature", {})
	if state.get("creature_type") not in summon.get("creature_types", []) or state.get("form") not in summon.get("forms", []): return "steed appearance or type is invalid"
	for field in ["spell_level", "armor_class", "max_hp", "current_hp", "speed_feet", "fly_speed_feet"]:
		var value: Variant = state.get(field)
		if (not value is int and not value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)): return "steed statistics are invalid"
	var spell_level := int(state["spell_level"])
	if spell_level < 2 or spell_level > 9: return "steed spell level is invalid"
	var ac: Dictionary = summon.get("armor_class", {})
	var hp: Dictionary = summon.get("hit_points", {})
	if int(state["armor_class"]) != int(ac.get("base", 10)) + int(ac.get("per_spell_level", 1)) * spell_level or int(state["max_hp"]) != int(hp.get("base", 5)) + int(hp.get("per_spell_level", 10)) * spell_level: return "steed statistics do not match its spell level"
	if int(state["current_hp"]) < 1 or int(state["current_hp"]) > int(state["max_hp"]): return "steed hit points are invalid"
	var fly_speed := int(summon.get("fly_speed_feet", 60)) if spell_level >= int(summon.get("fly_from_spell_level", 4)) else 0
	if int(state["speed_feet"]) != int(summon.get("speed_feet", 60)) or int(state["fly_speed_feet"]) != fly_speed: return "steed movement is invalid"
	if not state.get("mounted") is bool or not state.get("long_rest_ability_used") is bool: return "steed activity state is invalid"
	if not state.get("ability_scores") is Dictionary: return "steed ability scores are invalid"
	for ability in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		if state["ability_scores"].get(ability) != summon.get("ability_scores", {}).get(ability): return "steed ability scores are invalid"
	if state.has("local_room_id") or state.has("local_room_position"):
		if not state.get("local_room_id") is String or str(state["local_room_id"]).is_empty() or not DungeonPersistence.coordinate(state.get("local_room_position")): return "steed room position is invalid"
	return ""


## Return the steed's spell-defined actions. They use the shared attack and
## combat action budgets; only their unusual effects are resolved here.
static func find_steed_features(state: Dictionary) -> Array[Dictionary]:
	var features: Array[Dictionary] = [{
		"id": "otherworldly_steed_slam",
		"name": "Otherworldly Slam",
		"type": "active",
		"action_cost": "action",
	}]
	var ability_by_type := {
		"celestial": {"id": "otherworldly_steed_healing_touch", "name": "Healing Touch"},
		"fey": {"id": "otherworldly_steed_fey_step", "name": "Fey Step"},
		"fiend": {"id": "otherworldly_steed_fell_glare", "name": "Fell Glare"},
	}
	var ability: Dictionary = ability_by_type.get(str(state.get("creature_type", "celestial")), {})
	if not ability.is_empty():
		features.append({
			"id": str(ability["id"]),
			"name": str(ability["name"]),
			"type": "active",
			"action_cost": "bonus_action",
			"uses": 1,
			"uses_per": "long_rest",
		})
	return features


static func resolve_steed_slam(owner: Character, steed: Character, target: Dictionary, creature_type: String, spell_level: int) -> Dictionary:
	if owner == null or steed == null or target.is_empty():
		return {"success": false, "message": "Otherworldly Slam needs a living target."}
	var damage_type := "radiant" if creature_type == "celestial" else ("psychic" if creature_type == "fey" else "fire")
	var weapon := {
		"type": "weapon",
		"id": "otherworldly_steed_slam",
		"name": "Otherworldly Slam",
		"ability": "CHA",
		"attack_bonus_override": owner.get_spell_save_dc() - 8,
		"damage": "1d8+%d" % maxi(2, spell_level),
		"damage_type": damage_type,
		"range": 1,
		"attack_distance": 1,
	}
	return CombatAction.resolve_weapon_attack(steed, target, weapon)


static func mark_find_steed_ability_used(owner: Character) -> bool:
	var state := find_steed_state(owner)
	if state.is_empty() or bool(state.get("long_rest_ability_used", false)):
		return false
	state["long_rest_ability_used"] = true
	owner.feature_uses[FIND_STEED_STATE_KEY] = state
	return true


static func restore_find_steed_ability(owner: Character) -> void:
	var state := find_steed_state(owner)
	if state.is_empty():
		return
	state["long_rest_ability_used"] = false
	owner.feature_uses[FIND_STEED_STATE_KEY] = state


static func apply_life_bond(owner: Character, steed: Character, healing: int) -> int:
	if owner == null or steed == null or find_steed_state(owner).is_empty() or not steed.is_alive:
		return 0
	var restored := steed.heal(healing)
	if restored > 0:
		update_find_steed_hit_points(owner, steed.current_hp)
	return restored


static func lay_on_hands_conditions(paladin: Character, target: Character) -> Array[String]:
	var present: Array[String] = []
	if paladin == null or target == null:
		return present
	for condition in LAY_ON_HANDS_CONDITIONS:
		if condition != "poisoned" and not paladin.has_feature("paladin_restoring_touch"):
			continue
		if target.conditions.has(condition):
			present.append(condition)
	return present
