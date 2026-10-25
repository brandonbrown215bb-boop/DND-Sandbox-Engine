extends Node

func _ready() -> void:
	GameManager.test_mode = true
	TetherGroupChecks.load_fixtures()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://tether_object_anchor_manifest.json"))
	if not manifest is Dictionary or int(manifest.get("pid", 0)) == OS.get_process_id(): return _fail("Object anchor recovery requires a separate process")
	if not SaveManager.load_game(str(manifest.get("slot", ""))): return _fail("Allowed object anchor checkpoint refused")
	var caster: Character = PartyManager.characters.get(str(manifest.caster))
	var victim: Character = PartyManager.characters.get(str(manifest.victim))
	var character_caster: Character = PartyManager.characters.get(str(manifest.character_caster))
	var character_victim: Character = PartyManager.characters.get(str(manifest.character_victim))
	if caster == null or victim == null or character_caster == null or character_victim == null: return _fail("Object anchor checkpoint lost a party member")
	var room: Dictionary = {}
	for candidate in GameManager.active_dungeon_state.get("local_rooms", {}).values():
		if candidate is Dictionary and str(candidate.get("id", "")) == str(manifest.room_id):
			room = candidate
			break
	if room.is_empty(): return _fail("Object anchor checkpoint lost its room")
	GameManager.transition_context["local_room"] = room
	var anchor := LocalRoomRules.get_object(room, str(manifest.anchor))
	var relation: Dictionary = anchor.get("tethers", {}).get(str(manifest.relation), {})
	var condition_source := str(manifest.condition_source)
	var bindings := TetherRules.binding(victim, [caster])
	if anchor.is_empty() or relation.is_empty() or bindings.size() != 1 or str(bindings[0].relation) != str(manifest.relation) or str(relation.get("condition_source_id", "")) != condition_source or int(relation.get("hp", -1)) != int(manifest.tether_hp):
		return _fail("Object anchor relation was not rebuilt from its exact saved object record")
	if int(caster.spell_cast_serial) != int(manifest.serial) or int(anchor.hp) != int(manifest.hp) or anchor.position != manifest.position or relation.get("anchor_position") != manifest.position or int(relation.get("anchor_hp", -1)) != int(manifest.hp) or str(relation.get("anchor_plane", "")) != str(anchor.get("plane", "")):
		return _fail("Object anchor identity, location, plane, HP or cast serial changed on recovery")
	var condition_record: Dictionary = victim.spell_effects.get(condition_source, {})
	if not TetherRules.has_source(victim, condition_source) or int(condition_record.get("remaining_seconds", -1)) != int(manifest.remaining_seconds) or bool(condition_record.get("concentration", true)):
		return _fail("Independent victim condition source or remaining duration changed on recovery")
	var character_bindings := TetherRules.binding(character_victim, [character_caster])
	if character_bindings.size() != 1 or str(character_bindings[0].relation) != str(manifest.character_relation) or not TetherRules.has_source(character_victim, str(manifest.character_source)):
		return _fail("Character-anchor sibling did not recover with the object tether")
	print("TETHER OBJECT ANCHOR FRESH-PROCESS RECOVERY PASSED")
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[TetherObjectAnchorRecovery] " + message)
	get_tree().quit(1)
