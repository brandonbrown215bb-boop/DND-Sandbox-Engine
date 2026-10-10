## Wild Companion's durable creature state; encounter Characters are projections.
class_name FamiliarRules
extends RefCounted

const STATE_KEY := "druid_wild_companion_state"
const FORM_KEY := "druid_wild_companion_form"
const ABSENT := Vector2i(9999, 9999)

static func state(owner: Character) -> Dictionary:
	if owner == null: return {}
	var value: Variant = owner.feature_uses.get(STATE_KEY, {})
	return value.duplicate(true) if value is Dictionary else {}

static func create(owner: Character, form_id: String, origin: String = "wild_companion", creature_type: String = "fey") -> void:
	var form := DataLoader.get_monster(form_id)
	var hp := maxi(1, Dice.parse_dice_string(str(form.get("hit_points", "1"))))
	var existing := state(owner)
	var creature_id := str(existing.get("creature_id", "%s:%s" % ["wild_companion" if origin == "wild_companion" else "familiar", owner.character_id]))
	owner.feature_uses[FORM_KEY] = form_id
	owner.feature_uses[STATE_KEY] = {
		"creature_id": creature_id,
		"owner_id": owner.character_id, "form_id": form_id,
		"max_hp": hp, "current_hp": hp, "pocket": false,
		"origin": origin, "creature_type": creature_type,
		"lifetime": "until_owner_long_rest" if origin == "wild_companion" else "until_dismissed",
	}

static func finish_owner_long_rest(owner: Character) -> void:
	if str(state(owner).get("lifetime", "")) == "until_owner_long_rest": forget(owner)

## Authored exploration checks explicitly decide whether this assistance is
## physically possible. Help is performed for this next check, not banked.
static func skill_help_available(owner: Character, check_data: Dictionary) -> bool:
	if not bool(check_data.get("familiar_help_allowed", false)) or GameManager.current_state == GameManager.GameState.COMBAT: return false
	if owner == null or not owner.is_alive or CombatAction.is_incapacitated(owner): return false
	var skill := str(check_data.get("skill", ""))
	if skill not in ["Perception", "Stealth"]: return false
	var familiar := character(owner)
	return familiar != null and skill in familiar.skill_proficiencies

## Old schema-2 form-only records gain deterministic state, without resource use
## or gameplay dice consumption. The old record did not retain damage.
static func restore_legacy(owner: Character) -> void:
	if owner.feature_uses.has(STATE_KEY): return
	var form_id := str(owner.feature_uses.get(FORM_KEY, ""))
	if form_id not in DruidRules.WILD_COMPANION_FORMS: return
	var form := DataLoader.get_monster(form_id)
	if form.is_empty(): return
	var formula := str(form.get("hit_points", "1"))
	var match_result := RegEx.create_from_string("^(\\d+)d(\\d+)([+-]\\d+)?$").search(formula.replace(" ", ""))
	var hp := maxi(1, int(formula))
	if match_result != null:
		hp = maxi(1, floori(int(match_result.get_string(1)) * (int(match_result.get_string(2)) + 1) / 2.0) + int(match_result.get_string(3)))
	owner.feature_uses[STATE_KEY] = {"creature_id": "wild_companion:%s" % owner.character_id, "owner_id": owner.character_id, "form_id": form_id, "max_hp": hp, "current_hp": hp, "pocket": false, "lifetime": "until_owner_long_rest"}

static func forget(owner: Character) -> void:
	if owner == null: return
	owner.feature_uses.erase(STATE_KEY)
	owner.feature_uses.erase(FORM_KEY)

static func update_hp(owner: Character, hp: int) -> void:
	var record := state(owner)
	if record.is_empty(): return
	if hp <= 0:
		forget(owner)
		return
	record["current_hp"] = mini(hp, int(record["max_hp"]))
	owner.feature_uses[STATE_KEY] = record

static func set_pocket(owner: Character, pocket: bool) -> bool:
	var record := state(owner)
	if record.is_empty(): return false
	record["pocket"] = pocket
	if pocket:
		record.erase("local_room_id")
		record.erase("local_room_position")
	owner.feature_uses[STATE_KEY] = record
	return true

## These controls are derived from an existing bond, not permanent class grants.
## Canonical data also prevents HUD payloads from supplying a cheaper action cost.
static func command_feature(owner: Character, id: String) -> Dictionary:
	var record := state(owner)
	if record.is_empty() or owner == null or not owner.is_alive or CombatAction.is_incapacitated(owner): return {}
	var pocket := bool(record.get("pocket", false))
	if id == "familiar_recall" and not pocket: return {}
	if id == "familiar_dismiss" and pocket: return {}
	if id == "familiar_senses" and pocket: return {}
	var names := {"familiar_recall": "Recall familiar", "familiar_dismiss": "Dismiss familiar", "familiar_release": "Release familiar", "familiar_senses": "Share familiar senses"}
	if not names.has(id): return {}
	return {"id": id, "name": names[id], "type": "active", "action_cost": "bonus_action" if id == "familiar_senses" else "magic_action"}

