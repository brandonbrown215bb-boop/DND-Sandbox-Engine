## S-156 (Batch 055): command authority over exact owned created actors.
## A template may declare command {cost, range_hexes, orders, default,
## control_seconds}. The owner commands one exact actor (by actor id, so
## same-named actors stay separate); a refused command spends nothing; a valid
## one charges the owner's declared cost once. Uncommanded actors take the
## declared default at the end of the owner's turn. Control expiry only stops
## commands: the actor stays while its source lasts.
class_name CreatedCommandRules
extends RefCounted

const POLICY_KEYS := ["cost", "range_hexes", "orders", "default", "control_seconds", "initiative", "owner_incapacitated", "owner_dead", "control_expired", "concentration_end"]
## Batch 056 S-157: owner_turn (055 behaviour: orders resolve at once on the
## owner's turn), after_owner (own turn right after the owner), own (own d20+DEX).
const INITIATIVES := ["owner_turn", "after_owner", "own"]
## Batch 056 S-158: behaviour when the owner is incapacitated, dead, or control
## expired. Missing keys fall back to the declared uncommanded default.
const AUTONOMY := ["dodge", "none", "attack_nearest"]
## Concentration end keeps the existing source cleanup (actors end with their
## source); outliving concentration would be a disposal change (off-limits).
const CONCENTRATION_END := ["end"]
const COSTS := ["action", "bonus_action", "none"]
const ORDERS := ["attack", "dodge"]
const DEFAULTS := ["dodge", "none"]
## Uncommanded and unauthored: Bonus Action, 12 hexes (60 ft), attack/Dodge, Dodge.
const DEFAULT := {"cost": "bonus_action", "range_hexes": 12, "orders": ["attack", "dodge"], "default": "dodge"}

## Commanded actor id -> CombatAction.active_turn_serial; transient, never saved.
static var _commanded := {}
## Batch 056: orders paid on the owner's turn for actors with their own turn
## (actor id -> {order, target_id}); carried out on the actor's turn. Transient.
static var _orders := {}

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
	if p.has("initiative") and str(p.initiative) not in INITIATIVES: return "command initiative must be owner_turn, after_owner or own"
	for key in ["owner_incapacitated", "owner_dead", "control_expired"]:
		if p.has(key) and str(p[key]) not in AUTONOMY: return "command %s must be dodge, none or attack_nearest" % key
	if p.has("concentration_end") and str(p.concentration_end) not in CONCENTRATION_END: return "command concentration_end must be end"
	return ""

## Batch 056: declared initiative policy for this actor (default owner_turn).
static func initiative(owner: Character, actor: Character) -> String:
	return str(policy(_template(owner, actor)).get("initiative", "owner_turn"))

## Batch 056 S-158: what this actor does without a command, given its owner's state.
static func behaviour(owner: Character, actor: Character) -> String:
	var p := policy(_template(owner, actor))
	if owner == null or owner.is_dead(): return str(p.get("owner_dead", p.default))
	if not owner.is_alive or CombatAction.is_incapacitated(owner): return str(p.get("owner_incapacitated", p.default))
	if not controlled(owner, actor): return str(p.get("control_expired", p.default))
	return str(p.default)

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
	if not actor.is_alive or CombatAction.is_incapacitated(actor): return "That creature can't act." # Review R1: incapacitated actors take no actions.
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
	if initiative(owner, actor) != "owner_turn":
		_orders[actor_id] = {"order": order, "target_id": target_id}
		return {"success": true, "message": "%s will %s on its own turn." % [actor.character_name, order]}
	if order == "dodge":
		actor.add_condition("dodging", 2)
		return {"success": true, "message": "%s takes the Dodge action." % actor.character_name}
	return {"success": true, "message": _attack(state, owner, actor, _target(state, target_id))}

static func _attack(state, owner: Character, actor: Character, target: Dictionary) -> String:
	var profile := CreatedActorRules.attack_profile(owner, actor)
	var result := CombatAction.resolve_weapon_attack(actor, target, profile, false, CombatAction.has_condition(target, "dodging"))
	if int(target.get("current_hp", 0)) <= 0:
		target["is_alive"] = false
		if state.tracker != null: state.tracker.remove_combatant(str(target.get("id", "")))
	state._update_grid_entities()
	return str(result.get("message", "%s attacks." % actor.character_name))

static func _reachable(state, owner: Character, actor: Character, target_id: String) -> Dictionary:
	var target := _target(state, target_id)
	var entity := _entity(state, actor.character_id)
	if target.is_empty() or entity.is_empty(): return {}
	var reach := int(_template(owner, actor).get("attack", {}).get("range", 1))
	return target if HexUtils.get_distance(entity.hex_position, target.hex_position) <= reach else {}

