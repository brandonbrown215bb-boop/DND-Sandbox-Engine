class_name Batch046Checks
extends RefCounted

const TOME := "fixture:b046_study_tome"
const FRAME := "fixture:b046_ritual_frame"
const SNARE := "fixture:b046_snare"

static func load_fixtures() -> void:
	Batch045Checks.load_fixtures()
	if not DataLoader.get_item(TOME).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_046/items/work.json", "item")
	DataLoader._load_json_file("res://data/fixtures/batch_046/spells/snare.json", "spell")

static func actor(id: String) -> Character:
	return Batch031Checks._character(id, 40)

static func add(a: Character, definition: String) -> String:
	return Batch041Checks.add_copy(a, definition)

## Real shared resolver cast of the snare; retries seeds until the save fails (slot refilled each try).
static func snare(caster: Character, target) -> Dictionary:
	var r := {}
	for i in 30:
		seed(46000 + i)
		caster.spell_slots = {"1": 1}
		r = SpellResolver.resolve(caster, target, DataLoader.get_spell(SNARE).duplicate(true), true, {}, [], 1)
		if r.get("tether", {}).get("bound", false):
			caster.concentrating_on = {"spell_id": SNARE, "effect_source": str(r.tether.source_id), "targets": [target]}
			return r
		if r.get("refused", false): return r
		SpellEffects.remove(target, str(r.get("effect_cast", {}).get("source_id", "")))
	return r

## Participants must be party members; register only these fixture actors and remove them after.
static func _party(people: Array) -> void:
	for c in people: PartyManager.characters[c.character_id] = c

static func _leave(people: Array) -> void:
	for c in people: PartyManager.characters.erase(c.character_id)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "046 neutral work items and snare spell load: %s" % str(DataLoader.get_load_errors()))
	_work_validation(check)
	_work(check)
	_work_participants(check)
	_work_saves(check)
	_rescue_validation(check)
	_rescue(check)
	_rescue_saves(check)

static func _work_validation(check: Callable) -> void:
	var p: Dictionary = DataLoader.get_item(FRAME).work.duplicate(true)
	check.call(WorkRules.policy_error(p).is_empty() and WorkRules.policy_error(DataLoader.get_item(TOME).work).is_empty(), "046 S-066 declared work policies validate")
	var bad := 0
	for mutate in [func(x): x.required_seconds = 0, func(x): x.daily_seconds = 90000, func(x): x.participants = 7, func(x): x.on_interrupt = "pause", func(x): x.concentration = "yes", func(x): x["refund"] = true, func(x): x.erase("on_interrupt")]:
		var x := p.duplicate(true)
		mutate.call(x)
		if not WorkRules.policy_error(x).is_empty(): bad += 1
	check.call(bad == 7, "046 S-066 loader refuses zero, over-day, too many, unknown-policy, non-bool, extra and missing fields (%d/7)" % bad)

