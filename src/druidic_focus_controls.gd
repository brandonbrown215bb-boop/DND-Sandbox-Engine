class_name DruidicFocusControls
extends RefCounted
## SRD 5.2.1 Druidic Focus (Quarterstaff), Somatic and Material components
## (srd.txt 5877-5887, 6382-6404) through the real local-room Equip and
## "Cast Water Walk" controls and the real combat spell menu. Refusals spend
## nothing; a legal cast spends exactly one slot.

const FOCUS := "druidic_focus_quarterstaff"


static func _druid(h: Node, id: String) -> Character:
	var druid := Character.new()
	druid.initialize("Focus Druid", "human", "druid", AbilityScores.new(), "equipment", ClassProgression.default_creation_choices("druid", "human"))
	druid.character_id = id
	h._assert(druid.inventory.get_weapon() == FOCUS and druid.inventory.get_equipped(Inventory.Slot.SHIELD) == "shield" and druid.inventory.backpack.count("sickle") == 1 and not druid.inventory.has_item("component_pouch"), "Option A Druid holds the focus and Shield, carries the Sickle, and has no pouch")
	return druid


static func _select_item(h: Node, view: LocalRoomView, definition_id: String) -> void:
	for index in view.items.item_count:
		var record: Dictionary = view.actor().inventory.get_instance(str(view.items.get_item_metadata(index)))
		if str(record.get("definition_id", "")) == definition_id:
			view.items.select(index)
			view.items.item_selected.emit(index)
			return
	h._assert(false, "Room item list offers %s" % definition_id)


