class_name Batch030Controls
extends RefCounted

static func pause(h: Node, frames: int = 4) -> void:
	for frame in frames: await h.get_tree().process_frame


static func run(h: Node) -> void:
	h._enter_test("batch_030_physical_and_movement_flow")
	h._setup_world()
	Batch030Checks.load_fixtures()
	h._assert(DataLoader.get_load_errors().is_empty(), "030 examples load through ordinary validation without errors")

	var scores := AbilityScores.new()
	scores.from_dict({"STR": 16, "DEX": 14, "CON": 14, "INT": 12, "WIS": 12, "CHA": 10})

	var explorer := Character.new()
	explorer.initialize("Physical Explorer", "human", "fighter", scores)
	explorer.character_id = "b030_explorer"
	explorer.max_hp = 45
	explorer.current_hp = 45
	explorer.speed = 6
	explorer.known_spells = ["fixture:030_catapult_loose_object", "fixture:030_shatter_metal_crystal", "fixture:030_planar_space_step"]

	PartyManager.reset()
	PlayerManager.set_player_character(0, explorer)
	PartyManager.register_player_character(0, explorer)

	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false

	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame

	h._p_focus(combat, explorer)
	combat.player_entities[0].hex_position = Vector2i.ZERO

	var enemy: Dictionary = combat.monster_entities[0]
	enemy.hex_position = Vector2i(2, 0)
	enemy.current_hp = 30
	enemy.max_hp = 30
	combat._update_grid_entities()

	# Set up world objects in combat
	var loose_pebble := CombatObjectRules.make_dropped_item({"instance_id": "b030_pebble_1", "definition_id": "fixture:030_iron_pebble", "state": {}}, Vector2i(1, 0), "")
	var unknown_gadget := {"id": "b030_gadget_1", "instance_id": "b030_gadget_1", "name": "Unknown Gadget", "definition_id": "fixture:030_unknown_gadget", "hp": 10, "max_hp": 10, "removed": false}
	var fixed_anvil := {"id": "b030_anvil_1", "instance_id": "b030_anvil_1", "name": "Iron Anvil", "definition_id": "fixture:030_iron_anvil", "fixed": true, "weight_lb": 200.0, "material": "iron", "hp": 50, "max_hp": 50, "removed": false}

	combat.hex_grid.add_entity({"world_object": loose_pebble, "hex_position": Vector2i(1, 0)})
	combat.hex_grid.add_entity({"world_object": unknown_gadget, "hex_position": Vector2i(1, 1)})
	combat.hex_grid.add_entity({"world_object": fixed_anvil, "hex_position": Vector2i(0, 2)})

	# 1. S-032 Live Physical Eligibility & Unknown Refusal
	var catapult_spell: Dictionary = DataLoader.get_spell("fixture:030_catapult_loose_object")
	var catapult_reqs: Dictionary = catapult_spell.get("physical_requirements", {})

	# Unknown gadget has unknown weight and status -> REFUSED
	var eval_unknown := PhysicalFactsRules.evaluate_physical_eligibility(unknown_gadget, catapult_reqs)
	h._assert(not eval_unknown.eligible, "030 live targeting refuses object with unknown mass/status")
	h._assert("unknown" in eval_unknown.reason.to_lower(), "030 live refusal reason explicitly identifies unknown fact")

	# Loose 1 lb iron pebble -> ELIGIBLE
	var eval_pebble := PhysicalFactsRules.evaluate_physical_eligibility(loose_pebble, catapult_reqs)
	h._assert(eval_pebble.eligible, "030 live targeting accepts loose pebble under 5 lbs")

	# Fixed 200 lb anvil -> REFUSED
	var eval_anvil := PhysicalFactsRules.evaluate_physical_eligibility(fixed_anvil, catapult_reqs)
	h._assert(not eval_anvil.eligible, "030 live targeting refuses fixed 200 lb anvil")

	# 2. S-033 Live Space Availability Queries (Side-Effect Free)
	var tiles_before: int = combat.hex_grid.tiles.size()
	var entities_before: int = combat.hex_grid.entities.size()

	# Query open hex (0, 1)
	var space_open: Dictionary = PhysicalFactsRules.is_space_available(combat.hex_grid, Vector2i(0, 1), "medium", "material", {"players": combat.player_entities, "monsters": combat.monster_entities, "ignore_entity": explorer})
	h._assert(space_open.available, "030 live open hex on material plane has available space")

	# Query occupied hex (2, 0) where enemy stands
	var space_occupied: Dictionary = PhysicalFactsRules.is_space_available(combat.hex_grid, Vector2i(2, 0), "medium", "material", {"players": combat.player_entities, "monsters": combat.monster_entities, "ignore_entity": explorer})
	h._assert(not space_occupied.available, "030 live occupied enemy hex refuses medium body space")

	# Query fixed anvil hex (0, 2)
	var space_anvil: Dictionary = PhysicalFactsRules.is_space_available(combat.hex_grid, Vector2i(0, 2), "medium", "material", {"players": combat.player_entities, "monsters": combat.monster_entities, "ignore_entity": explorer})
	h._assert(not space_anvil.available, "030 live fixed object hex refuses body space")

	# Query ethereal plane on material grid
	var space_ethereal: Dictionary = PhysicalFactsRules.is_space_available(combat.hex_grid, Vector2i(0, 1), "medium", "ethereal", {"players": combat.player_entities, "monsters": combat.monster_entities, "ignore_entity": explorer})
	h._assert(not space_ethereal.available, "030 live cross-planar query refused without planar traversal")

	# Verify side-effect free: nothing was added, removed, or moved
	h._assert(combat.hex_grid.tiles.size() == tiles_before, "030 space query created no grid tiles")
	h._assert(combat.hex_grid.entities.size() == entities_before, "030 space query created no entities")

	# 3. S-179 Live Speeds, Hand Requirements, and Terrain Costs
	h._assert(combat.remaining_speed == 6.0, "030 initial combat speed is 6 hexes (30 ft)")

	# Test Hand Requirement for Climbing:
	# Equip two-handed greatsword -> 0 free hands
	explorer.inventory.equipped[Inventory.Slot.WEAPON] = "greatsword"
	combat.active_movement_mode = "climb"

	var can_climb_busy: bool = combat._player_can_enter(Vector2i(0, 1), explorer)
	h._assert(not can_climb_busy, "030 climbing refused when wielding two-handed weapon (0 free hands)")

	# Unequip weapon -> 2 free hands
	explorer.inventory.equipped.clear()
	var can_climb_free: bool = combat._player_can_enter(Vector2i(0, 1), explorer)
	h._assert(can_climb_free, "030 climbing permitted when hands are free")

	# Test Movement Refusal Spending 0 Distance:
	var initial_remaining: float = combat.remaining_speed
	# Attempt move to occupied hex (2, 0)
	var move_attempt: Dictionary = PhysicalFactsRules.attempt_movement_step(explorer, "walk", Vector2i.ZERO, Vector2i(2, 0), int(initial_remaining * 5), combat.hex_grid, "ground", "normal", {"players": combat.player_entities, "monsters": combat.monster_entities, "ignore_entity": explorer})
	h._assert(not move_attempt.success and move_attempt.refused, "030 movement step into occupied space is refused")
	h._assert(move_attempt.spent_distance_feet == 0, "030 movement refusal spends exactly 0 feet of distance")
	h._assert(move_attempt.remaining_budget_feet == int(initial_remaining * 5), "030 movement refusal preserves full movement budget")
	h._assert(move_attempt.unrelated_modes_spent == 0, "030 movement refusal leaves unrelated modes unaffected")

	# Test Terrain Costs:
	combat.active_movement_mode = "walk"
	# Add difficult terrain to hex (0, 1)
	var diff_coords: Array[Vector2i] = [Vector2i(0, 1)]
	combat.hex_grid.add_difficult_terrain("b030_mud", diff_coords)
	var walk_diff_cost: float = combat._player_movement_cost(Vector2i(0, 1), explorer)
	h._assert(walk_diff_cost == 2.0, "030 walking in difficult terrain costs 2.0 hexes (10 ft)")

	# Test Flying over ground difficult terrain:
	combat.active_movement_mode = "fly"
	var fly_diff_cost: float = combat._player_movement_cost(Vector2i(0, 1), explorer)
	h._assert(fly_diff_cost == 1.0, "030 flying ignores ground difficult terrain (1.0 hex / 5 ft)")

	combat.active_movement_mode = "walk"
	await _review_controls(h, combat, explorer, loose_pebble, unknown_gadget, fixed_anvil)
	await pause(h, 4)
	h._teardown_scene(combat)
	GameManager.test_mode = true
	DataLoader.load_all_data()
	h._exit_test()