static func position(owner: Character, room_id: String) -> Vector2i:
	var record := state(owner)
	if record.is_empty() or bool(record.get("pocket", false)) or str(record.get("local_room_id", "")) != room_id: return ABSENT
	var value: Variant = record.get("local_room_position", [])
	return LocalRoomRules.coord(value) if value is Array and value.size() == 2 else ABSENT

static func set_position(owner: Character, room_id: String, destination: Vector2i) -> void:
	var record := state(owner)
	if record.is_empty(): return
	record["local_room_id"] = room_id
	record["local_room_position"] = [destination.x, destination.y]
	owner.feature_uses[STATE_KEY] = record

static func character(owner: Character) -> Character:
	var record := state(owner)
	if record.is_empty() or bool(record.get("pocket", false)): return null
	var form := DataLoader.get_monster(str(record["form_id"]))
	var scores := AbilityScores.new()
	scores.from_dict(form.get("ability_scores", {}))
	var creature := Character.new()
	creature.initialize("%s's %s" % [owner.character_name, form.get("name", "Familiar")], "", "familiar", scores)
	creature.character_id = str(record["creature_id"])
	creature.max_hp = int(record["max_hp"])
	creature.current_hp = int(record["current_hp"])
	creature.base_ac = int(form.get("armor_class", 10))
	creature.speed = int(form.get("speed", 6))
	for mode in ["climb", "swim", "fly"]:
		creature.movement_speeds_feet[mode] = int(form.get("%s_speed_feet" % mode, 0))
	creature.feature_uses["creature_darkvision_range_feet"] = int(form.get("senses", {}).get("darkvision", 0))
	creature.feature_uses["creature_skills"] = form.get("skills", {}).duplicate(true)
	creature.feature_uses["creature_type"] = str(record.get("creature_type", "fey"))
	creature.creature_type = str(record.get("creature_type", "fey"))
	creature.feature_uses["creature_size"] = str(form.get("size", "tiny"))
	for ability in form.get("saving_throw_bonuses", {}):
		creature.saving_throw_proficiencies.append(str(ability))
	for skill in form.get("skills", {}):
		creature.skill_proficiencies.append(str(skill))
	for creature_trait in form.get("special_abilities", []):
		creature.features.append(creature_trait.duplicate(true))
	creature.is_alive = creature.current_hp > 0
	creature.features.append({"id": "familiar_help", "name": "Help", "type": "active", "action_cost": "action"})
	return creature

static func saved_error(data: Dictionary) -> String:
	var uses: Variant = data.get("feature_uses", {})
	if not uses is Dictionary: return "character feature state is malformed"
	var form_value: Variant = uses.get(FORM_KEY, "")
	if not form_value is String: return "familiar form is malformed"
	if not str(form_value).is_empty() and str(form_value) not in DruidRules.WILD_COMPANION_FORMS: return "familiar form is unsupported"
	if not uses.has(STATE_KEY):
		return "familiar form is unsupported" if not str(form_value).is_empty() and str(data.get("class_id", "")) != "druid" else ""
	var record: Variant = uses[STATE_KEY]
	if not record is Dictionary: return "familiar state is malformed"
	var owner_id := str(data.get("character_id", ""))
	if owner_id.is_empty() or record.get("owner_id") != owner_id or record.get("creature_id") not in ["wild_companion:%s" % owner_id, "familiar:%s" % owner_id]: return "familiar ownership is invalid"
	if str(form_value).is_empty() or record.get("form_id") != form_value: return "familiar form does not match its owner record"
	var origin := str(record.get("origin", "wild_companion"))
	if origin not in ["wild_companion", "find_familiar"] or (origin == "wild_companion" and str(data.get("class_id", "")) != "druid"): return "familiar origin is invalid"
	if str(record.get("creature_type", "fey")) not in ["celestial", "fey", "fiend"] or (origin == "wild_companion" and str(record.get("creature_type", "fey")) != "fey"): return "familiar creature type is invalid"
	var lifetime := "until_owner_long_rest" if origin == "wild_companion" else "until_dismissed"
	if record.get("lifetime") != lifetime or not record.get("pocket") is bool: return "familiar lifetime or presence is invalid"
	for key in ["max_hp", "current_hp"]:
		var hp: Variant = record.get(key)
		if (not hp is int and not hp is float) or not is_finite(float(hp)) or float(hp) != floorf(float(hp)) or int(hp) < 1 or int(hp) > 1000: return "familiar hit points are invalid"
	if int(record["current_hp"]) > int(record["max_hp"]): return "familiar hit points exceed maximum"
	if record.has("local_room_id") or record.has("local_room_position"):
		if not record.get("local_room_id") is String or str(record["local_room_id"]).is_empty() or not DungeonPersistence.coordinate(record.get("local_room_position")): return "familiar room position is invalid"
	return ""
