class_name TetherRules
extends RefCounted
## S-168 actor/object restraint relation. A source-owned tether binds the actual
## captor, victim and anchor with a range. The victim's condition is granted under
## the tether's own source, so escaping or breaking it removes only that source's
## restraint; other restraints on the same victim stay.

const CONDITIONS := ["restrained"]
const ESCAPES := {"STR": "Athletics", "DEX": "Acrobatics"}

static func effect_error(effect: Dictionary) -> String:
	if effect.keys().any(func(k): return str(k) not in ["type", "condition", "range_hexes", "escape", "capacity", "on_failed_save", "rescue", "hp", "anchor"]): return "Tethers accept only condition, range_hexes, escape, capacity, on_failed_save, rescue, hp and anchor."
	if str(effect.get("condition", "")) not in CONDITIONS: return "Tethers support only the restrained condition."
	if str(effect.get("anchor", "character")) not in ["character", "object"]: return "Tether anchor must be character or object."
	var r: Variant = effect.get("range_hexes")
	if not (r is int or r is float) or float(r) != floorf(float(r)) or int(r) < 1 or int(r) > 30: return "Tether range_hexes must be 1-30."
	var esc: Variant = effect.get("escape")
	if not esc is Array or esc.is_empty() or esc.any(func(a): return not a is String or not ESCAPES.has(str(a))): return "Tether escape abilities must be STR and/or DEX."
	var c: Variant = effect.get("capacity", 1)
	if not (c is int or c is float) or float(c) != floorf(float(c)) or int(c) < 1 or int(c) > 4: return "Tether capacity must be 1-4."
	# S-169: optional outside routes. rescue = abilities another creature may use; hp = damage the tether absorbs.
	if effect.has("rescue"):
		var res: Variant = effect.rescue
		if not res is Array or res.is_empty() or res.any(func(a): return not a is String or not ESCAPES.has(str(a))): return "Tether rescue abilities must be STR and/or DEX."
	if effect.has("hp"):
		var hp: Variant = effect.hp
		if not (hp is int or hp is float) or float(hp) != floorf(float(hp)) or int(hp) < 1 or int(hp) > 100: return "Tether hp must be 1-100."
	return ""

static func _effect(spell: Dictionary) -> Dictionary:
	for e in spell.get("effects", []):
		if e is Dictionary and e.get("type", "") == "bind_tether": return e
	return {}

## Whether this exact source grants any condition on the target (actor or monster).
static func has_source(target, source: String) -> bool:
	var sources: Variant = target.condition_sources if target is Character else target.get("condition_sources", {}) if target is Dictionary else {}
	if not sources is Dictionary: return false
	for grants in sources.values():
		if grants is Dictionary and grants.has(source): return true
	return false

static func victim_id(target) -> String:
	return str(target.character_id) if target is Character else str(target.get("id", "")) if target is Dictionary else ""

static func held(caster: Character, spell_id: String = "") -> Array:
	prune(caster)
	return caster.tethers.keys().filter(func(s): return spell_id.is_empty() or str(caster.tethers[s].spell_id) == spell_id)

## Refusal before the slot is spent: the captor's declared capacity is full.
static func cast_error(caster, spell: Dictionary) -> String:
	var effect := _effect(spell)
	if effect.is_empty(): return ""
	if not caster is Character: return "Tethers require a Character anchor."
	if held(caster, str(spell.get("id", ""))).size() >= int(effect.get("capacity", 1)): return "You already hold as many tethers from this spell as it allows."
	return ""

static func maximum_targets(spell: Dictionary, requested: int) -> int:
	var effect := _effect(spell)
	return requested if effect.is_empty() else mini(requested, int(effect.get("capacity", 1)))

## Single-recipient records keep their old key. Group relations name the parent
## separately, so selecting a parent can never silently select one of its children.
static func source_id(relation: String, tether: Dictionary) -> String:
	return str(tether.get("source_id", relation))

static func relation_id(source: String, kind: String, id: String, capacity: int) -> String:
	return source if capacity == 1 else "%s:tether:%s:%s" % [source, kind, id]

