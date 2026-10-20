class_name Batch042Controls
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("batch_042_linked_projection_flow")
	h._setup_world()
	Batch042Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var fig := Batch042Checks.add(a, Batch042Checks.FIGURINE)
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 1)
		entry["has_turn"] = true
	var enemy: Dictionary = combat.monster_entities[0]
	enemy["hex_position"] = Vector2i(2, 0)
	combat._update_grid_entities()
	# S-165: the exact carried copy becomes its actor and joins the owner's side.
	var r := ItemProjectionRules.project(a, fig)
	var joined := ItemProjectionRules.attach(combat, a, Vector2i.ZERO)
	var hound := ItemProjectionRules.actor(a, fig)
	h._assert(r.get("projected", false) and joined == [hound.character_id] and not a.inventory.has_item(Batch042Checks.FIGURINE) and combat.player_entities.any(func(e): return e.get("combat_id", "") == hound.character_id), "042 actual copy projects into its hound, leaves the inventory and joins the owner's side")
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, hound.character_name, 0)
	var hit_ac := int(combat.last_monster_weapon_attack_result.get("target_ac", -1))
	var damaged := hound.current_hp
	h._assert(hit_ac == 14 and damaged < 22, "042 actual monster attack reads the projected actor's AC and damages it (ac=%d hp=%d)" % [hit_ac, damaged])
	# S-162: real gear removal settles the declared linked fate exactly.
	var prior_features := a.features.duplicate(true)
	a.features.append(DataLoader.get_character_class(Batch042Checks.CLASS_ID).features_by_level["1"][0].duplicate(true))
	var weapon := a.inventory.equipped_instance_id(Inventory.Slot.WEAPON)
	var mate := Batch042Checks.add(a, "dagger")
	var loose := Batch042Checks.add(a, "dagger")
	var b1 := BondRules.bond(a, Batch042Checks.PAIR, weapon)
	var b2 := BondRules.bond(a, Batch042Checks.PAIR, mate)
	var dropped := a.inventory.drop_equipped_instance(Inventory.Slot.WEAPON)
	h._assert(b1.get("bonded", false) and b2.get("bonded", false) and str(dropped.get("instance_id", "")) == weapon and not Batch042Checks.owns(a, mate) and Batch042Checks.owns(a, loose) and BondRules.bonded(a, Batch042Checks.PAIR).is_empty(), "042 actual drop of one linked weapon disposes exactly its linked mate (weapon=%s)" % weapon)
	a.inventory.receive_instance(dropped)
	a.inventory.equip_instance(Inventory.Slot.WEAPON, weapon)
	a.inventory.destroy_instance(loose)
	a.features = prior_features
	a.exclusive_bonds.clear()
	h._teardown_scene(combat)
	# Real SaveManager round trip in session with the projected copy live.
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var slot := "batch_042_projection"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "042 actual real save with a projected copy (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var na: Character = PartyManager.characters.get(a.character_id, null)
		var back := ItemProjectionRules.actor(na, fig) if na != null else null
		h._assert(loaded and na != null and na != a and back != null and back != hound and back.current_hp == damaged and not na.inventory.has_item(Batch042Checks.FIGURINE), "042 actual real load rebuilds the same hound with its damage and keeps the copy out of the inventory")
		if na != null:
			var rev := ItemProjectionRules.revert(na, fig)
			h._assert(rev.get("reverted", false) and Batch042Checks.owns(na, fig) and na.inventory.count_item(Batch042Checks.FIGURINE) == 1 and ItemProjectionRules.actor(na, fig) == null, "042 actual reversion after reload returns the exact copy once")
			na.inventory.destroy_instance(fig)
		SaveManager.delete_save(slot)
	h._exit_test()
