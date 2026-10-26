class_name Batch074Checks
extends RefCounted
## Batch 074 (S-066): work-site location and helper proximity. The authored
## work "site" records the exact start cell; joining refuses a helper who is
## not within within_feet (or whose location is unknown) before anything
## changes; every advance checks every participant; pause/interrupt apply at
## the actual boundary, including inside one long clock jump.

const LOOM := "fixture:b074_site_loom"
const KILN := "fixture:b074_site_kiln"
const ROOM := "b074-room"

static func load_fixtures() -> void:
	Batch046Checks.load_fixtures()
	if not DataLoader.get_item(LOOM).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_074/items/work_site.json", "item")

static func _room(people: Dictionary) -> void:
	var positions := {}
	for id in people: positions[id] = people[id].duplicate()
	GameManager.active_dungeon_state = {"dungeon_id": "b074-dungeon", "local_rooms": {ROOM: {"id": ROOM, "party_positions": positions}}, "local_room_id": ROOM}

static func _place(id: String, at: Array) -> void:
	GameManager.active_dungeon_state.local_rooms[ROOM].party_positions[id] = at.duplicate()

static func run(check: Callable) -> void:
	load_fixtures()
	var prior_dungeon: Dictionary = GameManager.active_dungeon_state
	check.call(DataLoader.get_load_errors().is_empty() and WorkRules.policy_error(DataLoader.get_item(LOOM).work).is_empty() and WorkRules.policy_error(DataLoader.get_item(KILN).work).is_empty(), "074 S-066 neutral site work fixtures load: %s" % str(DataLoader.get_load_errors()))
	_validation(check)
	_join(check)
	_jump(check)
	_interrupt(check)
	_saves(check)
	GameManager.active_dungeon_state = prior_dungeon

static func _validation(check: Callable) -> void:
	var p: Dictionary = DataLoader.get_item(LOOM).work.duplicate(true)
	var bad := 0
	var mutations := [func(x): x.site = [], func(x): x.site.within_feet = 7, func(x): x.site.within_feet = -5, func(x): x.site.erase("within_feet"),
		func(x): x.site.on_away = "end", func(x): x.site.erase("on_away"), func(x): x.site.erase("away_limit_seconds"), func(x): x.site.away_limit_seconds = 0,
		func(x): x.site["radius"] = 5, func(x): x.site = {"within_feet": 5, "on_away": "interrupt", "away_limit_seconds": 60}]
	for mutate in mutations:
		var x := p.duplicate(true)
		mutate.call(x)
		if not WorkRules.policy_error(x).is_empty(): bad += 1
	check.call(bad == mutations.size(), "074 S-066 loader refuses a non-object site, odd/negative/missing reach, unknown or missing on_away, missing/zero pause limit, extra fields and a limit on interrupt (%d/%d)" % [bad, mutations.size()])

static func _join(check: Callable) -> void:
	var a := Batch046Checks.actor("b074_lead")
	var h := Batch046Checks.actor("b074_helper")
	Batch046Checks._party([a, h])
	var loom := Batch046Checks.add(a, LOOM)
	GameManager.active_dungeon_state = {}
	var unknown := WorkRules.start(a, loom)
	check.call(not unknown.success and not WorkRules.is_active(a.inventory.get_instance(loom)), "074 S-066 site work with no represented location refuses to start, nothing changed")
	_room({a.character_id: [0, 0], h.character_id: [3, 0]})
	var started := WorkRules.start(a, loom)
	var rec := a.inventory.get_instance(loom)
	check.call(started.success and rec.state.work_site == {"dungeon_id": "b074-dungeon", "room_id": ROOM, "position": [0, 0]}, "074 S-066 starting records the exact represented start cell as the site")
	var before := a.inventory.get_instance(loom)
	var far := WorkRules.join(h, a, loom)
	check.call(not far.success and str(far.message).contains("15 feet") and a.inventory.get_instance(loom) == before, "074 S-066 a helper 15 feet away is refused at the join with nothing changed (%s)" % far.message)
	_place(h.character_id, [2, 0])
	var implied := 0
	for cond in ["stunned", "paralyzed", "unconscious", "petrified"]:
		h.add_condition(cond, -1)
		var r := WorkRules.join(h, a, loom)
		if not r.success and str(r.message).contains("incapacitated") and a.inventory.get_instance(loom) == before: implied += 1
		h.remove_condition(cond)
	check.call(implied == 4, "Review 074 R1: a Stunned/Paralyzed/Unconscious/Petrified helper in range is refused as incapacitated (%d/4)" % implied)
	var near := WorkRules.join(h, a, loom)
	check.call(near.success and a.inventory.get_instance(loom).state.work_participants == [a.character_id, h.character_id], "074 S-066 a helper exactly 10 feet from the site joins")
	var h2 := Batch046Checks.actor("b074_elsewhere")
	Batch046Checks._party([h2])
	var nowhere := WorkRules.join(h2, a, loom)
	check.call(not nowhere.success and str(nowhere.message).contains("no represented location"), "074 S-066 an unknown helper location cannot satisfy proximity")
	Batch046Checks._leave([a, h, h2])

