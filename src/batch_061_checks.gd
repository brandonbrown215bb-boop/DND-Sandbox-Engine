class_name Batch061Checks
extends RefCounted
## Batch 061 (S-157 summon turn timing): when a created actor acts in initiative
## is declared in data (command.initiative: owner_turn, after_owner, own), per
## kind; mixed casts keep each kind's authored command and initiative policy.

const INSECTS := "fixture:b061_insects"

static func load_fixtures() -> void:
	Batch056Checks.load_fixtures()
	if not DataLoader.get_spell(INSECTS).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_061/spells/insects.json", "spell")

static func cast(owner: Character, n: int) -> Dictionary:
	return {"source_id": "spell:%s:b061_%d" % [owner.character_id, n], "caster_id": owner.character_id, "spell_id": INSECTS, "concentration": true, "conditions": []}

## One Spider and one Wasp from a single mixed cast.
static func make(owner: Character, n: int = 1) -> Dictionary:
	var spell := DataLoader.get_spell(INSECTS)
	var made := CreatedActorRules.create(owner, cast(owner, n), spell.effects[0].template, 1, spell, -1, {"b061_spider": 1, "b061_wasp": 1})
	owner.concentrating_on = {"effect_source": cast(owner, n).source_id}
	return made

## The fixture effect with each kind's command replaced, for loader checks.
static func _mix(a: Dictionary, b: Dictionary) -> Dictionary:
	var e: Dictionary = DataLoader.get_spell(INSECTS).effects[0].duplicate(true)
	e.template.command = a
	e.options[0].command = b
	return e

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_spell(INSECTS).is_empty(), "061 insect fixture loads (its kinds spell the no-cost command free and none): %s" % str(DataLoader.get_load_errors()))
	var bad := [{"initiative": "first"}, {"initiative": "shares_owner_turn"}, {"initiative": ""}, {"initiative": 1}, {"initiative": "AFTER_OWNER"}]
	var good := [{"initiative": "owner_turn"}, {"initiative": "after_owner"}, {"initiative": "own"}, {}]
	check.call(bad.all(func(p): return not CreatedCommandRules.policy_error(p).is_empty()) and good.all(func(p): return CreatedCommandRules.policy_error(p).is_empty()), "061 loader accepts owner_turn/after_owner/own (or absent) turn timing and refuses unknown values")
	# Mixed kinds retain independent authored policies; free and none remain equivalent costs.
	var same := [_mix({"cost": "free"}, {"cost": "none"}), _mix({"cost": "none", "order_costs": {"attack": "free"}}, {"cost": "free", "order_costs": {"attack": "none"}}), _mix({}, {"initiative": "owner_turn"}), _mix({"initiative": "after_owner", "cost": "free"}, {"initiative": "after_owner", "cost": "none"})]
	var differ := [_mix({"initiative": "after_owner"}, {"initiative": "own"}), _mix({}, {"initiative": "after_owner"}), _mix({"cost": "free"}, {"cost": "bonus_action"}), _mix({"cost": "none"}, {"cost": "action"})]
	check.call(same.all(func(e): return CreatedActorRules.mix_error(e).is_empty()) and differ.all(func(e): return CreatedActorRules.mix_error(e).is_empty()), "061 mixed casts accept per-kind timing/cost policies while free and none remain equivalent")
	var fp := CreatedCommandRules.policy({"command": {"cost": "free"}})
	check.call(str(fp.get("cost", "")) == "free" and CreatedCommandRules.cost(fp, "dodge") == "none", "061 normalization is comparison-only: the stored policy keeps the authored spelling and still pays nothing (%s -> %s)" % [str(fp), CreatedCommandRules.cost(fp, "dodge")])
	# Declared timing drives the real join_initiative on each kind.
	var owner := Batch031Checks._character("b061_owner", 30)
	var made := make(owner)
	var live := CreatedActorRules.actors(owner)
	var s := Batch056Checks.battle(owner, live)
	var names: Array = live.map(func(a): return a.character_name)
	check.call(made.created and live.size() == 2 and live.all(func(a): return CreatedCommandRules.initiative(owner, a) == "after_owner") and Batch056Checks.order(s) == ["b061_owner", names[0], names[1], "Goblin"], "061 a mixed after_owner cast: both kinds take their own turns right after the owner, before the goblin (%s)" % str(Batch056Checks.order(s)))
	# Legacy: no initiative field keeps 055/056's owner_turn (no tracker entry).
	var l_owner := Batch031Checks._character("b061_legacy", 30)
	var pack := DataLoader.get_spell(Batch055Checks.PACK)
	CreatedActorRules.create(l_owner, {"source_id": "spell:%s:b061l" % l_owner.character_id, "caster_id": l_owner.character_id, "spell_id": Batch055Checks.PACK, "concentration": true, "conditions": []}, pack.effects[0].template, 1, pack)
	var la := CreatedActorRules.actors(l_owner)
	var ls := Batch056Checks.battle(l_owner, la)
	check.call(not pack.effects[0].template.get("command", {}).has("initiative") and la.size() > 0 and la.all(func(a): return CreatedCommandRules.initiative(l_owner, a) == "owner_turn") and Batch056Checks.order(ls) == ["b061_legacy", "Goblin"], "061 legacy: a template without initiative keeps owner_turn and adds no turns (%s)" % str(Batch056Checks.order(ls)))
	# (b)/(d): timing is read from the template, not saved; a round-tripped owner keeps it.
	var dto: Dictionary = JSON.parse_string(JSON.stringify(owner.to_dict()))
	var rec: Dictionary = dto.spell_effects[cast(owner, 1).source_id]
	var back := Character.new()
	back.from_dict(dto)
	var bl := CreatedActorRules.actors(back)
	var bs := Batch056Checks.battle(back, bl)
	check.call(CreatedActorRules.saved_record_error(dto, rec).is_empty() and not JSON.stringify(rec).contains("initiative") and bl.size() == 2 and Batch056Checks.order(bs) == Batch056Checks.order(s), "061 checklist (b)/(d): the saved record validates unchanged, carries no timing field, and a reloaded owner rebuilds the same turn order (%s)" % str(Batch056Checks.order(bs)))

	# Review R1 stress: a goblin tying the owner on roll and DEX (id sorting after
	# the owner) must not split the owner from its after_owner summons when a
	# later own-initiative join re-sorts the tracker; a second owner's summons too.
	var t_owner := Batch031Checks._character("b061_a_owner", 30)
	make(t_owner, 7)
	var tl := CreatedActorRules.actors(t_owner)
	var ts := Batch056Checks.battle(t_owner, [])
	var tie := {"id": "zz_b061_tie", "name": "TieGoblin", "is_alive": true, "current_hp": 9, "max_hp": 9, "ac": 1}
	ts.tracker.add_combatant("zz_b061_tie", "TieGoblin", false, tie, 15, 14)
	ts.tracker.sort_initiative()
	for a in tl: CreatedCommandRules.join_initiative(ts, t_owner, a)
	var o2 := Batch031Checks._character("b061_b_owner", 30)
	make(o2, 8)
	var tl2 := CreatedActorRules.actors(o2)
	ts.tracker.add_combatant(o2.character_id, o2.character_name, true, o2, 15, 14)
	ts.tracker.sort_initiative_preserving_active()
	for a in tl2: CreatedCommandRules.join_initiative(ts, o2, a)
	ts.tracker.sort_initiative_preserving_active()
	var ids: Array = ts.tracker.combatants.map(func(c): return str(c.id))
	var ia := ids.find(t_owner.character_id)
	var ib := ids.find(o2.character_id)
	var ok := ia >= 0 and ib >= 0 and tl.all(func(a): return ids.find(a.character_id) in [ia + 1, ia + 2]) and tl2.all(func(a): return ids.find(a.character_id) in [ib + 1, ib + 2]) and ids.size() == 8
	check.call(ok, "061 review R1: after_owner summons stay right behind their own owner after re-sorts, with a roll/DEX tie and two owners (%s)" % str(ts.tracker.combatants.map(func(c): return str(c.name))))
