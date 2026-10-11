## Durable created Undead; control expiry never deletes their existence.
class_name CreatedCreatureRules
extends RefCounted

const FORMS := {
	"skeleton": {"name": "Skeleton", "hp": 13, "ac": 14, "speed": 6, "scores": {"STR": 10, "DEX": 16, "CON": 15, "INT": 6, "WIS": 8, "CHA": 5}, "damage": "1d6", "ability": "DEX", "attack_bonus": 5, "damage_type": "piercing"},
	"zombie": {"name": "Zombie", "hp": 15, "ac": 8, "speed": 4, "scores": {"STR": 13, "DEX": 6, "CON": 16, "INT": 3, "WIS": 6, "CHA": 5}, "damage": "1d8", "ability": "STR", "attack_bonus": 3, "damage_type": "bludgeoning"}
}

static func controlled(record: Dictionary, now: int = -1) -> bool:
	if record.get("source_spell", "") == "animate_objects": return AnimatedObjectRules.controlled(record)
	if now < 0: now = int(GameManager.campaign_elapsed_seconds)
	return int(record.get("current_hp", 0)) > 0 and int(record.get("control_until", 0)) > now

static func get_record(id: String) -> Dictionary:
	for record in GameManager.created_creatures:
		if str(record.get("id", "")) == id: return record
	return {}

static func dungeon_id() -> String:
	return str(GameManager.active_dungeon_state.get("dungeon_id", GameManager.transition_context.get("dungeon_id", "")))

static func in_room(record: Dictionary, room: Dictionary) -> bool:
	return int(record.get("current_hp", 0)) > 0 and str(record.get("dungeon_id", "")) == dungeon_id() and str(record.get("room_id", "")) == str(room.get("id", ""))