## Shared effect on a failed save: grant the condition under the cast's source and bind the relation.
static func apply(caster: Character, target, cast: Dictionary, effect: Dictionary, spell: Dictionary) -> Dictionary:
	if caster == null or target == null or (target is Character and target == caster) or not effect_error(effect).is_empty(): return {"bound": false, "reason": "invalid tether"}
	if str(effect.get("anchor", "character")) == "object": return _apply_object_anchor(caster, target, cast, effect, spell)
	var source := str(cast.get("source_id", ""))
	var kind := "character" if target is Character else "monster"
	var relation := relation_id(source, kind, victim_id(target), int(effect.get("capacity", 1)))
	var siblings := caster.tethers.keys().filter(func(r): return source_id(str(r), caster.tethers[r]) == source)
	if source.is_empty() or victim_id(target).is_empty() or caster.tethers.has(relation) or siblings.size() >= int(effect.get("capacity", 1)): return {"bound": false, "reason": "relation already bound or capacity full"}
	var condition := str(effect.condition)
	SpellEffects.grant(target, cast, condition)
	if not has_source(target, source): return {"bound": false, "reason": "The target resists the condition."}
	caster.tethers[relation] = {"spell_id": str(spell.get("id", "")), "victim_id": victim_id(target), "victim_kind": kind, "anchor_id": caster.character_id, "condition": condition, "range_hexes": int(effect.range_hexes), "escape": effect.escape.duplicate(), "dc": int(cast.get("save_dc", 10))}
	if relation != source: caster.tethers[relation]["source_id"] = source
	if effect.has("hp"): caster.tethers[relation]["hp"] = int(effect.hp)
	return {"bound": true, "source_id": source, "relation_id": relation, "victim_id": victim_id(target)}

## Object anchors live on the room's existing object record, not on the caster.
## Their source still records who cast the spell, but their lifetime is not
## pruned when that Character stops concentrating or dies.
static func _apply_object_anchor(caster: Character, target, cast: Dictionary, effect: Dictionary, spell: Dictionary) -> Dictionary:
	var room := LocalRoomCombat.room()
	if room.is_empty(): return {"bound": false, "reason": "object anchors require a located room object"}
	var target_position := Vector2i(9999, 9999)
	var target_plane := PhysicalFactsRules.get_plane(target, {"plane": PhysicalFactsRules.get_plane(room)})
	if target is Character:
		var location: Dictionary = LocatedSourceEndRules.capture(target, {}, "").final_location
		if not bool(location.get("location_known", false)): return {"bound": false, "reason": "the victim has no room location"}
		target_position = LocalRoomRules.coord(location.position)
		target_plane = str(location.plane)
	else:
		return {"bound": false, "reason": "object tethers require a Character victim"}
	var eligible: Array = []
	for object in room.get("objects", []):
		if not object is Dictionary or bool(object.get("removed", false)) or int(object.get("hp", 0)) <= 0: continue
		var object_plane := PhysicalFactsRules.get_plane(object, {"plane": PhysicalFactsRules.get_plane(room)})
		if object_plane != target_plane: continue
		var pos_value: Variant = object.get("position", null)
		if not pos_value is Array or pos_value.size() < 2: continue
		var distance := HexUtils.get_distance(target_position, LocalRoomRules.coord(pos_value))
		if distance <= int(effect.range_hexes): eligible.append({"object": object, "distance": distance})
	if eligible.is_empty(): return {"bound": false, "reason": "No living object anchor is close enough."}
	eligible.sort_custom(func(a, b):
		if int(a.distance) != int(b.distance): return int(a.distance) < int(b.distance)
		return str(a.object.get("id", "")) < str(b.object.get("id", "")))
	var anchor: Dictionary = eligible[0].object
	var source := str(cast.get("source_id", ""))
	var relation := relation_id(source, "character", victim_id(target), int(effect.get("capacity", 1)))
	var records: Dictionary = anchor.get("tethers", {})
	if source.is_empty() or records.has(relation): return {"bound": false, "reason": "relation already bound"}
	var siblings := records.keys().filter(func(r): return source_id(str(r), records[r]) == source)
	if siblings.size() >= int(effect.get("capacity", 1)): return {"bound": false, "reason": "capacity full"}
	var condition_source := "object_tether:%s:%d:%s" % [caster.character_id, caster.spell_cast_serial, victim_id(target)]
	var condition_cast := cast.duplicate(true)
	condition_cast["source_id"] = condition_source
	# Do not make an object anchor inherit a concentration requirement from the
	# parent caster. The object record owns the relation until its own end route.
	condition_cast["concentration"] = false
	SpellEffects.grant(target, condition_cast, str(effect.condition))
	if not has_source(target, condition_source): return {"bound": false, "reason": "The target resists the condition."}
	var position: Array = anchor.get("position", [0, 0]).duplicate()
	anchor["tethers"] = records
	anchor.tethers[relation] = {"source_id": source, "condition_source_id": condition_source, "spell_id": str(spell.get("id", "")), "caster_id": caster.character_id, "victim_id": victim_id(target), "victim_kind": "character", "anchor_id": str(anchor.get("id", "")), "anchor_kind": "object", "anchor_position": position, "anchor_plane": PhysicalFactsRules.get_plane(anchor, {"plane": target_plane}), "anchor_hp": int(anchor.get("hp", 0)), "condition": str(effect.condition), "range_hexes": int(effect.range_hexes), "escape": effect.escape.duplicate(), "dc": int(cast.get("save_dc", 10))}
	if effect.has("hp"): anchor.tethers[relation]["hp"] = int(effect.hp)
	return {"bound": true, "source_id": source, "relation_id": relation, "victim_id": victim_id(target), "anchor_id": str(anchor.get("id", "")), "anchor_kind": "object"}