## Carry out one autonomous behaviour; returns a log line ("" when nothing happens).
static func act(state, owner: Character, actor: Character, what: String) -> String:
	if not actor.is_alive or CombatAction.is_incapacitated(actor) or what == "none": return ""
	if what == "attack_nearest":
		var entity := _entity(state, actor.character_id)
		var best := {}
		for m in state.monster_entities:
			if not m.get("is_alive", false) or entity.is_empty(): continue
			if best.is_empty() or HexUtils.get_distance(entity.hex_position, m.hex_position) < HexUtils.get_distance(entity.hex_position, best.hex_position): best = m
		if not best.is_empty() and not _reachable(state, owner, actor, str(best.id)).is_empty():
			return _attack(state, owner, actor, best)
	actor.add_condition("dodging", 2)
	return "%s takes the Dodge action." % actor.character_name

## The owner of a created-actor battlefield entity (dead owners included).
static func owner_entity(state, entity: Dictionary) -> Character:
	for e in state.player_entities:
		var c: Variant = e.get("character")
		if c is Character and c.character_id == str(entity.get("created_owner_id", "")): return c
	return null

## Batch 056 S-157: an actor's own turn, with its own budget. A paid order runs
## if it still can; otherwise the declared behaviour for the owner's state.
static func take_turn(state, entity: Dictionary) -> String:
	var actor: Character = entity.get("character")
	var owner := owner_entity(state, entity)
	var order: Dictionary = _orders.get(actor.character_id, {})
	_orders.erase(actor.character_id)
	if owner == null or not CreatedActorRules.actors(owner).has(actor): return "%s's source has ended." % actor.character_name
	if not actor.is_alive or CombatAction.is_incapacitated(actor): return "%s can't act." % actor.character_name
	if not state._spend_action_cost("action"): return ""
	if not order.is_empty():
		if order.order == "dodge":
			actor.add_condition("dodging", 2)
			return "%s takes the ordered Dodge action." % actor.character_name
		var target := _reachable(state, owner, actor, str(order.get("target_id", "")))
		if not target.is_empty(): return _attack(state, owner, actor, target)
	return act(state, owner, actor, behaviour(owner, actor))

## Batch 056 S-157: put an independent actor into initiative. after_owner sits
## directly behind its owner (and earlier linked actors); own rolls d20+DEX.
static func join_initiative(state, owner: Character, actor: Character) -> void:
	var tracker = state.get("tracker")
	if tracker == null or tracker.combatants.is_empty(): return
	if tracker.combatants.any(func(c): return str(c.id) == actor.character_id): return
	var mode := initiative(owner, actor)
	if mode == "owner_turn": return
	var dex := actor.ability_scores.get_score("DEX")
	if mode == "own":
		var roll := Dice.roll(20) + AbilityScores.get_modifier(dex)
		tracker.add_combatant(actor.character_id, actor.character_name, true, actor, roll, dex)
		tracker.sort_initiative_preserving_active()
		return
	var at := -1
	for i in tracker.combatants.size():
		var c: Dictionary = tracker.combatants[i]
		if c.entity is Character and c.entity == owner: at = i
		elif at >= 0 and i == at + 1 and c.entity is Character and CreatedActorRules.owner_of(c.entity) == owner.character_id and initiative(owner, c.entity) == "after_owner": at = i # Review R1: contiguous after_owner run only.
	if at < 0: return
	var anchor: Dictionary = tracker.combatants[at]
	tracker.combatants.insert(at + 1, {"id": actor.character_id, "name": actor.character_name, "is_player": true, "entity": actor, "roll": anchor.roll, "dex": float(anchor.dex) - 0.01, "has_acted": false})
	if at + 1 <= tracker.active_index: tracker.active_index += 1

## Batch 056: drop battlefield entries whose source has ended (concentration end
## uses the existing cleanup). Call before the tracker advances so removal never
## replays or skips anyone's turn.
static func reconcile(state) -> Array:
	var gone: Array = []
	for e in state.player_entities.duplicate():
		if not e.get("is_created_actor", false): continue
		var owner := owner_entity(state, e)
		if owner != null and CreatedActorRules.actors(owner).has(e.character): continue
		state.player_entities.erase(e)
		_orders.erase(e.combat_id)
		if state.get("tracker") != null: state.tracker.remove_combatant(str(e.combat_id))
		gone.append(str(e.get("name", e.combat_id)))
	if not gone.is_empty(): state._update_grid_entities()
	return gone

## End of the owner's turn: each uncommanded actor takes its declared default.
static func apply_defaults(state, owner: Character) -> Array:
	var out: Array = []
	if owner == null: return out
	for a in actors(state, owner):
		if int(_commanded.get(a.character_id, -1)) == CombatAction.active_turn_serial: continue
		if CombatAction.is_incapacitated(a): continue # Review R1: no default Dodge while incapacitated.
		if initiative(owner, a) != "owner_turn": continue # Batch 056: acts on its own turn.
		if not act(state, owner, a, behaviour(owner, a)).is_empty(): out.append(a.character_id)
	return out

## Saved control_until: present only when the template declares control_seconds.
static func saved_error(template: Dictionary, data: Dictionary) -> String:
	var declared := policy(template).has("control_seconds")
	if not data.has("control_until"): return "saved created actors lack their control deadline" if declared else ""
	if not declared or not CreatedActorRules._int(data.control_until, 0, 2147483647): return "invalid saved control deadline"
	return ""
