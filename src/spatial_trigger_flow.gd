class_name SpatialTriggerFlow
extends RefCounted

const SLOT := "spatial_triggers"

class Gate extends RefCounted:
	signal released
	var calls := 0
	func wait_for_resume(_actor, _damage) -> void:
		calls += 1
		await released

static func fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/spatial_triggers/spells.json", "spell")
	for id in DataLoader.spells:
		if str(id).begins_with("fixture:spatial_") and id not in DataLoader.classes.wizard.spell_list_ids: DataLoader.classes.wizard.spell_list_ids.append(id)

static func declaration(name: String) -> Dictionary:
	return DataLoader.get_spell("fixture:spatial_" + name).end_aftermath[0].children[0].duplicate(true)

static func logic(check: Callable) -> void:
	fixtures()
	var area := declaration("threshold")
	area["caster_id"] = "owner"
	var clocks := {"turn":"t1", "actors":{"actor":"a1", "owner":"o1"}}
	var pending := SpatialTriggerRules.claim(area, "actor", ["entry"], "move1", clocks)
	check.call(pending.size() == 1 and not SpatialTriggerRules.state_error(area).is_empty(), "S184 a reserved delivery blocks checkpoint serialization")
	check.call(SpatialTriggerRules.settle(pending[0]) and not SpatialTriggerRules.settle(pending[0]) and SpatialTriggerRules.state_error(area).is_empty(), "S184 one delivery settles once and completed state validates")
	clocks.turn = "t2"
	check.call(SpatialTriggerRules.claim(area, "actor", ["entry"], "move1", clocks).is_empty(), "S184 an old movement callback cannot borrow a later turn reset")
	var malformed := area.duplicate(true)
	malformed.trigger_limits.values()[0].count = 2
	check.call(not SpatialTriggerRules.state_error(malformed).is_empty(), "S184 saved limits cannot exceed the authored policy")
	var invalid := declaration("threshold")
	invalid.trigger_policies[0].events = ["appearance"]
	check.call(not SpatialTriggerRules.policies_error(invalid.trigger_policies).is_empty(), "S184 unsupported appearance policies refuse instead of silently claiming support")
	var state := room([])
	state.area_actor_turns = []
	check.call(not DungeonPersistence.local_error(state).is_empty(), "S184 malformed actor clock refuses before load")
	state.erase("area_actor_turns")
	state.area_encounter_serial = -1
	check.call(not DungeonPersistence.local_error(state).is_empty(), "S184 negative encounter epoch refuses before load")
	var victim := {"id":"other", "current_hp":20,"max_hp":20,"is_alive":true}
	var source := declaration("every_entry")
	source.merge({"id":"expiring","caster_id":"owner","spell_id":"neutral","hazard_kind":"trigger_damage","plane":"material","expires_at_seconds":0}, true)
	state.areas = [source]
	var reserved := SpatialTriggerRules.claim(source, "other", ["entry"], "before-expiry", clocks)
	LocalRoomAreas.expire(state, 1)
	check.call(LocalRoomAreas.resolve_aftermath_entry(reserved[0], victim).is_empty() and victim.current_hp == 20 and state.areas.is_empty(), "S184 expiry invalidates a reserved source without applying its queued effect")
	var previous := GameManager.transition_context
	state = room([])
	GameManager.transition_context = {"local_room":state}
	var actor_area := declaration("actor_clock")
	var source_area := declaration("source_clock")
	for declared in [actor_area, source_area]:
		declared["caster_id"] = "owner"
		var first := SpatialTriggerRules.claim(declared, "visitor", ["entry"], "room-entry", LocalRoomAreas.turn_clocks(state))
		SpatialTriggerRules.settle(first[0])
	var zones := CombatSpellZones.new()
	zones.tracker = InitiativeTracker.new()
	zones.tracker.add_combatant("owner", "Owner", true, null, 20, 10)
	check.call(SpatialTriggerRules.claim(actor_area, "visitor", ["entry"], "combat-entry", zones._trigger_clocks()).is_empty() and SpatialTriggerRules.claim(source_area, "visitor", ["entry"], "combat-entry", zones._trigger_clocks()).is_empty(), "S184 room-to-combat transition preserves affected-actor and source-owner intervals before either actor starts a turn")
	zones.begin_trigger_turn("owner")
	var source_next := SpatialTriggerRules.claim(source_area, "visitor", ["entry"], "owner-started", zones._trigger_clocks())
	check.call(source_next.size() == 1 and SpatialTriggerRules.claim(actor_area, "visitor", ["entry"], "owner-started", zones._trigger_clocks()).is_empty(), "S184 actual represented owner start advances only its durable actor clock")
	SpatialTriggerRules.settle(source_next[0])
	check.call(SpatialTriggerRules.claim(source_area, "visitor", ["entry"], "back-in-room", LocalRoomAreas.turn_clocks(state)).is_empty(), "S184 combat-to-room transition preserves the already spent owner interval")
	GameManager.transition_context = previous
	_room_concentration(check)

