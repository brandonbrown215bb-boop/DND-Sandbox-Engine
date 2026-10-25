class_name ItemLifecycleControlsFlow
extends RefCounted

const ITEM := "fixture:item_lifecycle"
const RENAMED := "fixture:item_lifecycle_renamed"
const SLOT := "item_lifecycle_checkpoint"

static func load_fixtures() -> void:
	ItemFormReturnChecks.load_fixtures()
	if DataLoader.get_item(ITEM).is_empty(): DataLoader._load_json_file("res://data/fixtures/item_lifecycle/items.json", "item")

static func popup(h: Node, parent: Node) -> PopupMenu:
	for _f in 60:
		await h.get_tree().process_frame
		for child in parent.get_children():
			if child is PopupMenu and child.visible and not child.is_queued_for_deletion() and child.name == "ItemLifecyclePopup": return child
	return null

static func press(h: Node, menu: PopupMenu, index: int) -> void:
	if menu == null: return
	menu.hide() # Actual PopupMenu activation hides before id_pressed.
	menu.id_pressed.emit(index)
	for _f in 4: await h.get_tree().process_frame

static func begin_room(h: Node, view: LocalRoomView, id: String, kind: String) -> PopupMenu:
	view.refresh()
	for i in view.item_lifecycle_offers.item_count:
		var offer: Dictionary = view.item_lifecycle_offers.get_item_metadata(i)
		if offer.instance_id != id or offer.kind != kind: continue
		view.item_lifecycle_offers.select(i)
		for child in view.item_lifecycle_row.get_children():
			if child is Button and child.text == "Use item control": child.pressed.emit(); break
		var menu := await popup(h, view.panel)
		h._assert(menu != null, "Actual room %s chooser opened for exact copy %s" % [kind, id])
		return menu
	h._assert(false, "Room %s offer missing for %s" % [kind, id])
	return null

static func begin_combat(h: Node, combat: Node, id: String, kind: String) -> PopupMenu:
	combat.hud._show_feature_selection()
	for i in combat.hud.features_registered.size():
		var row: Dictionary = combat.hud.features_registered[i]
		if row.get("id") != "item_lifecycle_control": continue
		if row.offer.instance_id != id or row.offer.kind != kind: continue
		if combat.hud.feature_list.is_item_disabled(i):
			h._assert(false, "Combat %s unexpectedly unavailable: %s" % [kind, combat.hud.feature_list.get_item_text(i)])
			return null
		combat.hud._on_feature_selected(i)
		var menu := await popup(h, combat.hud)
		h._assert(menu != null, "Actual combat %s chooser opened for exact copy %s" % [kind, id])
		return menu
	h._assert(false, "Combat %s offer missing for %s" % [kind, id])
	return null

