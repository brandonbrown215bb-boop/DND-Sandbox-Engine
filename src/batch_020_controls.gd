class_name Batch020Controls
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("batch_020_suppression_aura_flow")
	h._setup_world()
	Batch020Checks.load_fixtures()
	while PlayerManager.get_player_count() < 3:
		PlayerManager.add_player("Aura party")
	var bearer := Batch020Checks.actor("b020_control_bearer", "fixture:condition_aura_plain")
	var recipient := Batch020Checks.actor("b020_control_recipient", "fighter")
	var second := Batch020Checks.actor("b020_control_second", "fixture:condition_aura_plain")
	var members: Array = [bearer, recipient, second]
	PartyManager.reset()
	for index in members.size():
		PlayerManager.set_player_character(index, members[index])
		PartyManager.register_player_character(index, members[index])
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	FighterChecks._seed_die(20, 20)
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for entry in combat.player_entities:
		var character: Character = entry.get("character")
		entry["hex_position"] = Vector2i(10, 0) if character == second else Vector2i.ZERO if character == bearer else Vector2i(2, 0)
	combat._update_grid_entities()
	recipient.add_condition("frightened", 3, "fear:control")
	h._assert(not recipient.has_condition("frightened"), "Batch 020 controls: active aura suppresses Frightened through combat projection")
	h._p_focus(combat, recipient)
	combat.remaining_speed = 6.0
	await combat._on_hex_clicked(Vector2i(3, 0))
	for _frame in 3:
		await h.get_tree().process_frame
	h._assert(combat.player_entities[combat.current_player_idx].get("hex_position") == Vector2i(3, 0) and recipient.has_condition("frightened"), "Batch 020 controls: real movement click leaves the aura and restores the unexpired condition")
	combat.remaining_speed = 6.0
	await combat._on_hex_clicked(Vector2i(2, 0))
	for _frame in 3:
		await h.get_tree().process_frame
	h._assert(combat.player_entities[combat.current_player_idx].get("hex_position") == Vector2i(2, 0) and not recipient.has_condition("frightened"), "Batch 020 controls: real movement click re-enters and suppresses the same retained condition")
	h._teardown_scene(combat)
	GameManager.test_mode = true
	DataLoader.load_all_data()
	h._exit_test()