## A tether lives only while its concentration source does.
static func prune(caster: Character) -> void:
	if caster == null: return
	for relation in caster.tethers.keys():
		if str(caster.concentrating_on.get("effect_source", "")) != source_id(str(relation), caster.tethers[relation]): caster.tethers.erase(relation)
	reconcile(caster, caster.concentrating_on.get("targets", []) + PartyManager.characters.values())

static func reconcile(caster: Character, victims: Array) -> void:
	for relation in caster.tethers.keys():
		var tether: Dictionary = caster.tethers[relation]
		for victim in victims:
			if victim_id(victim) == str(tether.victim_id) and (victim is Character) == (str(tether.victim_kind) == "character") and not has_source(victim, source_id(str(relation), tether)):
				caster.tethers.erase(relation)
				break

static func _release(caster: Character, relation: String, victim) -> void:
	var t: Dictionary = caster.tethers.get(relation, {})
	if t.is_empty(): return
	var source := source_id(relation, t)
	caster.tethers.erase(relation)
	CombatAction.remove_condition_source(victim, source, [str(t.get("condition", "restrained"))])
	SpellEffects.remove(victim, source, "tether_released")
	var targets: Array = caster.concentrating_on.get("targets", [])
	targets.erase(victim)
	if str(caster.concentrating_on.get("effect_source", "")) == source and not caster.tethers.values().any(func(s): return str(s.get("source_id", source)) == source):
		SpellEffects.end_concentration(caster, [caster])

static func _release_object_anchor(object: Dictionary, relation: String, victim, reason: String = "tether_released") -> void:
	var tether: Dictionary = object.get("tethers", {}).get(relation, {})
	if tether.is_empty(): return
	object.tethers.erase(relation)
	var condition_source := str(tether.get("condition_source_id", tether.get("source_id", "")))
	if victim is Character:
		CombatAction.remove_condition_source(victim, condition_source, [str(tether.get("condition", "restrained"))])
		SpellEffects.remove(victim, condition_source, reason)

## The victim-owned effect can end from expiry or another declared source end.
## Remove only that reverse relation from loaded and checkpointed room objects.
static func end_victim_source(victim: Character, condition_source: String) -> void:
	if victim == null or condition_source.is_empty(): return
	var rooms: Array = []
	var active := LocalRoomCombat.room()
	if not active.is_empty(): rooms.append(active)
	var dungeon: Dictionary = GameManager.active_dungeon_state
	for room in dungeon.get("local_rooms", {}).values():
		if room not in rooms: rooms.append(room)
	for snapshot in GameManager.dungeon_snapshots.values():
		for room in snapshot.get("local_rooms", {}).values():
			if room not in rooms: rooms.append(room)
	for room in rooms:
		for object in room.get("objects", []):
			if not object is Dictionary or not object.get("tethers", {}) is Dictionary: continue
			var object_tethers: Dictionary = object.get("tethers", {})
			for relation in object_tethers.keys().duplicate():
				if str(object_tethers[relation].get("condition_source_id", "")) == condition_source and str(object_tethers[relation].get("victim_id", "")) == victim.character_id:
					object_tethers.erase(relation)