static func room_records(room: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in GameManager.created_creatures:
		if in_room(record, room): result.append(record)
	return result

static func hostile_in_room(room: Dictionary) -> bool:
	for record in room_records(room):
		if record.get("source_spell") == "animate_dead" and not controlled(record): return true
	return false

static func occupied(room: Dictionary, position: Vector2i) -> bool:
	for record in room_records(room):
		if LocalRoomRules.coord(record["position"]) == position: return true
	return false

static func _free_cell(room: Dictionary, origin: Vector2i, party: Array, ignored_object: String = "") -> Vector2i:
	for position in HexUtils.get_hexes_in_range(origin, 2):
		if not LocalRoomRules.passable(room, position) or occupied(room, position): continue
		var object := LocalRoomRules.object_at(room, position)
		if not object.is_empty() and str(object.get("id", "")) != ignored_object: continue
		var blocked := false
		for member in party:
			if LocalRoomRules.coord(room.get("party_positions", {}).get(member.character_id, [9999, 9999])) == position or FamiliarRules.position(member, str(room.get("id", ""))) == position or PaladinRules.find_steed_room_position(member, str(room.get("id", ""))) == position: blocked = true
		if not blocked: return position
	return FamiliarRules.ABSENT

## Following is a declared standing order; expired control leaves the creature behind.
static func enter_room(room: Dictionary, party: Array) -> void:
	AnimatedObjectRules.reconcile()
	for record in GameManager.created_creatures:
		if not controlled(record) or not bool(record.get("following", false)) or in_room(record, room): continue
		for owner in party:
			if owner.character_id != str(record["owner_id"]): continue
			var origin := LocalRoomRules.coord(room["party_positions"][owner.character_id])
			var destination := _free_cell(room, origin, party)
			if destination == FamiliarRules.ABSENT: break
			record["dungeon_id"] = dungeon_id()
			record["room_id"] = str(room["id"])
			record["position"] = [destination.x, destination.y]
			break

static func animate(room: Dictionary, caster: Character, party: Array, body_id: String) -> Dictionary:
	if GameManager.current_state == GameManager.GameState.COMBAT: return LocalRoomRules.failure("Animate Dead takes one minute; use the room casting control.")
	var spell := DataLoader.get_spell("animate_dead")
	var error := LocalRoomRules._room_spell_caster_error(caster, spell)
	if not error.is_empty(): return LocalRoomRules.failure(error)
	var object := LocalRoomRules.get_object(room, body_id)
	var body_character: Character = null
	for member in party:
		if str(member.corpse_state.get("corpse_id", "")) == body_id: body_character = member
	var remains := ""
	var position := FamiliarRules.ABSENT
	if body_character != null:
		if not body_character.is_dead() or body_character.creature_type != "humanoid" or body_character.get_creature_size() not in ["small", "medium"] or "transformed_undead" in body_character.corpse_state.get("recovery_restrictions", []): return LocalRoomRules.failure("Choose unanimated Small or Medium Humanoid remains.")
		if CorpseRules.protected_from_undeath(body_character, int(GameManager.campaign_elapsed_seconds)): return LocalRoomRules.failure("Gentle Repose protects those remains from becoming Undead.")
		remains = str(body_character.corpse_state.get("remains", ""))
		position = LocalRoomRules.coord(room["party_positions"][body_character.character_id])
	elif not object.is_empty():
		if str(object.get("kind", "")) != "remains" or bool(object.get("removed", false)) or str(object.get("body_creature_type", "")) != "humanoid" or str(object.get("size", "")).to_lower() not in ["small", "medium"] or int(object.get("hp", 1)) <= 0: return LocalRoomRules.failure("Choose unanimated Small or Medium Humanoid remains.")
		if int(object.get("preserved_until", 0)) > GameManager.campaign_elapsed_seconds: return LocalRoomRules.failure("Gentle Repose protects those remains from becoming Undead.")
		remains = str(object.get("remains", ""))
		position = LocalRoomRules.coord(object["position"])
	else: return LocalRoomRules.failure("Choose recorded remains.")
	if remains not in ["intact", "partial", "bones"]: return LocalRoomRules.failure("Only a corpse or a pile of bones can become this Undead.")
	var origin := LocalRoomRules.coord(room["party_positions"][caster.character_id])
	if HexUtils.get_distance(origin, position) > 2 or not LocalRoomBodies._clear_path(room, origin, position): return LocalRoomRules.failure("Move within 10 feet of the remains with an unobstructed path.")
	var destination := _free_cell(room, position, party, body_id)
	if destination == FamiliarRules.ABSENT: return LocalRoomRules.failure("There is no legal space for the created creature; no slot was spent.")
	if int(caster.spell_slots.get("3", 0)) <= 0: return LocalRoomRules.failure("This Crown path needs a level 3 slot; higher-slot multi-body casting is not supported yet.")
	if GameManager.created_creatures.size() >= 100: return LocalRoomRules.failure("The campaign's created-creature record limit is full.")
	var form_id := "skeleton" if remains == "bones" else "zombie"
	var form: Dictionary = FORMS[form_id]
	var now := int(GameManager.campaign_elapsed_seconds) + 60
	var serial := int(GameManager.next_created_creature_id)
	var record := {"id": "created:%d" % serial, "serial": serial, "owner_id": caster.character_id, "source_spell": "animate_dead", "body_id": body_id if body_character != null else "%s:%s" % [room["id"], body_id], "form_id": form_id, "current_hp": int(form["hp"]), "max_hp": int(form["hp"]), "created_at": now, "control_started_at": now, "control_until": now + 86400, "existence_until": -1, "dungeon_id": dungeon_id(), "room_id": str(room["id"]), "position": [destination.x, destination.y], "following": false, "order": "guard", "order_target": ""}
	caster.spell_slots["3"] = int(caster.spell_slots["3"]) - 1
	GameManager.next_created_creature_id += 1
	GameManager.created_creatures.append(record)
	if body_character != null: body_character.corpse_state["recovery_restrictions"].append("transformed_undead")
	else: object["removed"] = true
	return {"success": true, "seconds": 60, "creature_id": record["id"], "message": "A %s rises. Control lasts 24 hours; it waits and Dodges until commanded. Use Follow owner to bring it to another room." % form["name"]}

static func renew(room: Dictionary, caster: Character, ids: Array[String]) -> Dictionary:
	if GameManager.current_state == GameManager.GameState.COMBAT: return LocalRoomRules.failure("Renewing Animate Dead takes one minute; use the room casting control.")
	var error := LocalRoomRules._room_spell_caster_error(caster, DataLoader.get_spell("animate_dead"))
	if not error.is_empty(): return LocalRoomRules.failure(error)
	if ids.is_empty() or ids.size() > 4: return LocalRoomRules.failure("Choose one to four Undead you animated.")
	var records: Array[Dictionary] = []
	var origin := LocalRoomRules.coord(room["party_positions"][caster.character_id])
	var complete := int(GameManager.campaign_elapsed_seconds) + 60
	for id in ids:
		var record := get_record(id)
		if record.is_empty() or record in records or not in_room(record, room) or record["owner_id"] != caster.character_id or not controlled(record, complete): return LocalRoomRules.failure("Control must still be active when the one-minute recast finishes.")
		if HexUtils.get_distance(origin, LocalRoomRules.coord(record["position"])) > 2 or not LocalRoomBodies._clear_path(room, origin, LocalRoomRules.coord(record["position"])): return LocalRoomRules.failure("Every selected Undead must be within 10 feet with an unobstructed path.")
		records.append(record)
	if int(caster.spell_slots.get("3", 0)) <= 0: return LocalRoomRules.failure("No level 3 spell slot remains.")
	caster.spell_slots["3"] = int(caster.spell_slots["3"]) - 1
	for record in records:
		record["control_started_at"] = complete
		record["control_until"] = complete + 86400
	return {"success": true, "seconds": 60, "message": "Control renewed for 24 hours over %d Undead; their identity and damage are retained." % records.size()}

static func command_feature(owner: Character, id: String) -> Dictionary:
	if owner == null or not owner.is_alive or CombatAction.is_incapacitated(owner) or id not in ["created_attack", "created_guard", "animated_attack", "animated_guard"]: return {}
	var source := "animate_objects" if id.begins_with("animated_") else "animate_dead"
	for record in GameManager.created_creatures:
		if record.get("source_spell") == source and controlled(record) and record["owner_id"] == owner.character_id:
			return {"id": id, "name": "Order %s to %s" % ["Constructs" if source == "animate_objects" else "Undead", "attack" if id.ends_with("attack") else "Dodge"], "type": "active", "action_cost": "bonus_action"}
	return {}

static func character(record: Dictionary) -> Character:
	if record.get("source_spell") == "animate_objects": return AnimatedObjectRules.character(record)
	var form: Dictionary = FORMS[str(record["form_id"])]
	var creature := Character.new()
	creature.character_id = str(record["id"])
	creature.character_name = "%s %s" % [form["name"], str(record["serial"])]
	creature.class_id = "created_creature"
	creature.creature_type = "undead"
	creature.ability_scores.from_dict(form["scores"])
	creature.base_ac = int(form["ac"])
	creature.max_hp = int(record["max_hp"])
	creature.current_hp = int(record["current_hp"])
	creature.is_alive = creature.current_hp > 0
	creature.speed = int(form["speed"])
	creature.feature_uses["creature_size"] = "medium"
	creature.feature_uses["creature_darkvision_range_feet"] = 60
	creature.feature_uses["created_form_id"] = str(record["form_id"])
	creature.saving_throw_proficiencies.assign(["WIS"] if str(record["form_id"]) == "zombie" else [])
	creature.features.append({"id": "created_undead_immunities", "effects": [{"type": "immunity", "condition": "poisoned"}, {"type": "immunity", "condition": "exhaustion"}]})
	var form_id := str(record.get("form_id", ""))
	var monster_data: Dictionary = DataLoader.get_monster(form_id)
	for ability in monster_data.get("special_abilities", []):
		if ability is Dictionary:
			creature.features.append(ability.duplicate(true))
	return creature

static func monster(record: Dictionary) -> Dictionary:
	var form: Dictionary = FORMS[str(record["form_id"])]
	var attacks: Array = [attack_profile(record)]
	if record["form_id"] == "skeleton": attacks.append(attack_profile(record, true))
	var monster_form_id := str(record.get("form_id", ""))
	var monster_def: Dictionary = DataLoader.get_monster(monster_form_id)
	var special_abilities: Array = []
	for ability in monster_def.get("special_abilities", []):
		if ability is Dictionary:
			special_abilities.append(ability.duplicate(true))
	return {"id": record["id"], "name": "%s %s (uncontrolled)" % [form["name"], str(record["serial"])], "created_creature_id": record["id"], "monster_id": "", "creature_type": "undead", "size": "medium", "max_hp": record["max_hp"], "current_hp": record["current_hp"], "armor_class": form["ac"], "speed": form["speed"], "ability_scores": form["scores"].duplicate(), "attacks": attacks, "is_alive": int(record["current_hp"]) > 0, "hex_position": LocalRoomRules.coord(record["position"]), "conditions": {}, "spell_slots": {}, "damage_immunities": ["poison"], "damage_vulnerabilities": ["bludgeoning"] if str(record["form_id"]) == "skeleton" else [], "condition_immunities": ["poisoned", "exhaustion"], "saving_throw_bonuses": {"WIS": 0} if str(record["form_id"]) == "zombie" else {}, "senses": {"darkvision": 60}, "undead_fortitude": str(record["form_id"]) == "zombie", "special_abilities": special_abilities, "color": Color.RED, "ai_behavior": "aggressive", "loot_table": []}

static func attack_profile(record: Dictionary, ranged: bool = false) -> Dictionary:
	if record.get("source_spell") == "animate_objects": return AnimatedObjectRules.attack_profile(record)
	var form: Dictionary = FORMS[str(record["form_id"])]
	ranged = ranged and record["form_id"] == "skeleton"
	return {"id": "created_%s_attack" % record["form_id"], "name": "Shortbow" if ranged else "Shortsword" if record["form_id"] == "skeleton" else "Slam", "type": "weapon", "weapon_type": "simple", "ability": form["ability"], "attack_bonus_override": form["attack_bonus"], "damage": "%s+%s" % [form["damage"], form["ability"]], "damage_type": form["damage_type"], "range": 16 if ranged else 1, "long_range": 64 if ranged else 1, "properties": ["ranged"] if ranged else []}

static func settle(players: Array, monsters: Array) -> void:
	for entity in players:
		if not entity.get("is_created_creature", false): continue
		var creature: Character = entity["character"]
		var record := get_record(creature.character_id)
		if record.is_empty(): continue
		record["current_hp"] = maxi(0, creature.current_hp)
		var position: Vector2i = entity["hex_position"]
		record["position"] = [position.x, position.y]
	for entity in monsters:
		var record := get_record(str(entity.get("created_creature_id", "")))
		if record.is_empty(): continue
		record["current_hp"] = maxi(0, int(entity["current_hp"]))
		var position: Vector2i = entity["hex_position"]
		record["position"] = [position.x, position.y]

static func saved_error(value: Variant, next_id: Variant, now: int) -> String:
	if not value is Array or value.size() > 100 or not CorpseRules._integer(next_id, 1): return "created creature ledger is invalid"
	var ids: Dictionary = {}
	var bodies: Dictionary = {}
	for record in value:
		if not record is Dictionary: return "created creature is not an object"
		if not CorpseRules._integer(record.get("serial", null), 1) or int(record["serial"]) >= int(next_id) or record.get("id") != "created:%d" % int(record["serial"]) or ids.has(record["id"]): return "created creature identity is invalid"
		ids[record["id"]] = true
		for key in ["owner_id", "body_id", "dungeon_id", "room_id"]:
			if not record.get(key) is String or str(record[key]).is_empty() or str(record[key]).length() > 150: return "created creature source or location is invalid"
		if bodies.has(record["body_id"]): return "created creatures share the same remains"
		bodies[record["body_id"]] = true
		if record.get("source_spell") == "animate_objects":
			var object_error := AnimatedObjectRules.saved_error(record, now)
			if not object_error.is_empty(): return object_error
			continue
		if record.get("source_spell") != "animate_dead" or record.get("form_id") not in FORMS or record.get("existence_until") != -1 or not record.get("following") is bool or record.get("order") not in ["guard", "attack"] or not record.get("order_target") is String or str(record["order_target"]).length() > 150: return "created creature rules are invalid"
		var form: Dictionary = FORMS[str(record["form_id"])]
		if not CorpseRules._integer(record.get("current_hp", null), 0) or record.get("max_hp") != form["hp"] or int(record["current_hp"]) > int(form["hp"]): return "created creature health is invalid"
		for key in ["created_at", "control_started_at", "control_until"]:
			if not CorpseRules._integer(record.get(key, null), 0): return "created creature clock is invalid"
		if int(record["created_at"]) > int(record["control_started_at"]) or int(record["control_started_at"]) > now or int(record["control_until"]) - int(record["control_started_at"]) != 86400: return "created creature control interval is invalid"
		if not DungeonPersistence.coordinate(record.get("position")): return "created creature position is invalid"
	return ""

static func resolve_fortitude(_target, _hp_before: int, _damage: int, _damage_type: String, _critical: bool) -> bool:
	# Deprecated: Zero-HP replacement is handled data-driven by CombatAction.resolve_zero_hp_replacement.
	return false

static func saved_locations_error(records: Array, campaign: Dictionary, snapshots: Dictionary, active: Dictionary) -> String:
	for record in records:
		if not campaign.get("dungeons", {}).has(str(record["dungeon_id"])): return "created creature references an unknown dungeon"
		var room: Dictionary = {}
		for dungeon in [active, snapshots.get(str(record["dungeon_id"]), {})]:
			if dungeon.get("dungeon_id", "") != record["dungeon_id"]: continue
			for candidate in dungeon.get("local_rooms", {}).values():
				if candidate.get("id", "") == record["room_id"]: room = candidate
		if room.is_empty() or not room.get("cells", []).any(func(cell): return LocalRoomRules.coord(cell) == LocalRoomRules.coord(record["position"])): return "created creature lies outside its saved room"
		if int(record["current_hp"]) > 0 and not LocalRoomRules.passable(room, LocalRoomRules.coord(record["position"])): return "created creature occupies an impassable room space"
	return ""
