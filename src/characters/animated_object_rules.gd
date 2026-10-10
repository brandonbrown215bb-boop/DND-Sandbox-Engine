## Room objects retain their identity while a temporary Construct uses separate HP.
class_name AnimatedObjectRules
extends RefCounted

const SIZES := ["tiny", "small", "medium", "large", "huge"]
const CONDITIONS := ["charmed", "exhaustion", "frightened", "paralyzed", "poisoned"]

static func owner(record: Dictionary) -> Character:
	for member in PartyManager.characters.values():
		if member.character_id == record.get("owner_id", ""): return member
	return null

static func controlled(record: Dictionary) -> bool:
	var caster := owner(record)
	return int(record.get("current_hp", 0)) > 0 and int(record.get("existence_until", 0)) > GameManager.campaign_elapsed_seconds and caster != null and caster.is_alive and not CombatAction.is_incapacitated(caster) and caster.concentrating_on.get("effect_source", "") == record.get("source_id", "")

static func weight(object: Dictionary) -> int:
	return 3 if str(object.get("size", "medium")).to_lower() == "huge" else 2 if str(object.get("size", "medium")).to_lower() == "large" else 1

static func hp(size: String) -> int:
	return 40 if size == "huge" else 20 if size == "large" else 10

static func eligible(object: Dictionary) -> bool:
	return CombatObjectRules.can_take_spell_damage(object) and not bool(object.get("fixed", false)) and str(object.get("kind", "")) != "remains" and str(object.get("size", "medium")).to_lower() in SIZES and object.get("contents", []).is_empty()

static func preflight(room: Dictionary, caster: Character, ids: Array[String], origin: Vector2i, players: Array, monsters: Array = []) -> String:
	var error := LocalRoomRules._room_spell_caster_error(caster, DataLoader.get_spell("animate_objects"))
	if not error.is_empty(): return error
	if room.is_empty() or ids.is_empty(): return "Choose recorded unattended room objects."
	var maximum := caster.ability_scores.get_ability_modifier(caster.get_spellcasting_ability())
	var used := 0
	var seen: Array[String] = []
	for id in ids:
		var object := LocalRoomRules.get_object(room, id)
		if id in seen or not eligible(object): return "Choose distinct nonmagical, unfixed, unattended objects up to Huge size. Containers with item copies are not supported yet."
		seen.append(id)
		used += weight(object)
		var position := LocalRoomRules.coord(object["position"])
		if HexUtils.get_distance(origin, position) > 24 or not LocalRoomBodies._clear_path(room, origin, position): return "Every object must be within 120 feet with an unobstructed path."
		if not LocalRoomRules.passable(room, position) or CreatedCreatureRules.occupied(room, position): return "An animated object needs a legal unoccupied space."
		for entity in players:
			var position_value: Variant = entity.get("hex_position") if entity is Dictionary else room.get("party_positions", {}).get(entity.character_id)
			var character: Character = entity.get("character") if entity is Dictionary else entity
			if character != null and character.current_hp > 0 and position_value != null and (position_value if position_value is Vector2i else LocalRoomRules.coord(position_value)) == position: return "An animated object cannot overlap another creature."
		for entity in monsters:
			if entity.get("is_alive", false) and entity.get("hex_position") == position: return "An animated object cannot overlap another creature."
	if used > maximum: return "Selected object weight %d exceeds your spellcasting modifier of %d (Large counts as two; Huge as three)." % [used, maximum]
	if GameManager.created_creatures.size() + ids.size() > 100: return "The campaign's created-creature record limit is full."
	return ""

