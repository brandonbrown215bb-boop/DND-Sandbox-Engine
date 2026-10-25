class_name Batch066Controls
extends RefCounted
## S-121: resolve a real monster saving throw, then settle the required exit
## through the live HUD popup before the resolver applies save consequences.

static func _finish_exit(cast: SpellCastContext, target: Dictionary, spell: Dictionary, decisions: Dictionary, result: Dictionary, out: Array) -> void:
	out.append(await SpellCastResults._settle_save_exit(cast, target, spell, decisions, [], 0, 5, result))

static func _popup(h: Node, combat: Node) -> PopupMenu:
	for _frame in 180:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if child is PopupMenu and child.visible and not child.is_queued_for_deletion() and str(child.title).begins_with("Choose the required exit space"):
				return child
	return null

static func run(h: Node) -> void:
	h._enter_test("s121_exit_placement_flow")
	h._setup_world()
	DataLoader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	var caster: Character = PlayerManager.get_player(0).get("character")
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	var target: Dictionary = combat.monster_entities[0]
	var origin: Vector2i = target.get("hex_position", Vector2i.ZERO)
	var spell: Dictionary = DataLoader.get_spell("fixture:renamed_exit_placement").duplicate(true)
	spell["_save_dc_override"] = 1 # A successful numeric save for this authored fixture.
	var cast := SpellCastContext.new()
	cast.caster = caster
	cast.invocation_id = "s121-live-control"
	cast.spell = spell
	cast.players = combat.player_entities
	cast.monsters = combat.monster_entities
	cast.hud = combat.hud
	cast.grid = combat.hex_grid
	cast.slot_level_used = 0
	cast.redraw_entities = Callable(combat, "_update_grid_entities")
	var decisions := {"grid": combat.hex_grid, "players": cast.players, "monsters": cast.monsters, "cast_context": cast, "hud": combat.hud}
	var before_hp := int(target.get("current_hp", 0))
	var first := CombatAction.resolve_spell(caster, target, spell, false, decisions, [], 0, 5, cast)
	h._assert(first.has("save_exit_request") and bool(first.get("saved", false)) and int(target.get("current_hp", before_hp)) == before_hp and not CombatAction.has_condition(target, "frightened"), "S-121 real resolver suspends the successful numeric save before damage or failed-save effects")
	var out: Array = []
	_finish_exit(cast, target, spell, decisions, first, out)
	var menu := await _popup(h, combat)
	var labels: Array[String] = []
	if menu != null:
		for index in menu.item_count: labels.append(menu.get_item_text(index))
	var picked := ""
	if menu != null and menu.item_count > 1:
		picked = menu.get_item_text(1)
		menu.id_pressed.emit(menu.get_item_id(1))
	for _frame in 240:
		if not out.is_empty(): break
		await h.get_tree().process_frame
	var settled: Dictionary = out[0] if not out.is_empty() else {}
	var destination: Variant = SaveExitPlacementRules.actor_position(cast, target)
	var result_ok: bool = menu != null and labels.size() > 1 and labels[0] == "Cancel" and picked.begins_with("Hex (") and destination != origin and settled.has("save_total") and int(settled.get("save_dc", -1)) == 1 and not CombatAction.has_condition(target, "frightened")
	h._assert(result_ok, "S-121 actual exit popup moves only after the choice and preserves the captured save total/DC (%s)" % str(settled.get("message", "")))
	var location_after_settlement: Variant = SaveExitPlacementRules.actor_position(cast, target)
	# An already-failed numeric save has no required exit choice. It settles its
	# authored failure effects through the normal path.
	var failed_target: Dictionary = target.duplicate(true)
	failed_target["id"] = "s121-direct-failed-save"
	failed_target["hex_position"] = location_after_settlement + Vector2i(2, 0)
	failed_target["current_hp"] = int(failed_target.get("max_hp", 10))
	failed_target["conditions"] = {}
	cast.monsters.append(failed_target)
	spell["_save_dc_override"] = 30
	FighterChecks._seed_die(20, 1)
	var failed_hp := int(failed_target.get("current_hp", 0))
	var direct_failure := CombatAction.resolve_spell(caster, failed_target, spell, false, decisions, [], 0, 5, cast)
	h._assert(not direct_failure.has("save_exit_request") and not bool(direct_failure.get("saved", true)) and int(failed_target.get("current_hp", failed_hp)) < failed_hp and CombatAction.has_condition(failed_target, "frightened"), "S-121 an initially failed numeric save settles failure effects without requesting an exit")
	cast.monsters.erase(failed_target)
	spell["_save_dc_override"] = 1
	# The same authored spell with no legal exit space changes the captured
	# successful save to failure, because this fixture explicitly declares it.
	cast.invocation_id = "s121-no-space-control"
	spell["save_exit_placement"]["range_hexes"] = 0
	var no_space_request := CombatAction.resolve_spell(caster, target, spell, false, decisions, [], 0, 5, cast)
	var no_space := await SpellCastResults._settle_save_exit(cast, target, spell, decisions, [], 0, 5, no_space_request)
	h._assert(no_space_request.has("save_exit_request") and not bool(no_space.get("saved", true)) and int(no_space.get("save_total", -1)) == int(no_space_request.get("save_exit_request", {}).get("save_test", {}).get("total", -2)) and int(no_space.get("save_dc", -1)) == int(no_space_request.get("save_exit_request", {}).get("save_test", {}).get("dc", -2)) and CombatAction.has_condition(target, "frightened"), "S-121 authored no-space failure preserves the successful roll/total/DC, then applies failure effects")
	var hp_after_no_space := int(target.get("current_hp", 0))
	spell["save_exit_placement"]["range_hexes"] = 1
	var duplicate := await SpellCastResults._settle_save_exit(cast, target, spell, decisions, [], 0, 5, first)
	h._assert(bool(duplicate.get("refused", false)) and SaveExitPlacementRules.actor_position(cast, target) == location_after_settlement and int(target.get("current_hp", 0)) == hp_after_no_space, "S-121 a duplicate answer cannot move or apply the saved result twice")
	# A canceled, invalid or stale answer never moves the actor or resumes effects.
	cast.hud = null
	cast.invocation_id = "s121-cancel-control"
	var cancel_request := CombatAction.resolve_spell(caster, target, spell, false, decisions, [], 0, 5, cast)
	cast.choose_save_exit = func(_options: Array, _ids: Array) -> String: return ""
	var canceled := await SpellCastResults._settle_save_exit(cast, target, spell, decisions, [], 0, 5, cancel_request)
	h._assert(bool(canceled.get("canceled", false)) and SaveExitPlacementRules.actor_position(cast, target) == location_after_settlement and int(target.get("current_hp", 0)) == hp_after_no_space, "S-121 cancel leaves location and failed-save consequences untouched")
	cast.invocation_id = "s121-invalid-control"
	var invalid_request := CombatAction.resolve_spell(caster, target, spell, false, decisions, [], 0, 5, cast)
	cast.choose_save_exit = func(_options: Array, _ids: Array) -> String: return "999,999"
	var invalid := await SpellCastResults._settle_save_exit(cast, target, spell, decisions, [], 0, 5, invalid_request)
	h._assert(bool(invalid.get("canceled", false)) and SaveExitPlacementRules.actor_position(cast, target) == location_after_settlement and int(target.get("current_hp", 0)) == hp_after_no_space, "S-121 an unoffered destination is refused without movement or consequences")
	cast.invocation_id = "s121-stale-control"
	var stale_request := CombatAction.resolve_spell(caster, target, spell, false, decisions, [], 0, 5, cast)
	cast.choose_save_exit = func(options: Array, _ids: Array) -> String:
		var hex: Vector2i = options[0]
		return "%d,%d" % [hex.x, hex.y]
	cast.commit_guard = func() -> bool: return false
	var stale := await SpellCastResults._settle_save_exit(cast, target, spell, decisions, [], 0, 5, stale_request)
	h._assert(bool(stale.get("refused", false)) and SaveExitPlacementRules.actor_position(cast, target) == location_after_settlement and int(target.get("current_hp", 0)) == hp_after_no_space, "S-121 a stale choice is refused without movement or consequences")
	cast.commit_guard = Callable()
	var live_location: Vector2i = SaveExitPlacementRules.actor_position(cast, target)
	cast.invocation_id = "s121-occupied-control"
	var occupied_request := CombatAction.resolve_spell(caster, target, spell, false, decisions, [], 0, 5, cast)
	var occupied_cell: Vector2i = SaveExitPlacementRules.candidates(cast, target, live_location, PhysicalFactsRules.get_size(target), PhysicalFactsRules.get_plane(target), spell.save_exit_placement)[0]
	var blocker := {"id": "s121-choice-blocker", "name": "Choice blocker", "size": "medium", "plane": "material", "hex_position": occupied_cell, "is_alive": true, "conditions": {}}
	cast.choose_save_exit = func(_options: Array, ids: Array) -> String:
		cast.monsters.append(blocker)
		return str(ids[1])
	var occupied := await SpellCastResults._settle_save_exit(cast, target, spell, decisions, [], 0, 5, occupied_request)
	cast.monsters.erase(blocker)
	h._assert(bool(occupied.get("refused", false)) and SaveExitPlacementRules.actor_position(cast, target) == live_location and int(target.get("current_hp", 0)) == hp_after_no_space, "S-121 recheck refuses a destination occupied while the choice is open")
	cast.invocation_id = "s121-wall-control"
	var wall_request := CombatAction.resolve_spell(caster, target, spell, false, decisions, [], 0, 5, cast)
	var wall_cell: Vector2i = SaveExitPlacementRules.candidates(cast, target, live_location, PhysicalFactsRules.get_size(target), PhysicalFactsRules.get_plane(target), spell.save_exit_placement)[0]
	var wall_tile: HexTile = cast.grid.get_tile(wall_cell)
	cast.choose_save_exit = func(_options: Array, ids: Array) -> String:
		wall_tile.custom_properties["blocks_movement"] = true
		return str(ids[1])
	var walled := await SpellCastResults._settle_save_exit(cast, target, spell, decisions, [], 0, 5, wall_request)
	wall_tile.custom_properties.erase("blocks_movement")
	h._assert(bool(walled.get("refused", false)) and SaveExitPlacementRules.actor_position(cast, target) == live_location and int(target.get("current_hp", 0)) == hp_after_no_space, "S-121 recheck refuses a destination blocked by a wall while the choice is open")
	cast.invocation_id = "s121-clearance-control"
	var clearance_request := CombatAction.resolve_spell(caster, target, spell, false, decisions, [], 0, 5, cast)
	var clearance_cell: Vector2i = SaveExitPlacementRules.candidates(cast, target, live_location, PhysicalFactsRules.get_size(target), PhysicalFactsRules.get_plane(target), spell.save_exit_placement)[0]
	cast.choose_save_exit = func(_options: Array, ids: Array) -> String:
		spell["save_exit_placement"]["clearance_feet"] = 1001
		return str(ids[1])
	var clearance := await SpellCastResults._settle_save_exit(cast, target, spell, decisions, [], 0, 5, clearance_request)
	spell["save_exit_placement"].erase("clearance_feet")
	h._assert(bool(clearance.get("refused", false)) and SaveExitPlacementRules.actor_position(cast, target) == live_location and int(target.get("current_hp", 0)) == hp_after_no_space and clearance_cell != live_location, "S-121 recheck refuses a destination with insufficient declared clearance")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	await _sanctuary_regression(h)
	await _represented_travel_placement(h)
	h._exit_test()


