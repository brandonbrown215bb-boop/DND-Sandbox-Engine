## Shared, position-aware support for passive allied auras.
class_name AuraRules
extends RefCounted

const FEET_PER_HEX := 5
const INCAPACITATING_CONDITIONS := ["incapacitated", "unconscious", "paralyzed", "petrified", "stunned"]


## Snapshot nearby Character aura owners after combatant positions change.
static func refresh_party_context(player_entities: Array) -> void:
	var members: Array[Dictionary] = []
	for entity in player_entities:
		if not entity is Dictionary:
			continue
		var character: Character = entity.get("character")
		if character == null:
			continue
		members.append({"character": character, "position": entity.get("hex_position", Vector2i.ZERO)})
	for member in members:
		var recipient: Character = member["character"]
		recipient.saving_throw_aura_sources.clear()
		if not recipient.is_alive:
			continue
		for source_member in members:
			var source: Character = source_member["character"]
			if not source.is_alive or source.get_feature_effect("saving_throw_aura").is_empty():
				continue
			var hex_distance := HexUtils.get_distance(member["position"], source_member["position"])
			recipient.saving_throw_aura_sources.append({"source_ref": weakref(source), "distance_feet": hex_distance * FEET_PER_HEX})


## Return the strongest active nearby saving-throw aura bonus. Matching auras
## do not stack, so a creature with two sources receives only the larger one.
static func saving_throw_bonus(recipient: Character) -> int:
	if recipient == null:
		return 0
	var best_bonus := 0
	for entry in recipient.saving_throw_aura_sources:
		var source := _source_from_entry(entry)
		if not _source_is_active(source):
			continue
		var aura := source.get_feature_effect("saving_throw_aura")
		if aura.is_empty() or int(entry.get("distance_feet", 0)) > _aura_radius_feet(source, str(aura.get("aura_id", "")), int(aura.get("radius_feet", 0))):
			continue
		var ability := str(aura.get("ability", "CHA"))
		var bonus := maxi(int(aura.get("minimum_bonus", 1)), source.ability_scores.get_ability_modifier(ability))
		best_bonus = maxi(best_bonus, bonus)
	return best_bonus


## An immunity aura suppresses the condition while the recipient is in range;
## keeping the underlying duration lets it resume if the recipient leaves.
static func suppresses_condition(recipient: Character, condition_name: String) -> bool:
	if recipient == null or condition_name.is_empty():
		return false
	for entry in recipient.saving_throw_aura_sources:
		var source := _source_from_entry(entry)
		if not _source_is_active(source):
			continue
		for feature in source.features:
			for effect in source._feature_effects(feature):
				if effect.get("type", "") != "condition_immunity_aura" or str(effect.get("condition", "")) != condition_name:
					continue
				var aura_id := str(effect.get("aura_id", ""))
				var aura := _saving_throw_aura(source, aura_id)
				if not aura.is_empty() and int(entry.get("distance_feet", 0)) <= _aura_radius_feet(source, aura_id, int(aura.get("radius_feet", 0))):
					return true
	return false


static func _source_from_entry(entry: Dictionary) -> Character:
	var source_ref: WeakRef = entry.get("source_ref")
	return source_ref.get_ref() as Character if source_ref != null else null


static func _source_is_active(source: Character) -> bool:
	if source == null or not source.is_alive:
		return false
	for condition in INCAPACITATING_CONDITIONS:
		if source.conditions.has(condition):
			return false
	return not source.get_feature_effect("saving_throw_aura").is_empty()


static func _saving_throw_aura(source: Character, aura_id: String) -> Dictionary:
	var aura := source.get_feature_effect("saving_throw_aura")
	return aura if str(aura.get("aura_id", "")) == aura_id else {}


static func _aura_radius_feet(source: Character, aura_id: String, base_radius: int) -> int:
	var radius := base_radius
	for feature in source.features:
		for effect in source._feature_effects(feature):
			if effect.get("type", "") == "aura_radius_expansion" and str(effect.get("aura_id", "")) == aura_id:
				radius = maxi(radius, int(effect.get("radius_feet", 0)))
	return radius
