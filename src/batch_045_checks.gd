class_name Batch045Checks
extends RefCounted

const WING := "fixture:b045_wing_ring"
const LAMP := "fixture:b045_fuel_lamp"
const LASH := "fixture:b045_lash"

static func load_fixtures() -> void:
	Batch044Checks.load_fixtures()
	if not DataLoader.get_item(WING).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_045/items/active.json", "item")
	DataLoader._load_json_file("res://data/fixtures/batch_045/spells/lash.json", "spell")

static func actor(id: String) -> Character:
	return Batch031Checks._character(id, 40)

static func add(a: Character, definition: String) -> String:
	return Batch041Checks.add_copy(a, definition)

## Real shared resolver cast; retries fresh seeds only until the save fails (slot refilled each try).
static func lash(caster: Character, target) -> Dictionary:
	var r := {}
	for i in 30:
		seed(45000 + i)
		caster.spell_slots = {"1": 1}
		r = SpellResolver.resolve(caster, target, DataLoader.get_spell(LASH).duplicate(true), true, {}, [], 1)
		if r.get("tether", {}).get("bound", false):
			caster.concentrating_on = {"spell_id": LASH, "effect_source": str(r.tether.source_id), "targets": [target]}
			return r
		if r.get("refused", false): return r
		SpellEffects.remove(target, str(r.get("effect_cast", {}).get("source_id", "")))
	return r

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "045 neutral active-time items and tether spell load: %s" % str(DataLoader.get_load_errors()))
	_active_validation(check)
	_active(check)
	_active_saves(check)
	_tether_validation(check)
	_tethers(check)
	_tether_saves(check)
	review_stress(check)

static func _active_validation(check: Callable) -> void:
	var p: Dictionary = DataLoader.get_item(WING).active_time.duplicate(true)
	check.call(ActiveTimeRules.policy_error(p).is_empty(), "045 S-064 declared active time validates")
	var bad := 0
	for mutate in [func(x): x.budget_seconds = 0, func(x): x.budget_seconds = 1.5, func(x): x.cooldown_seconds = -1, func(x): x["refuel"] = true, func(x): x.erase("budget_seconds")]:
		var x := p.duplicate(true)
		mutate.call(x)
		if not ActiveTimeRules.policy_error(x).is_empty(): bad += 1
	check.call(bad == 5, "045 S-064 loader refuses zero, fractional, negative, unknown and missing budgets (%d/5)" % bad)

static func _active(check: Callable) -> void:
	var a := actor("b045_flier")
	var ring := add(a, WING)
	a.inventory.equip_instance(Inventory.Slot.RING_1, ring)
	var t := 1000
	check.call(SourceBenefitRules.total(a, "speed") == 0, "045 S-064 an inactive copy grants nothing")
	check.call(ActiveTimeRules.activate(a, ring, t).success and SourceBenefitRules.total(a, "speed") == 2, "045 S-064 activation turns on the copy's benefit")
	t += 25
	ActiveTimeRules.settle(a, 25, t)
	ActiveTimeRules.pause(a, ring)
	t += 500
	ActiveTimeRules.settle(a, 500, t)
	var rec := a.inventory.get_instance(ring)
	check.call(ActiveTimeRules.used(rec) == 25 and not ActiveTimeRules.is_active(rec) and SourceBenefitRules.total(a, "speed") == 0, "045 S-064 paused time is not spent (used=%d)" % ActiveTimeRules.used(rec))
	ActiveTimeRules.activate(a, ring, t)
	check.call(ActiveTimeRules.used(a.inventory.get_instance(ring)) == 25, "045 S-064 resuming continues the same allowance instead of restarting it")
	t += 50
	var receipts := ActiveTimeRules.settle(a, 50, t)
	rec = a.inventory.get_instance(ring)
	check.call(receipts.size() == 1 and int(receipts[0].exhausted_at) == t - 15 and ActiveTimeRules.used(rec) == 60 and not ActiveTimeRules.is_active(rec) and int(rec.state.active_cooldown_until) == t - 15 + 600, "045 S-064 exhaustion records its exact time and the cooldown starts there")
	var before := a.inventory.get_instance(ring)
	var refused := ActiveTimeRules.activate(a, ring, t + 10)
	check.call(not refused.success and "recovering" in refused.message and a.inventory.get_instance(ring) == before, "045 S-064 activation during cooldown refuses before anything changes")
	t = t - 15 + 600
	ActiveTimeRules.settle(a, 0, t)
	check.call(ActiveTimeRules.used(a.inventory.get_instance(ring)) == 0 and ActiveTimeRules.activate(a, ring, t).success, "045 S-064 a fresh allowance exists only after the declared cooldown")
	var lamp := add(a, LAMP)
	ActiveTimeRules.activate(a, lamp, t)
	ActiveTimeRules.settle(a, 200, t + 200)
	var spent := a.inventory.get_instance(lamp)
	check.call(ActiveTimeRules.used(spent) == 120 and not spent.state.has("active_cooldown_until") and not ActiveTimeRules.activate(a, lamp, t + 999999).success, "045 S-064 an undeclared cooldown never refreshes spent fuel")
	var other := add(a, WING)
	check.call(ActiveTimeRules.used(a.inventory.get_instance(other)) == 0 and ActiveTimeRules.activate(a, other, t).success, "045 S-064 another copy keeps its own budget")