static func _work(check: Callable) -> void:
	var a := actor("b046_scholar")
	_party([a])
	var tome := add(a, TOME)
	var other := actor("b046_stranger")
	var before := a.inventory.get_instance(tome)
	var refused := WorkRules.start(other, tome)
	check.call(not refused.success and a.inventory.get_instance(tome) == before, "046 S-066 starting work on a copy not at hand refuses with nothing changed")
	var started := WorkRules.start(a, tome)
	WorkRules.settle(a, 3600, 3600)
	check.call(started.success and WorkRules.progress(a.inventory.get_instance(tome)) == 3600, "046 S-066 eligible elapsed time accrues on the exact copy")
	WorkRules.settle(a, 86400 - 3600 + 3600, 86400 + 3600)
	check.call(WorkRules.progress(a.inventory.get_instance(tome)) == 28800 + 3600 and WorkRules.is_active(a.inventory.get_instance(tome)), "046 S-066 at most the daily allowance accrues per campaign day; the rest is rest (%d)" % WorkRules.progress(a.inventory.get_instance(tome)))
	a.concentrating_on = {"spell_id": "bless", "effect_source": "fixture:b046_focus", "targets": [a]}
	var cut := WorkRules.settle(a, 600, 86400 + 4200)
	check.call(cut.size() == 1 and cut[0].get("interrupted", false) and not WorkRules.is_active(a.inventory.get_instance(tome)) and WorkRules.progress(a.inventory.get_instance(tome)) == 32400, "046 S-066 concentration breaks attention-bound work; the keep policy keeps progress")
	check.call(not WorkRules.start(a, tome).success, "046 S-066 work needing full attention cannot start while concentrating")
	a.concentrating_on = {}
	WorkRules.start(a, tome)
	var done := WorkRules.settle(a, 7200, 2 * 86400 + 7200)
	check.call(done.size() == 1 and done[0].get("complete", false) and WorkRules.progress(a.inventory.get_instance(tome)) == 36000 and not WorkRules.is_active(a.inventory.get_instance(tome)) and not WorkRules.start(a, tome).success, "046 S-066 work completes exactly at its requirement and stops accruing")
	var tome2 := add(a, TOME)
	var bag := add(a, Batch043Checks.SATCHEL)
	WorkRules.start(a, tome2)
	var stow := ContainerRules.put(a.inventory, bag, tome2, "main")
	check.call(not stow.get("success", false) and WorkRules.is_active(a.inventory.get_instance(tome2)), "046 S-066 an active work copy cannot be stowed away mid-work")
	WorkRules.settle(a, 600, 3 * 86400 + 600)
	var stop := WorkRules.stop(a, tome2)
	check.call(stop.success and WorkRules.progress(a.inventory.get_instance(tome2)) == 600 and not WorkRules.is_active(a.inventory.get_instance(tome2)), "046 S-066 leaving the work keeps progress under the keep policy")
	WorkRules.start(a, tome2)
	var combat := WorkRules.interrupt_all(a, "combat")
	check.call(combat.size() == 1 and WorkRules.progress(a.inventory.get_instance(tome2)) == 600 and not WorkRules.is_active(a.inventory.get_instance(tome2)), "046 S-066 combat interrupts work through its own policy")
	_leave([a])

static func _work_participants(check: Callable) -> void:
	var a := actor("b046_lead")
	var h := actor("b046_helper")
	_party([a, h])
	var frame := add(a, FRAME)
	WorkRules.start(a, frame)
	WorkRules.settle(a, 600, 600)
	check.call(WorkRules.progress(a.inventory.get_instance(frame)) == 0 and WorkRules.is_active(a.inventory.get_instance(frame)), "046 S-066 group work waits (nothing accrues, nothing lost) until enough participants join")
	var joined := WorkRules.join(h, a, frame)
	WorkRules.settle(a, 1200, 1800)
	check.call(joined.success and WorkRules.progress(a.inventory.get_instance(frame)) == 1200 and not WorkRules.join(h, a, frame).success, "046 S-066 with its participants the work accrues; joining twice refuses")
	h.current_hp = 0
	h.is_alive = false
	var lost := WorkRules.settle(a, 600, 2400)
	check.call(lost.size() == 1 and int(lost[0].lost_seconds) == 1200 and WorkRules.progress(a.inventory.get_instance(frame)) == 0 and not WorkRules.is_active(a.inventory.get_instance(frame)), "046 S-066 a participant dropping out interrupts; the reset policy loses only this work's progress")
	h.current_hp = 40
	h.is_alive = true
	WorkRules.start(a, frame)
	WorkRules.join(h, a, frame)
	WorkRules.settle(a, 600, 3000)
	var b := actor("b046_receiver")
	_party([b])
	var record := a.inventory.get_instance(frame)
	var moved := {"success": a.inventory.transfer_instance(frame, b.inventory), "message": "transfer_instance"}
	var lost_hands := WorkRules.settle(b, 600, 3600)
	var held := b.inventory.get_instance(frame)
	check.call(not record.is_empty() and moved.get("success", false) and lost_hands.is_empty() and not WorkRules.is_active(held) and WorkRules.progress(held) == 0, "046 S-066 changing hands settles the reset policy immediately, without waiting for time to advance")
	_leave([a, h, b])