static func run(h: Node) -> void:
	h._enter_test("item_lifecycle_controls_flow")
	h._setup_world()
	load_fixtures()
	h._assert(DataLoader.get_load_errors().is_empty(), "Authored lifecycle fixtures pass production loading")
	var base: Dictionary = DataLoader.get_item(ITEM).actor_projection
	for patch in [{"activation": {"action_cost": "reaction"}}, {"activation": {"charges": -1}}, {"activation": {"bond_id": ""}}, {"activation": {"pool": "new_pool"}}, {"dismiss_cost": "reaction"}, {"placement": {"no_space": "overlap"}}]:
		var bad := base.duplicate(true)
		bad.merge(patch, true)
		h._assert(not ItemProjectionRules.policy_error(bad).is_empty(), "Unsupported lifecycle declaration refuses: %s" % str(patch))
	# A neutral source-declared class supplies the existing two-copy tool bond.
	var owner := Batch042Checks.linker(PlayerManager.get_player(0).character.character_id)
	owner.character_name = "Token Keeper"
	PlayerManager.set_player_character(0, owner)
	PartyManager.characters[owner.character_id] = owner
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: dungeon.hex_grid.hex_clicked.emit(candidate.coord); break
	await h.get_tree().process_frame
	var view := dungeon.local_view
	var state := view.state
	var room_key := dungeon.local_room_id
	# Authored room copies use world IDs rather than inventory allocator IDs.
	var first := "world:%s:token:0" % str(state.id)
	var source := LocalRoomRules.placed_item(state, {"instance_id": first, "definition_id": ITEM, "state": {"charges": 5}}, LocalRoomRules.coord(state.party_positions[owner.character_id]))
	state.objects.append(source)
	var taken := LocalRoomRules.interact(state, str(source.id), "take", owner, first)
	h._assert(taken.get("success", false) and not owner.inventory.get_instance(first).is_empty(), "World-source copy enters ordinary inventory without changing its identity")
	var second := Batch042Checks.add(owner, ITEM)
	var child := Batch042Checks.add(owner, "dagger")
	ContainerRules.put(owner.inventory, first, child, "pocket")
	var copy := owner.inventory.get_instance(first)
	copy.state["engraving"] = "original source"
	owner.inventory.update_instance(copy)
	owner.inventory.attune_instance(first, owner.character_id)
	owner.inventory.attune_instance(second, owner.character_id)
	view.refresh()
	var exact_rows := 0
	for i in view.item_lifecycle_offers.item_count:
		var offer: Dictionary = view.item_lifecycle_offers.get_item_metadata(i)
		if offer.kind == "project" and offer.instance_id in [first, second] and str(offer.text).contains(str(offer.instance_id)): exact_rows += 1
	h._assert(exact_rows == 2, "Item controls distinguish two identical names by stable copy identity")
	var menu := await begin_room(h, view, first, "bond")
	await press(h, menu, 0)
	h._assert(not BondRules.is_bonded(owner, Batch042Checks.TOTEM, first), "Room bond cancellation changes nothing")
	menu = await begin_room(h, view, first, "bond")
	await press(h, menu, 1)
	menu = await begin_room(h, view, second, "bond")
	await press(h, menu, 1)
	h._assert(BondRules.bonded(owner, Batch042Checks.TOTEM) == [first, second], "Room controls bond both exact identical copies independently")
	menu = await begin_room(h, view, first, "project")
	await press(h, menu, 0)
	h._assert(not ItemProjectionRules.is_projected(owner, first) and owner.inventory.get_instance(first).state.charges == 5, "Room projection cancellation preserves charges and original contents")
	menu = await begin_room(h, view, first, "project")
	if menu != null:
		owner.inventory.unattune_instance(first, owner.character_id)
		await press(h, menu, 1)
	h._assert(not ItemProjectionRules.is_projected(owner, first) and owner.inventory.get_instance(first).state.charges == 5, "Attunement changed during room chooser refuses before payment")
	owner.inventory.attune_instance(first, owner.character_id)
	menu = await begin_room(h, view, first, "project")
	await press(h, menu, 1)
	var actor_id := ItemProjectionRules.actor_id(first)
	h._assert(ItemProjectionRules.is_projected(owner, first) and state.created_actor_positions.has(actor_id) and view.grid.entities.any(func(e): return e.get("character") == ItemProjectionRules.actor(owner, first)) and owner.item_projections[first].copy.state.charges == 4 and owner.item_projections[first].copy.state.contents.pocket[0].instance_id == child, "Room projection appears at the chosen legal cell with exact contents and once-spent charges")
	h._assert(DungeonPersistence.local_error(state).is_empty(), "Room DTO accepts a live projected actor with its original world-source identity")
	menu = await begin_room(h, view, second, "release")
	await press(h, menu, 1)
	h._assert(BondRules.bonded(owner, Batch042Checks.TOTEM) == [first], "Room release selects only the second identical copy")
	menu = await begin_room(h, view, second, "bond")
	await press(h, menu, 1)
	# Encounter entry recovers the represented room actor; subsequent presses use Features.
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"], "local_room": state}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.3)
	for _f in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	h._p_focus(combat, owner)
	combat.resolving_player_action = false
	menu = await begin_combat(h, combat, second, "project")
	if menu != null: menu.hide()
	for _f in 4: await h.get_tree().process_frame
	h._assert(not ItemProjectionRules.is_projected(owner, second) and combat.turn_budget.action_available and owner.inventory.get_instance(second).state.charges == 5, "Closing combat projection chooser cancels without payment")
	menu = await begin_combat(h, combat, second, "project")
	if menu != null:
		var destination := Batch053Controls._hex(menu.get_item_text(1))
		var prior: Vector2i = combat.monster_entities[0].hex_position
		combat.monster_entities[0].hex_position = destination
		await press(h, menu, 1)
		combat.monster_entities[0].hex_position = prior
	h._assert(not ItemProjectionRules.is_projected(owner, second) and combat.turn_budget.action_available and owner.inventory.get_instance(second).state.charges == 5, "Occupied combat destination revalidates immediately before payment")
	menu = await begin_combat(h, combat, second, "project")
	combat.turn_budget.action_available = false
	combat.turn_budget.surge_actions = 1
	await press(h, menu, 1)
	h._assert(not ItemProjectionRules.is_projected(owner, second) and owner.inventory.get_instance(second).state.charges == 5, "Action spent while choosing refuses activation without charge loss")
	h._p_focus(combat, owner)
	menu = await begin_combat(h, combat, second, "project")
	var other: Character = PlayerManager.get_player(1).character
	owner.inventory.transfer_instance(second, other.inventory)
	await press(h, menu, 1)
	h._assert(not ItemProjectionRules.is_projected(owner, second) and other.inventory.get_instance(second).state.charges == 5 and combat.turn_budget.action_available, "Stale ownership cannot activate or spend another holder's exact copy")
	other.inventory.transfer_instance(second, owner.inventory)
	# Ownership loss prunes its old bond; restore through actual bond control.
	menu = await begin_combat(h, combat, second, "bond")
	await press(h, menu, 1)
	menu = await begin_combat(h, combat, second, "project")
	copy = owner.inventory.get_instance(second)
	copy.state.charges = 0
	owner.inventory.update_instance(copy)
	await press(h, menu, 1)
	h._assert(not ItemProjectionRules.is_projected(owner, second) and combat.turn_budget.action_available, "Exhausted exact-copy charges during chooser refuse before action payment")
	copy.state.charges = 5
	owner.inventory.update_instance(copy)
	menu = await begin_combat(h, combat, second, "project")
	await press(h, menu, 1)
	h._assert(ItemProjectionRules.is_projected(owner, first) and ItemProjectionRules.is_projected(owner, second) and ItemProjectionRules.actor(owner, first) != ItemProjectionRules.actor(owner, second) and owner.item_projections[second].copy.state.charges == 4 and not combat.turn_budget.action_available and Batch053Controls._no_overlap(combat), "Combat projects second identical copy into distinct actor and space for exactly one authored Magic action and charge")
	menu = await begin_combat(h, combat, second, "dismiss")
	ItemProjectionRules.revert(owner, second)
	combat._update_grid_entities()
	ItemProjectionRules.project(owner, second)
	ItemProjectionRules.attach(combat, owner, Batch031Controls._position(combat, owner))
	await press(h, menu, 1)
	h._assert(ItemProjectionRules.is_projected(owner, second) and combat.turn_budget.bonus_action_available, "Stale dismissal cannot end a later activation of the same exact copy")
	ItemProjectionRules.actor(owner, first).current_hp = 17
	menu = await begin_combat(h, combat, second, "dismiss")
	await press(h, menu, 1)
	h._assert(not ItemProjectionRules.is_projected(owner, second) and ItemProjectionRules.actor(owner, first).current_hp == 17 and owner.inventory.get_instance(second).state.charges == 4 and not combat.turn_budget.bonus_action_available, "Dismiss chooses second identical actor and pays its authored Bonus Action without refilling charges")
	# Renamed definition also uses automatic placement and explicit paid no-space.
	var renamed := Batch042Checks.add(owner, RENAMED)
	owner.inventory.attune_instance(renamed, owner.character_id)
	h._p_focus(combat, owner)
	menu = await begin_combat(h, combat, renamed, "project")
	h._assert(menu != null and menu.item_count == 2 and menu.get_item_text(1).begins_with("Project at"), "Authored automatic placement offers one reserved destination plus Cancel")
	await press(h, menu, 1)
	h._assert(ItemProjectionRules.is_projected(owner, renamed) and not combat.turn_budget.action_available, "Renamed definition projects through the same controls and authored cost")
	menu = await begin_combat(h, combat, renamed, "dismiss")
	await press(h, menu, 1)
	h._p_focus(combat, owner)
	var origin := Batch031Controls._position(combat, owner)
	var blocked_tiles := {}
	for hex in HexUtils.get_hexes_in_range(origin, 2):
		if combat.hex_grid.has_tile(hex):
			blocked_tiles[hex] = combat.hex_grid.tiles[hex].custom_properties.get("blocks_movement", false)
			if hex != origin: combat.hex_grid.tiles[hex].custom_properties["blocks_movement"] = true
	combat.hud._show_feature_selection()
	for i in combat.hud.features_registered.size():
		var row: Dictionary = combat.hud.features_registered[i]
		if row.get("id") == "item_lifecycle_control" and row.offer.instance_id == second and row.offer.kind == "project":
			combat.hud._on_feature_selected(i)
			break
	for _f in 4: await h.get_tree().process_frame
	h._assert(not ItemProjectionRules.is_projected(owner, second) and owner.inventory.get_instance(second).state.charges == 4 and combat.turn_budget.action_available, "Authored no-space refusal leaves the exact copy, charge and action untouched")
	menu = await begin_combat(h, combat, renamed, "project")
	h._assert(menu != null and menu.get_item_text(1).contains("no space"), "Authored paid no-space outcome asks for explicit confirmation")
	await press(h, menu, 0)
	h._assert(combat.turn_budget.action_available and owner.inventory.get_instance(renamed).state.charges == 4, "Canceling paid no-space leaves costs untouched")
	menu = await begin_combat(h, combat, renamed, "project")
	await press(h, menu, 1)
	h._assert(not ItemProjectionRules.is_projected(owner, renamed) and owner.inventory.get_instance(renamed).state.charges == 3 and not combat.turn_budget.action_available, "Declared no-space spend pays once without moving or recreating the original copy")
	for hex in blocked_tiles: combat.hex_grid.tiles[hex].custom_properties["blocks_movement"] = blocked_tiles[hex]
	# Full inventory return uses the already delivered legal ground policy.
	h._p_focus(combat, owner)
	ItemFormReturnChecks.fill(owner)
	menu = await begin_combat(h, combat, first, "dismiss")
	await press(h, menu, 1)
	var ground := ItemFormReturnControls.find(state, first)
	h._assert(not ItemProjectionRules.is_projected(owner, first) and not ground.is_empty() and ground.state.charges == 4 and ground.state.contents.pocket[0].instance_id == child and ground.state.engraving == "original source" and owner.inventory.backpack.size() == 40, "Full-inventory Dismiss returns original copy and contents to legal room ground with charges intact")
	GameManager.test_mode = true
	await combat._end_battle("victory")
	h._teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	# Re-project the second copy through room controls so a live form recovers too.
	menu = await begin_room(h, view, second, "project")
	await press(h, menu, 1)
	h._assert(ItemProjectionRules.is_projected(owner, second) and owner.item_projections[second].copy.state.charges == 3, "Room control projects again without refilling the returned copy")
	GameManager.remember_dungeon()
	h._teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {}
	GameManager.active_dungeon_state.clear()
	var manifest := {"pid": OS.get_process_id(), "owner": owner.character_id, "first": first, "second": second, "child": child, "room_key": room_key}
	h._assert(SaveManager.save_game(SLOT), "Normal allowed checkpoint accepts control-created exact item lifecycle")
	var file := FileAccess.open("user://item_lifecycle_manifest.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(manifest)); file.close()
	h._assert(verify(manifest), "Disk checkpoint recovers exact original identity, contents, spent charges and independent second copy")
	h._exit_test()

static func verify(manifest: Dictionary) -> bool:
	if not SaveManager.load_game(SLOT): return false
	var owner: Character = PartyManager.characters.get(str(manifest.owner))
	var room: Dictionary = GameManager.dungeon_snapshots.get("ruins_of_ashvale", {}).get("local_rooms", {}).get(str(manifest.room_key), {})
	if owner == null: return false
	var first := ItemFormReturnControls.find(room, str(manifest.first))
	if not ItemProjectionRules.is_projected(owner, str(manifest.second)): return false
	var second: Dictionary = owner.item_projections[manifest.second].copy
	return not first.is_empty() and first.state.charges == 4 and first.state.engraving == "original source" and first.state.contents.pocket[0].instance_id == manifest.child and second.state.charges == 3 and room.get("created_actor_positions", {}).has(ItemProjectionRules.actor_id(str(manifest.second))) and owner.inventory.get_instance(str(manifest.second)).is_empty() and BondRules.is_bonded(owner, Batch042Checks.TOTEM, str(manifest.second)) and not BondRules.is_bonded(owner, Batch042Checks.TOTEM, str(manifest.first)) and DungeonPersistence.local_error(room).is_empty()