static func _represented_travel_placement(h: Node) -> void:
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {}
	GameManager.game_in_progress = true
	var overworld: Node = await h._spawn_scene("res://scenes/overworld.tscn", 0.8)
	if overworld == null:
		h._assert(false, "S-122 represented-travel host opens the production overworld")
		return
	var origin := PartyManager.get_exploration_position()
	var refused: Variant = overworld._represented_travel_destination({"destination": [999999, -999999]})
	h._assert(refused == null and PartyManager.get_exploration_position() == origin, "S-122 unknown travel destination refuses without inventing a coordinate or moving the party")
	var malformed_refused := true
	for invalid in ["unknown-place", null, [], [0], [0.5, 1], ["0", 1], [0, 0, 0]]:
		for field in ["destination", "destination_coord"]:
			malformed_refused = malformed_refused and overworld._represented_travel_destination({field: invalid}) == null
	h._assert(malformed_refused and PartyManager.get_exploration_position() == origin, "S-122 malformed explicit travel destinations refuse instead of falling back to random travel or truncating coordinates")
	var destination: Variant = overworld._represented_travel_destination({})
	var travel_ok: bool = destination is Vector2i and destination != origin and overworld.hex_grid.has_tile(destination)
	if travel_ok:
		var max_range := 0
		for cell in overworld.hex_grid.tiles: max_range = maxi(max_range, HexUtils.get_distance(origin, cell))
		travel_ok = PlacementRules.legal_error(overworld._represented_travel_placement_state(), origin, destination, "medium", max_range).is_empty()
	PartyManager.move_exploration_party(destination if destination is Vector2i else origin)
	h._assert(travel_ok and PartyManager.get_exploration_position() == destination, "S-122 random travel selects an actual legal overworld tile through PlacementRules and PhysicalFactsRules")
	var checkpoint_saved := SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game("represented_travel_placement")
	var checkpoint_loaded := checkpoint_saved and SaveManager.load_game("represented_travel_placement")
	h._assert(checkpoint_saved and checkpoint_loaded and PartyManager.get_exploration_position() == destination, "S-122 represented travel survives the supported overworld checkpoint without choosing a new destination (saved=%s loaded=%s pos=%s expected=%s block=%s)" % [str(checkpoint_saved), str(checkpoint_loaded), str(PartyManager.get_exploration_position()), str(destination), SaveManager.get_save_block_reason()])
	h._teardown_scene(overworld)
	await _exploration_exit_control(h)