static func _active_saves(check: Callable) -> void:
	var a := actor("b045_active_save")
	var ring := add(a, WING)
	ActiveTimeRules.activate(a, ring, 0)
	ActiveTimeRules.settle(a, 20, 20)
	var dto := a.to_dict()
	var rec: Dictionary = dto.inventory.copies.records[ring]
	check.call(InventoryCopies.record_state_error(rec).is_empty() and InventoryCopies.saved_error(dto.inventory).is_empty(), "045 S-064 saved active time passes record_state_error (%s)" % InventoryCopies.record_state_error(rec))
	var back := Character.new()
	back.from_dict(dto)
	ActiveTimeRules.settle(back, 10, 30)
	check.call(ActiveTimeRules.used(back.inventory.get_instance(ring)) == 30 and ActiveTimeRules.is_active(back.inventory.get_instance(ring)), "045 S-064 reload keeps the spent total and the active state")
	var defects := [
		func(r): r.state.active_used_seconds = 61,
		func(r): r.state.active = "yes",
		func(r):
			r.state.active_used_seconds = 60
			r.state.active = true,
		func(r): r.state.active_cooldown_until = 99,
		func(r): r.definition_id = LAMP if false else "dagger",
	]
	var refused := 0
	for mutate in defects:
		var bad: Dictionary = rec.duplicate(true)
		mutate.call(bad)
		if not ActiveTimeRules.record_error(bad).is_empty(): refused += 1
	check.call(refused == 5, "045 S-064 saved active time refuses overspent, malformed, spent-active, early-cooldown and undeclared records (%d/5)" % refused)
	var bag := add(a, Batch043Checks.SATCHEL)
	var lamp := add(a, LAMP)
	ActiveTimeRules.activate(a, lamp, 30)
	ActiveTimeRules.settle(a, 5, 35)
	ActiveTimeRules.pause(a, lamp)
	var put := ContainerRules.put(a.inventory, bag, lamp, "main")
	var nested := a.to_dict()
	if put.get("success", false): nested.inventory.copies.records[bag].state.contents.main[0].state.active_used_seconds = 500
	check.call(put.get("success", false) and not ContainerRules.saved_error(nested).is_empty(), "045 S-064 a contained copy's active time goes through record_state_error too")

static func _tether_validation(check: Callable) -> void:
	var e: Dictionary = DataLoader.get_spell(LASH).effects[0].duplicate(true)
	check.call(TetherRules.effect_error(e).is_empty() and SharedSpell.content_error(DataLoader.get_spell(LASH)).is_empty(), "045 S-168 declared tether validates (%s)" % SharedSpell.content_error(DataLoader.get_spell(LASH)))
	var bad := 0
	for mutate in [func(x): x.condition = "grappled", func(x): x.range_hexes = 0, func(x): x.escape = ["CHA"], func(x): x.escape = [], func(x): x.capacity = 9, func(x): x["drag"] = true]:
		var x := e.duplicate(true)
		mutate.call(x)
		if not TetherRules.effect_error(x).is_empty(): bad += 1
	check.call(bad == 6, "045 S-168 loader refuses unsupported condition, range, escape, capacity and fields (%d/6)" % bad)