static func _jump(check: Callable) -> void:
	var a := Batch046Checks.actor("b074_jl")
	var h := Batch046Checks.actor("b074_jh")
	Batch046Checks._party([a, h])
	_room({a.character_id: [0, 0], h.character_id: [1, 0]})
	var loom := Batch046Checks.add(a, LOOM)
	WorkRules.start(a, loom)
	WorkRules.join(h, a, loom)
	WorkRules.settle(a, 3600, 3600)
	check.call(WorkRules.progress(a.inventory.get_instance(loom)) == 3600, "074 S-066 everyone at the site: time accrues")
	_place(h.character_id, [5, 0])
	var paused := WorkRules.settle(a, 600, 4200)
	var rec := a.inventory.get_instance(loom)
	check.call(paused.size() == 1 and paused[0].get("paused", false) and int(rec.state.work_away_since) == 3600 and WorkRules.progress(rec) == 3600 and WorkRules.is_active(rec), "074 S-066 a helper moving away pauses at the span start; no away time accrues")
	_place(h.character_id, [1, 0])
	var back := WorkRules.settle(a, 600, 4800)
	check.call(back.size() == 1 and back[0].get("resumed", false) and WorkRules.progress(a.inventory.get_instance(loom)) == 3600 and not a.inventory.get_instance(loom).state.has("work_away_since"), "074 S-066 the span in which the helper returns is still away time")
	WorkRules.settle(a, 1200, 6000)
	check.call(WorkRules.progress(a.inventory.get_instance(loom)) == 4800, "074 S-066 work resumes after everyone is back (%d)" % WorkRules.progress(a.inventory.get_instance(loom)))
	_place(a.character_id, [4, 0]) # The worker himself leaves the site.
	WorkRules.settle(a, 60, 6060)
	var jump := WorkRules.settle(a, 2 * 86400, 6060 + 2 * 86400)
	rec = a.inventory.get_instance(loom)
	check.call(jump.size() == 1 and jump[0].get("interrupted", false) and int(jump[0].at) == 6000 + 3601 and int(jump[0].lost_seconds) == 4800 and WorkRules.progress(rec) == 0 and not WorkRules.is_active(rec) and not rec.state.has("work_site"), "074 S-066 a two-day jump applies the reset policy just past away_since + limit (at=%s), crediting none of the jump" % str(jump[0].get("at", "?") if not jump.is_empty() else "none"))
	# Long jump with everyone present: the daily allowance still bounds it.
	_place(a.character_id, [0, 0])
	WorkRules.start(a, loom)
	WorkRules.join(h, a, loom)
	var t0 := 3 * 86400
	WorkRules.settle(a, 86400 + 43200, t0 + 86400 + 43200)
	check.call(WorkRules.progress(a.inventory.get_instance(loom)) == 86400 + 43200, "074 S-066 a present long jump accrues day by day (%d)" % WorkRules.progress(a.inventory.get_instance(loom)))
	Batch046Checks._leave([a, h])