static func _exploration_exit_control(h: Node) -> void:
	var caster: Character = PlayerManager.get_player(1).get("character")
	var target: Character = PlayerManager.get_player(0).get("character")
	DataLoader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	DataLoader.get_spell("fixture:renamed_exit_placement")["damage"] = "4"
	DataLoader.get_spell("fixture:renamed_exit_placement")["half_on_save"] = true
	caster.known_spells.assign(["fixture:renamed_exit_placement"])
	caster.spell_slots["1"] = 3
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await h._spawn_scene("res://scenes/dungeon.tscn", 0.5)
	if dungeon == null:
		h._assert(false, "S-121 local-room host opens the production dungeon controls")
		return
	var cells: Array = []
	for cell in HexUtils.get_hexes_in_range(Vector2i.ZERO, 2): cells.append([cell.x, cell.y])
	var state := LocalRoomRules.create({"id": "s121-exploration-room", "name": "Exit Room", "cells": cells, "walls": [], "exits": [], "party_spawns": [[0, 0], [1, 0]], "monster_spawns": [], "objects": [], "encounter_monsters": [], "plane": "material", "ceiling_feet": 8}, [caster, target])
	var view := LocalRoomView.new()
	dungeon.local_view = view
	view.start(state, [caster, target], dungeon.hex_grid, dungeon.hud, func(): return {})
	var hp_before := target.current_hp
	var slots_before := int(caster.spell_slots.get("1", 0))
	var choice_mode := {"mode": "cancel", "blocker": {}}
	var chooser := func(options: Array, ids: Array) -> String:
		h.get_tree().create_timer(0.1).timeout.connect(func():
			if str(choice_mode.get("mode", "")) == "cancel":
				if view.save_exit_cancel_button != null: view.save_exit_cancel_button.pressed.emit()
			elif str(choice_mode.get("mode", "")) == "occupy":
				var blocker := {"character": caster, "hex_position": options[0]}
				choice_mode["blocker"] = blocker
				view.grid.add_entity(blocker)
				view.click(options[0])
			else: view.click(options[0]))
		return await view.choose_save_exit(options, ids)
	FighterChecks._seed_die(20, 20)
	var canceled: Dictionary = await LocalRoomSharedSpells.cast_with_save_exit(state, caster, "fixture:renamed_exit_placement", target, [caster, target], dungeon.hex_grid, chooser)
	h._assert(bool(canceled.get("canceled", false)) and LocalRoomRules.coord(state.party_positions[target.character_id]) == Vector2i(1, 0) and target.current_hp == hp_before, "S-121 real room cancel preserves target location and HP before settling save consequences")
	var slots_after_cancel := int(caster.spell_slots.get("1", 0))
	choice_mode["mode"] = "occupy"
	FighterChecks._seed_die(20, 20)
	var occupied: Dictionary = await LocalRoomSharedSpells.cast_with_save_exit(state, caster, "fixture:renamed_exit_placement", target, [caster, target], dungeon.hex_grid, chooser)
	dungeon.hex_grid.entities.erase(choice_mode["blocker"])
	h._assert(bool(occupied.get("refused", false)) and LocalRoomRules.coord(state.party_positions[target.character_id]) == Vector2i(1, 0) and target.current_hp == hp_before, "S-121 room choice recheck refuses a destination occupied while the real map decision is open")
	var slots_after_occupancy := int(caster.spell_slots.get("1", 0))
	choice_mode["mode"] = "choose"
	FighterChecks._seed_die(20, 20)
	var settled: Dictionary = await LocalRoomSharedSpells.cast_with_save_exit(state, caster, "fixture:renamed_exit_placement", target, [caster, target], dungeon.hex_grid, chooser)
	var settled_position := LocalRoomRules.coord(state.party_positions[target.character_id])
	h._assert(bool(settled.get("success", false)) and settled_position != Vector2i(1, 0) and target.current_hp < hp_before and int(caster.spell_slots.get("1", 0)) == slots_after_occupancy - 1, "S-121 real room map click validates and records the exit before applying the captured save's damage and spends one slot (result=%s position=%s hp=%d/%d slots=%d/%d)" % [str(settled), str(settled_position), target.current_hp, hp_before, int(caster.spell_slots.get("1", 0)), slots_after_occupancy])
	caster.spell_slots["1"] = 1
	for selector in view.action_row.find_children("*", "OptionButton", true, false):
		for index in selector.item_count:
			if selector.get_item_metadata(index) == "party:" + target.character_id: selector.select(index)
	var hp_before_stop := target.current_hp
	FighterChecks._seed_die(20, 20)
	h._local_room_press(view, "Cast")
	await h.get_tree().process_frame
	h._assert(not view.pending_save_exit.is_empty() and view.actors.disabled, "S-121 actual room Cast button suspends at the map decision and disables competing room actions")
	view.stop()
	h._assert(view.pending_save_exit.is_empty() and target.current_hp == hp_before_stop and LocalRoomRules.coord(state.party_positions[target.character_id]) == settled_position, "S-121 closing the room cancels its pending exit without applying the captured consequences")
	dungeon.local_view = null
	h._teardown_scene(dungeon)

