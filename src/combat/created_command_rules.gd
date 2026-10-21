## S-156 (Batch 055): command authority over exact owned created actors.
## A template may declare command {cost, range_hexes, orders, default,
## control_seconds}. The owner commands one exact actor (by actor id, so
## same-named actors stay separate); a refused command spends nothing; a valid
## one charges the owner's declared cost once. Uncommanded actors take the
## declared default at the end of the owner's turn. Control expiry only stops
## commands: the actor stays while its source lasts.
class_name CreatedCommandRules
extends RefCounted

const POLICY_KEYS := ["cost", "range_hexes", "orders", "default", "control_seconds"]
const COSTS := ["action", "bonus_action", "none"]
const ORDERS := ["attack", "dodge"]
const DEFAULTS := ["dodge", "none"]
## Uncommanded and unauthored: Bonus Action, 12 hexes (60 ft), attack/Dodge, Dodge.
const DEFAULT := {"cost": "bonus_action", "range_hexes": 12, "orders": ["attack", "dodge"], "default": "dodge"}

## Commanded actor id -> CombatAction.active_turn_serial; transient, never saved.
static var _commanded := {}

static func policy_error(p: Variant) -> String:
	if not p is Dictionary: return "command must be an object"
	for key in p:
		if str(key) not in POLICY_KEYS: return "command has unknown field '%s'" % key
	if p.has("cost") and str(p.cost) not in COSTS: return "command cost must be action, bonus_action or none"
	if p.has("range_hexes") and not CreatedActorRules._int(p.range_hexes, 1, 24): return "command range_hexes must be 1-24"
	if p.has("orders"):
		if not p.orders is Array or p.orders.is_empty() or p.orders.size() > ORDERS.size(): return "command orders must be attack and/or dodge, once each"
		var seen := {}
		for o in p.orders:
			if str(o) not in ORDERS or seen.has(str(o)): return "command orders must be attack and/or dodge, once each"
			seen[str(o)] = true
	if p.has("default") and str(p.default) not in DEFAULTS: return "command default must be dodge or none"
	if p.has("control_seconds") and not CreatedActorRules._int(p.control_seconds, 6, 86400): return "command control_seconds must be 6-86400"
	return ""

static func policy(template: Dictionary) -> Dictionary:
	var out := DEFAULT.duplicate(true)
	var p: Variant = template.get("command", {})
	if p is Dictionary and policy_error(p).is_empty(): out.merge(p, true)
	return out

static func _record(owner: Character, actor: Character) -> Dictionary:
	return owner.spell_effects.get(str(actor.get_meta("created_source_id", "")), {})

static func _template(owner: Character, actor: Character) -> Dictionary:
	var record := _record(owner, actor)
	return CreatedActorRules._template(DataLoader.get_spell(str(record.get("spell_id", ""))), str(record.get("created_actors", {}).get("template_id", "")))

## Control lasts while the source lasts, or until control_until when declared.
static func controlled(owner: Character, actor: Character, now: int = -1) -> bool:
	var data: Dictionary = _record(owner, actor).get("created_actors", {})
	if not data.has("control_until"): return true
	if now < 0: now = int(GameManager.campaign_elapsed_seconds)
	return int(data.control_until) > now

static func _entity(state, actor_id: String) -> Dictionary:
	for e in state.player_entities:
		if str(e.get("combat_id", "")) == actor_id: return e
	return {}

static func _owner_hex(state, owner: Character) -> Vector2i:
	for e in state.player_entities:
		if e.get("character") == owner: return e.get("hex_position", Vector2i.ZERO)
	return Vector2i.ZERO

## Owned, living, placed actors this owner could address now (one row per actor id).
static func actors(state, owner: Character) -> Array:
	var out: Array = []
	for a in CreatedActorRules.actors(owner):
		if a.is_alive and not _entity(state, a.character_id).is_empty(): out.append(a)
	return out

