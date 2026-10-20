## S-120: a declared successor actor created once from a final S-119
## death/destruction at the dead creature's actual location. The successor's
## template is S-154's created-actor vocabulary (forbidden creation features
## are excluded); the policy lives on its stable damage carrier (a shared spell
## or a weapon item) and the record lives with the remains, so a reload
## rebuilds the same successor and a second settlement never makes another.
class_name AftermathSuccessorRules
extends RefCounted

const POLICY_KEYS := ["template", "attack_bonus", "side"]
const SIDES := ["source"]
const RECORD_KEYS := ["policy_id", "carrier", "owner_id", "corpse_id", "actors"]

static var _live := {}

static func policy_error(successor: Variant) -> String:
	if not successor is Dictionary: return "zero_hp_aftermath successor must be an object"
	for key in successor:
		if str(key) not in POLICY_KEYS: return "zero_hp_aftermath successor has unknown field '%s'" % key
	var e := CreatedActorRules.template_error(successor.get("template"))
	if not e.is_empty(): return "zero_hp_aftermath successor " + e
	if not CreatedActorRules._int(successor.get("attack_bonus"), -5, 20): return "zero_hp_aftermath successor attack_bonus must be -5..20"
	if str(successor.get("side", "")) not in SIDES: return "zero_hp_aftermath successor side must be one of %s" % str(SIDES)
	return ""

## The stable carrier's declared policy, or {}.
static func carrier_policy(carrier: String) -> Dictionary:
	var data := {}
	if carrier.begins_with("spell:"): data = DataLoader.get_spell(carrier.trim_prefix("spell:"))
	elif carrier.begins_with("item:"): data = DataLoader.get_item(carrier.trim_prefix("item:"))
	var policy: Variant = data.get("zero_hp_aftermath", {})
	return policy if policy is Dictionary and policy.has("successor") and ZeroHpAftermathRules.validate_policy(policy).is_empty() else {}

static func carrier_for_weapon(weapon_data: Dictionary) -> String:
	var id := str(weapon_data.get("id", ""))
	if id.is_empty(): return ""
	return "item:" + id if DataLoader.get_item(id).get("zero_hp_aftermath", null) == weapon_data.get("zero_hp_aftermath") else ""

static func _host_record(host) -> Dictionary:
	if host is Character: return host.corpse_state.get("successor", {})
	if host is Dictionary: return host.get("zero_hp_aftermath", {}).get("successor", {})
	return {}

static func host_id(host) -> String:
	return host.character_id if host is Character else str(host.get("id", host.get("combat_id", ""))) if host is Dictionary else ""

## Settle once after the S-119 aftermath; receipt or {}.
static func settle(target, policy: Dictionary, decisions: Dictionary, owner_id: String) -> Dictionary:
	if not policy.has("successor"): return {}
	if not _host_record(target).is_empty(): return {"created": false, "reason": "successor already created for this death"}
	var carrier := str(decisions.get("zero_hp_aftermath_carrier", ""))
	if carrier_policy(carrier) != policy: return {"created": false, "reason": "successor requires a stable carrier"}
	var template: Dictionary = policy.successor.template
	var corpse_id := str(target.corpse_state.get("corpse_id", "")) if target is Character else "creature:%s" % host_id(target)
	var record := {"policy_id": str(policy.id), "carrier": carrier, "owner_id": owner_id, "corpse_id": corpse_id, "actors": []}
	var maximum := CreatedActorRules.value(template.max_hp, 0)
	for i in CreatedActorRules.value(template.count, 0):
		record.actors.append({"actor_id": "%s:successor:%d" % [corpse_id, i + 1], "current_hp": maximum})
	if target is Character: target.corpse_state["successor"] = record
	else: target["zero_hp_aftermath"]["successor"] = record
	var made := actors(target)
	return {"created": true, "carrier": carrier, "owner_id": owner_id, "actor_ids": made.map(func(a): return a.character_id), "max_hp": maximum, "ac": CreatedActorRules.value(template.ac, 0), "excluded_features": template.get("features", []).filter(func(f): return CreatedActorRules._forbidden(f)).map(func(f): return str(f.id))}

