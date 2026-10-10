## Finds only magical state the combat model currently represents.
class_name DetectMagicRules
extends RefCounted

static func auras_within(origin: Vector2i, player_entities: Array, monster_entities: Array, spell_zones: Dictionary) -> Array[Dictionary]:
	var auras: Array[Dictionary] = []
	var seen: Dictionary = {}
	for player in player_entities:
		var character: Character = player.get("character")
		if character == null or not character.is_alive:
			continue
		if HexUtils.get_distance(origin, player.get("hex_position", Vector2i.ZERO)) > 6:
			continue
		_append_effect_auras(auras, seen, character.character_name, character.spell_effects)
		for item_aura in character.inventory.magic_item_aura_instances():
			var item_key := "item:%s" % str(item_aura.get("instance_id", ""))
			if seen.has(item_key):
				continue
			seen[item_key] = true
			var item := DataLoader.get_item(str(item_aura.get("item_id", "")))
			auras.append({"name": str(item_aura.get("name", "Magic item")), "school": str(item.get("school", "unknown")), "location": "%s's carried item" % character.character_name, "instance_id": str(item_aura.get("instance_id", ""))})
	for monster in monster_entities:
		if not bool(monster.get("is_alive", false)) or HexUtils.get_distance(origin, monster.get("hex_position", Vector2i.ZERO)) > 6:
			continue
		_append_effect_auras(auras, seen, str(monster.get("name", "Creature")), monster.get("spell_effects", {}))
	for source_value in spell_zones:
		var zone: Dictionary = spell_zones[source_value]
		var spell_id := str(zone.get("spell_id", ""))
		if spell_id.is_empty() or (not zone.has("center") and not zone.has("position")):
			continue
		var center: Vector2i = zone.get("center", zone.get("position", Vector2i.ZERO))
		var radius := maxi(0, int(zone.get("radius_hexes", 0)))
		if HexUtils.get_distance(origin, center) > 6 + radius:
			continue
		var aura_key := "%s:%s:area" % [str(source_value), spell_id]
		if seen.has(aura_key):
			continue
		seen[aura_key] = true
		var spell: Dictionary = DataLoader.get_spell(spell_id)
		auras.append({"name": str(spell.get("name", spell_id.replace("_", " ").capitalize())), "school": str(spell.get("school", "")), "location": "spell area", "source_id": str(source_value)})
	return auras


static func _append_effect_auras(auras: Array[Dictionary], seen: Dictionary, target_name: String, effect_records: Dictionary) -> void:
	for source_value in effect_records:
		var record: Dictionary = effect_records[source_value]
		var spell_id := str(record.get("spell_id", ""))
		if spell_id.is_empty() or int(record.get("remaining_seconds", 1)) == 0:
			continue
		var aura_key := "%s:%s:%s" % [str(source_value), spell_id, target_name]
		if seen.has(aura_key):
			continue
		seen[aura_key] = true
		var spell: Dictionary = DataLoader.get_spell(spell_id)
		auras.append({"name": str(spell.get("name", spell_id.replace("_", " ").capitalize())), "school": str(spell.get("school", "")), "location": target_name, "source_id": str(source_value)})