## Recheck only relations attached to this exact object after it moves or takes
## damage. Its current room record is the location/plane/HP authority.
static func reconcile_object_anchor(object: Dictionary, room: Dictionary = {}, known_victims: Array = [], positions: Dictionary = {}) -> Array:
	var broken: Array = []
	if object.is_empty() or not object.get("tethers", {}) is Dictionary: return broken
	if room.is_empty(): room = LocalRoomCombat.room()
	for relation in object.tethers.keys().duplicate():
		var tether: Dictionary = object.tethers[relation]
		var victim: Character = PartyManager.characters.get(str(tether.get("victim_id", "")))
		if victim == null:
			for possible in known_victims:
				if possible is Character and possible.character_id == str(tether.get("victim_id", "")): victim = possible; break
		var location: Dictionary = LocatedSourceEndRules.capture(victim, {}, "").final_location if victim != null else {}
		var position: Vector2i = positions.get(str(tether.get("victim_id", "")), LocalRoomRules.coord(location.position) if bool(location.get("location_known", false)) else Vector2i(9999, 9999))
		var valid: bool = victim != null and position != Vector2i(9999, 9999) and not bool(object.get("removed", false)) and int(object.get("hp", 0)) > 0
		if valid:
			var same_plane := PhysicalFactsRules.get_plane(object, {"plane": PhysicalFactsRules.get_plane(room)}) == PhysicalFactsRules.get_plane(victim, {"plane": PhysicalFactsRules.get_plane(room)})
			valid = same_plane and HexUtils.get_distance(position, LocalRoomRules.coord(object.get("position", [0, 0]))) <= int(tether.get("range_hexes", 0))
		if not valid:
			_release_object_anchor(object, str(relation), victim, "tether_anchor_lost")
			broken.append(str(relation))
		else:
			tether["anchor_position"] = object.get("position", [0, 0]).duplicate()
			tether["anchor_plane"] = PhysicalFactsRules.get_plane(object, {"plane": PhysicalFactsRules.get_plane(room)})
			tether["anchor_hp"] = int(object.get("hp", 0))
	return broken

static func move_object_anchor(object: Dictionary, room: Dictionary, destination: Vector2i, known_victims: Array = []) -> Dictionary:
	if not is_same(LocalRoomRules.get_object(room, str(object.get("id", ""))), object): return LocalRoomRules.failure("That exact object was replaced.")
	if not ContainmentRules.relation(room, "object", str(object.get("id", ""))).is_empty(): return LocalRoomRules.failure("Internal objects cannot move independently.")
	if bool(object.get("fixed", false)) or int(object.get("hp", 1)) <= 0: return LocalRoomRules.failure("That object cannot move.")
	if ContainmentRules.active(room):
		var state := ContainmentRules.placement_state(room, known_victims)
		var reserved: Array = state.reserved.filter(func(r): return r.hex != LocalRoomRules.coord(object.position))
		var error := PlacementRules.legal_error(state, LocalRoomRules.coord(object.position), destination, PhysicalFactsRules.get_size(object), -1, reserved, {"objects": room.objects.filter(func(o): return not is_same(o, object))})
		state._placement_grid.free()
		if not error.is_empty(): return LocalRoomRules.failure(error)
	if object.is_empty() or room.is_empty() or not room.get("cells", []).any(func(cell): return LocalRoomRules.coord(cell) == destination) or (LocalRoomRules.object_at(room, destination) != object and not LocalRoomRules.object_at(room, destination).is_empty()) or not LocalRoomRules.passable(room, destination):
		return {"success": false, "message": "That object cannot move there."}
	object["position"] = [destination.x, destination.y]
	var broken: Array = reconcile_object_anchor(object, room, known_victims) if object.has("tethers") else []
	return {"success": true, "message": "%s moves%s." % [str(object.get("name", "The object")), "; %d tether%s snap" % [broken.size(), "s" if broken.size() != 1 else ""] if not broken.is_empty() else ""]}

## Parent removal erases the complete group before removing recipient records.
## That ordering makes nested/repeated cleanup harmless.
static func end_source(caster: Character, source: String, reason: String, cause: Dictionary) -> void:
	var relations := caster.tethers.keys().filter(func(r): return source_id(str(r), caster.tethers[r]) == source)
	if relations.is_empty(): return
	var victims: Array = caster.concentrating_on.get("targets", []).duplicate()
	for actor in PartyManager.characters.values():
		if actor not in victims: victims.append(actor)
	var released: Array = []
	for relation in relations:
		var tether: Dictionary = caster.tethers[relation]
		for victim in victims:
			if victim_id(victim) == str(tether.victim_id) and (victim is Character) == (str(tether.victim_kind) == "character") and victim not in released: released.append(victim)
		caster.tethers.erase(relation)
	for victim in released:
		CombatAction.remove_condition_source(victim, source, ["restrained"])
		SpellEffects.remove(victim, source, reason, cause)
	if str(caster.concentrating_on.get("effect_source", "")) == source: caster.concentrating_on.clear()