static func _interrupt(check: Callable) -> void:
	var a := Batch046Checks.actor("b074_kiln")
	Batch046Checks._party([a])
	_room({a.character_id: [0, 0]})
	var kiln := Batch046Checks.add(a, KILN)
	WorkRules.start(a, kiln)
	WorkRules.settle(a, 3600, 3600)
	_place(a.character_id, [1, 0])
	var cut := WorkRules.settle(a, 86400, 90000)
	var rec := a.inventory.get_instance(kiln)
	check.call(cut.size() == 1 and int(cut[0].at) == 3600 and WorkRules.progress(rec) == 3600 and not WorkRules.is_active(rec), "074 S-066 interrupt policy ends at the first away span (keep keeps 3600)")
	_room({a.character_id: [0, 0]})
	WorkRules.start(a, kiln)
	GameManager.active_dungeon_state.local_room_id = "" # Leaving the room: location unknown.
	var gone := WorkRules.settle(a, 60, 90060)
	check.call(gone.size() == 1 and gone[0].get("interrupted", false) and str(gone[0].reason).contains("no represented location"), "074 S-066 leaving the represented room interrupts site work")
	# Legacy work without a site is not location-bound.
	GameManager.active_dungeon_state = {}
	var tome := Batch046Checks.add(a, Batch046Checks.TOME)
	var legacy := WorkRules.start(a, tome)
	WorkRules.settle(a, 600, 90660)
	check.call(legacy.success and WorkRules.progress(a.inventory.get_instance(tome)) == 600, "074 S-066 legacy site-less work still accrues anywhere")
	WorkRules.stop(a, tome)
	Batch046Checks._leave([a])

static func _saves(check: Callable) -> void:
	var a := Batch046Checks.actor("b074_sl")
	var h := Batch046Checks.actor("b074_sh")
	Batch046Checks._party([a, h])
	_room({a.character_id: [0, 0], h.character_id: [1, 0]})
	var loom := Batch046Checks.add(a, LOOM)
	WorkRules.start(a, loom)
	WorkRules.join(h, a, loom)
	_place(h.character_id, [6, 0])
	WorkRules.settle(a, 600, 600)
	var dto: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	var rec: Dictionary = dto.inventory.copies.records[loom]
	check.call(InventoryCopies.record_state_error(rec).is_empty() and int(rec.state.work_away_since) == 0, "074 S-066 JSON-text DTO keeps the site and away time (%s)" % InventoryCopies.record_state_error(rec))
	var back := Character.new()
	back.from_dict(dto)
	PartyManager.characters[a.character_id] = back
	var lapse := WorkRules.settle(back, 7200, 7800)
	check.call(lapse.size() == 1 and int(lapse[0].at) == 3601 and WorkRules.progress(back.inventory.get_instance(loom)) == 0, "074 S-066 reloaded away time lapses just past the original away_since + limit")
	var defects := [
		func(s): s.erase("work_site"),
		func(s): s.work_site = {"dungeon_id": "d", "room_id": "", "position": [0, 0]},
		func(s): s.work_site.position = [0.5, 0],
		func(s): s.work_site["extra"] = 1,
		func(s): s.work_away_since = -1,
		func(s): s.work_away_since = "soon",
	]
	var refused := 0
	for mutate in defects:
		var r: Dictionary = rec.duplicate(true)
		mutate.call(r.state)
		if not InventoryCopies.record_state_error(r).is_empty(): refused += 1
	var interrupting := rec.duplicate(true)
	interrupting.definition_id = KILN
	interrupting.state.work_participants = [a.character_id]
	if not InventoryCopies.record_state_error(interrupting).is_empty(): refused += 1
	var tome := rec.duplicate(true)
	tome.definition_id = Batch046Checks.TOME
	tome.state.erase("work_away_since")
	if not InventoryCopies.record_state_error(tome).is_empty(): refused += 1
	check.call(refused == defects.size() + 2, "074 S-066 saved site work refuses a missing/blank/fractional/extra site, bad away time, away time under interrupt and a site on site-less work (%d/%d)" % [refused, defects.size() + 2])
	var legacy := {"instance_id": "legacy", "definition_id": Batch046Checks.TOME, "state": {"work_active": true, "work_participants": [a.character_id], "work_progress_seconds": 60}}
	check.call(InventoryCopies.record_state_error(legacy).is_empty(), "074 S-066 a legacy site-less active work record still loads")
	Batch046Checks._leave([a, h])