static func _work_saves(check: Callable) -> void:
	var a := actor("b046_save")
	_party([a])
	var tome := add(a, TOME)
	WorkRules.start(a, tome)
	WorkRules.settle(a, 1800, 1800)
	var dto := a.to_dict()
	var rec: Dictionary = dto.inventory.copies.records[tome]
	check.call(InventoryCopies.record_state_error(rec).is_empty() and InventoryCopies.saved_error(dto.inventory).is_empty(), "046 S-066 saved work passes record_state_error (%s)" % InventoryCopies.record_state_error(rec))
	var back := Character.new()
	back.from_dict(dto)
	PartyManager.characters[a.character_id] = back
	WorkRules.settle(back, 600, 2400)
	check.call(WorkRules.progress(back.inventory.get_instance(tome)) == 2400 and WorkRules.is_active(back.inventory.get_instance(tome)), "046 S-066 reload keeps progress, participants and the day ledger")
	var defects := [
		func(r): r.state.work_progress_seconds = 36001,
		func(r): r.state.work_active = "yes",
		func(r): r.state.erase("work_participants"),
		func(r): r.state.work_participants = ["x", "x"],
		func(r): r.state.work_day_seconds = 30000,
		func(r): r.definition_id = "dagger",
	]
	var refused := 0
	for mutate in defects:
		var bad: Dictionary = rec.duplicate(true)
		mutate.call(bad)
		if not WorkRules.record_error(bad).is_empty(): refused += 1
	check.call(refused == 6, "046 S-066 saved work refuses overdone, malformed, orphaned, duplicated, over-day and undeclared records (%d/6)" % refused)
	WorkRules.stop(back, tome)
	var bag := add(back, Batch043Checks.SATCHEL)
	var put := ContainerRules.put(back.inventory, bag, tome, "main")
	var nested := back.to_dict()
	if put.get("success", false): nested.inventory.copies.records[bag].state.contents.main[0].state.work_progress_seconds = 99999
	check.call(put.get("success", false) and not ContainerRules.saved_error(nested).is_empty(), "046 S-066 a contained copy's work progress goes through record_state_error too")
	_leave([a])

static func _rescue_validation(check: Callable) -> void:
	var e: Dictionary = DataLoader.get_spell(SNARE).effects[0].duplicate(true)
	check.call(TetherRules.effect_error(e).is_empty() and SharedSpell.content_error(DataLoader.get_spell(SNARE)).is_empty(), "046 S-169 declared rescue and tether hp validate (%s)" % SharedSpell.content_error(DataLoader.get_spell(SNARE)))
	var bad := 0
	for mutate in [func(x): x.rescue = ["WIS"], func(x): x.rescue = [], func(x): x.hp = 0, func(x): x.hp = 2.5]:
		var x := e.duplicate(true)
		mutate.call(x)
		if not TetherRules.effect_error(x).is_empty(): bad += 1
	check.call(bad == 4, "046 S-169 loader refuses bad rescue abilities and tether hp (%d/4)" % bad)

