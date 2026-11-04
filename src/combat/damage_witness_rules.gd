## Ends markers carrying ends_on_seen_ally_damage when a creature sees one of
## its allies (same side of the live combat roster) take damage. The live
## CombatState binds itself; without a bound roster nothing is witnessed.
class_name DamageWitnessRules
extends RefCounted

const CONSEQUENCE := "ends_on_seen_ally_damage"
static var _combat: WeakRef = null

static func bind(combat) -> void:
	_combat = weakref(combat)

static func unbind(combat) -> void:
	if _combat != null and _combat.get_ref() == combat: _combat = null

static func on_damage(target) -> Array:
	var combat = _combat.get_ref() if _combat != null else null
	if combat == null or target == null: return []
	return witness(target, combat.player_entities, combat.monster_entities, combat.hex_grid)

## Generic roster form: players are {character, hex_position}; monsters are dicts.
static func witness(target, players: Array, monsters: Array, grid) -> Array:
	var side := []
	var target_hex = null
	for entity in players:
		if is_same(entity.get("character"), target): target_hex = entity.get("hex_position", Vector2i.ZERO)
	if target_hex != null:
		for entity in players:
			if entity.get("character") != null and not is_same(entity.get("character"), target): side.append([entity.get("character"), entity.get("hex_position", Vector2i.ZERO)])
	else:
		for monster in monsters:
			if is_same(monster, target): target_hex = monster.get("hex_position", Vector2i.ZERO)
		if target_hex == null: return []
		for monster in monsters:
			if not is_same(monster, target): side.append([monster, monster.get("hex_position", Vector2i.ZERO)])
	var ended := []
	for pair in side:
		var viewer = pair[0]
		if CombatAction.conditions_with_consequence(viewer, CONSEQUENCE).is_empty(): continue
		if viewer is Character and not viewer.is_alive: continue
		if viewer is Dictionary and not bool(viewer.get("is_alive", true)): continue
		if grid == null or not CombatPerception.can_see_target(viewer, target, pair[1], target_hex, grid): continue
		CombatAction.end_markers_with(viewer, CONSEQUENCE)
		ended.append(viewer)
	return ended
