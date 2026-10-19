class_name Batch027Controls
extends RefCounted

static func popup(h: Node, combat: Node, title: String) -> PopupMenu:
	for frame in 30:
		await h.get_tree().process_frame
		var menu: PopupMenu = h._find_visible_exchange_popup(combat, title)
		if menu != null: return menu
	return null

static func answer(h: Node, combat: Node, title: String, text: String) -> bool:
	var menu := await popup(h, combat, title)
	if menu == null: return false
	if text.is_empty(): menu.hide()
	else:
		var found := false
		for index in menu.item_count:
			if menu.get_item_text(index).begins_with(text):
				menu.id_pressed.emit(menu.get_item_id(index))
				found = true
				break
		if not found: return false
	for frame in 4: await h.get_tree().process_frame
	return true

static func run(h: Node) -> void:
	h._enter_test("batch_027_protections_flow")
	h._setup_world()
	Batch027Checks.load_fixtures()
	while PlayerManager.get_player_count() < 3: PlayerManager.add_player("Protection party")
	var supplier := Batch027Checks.actor("b027_control_supplier", "fixture:027_class_plain")
	supplier.ability_scores.from_dict({"STR":10, "DEX":20, "CON":12, "INT":10, "WIS":10, "CHA":16})
	var other := Batch027Checks.actor("b027_control_other", "fixture:027_class_renamed")
	var recipient := Batch027Checks.actor("b027_control_recipient")
	var members: Array = [supplier, other, recipient]
	for member in members:
		member.max_hp = 100
		member.current_hp = 100
	PartyManager.reset()
	for index in members.size():
		PlayerManager.set_player_character(index, members[index])
		PartyManager.register_player_character(index, members[index])
	GameManager.transition_context = {"terrain":"plains", "monster_ids":["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	FighterChecks._seed_die(20, 20)
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	# Let any naturally selected opening monster turn finish before focusing a seat.
	# Replacing active_combatant during its delayed AI callback corrupts the harness.
	for frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	h._assert(combat.active_combatant.get("is_player", false), "027 initial turn settles on a player before controlled inputs")
	for entry in combat.player_entities:
		entry.hex_position = Vector2i.ZERO if entry.character == supplier else Vector2i(1, 0) if entry.character == other else Vector2i(2, 0)
	combat._update_grid_entities()
	var fid := "fixture:027_guard_plain"
	var source := Batch027Checks.source(supplier, fid)
	h._p_focus(combat, supplier)
	recipient.temp_hp = 12
	h._assert(h._p_select(combat, fid, source), "027 actual source-owned feature menu opens")
	h._assert(await answer(h, combat, "Temporary HP recipient", recipient.character_name), "027 actual recipient popup selects another actor")
	h._assert(await answer(h, combat, "Temporary HP: keep", "Keep"), "027 actual keep button answers the offer")
	h._assert(recipient.temp_hp == 12 and recipient.linked_temporary_hp.is_empty() and supplier.numeric_resource_pools[source].current == 4 and combat.turn_budget.bonus_action_available, "027 keep control preserves old supplier/clock and pays nothing")
	h._p_select(combat, fid, source)
	await answer(h, combat, "Temporary HP recipient", recipient.character_name)
	await answer(h, combat, "Temporary HP: keep", "Replace")
	var grant := recipient.linked_temporary_hp.duplicate(true)
	h._assert(recipient.temp_hp == 8 and grant.get("supplier_id") == supplier.character_id and not combat.turn_budget.bonus_action_available and supplier.numeric_resource_pools[source].current == 3, "027 replace control accepts smaller HP and commits exact source/action once")
	h._assert(not h._p_select(combat, fid, source), "027 repeated feature click cannot spend an unavailable Bonus Action")
	h._p_focus(combat, supplier)
	h._p_select(combat, fid, source)
	await answer(h, combat, "Temporary HP recipient", recipient.character_name)
	await answer(h, combat, "Temporary HP: keep", "")
	h._assert(recipient.linked_temporary_hp == grant and supplier.numeric_resource_pools[source].current == 3 and combat.turn_budget.bonus_action_available and not combat.resolving_player_action, "027 cancel control preserves grant and releases controls")
	h._p_select(combat, fid, source)
	await answer(h, combat, "Temporary HP recipient", recipient.character_name)
	recipient.absorb_temporary_hp(1)
	await answer(h, combat, "Temporary HP: keep", "Replace")
	h._assert(recipient.temp_hp == 7 and recipient.linked_temporary_hp == grant and supplier.numeric_resource_pools[source].current == 3 and combat.turn_budget.bonus_action_available, "027 stale actual offer refuses after HP changes without paying")
	h._p_select(combat, fid, source)
	await answer(h, combat, "Temporary HP recipient", recipient.character_name)
	await answer(h, combat, "Temporary HP: keep", "Keep")
	h._assert(recipient.temp_hp == 7 and recipient.linked_temporary_hp == grant, "027 keeping partly absorbed HP does not refill it or restart its deadline")
	# Renamed supplier-target benefit through the same production route.
	h._p_focus(combat, other)
	var other_id := "fixture:027_guard_renamed"
	var other_source := Batch027Checks.source(other, other_id)
	var supplier_ac := other.get_ac()
	h._p_select(combat, other_id, other_source)
	await answer(h, combat, "Temporary HP recipient", recipient.character_name)
	await answer(h, combat, "Temporary HP: keep", "Replace")
	h._assert(recipient.temp_hp == 5 and recipient.linked_temporary_hp.get("supplier_id") == other.character_id and other.get_ac() == supplier_ac+3, "027 renamed consumer projects linked protection onto the supplier")
	recipient.absorb_temporary_hp(1)
	h._assert(other.get_ac() == supplier_ac+3, "027 supplier protection survives partial absorption")
	recipient.absorb_temporary_hp(99)
	h._assert(other.get_ac() == supplier_ac and recipient.linked_temporary_hp.is_empty(), "027 actual HP absorption removes supplier protection when qualifying HP ends")
	# Aura choice comes from the feature menu; movement must preserve the timed entry.
	h._p_focus(combat, recipient)
	h._assert(h._p_select(combat, "choose_aura_protection"), "027 actual aura protection menu exists")
	h._assert(await answer(h, combat, "Choose aura protection", other.character_id), "027 actual aura popup chooses the second supplier")
	var receipts := recipient.aura_entry_receipts.duplicate(true)
	h._assert(AuraProtectionRules.bonus(recipient, "ac_bonus") == 3 and AuraProtectionRules.bonus(recipient, "save_bonus") == 2, "027 chosen overlapping aura supplies only selected AC/save benefit")
	combat.remaining_speed = 8.0
	await combat._on_hex_clicked(Vector2i(4, 0))
	for frame in 4: await h.get_tree().process_frame
	h._assert(combat.player_entities[combat.current_player_idx].hex_position == Vector2i(4, 0) and recipient.aura_entry_receipts == receipts and AuraProtectionRules.bonus(recipient, "ac_bonus") == 3, "027 actual movement exits both auras while retaining chosen timed protection")
	combat.remaining_speed = 8.0
	await combat._on_hex_clicked(Vector2i(2, 0))
	for frame in 4: await h.get_tree().process_frame
	h._assert(recipient.aura_entry_receipts == receipts, "027 actual movement reentry cannot restart entry use")
	var old_clock := int(GameManager.campaign_elapsed_seconds)
	GameManager.campaign_elapsed_seconds = 30
	combat._update_grid_entities()
	h._assert(AuraProtectionRules.offers(recipient).is_empty() and recipient.aura_entry_receipts == receipts, "027 expiry after movement ends benefit without deleting anti-reentry receipt")
	GameManager.campaign_elapsed_seconds = old_clock
	h._p_focus(combat, supplier)
	h._p_select(combat, fid, source)
	await answer(h, combat, "Temporary HP recipient", recipient.character_name)
	h._assert(recipient.temp_hp == 8 and recipient.linked_temporary_hp.get("supplier_id") == supplier.character_id, "027 zero-HP recipient accepts without an unnecessary replacement popup")
	ResourcePoolRules.remove(supplier, source)
	h._assert(recipient.temp_hp == 0 and recipient.linked_temporary_hp.is_empty(), "027 exact supplier source removal clears cross-actor HP and linked protection")
	# Range-only protection must end when the combat position owner goes away.
	var membership_source := Batch027Checks.actor("b027_exit_membership", "fixture:027_membership_class")
	supplier.features.append(membership_source.get_feature("fixture:027_membership_feature").duplicate(true))
	combat._update_grid_entities()
	h._assert(AuraProtectionRules.offers(recipient, "membership_guard").size() == 1, "027 membership protection is active before combat exit")
	var exit_receipts := recipient.aura_entry_receipts.duplicate(true)
	h._teardown_scene(combat)
	h._assert(AuraProtectionRules.offers(recipient, "membership_guard").is_empty() and AuraProtectionRules.bonus(recipient, "ac_bonus") == 3 and recipient.aura_entry_receipts == exit_receipts, "027 combat exit drops membership protection and retains timed entry receipts")
	GameManager.test_mode = true
	DataLoader.load_all_data()
	h._exit_test()