## Tethers binding this victim, as [{captor, source, relation, tether}].
static func binding(victim, captors: Array) -> Array:
	var id := victim_id(victim)
	var result: Array = []
	for c in captors:
		if not c is Character: continue
		prune(c)
		for relation in c.tethers:
			var source := source_id(str(relation), c.tethers[relation])
			if str(c.tethers[relation].victim_id) == id and (victim is Character) == (str(c.tethers[relation].victim_kind) == "character") and has_source(victim, source): result.append({"captor": c, "source": source, "relation": str(relation), "tether": c.tethers[relation]})
	if victim is Character:
		var room := LocalRoomCombat.room()
		for object in room.get("objects", []):
			if not object is Dictionary: continue
			for relation in object.get("tethers", {}):
				var tether: Dictionary = object.tethers[relation]
				var source := str(tether.get("condition_source_id", tether.get("source_id", "")))
				if str(tether.get("victim_id", "")) != id: continue
				if not has_source(victim, source):
					object.tethers.erase(relation)
					continue
				var owner: Character = PartyManager.characters.get(str(tether.get("caster_id", "")))
				if owner == null:
					for possible: Character in captors:
						if possible.character_id == str(tether.get("caster_id", "")): owner = possible; break
				result.append({"captor": owner, "source": str(tether.get("source_id", source)), "condition_source": source, "relation": str(relation), "tether": tether, "object": object})
	return result

## Escape one exact tether with the victim's best declared check; other restraints remain.
## The selection names an exact relation; omission is allowed only when unambiguous.
static func escape(victim, captors: Array, roll: int = 0, source: String = "") -> Dictionary:
	var bound := binding(victim, captors)
	if not source.is_empty(): bound = bound.filter(func(b): return str(b.relation) == source)
	elif bound.size() > 1: return {"attempted": false, "message": "Choose the exact tether to escape."}
	if bound.is_empty(): return {"attempted": false, "message": "Nothing tethers you." if source.is_empty() else "That tether does not bind you."}
	var entry: Dictionary = bound[0]
	var best := -100
	var used := ""
	for ability in entry.tether.escape:
		var mod := 0
		if victim is Character: mod = victim.ability_scores.get_ability_modifier(str(ability))
		else:
			mod = AbilityScores.get_modifier(int(victim.get("ability_scores", {}).get(str(ability), 10)))
			var skills: Variant = victim.get("skills", {})
			if skills is Dictionary: mod = int(skills.get(ESCAPES[ability], mod))
		if mod > best:
			best = mod
			used = str(ability)
	var dc := int(entry.tether.dc)
	var total := 0
	if victim is Character:
		var check := EventResolver.resolve_skill_check(victim, {"ability": used, "skill": ESCAPES[used], "dc": dc, "use_primal_knowledge": false})
		total = int(check.get("total", 0))
	else: total = (roll if roll > 0 else Dice.roll(20)) + best
	var freed := total >= dc
	if freed:
		if entry.has("object"): _release_object_anchor(entry.object, entry.relation, victim)
		else: _release(entry.captor, entry.relation, victim)
	return {"attempted": true, "success": freed, "total": total, "dc": dc, "ability": used, "source_id": entry.source, "relation_id": entry.relation, "message": "%s %s the tether with %s (%s) (%d vs DC %d)." % [_name(victim), "breaks free of" if freed else "fails to escape", used, ESCAPES[used], total, dc]}

## S-169: the exact tether another creature may free the victim from, by mode.
static func _rescuable(rescuer, victim, captors: Array, mode: String, source: String) -> Array:
	var bound := binding(victim, captors)
	if not source.is_empty(): bound = bound.filter(func(b): return str(b.relation) == source)
	var rid := victim_id(rescuer)
	return bound.filter(func(b): return (str(b.tether.anchor_id) != rid if not b.has("object") else true) and (b.tether.has("hp") if mode == "strike" else _effect(DataLoader.get_spell(str(b.tether.spell_id))).has("rescue")))

## Refusal before the rescuer's Action (or time) is spent.
static func rescue_error(rescuer, victim, captors: Array, mode: String, source: String = "") -> String:
	if mode not in ["check", "strike"]: return "Choose to pull free or to cut the tether."
	if rescuer == null or victim == null or victim_id(rescuer) == victim_id(victim): return "Choose another creature to free."
	if rescuer is Character and not rescuer.is_alive or rescuer is Dictionary and not bool(rescuer.get("is_alive", true)): return "An incapacitated creature cannot help."
	if binding(victim, captors).is_empty(): return "Nothing tethers them."
	if source.is_empty() and _rescuable(rescuer, victim, captors, mode, source).size() > 1: return "Choose the exact tether to rescue."
	if _rescuable(rescuer, victim, captors, mode, source).is_empty(): return "That tether cannot be cut." if mode == "strike" else "That tether cannot be pulled free from outside."
	if mode == "strike" and _strike_formula(rescuer).is_empty(): return "You have nothing to cut with."
	return ""

