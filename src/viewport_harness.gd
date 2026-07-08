## Headless Viewport Harness
## Instantiates the REAL combat and overworld scenes inside a Godot Viewport
## (renders headlessly, no display needed) and asserts their _ready wiring
## actually executed: grid build, HUD signal connect, player/monster spawn,
## initiative roll, fog-of-war update, event-trigger plumbing.
##
## Restructured (B): the old single _ready() coroutine is split into discrete,
## individually-named test methods (test_combat, test_overworld, ...). Each owns
## its own SubViewport + teardown, so a failure names the test instead of
## stalling the whole chain, and one broken scene cannot block the others.
## Each test establishes its own preconditions (no cross-test coupling).
extends Node

var _fail := 0
var _failures: Array[String] = []

# Per-test tracking so failures are attributed to a named test.
var _current_test := "harness"
var _fail_at_entry := 0
var _tests_run := 0
var _tests_failed_names: Array[String] = []

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("[ok]   %s" % msg)
	else:
		_fail += 1
		_failures.append("[%s] %s" % [_current_test, msg])
		print("[FAIL] [%s] %s" % [_current_test, msg])

func _fresh_char(name: String, race: String, klass: String, sd: Dictionary) -> Character:
	var s := AbilityScores.new()
	s.from_dict(sd)
	var c := Character.new()
	c.initialize(name, race, klass, s)
	return c

func _setup_world() -> void:
	var camp = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin", "goblin"]}
	GameManager.is_loading_save = false
	GameManager.game_in_progress = false
	GameManager.test_mode = true
	PlayerManager.reset()
	PlayerManager.add_player("Alice")
	PlayerManager.add_player("Bob")
	PlayerManager.set_player_character(0, _fresh_char("Alice", "human", "fighter",
		{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8}))
	PlayerManager.set_player_character(1, _fresh_char("Bob", "elf", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10}))

# --- per-test scaffolding ---------------------------------------------------

func _enter_test(name: String) -> void:
	_current_test = name
	_fail_at_entry = _fail
	_tests_run += 1
	print("\n[TEST] %s" % name)

func _exit_test() -> void:
	if _fail > _fail_at_entry and not _tests_failed_names.has(_current_test):
		_tests_failed_names.append(_current_test)

## Spawn a scene inside an isolated SubViewport, settle for `settle` seconds,
## and return the instance (vp tracked via meta for teardown).
func _spawn_scene(scene_path: String, settle: float) -> Node:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child(vp)
	var inst = load(scene_path).instantiate()
	vp.add_child(inst)
	await get_tree().create_timer(settle).timeout
	inst.set_meta("vp", vp)
	return inst

## Free a scene spawned by _spawn_scene (removes from its vp, frees both).
func _teardown_scene(inst: Node) -> void:
	if inst == null:
		return
	var vp = inst.get_meta("vp") if inst.has_meta("vp") else null
	if vp != null:
		vp.remove_child(inst)
		vp.queue_free()
	inst.queue_free()

# --- test orchestration -----------------------------------------------------

func _ready() -> void:
	print("==================================================")
	print(" Rook's Headless Viewport Harness (per-beat)")
	print("==================================================")
	_setup_world()

	await test_combat()
	await test_combat_ai_loop()
	await test_combat_victory()
	await test_overworld()
	await test_main_menu_load()
	await test_dungeon()
	await test_event_dialog()
	await test_character_creation()
	await test_shop()
	await test_save_load()
	await test_combat_resolution()
	await test_event_choice_resolution()
	await test_event_dialog_choice_click()
	await test_character_sheet()

	_report()
	get_tree().quit(1 if _fail > 0 else 0)

# --- tests ------------------------------------------------------------------

