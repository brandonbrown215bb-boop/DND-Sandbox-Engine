## Ordinary combat actions. Costs belong to CombatState, never HUD payloads.
class_name OrdinaryActionRules
extends RefCounted

const ACTIONS := ["help_check", "ready", "dash", "disengage", "dodge", "hide", "help_attack", "stabilize", "search", "utilize", "study", "influence"]
const LABELS := {"help_check":"Help a skill/tool check", "ready":"Ready", "dash":"Dash", "disengage":"Disengage", "dodge":"Dodge", "hide":"Hide", "help_attack":"Help an attack", "stabilize":"Help: stabilize", "search":"Search", "utilize":"Utilize a room object", "study":"Study a room source", "influence":"Influence a creature"}
const HIDE_SOURCE := "ordinary_action:hide"


static func remove_hidden(actor) -> void:
	if actor is Character:
		actor.remove_condition("hidden")
		actor.combat_hide_dc = 0
	elif actor is Dictionary:
		actor.get("conditions", {}).erase("hidden")
		actor.get("condition_sources", {}).erase("hidden")
		actor.erase("combat_hide_dc")


static func hide_error(actor, origin: Vector2i, enemies: Array, grid: HexGrid) -> String:
	if grid == null or not grid.has_tile(origin): return "There is no represented hiding place here."
	var obscured := CombatAction.has_condition(actor, "fog_cloud_obscured") or CombatAction.has_condition(actor, "darkness_obscured") or CombatPerception.illumination_level_at(grid, origin) == "dark"
	for area in grid.obscurement_sources.values():
		if origin in area.get("coords", []): obscured = true
	# Only actual intervening Three-Quarters/Total Cover supplies this location gate.
	var behind_cover := false
	for enemy in enemies:
		var subject = enemy.get("character", enemy)
		if not _alive(subject): continue
		var position: Vector2i = enemy.get("hex_position", Vector2i.ZERO)
		if CoverRules.degree(position, origin, grid) >= 2: behind_cover = true
		if CombatPerception.can_see_before_hide(subject, actor, position, origin, grid):
			return "You must be out of every enemy's sight to Hide."
	if not obscured and not behind_cover: return "Hide requires heavy obscurement or Three-Quarters/Total Cover."
	return ""


static func hide(actor, context: Dictionary) -> Dictionary:
	var check: Dictionary
	if actor is Character:
		check = EventResolver.resolve_skill_check(actor, {"ability":"DEX", "skill":"Stealth", "dc":15}, {}, context)
	else:
		check = EventResolver.resolve_monster_ability_check(actor, "DEX", "Stealth", 15, 0, {}, context)
	if bool(check.get("success", false)):
		CombatAction.apply_condition(actor, "hidden", -1, HIDE_SOURCE)
		if actor is Character: actor.combat_hide_dc = int(check.total)
		else: actor["combat_hide_dc"] = int(check.total)
	return check


static func search(actor: Character, origin: Vector2i, enemies: Array, grid: HexGrid, context: Dictionary) -> Dictionary:
	# One actual Perception check; no list of undiscovered targets is exposed.
	var check := EventResolver.resolve_skill_check(actor, {"ability":"WIS", "skill":"Perception", "sense":"hearing", "dc":0}, {}, context)
	var found := 0
	for enemy in enemies:
		var target = enemy.get("character", enemy)
		var dc: int = target.combat_hide_dc if target is Character else int(target.get("combat_hide_dc", 0))
		var position: Vector2i = enemy.get("hex_position", Vector2i.ZERO)
		# Reuse the represented 60-foot hearing boundary; no sound propagation
		# around corners or through walls is inferred. Deafened auto-fails.
		if dc <= 0 or not _alive(target) or not CombatAction.has_condition(target, "hidden") or not CombatNoiseRules.can_hear(actor, origin, position, grid, CombatNoiseRules.VERBAL_SOUND, target, LocalRoomCombat.room()): continue
		if not bool(check.get("auto_failed", false)) and int(check.get("total", -99)) >= dc:
			remove_hidden(target)
			CombatPerception.reveal_location(actor, target, position, grid)
			found += 1
	return {"check":check, "found":found}


static func start_turn(actor, enemies: Array) -> void:
	if actor is Character:
		actor.remove_condition("dodging")
	else:
		actor.get("conditions", {}).erase("dodging")
		actor.get("condition_sources", {}).erase("dodging")
	var id := CombatAction.actor_id(actor)
	for enemy in enemies:
		if str(enemy.get("familiar_helped_by", "")) == id: enemy.erase("familiar_helped_by")


static func _alive(actor) -> bool:
	return actor.is_alive if actor is Character else bool(actor.get("is_alive", false))