## The rescuer's weapon or melee attack damage, as dice and modifier.
static func _strike_formula(rescuer) -> Dictionary:
	if rescuer is Character:
		var weapon := DataLoader.get_item(rescuer.inventory.get_weapon())
		if str(weapon.get("damage", "")).is_empty(): return {}
		return {"dice": str(weapon.damage), "mod": rescuer.ability_scores.get_ability_modifier("STR")}
	if rescuer is Dictionary:
		for attack in rescuer.get("attacks", []):
			if attack is Dictionary and int(attack.get("range", 1)) <= 1 and not str(attack.get("damage", "")).is_empty():
				return {"dice": str(attack.damage), "mod": AbilityScores.get_modifier(int(rescuer.get("ability_scores", {}).get(str(attack.get("ability", "STR")), 10)))}
	return {}

## Route a rescue to the exact tether: "check" pulls it free with the rescuer's best
## declared ability; "strike" deals the rescuer's melee damage to the tether's own hp.
## Only that tether ends; other restraints and tethers on the victim stay.
static func rescue(rescuer, victim, captors: Array, mode: String, source: String = "", roll: int = 0) -> Dictionary:
	var error := rescue_error(rescuer, victim, captors, mode, source)
	if not error.is_empty(): return {"success": false, "attempted": false, "message": error}
	var entry: Dictionary = _rescuable(rescuer, victim, captors, mode, source)[0]
	var captor: Character = entry.captor
	var src := str(entry.relation)
	if mode == "strike":
		var f := _strike_formula(rescuer)
		var damage := maxi(1, Dice.parse_dice_string(str(f.dice), {}, rescuer if rescuer is Character else null) + int(f.mod))
		var relation_record: Dictionary = entry.object.tethers[src] if entry.has("object") else captor.tethers[src]
		var left := int(relation_record.hp) - damage
		if left <= 0:
			if entry.has("object"): _release_object_anchor(entry.object, src, victim)
			else: _release(captor, src, victim)
		else: relation_record["hp"] = left
		return {"success": left <= 0, "attempted": true, "seconds": 6, "damage": damage, "hp_left": maxi(0, left), "source_id": entry.source, "relation_id": src, "message": "%s cuts the tether on %s for %d damage%s." % [_name(rescuer), _name(victim), damage, "; it snaps" if left <= 0 else " (%d left)" % left]}
	var best := -100
	var used := ""
	for ability in _effect(DataLoader.get_spell(str(entry.tether.spell_id))).rescue:
		var mod := 0
		if rescuer is Character: mod = rescuer.ability_scores.get_ability_modifier(str(ability))
		else:
			mod = AbilityScores.get_modifier(int(rescuer.get("ability_scores", {}).get(str(ability), 10)))
			var skills: Variant = rescuer.get("skills", {})
			if skills is Dictionary: mod = int(skills.get(ESCAPES[ability], mod))
		if mod > best:
			best = mod
			used = str(ability)
	var dc := int(entry.tether.dc)
	var total := 0
	if rescuer is Character: total = int(EventResolver.resolve_skill_check(rescuer, {"ability": used, "skill": ESCAPES[used], "dc": dc, "use_primal_knowledge": false}).get("total", 0))
	else: total = (roll if roll > 0 else Dice.roll(20)) + best
	var freed := total >= dc
	if freed:
		if entry.has("object"): _release_object_anchor(entry.object, src, victim)
		else: _release(captor, src, victim)
	return {"success": freed, "attempted": true, "seconds": 6, "total": total, "dc": dc, "ability": used, "source_id": entry.source, "relation_id": src, "message": "%s %s %s from the tether with %s (%s) (%d vs DC %d)." % [_name(rescuer), "pulls" if freed else "fails to pull", _name(victim), used, ESCAPES[used], total, dc]}

static func _name(target) -> String:
	return target.character_name if target is Character else str(target.get("name", "The creature"))

## Combat: a tether whose victim is beyond its range from the anchor breaks; only that source ends.
static func enforce_range(captors: Array, positions: Dictionary, victims: Dictionary) -> Array:
	var broken: Array = []
	for c in captors:
		if not c is Character: continue
		prune(c)
		for source in c.tethers.keys():
			var t: Dictionary = c.tethers[source]
			var victim: Variant = victims.get(str(t.victim_id))
			if victim is Dictionary and not bool(victim.get("is_alive", true)):
				# S-169: a destroyed victim releases only its own relation (and the source's concentration when no target remains).
				_release(c, str(source), victim)
				broken.append(str(source))
				continue
			if not positions.has(str(t.anchor_id)) or not positions.has(str(t.victim_id)) or not victims.has(str(t.victim_id)): continue
			if HexUtils.get_distance(positions[str(t.anchor_id)], positions[str(t.victim_id)]) > int(t.range_hexes):
				_release(c, str(source), victims[str(t.victim_id)])
				broken.append(str(source))
	var room := LocalRoomCombat.room()
	for object in room.get("objects", []):
		if object is Dictionary and object.has("tethers"):
			broken.append_array(reconcile_object_anchor(object, room, victims.values(), positions))
	return broken