static func command_error(state, owner: Character, actor_id: String, order: String, target_id: String = "") -> String:
	if owner == null or not owner.is_alive or CombatAction.is_incapacitated(owner): return "A conscious owner is required."
	if state.active_character != owner: return "Only the owner can command on the owner's turn."
	var actor: Character = null
	for a in CreatedActorRules.actors(owner):
		if a.character_id == actor_id: actor = a
	if actor == null or CreatedActorRules.owner_of(actor) != owner.character_id: return "You don't own that creature."
	if not actor.is_alive: return "That creature can't act."
	var entity := _entity(state, actor_id)
	if entity.is_empty(): return "That creature is not on the battlefield."
	if not controlled(owner, actor): return "Your control of %s has ended." % actor.character_name
	var p := policy(_template(owner, actor))
	if order not in p.orders: return "%s can't be ordered to %s." % [actor.character_name, order]
	if HexUtils.get_distance(_owner_hex(state, owner), entity.hex_position) > int(p.range_hexes): return "%s is beyond command range (%d ft)." % [actor.character_name, int(p.range_hexes) * 5]
	if int(_commanded.get(actor_id, -1)) == CombatAction.active_turn_serial: return "%s was already commanded this turn." % actor.character_name
	if p.cost != "none" and not state._can_spend_action_cost(str(p.cost)): return "No %s is available to command." % str(p.cost).replace("_", " ")
	if order == "attack":
		var target := _target(state, target_id)
		if target.is_empty(): return "Choose a living enemy."
		var reach := int(_template(owner, actor).get("attack", {}).get("range", 1))
		if HexUtils.get_distance(entity.hex_position, target.hex_position) > reach: return "%s can't reach that enemy." % actor.character_name
	return ""

static func _target(state, target_id: String) -> Dictionary:
	for m in state.monster_entities:
		if str(m.get("id", "")) == target_id and m.get("is_alive", false): return m
	return {}

## Validate fully, then charge the owner once and carry out the order.
static func issue(state, owner: Character, actor_id: String, order: String, target_id: String = "") -> Dictionary:
	var error := command_error(state, owner, actor_id, order, target_id)
	if not error.is_empty(): return {"success": false, "message": error + " Nothing was spent."}
	var actor: Character = null
	for a in CreatedActorRules.actors(owner):
		if a.character_id == actor_id: actor = a
	var p := policy(_template(owner, actor))
	if p.cost != "none" and not state._spend_action_cost(str(p.cost)): return {"success": false, "message": "The command could not be paid. Nothing was spent."}
	_commanded[actor_id] = CombatAction.active_turn_serial
	if order == "dodge":
		actor.add_condition("dodging", 2)
		return {"success": true, "message": "%s takes the Dodge action." % actor.character_name}
	var target := _target(state, target_id)
	var profile := CreatedActorRules.attack_profile(owner, actor)
	var result := CombatAction.resolve_weapon_attack(actor, target, profile, false, CombatAction.has_condition(target, "dodging"))
	if int(target.get("current_hp", 0)) <= 0:
		target["is_alive"] = false
		state.tracker.remove_combatant(str(target.get("id", "")))
	state._update_grid_entities()
	return {"success": true, "message": str(result.get("message", "%s attacks." % actor.character_name))}

## End of the owner's turn: each uncommanded actor takes its declared default.
static func apply_defaults(state, owner: Character) -> Array:
	var out: Array = []
	if owner == null: return out
	for a in actors(state, owner):
		if int(_commanded.get(a.character_id, -1)) == CombatAction.active_turn_serial: continue
		if policy(_template(owner, a)).default == "dodge":
			a.add_condition("dodging", 2)
			out.append(a.character_id)
	return out

## Saved control_until: present only when the template declares control_seconds.
static func saved_error(template: Dictionary, data: Dictionary) -> String:
	var declared := policy(template).has("control_seconds")
	if not data.has("control_until"): return "saved created actors lack their control deadline" if declared else ""
	if not declared or not CreatedActorRules._int(data.control_until, 0, 2147483647): return "invalid saved control deadline"
	return ""
