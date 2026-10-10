## Detection and Identify contact/completion.
class_name SpellEncounterPerception
extends RefCounted


static func _refresh_detect_evil_and_good_senses(cast: SpellCastContext) -> void:
	var active_detectors: Dictionary = {}
	var detectable_types := ["aberration", "celestial", "elemental", "fey", "fiend", "undead"]
	for detector_entry in cast.players:
		var detector: Character = detector_entry.get("character")
		if detector == null or not detector.is_alive or not SpellEffects.has_spell(detector, "detect_evil_and_good"):
			continue
		var detector_id := SpellEffects.caster_id(detector)
		active_detectors[detector_id] = true
		var origin: Vector2i = detector_entry.get("hex_position", Vector2i.ZERO)
		var previous: Dictionary = cast.detected_creatures.get(detector_id, {})
		var current: Dictionary = {}
		for target_entry in cast.players:
			var target: Character = target_entry.get("character")
			if target == null or not target.is_alive or target == detector:
				continue
			var creature_type := target.creature_type.to_lower()
			var target_id := target.character_id if not target.character_id.is_empty() else "runtime_%d" % target.get_instance_id()
			var target_hex: Vector2i = target_entry.get("hex_position", Vector2i.ZERO)
			if HexUtils.get_distance(origin, target_hex) <= 6 and creature_type in detectable_types:
				current[target_id] = {"name": target.character_name, "creature_type": creature_type, "hex": target_hex}
		for target in cast.monsters:
			if not bool(target.get("is_alive", false)):
				continue
			var creature_type := str(target.get("creature_type", "")).to_lower()
			var target_id := str(target.get("id", target.get("monster_id", "")))
			var target_hex: Vector2i = target.get("hex_position", Vector2i.ZERO)
			if target_id.is_empty() or HexUtils.get_distance(origin, target_hex) > 6 or creature_type not in detectable_types:
				continue
			current[target_id] = {"name": str(target.get("name", "Creature")), "creature_type": creature_type, "hex": target_hex}
		for zone_source in cast.areas.active_spell_zones:
			var zone: Dictionary = cast.areas.active_spell_zones[zone_source]
			if str(zone.get("spell_id", "")) != "hallow" or not zone.has("center"):
				continue
			var center: Vector2i = zone.get("center", Vector2i.ZERO)
			if HexUtils.get_distance(origin, center) <= 6 + maxi(0, int(zone.get("radius_hexes", 0))):
				current["hallow:%s" % str(zone_source)] = {"name": "Hallow", "creature_type": "active Hallow", "hex": center}
		for detected_id in current:
			var detected: Dictionary = current[detected_id]
			var location: Vector2i = detected["hex"]
			var was_detected: bool = previous.has(detected_id)
			if was_detected and previous[detected_id].get("hex", Vector2i(-999, -999)) == location:
				continue
			var verb := "senses" if not was_detected else "locates"
			cast.hud.add_log("[color=purple]Detect Evil and Good %s %s (%s) at hex (%d, %d).[/color]" % [verb, str(detected["name"]), str(detected["creature_type"]).capitalize(), location.x, location.y])
		cast.detected_creatures[detector_id] = current
	for detector_id in cast.detected_creatures.keys().duplicate():
		if not active_detectors.has(detector_id):
			cast.detected_creatures.erase(detector_id)


static func _refresh_detect_poison_and_disease_senses(cast: SpellCastContext) -> void:
	var active_detectors: Dictionary = {}
	for detector_entry in cast.players:
		var detector: Character = detector_entry.get("character")
		if detector == null or not detector.is_alive or not SpellEffects.has_spell(detector, "detect_poison_and_disease"):
			continue
		var detector_id := SpellEffects.caster_id(detector)
		active_detectors[detector_id] = true
		var origin: Vector2i = detector_entry.get("hex_position", Vector2i.ZERO)
		var previous: Dictionary = cast.detected_hazards.get(detector_id, {})
		var current: Dictionary = DetectPoisonRules.sensed_hazards(origin, cast.players, cast.monsters)
		for hazard_id in current:
			var hazard: Dictionary = current[hazard_id]
			var location: Vector2i = hazard["hex"]
			var was_sensed: bool = previous.has(hazard_id)
			if was_sensed and previous[hazard_id].get("hex", Vector2i(-999, -999)) == location:
				continue
			var verb := "senses" if not was_sensed else "locates"
			cast.hud.add_log("[color=green]Detect Poison and Disease %s %s (%s) at hex (%d, %d).[/color]" % [verb, str(hazard["name"]), str(hazard["kind"]), location.x, location.y])
		cast.detected_hazards[detector_id] = current
	for detector_id in cast.detected_hazards.keys().duplicate():
		if not active_detectors.has(detector_id):
			cast.detected_hazards.erase(detector_id)