static func restore(actor: Character, data: Dictionary) -> void:
	actor.tethers = data.get("tethers", {}).duplicate(true) if data.get("tethers", {}) is Dictionary else {}

static func saved_error(dto: Dictionary) -> String:
	var tethers: Variant = dto.get("tethers", {})
	if not tethers is Dictionary: return "tethers are invalid"
	var counts := {}
	for relation in tethers:
		var t: Variant = tethers[relation]
		if not t is Dictionary or t.keys().any(func(k): return str(k) not in ["source_id", "spell_id", "victim_id", "victim_kind", "anchor_id", "condition", "range_hexes", "escape", "dc", "hp"]) or t.keys().size() != 8 + int(t.has("hp")) + int(t.has("source_id")): return "tether record is malformed"
		var source := source_id(str(relation), t)
		var spell := DataLoader.get_spell(str(t.get("spell_id", "")))
		var effect := _effect(spell)
		if effect.is_empty(): return "tether names a spell without a tether"
		if str(relation) != (relation_id(source, str(t.get("victim_kind", "")), str(t.get("victim_id", "")), int(effect.get("capacity", 1))) if t.has("source_id") else source): return "tether relation identity is invalid"
		counts[source] = int(counts.get(source, 0)) + 1
		if int(counts[source]) > int(effect.get("capacity", 1)): return "tether capacity exceeded"
		if t.has("hp") != effect.has("hp") or (t.has("hp") and (not (t.hp is int or t.hp is float) or float(t.hp) != floorf(float(t.hp)) or int(t.hp) < 1 or int(t.hp) > int(effect.hp))): return "tether hp is invalid"
		if not str(source).begins_with("spell:%s:" % str(dto.get("character_id", ""))) or str(t.get("anchor_id", "")) != str(dto.get("character_id", "")): return "tether has an invalid captor"
		if str(dto.get("spell_concentration", dto.get("concentrating_on", {})).get("effect_source", "")) != str(source): return "tether lacks its concentration source"
		if str(t.get("condition", "")) != str(effect.condition) or not SourceEndAftermathRules._int(t.get("range_hexes"), 1, 30) or int(t.range_hexes) != int(effect.range_hexes) or t.get("escape") != effect.escape or str(t.get("victim_kind", "")) not in ["character", "monster"] or str(t.get("victim_id", "")).is_empty() or str(t.victim_id) == str(dto.get("character_id", "")): return "tether differs from its spell"
		var dc: Variant = t.get("dc")
		if not (dc is int or dc is float) or not is_finite(float(dc)) or float(dc) != floorf(float(dc)) or int(dc) < 1 or int(dc) > 30: return "tether DC is invalid"
	return ""