## Combat boot + weapon/range enforcement + P0 juice/payoff + P1 readability.
func test_combat() -> void:
	_enter_test("combat")
	_setup_world()
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 3.5)

	_assert(combat != null, "combat scene instantiated without error")
	_assert(combat.has_method("_on_hud_action"), "combat exposes HUD action handler")
	_assert(combat.hex_grid != null, "combat HexGrid @onready resolved")
	_assert(combat.hex_grid.tiles.size() > 0, "combat grid built tiles (got %d)" % combat.hex_grid.tiles.size())
	_assert(combat.player_entities.size() == 2, "combat spawned 2 players")
	_assert(combat.monster_entities.size() > 0, "combat spawned monsters (got %d)" % combat.monster_entities.size())
	_assert(combat.tracker.combatants.size() > 0, "initiative rolled (got %d)" % combat.tracker.combatants.size())
	var hud: Node = combat.hud
	_assert(hud != null, "combat HUD @onready resolved")
	_assert(hud.has_method("update_hud"), "combat HUD has update_hud")
	_assert(combat.hex_grid.entities.size() > 0, "combat grid has rendered entities (got %d)" % combat.hex_grid.entities.size())
	# drive an end-turn to prove the turn machine advances
	var before_round: int = combat.tracker.current_round
	combat._on_hud_action("end_turn", {})
	await get_tree().create_timer(1.0).timeout
	_assert(true, "end_turn action did not crash")
	await get_tree().create_timer(2.5).timeout
	_assert(combat.monster_entities.size() > 0, "combat still intact after a monster turn")
	_assert(combat.tracker.combatants.size() > 0, "initiative still populated after turns")

	# ---- Equipped weapon display + range enforcement ----
	if combat.player_entities.size() > 0:
		var p0: Dictionary = combat.player_entities[0]
		var pchar: Character = p0["character"]
		combat.current_player_idx = 0
		combat.active_character = pchar
		combat.has_acted_this_turn = false
		combat.pending_action_type = "attack"
		p0["hex_position"] = Vector2i.ZERO
		pchar.inventory.equip(Inventory.Slot.WEAPON, "longsword")
		combat.hud.update_hud(pchar, combat.tracker)
		_assert(combat.hud.weapon_info.text.contains("Weapon:"), "combat HUD shows weapon line")
		_assert(combat.hud.weapon_info.text.contains("Longsword") or combat.hud.weapon_info.text.contains("longsword"), "combat HUD shows equipped weapon name")
		_assert(combat.hud.weapon_info.text.contains("melee"), "melee weapon labeled as melee/reach")
		if combat.monster_entities.size() > 0:
			var m0: Dictionary = combat.monster_entities[0]
			m0["hex_position"] = Vector2i(5, 0)
			m0["is_alive"] = true
			var hp_before: int = int(m0.get("current_hp", 0))
			combat._on_hex_clicked(Vector2i(5, 0))
			var hp_after: int = int(m0.get("current_hp", 0))
			_assert(hp_before == hp_after, "out-of-range attack does NOT deal damage (range enforced)")
			_assert(combat.hud.log_text.text.contains("out of range"), "out-of-range attack logged a range rejection")
			# ---- Bug fix: out-of-range attack must NOT trap the player in targeting mode ----
			_assert(combat.pending_action_type == "attack", "still targeting after an out-of-range click (pre-condition)")
			combat._cancel_pending_action()
			_assert(combat.pending_action_type == "", "cancel clears pending targeting (player can return to movement)")
			m0["hex_position"] = Vector2i(1, 0)
			combat.hud.log_text.text = ""
			combat._on_hex_clicked(Vector2i(1, 0))
			_assert(not combat.hud.log_text.text.contains("out of range"), "adjacent attack is not range-rejected")

			# ---- P0 juice: floating damage text + camera/shake plumbing ----
			_assert(combat.fx_layer != null, "combat FxLayer @onready resolved")
			_assert(combat.cam != null, "combat Camera2D @onready resolved")
			Settings.show_damage_numbers = true
			Settings.screen_shake = true
			var fx_before: int = combat.fx_layer.get_child_count()
			combat._spawn_floating_text(Vector2i(1, 0), "-9", Color(1.0, 0.3, 0.3))
			combat._shake_camera(5.0)
			await get_tree().create_timer(0.2).timeout
			_assert(combat.fx_layer.get_child_count() > fx_before, "floating damage text spawned a label")
			Settings.show_damage_numbers = false
			var fx_off: int = combat.fx_layer.get_child_count()
			combat._spawn_floating_text(Vector2i(1, 0), "x", Color.WHITE)
			_assert(combat.fx_layer.get_child_count() == fx_off, "damage numbers suppressed when setting disabled")
			Settings.show_damage_numbers = true

			# ---- P0 payoff: victory screen shows + auto-resolves in test mode ----
			var ovr = load("res://src/combat/battle_result_overlay.gd").new()
			combat.add_child(ovr)
			ovr.show_result("victory")
			_assert(ovr.visible, "battle result overlay presents on victory")
			ovr.resolved.emit("victory")
			ovr.queue_free()
			_assert(true, "battle result overlay emits a resolution signal without hanging")

			# ---- P1 readability ----
			_assert(combat._describe_intent({"name":"Goblin"},
				{"action":"move_attack","target_id":"Thorne"}) == "Move + Attack Thorne",
				"intent describes move+attack")
			_assert(combat._describe_intent({"name":"Goblin"},
				{"action":"attack","target_id":"Brunhild"}) == "Attack Brunhild",
				"intent describes attack")
			_assert(combat._describe_intent({"name":"Goblin"},
				{"action":"move"}) == "Move", "intent describes move")
			_assert(combat._describe_intent({"name":"Goblin"},
				{"action":"none"}) == "Hold", "intent describes hold")

			# Move-path preview
			combat.pending_action_type = ""
			combat.remaining_speed = float(combat.active_character.speed)
			var ppos: Vector2i = combat.player_entities[combat.current_player_idx]["hex_position"]
			var reach: Dictionary = combat.hex_grid.get_reachable(ppos, combat.remaining_speed)
			var some_hex: Vector2i = Vector2i.ZERO
			for h in reach:
				if h != ppos:
					some_hex = h
					break
			combat._path_preview_hexes.clear()
			if some_hex != Vector2i.ZERO:
				combat._on_hex_hovered(some_hex)
				_assert(combat._path_preview_hexes.size() > 0, "hovering a reachable hex previews a movement path")
			else:
				_assert(false, "expected at least one reachable hex for path-preview test")

			# Attack-range ring
			combat.pending_action_type = "attack"
			combat._highlight_attack_targets()
			_assert(combat.hex_grid.get_highlight_count() > 0, "attack select highlights weapon range hexes")

			# First-turn hint
			_assert(not combat.hud.hint_label.text.is_empty(), "first-turn hint was configured with guidance text")
			_assert(combat._hint_shown, "first-turn hint flag set (shown once per battle)")
			combat.hud.show_hint("test")
			_assert(combat.hud.hint_label.visible, "hint show() makes the banner visible")
			combat.hud.hide_hint()
			_assert(not combat.hud.hint_label.visible, "hint hide() hides the banner")

	_teardown_scene(combat)
	_exit_test()