static func _tethers(check: Callable) -> void:
	var c := actor("b045_captor")
	var v := actor("b045_victim")
	v.ability_scores.from_dict({"STR": 8, "DEX": 8, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	var r := lash(c, v)
	var source := str(r.get("tether", {}).get("source_id", ""))
	check.call(r.get("tether", {}).get("bound", false) and v.has_condition("restrained") and c.tethers.has(source) and str(c.tethers[source].victim_id) == v.character_id and str(c.tethers[source].anchor_id) == c.character_id, "045 S-168 a failed save binds captor, victim and anchor under the cast's own source")
	c.spell_slots = {"1": 1}
	var again := SpellResolver.resolve(c, actor("b045_second"), DataLoader.get_spell(LASH).duplicate(true), true, {}, [], 1)
	check.call(again.get("refused", false) and int(c.spell_slots.get("1", 0)) == 1 and not TetherRules.cast_error(c, DataLoader.get_spell(LASH)).is_empty(), "045 S-168 a full tether capacity refuses before the slot is spent (slots=%s)" % str(c.spell_slots))
	v.add_condition("restrained", 10, "fixture:other_restraint")
	var esc := {}
	for i in 40:
		seed(45500 + i)
		esc = TetherRules.escape(v, [c])
		if esc.get("success", false): break
	check.call(esc.get("success", false) and not c.tethers.has(source) and not TetherRules.has_source(v, source) and v.has_condition("restrained") and TetherRules.has_source(v, "fixture:other_restraint"), "045 S-168 escaping removes only that tether's restraint; another source keeps the victim restrained")
	var m := {"id": "b045_goblin", "name": "Goblin", "ability_scores": {"STR": 8, "DEX": 14}, "skills": {}, "conditions": {}, "condition_sources": {}, "saves": {}}
	var c2 := actor("b045_captor_two")
	var mr := lash(c2, m)
	var msource := str(mr.get("tether", {}).get("source_id", ""))
	var miss := TetherRules.escape(m, [c2], 1)
	check.call(mr.get("tether", {}).get("bound", false) and miss.attempted and not miss.success and miss.ability == "DEX" and c2.tethers.has(msource), "045 S-168 a monster escape uses its best declared ability against the tether DC (%s)" % str(miss.get("message", "")))
	var broken := TetherRules.enforce_range([c2], {c2.character_id: Vector2i.ZERO, "b045_goblin": Vector2i(5, 0)}, {"b045_goblin": m})
	check.call(broken == [msource] and not c2.tethers.has(msource) and not CombatAction.has_condition(m, "restrained"), "045 S-168 a victim beyond the tether range breaks only that tether")
	var c3 := actor("b045_captor_three")
	var r3 := lash(c3, v)
	var bound3 := TetherRules.binding(v, [c3]).size()
	SpellEffects.end_concentration(c3, [v])
	check.call(r3.get("tether", {}).get("bound", false) and bound3 == 1 and TetherRules.held(c3).is_empty() and not TetherRules.has_source(v, str(r3.tether.source_id)) and TetherRules.binding(v, [c3]).is_empty(), "045 S-168 ending the source's concentration ends its tether (bound=%s/%d conc=%s)" % [str(r3.get("tether", {})), bound3, str(c3.concentrating_on)])

static func _tether_saves(check: Callable) -> void:
	var c := actor("b045_tether_save")
	var v := actor("b045_tether_victim")
	v.ability_scores.from_dict({"STR": 8, "DEX": 8, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	var r := lash(c, v)
	var dto := c.to_dict()
	check.call(r.get("tether", {}).get("bound", false) and TetherRules.saved_error(dto).is_empty() and dto.tethers.size() == 1, "045 S-168 a live tether validates in the captor's save (%s)" % TetherRules.saved_error(dto))
	var back := Character.new()
	back.from_dict(dto)
	check.call(back.tethers.size() == 1 and TetherRules.binding(v, [back]).size() == 1, "045 S-168 reload keeps the exact relation to the same victim")
	var source: String = dto.tethers.keys()[0]
	var defects := {
		"widened": func(d): d.tethers[source].range_hexes = 30,
		"other captor": func(d): d.tethers[source].anchor_id = "someone",
		"self": func(d): d.tethers[source].victim_id = d.character_id,
		"orphan": func(d): d.spell_concentration = {},
		"extra": func(d): d.tethers[source]["dragging"] = true,
	}
	var refused := 0
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		if not TetherRules.saved_error(bad).is_empty(): refused += 1
	check.call(refused == 5, "045 S-168 saved tethers refuse widened, foreign, self, orphaned and extended records (%d/5)" % refused)


## Runtime Reviewer stress (RT2-RT6; RT1 is in the scenario).
static func review_stress(check: Callable) -> void:
	# RT2: two captors on one victim; escape names an exact tether and leaves the other.
	var v := actor("b045_rt2_v")
	var c1 := actor("b045_rt2_c1")
	var c2 := actor("b045_rt2_c2")
	var r1 := lash(c1, v)
	var r2 := lash(c2, v)
	var s1 := str(r1.get("tether", {}).get("source_id", ""))
	var s2 := str(r2.get("tether", {}).get("source_id", ""))
	var both := TetherRules.binding(v, [c1, c2]).size()
	var esc := {}
	for i in 40:
		seed(45200 + i)
		esc = TetherRules.escape(v, [c1, c2], 0, s2)
		if esc.get("success", false): break
	check.call(both == 2 and esc.get("success", false) and esc.source_id == s2 and c1.tethers.has(s1) and not c2.tethers.has(s2) and TetherRules.has_source(v, s1) and not TetherRules.has_source(v, s2) and CombatAction.has_condition(v, "restrained"), "045 RT2 escaping one of two tethers frees only that exact source (both=%d)" % both)
	check.call(not TetherRules.escape(v, [c1, c2], 0, s2).attempted and c1.tethers.has(s1), "045 RT2 naming an already-escaped tether changes nothing")
	# RT3: positions changed by teleport break the tether on the next range check regardless of turn.
	var v3 := actor("b045_rt3_v")
	var c3 := actor("b045_rt3_c")
	var r3 := lash(c3, v3)
	var kept := TetherRules.enforce_range([c3], {c3.character_id: Vector2i.ZERO, v3.character_id: Vector2i(3, 0)}, {v3.character_id: v3})
	var gone := TetherRules.enforce_range([c3], {c3.character_id: Vector2i.ZERO, v3.character_id: Vector2i(4, 0)}, {v3.character_id: v3})
	check.call(r3.get("tether", {}).get("bound", false) and kept.is_empty() and gone.size() == 1 and not CombatAction.has_condition(v3, "restrained") and c3.concentrating_on.is_empty(), "045 RT3 range is inclusive at 3 hexes and one hex beyond ends tether and its concentration")
	# RT4: capacity refusal is pre-cost (cast_error) while held.
	var v4 := actor("b045_rt4_v")
	var c4 := actor("b045_rt4_c")
	lash(c4, v4)
	c4.spell_slots = {"1": 1}
	var refused := SpellResolver.resolve(c4, v4, DataLoader.get_spell(LASH).duplicate(true), true, {}, [], 1)
	check.call(not ActorProjectionRules.cast_error(c4, DataLoader.get_spell(LASH)).is_empty() and int(c4.spell_slots.get("1", 0)) == 1 and TetherRules.held(c4).size() == 1, "045 RT4 a full-capacity cast refuses before the slot is spent")
	# RT5: tampered tether saves are refused.
	var dto := c4.to_dict()
	var bad_dc := dto.duplicate(true)
	for s in bad_dc.tethers: bad_dc.tethers[s].dc = 99
	var no_conc := dto.duplicate(true)
	no_conc["spell_concentration"] = {}
	no_conc["concentrating_on"] = {}
	var self_bind := dto.duplicate(true)
	for s in self_bind.tethers: self_bind.tethers[s].victim_id = c4.character_id
	check.call(TetherRules.saved_error(dto).is_empty() and not TetherRules.saved_error(bad_dc).is_empty() and not TetherRules.saved_error(no_conc).is_empty() and not TetherRules.saved_error(self_bind).is_empty(), "045 RT5 tampered tether DC, missing concentration and self-binding saves are refused")
	# RT6: legacy save without tethers or active time validates.
	var l := actor("b045_rt6")
	var ldto := l.to_dict()
	ldto.erase("tethers")
	check.call(TetherRules.saved_error(ldto).is_empty() and InventoryCopies.saved_error(ldto.inventory).is_empty(), "045 RT6 a legacy save without tethers validates")