static func _review_controls(h: Node, combat: Node, actor: Character, pebble: Dictionary, unknown: Dictionary, anvil: Dictionary) -> void:
	combat._cancel_pending_action()
	actor.inventory.equipped.clear()
	combat._reset_turn_action_economy()
	h._p_focus(combat, actor, false)
	combat._highlight_reachable()
	var modes: Array = []
	for index in combat.hud.movement_mode_picker.item_count: modes.append(combat.hud.movement_mode_picker.get_item_metadata(index))
	h._assert("climb" in modes and "swim" in modes, "030 actual picker exposes ordinary climb and swim without innate speeds")
	# A Dash allowance survives mode changes once, with spent distance retained.
	combat.remaining_speed = 6.0
	combat.extra_movement_speed_hexes = 0.0
	combat._grant_extra_movement_speed()
	combat.remaining_speed -= 2.0
	combat.hud.movement_mode_selected.emit("climb")
	h._assert(combat.active_movement_mode == "climb" and combat.remaining_speed == 10.0, "030 actual mode control does not duplicate Dash or refund spent distance")
	combat.hud.movement_mode_selected.emit("walk")
	h._assert(combat.remaining_speed == 10.0, "030 switching back cannot mint movement")
	combat.extra_movement_speed_hexes = 0.0
	actor.add_condition("prone", 10)
	combat.remaining_speed = 3.0
	combat.hud.movement_mode_selected.emit("climb")
	combat.hud.movement_mode_selected.emit("walk")
	h._assert(combat.remaining_speed == 3.0, "030 actual prone mode changes preserve existing movement allowance")
	actor.remove_condition("prone")
	combat.remaining_speed = 6.0
	combat.player_entities[0].hex_position = Vector2i.ZERO
	actor.add_condition("disengaging", 10)
	await combat._on_hex_clicked(Vector2i(2, 0))
	h._assert(combat.player_entities[0].hex_position == Vector2i.ZERO and combat.remaining_speed == 6.0, "030 actual movement click refuses enemy occupancy without spending distance")
	# Persist the actual objects through combat's normal grid refresh.
	unknown["position"] = [1, 1]
	anvil["position"] = [0, 2]
	for object in [pebble, unknown, anvil]:
		if object not in combat.dropped_combat_items: combat.dropped_combat_items.append(object)
	combat._update_grid_entities()
	await combat._on_hex_clicked(Vector2i(0, 2))
	h._assert(combat.player_entities[0].hex_position == Vector2i.ZERO and combat.remaining_speed == 6.0, "030 actual movement click refuses a fixed object without spending distance")
	await combat._on_hex_clicked(Vector2i(0, 1))
	h._assert(combat.player_entities[0].hex_position == Vector2i(0, 1) and combat.remaining_speed == 4.0, "030 actual movement click pays difficult-terrain cost once")
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.remaining_speed = 6.0
	var water := Vector2i(-1, 0)
	combat.hex_grid.tiles[water].terrain = HexTile.TerrainType.WATER
	combat._update_grid_entities()
	await combat._on_hex_clicked(water)
	h._assert(combat.player_entities[0].hex_position == Vector2i.ZERO and combat.remaining_speed == 6.0, "030 actual walk click refuses water without spending distance")
	combat.hud.movement_mode_selected.emit("swim")
	await combat._on_hex_clicked(water)
	h._assert(combat.player_entities[0].hex_position == water and combat.remaining_speed == 4.0, "030 actual ordinary swimming crosses water for ten feet")
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.hud.movement_mode_selected.emit("walk")
	combat.remaining_speed = 6.0
	combat._update_grid_entities()
	# Select a loaded spell with real source and slot controls, then target it.
	SpellPermissionChecks.grant_slot_permission(actor, ["fixture:030_catapult_loose_object"])
	actor.spell_slots = {"1":4}
	h._p_focus(combat, actor)
	h._assert(await Batch028Controls.pick_spell(h, combat, "fixture:030_catapult_loose_object"), "030 actual picker selects physical-target fixture")
	await combat._on_hex_clicked(Vector2i(1, 1))
	h._assert(actor.spell_slots["1"] == 4 and combat.turn_budget.action_available and int(unknown.hp) == 10, "030 actual cast refuses unknown facts before slot, Action or effects")
	await combat._on_hex_clicked(Vector2i(1, 0))
	h._assert(actor.spell_slots["1"] == 3 and not combat.turn_budget.action_available and int(pebble.hp) == 0, "030 actual cast accepts known loose copy and settles one slot, Action and damage")
	combat._cancel_pending_action()
	combat._reset_turn_action_economy()
	SpellPermissionChecks.grant_slot_permission(actor, ["fixture:030_planar_space_step"])
	actor.spell_slots["2"] = 4
	var cells: Array = []
	for coord in combat.hex_grid.tiles: cells.append([coord.x, coord.y])
	var room := LocalRoomRules.create({"id":"review030","cells":cells,"party_spawns":[[0,0]],"ceiling_feet":8,"plane":"material"}, [actor])
	GameManager.transition_context["local_room"] = room
	combat._update_grid_entities()
	combat.hud._show_spell_selection()
	var selected := false
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index].get("id") == "fixture:030_planar_space_step" and not combat.hud.spell_list.is_item_disabled(index):
			combat.hud._on_spell_selected(index)
			await Batch027Controls.answer(h, combat, "", "Level 2")
			selected = true
			break
	h._assert(selected, "030 actual picker loads integral JSON clearance requirement")
	var thp_before := actor.temp_hp
	await combat._on_hex_clicked(Vector2i.ZERO)
	h._assert(actor.spell_slots["2"] == 4 and combat.turn_budget.bonus_action_available and actor.temp_hp == thp_before, "030 actual spatial cast refuses authored clearance before payment")
	room.ceiling_feet = 20
	actor.feature_uses["plane"] = "ethereal"
	await combat._on_hex_clicked(Vector2i.ZERO)
	h._assert(actor.spell_slots["2"] == 4 and combat.turn_budget.bonus_action_available and actor.temp_hp == thp_before, "030 actual spatial cast refuses different caster plane before payment")
	actor.feature_uses.erase("plane")
	await combat._on_hex_clicked(Vector2i.ZERO)
	h._assert(actor.spell_slots["2"] == 3 and not combat.turn_budget.bonus_action_available and actor.temp_hp == 5, "030 actual spatial cast settles once after clearance and plane become legal")
	GameManager.transition_context.erase("local_room")