static func concentrate(actor: Character) -> String:
	var cast := SpellEffects.begin_cast(actor, DataLoader.get_spell("bless"))
	SpellEffects.grant(actor, cast, "blessed")
	actor.concentrating_on = {"spell_id":"bless", "effect_source":cast.source_id, "targets":[]}
	return str(cast.source_id)

static func _room_concentration(check: Callable) -> void:
	var actor := Character.new()
	actor.initialize("Hazard concentration", "human", "wizard", AbilityScores.new())
	actor.character_id = "fixture:hazard_concentration"
	actor.max_hp = 100; actor.current_hp = 100
	actor.add_modifier("roll", "save:CON", -1000, 100)
	var state := room([actor])
	var previous := GameManager.transition_context
	GameManager.transition_context = {"local_room":state}
	var grid := HexGrid.new()
	for cell in state.cells:
		var tile := HexTile.new()
		tile.coord = LocalRoomRules.coord(cell)
		grid.tiles[tile.coord] = tile
	var child := declaration("every_entry")
	var details := {"id":"fixture:concentration_hazard", "spell_id":"neutral", "hazard_kind":"trigger_damage", "plane":"material", "amount":30, "damage_type":"fire", "trigger_policies":child.trigger_policies}
	LocalRoomAreas.add(state, "neutral", actor.character_id, Vector2i.ZERO, 0, 600, 100, details)
	state.party_positions[actor.character_id] = [-1,0]
	actor.temp_hp = 40
	var source := concentrate(actor)
	var moved := LocalRoomRules.move(state, actor, Vector2i.ZERO, grid, "walk", [actor])
	check.call(moved.success and actor.current_hp == 100 and actor.temp_hp == 10 and actor.concentrating_on.is_empty() and not actor.spell_effects.has(source) and not actor.has_condition("blessed"), "S184 room movement checks concentration through Temporary HP and removes the exact failed source")
	var area: Dictionary = state.areas[0]
	area.trigger_policies = [{"id":"turn", "events":["end_turn"], "boundary":"event", "limit":1}]
	actor.feature_uses["damage_resistances"] = ["fire"]
	actor.temp_hp = 30
	source = concentrate(actor)
	var ended := LocalRoomRules.end_local_turn(state, actor)
	check.call(ended.success and actor.temp_hp == 15 and actor.concentrating_on.is_empty() and not actor.spell_effects.has(source), "S184 room End Turn checks concentration on resisted damage absorbed by Temporary HP")
	actor.feature_uses["damage_immunities"] = ["fire"]
	source = concentrate(actor)
	LocalRoomRules.end_local_turn(state, actor)
	check.call(actor.temp_hp == 15 and actor.spell_effects.has(source) and not actor.concentrating_on.is_empty(), "S184 immune room hazard causes no concentration check or source loss")
	SpellEffects.end_concentration(actor, [])
	grid.free()
	GameManager.transition_context = previous

static func room(party: Array) -> Dictionary:
	var cells: Array = []
	for x in range(-4, 7):
		for y in range(-3, 4): cells.append([x, y])
	return LocalRoomRules.create({"id":"spatial-proof", "name":"Spatial proof", "plane":"material", "cells":cells, "walls":[], "exits":[[-4,0]], "party_spawns":[[0,0],[-2,2]], "monster_spawns":[[6,0]], "objects":[], "encounter_monsters":[]}, party)