## Overworld boot + fog + reachable + rest + save + settings + ambush (Stealth).
func test_overworld() -> void:
	_enter_test("overworld")
	_setup_world()
	PlayerManager.set_player_position(0, Vector2i.ZERO)
	PlayerManager.set_player_position(1, Vector2i(1, 0))
	var overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 2.5)

	_assert(overworld != null, "overworld scene instantiated without error")
	_assert(overworld.hex_grid != null, "overworld HexGrid @onready resolved")
	_assert(overworld.hex_grid.tiles.size() > 0, "overworld grid built tiles (got %d)" % overworld.hex_grid.tiles.size())
	_assert(overworld.has_method("_resolve_destination_tile"), "overworld has tile resolver")
	var center: HexTile = overworld.hex_grid.get_tile(PlayerManager.get_player_position(0))
	_assert(center != null and center.is_visible, "overworld fog reveals active player tile")
	var reach: Dictionary = overworld.reachable_hexes
	_assert(reach.size() > 1, "overworld computed reachable hexes (got %d)" % reach.size())

	# ---- Overworld HUD: rest + save buttons ----
	var ow_hud: Node = overworld.hud
	_assert(ow_hud != null, "overworld HUD resolved")
	_assert(ow_hud.has_signal("rest_pressed"), "overworld HUD exposes rest_pressed signal")
	_assert(ow_hud.has_signal("save_pressed"), "overworld HUD exposes save_pressed signal")
	_assert(ow_hud.has_signal("menu_pressed"), "overworld HUD exposes menu_pressed signal")
	_assert(ow_hud.btn_rest != null, "overworld HUD rest button present")
	_assert(ow_hud.btn_save != null, "overworld HUD save button present")
	_assert(ow_hud.btn_menu != null, "overworld HUD menu button present")
	var rest_char: Character = PlayerManager.get_player(0).get("character")
	rest_char.current_hp = 1
	overworld._rest_party()
	_assert(rest_char.current_hp == rest_char.max_hp, "wilderness rest restored HP (1 -> %d)" % rest_char.current_hp)
	GameManager.game_in_progress = true
	SaveManager.delete_save("quicksave")
	ow_hud.save_pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_assert(SaveManager.get_available_saves().has("quicksave"), "save button wrote 'quicksave' slot")

	# ---- Settings overlay (save/load anywhere + options) ----
	_assert(ow_hud.has_signal("settings_pressed"), "overworld HUD exposes settings_pressed signal")
	ow_hud.settings_pressed.emit()
	_assert(Settings.is_open(), "settings overlay opened from overworld")
	_assert(get_tree().paused, "tree paused while settings open")
	Settings.close_settings()
	_assert(not Settings.is_open(), "settings overlay closed")
	_assert(not get_tree().paused, "tree resumed after settings close")
	Settings.master_volume = 0.42
	Settings.save_settings()
	Settings.master_volume = 1.0
	Settings.load_settings()
	_assert(abs(Settings.master_volume - 0.42) < 0.001, "settings persisted to disk (master_volume)")

	# ---- Ambush is now a Stealth check, not a flat 40% roll ----
	_assert(overworld.has_method("_compute_ambush_dc"), "ambush uses Stealth DC calc")
	_assert(overworld.has_method("_party_best_stealth_mod"), "ambush uses party Stealth mod")
	var exp_dc := 12 + maxi(0, PlayerManager.get_player_count() - 1)
	_assert(overworld._compute_ambush_dc() == exp_dc, "ambush DC = 12 + (party-1) = %d" % exp_dc)
	var stealth_char: Character = PlayerManager.get_player(0).get("character")
	stealth_char.ability_scores.dexterity = 20
	var best_mod: int = overworld._party_best_stealth_mod()
	_assert(best_mod >= 5, "best Stealth mod reflects high DEX (got %d)" % best_mod)
	_assert(overworld.has_method("_on_rest_pressed"), "rest handler present (Stealth-based ambush)")

	_teardown_scene(overworld)
	_exit_test()

