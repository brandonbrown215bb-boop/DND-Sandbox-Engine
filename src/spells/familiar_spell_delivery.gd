## Touch delivery changes range origin, never the caster or its resources.
class_name FamiliarSpellDelivery
extends RefCounted

static func creature(owner: Character, players: Array[Dictionary], require_reaction: bool = true) -> Dictionary:
	if owner == null or not owner.is_alive or CombatAction.is_incapacitated(owner): return {}
	var bond := FamiliarRules.state(owner)
	if bond.is_empty() or bool(bond.get("pocket", false)): return {}
	var owner_entity: Dictionary = {}
	var familiar_entity: Dictionary = {}
	for entity in players:
		if entity.get("character") == owner: owner_entity = entity
		if entity.get("is_familiar", false) and entity.get("familiar_owner") == owner: familiar_entity = entity
	if owner_entity.is_empty() or familiar_entity.is_empty(): return {}
	var familiar: Character = familiar_entity.get("character")
	if familiar == null or not familiar.is_alive or CombatAction.is_incapacitated(familiar) or (require_reaction and not familiar.reaction_available): return {}
	if HexUtils.get_distance(owner_entity["hex_position"], familiar_entity["hex_position"]) > 20: return {}
	return familiar_entity

static func eligible(spell: Dictionary) -> bool:
	return str(spell.get("range_kind", "")) == "touch" and not bool(spell.get("_metamagic_distant", false)) and not bool(spell.get("_magic_item_activation", false))

static func origin(owner: Character, players: Array[Dictionary], spell: Dictionary, fallback: Vector2i) -> Vector2i:
	if not bool(spell.get("_familiar_delivery", false)): return fallback
	var entity := creature(owner, players)
	return entity.get("hex_position", fallback)

static func validate(cast: SpellCastContext) -> bool:
	if not bool(cast.spell.get("_familiar_delivery", false)): return true
	if not eligible(cast.spell):
		cast.hud.add_log("Familiar delivery requires a supported Touch spell at its normal range.")
		return false
	var entity := creature(cast.caster, cast.players)
	if entity.is_empty():
		cast.hud.add_log("Touch delivery needs your present, conscious familiar within 100 feet, with its Reaction available.")
		return false
	var origin_hex: Vector2i = entity["hex_position"]
	var targets: Array[Vector2i] = [cast.target_coord]
	targets.append_array(cast.extra_target_coords)
	if cast.additional_target_coord != FamiliarRules.ABSENT:
		targets.append(cast.additional_target_coord)
	for target in targets:
		if not cast.grid.has_tile(target) or not Targeting.is_in_range(origin_hex, target, 1) or not Targeting.has_line_of_sight(origin_hex, target, cast.grid):
			cast.hud.add_log("The familiar must be able to touch each target within 5 feet; no resource was spent.")
			return false
	cast.delivery_character = entity["character"]
	cast.spell_origin = origin_hex
	return true

static func commit(cast: SpellCastContext) -> void:
	if cast.delivery_character == null: return
	cast.delivery_character.reaction_available = false
	cast.hud.add_log("%s uses its Reaction to deliver %s." % [cast.delivery_character.character_name, str(cast.spell.get("name", "the Touch spell"))])