static func saved_party_error(characters: Dictionary, save_data: Dictionary = {}) -> String:
	for dto in characters.values():
		var seen := {}
		for relation in dto.get("tethers", {}):
			var tether: Dictionary = dto.tethers[relation]
			var source := source_id(str(relation), tether)
			var id := str(tether.victim_id)
			var identity := "%s|%s|%s" % [source, tether.victim_kind, id]
			if seen.has(identity): return "duplicate tether victim"
			seen[identity] = true
			if str(tether.victim_kind) != "character" or not characters.has(id): return "saved tether has no persistent victim"
			var record: Dictionary = characters[id].get("spell_effects", {}).get(source, {})
			if str(record.get("caster_id", "")) != str(dto.character_id) or str(record.get("spell_id", "")) != str(tether.spell_id) or int(record.get("save_dc", -1)) != int(tether.dc) or not bool(record.get("concentration", false)) or not characters[id].get("condition_sources", {}).get(str(tether.condition), {}).has(source): return "saved tether lacks its exact victim source"
	if not save_data.is_empty():
		var campaign: Dictionary = save_data.get("campaign_ledger", {})
		var dungeons: Array = [save_data.get("active_dungeon_state", {})]
		dungeons.append_array(campaign.get("dungeon_snapshots", {}).values())
		var anchor_counts: Dictionary = {}
		var seen_object_relations: Dictionary = {}
		var linked_conditions: Dictionary = {}
		for dungeon in dungeons:
			for room in dungeon.get("local_rooms", {}).values():
				for object in room.get("objects", []):
					if not object is Dictionary: continue
					var object_tethers: Variant = object.get("tethers", {})
					if not object_tethers is Dictionary: return "saved object tethers are malformed"
					for relation in object_tethers:
						var tether_value: Variant = object.tethers[relation]
						if not tether_value is Dictionary: return "saved object tether relation is malformed"
						var tether: Dictionary = tether_value
						var source := str(tether.get("source_id", ""))
						var anchor_relation_key := "%s|%s" % [source, str(relation)]
						var anchored_record := {"tether": tether, "dungeon": dungeon.get("dungeon_id", ""), "room": room.get("id", ""), "object": object.get("id", ""), "position": object.get("position"), "plane": object.get("plane"), "hp": object.get("hp"), "removed": object.get("removed", false)}
						if seen_object_relations.has(anchor_relation_key):
							if seen_object_relations[anchor_relation_key] != anchored_record: return "duplicate saved object tether relation"
							continue
						seen_object_relations[anchor_relation_key] = anchored_record.duplicate(true)
						var victim_id_value := str(tether.get("victim_id", ""))
						var victim: Dictionary = characters.get(victim_id_value, {})
						var condition_source := str(tether.get("condition_source_id", ""))
						var spell := DataLoader.get_spell(str(tether.get("spell_id", "")))
						var effect := _effect(spell)
						var expected_relation := relation_id(source, "character", victim_id_value, int(effect.get("capacity", 1)))
						var effect_record: Dictionary = victim.get("spell_effects", {}).get(condition_source, {})
						var expected_condition_source := "object_tether:%s:%s:%s" % [str(tether.get("caster_id", "")), source.get_slice(":", source.get_slice_count(":") - 1), victim_id_value]
						if str(relation) != expected_relation or str(tether.get("anchor_id", "")) != str(object.get("id", "")) or str(tether.get("anchor_kind", "")) != "object" or str(tether.get("victim_kind", "")) != "character" or victim.is_empty() or effect.is_empty() or str(effect.get("anchor", "character")) != "object" or not source.begins_with("spell:%s:" % str(tether.get("caster_id", ""))) or condition_source != expected_condition_source or str(tether.get("condition", "")) != str(effect.get("condition", "")) or not victim.get("condition_sources", {}).get(str(tether.get("condition", "")), {}).has(condition_source) or str(effect_record.get("spell_id", "")) != str(tether.get("spell_id", "")) or str(effect_record.get("caster_id", "")) != str(tether.get("caster_id", "")) or bool(effect_record.get("concentration", true)):
							return "saved object tether lacks its exact victim source"
						if not characters.has(str(tether.get("caster_id", ""))): return "saved object tether names a missing caster"
						var anchor_pos: Variant = tether.get("anchor_position", null)
						if not SourceEndAftermathRules._int(tether.get("anchor_hp"), 1, 2147483647): return "saved object tether anchor HP is invalid"
						if anchor_pos != object.get("position", null) or str(tether.get("anchor_plane", "")) != str(PhysicalFactsRules.get_plane(object, {"plane": PhysicalFactsRules.get_plane(room)})) or int(tether.get("anchor_hp", -1)) != int(object.get("hp", 0)) or int(object.get("hp", 0)) <= 0 or bool(object.get("removed", false)):
							return "saved object tether has a stale anchor"
						var dc: Variant = tether.get("dc", null)
						if not SourceEndAftermathRules._int(dc, 1, 30) or int(effect_record.get("save_dc", -1)) != int(dc) or not SourceEndAftermathRules._int(tether.get("range_hexes"), 1, 30) or int(tether.range_hexes) != int(effect.get("range_hexes", -2)) or tether.get("escape") != effect.get("escape", []): return "saved object tether differs from its spell"
						if not SourceEndAftermathRules._int(tether.get("anchor_hp"), 1, 2147483647) or tether.get("rescue", effect.get("rescue", [])) != effect.get("rescue", []) or tether.has("hp") != effect.has("hp") or (tether.has("hp") and not SourceEndAftermathRules._int(tether.hp, 1, int(effect.hp))): return "saved object tether HP or rescue rules are invalid"
						var condition_key := JSON.stringify([victim_id_value, condition_source])
						if linked_conditions.has(condition_key): return "saved object tether condition has several relations"
						linked_conditions[condition_key] = true
						anchor_counts[source] = int(anchor_counts.get(source, 0)) + 1
						if int(anchor_counts[source]) > int(effect.get("capacity", 1)): return "saved object tether capacity exceeded"
		for victim in characters.values():
			for source in victim.get("spell_effects", {}):
				if str(source).begins_with("object_tether:") and not linked_conditions.has(JSON.stringify([str(victim.get("character_id", "")), source])): return "saved object tether source lacks its exact anchor relation"
	return ""