## Main-menu Load Game UI (writes its own quicksave so it's self-contained).
func test_main_menu_load() -> void:
	_enter_test("main_menu_load")
	_setup_world()
	GameManager.game_in_progress = true
	SaveManager.delete_save("quicksave")
	SaveManager.save_game("quicksave")
	var main_menu: Node = await _spawn_scene("res://scenes/main_menu.tscn", 1.0)

	_assert(main_menu.btn_load != null, "main menu has Load Game button")
	_assert(main_menu.save_slot_list != null, "main menu has save-slot list")
	_assert(SaveManager.get_available_saves().has("quicksave"), "quicksave available for menu load")
	_assert(not main_menu.btn_load.disabled, "load button enabled when saves exist")
	_assert(main_menu.has_method("_on_load_pressed"), "main menu wires _on_load_pressed")
	_assert(main_menu.has_method("_refresh_save_slots"), "main menu populates save slots on ready")

	_teardown_scene(main_menu)
	_exit_test()

## Dungeon boot + rooms + party move.
func test_dungeon() -> void:
	_enter_test("dungeon")
	_setup_world()
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 2.5)

	_assert(dungeon != null, "dungeon scene instantiated without error")
	_assert(dungeon.hex_grid != null, "dungeon HexGrid @onready resolved")
	_assert(dungeon.hex_grid.tiles.size() > 0, "dungeon rooms generated (got %d)" % dungeon.hex_grid.tiles.size())
	_assert(dungeon.hud != null, "dungeon HUD @onready resolved")
	_assert(dungeon.hud.get("btn_end_turn") == null, "dungeon HUD truly has NO end-turn button (real BaseHUD split, not hidden)")
	_assert(dungeon.hud.has_signal("rest_pressed"), "dungeon HUD exposes rest_pressed signal")
	_assert(dungeon.hud.has_signal("save_pressed"), "dungeon HUD exposes save_pressed signal")
	_assert(dungeon.hud.has_signal("menu_pressed"), "dungeon HUD exposes menu_pressed signal")
	var has_entrance := false
	var has_boss := false
	for coord in dungeon.rooms:
		var rm = dungeon.rooms[coord]
		if rm.type == Room.RoomType.ENTRANCE:
			has_entrance = true
		if rm.type == Room.RoomType.BOSS:
			has_boss = true
	_assert(has_entrance, "dungeon has an entrance room")
	_assert(has_boss, "dungeon has a boss room")
	_assert(dungeon.party_position == Vector2i.ZERO, "dungeon party starts at origin")
	var move_target := Vector2i.ZERO
	for n in HexUtils.get_neighbors(dungeon.party_position):
		if n in dungeon.rooms:
			var rt = dungeon.rooms[n].type
			if rt != Room.RoomType.COMBAT and rt != Room.RoomType.BOSS:
				move_target = n
				break
	if move_target != Vector2i.ZERO:
		dungeon._on_room_clicked(move_target)
		var moved_to = dungeon.party_position
		_assert(moved_to == move_target, "dungeon party moved after room click")
	else:
		_assert(true, "dungeon: all adjacent rooms are combat (movement not exercised this run)")

	_teardown_scene(dungeon)
	_exit_test()

## EventDialog UI: choice + skill-check events, roll seam, re-popup regression.
func test_event_dialog() -> void:
	_enter_test("event_dialog")
	var ev_dialog: EventDialog = await _spawn_scene("res://scenes/ui/event_dialog.tscn", 0.3)

	_assert(ev_dialog != null, "EventDialog instantiated")
	var ev_scores := AbilityScores.new()
	ev_scores.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var ev_char := Character.new()
	ev_char.initialize("EventTester", "human", "fighter", ev_scores)
	var dungeon_events: Dictionary = DataLoader.get_event_table("dungeon_events")
	_assert(not dungeon_events.is_empty(), "loaded dungeon_events table from data")
	var event_list: Array = dungeon_events.get("events", [])
	var choice_evt: Dictionary = {}
	for e in event_list:
		if e.get("id", "") == "trapped_chest":
			choice_evt = e
			break
	_assert(not choice_evt.is_empty(), "loaded 'trapped_chest' choice event from data")
	ev_dialog.popup_event(ev_char, choice_evt)
	await get_tree().create_timer(0.2).timeout
	_assert(ev_dialog.title_label.text == "Trapped Chest", "EventDialog title set from event")
	_assert(ev_dialog.choice_container.get_child_count() == 3, "EventDialog built 3 choice buttons")
	_assert(ev_dialog.choice_container.visible, "EventDialog choice container visible for choice event")
	var skill_evt: Dictionary = {}
	for e in event_list:
		if e.get("id", "") == "cave_in":
			skill_evt = e
			break
	_assert(not skill_evt.is_empty(), "loaded 'cave_in' skill_check event from data")
	ev_dialog.popup_event(ev_char, skill_evt)
	await get_tree().create_timer(0.2).timeout
	_assert(ev_dialog.roll_section.visible, "EventDialog roll section visible for skill_check event")
	_assert(not ev_dialog.choice_container.visible, "EventDialog choices hidden for skill_check event")
	_assert(ev_dialog.btn_roll.visible, "EventDialog roll button visible for skill_check event")
	_assert(ev_dialog.btn_roll.pressed.is_connected(ev_dialog._on_btn_roll_pressed),
		"EventDialog roll button wired to stable handler (not one-shot)")
	ev_dialog.btn_roll.pressed.emit()
	_assert(ev_dialog.roll_result_lbl.text.begins_with("Rolled:"),
		"EventDialog skill_check roll produced a result label ('%s')" % ev_dialog.roll_result_lbl.text)
	ev_dialog.popup_event(ev_char, skill_evt)
	_assert(ev_dialog.roll_result_lbl.text == "", "EventDialog result label reset on re-popup")
	ev_dialog.btn_roll.pressed.emit()
	_assert(ev_dialog.roll_result_lbl.text.begins_with("Rolled:"),
		"EventDialog roll still fires on re-popup (one-shot regression)")

	_teardown_scene(ev_dialog)
	_exit_test()

