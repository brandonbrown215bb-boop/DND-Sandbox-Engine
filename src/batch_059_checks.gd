class_name Batch059Checks
extends RefCounted
## Batch 059 (S-155): Animate Dead-shaped casts are limited by eligible remains nearby.

const REMAINS := "fixture:b059_animate_remains"

static func load_fixtures() -> void:
	Batch058Checks.load_fixtures()
	if not DataLoader.get_spell(REMAINS).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_059/spells/animate_remains.json", "spell")

static func _body(remains: String, at: Vector2i, kind := "humanoid", size := "medium") -> Dictionary:
	return {"id": "b059_body_%d_%d" % [at.x, at.y], "name": "Body", "is_alive": false, "current_hp": 0, "remains": remains, "creature_type": kind, "size": size, "hex_position": at}

static func _cast(owner: Character, monsters: Array, extra_players: Array = []) -> SpellCastContext:
	var c := SpellCastContext.new()
	c.caster = owner
	var players: Array[Dictionary] = [{"character": owner, "hex_position": Vector2i.ZERO}]
	for p in extra_players: players.append(p)
	c.players = players
	c.player_index = 0
	var ms: Array[Dictionary] = []
	for m in monsters: ms.append(m)
	c.monsters = ms
	return c

static func run(check: Callable) -> void:
	load_fixtures()
	var spell := DataLoader.get_spell(REMAINS)
	var effect := CreatedActorRules._effect(spell)
	check.call(DataLoader.get_load_errors().is_empty() and not MaterialTargetRules.spec(effect).is_empty(), "059 animate-remains fixture loads with data-declared material targets: %s" % str(DataLoader.get_load_errors()))
	# Slot scaling is the existing mix.count formula (SRD: +2 creatures per slot level above 3rd).
	check.call(CreatedActorRules.counts(effect, {}, 0) == [1] and CreatedActorRules.counts(effect, {}, 1).back() == 3 and CreatedActorRules.counts(effect, {}, 2).back() == 5 and CreatedActorRules.counts(effect, {}, 6).back() == 13, "059 slot scaling: 1 at 3rd, 3 at 4th, 5 at 5th, 13 at 9th")
	var bad := []
	for mutate in ["shape", "key", "tag", "range", "type", "kind_id", "kind_tag"]:
		var e: Dictionary = effect.duplicate(true)
		match mutate:
			"shape": e.material_targets = ["bones"]
			"key": e.material_targets["extra"] = 1
			"tag": e.material_targets.tags = ["ashes"]
			"range": e.material_targets.range = -1
			"type": e.material_targets.creature_types = ["robot"]
			"kind_id": e.material_targets.kinds = {"b054_owl": "bones"}
			"kind_tag": e.material_targets.tags = ["bones"]
		bad.append(SharedSpell.content_error(Batch058Checks._spell(REMAINS, e)))
	check.call(bad.all(func(x): return not str(x).is_empty()), "059 loader refuses malformed material targets (%s)" % str(bad))
	var owner := Batch031Checks._character("b059_owner", 20)
	# Legacy: an effect with no material_targets has no cap (058 casts unchanged).
	check.call(MaterialTargetRules.cap(_cast(owner, []), CreatedActorRules._effect(DataLoader.get_spell(Batch058Checks.BONES))).is_empty(), "059 effects without material_targets are uncapped (058 behaviour unchanged)")
	# Eligibility: in range, Humanoid, Small/Medium, corpse/bones, not used.
	var bodies := [_body("bones", Vector2i(1, 0)), _body("intact", Vector2i(0, 1)), _body("bones", Vector2i(5, 5)), _body("bones", Vector2i(1, 1), "fey"), _body("bones", Vector2i(0, 2), "humanoid", "large"), _body("dust", Vector2i(1, 0))]
	var alive := _body("bones", Vector2i(1, 0)); alive.is_alive = true
	bodies.append(alive)
	var cap := MaterialTargetRules.cap(_cast(owner, bodies), effect)
	check.call(cap.total == 2 and cap.kinds.b059_skeleton == 1 and cap.kinds.b059_zombie == 1, "059 only nearby Small/Medium Humanoid corpses and bones count; far, Fey, Large, dust and living do not (%s)" % str(cap))
	var dead := Batch031Checks._character("b059_fallen", 20)
	dead.current_hp = 0
	dead.is_alive = false
	dead.death_save_failures = 3
	CorpseRules.mark_dead(dead, "test", "intact", 0)
	dead.creature_type = "humanoid"
	var with_pc := MaterialTargetRules.cap(_cast(owner, [], [{"character": dead, "hex_position": Vector2i(1, 0)}]), effect)
	check.call(dead.is_dead() and with_pc.total == 1 and with_pc.kinds.b059_zombie == 1, "059 a dead party member's corpse counts as a Zombie target (%s)" % str(with_pc))
	check.call(MaterialTargetRules.mix_cap_error({"b059_skeleton": 1, "b059_zombie": 1}, cap).is_empty() and not MaterialTargetRules.mix_cap_error({"b059_skeleton": 2}, cap).is_empty() and not MaterialTargetRules.mix_cap_error({"b059_skeleton": 1, "b059_zombie": 2}, cap).is_empty(), "059 the mix is capped at min(slot count, remains) and per kind by its remains")
	check.call(SpellCastChoices._capped([1, 2, 3], cap) == [1, 2] and SpellCastChoices._capped([5], cap) == [2] and SpellCastChoices._capped([1, 2], {}) == [1, 2], "059 fewer remains than the slot allows: the cast still creates as many as it can")
	# Consumption: each creature uses one body; used bodies stop counting.
	var cast := _cast(owner, bodies, [{"character": dead, "hex_position": Vector2i(2, 0)}])
	var used := MaterialTargetRules.consume(cast, effect, {"mix": {"b059_skeleton": 1, "b059_zombie": 1}})
	var after := MaterialTargetRules.cap(cast, effect)
	check.call(used == 2 and bool(bodies[0].get("material_used", false)) and bool(bodies[1].get("material_used", false)) and after.total == 1 and after.kinds.b059_zombie == 1 and not "transformed_undead" in dead.corpse_state.recovery_restrictions, "059 nearest matching remains are used, one per creature (used=%d left=%s)" % [used, str(after)])
	MaterialTargetRules.consume(cast, effect, {"mix": {"b059_zombie": 1}})
	check.call("transformed_undead" in dead.corpse_state.recovery_restrictions and MaterialTargetRules.cap(cast, effect).total == 0, "059 a used party corpse carries the saved transformed_undead restriction and no longer counts")
	var dto: Dictionary = JSON.parse_string(JSON.stringify(dead.to_dict()))
	check.call(CorpseRules.saved_error(dto).is_empty(), "059 checklist (b): the used corpse still passes the saved corpse check: %s" % CorpseRules.saved_error(dto))