static func run(h: Node) -> void:
	h._enter_test("druidic_focus_cast_flow")
	h._setup_world()
	var druid := _druid(h, "focus_room_druid")
	druid.known_spells.append("water_walk")
	h._own_class_spells(druid)
	PlayerManager.reset()
	PlayerManager.add_player("Focus seat")
	PlayerManager.set_player_character(0, druid)
	PartyManager.reset()
	PartyManager.register_player_character(0, druid)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	var room: Room
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: room = candidate
	h._assert(room != null, "Focus fixture enters an authored room")
	if room == null:
		h._teardown_scene(dungeon)
		h._exit_test()
		return
	dungeon.hex_grid.hex_clicked.emit(room.coord)
	await h.get_tree().process_frame
	var view := dungeon.local_view
	druid.spell_slots["3"] = 1
	# Sickle deliberately equipped beside the Shield: focus is stowed, no free hand.
	view.slots.select(Inventory.Slot.WEAPON)
	_select_item(h, view, "sickle")
	h._local_room_press(view, "Equip")
	view.refresh()
	h._assert(druid.inventory.get_weapon() == "sickle" and druid.inventory.backpack.has(FOCUS), "Room Equip control swaps in the Sickle and stows the focus")
	h._local_room_press(view, "Cast Water Walk")
	h._assert(int(druid.spell_slots.get("3", 0)) == 1 and not SpellEffects.has_spell(druid, "water_walk"), "Sickle plus Shield refuses Water Walk before payment; the slot is unspent")
	view.slots.select(Inventory.Slot.WEAPON)
	_select_item(h, view, FOCUS)
	h._local_room_press(view, "Equip")
	view.refresh()
	h._assert(druid.inventory.get_weapon() == FOCUS and druid.inventory.backpack.count("sickle") == 1, "Room Equip control re-holds the same focus copy")
	h._local_room_press(view, "Cast Water Walk")
	h._assert(int(druid.spell_slots.get("3", 0)) == 0 and SpellEffects.has_spell(druid, "water_walk"), "Shield plus held focus casts Water Walk through the room control, spending one slot")
	view.refresh()
	h._local_room_press(view, "Cast Water Walk")
	h._assert(int(druid.spell_slots.get("3", 0)) == 0 and ClassToolItemChecks.owned(druid) == ClassToolItemChecks.DRUID_A, "A repeated press pays nothing twice and consumes no gear")
	h._teardown_scene(dungeon)
	# Combat: real spell menu.
	var fighter := _druid(h, "focus_combat_druid")
	fighter.known_spells.assign(["produce_flame", "cure_wounds", "ice_knife"])
	h._own_class_spells(fighter)
	PlayerManager.set_player_character(0, fighter)
	PartyManager.reset()
	PartyManager.register_player_character(0, fighter)
	GameManager.current_state = GameManager.GameState.COMBAT
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	fighter.spell_slots["1"] = 2
	fighter.current_hp = 1
	var target := Batch085Controls._target("focus_dummy", Vector2i(2, 0))
	# Sickle plus Shield through the equipment control: V, S Cure Wounds refused before payment.
	Batch085Controls._turn(combat, fighter, target)
	var focus_id := fighter.inventory.equipped_instance_id(Inventory.Slot.WEAPON)
	var sickle_id := ""
	for record in fighter.inventory.backpack_instances():
		if str(record.definition_id) == "sickle": sickle_id = str(record.instance_id)
	h._assert(fighter.inventory.equipment_control_equip(Inventory.Slot.WEAPON, sickle_id, combat).get("success", false), "Combat equipment control swaps in the Sickle")
	await h._cast_menu_spell(combat, "cure_wounds", 1)
	for _i in 3:
		if combat.pending_action_type.is_empty(): break
		await combat._on_hex_clicked(Vector2i.ZERO)
	await Batch085Controls._settle(h, combat)
	h._assert(int(fighter.spell_slots.get("1", 0)) == 2 and combat.turn_budget.action_available and fighter.current_hp == 1, "Sickle plus Shield refuses Cure Wounds before payment; slot and Action unspent")
	combat.pending_action_type = ""
	combat.pending_spell_data = {}
	h._assert(fighter.inventory.equipment_control_equip(Inventory.Slot.WEAPON, focus_id, combat).get("success", false) and fighter.inventory.get_weapon() == FOCUS, "Combat equipment control re-holds the same focus copy")
	# Default option-A loadout (Shield + focus): Produce Flame (Bonus Action) and Cure Wounds (Action, one slot).
	Batch085Controls._turn(combat, fighter, target)
	await h._cast_menu_spell(combat, "produce_flame", 0)
	for _i in 3:
		if combat.pending_action_type.is_empty(): break
		await combat._on_hex_clicked(Vector2i.ZERO)
	await Batch085Controls._settle(h, combat)
	h._assert(combat.produce_flame_markers.has(fighter.character_id) and not combat.turn_budget.bonus_action_available and combat.turn_budget.action_available and int(fighter.spell_slots.get("1", 0)) == 2, "Shield plus focus casts Produce Flame: Bonus Action spent once, no slot")
	await h._cast_menu_spell(combat, "cure_wounds", 1)
	for _i in 3:
		if combat.pending_action_type.is_empty(): break
		await combat._on_hex_clicked(Vector2i.ZERO)
	await Batch085Controls._settle(h, combat)
	h._assert(fighter.current_hp > 1 and int(fighter.spell_slots.get("1", 0)) == 1 and not combat.turn_budget.action_available, "Shield plus focus casts Cure Wounds: one slot and the Action spent, HP restored (hp=%d)" % fighter.current_hp)
	fighter.spell_slots["1"] = 2
	Batch085Controls._turn(combat, fighter, target)
	await h._cast_menu_spell(combat, "ice_knife", 1)
	h._assert(combat.pending_action_type == "spell" and int(fighter.spell_slots.get("1", 0)) == 2, "Combat menu accepts Ice Knife (S, M) through the held focus without paying during selection")
	await combat._on_hud_action("cancel", {})
	h._assert(int(fighter.spell_slots.get("1", 0)) == 2 and combat.pending_action_type.is_empty(), "Cancelling Ice Knife spends nothing")
	Batch085Controls._turn(combat, fighter, target)
	await h._cast_menu_spell(combat, "ice_knife", 1)
	for _i in 3:
		if combat.pending_action_type.is_empty(): break
		await combat._on_hex_clicked(target.hex_position)
	await Batch085Controls._settle(h, combat)
	h._assert(int(fighter.spell_slots.get("1", 0)) == 1 and not combat.turn_budget.action_available and fighter.inventory.get_weapon() == FOCUS, "Ice Knife cast through the held focus spends exactly one slot and the Action; the focus stays held")
	h._teardown_scene(combat)
	h._exit_test()