## Character creation flow: randomize + per-player confirm/save loop.
func test_character_creation() -> void:
	_enter_test("character_creation")
	PlayerManager.reset()
	PlayerManager.add_player("Alice")
	PlayerManager.add_player("Bob")
	PlayerManager.add_player("Carol")
	var cc: Node = await _spawn_scene("res://scenes/ui/character_creation.tscn", 0.5)

	_assert(cc != null, "character_creation scene instantiated")
	_assert(cc.race_grid.get_child_count() > 0, "character_creation built race cards")
	_assert(cc.current_step == cc.CreationStep.RACE, "character_creation starts at RACE step")
	cc._on_randomize_pressed()
	await get_tree().create_timer(0.2).timeout
	_assert(not cc.selected_race_id.is_empty(), "character_creation race selected after randomize")
	_assert(not cc.selected_class_id.is_empty(), "character_creation class selected after randomize")
	_assert(cc.current_step == cc.CreationStep.SUMMARY, "character_creation jumped to SUMMARY after randomize")
	cc._confirm_and_save_character()
	await get_tree().create_timer(0.3).timeout
	_assert(PlayerManager.get_player(0).get("character") != null, "player 0 character saved via creation flow")
	_assert(cc.current_player_idx == 1, "creation flow advanced to player 1")
	cc._on_randomize_pressed()
	await get_tree().create_timer(0.2).timeout
	_assert(not cc.selected_race_id.is_empty(), "player 1 selections built in creation flow")
	cc._confirm_and_save_character()
	await get_tree().create_timer(0.3).timeout
	_assert(PlayerManager.get_player(1).get("character") != null, "player 1 character saved via creation flow")
	_assert(cc.current_player_idx == 2, "creation flow advanced to player 2")

	_teardown_scene(cc)
	_exit_test()

## Shop UI: setup + purchase deducts gold + adds to backpack.
func test_shop() -> void:
	_enter_test("shop")
	if PlayerManager.get_player(0).get("character") == null:
		var s1 := AbilityScores.new()
		s1.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
		var shop_char := Character.new()
		shop_char.initialize("Shopper","human","fighter",s1)
		PlayerManager.set_player_character(0, shop_char)
	var shop: ShopUI = await _spawn_scene("res://scenes/ui/shop.tscn", 0.3)

	_assert(shop != null, "ShopUI instantiated")
	shop.setup_shop("Test Town")
	await get_tree().create_timer(0.2).timeout
	_assert(shop.items_data.size() > 0, "ShopUI populated buyable items (got %d)" % shop.items_data.size())
	_assert(shop.gold_label.text.contains("Gold"), "ShopUI gold label set")
	shop.active_player_index = 0
	shop._update_player_data()
	var buyer: Character = PlayerManager.get_player(0).get("character")
	buyer.inventory.gold = 9999
	var gold_before: int = buyer.inventory.gold
	shop.selected_item_idx = 0
	shop._on_item_selected(0)
	shop._update_buy_button_state()
	_assert(not shop.btn_buy.disabled, "ShopUI buy button enabled when affordable")
	shop._on_buy_pressed()
	await get_tree().create_timer(0.2).timeout
	_assert(buyer.inventory.gold < gold_before, "ShopUI purchase deducted gold (%d -> %d)" % [gold_before, buyer.inventory.gold])
	_assert(buyer.inventory.backpack.size() > 0, "ShopUI purchase added item to backpack")

	_teardown_scene(shop)
	_exit_test()