static func create(room: Dictionary, caster: Character, ids: Array[String], slot_level: int) -> Array[Dictionary]:
	var spell := DataLoader.get_spell("animate_objects")
	var cast := SpellEffects.begin_cast(caster, spell)
	var source := str(cast["source_id"])
	caster.spell_effects[source] = cast
	caster.concentrating_on = {"spell_id": "animate_objects", "effect_source": source, "targets": []}
	var result: Array[Dictionary] = []
	var now := int(GameManager.campaign_elapsed_seconds)
	var ability_mod := caster.ability_scores.get_ability_modifier(caster.get_spellcasting_ability())
	for id in ids:
		var object := LocalRoomRules.get_object(room, id)
		var size := str(object.get("size", "medium")).to_lower()
		var serial := int(GameManager.next_created_creature_id)
		var record := {"id": "created:%d" % serial, "serial": serial, "owner_id": caster.character_id, "source_spell": "animate_objects", "source_id": source, "body_id": "%s:%s" % [room["id"], id], "object_id": id, "object_size": size, "object_name": str(object["name"]), "form_id": "animated_object", "current_hp": hp(size), "max_hp": hp(size), "created_at": now, "control_started_at": now, "control_until": now + 60, "existence_until": now + 60, "dungeon_id": CreatedCreatureRules.dungeon_id(), "room_id": str(room["id"]), "position": object["position"].duplicate(), "following": false, "order": "guard", "order_target": "", "slot_level": slot_level, "ability_mod": ability_mod, "attack_bonus": caster.proficiency_bonus + ability_mod, "proficiency_bonus": caster.proficiency_bonus}
		object["removed"] = true
		object["animation_id"] = record["id"]
		GameManager.next_created_creature_id += 1
		GameManager.created_creatures.append(record)
		result.append(record)
	return result

static func cast_room(room: Dictionary, caster: Character, party: Array, ids: Array[String]) -> Dictionary:
	var origin := LocalRoomRules.coord(room["party_positions"][caster.character_id])
	var error := preflight(room, caster, ids, origin, party)
	if not error.is_empty(): return LocalRoomRules.failure(error)
	var spent := CombatAction.spend_spell_slot(caster, DataLoader.get_spell("animate_objects"))
	if not spent.get("success", false): return LocalRoomRules.failure(str(spent.get("message", "No slot remains.")))
	SpellEffects.end_concentration(caster, party)
	create(room, caster, ids, int(spent["slot_level"]))
	return {"success": true, "seconds": 6, "message": "%d objects animate. They wait and Dodge until ordered, and revert when Concentration ends." % ids.size()}

static func character(record: Dictionary) -> Character:
	var creature := Character.new()
	creature.character_id = str(record["id"])
	creature.character_name = "Animated %s" % record["object_name"]
	creature.class_id = "created_creature"
	creature.creature_type = "construct"
	creature.ability_scores.from_dict({"STR": 16, "DEX": 10, "CON": 10, "INT": 3, "WIS": 3, "CHA": 1})
	creature.proficiency_bonus = int(record["proficiency_bonus"])
	creature.base_ac = 15
	creature.max_hp = int(record["max_hp"])
	creature.current_hp = int(record["current_hp"])
	creature.is_alive = creature.current_hp > 0
	creature.speed = 6
	creature.feature_uses["creature_size"] = record["object_size"]
	creature.feature_uses["creature_blindsight_range_feet"] = 30
	creature.feature_uses["created_form_id"] = "animated_object"
	var effects: Array = []
	for condition in CONDITIONS: effects.append({"type": "immunity", "condition": condition})
	creature.features.append({"id": "animated_object_immunities", "effects": effects})
	return creature

static func attack_profile(record: Dictionary) -> Dictionary:
	var size := str(record["object_size"])
	var extra := maxi(0, int(record["slot_level"]) - 5)
	var damage := "%dd4+3" % (1 + extra)
	if size == "large": damage = "%dd6+%d" % [2 + extra, 3 + int(record["ability_mod"])]
	if size == "huge": damage = "%dd12+%d" % [2 + extra, 3 + int(record["ability_mod"])]
	return {"id": "animated_slam", "name": "Slam", "type": "weapon", "ability": "STR", "attack_bonus_override": int(record["attack_bonus"]), "damage": damage, "damage_type": "force", "range": 1, "fixed_damage": true, "properties": []}

static func revert(record: Dictionary, excess_damage: int = 0) -> void:
	for room in GameManager.saved_local_room_states():
		if room.get("id", "") != record.get("room_id", ""): continue
		var object := LocalRoomRules.get_object(room, str(record["object_id"]))
		if object.is_empty() or object.get("animation_id", "") != record["id"]: continue
		object["position"] = record["position"].duplicate()
		object["hp"] = maxi(0, int(object.get("hp", 1)) - excess_damage)
		object["removed"] = int(object["hp"]) <= 0
		object.erase("animation_id")
	GameManager.created_creatures.erase(record)