static func _rescue(check: Callable) -> void:
	var c := actor("b046_captor")
	var v := actor("b046_victim")
	var h := actor("b046_rescuer")
	v.ability_scores.from_dict({"STR": 8, "DEX": 8, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	var r := snare(c, v)
	var source := str(r.get("tether", {}).get("source_id", ""))
	v.add_condition("restrained", 10, "fixture:b046_other")
	check.call(r.get("tether", {}).get("bound", false) and int(c.tethers[source].hp) == 5, "046 S-169 a snare binds with its own tether hp")
	var own := TetherRules.rescue(c, v, [c], "check")
	var self_help := TetherRules.rescue(v, v, [c], "check")
	check.call(not own.attempted and not self_help.attempted and not own.has("seconds") and c.tethers.has(source), "046 S-169 the captor and the victim cannot rescue; refusal spends nothing")
	var lash_c := actor("b046_lash_c")
	var lr := Batch045Checks.lash(lash_c, actor("b046_lash_v"))
	var lv: Variant = lr.get("tether", {}).get("victim_id", "")
	var lash_victim := actor("b046_lash_v2")
	var lr2 := Batch045Checks.lash(actor("b046_lash_c2"), lash_victim)
	check.call(lv != "" and lr2.get("tether", {}).get("bound", false) and not TetherRules.rescue_error(h, lash_victim, [], "check").is_empty() and TetherRules.rescue_error(h, v, [c], "check").is_empty(), "046 S-169 only a tether that declares rescue can be pulled free from outside")
	var pulled := {}
	for i in 40:
		seed(46500 + i)
		pulled = TetherRules.rescue(h, v, [c], "check")
		if pulled.get("success", false): break
	check.call(pulled.get("success", false) and pulled.ability == "STR" and not c.tethers.has(source) and not TetherRules.has_source(v, source) and v.has_condition("restrained") and TetherRules.has_source(v, "fixture:b046_other") and c.concentrating_on.is_empty(), "046 S-169 a rescue check ends only that tether (and its concentration); the other restraint stays")
	var c2 := actor("b046_captor_two")
	var r2 := snare(c2, v)
	var s2 := str(r2.get("tether", {}).get("source_id", ""))
	h.inventory.unequip(Inventory.Slot.WEAPON)
	var unarmed := TetherRules.rescue_error(h, v, [c2], "strike")
	h.inventory.add_item("longsword")
	h.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	var weapon := h.inventory.get_weapon()
	var hits := 0
	var last := {}
	while c2.tethers.has(s2) and hits < 10:
		last = TetherRules.rescue(h, v, [c2], "strike")
		hits += 1
	check.call(r2.get("tether", {}).get("bound", false) and weapon == "longsword" and not unarmed.is_empty() and not c2.tethers.has(s2) and last.get("success", false) and v.has_condition("restrained") and TetherRules.has_source(v, "fixture:b046_other"), "046 S-169 striking routes damage to the tether's own hp until it snaps; only it ends (weapon=%s hits=%d)" % [weapon, hits])
	var m := {"id": "b046_gob", "name": "Goblin", "is_alive": true, "ability_scores": {"STR": 8, "DEX": 14}, "skills": {}, "conditions": {}, "condition_sources": {}, "saves": {}, "attacks": DataLoader.get_monster("goblin").get("attacks", [])}
	var friend := {"id": "b046_gob2", "name": "Goblin", "is_alive": true, "ability_scores": {"STR": 8, "DEX": 14}, "skills": {}, "attacks": DataLoader.get_monster("goblin").get("attacks", [])}
	var c3 := actor("b046_captor_three")
	var r3 := snare(c3, m)
	var s3 := str(r3.get("tether", {}).get("source_id", ""))
	var cut := TetherRules.rescue(friend, m, [c3], "strike")
	check.call(r3.get("tether", {}).get("bound", false) and cut.attempted and int(cut.damage) >= 1 and (int(cut.hp_left) == 5 - int(cut.damage) or not c3.tethers.has(s3)), "046 S-169 a monster ally strikes with its own melee attack at the tether (%s)" % str(cut.get("message", "")))
	if c3.tethers.has(s3): c3.tethers[s3]["hp"] = 5
	m["is_alive"] = false
	var gone := TetherRules.enforce_range([c3], {c3.character_id: Vector2i.ZERO, "b046_gob": Vector2i(1, 0)}, {"b046_gob": m})
	check.call(gone == [s3] and not c3.tethers.has(s3) and c3.concentrating_on.is_empty(), "046 S-169 a destroyed victim releases only its own relation and its concentration")

static func _rescue_saves(check: Callable) -> void:
	var c := actor("b046_tsave")
	var v := actor("b046_tsave_v")
	v.ability_scores.from_dict({"STR": 8, "DEX": 8, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10})
	var r := snare(c, v)
	var source := str(r.get("tether", {}).get("source_id", ""))
	if c.tethers.has(source): c.tethers[source]["hp"] = 3
	var dto := c.to_dict()
	var back := Character.new()
	back.from_dict(dto)
	check.call(TetherRules.saved_error(dto).is_empty() and int(back.tethers.get(source, {}).get("hp", 0)) == 3, "046 S-169 a damaged tether's remaining hp saves and reloads (%s)" % TetherRules.saved_error(dto))
	var over := dto.duplicate(true)
	over.tethers[source].hp = 6
	var missing := dto.duplicate(true)
	missing.tethers[source].erase("hp")
	check.call(not TetherRules.saved_error(over).is_empty() and not TetherRules.saved_error(missing).is_empty(), "046 S-169 saved tether hp above its spell or missing is refused")