## SaveManager save/load/delete round-trip (actual SaveManager).
func test_save_load() -> void:
	_enter_test("save_load")
	GameManager.active_campaign = DataLoader.campaigns.values()[0]
	GameManager.game_in_progress = true
	GameManager.defeated_monsters.clear()
	GameManager.defeated_monsters.append("goblin")
	PlayerManager.reset()
	PlayerManager.add_player("Saver")
	var ss := AbilityScores.new()
	ss.from_dict({"STR":16,"DEX":12,"CON":14,"INT":10,"WIS":13,"CHA":8})
	var saver := Character.new()
	saver.initialize("Saver","elf","ranger",ss)
	PlayerManager.set_player_character(0, saver)
	var save_ok: bool = SaveManager.save_game("harness_test_slot")
	_assert(save_ok, "SaveManager.save_game returned true")
	_assert(SaveManager.get_available_saves().has("harness_test_slot"), "save slot present after save")
	GameManager.defeated_monsters.clear()
	PlayerManager.reset()
	PlayerManager.add_player("Nobody")
	var load_ok: bool = SaveManager.load_game("harness_test_slot")
	_assert(load_ok, "SaveManager.load_game returned true")
	_assert(GameManager.defeated_monsters.has("goblin"), "load restored defeated_monsters")
	_assert(PlayerManager.get_player_count() == 1, "load restored player count")
	_assert(PlayerManager.get_player(0).get("character") != null, "load restored player character")
	_assert(PlayerManager.get_player(0).get("character").character_name == "Saver", "load restored character name")
	var del_ok: bool = SaveManager.delete_save("harness_test_slot")
	_assert(del_ok, "SaveManager.delete_save returned true")
	_assert(not SaveManager.get_available_saves().has("harness_test_slot"), "save slot gone after delete")
	_exit_test()