static func end_source(caster_id: String, source_id: String) -> void:
	for record in GameManager.created_creatures.duplicate():
		if record.get("source_spell") == "animate_objects" and record.get("owner_id") == caster_id and record.get("source_id") == source_id: revert(record)

static func reconcile() -> void:
	for record in GameManager.created_creatures.duplicate():
		if record.get("source_spell") == "animate_objects" and not controlled(record): revert(record)

static func damage(target: Character, hp_before: int, hp_damage: int) -> void:
	var record := CreatedCreatureRules.get_record(target.character_id)
	if record.get("source_spell", "") != "animate_objects": return
	record["current_hp"] = maxi(0, target.current_hp)
	if target.current_hp <= 0: revert(record, maxi(0, hp_damage - hp_before))

static func saved_error(record: Dictionary, now: int) -> String:
	if record.get("form_id") != "animated_object" or record.get("object_size") not in SIZES: return "animated object form is invalid"
	for key in ["source_id", "object_id", "object_name"]:
		if not record.get(key) is String or str(record[key]).is_empty() or str(record[key]).length() > 150: return "animated object source is invalid"
	if record.get("body_id") != "%s:%s" % [record["room_id"], record["object_id"]] or not str(record["source_id"]).begins_with("spell:%s:" % record["owner_id"]): return "animated object identity is invalid"
	if not CorpseRules._integer(record.get("current_hp"), 1) or record.get("max_hp") != hp(str(record["object_size"])) or int(record["current_hp"]) > int(record["max_hp"]): return "animated object HP is invalid"
	for key in ["created_at", "control_started_at", "control_until", "existence_until"]:
		if not CorpseRules._integer(record.get(key), 0): return "animated object clock is invalid"
	if record["control_started_at"] != record["created_at"] or int(record["created_at"]) > now or record["control_until"] != record["existence_until"] or int(record["existence_until"]) - int(record["created_at"]) != 60 or int(record["existence_until"]) <= now: return "animated object lifetime is invalid"
	if record.get("following") != false or record.get("order") not in ["guard", "attack"] or not record.get("order_target") is String or str(record["order_target"]).length() > 150 or not DungeonPersistence.coordinate(record.get("position")): return "animated object order or position is invalid"
	if not CorpseRules._integer(record.get("slot_level"), 5) or int(record["slot_level"]) > 9 or not CorpseRules._integer(record.get("proficiency_bonus"), 2) or int(record["proficiency_bonus"]) > 6 or not CorpseRules._integer(record.get("ability_mod"), 1) or int(record["ability_mod"]) > 10 or record.get("attack_bonus") != int(record["proficiency_bonus"]) + int(record["ability_mod"]): return "animated object captured casting statistics are invalid"
	return ""

static func saved_links_error(records: Array, rooms: Array, characters: Dictionary) -> String:
	for record in records:
		if record.get("source_spell") != "animate_objects": continue
		var dto: Dictionary = characters.get(str(record["owner_id"]), {})
		var concentration: Dictionary = dto.get("spell_concentration", {})
		var effect: Dictionary = dto.get("spell_effects", {}).get(str(record["source_id"]), {})
		if concentration.get("effect_source") != record["source_id"] or effect.get("spell_id") != "animate_objects" or int(effect.get("remaining_seconds", 0)) > int(record["existence_until"]) - int(record["created_at"]): return "animated object has no matching Concentration source"
		var found := false
		for room in rooms:
			if room.get("id") != record["room_id"]: continue
			var object := LocalRoomRules.get_object(room, str(record["object_id"]))
			if object.get("animation_id") == record["id"] and object.get("removed") == true and int(object.get("hp", 0)) > 0: found = true
		if not found: return "animated object has no retained original object"
	for room in rooms:
		for object in room.get("objects", []):
			if object.has("animation_id") and not records.any(func(record): return record.get("source_spell") == "animate_objects" and record.get("id") == object["animation_id"] and record.get("room_id") == room.get("id") and record.get("object_id") == object.get("id")): return "object refers to a missing animated creature"
	return ""
