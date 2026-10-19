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
		recipient.aura_source_memberships.clear()
		if not recipient.is_alive:
			continue
		for source_member in members:
			var source: Character = source_member["character"]
			if not source.is_alive or not _has_managed_aura(source):
				continue
			var hex_distance := HexUtils.get_distance(member["position"], source_member["position"])
			recipient.aura_source_memberships.append({
				"source_ref": weakref(source),
				"bearer_ref": weakref(source),
				"source_owner_id": source.character_id,
				"bearer_id": source.character_id,
				"recipient_id": recipient.character_id,
				"distance_feet": hex_distance * FEET_PER_HEX,
			})

	AuraProtectionRules.refresh(members)


## Return the strongest active nearby saving-throw aura bonus. Matching auras
## do not stack, so a creature with two sources receives only the larger one.
static func saving_throw_bonus(recipient: Character) -> int:
	if recipient == null:
		return 0
	var best_bonus := 0
	for entry in recipient.aura_source_memberships:
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
	for entry in recipient.aura_source_memberships:
		var source := _source_from_entry(entry)
		var bearer := _bearer_from_entry(entry)
		if not _source_is_active(source) or source.character_id != str(entry.get("source_owner_id", "")) or bearer == null or bearer.character_id != str(entry.get("bearer_id", "")) or recipient.character_id != str(entry.get("recipient_id", "")):
			continue
		for feature in source.features:
			for effect in source._feature_effects(feature):
				if effect.get("type", "") != "condition_immunity_aura" or str(effect.get("condition", "")) != condition_name:
					continue
				var aura_id := str(effect.get("aura_id", ""))
				var radius := _condition_aura_radius(source, effect, aura_id)
				if radius > 0 and int(entry.get("distance_feet", 0)) <= radius:
					return true
	return false


static func _source_from_entry(entry: Dictionary) -> Character:
	var source_ref: WeakRef = entry.get("source_ref")
	return source_ref.get_ref() as Character if source_ref != null else null


static func _bearer_from_entry(entry: Dictionary) -> Character:
	var bearer_ref: WeakRef = entry.get("bearer_ref")
	return bearer_ref.get_ref() as Character if bearer_ref != null else null


static func _source_is_active(source: Character) -> bool:
	if source == null or not source.is_alive:
		return false
	for condition in INCAPACITATING_CONDITIONS:
		if source.conditions.has(condition):
			return false
	return _has_managed_aura(source)


static func _has_managed_aura(source: Character) -> bool:
	if source == null:
		return false
	for feature in source.features:
		for effect in source._feature_effects(feature):
			if str(effect.get("type", "")) == "saving_throw_aura":
				return true
			if str(effect.get("type", "")) == "condition_immunity_aura":
				return true
			if str(effect.get("type", "")) == "protection_aura":
				return true
	return false


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


static func _condition_aura_radius(source: Character, effect: Dictionary, aura_id: String) -> int:
	var own_radius := int(effect.get("radius_feet", 0))
	if own_radius > 0:
		return _aura_radius_feet(source, aura_id, own_radius)
	var linked_aura := _saving_throw_aura(source, aura_id)
	if linked_aura.is_empty():
		return 0
	return _aura_radius_feet(source, aura_id, int(linked_aura.get("radius_feet", 0)))