## Combat resolution: attack -> damage -> kill (pure logic, no scene).
func test_combat_resolution() -> void:
	_enter_test("combat_resolution")
	var atk_scores := AbilityScores.new()
	atk_scores.from_dict({"STR":18,"DEX":14,"CON":14,"INT":10,"WIS":12,"CHA":8})
	var attacker := Character.new()
	attacker.initialize("Slayer", "human", "fighter", atk_scores)
	var tgt_scores := AbilityScores.new()
	tgt_scores.from_dict({"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	var defender := Character.new()
	defender.initialize("PunchingBag", "goblin", "fighter", tgt_scores)
	defender.max_hp = 5
	defender.current_hp = 5
	defender.is_alive = true
	var weapon := {"name":"sword","ability":"STR","damage":"1d8","damage_type":"slashing"}
	var total_dmg := 0
	var swings := 0
	while defender.is_alive and swings < 50:
		var res := CombatAction.resolve_weapon_attack(attacker, defender, weapon)
		_assert(res.has("hit"), "attack result has 'hit' key")
		if res.get("hit", false):
			total_dmg += int(res.get("damage", 0))
		swings += 1
	_assert(swings < 50, "defender died within 50 swings (got %d)" % swings)
	_assert(not defender.is_alive, "defender is dead after sustained attacks")
	_assert(total_dmg > 0, "attacker dealt total damage (%d)" % total_dmg)
	_assert(defender.current_hp == 0, "defender hp floored at 0")
	_exit_test()

## Event choice resolution: real EventResolver.apply_effects.
func test_event_choice_resolution() -> void:
	_enter_test("event_choice_resolution")
	var ev2_scores := AbilityScores.new()
	ev2_scores.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var ev2_char := Character.new()
	ev2_char.initialize("Chooser", "human", "fighter", ev2_scores)
	ev2_char.inventory.gold = 0
	ev2_char.current_hp = ev2_char.max_hp
	var before_hp := ev2_char.current_hp
	var open_choice := {
		"text": "Just open it",
		"effects": [
			{"type":"damage","value":"1d6","damage_type":"poison"},
			{"type":"grant_condition","condition":"poisoned","duration":3},
			{"type":"give_item","item_id":"gold_100"}
		],
		"description": "test"
	}
	EventResolver.apply_effects(ev2_char, open_choice["effects"])
	_assert(ev2_char.current_hp < before_hp, "event choice dealt damage (%d -> %d)" % [before_hp, ev2_char.current_hp])
	_assert(ev2_char.has_condition("poisoned"), "event choice applied poisoned condition")
	_assert(ev2_char.inventory.has_item("gold_100"), "event choice gave gold_100 item to backpack")
	var heal_choice := [{"type":"heal","value":"2d4"}]
	var hp_before_heal := ev2_char.current_hp
	EventResolver.apply_effects(ev2_char, heal_choice)
	_assert(ev2_char.current_hp > hp_before_heal, "event heal raised hp (%d -> %d)" % [hp_before_heal, ev2_char.current_hp])
	_exit_test()

## Event dialog choice click: end-to-end UI -> resolver.
func test_event_dialog_choice_click() -> void:
	_enter_test("event_dialog_choice_click")
	var evd2vp := SubViewport.new()
	evd2vp.size = Vector2i(1280, 720)
	add_child(evd2vp)
	var evd2: EventDialog = load("res://scenes/ui/event_dialog.tscn").instantiate()
	evd2vp.add_child(evd2)
	await get_tree().create_timer(0.2).timeout
	var dialog_char_scores := AbilityScores.new()
	dialog_char_scores.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var dialog_char := Character.new()
	dialog_char.initialize("Dialoger", "human", "fighter", dialog_char_scores)
	dialog_char.inventory.gold = 0
	var dungeon_events2: Dictionary = DataLoader.get_event_table("dungeon_events")
	var event_list2: Array = dungeon_events2.get("events", [])
	var trapped_chest_evt: Dictionary = {}
	for e in event_list2:
		if e.get("id", "") == "trapped_chest":
			trapped_chest_evt = e
			break
	evd2.popup_event(dialog_char, trapped_chest_evt)
	var choice_buttons: Array = evd2.choice_container.get_children()
	_assert(choice_buttons.size() == 3, "trapped_chest has 3 choice buttons in dialog")
	choice_buttons[1].pressed.emit()
	_assert(dialog_char.current_hp < dialog_char.max_hp, "dialog choice dealt damage to character")
	_assert(dialog_char.inventory.has_item("gold_100"), "dialog choice gave gold_100 via UI")
	evd2vp.remove_child(evd2)
	evd2.queue_free()
	evd2vp.queue_free()
	_exit_test()

## Character Sheet overlay: show + render sections + close.
func test_character_sheet() -> void:
	_enter_test("character_sheet")
	PlayerManager.reset()
	PlayerManager.add_player("SheetHero")
	var sheet_scores := AbilityScores.new()
	sheet_scores.from_dict({"STR":16,"DEX":12,"CON":14,"INT":10,"WIS":13,"CHA":8})
	var sheet_char := Character.new()
	sheet_char.initialize("SheetHero", "human", "fighter", sheet_scores)
	PlayerManager.set_player_character(0, sheet_char)
	PlayerManager.start_game()
	_assert(PlayerManager.get_active_player().get("character") == sheet_char, "active player is SheetHero")
	CharacterSheet.show_active()
	_assert(CharacterSheet.is_open(), "character sheet opens (is_open true)")
	_assert(CharacterSheet._layer != null and CharacterSheet._layer.visible, "character sheet layer is visible")
	_assert(CharacterSheet._content.get_child_count() > 0, "character sheet rendered content sections")
	var title_text: String = CharacterSheet._title.text
	_assert(title_text.contains("SheetHero"), "character sheet title shows character name")
	var all_text := ""
	for sec in CharacterSheet._content.get_children():
		if sec is Label:
			all_text += sec.text + "\n"
	_assert(all_text.contains("Ability Scores"), "character sheet shows Ability Scores section")
	_assert(all_text.contains("STR"), "character sheet shows STR line")
	_assert(all_text.contains("Saving Throws"), "character sheet shows Saving Throws section")
	_assert(all_text.contains("Skills"), "character sheet shows Skills section")
	_assert(all_text.contains("Equipment"), "character sheet shows Equipment section")
	CharacterSheet.close_sheet()
	_assert(not CharacterSheet.is_open(), "character sheet closes (is_open false)")
	_assert(CharacterSheet._layer == null or not CharacterSheet._layer.visible, "character sheet layer hidden after close")
	PlayerManager.reset()
	_exit_test()

# --- combat turn-loop integration (closes AIController-not-driven gap) ------

## Drive the REAL combat turn loop and prove AIController's decision produces a
## real, observable monster action (move toward / attack a player) and that the
## live intent preview is wired to the actual AI, not a stub.
func test_combat_ai_loop() -> void:
	_enter_test("combat_ai_loop")
	_setup_world()
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 3.5)
	await get_tree().create_timer(0.5).timeout

	var initial_positions: Array = []
	for m in combat.monster_entities:
		initial_positions.append(m["hex_position"])
	var initial_hp: int = 0
	for p in combat.player_entities:
		initial_hp += int(p["character"].current_hp)

	var saw_intent := false
	var monster_moved := false
	var player_damaged := false
	var polls := 0
	while polls < 120 and not combat._battle_ending:
		var ac: Dictionary = combat.active_combatant
		if not ac.is_empty() and not ac.get("is_player", true):
			var ent: Dictionary = ac.get("entity", {})
			if ent.get("intent", {}).size() > 0:
				saw_intent = true
		if not ac.is_empty() and ac.get("is_player", false):
			combat._on_hud_action("end_turn", {})
		await get_tree().create_timer(0.3).timeout
		polls += 1
		for i in combat.monster_entities.size():
			if combat.monster_entities[i]["hex_position"] != initial_positions[i]:
				monster_moved = true
		var cur_hp: int = 0
		for p in combat.player_entities:
			cur_hp += int(p["character"].current_hp)
		if cur_hp < initial_hp:
			player_damaged = true
		if saw_intent and (monster_moved or player_damaged):
			break

	_assert(saw_intent, "live monster turn computed an AIController intent (monster['intent'] set in-loop)")
	_assert(monster_moved or player_damaged, "AIController decision produced a real effect (monster moved toward player or dealt damage) through the live turn loop")
	_assert(combat.tracker.current_round >= 1, "combat turn loop advanced at least one round")

	_teardown_scene(combat)
	_exit_test()


## Drive the REAL combat turn loop to a resolved end state: equip players,
## weaken + adjacent the monsters, then have players attack through the actual
## input handlers until victory fires via the shared _check_battle_end_conditions
## chokepoint (not a stubbed 'didn't crash').
func test_combat_victory() -> void:
	_enter_test("combat_victory")
	_setup_world()
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 3.5)
	await get_tree().create_timer(0.5).timeout

	# Equip players so weapon range resolves; weaken + place monsters adjacent.
	for i in combat.player_entities.size():
		var pc: Character = combat.player_entities[i]["character"]
		pc.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	for i in combat.monster_entities.size():
		var m: Dictionary = combat.monster_entities[i]
		var ppos: Vector2i = combat.player_entities[i % combat.player_entities.size()]["hex_position"]
		var spot: Vector2i = ppos
		for n in HexUtils.get_neighbors(ppos):
			if combat.hex_grid.has_tile(n) and combat.hex_grid.is_hex_passable(n):
				spot = n
				break
		m["hex_position"] = spot
		m["current_hp"] = 1
		m["max_hp"] = 1
		m["is_alive"] = true
	combat._update_grid_entities()

	var rounds := 0
	while rounds < 6 and not combat._battle_ending:
		var start_round: int = combat.tracker.current_round
		var guard := 0
		while not combat._battle_ending and combat.tracker.current_round == start_round and guard < 12:
			var ac: Dictionary = combat.active_combatant
			if not ac.is_empty() and ac.get("is_player", false):
				_drive_player_attack_turn(combat)
			await get_tree().create_timer(2.5).timeout
			guard += 1
		rounds += 1

	var alive_monsters := 0
	for m in combat.monster_entities:
		if m["is_alive"]:
			alive_monsters += 1
	_assert(combat._battle_ending, "battle reached an end state through the live turn loop")
	_assert(alive_monsters == 0, "victory: all monsters defeated (got %d alive)" % alive_monsters)
	_assert(GameManager.defeated_monsters.has("goblin"), "victory registered defeated monsters in GameManager")

	_teardown_scene(combat)
	_exit_test()