## Live successor actors rebuilt from the host's record.
static func actors(host) -> Array:
	var out: Array = []
	var record := _host_record(host)
	if record.is_empty(): return out
	var policy := carrier_policy(str(record.get("carrier", "")))
	if policy.is_empty() or str(policy.id) != str(record.get("policy_id", "")): return out
	var iid: int = host.get_instance_id() if host is Character else hash(record.corpse_id)
	for entry in record.actors:
		var id := str(entry.actor_id)
		if not _live.has(id) or _live[id].get_meta("successor_host_iid", 0) != iid:
			var a := CreatedActorRules.instance(policy.successor.template, 0, entry)
			a.set_meta("successor_host_iid", iid)
			a.set_meta("successor_of", host_id(host))
			a.set_meta("successor_owner_id", str(record.owner_id))
			a.set_meta("successor_carrier", str(record.carrier))
			_live[id] = a
		out.append(_live[id])
	return out

static func any_alive(host) -> bool:
	sync(host)
	return _host_record(host).get("actors", []).any(func(e): return int(e.get("current_hp", 0)) > 0)

static func sync(host) -> void:
	for entry in _host_record(host).get("actors", []):
		var id := str(entry.actor_id)
		if _live.has(id): entry.current_hp = maxi(0, int(_live[id].current_hp))

static func attack_profile(actor: Character) -> Dictionary:
	var policy := carrier_policy(str(actor.get_meta("successor_carrier", "")))
	if policy.is_empty(): return {}
	var at: Dictionary = policy.successor.template.attack
	return {"id": "successor_attack", "name": str(at.name), "type": "weapon", "weapon_type": "simple", "ability": "STR", "attack_bonus_override": int(policy.successor.attack_bonus), "damage": str(at.damage), "damage_type": str(at.damage_type), "range": int(at.range), "long_range": int(at.range), "properties": []}

static func saved_error(dto: Dictionary, body: Dictionary) -> String:
	if not body.has("successor"): return ""
	var record: Variant = body.successor
	if not record is Dictionary or record.size() != RECORD_KEYS.size() or record.keys().any(func(k): return str(k) not in RECORD_KEYS): return "invalid saved successor"
	var policy := carrier_policy(str(record.get("carrier", "")))
	if policy.is_empty() or str(policy.id) != str(record.get("policy_id", "")) or str(body.get("cause_source", {}).get("policy_id", "")) != str(policy.id): return "saved successor has no matching carrier policy"
	if str(record.get("corpse_id", "")) != str(body.get("corpse_id", "")) or str(record.get("owner_id", "")).is_empty() or str(record.owner_id) == str(dto.get("character_id", "")): return "saved successor identity is invalid"
	var template: Dictionary = policy.successor.template
	var maximum := CreatedActorRules.value(template.max_hp, 0)
	if not record.get("actors") is Array or record.actors.size() != CreatedActorRules.value(template.count, 0): return "saved successor count differs from its template"
	for i in record.actors.size():
		var e: Variant = record.actors[i]
		if not e is Dictionary or e.size() != 2 or str(e.get("actor_id", "")) != "%s:successor:%d" % [str(record.corpse_id), i + 1] or not CreatedActorRules._int(e.get("current_hp"), 0, maximum): return "invalid saved successor actor"
	return ""

## Combat host: living successors join the side of their source at the dead
## creature's actual hex. Owners not on the party side are not placed.
static func attach(state: Node, host) -> Array:
	var joined: Array = []
	var owner_id := str(_host_record(host).get("owner_id", ""))
	if owner_id.is_empty() or not state.player_entities.any(func(e): return e.character is Character and e.character.character_id == owner_id): return joined
	var hex := Vector2i(-9999, -9999)
	for entity in state.player_entities + state.monster_entities:
		var c = entity.get("character", null)
		if (host is Character and c is Character and c == host) or (host is Dictionary and is_same(entity, host)): hex = entity.get("hex_position", hex)
	if hex == Vector2i(-9999, -9999): return joined
	for a in actors(host):
		if not a.is_alive or state.player_entities.any(func(e): return e.get("combat_id", "") == a.character_id): continue
		state.player_entities.append({"name": a.character_name, "display_name": a.character_name, "character": a, "combat_id": a.character_id, "owner_player_index": -1, "hex_position": hex, "is_created_actor": true, "created_owner_id": owner_id, "reaction_available": true, "color": Color(0.6, 0.5, 0.8)})
		joined.append(a.character_id)
	state._update_grid_entities()
	return joined
