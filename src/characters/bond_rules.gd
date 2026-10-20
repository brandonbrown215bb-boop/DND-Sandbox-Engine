## S-161: exclusive bonds between an owner and an exact item copy or an
## owned actor. The owner's source-owned feature declares the bond: target
## kind, eligibility, capacity, uniqueness and legal replacement. A refused
## bond changes nothing; a legal replacement releases only the declared
## previous bond. Bonds end when their exact target is no longer owned.
class_name BondRules
extends RefCounted

const FEATURE_KEYS := ["id", "name", "type", "bond_id", "target", "capacity", "replacement", "item_types", "creature_types", "unique", "description", "on_replace", "on_loss"]
## S-162 deliberate disposal of linked copies.
const ON_REPLACE := ["release", "destroy"]
const ON_LOSS := ["keep_survivors", "dispose_group"]

static var last_disposal: Dictionary = {}
static var _settling := false
const TARGETS := ["item", "actor"]
const REPLACEMENTS := ["refuse", "release_oldest"]

static func rule_error(feature: Variant) -> String:
	if not feature is Dictionary: return "exclusive_bond must be an object"
	for key in feature:
		if str(key) not in FEATURE_KEYS: return "exclusive_bond has unknown field '%s'" % key
	if str(feature.get("bond_id", "")).is_empty() or str(feature.get("bond_id", "")).length() > 80: return "exclusive_bond needs bond_id"
	var target := str(feature.get("target", ""))
	if target not in TARGETS: return "exclusive_bond target must be item or actor"
	if not CreatedActorRules._int(feature.get("capacity"), 1, 3): return "exclusive_bond capacity must be 1-3"
	if str(feature.get("replacement", "")) not in REPLACEMENTS: return "exclusive_bond replacement must be one of %s" % str(REPLACEMENTS)
	if not feature.get("unique", null) is bool: return "exclusive_bond unique must be boolean"
	var list_key := "item_types" if target == "item" else "creature_types"
	var other_key := "creature_types" if target == "item" else "item_types"
	var list: Variant = feature.get(list_key)
	if feature.has(other_key) or not list is Array or list.is_empty() or list.any(func(v): return not v is String or str(v).is_empty()): return "exclusive_bond %s target requires %s" % [target, list_key]
	if target == "actor" and list.any(func(v): return v not in CreatedActorRules.CREATURE_TYPES): return "exclusive_bond creature_types are invalid"
	if str(feature.get("on_replace", "release")) not in ON_REPLACE or str(feature.get("on_loss", "keep_survivors")) not in ON_LOSS: return "exclusive_bond on_replace/on_loss are invalid"
	if target == "actor" and (str(feature.get("on_replace", "release")) != "release" or str(feature.get("on_loss", "keep_survivors")) != "keep_survivors"): return "exclusive_bond actor targets cannot dispose linked identities"
	if str(feature.get("on_replace", "release")) == "destroy" and str(feature.replacement) != "release_oldest": return "exclusive_bond on_replace destroy requires release_oldest"
	return ""

## An exact copy is held when carried, worn, or projected into its temporary form (S-165).
static func held(actor: Character, id: String) -> bool:
	return actor.inventory.owned_instances().any(func(c): return str(c.instance_id) == id) or ItemProjectionRules.is_projected(actor, id)

static func rules(actor: Character) -> Dictionary:
	var out := {}
	if actor == null: return out
	for feature in actor.features:
		if feature is Dictionary and str(feature.get("type", "")) == "exclusive_bond" and rule_error(feature).is_empty(): out[str(feature.bond_id)] = feature
	return out

static func _declared(class_id: String, level: int) -> Dictionary:
	var out := {}
	var by_level: Dictionary = DataLoader.get_character_class(class_id).get("features_by_level", {})
	for l in by_level:
		if int(l) > level: continue
		for feature in by_level[l]:
			if feature is Dictionary and str(feature.get("type", "")) == "exclusive_bond" and rule_error(feature).is_empty(): out[str(feature.bond_id)] = feature
	return out