static func _sanctuary_regression(h: Node) -> void:
	var caster := Character.new()
	caster.initialize("Exit caster", "human", "wizard", AbilityScores.new())
	caster.ability_scores.wisdom = 10
	var protector := Character.new()
	protector.initialize("Exit protector", "human", "cleric", AbilityScores.new())
	protector.ability_scores.wisdom = 10
	var target := {"id": "s121-sanctuary-target", "name": "Protected target", "current_hp": 100, "max_hp": 100, "is_alive": true, "size": "medium", "hex_position": Vector2i.ZERO, "ability_scores": {"DEX": 100}, "conditions": {}}
	SpellEffects.grant(target, SpellEffects.begin_cast(protector, DataLoader.get_spell("sanctuary")), "sanctuary")
	var spell := DataLoader.get_spell("fixture:renamed_exit_placement").duplicate(true)
	spell["_save_dc_override"] = 1
	spell["damage"] = "4"
	spell["half_on_save"] = true
	spell["_effect_cast"] = SpellEffects.begin_cast(caster, spell)
	var host := SpellCastContext.new()
	host.caster = caster
	host.invocation_id = "s121-sanctuary-regression"
	host.spell = spell
	host.monsters = [target]
	host.grid = HexGrid.new()
	h.add_child(host.grid)
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 2):
		var tile := HexTile.new()
		tile.coord = coord
		host.grid.add_tile(tile)
	host.choose_save_exit = func(_options: Array, ids: Array) -> String:
		# Re-entering the cast resolver would fail a second Sanctuary check.
		FighterChecks._seed_die(20, 1)
		return str(ids[1])
	var decisions := {"cast_context": host}
	FighterChecks._seed_die(20, 20)
	var first := CombatAction.resolve_spell(caster, target, spell, false, decisions, [], 0, 5, host)
	var final := await SpellCastResults._settle_save_exit(host, target, spell, decisions, [], 0, 5, first)
	h._assert(first.has("save_exit_request") and not bool(final.get("sanctuary_blocked", false)) and target.hex_position != Vector2i.ZERO and int(target.current_hp) == 98 and int(final.get("save_total", -1)) == int(first.get("save_exit_request", {}).get("save_test", {}).get("total", -2)) and final.get("effect_cast", {}).get("source_id") == spell._effect_cast.source_id and caster.spell_cast_serial == 1, "S-121 resumes the captured save after one Sanctuary check, retaining its source and applying half damage once")
	host.grid.queue_free()