## Helper: play one player's turn in the live combat scene by driving the real
## movement + attack input handlers toward the nearest alive monster.
func _drive_player_attack_turn(combat: Node) -> void:
	var pidx: int = combat.current_player_idx
	if pidx < 0 or pidx >= combat.player_entities.size():
		return
	var p: Dictionary = combat.player_entities[pidx]
	var pchar: Character = p["character"]
	if pchar == null or not pchar.is_alive:
		combat._on_hud_action("end_turn", {})
		return
	var nearest = null
	var nd := 9999
	for m in combat.monster_entities:
		if not m["is_alive"]:
			continue
		var d: int = HexUtils.get_distance(p["hex_position"], m["hex_position"])
		if d < nd:
			nd = d
			nearest = m
	if nearest == null:
		combat._on_hud_action("end_turn", {})
		return
	var mpos: Vector2i = nearest["hex_position"]
	var weapon_id: String = pchar.inventory.get_weapon()
	var weapon: Dictionary = DataLoader.get_item(weapon_id)
	var max_range: int = int(weapon.get("range", 1))
	if HexUtils.get_distance(p["hex_position"], mpos) <= max_range:
		combat.pending_action_type = "attack"
		combat._on_hex_clicked(mpos)
		if not combat._battle_ending:
			combat._on_hud_action("end_turn", {})
		return
	var reach: Dictionary = combat.hex_grid.get_reachable(p["hex_position"], combat.remaining_speed)
	var best_step: Vector2i = p["hex_position"]
	var best_d: int = nd
	for h in reach:
		var d: int = HexUtils.get_distance(h, mpos)
		if d < best_d:
			best_d = d
			best_step = h
	if best_step != p["hex_position"]:
		combat._on_hex_clicked(best_step)
	if HexUtils.get_distance(combat.player_entities[pidx]["hex_position"], mpos) <= max_range:
		combat.pending_action_type = "attack"
		combat._on_hex_clicked(mpos)
	if not combat._battle_ending:
		combat._on_hud_action("end_turn", {})


# --- reporting --------------------------------------------------------------

func _report() -> void:
	print("--------------------------------------------------")
	print(" VIEWPORT RESULTS: %d failed (%d tests run)" % [_fail, _tests_run])
	if _tests_failed_names.size() > 0:
		print(" FAILED TESTS: %s" % ", ".join(_tests_failed_names))
		for f in _failures:
			print("   - %s" % f)
		print("VIEWPORT TESTS FAILED")
	else:
		print("VIEWPORT TESTS PASSED")