static func bonded(actor: Character, bond_id: String) -> Array:
	prune(actor)
	return actor.exclusive_bonds.get(bond_id, {}).get("targets", []).map(func(e): return str(e.target_id))

static func is_bonded(actor: Character, bond_id: String, target_id: String) -> bool:
	return target_id in bonded(actor, bond_id)

static func _target_id(target) -> String:
	return target.character_id if target is Character else str(target)

static func _eligible(actor: Character, rule: Dictionary, target) -> String:
	if str(rule.target) == "item":
		if not target is String: return "That is not an item copy."
		var copy := actor.inventory.get_instance(target)
		if copy.is_empty() or not actor.inventory.owned_instances().any(func(c): return str(c.instance_id) == target): return "You do not hold that exact copy."
		if str(DataLoader.get_item(str(copy.definition_id)).get("type", "")) not in rule.item_types: return "That copy is not eligible for this bond."
		return ""
	if not target is Character: return "That is not a creature."
	if CreatedActorRules.owner_of(target) != actor.character_id or not CreatedActorRules.actors(actor).has(target): return "That creature is not yours to bond."
	if target.get_creature_type() not in rule.creature_types: return "That creature is not eligible for this bond."
	return ""

## Bond the exact target. `others` are the other owners checked for uniqueness.
static func bond(actor: Character, bond_id: String, target, others: Array = []) -> Dictionary:
	var rule: Dictionary = rules(actor).get(bond_id, {})
	if rule.is_empty(): return {"bonded": false, "reason": "You have no such bond."}
	var reason := _eligible(actor, rule, target)
	var id := _target_id(target)
	if reason.is_empty() and is_bonded(actor, bond_id, id): reason = "Already bonded."
	if reason.is_empty() and bool(rule.unique):
		for other in others:
			if other is Character and other != actor and is_bonded(other, bond_id, id): reason = "That target is bonded to another owner."
	var state: Dictionary = actor.exclusive_bonds.get(bond_id, {"serial": 0, "targets": []})
	var released := ""
	if reason.is_empty() and state.targets.size() >= int(rule.capacity):
		if str(rule.replacement) == "refuse": reason = "The bond is at capacity."
		else: released = str(state.targets[0].target_id)
	if not reason.is_empty(): return {"bonded": false, "reason": reason}
	var destroyed := ""
	if not released.is_empty():
		state.targets.remove_at(0)
		if str(rule.get("on_replace", "release")) == "destroy" and not ItemProjectionRules.is_projected(actor, released):
			_settling = true
			if not actor.inventory.destroy_instance(released).is_empty(): destroyed = released
			_settling = false
	state.serial = int(state.serial) + 1
	state.targets.append({"target_id": id, "serial": int(state.serial)})
	actor.exclusive_bonds[bond_id] = state
	return {"bonded": true, "bond_id": bond_id, "target_id": id, "released": released, "destroyed": destroyed, "serial": int(state.serial)}

static func release(actor: Character, bond_id: String, target_id: String) -> bool:
	var state: Dictionary = actor.exclusive_bonds.get(bond_id, {})
	var before: int = state.get("targets", []).size()
	if before == 0: return false
	state.targets = state.targets.filter(func(e): return str(e.target_id) != target_id)
	return state.targets.size() < before