static func run(h: Node) -> void:
	h._enter_test("spatial_trigger_flow")
	h._setup_world()
	fixtures()
	h._assert(DataLoader.get_load_errors().is_empty(), "S184 neutral declarations load through production validation")
	var actor: Character = PlayerManager.get_player(0).character
	var caster: Character = PlayerManager.get_player(1).character
	var party: Array = [actor, caster]
	var state := room(party)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"local_room":state}
	var grid := HexGrid.new()
	for cell in state.cells:
		var tile := HexTile.new()
		tile.coord = LocalRoomRules.coord(cell)
		grid.tiles[tile.coord] = tile
	await room_paths(h, state, grid, actor, caster, party)
	grid.free()
	GameManager.transition_context = {"terrain":"plains", "monster_ids":["goblin"], "local_room":state}
	var combat: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.3)
	await combat_paths(h, combat, actor, caster)
	# A represented room's combat epoch and receipts must survive an allowed checkpoint.
	LocalRoomCombat.capture(combat.player_entities)
	h._teardown_scene(combat)
	await h.get_tree().process_frame
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id":"ruins_of_ashvale"}
	GameManager.active_dungeon_state.clear()
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	GameManager.active_dungeon_state["local_rooms"] = {"0":state}
	GameManager.active_dungeon_state["local_room_id"] = ""
	GameManager.remember_dungeon()
	GameManager.game_in_progress = true
	h._assert(DungeonPersistence.local_error(state).is_empty(), "S184 moved declared children and settled receipts validate: " + DungeonPersistence.local_error(state))
	h._assert(SaveManager.save_game(SLOT), "S184 allowed entrance checkpoint saves exact sources and trigger clocks: " + SaveManager.get_save_block_reason())
	var manifest := FileAccess.open("user://spatial_manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"pid":OS.get_process_id(), "epoch":state.get("area_encounter_serial", 0), "ids":state.areas.map(func(a): return a.id), "receipts":state.areas.map(func(a): return a.get("trigger_receipts", {}).size())}))
	manifest.close()
	h._teardown_scene(dungeon)
	h._exit_test()

static func create_child(h: Node, state: Dictionary, grid: HexGrid, actor: Character, caster: Character, party: Array, name: String) -> Dictionary:
	var id := "fixture:spatial_" + name
	if id not in caster.known_spells: caster.known_spells.append(id)
	if id not in caster.wizard_spellbook: caster.wizard_spellbook.append(id)
	caster.spell_slots["1"] = 2
	var cast := LocalRoomSharedSpells.cast(state, caster, id, actor, party, grid)
	var source := str(cast.get("effect_cast", {}).get("source_id", ""))
	SpellEffects.remove(actor, source, "dismissed")
	var choices := LocatedSourceEndRules.observe(state, party)
	if choices.is_empty(): h._assert(false, "S184 actual source end exposes declared area choice: " + JSON.stringify(cast)); return {}
	var request: Dictionary = choices[0]
	var answer := LocatedSourceEndRules.answer(state, str(request.invocation), name, true, party)
	var count: int = state.areas.size()
	var stale := LocatedSourceEndRules.answer(state, str(request.invocation), name, true, party)
	h._assert(cast.get("success", false) and answer.get("success", false) and not stale.get("success", false) and state.areas.size() == count and caster.spell_slots["1"] == 1, "S184 resumed area creation pays one slot and creates one exact child: " + name)
	return state.areas[-1]

static func room_paths(h: Node, state: Dictionary, grid: HexGrid, actor: Character, caster: Character, party: Array) -> void:
	var area := create_child(h, state, grid, actor, caster, party, "every_entry")
	if area.is_empty(): return
	state.party_positions[actor.character_id] = [-1,0]
	actor.current_hp = actor.max_hp
	var hp := actor.current_hp
	var first := LocalRoomRules.move(state, actor, Vector2i.ZERO, grid, "walk", party)
	var movement_id := "room:%s:move:%d" % [state.id, state.area_event_serial]
	var repeated := LocalRoomAreas.enter(state, actor.character_id, Vector2i(-1,0), Vector2i.ZERO, int(GameManager.campaign_elapsed_seconds), "material", movement_id)
	LocalRoomRules.resolve_area_entries(repeated, actor)
	h._assert(first.get("success", false) and actor.current_hp == hp - 3 and repeated.is_empty(), "S184 real room step settles once and repeated callback cannot replay an event")
	LocalRoomRules.move(state, actor, Vector2i(-1,0), grid, "walk", party)
	LocalRoomRules.move(state, actor, Vector2i.ZERO, grid, "walk", party)
	h._assert(actor.current_hp == hp - 6, "S184 event-scoped policy allows a genuinely new entry in the same turn")
	# Moving the same area over a stationary actor does not invent entry.
	var old_hp := actor.current_hp
	LocalRoomAreas.move_area(state, str(area.id), Vector2i(2,0), [{"id":actor.character_id,"position":Vector2i.ZERO,"plane":"material"}])
	LocalRoomRules.resolve_area_entries(LocalRoomAreas.move_area(state, str(area.id), Vector2i.ZERO, [{"id":actor.character_id,"position":Vector2i.ZERO,"plane":"material"}]), actor)
	h._assert(actor.current_hp == old_hp and area.created_center == [0,0], "S184 entry-only room policy ignores area movement and keeps immutable creation origin")
	LocalRoomAreas.move_area(state, str(area.id), Vector2i(3,0), [])
	state.party_positions[actor.character_id] = [0,0]
	var threshold := create_child(h, state, grid, actor, caster, party, "threshold")
	state.party_positions[actor.character_id] = [-1,0]
	actor.current_hp = actor.max_hp
	hp = actor.current_hp
	LocalRoomRules.move(state, actor, Vector2i.ZERO, grid, "walk", party)
	GameManager.advance_campaign_time(6)
	LocalRoomRules.move(state, actor, Vector2i(-1,0), grid, "walk", party)
	LocalRoomRules.move(state, actor, Vector2i.ZERO, grid, "walk", party)
	h._assert(actor.current_hp == hp - 3, "S184 campaign seconds and repeated room movement do not reset an explicit turn limit")
	var ended := LocalRoomRules.end_local_turn(state, actor)
	h._assert(ended.success and actor.current_hp == hp - 3, "S184 room end shares the declared entry/end limit before resetting the next turn")
	LocalRoomRules.move(state, actor, Vector2i(-1,0), grid, "walk", party)
	LocalRoomRules.move(state, actor, Vector2i.ZERO, grid, "walk", party)
	h._assert(actor.current_hp == hp - 6, "S184 actual room End Turn renews the next entry")
	# An independently declared area-movement trigger has its own source receipts.
	actor.current_hp = actor.max_hp
	var sweep := create_child(h, state, grid, actor, caster, party, "sweep")
	LocalRoomAreas.move_area(state, str(sweep.id), Vector2i(2,0), [])
	hp = actor.current_hp
	var deliveries := LocalRoomAreas.move_area(state, str(sweep.id), Vector2i.ZERO, [{"id":actor.character_id,"position":Vector2i.ZERO,"plane":"material"}])
	LocalRoomRules.resolve_area_entries(deliveries, actor)
	LocalRoomRules.resolve_area_entries(deliveries, actor)
	h._assert(actor.current_hp == hp - 3, "S184 declared area_enter damages a stationary actor once, including repeated delivery")
	LocalRoomAreas.move_area(state, str(sweep.id), Vector2i(4,0), [])
	LocalRoomAreas.move_area(state, str(threshold.id), Vector2i(5,0), [])
	# The room mover must stop on a lethal intermediate cell, not its requested destination.
	actor.current_hp = 1
	state.party_positions[actor.character_id] = [2,0]
	var interrupted := LocalRoomRules.move(state, actor, Vector2i(4,0), grid, "walk", party)
	h._assert(interrupted.success and state.party_positions[actor.character_id] == [3,0] and interrupted.movement_cost_feet == 5 and not actor.is_alive, "S184 room path stops at the lethal entered cell and charges only the actual step")
	actor.heal(actor.max_hp)
	state.party_positions[actor.character_id] = [-1,0]
	actor.heal(actor.max_hp)
	var saved_position: Array = state.party_positions[actor.character_id]
	state.party_positions[actor.character_id] = [0,0]
	var lifetime := create_child(h, state, grid, actor, caster, party, "lifetime")
	LocalRoomAreas.move_area(state, str(lifetime.id), Vector2i(6,3), [])
	state.party_positions[actor.character_id] = saved_position

static func prepare(h: Node, combat: CombatState, actor: Character, caster: Character) -> void:
	for key in combat.active_spell_zones.keys(): combat._remove_spell_zone(str(key))
	for entity in combat.player_entities:
		entity.hex_position = Vector2i.ZERO if entity.character == actor else Vector2i(0,2)
	for enemy in combat.monster_entities:
		enemy.hex_position = Vector2i(6,0)
		enemy.current_hp = 200; enemy.max_hp = 200; enemy.reaction_available = false
	actor.heal(actor.max_hp)
	caster.heal(caster.max_hp)
	h._p_focus(combat, actor)
	combat.remaining_speed = 6
	combat.pending_action_type = ""
	combat._update_grid_entities()

static func add(h: Node, combat: CombatState, name: String, source: String, caster: Character, center: Vector2i = Vector2i(1,0)) -> Dictionary:
	var result := combat._spell_zones().add_trigger_area(source, caster.character_id, declaration(name), center)
	h._assert(result.get("success", false), "S184 generic combat factory accepts neutral " + name)
	return result.get("area", {})

static func start_turn(combat: CombatState, actor: Character, round_number: int) -> void:
	for index in combat.tracker.combatants.size():
		var candidate: Variant = combat.tracker.combatants[index].get("entity")
		if candidate is Character and candidate == actor: combat.tracker.active_index = index; break
	combat.tracker.current_round = round_number
	combat._start_combat_turn()

static func combat_paths(h: Node, combat: CombatState, actor: Character, caster: Character) -> void:
	for area in LocalRoomCombat.room().get("areas", []): LocalRoomAreas.move_area(LocalRoomCombat.room(), str(area.id), Vector2i(6,3), [])
	prepare(h, combat, actor, caster)
	start_turn(combat, actor, 3)
	add(h, combat, "threshold", "exact:a", caster)
	var hp := actor.current_hp
	var speed := combat.remaining_speed
	await combat._on_hex_clicked(Vector2i(1,0))
	await combat._resolve_spell_zone_entries(actor, Vector2i.ZERO, Vector2i(1,0))
	await combat._on_hex_clicked(Vector2i.ZERO)
	await combat._on_hex_clicked(Vector2i(1,0))
	h._assert(actor.current_hp == hp - 3 and combat.remaining_speed == speed - 3, "S184 actual combat clicks charge movement once per route and once-per-turn entry ignores replay/reentry")
	await combat._resolve_spell_zone_end_turn(actor, Vector2i(1,0))
	h._assert(actor.current_hp == hp - 3, "S184 declared entry/end events share a single turn limit")
	add(h, combat, "threshold", "exact:b", caster)
	await combat._on_hex_clicked(Vector2i.ZERO)
	await combat._on_hex_clicked(Vector2i(1,0))
	h._assert(actor.current_hp == hp - 6, "S184 two sources of the same definition retain independent actor limits")
	actor.heal(actor.max_hp)
	# Actual AI passes null as its target argument; the mover dictionary must still trigger.
	var enemy: Dictionary = combat.monster_entities[0]
	var enemy_hp := int(enemy.current_hp)
	await combat._check_opportunity_attacks_for_path(null, enemy, [Vector2i(6,0),Vector2i(5,0),Vector2i(4,0),Vector2i(3,0),Vector2i(2,0),Vector2i(1,0)], true)
	h._assert(enemy.current_hp == enemy_hp - 6, "S184 actual null-target AI movement triggers each exact source independently for another actor")
	prepare(h, combat, actor, caster)
	add(h, combat, "passage", "pass", caster)
	hp = actor.current_hp
	await combat._on_hex_clicked(Vector2i(1,0))
	await combat._on_hex_clicked(Vector2i.ZERO)
	h._assert(actor.current_hp == hp - 6, "S184 crossing fires on both boundary directions while entry is directional")
	prepare(h, combat, actor, caster)
	add(h, combat, "nearby", "near", caster, Vector2i.ZERO)
	hp = actor.current_hp
	await combat._on_hex_clicked(Vector2i(1,0))
	await combat._on_hex_clicked(Vector2i.ZERO)
	h._assert(actor.current_hp == hp - 3, "S184 first approach triggers on first movement while already in range, once on that turn")
	prepare(h, combat, actor, caster)
	add(h, combat, "threshold", "fixed", caster, Vector2i(3,0))
	add(h, combat, "sweep", "swept", caster, Vector2i(3,0))
	hp = actor.current_hp
	await combat._spell_zones().move_trigger_area("fixed", Vector2i.ZERO)
	await combat._spell_zones().move_trigger_area("swept", Vector2i.ZERO)
	await combat._spell_zones().move_trigger_area("swept", Vector2i(3,0))
	await combat._spell_zones().move_trigger_area("swept", Vector2i.ZERO)
	h._assert(actor.current_hp == hp - 3, "S184 combat area motion follows area_enter policy instead of pretending the stationary actor entered")
	await clock_paths(h, combat, actor, caster)
	await additional_hosts(h, combat, actor, caster)
	await concentration_paths(h, combat, actor, caster)
	prepare(h, combat, actor, caster)
	var area := add(h, combat, "every_entry", "suspended", caster)
	var zones := combat._spell_zones()
	var gate := Gate.new()
	zones.check_concentration = gate.wait_for_resume
	hp = actor.current_hp
	CombatAction.resolve_movement_step(combat.player_entities[combat.current_player_idx], Vector2i.ZERO, Vector2i(1,0))
	zones._resolve_spell_zone_entries(actor, Vector2i.ZERO, Vector2i(1,0))
	await h.get_tree().process_frame
	var paid_speed := combat.remaining_speed
	await zones._resolve_spell_zone_entries(actor, Vector2i.ZERO, Vector2i(1,0))
	h._assert(gate.calls == 1 and actor.current_hp == hp - 3 and combat.remaining_speed == paid_speed, "S184 suspended concentration callback plus repeated entry cannot duplicate damage or consume movement")
	zones._remove_spell_zone("suspended")
	gate.released.emit()
	await h.get_tree().process_frame
	h._assert(area.get("_trigger_ended", false) and actor.current_hp == hp - 3 and not combat.resolving_player_action, "S184 source cleanup during interruption resumes once without replay")
	prepare(h, combat, actor, caster)
	add(h, combat, "every_entry", "lethal", caster, Vector2i(2,0))
	actor.current_hp = 1
	await combat._on_hex_clicked(Vector2i(4,0))
	h._assert(combat.player_entities[combat.current_player_idx].hex_position == Vector2i(2,0) and not actor.is_alive, "S184 actual combat movement stops at lethal intermediate entry")
	actor.heal(actor.max_hp)
	# Persist a combat movement receipt on a room child for the fresh-process probe.
	prepare(h, combat, actor, caster)
	for child in LocalRoomCombat.room().get("areas", []):
		if child.trigger_policies[0].boundary == "event": LocalRoomAreas.move_area(LocalRoomCombat.room(), str(child.id), Vector2i(3,0), [])
	await combat._on_hex_clicked(Vector2i(3,0))
	actor.heal(actor.max_hp)
	for child in LocalRoomCombat.room().get("areas", []):
		if child.trigger_policies[0].boundary == "lifetime": LocalRoomAreas.move_area(LocalRoomCombat.room(), str(child.id), Vector2i(2,0), [])
	var enemy_hp_before := int(enemy.current_hp)
	await combat._check_opportunity_attacks_for_path(null, enemy, [Vector2i(6,0),Vector2i(5,0),Vector2i(4,0),Vector2i(3,0),Vector2i(2,0)], true)
	h._assert(enemy.current_hp == enemy_hp_before - 6, "S184 first encounter monster consumes its own lifetime receipt on a persistent room source")

static func concentration_paths(h: Node, combat: CombatState, actor: Character, caster: Character) -> void:
	prepare(h, combat, actor, caster)
	var original_max_hp := actor.max_hp
	actor.max_hp = maxi(100, actor.max_hp)
	actor.current_hp = actor.max_hp
	var zones := combat._spell_zones()
	var original_check := zones.check_concentration
	var amounts: Array[int] = []
	var area := add(h, combat, "every_entry", "temp-hp-concentration", caster)
	area.amount = 30
	area.damage_type = "fire"
	# The factory rebinds the encounter callbacks; observe after it finishes.
	zones.check_concentration = func(_target, amount): amounts.append(amount)
	var hp := actor.current_hp
	for temporary in [40, 2]:
		actor.temp_hp = temporary
		var event := SpatialTriggerRules.next_event()
		var deliveries := SpatialTriggerRules.claim(area, actor.character_id, ["entry"], event, zones._trigger_clocks())
		await zones._resolve_trigger_deliveries(actor, deliveries)
	h._assert(amounts == [30,30] and actor.current_hp == hp - 28, "S184 full and partial Temporary HP absorption each pass the full settled hit to concentration: %s, HP %d -> %d" % [str(amounts), hp, actor.current_hp])
	actor.feature_uses["damage_resistances"] = ["fire"]
	actor.temp_hp = 40
	var resisted := SpatialTriggerRules.claim(area, actor.character_id, ["entry"], SpatialTriggerRules.next_event(), zones._trigger_clocks())
	await zones._resolve_trigger_deliveries(actor, resisted)
	h._assert(amounts == [30,30,15] and actor.temp_hp == 25, "S184 concentration receives settled resisted damage rather than the authored amount: %s, temp %d" % [str(amounts), actor.temp_hp])
	actor.feature_uses["damage_immunities"] = ["fire"]
	var immune := SpatialTriggerRules.claim(area, actor.character_id, ["entry"], SpatialTriggerRules.next_event(), zones._trigger_clocks())
	await zones._resolve_trigger_deliveries(actor, immune)
	h._assert(amounts == [30,30,15] and actor.temp_hp == 25, "S184 immunity does not open a concentration callback: %s, temp %d" % [str(amounts), actor.temp_hp])
	actor.feature_uses.erase("damage_resistances")
	actor.feature_uses.erase("damage_immunities")
	actor.temp_hp = 0
	zones.check_concentration = original_check
	actor.max_hp = original_max_hp
	actor.current_hp = mini(actor.current_hp, actor.max_hp)
	prepare(h, combat, actor, caster)

static func clock_paths(h: Node, combat: CombatState, actor: Character, caster: Character) -> void:
	prepare(h, combat, actor, caster)
	start_turn(combat, actor, 10)
	add(h, combat, "actor_clock", "actor-clock", caster)
	add(h, combat, "source_clock", "source-clock", caster)
	var hp := actor.current_hp
	await combat._on_hex_clicked(Vector2i(1,0))
	await combat._on_hex_clicked(Vector2i.ZERO)
	start_turn(combat, caster, 10)
	h._p_focus(combat, actor)
	await combat._on_hex_clicked(Vector2i(1,0))
	h._assert(actor.current_hp == hp - 9, "S184 source-owner turn renews only source_turn, preserving actor_turn limit")
	actor.heal(actor.max_hp)
	await combat._on_hex_clicked(Vector2i.ZERO)
	start_turn(combat, actor, 11)
	hp = actor.current_hp
	await combat._on_hex_clicked(Vector2i(1,0))
	h._assert(actor.current_hp == hp - 3, "S184 affected actor turn renews actor_turn without resetting source_turn")
	prepare(h, combat, actor, caster)
	add(h, combat, "start_end", "turns", caster, Vector2i.ZERO)
	hp = actor.current_hp
	start_turn(combat, actor, 12)
	start_turn(combat, actor, 12)
	await combat._resolve_spell_zone_end_turn(actor, Vector2i.ZERO)
	await combat._resolve_spell_zone_end_turn(actor, Vector2i.ZERO)
	h._assert(actor.current_hp == hp - 6, "S184 repeated actual start callback and repeated end callback settle each separately once")
	actor.heal(actor.max_hp)
	hp = actor.current_hp
	start_turn(combat, actor, 13)
	h._assert(actor.current_hp == hp - 3, "S184 next actual initiative turn renews start scope")
	prepare(h, combat, actor, caster)
	add(h, combat, "start_end", "born-after-start", caster, Vector2i.ZERO)
	hp = actor.current_hp
	start_turn(combat, actor, 13)
	h._assert(actor.current_hp == hp, "S184 an area created after turn start cannot borrow a replay of that passed boundary")
	prepare(h, combat, actor, caster)
	add(h, combat, "lifetime", "lifetime", caster)
	hp = actor.current_hp
	await combat._on_hex_clicked(Vector2i(1,0))
	await combat._on_hex_clicked(Vector2i.ZERO)
	start_turn(combat, actor, 14)
	await combat._on_hex_clicked(Vector2i(1,0))
	h._assert(actor.current_hp == hp - 3, "S184 lifetime scope survives a real turn reset and reentry")
	combat._remove_spell_zone("lifetime")
	add(h, combat, "lifetime", "new-lifetime", caster)
	await combat._on_hex_clicked(Vector2i.ZERO)
	await combat._on_hex_clicked(Vector2i(1,0))
	h._assert(actor.current_hp == hp - 6, "S184 cleanup leaves a newly created exact source its own lifetime")

static func additional_hosts(h: Node, combat: CombatState, actor: Character, caster: Character) -> void:
	prepare(h, combat, actor, caster)
	add(h, combat, "every_entry", "tactical", caster)
	combat.fighter_move_waiting = true
	combat.fighter_move_done = false
	combat.fighter_move_entity = combat.player_entities[combat.current_player_idx]
	combat.fighter_move_choices = {Vector2i(2,0):2}
	var hp := actor.current_hp
	var speed := combat.remaining_speed
	await combat._on_hex_clicked(Vector2i(2,0))
	await combat._on_hex_clicked(Vector2i(2,0))
	h._assert(actor.current_hp == hp - 3 and combat.player_entities[combat.current_player_idx].hex_position == Vector2i(2,0) and combat.remaining_speed == speed and combat.fighter_move_done, "S184 actual tactical destination control traverses hazard cells once without spending ordinary movement")
	combat.fighter_move_waiting = false
	prepare(h, combat, actor, caster)
	while caster.level < 3: caster.level_up()
	if "misty_step" not in caster.known_spells: caster.known_spells.append("misty_step")
	if "misty_step" not in caster.wizard_spellbook: caster.wizard_spellbook.append("misty_step")
	h._own_class_spells(caster)
	caster.wizard_spellbook.assign(caster.wizard_spellbook.filter(func(id): return int(DataLoader.get_spell(str(id)).get("level", 0)) > 0))
	caster.spell_slots["2"] = 2
	h._p_focus(combat, caster)
	combat.player_entities[combat.current_player_idx].hex_position = Vector2i.ZERO
	combat.player_entities[0].hex_position = Vector2i(-2,0)
	add(h, combat, "passage", "teleport-crossing", caster)
	add(h, combat, "nearby", "teleport-approach", caster, Vector2i(2,0))
	add(h, combat, "every_entry", "teleport-entry", caster, Vector2i(2,0))
	hp = caster.current_hp
	combat._update_grid_entities()
	await Batch066TravelControls._cast(h, combat, Vector2i(2,0))
	await Batch066TravelControls._cast(h, combat, Vector2i(1,0))
	h._assert(combat.player_entities[combat.current_player_idx].hex_position == Vector2i(2,0) and caster.current_hp == hp - 3 and caster.spell_slots["2"] == 1 and not combat.turn_budget.bonus_action_available, "S184 actual teleport arrival enters once, skips swept crossing/first approach and pays one slot/Bonus Action")
	prepare(h, combat, actor, caster)
	var pair := declaration("sweep")
	pair.radius_hexes = 1
	combat._spell_zones().add_trigger_area("pair", caster.character_id, pair, Vector2i(5,0))
	combat.player_entities[1].hex_position = Vector2i(0,1)
	var zones := combat._spell_zones()
	var gate := Gate.new()
	zones.check_concentration = gate.wait_for_resume
	var actor_hp := actor.current_hp
	var caster_hp := caster.current_hp
	zones.move_trigger_area("pair", Vector2i.ZERO)
	await h.get_tree().process_frame
	await zones.move_trigger_area("pair", Vector2i(5,0))
	gate.released.emit()
	await h.get_tree().process_frame
	gate.released.emit()
	await h.get_tree().process_frame
	h._assert(actor.current_hp == actor_hp - 3 and caster.current_hp == caster_hp - 3 and gate.calls == 2, "S184 area movement captures both stationary recipients before the first suspended callback, even if the area moves again")

static func run_reload(h: Node) -> void:
	h._enter_test("spatial_trigger_reload")
	fixtures()
	var file := FileAccess.open("user://spatial_manifest.json", FileAccess.READ)
	var manifest: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	h._assert(OS.get_process_id() != int(manifest.pid) and SaveManager.load_game(SLOT), "S184 checkpoint loads in a genuinely fresh process")
	var state: Dictionary = GameManager.active_dungeon_state.local_rooms["0"]
	var recovered_ids: Array = state.areas.map(func(a): return a.id)
	var recovered_counts: Array = state.areas.map(func(a): return a.get("trigger_receipts", {}).size())
	h._assert(recovered_ids == manifest.ids and recovered_counts == manifest.receipts.map(func(value): return int(value)), "S184 fresh load preserves exact sources and consumed receipts without replay: " + JSON.stringify({"ids_equal":recovered_ids == manifest.ids,"actual":recovered_counts,"expected":manifest.receipts}))
	var actor: Character = PlayerManager.get_player(0).character
	GameManager.transition_context = {"terrain":"plains", "monster_ids":["goblin"], "local_room":state}
	var combat: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.3)
	prepare(h, combat, actor, PlayerManager.get_player(1).character)
	var hp := actor.current_hp
	await combat._on_hex_clicked(Vector2i(3,0))
	h._assert(int(state.area_encounter_serial) > int(manifest.epoch) and actor.current_hp == hp - 6, "S184 fresh encounter uses durable epoch so its first movement cannot collide with a prior process receipt")
	actor.heal(actor.max_hp)
	var enemy: Dictionary = combat.monster_entities[0]
	var enemy_hp := int(enemy.current_hp)
	await combat._check_opportunity_attacks_for_path(null, enemy, [Vector2i(6,0),Vector2i(5,0),Vector2i(4,0),Vector2i(3,0),Vector2i(2,0)], true)
	h._assert(enemy.current_hp == enemy_hp - 6, "S184 a different encounter's monster_0 is a different actor for the saved lifetime source")
	h._teardown_scene(combat)
	h._exit_test()
