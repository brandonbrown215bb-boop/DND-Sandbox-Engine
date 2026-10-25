class_name Batch066TravelControls
extends RefCounted
## Batch 066 (S-121/S-122): live combat Misty Step through the production cast
## path. Illegal arrivals refuse before the slot or Bonus Action; a legal one
## settles once; the paid slot survives a real save/load.

static func _cast(h: Node, combat: Node, dest: Vector2i) -> void:
	combat.pending_spell_data = DataLoader.get_spell("misty_step").duplicate(true)
	combat.pending_spell_data["_selected_spell_slot_level"] = 2
	combat.pending_action_type = "cast_spell"
	combat.call_deferred("_execute_player_spell", dest)
	for _frame in 180:
		await h.get_tree().process_frame
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action: break
	combat.pending_action_type = ""
	combat.pending_spell_data = {}

static func run(h: Node) -> void:
	h._enter_test("batch_066_travel_placement_flow")
	h._setup_world()
	var wizard: Character = h._fresh_char("Travel Wizard", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	wizard.known_spells.assign(["misty_step"])
	wizard.spell_slots["2"] = 2
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.current_player_idx = 0
	combat.active_character = wizard
	combat.active_combatant = {"is_player": true, "entity": wizard}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.remaining_attack_swings = 0
	var ogre: Dictionary = {"id": "b066_live_ogre", "name": "Travel Ogre", "size": "large", "creature_type": "giant", "hex_position": Vector2i(4, 0), "is_alive": true, "current_hp": 50, "max_hp": 50, "armor_class": 11, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {}, "spell_slots": {}}
	combat.monster_entities.clear()
	combat.monster_entities.append(ogre)
	combat._update_grid_entities()
	GameManager.test_mode = false
	var pos := func() -> Vector2i: return combat.player_entities[0].get("hex_position", Vector2i.ZERO)
	await _cast(h, combat, Vector2i(3, 0))
	h._assert(pos.call() == Vector2i.ZERO and int(wizard.spell_slots["2"]) == 2 and combat.turn_budget.bonus_action_available, "066 live a cell inside a Large creature's footprint refuses before the slot and Bonus Action")
	await _cast(h, combat, Vector2i(0, 7))
	h._assert(pos.call() == Vector2i.ZERO and int(wizard.spell_slots["2"]) == 2 and combat.turn_budget.bonus_action_available, "066 live an out-of-range destination refuses before paying")
	var wall: HexTile = combat.hex_grid.get_tile(Vector2i(0, 2))
	var wall_ok: bool = wall != null
	if wall_ok:
		wall.custom_properties["blocks_movement"] = true
		await _cast(h, combat, Vector2i(0, 2))
		wall.custom_properties["blocks_movement"] = false
	h._assert(wall_ok and pos.call() == Vector2i.ZERO and int(wizard.spell_slots["2"]) == 2 and combat.turn_budget.bonus_action_available, "066 live a walled destination refuses before paying")
	# Stale choice: the destination became occupied after it was chosen; the pre-commit recheck refuses.
	var cast := SpellCastContext.new()
	cast.caster = wizard
	cast.players = combat.player_entities
	cast.monsters = combat.monster_entities
	cast.grid = combat.hex_grid
	cast.player_index = 0
	cast.spell = DataLoader.get_spell("misty_step").duplicate(true)
	cast.target_coord = Vector2i(-2, 0)
	var fresh := SpellCastMovement.refuse_teleport_destination_reason(cast)
	ogre["hex_position"] = Vector2i(-2, 0)
	var stale := SpellCastMovement.refuse_teleport_destination_reason(cast)
	ogre["hex_position"] = Vector2i(4, 0)
	var charged: Array = []
	cast.spend_action_cost = func(kind): charged.append(kind)
	cast.teleport_settled = true
	var handled: bool = await SpellCastMovement._resolve_spell_cast_movement(cast)
	h._assert(handled and charged.is_empty() and pos.call() == Vector2i.ZERO, "066 live a settled teleport invocation never moves or charges twice")
	h._assert(fresh.is_empty() and not stale.is_empty(), "066 live a destination that becomes occupied after the choice is refused by the recheck")
	await _cast(h, combat, Vector2i(2, 0))
	h._assert(pos.call() == Vector2i(2, 0) and int(wizard.spell_slots["2"]) == 1 and not combat.turn_budget.bonus_action_available, "066 live a legal destination moves once and spends one slot and the Bonus Action")
	await _cast(h, combat, Vector2i(1, 0))
	h._assert(pos.call() == Vector2i(2, 0) and int(wizard.spell_slots["2"]) == 1, "066 live a second Misty Step without a Bonus Action spends nothing")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_066_travel_placement"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "066 live real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nc: Character = PartyManager.characters.get(wizard.character_id, null)
		h._assert(loaded and nc != null and int(nc.spell_slots.get("2", -1)) == 1, "066 live real load keeps exactly one spent slot")
		SaveManager.delete_save(slot)
	h._exit_test()