static func _identify_target_remains_touchable(cast: SpellCastContext, caster: Character, identify_target: Dictionary) -> bool:
	if str(identify_target.get("kind", "")) == "item":
		var instance_id := str(identify_target.get("instance_id", ""))
		if instance_id.is_empty():
			var item_id := str(identify_target.get("item_id", ""))
			return item_id in caster.inventory.get_all_equipped() or caster.inventory.has_item(item_id)
		return not caster.inventory.get_instance(instance_id).is_empty()
	var origin := Vector2i.ZERO
	for entry in cast.players:
		if entry.get("character") == caster:
			origin = entry.get("hex_position", Vector2i.ZERO)
			break
	var target_id := str(identify_target.get("target_id", ""))
	for entry in cast.players:
		var target: Character = entry.get("character")
		if target != null and target.is_alive and cast.areas._spell_zone_target_id(target) == target_id:
			return HexUtils.get_distance(origin, entry.get("hex_position", Vector2i.ZERO)) <= 1
	for target in cast.monsters:
		if bool(target.get("is_alive", false)) and cast.areas._spell_zone_target_id(target) == target_id:
			return HexUtils.get_distance(origin, target.get("hex_position", Vector2i.ZERO)) <= 1
	return false


static func _validate_identify_contacts(cast: SpellCastContext) -> void:
	for entry in cast.players:
		var caster: Character = entry.get("character")
		if caster == null:
			continue
		for source in caster.spell_effects.keys().duplicate():
			var record: Dictionary = caster.spell_effects[source]
			if str(record.get("spell_id", "")) != "identify" or not record.has("identify_target"):
				continue
			if SpellEncounterPerception._identify_target_remains_touchable(cast, caster, record.get("identify_target", {})):
				continue
			SpellEncounterLifecycle._end_concentration(cast, caster)
			cast.hud.add_log("[color=orange]Identify ends because contact with its target was broken before the casting finished.[/color]")
			break


static func _complete_identify(cast: SpellCastContext, caster: Character, identify_record: Dictionary) -> void:
	var source_id := str(identify_record.get("source_id", ""))
	var identify_target: Dictionary = identify_record.get("identify_target", {})
	if str(identify_target.get("kind", "")) == "item":
		var item_copy: Dictionary = caster.inventory.get_instance(str(identify_target.get("instance_id", "")))
		var definition_id := str(item_copy.get("definition_id", identify_target.get("item_id", "")))
		var item := DataLoader.get_item(definition_id)
		if item.is_empty():
			cast.hud.add_log("[color=orange]Identify's item is no longer available.[/color]")
		else:
			cast.hud.add_log("[color=violet]%s[/color]" % IdentifyRules.item_report(item, item_copy.get("state", {})))
			if IdentifyRules.is_magic_item(item) and item.get("ongoing_spells", []).is_empty():
				cast.hud.add_log("No ongoing spell or spell that created this item is recorded in the item data.")
	else:
		var target = null
		var target_id := str(identify_target.get("target_id", ""))
		for entry in cast.players:
			var character: Character = entry.get("character")
			if character != null and character.is_alive and cast.areas._spell_zone_target_id(character) == target_id:
				target = character
				break
		if target == null:
			for monster in cast.monsters:
				if bool(monster.get("is_alive", false)) and cast.areas._spell_zone_target_id(monster) == target_id:
					target = monster
					break
		if target == null:
			cast.hud.add_log("[color=orange]Identify's creature target is no longer available.[/color]")
		else:
			var spell_names := IdentifyRules.ongoing_spell_names(target)
			var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
			cast.hud.add_log("[color=violet]Identify reveals %s is affected by: %s.[/color]" % [target_name, ", ".join(spell_names) if not spell_names.is_empty() else "no tracked ongoing spells"])
	if str(caster.concentrating_on.get("effect_source", "")) == source_id:
		caster.concentrating_on.clear()