## Bonds whose exact target is no longer owned end; returns released ids.
static func prune(actor: Character) -> Array:
	var released: Array = []
	if actor == null: return released
	var declared := rules(actor)
	for bond_id in actor.exclusive_bonds.keys():
		var rule: Dictionary = declared.get(bond_id, {})
		var state: Dictionary = actor.exclusive_bonds[bond_id]
		var kept: Array = []
		for e in state.get("targets", []):
			var id := str(e.target_id)
			var live := false
			# Review 041 R3: a temporarily suppressed source feature (projection) does not end the bond.
			if rule.is_empty(): live = true
			else:
				if str(rule.target) == "item": live = held(actor, id)
				else: live = CreatedActorRules.actors(actor).any(func(a): return a.character_id == id)
			if live: kept.append(e)
			else: released.append(id)
		var lost: Array = released.filter(func(x): return state.get("targets", []).any(func(e): return str(e.target_id) == x))
		if not lost.is_empty() and str(rule.get("on_loss", "keep_survivors")) == "dispose_group" and not _settling:
			# S-162: losing one linked copy disposes exactly the other linked copies.
			var disposed: Array = []
			_settling = true
			for e in kept:
				var sid := str(e.target_id)
				if not ItemProjectionRules.is_projected(actor, sid) and not actor.inventory.destroy_instance(sid).is_empty(): disposed.append(sid)
				released.append(sid)
			_settling = false
			last_disposal = {"bond_id": str(bond_id), "lost": lost, "disposed": disposed, "kept": kept.map(func(e): return str(e.target_id)).filter(func(x): return x not in disposed)}
			kept = kept.filter(func(e): return str(e.target_id) not in disposed)
		state.targets = kept
	return released

## Inventory hook: an exact copy left its holder; settle linked-copy fates now.
static func on_copy_removed(actor) -> void:
	if actor is Character and not _settling and not actor.exclusive_bonds.is_empty(): prune(actor)

static func restore(actor: Character, data: Dictionary) -> void:
	actor.exclusive_bonds = data.get("exclusive_bonds", {}).duplicate(true) if data.get("exclusive_bonds", {}) is Dictionary else {}

static func saved_error(dto: Dictionary) -> String:
	var bonds: Variant = dto.get("exclusive_bonds", {})
	if not bonds is Dictionary: return "exclusive bonds are invalid"
	if bonds.is_empty(): return ""
	var declared := {}
	var levels: Variant = dto.get("class_levels", {})
	if levels is Dictionary and not levels.is_empty():
		for class_id in levels: declared.merge(_declared(str(class_id), int(levels[class_id])))
	else: declared = _declared(str(dto.get("class_id", "")), int(dto.get("level", 1)))
	var records: Dictionary = dto.get("inventory", {}).get("copies", {}).get("records", {}).duplicate()
	for pid in dto.get("item_projections", {}):
		var projected: Variant = dto.item_projections[pid]
		if projected is Dictionary and projected.get("copy") is Dictionary: records[str(pid)] = projected.copy
	var actor_ids: Array = []
	for record in dto.get("spell_effects", {}).values():
		if record is Dictionary and record.get("created_actors") is Dictionary:
			for e in record.created_actors.get("actors", []): actor_ids.append(str(e.get("actor_id", "")))
	for bond_id in bonds:
		var rule: Dictionary = declared.get(str(bond_id), {})
		var state: Variant = bonds[bond_id]
		if rule.is_empty(): return "saved bond has no declared source"
		if not state is Dictionary or state.size() != 2 or not CreatedActorRules._int(state.get("serial"), 0, 1000000) or not state.get("targets") is Array: return "saved bond is invalid"
		if state.targets.size() > int(rule.capacity): return "saved bond exceeds its capacity"
		var last := 0
		var seen: Array = []
		for e in state.targets:
			if not e is Dictionary or e.size() != 2 or not CreatedActorRules._int(e.get("serial"), 1, int(state.serial)) or int(e.serial) <= last or str(e.get("target_id", "")) in seen: return "saved bond target is invalid"
			last = int(e.serial)
			var id := str(e.target_id)
			seen.append(id)
			if str(rule.target) == "item" and (not records.has(id) or str(DataLoader.get_item(str(records[id].get("definition_id", ""))).get("type", "")) not in rule.item_types): return "saved bond names a copy this character does not hold"
			if str(rule.target) == "actor" and id not in actor_ids: return "saved bond names a creature this character does not own"
	return ""
