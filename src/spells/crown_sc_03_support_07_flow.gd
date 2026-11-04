class_name CrownSc03Support07Flow
extends RefCounted

static func run(h) -> void:
	h._enter_test("crown_sc_03_support_07_flow")
	h._setup_world()
	var wizard := ConversionBatch002Checks.actor("crown-sc03s7-wizard", "wizard", 1)
	while wizard.level < 5: wizard.level_up()
	var book: Array[String] = ["shatter"]
	for option in DataLoader.get_castable_spell_list_options(wizard.get_spell_list_ids()):
		if book.size() >= wizard.wizard_spellbook_pending: break
		if int(option.get("level", 0)) in [1, 2, 3] and str(option.id) not in book: book.append(str(option.id))
	ClassProgression.choose_wizard_spellbook(wizard, book)
	CrownSc03Support04Flow._prepare_keeping(wizard, "shatter")
	wizard.inventory.add_item("component_pouch")
	wizard.spell_slots = {"2": 3, "3": 2}
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	h._assert(not combat.hex_grid.has_tile(Vector2i(5, 0)) and Targeting.is_in_range(Vector2i.ZERO, Vector2i(5, 0), 12), "SC-03 support 07: (5,0) is in Shatter range but has no map tile")
	var golem := CrownSc01Support01Flow._monster("g", Vector2i(5, 0), 10, {"CON": 10})
	combat.monster_entities.clear()
	combat.monster_entities.assign([golem])
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.turn_budget.action_available = true
	ConversionBatch002Flow._select(h, combat, wizard, "shatter", 3)
	await combat._on_hex_clicked(Vector2i(5, 0))
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(int(wizard.spell_slots.get("3", 0)) == 2 and int(wizard.spell_slots.get("2", 0)) == 3, "SC-03 support 07: off-map area center refused before the slot is spent")
	h._assert(combat.turn_budget.action_available and golem.current_hp == 1000, "SC-03 support 07: refused cast keeps the action and deals nothing")
	h._assert("Choose a point on the map for the center of Shatter" in combat.hud.log_text.text, "SC-03 support 07: refusal is logged")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	h._exit_test()
